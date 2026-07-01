#!/usr/bin/env node

// Outreach tracker: concurrency-safe read/write for the codex-profiles outreach
// ledger, which lives in Airtable (base "codex-profiles Outreach Tracker").
//
// This is operational tooling for the agent.md distribution agent. It is NOT part
// of the shipped CLI: it is excluded from the npm package (package.json `files`),
// and it deliberately uses only the Node standard library + global fetch (Node 18+)
// to stay dependency-free, matching test/geo-site-test.mjs.
//
// Why it exists: multiple outreach agents run in parallel. Editing a shared
// Markdown ledger would race (lost updates, duplicate submissions). Airtable gives
// atomic upserts (dedup on `Key`) and a claim protocol so two agents never act on
// the same target at once.
//
// Config (env):
//   AIRTABLE_TOKEN        Personal access token. If unset, read from a file.
//   AIRTABLE_TOKEN_FILE   Token file path (default ~/.codex-outreach-airtable-token).
//   AIRTABLE_BASE         Base id (default appcezSUhDxz7uaQW).
//
// Commands:
//   list [--status S] [--priority P] [--channel C] [--owned] [--json]
//   get <key> [--json]
//   claim <key> --by <workflowId>
//   release <key> --by <workflowId>
//   upsert <key> [--name .. --channel .. --status .. --priority .. --link ..
//                 --owned true|false --last-checked YYYY-MM-DD --next-action ..
//                 --last-version-told .. --notes ..]
//   set-status <key> <status>
//   log --target <key> --workflow <id> --action <A> [--result T] [--link URL]

import { readFileSync } from 'node:fs';
import { homedir } from 'node:os';
import { join } from 'node:path';
import { setTimeout as sleep } from 'node:timers/promises';

const BASE = process.env.AIRTABLE_BASE || 'appcezSUhDxz7uaQW';
const TARGETS = 'tblHOr51tpYHiaYWQ';
const LOG = 'tbloEavouTn5Z7fOw';
const CLAIM_TTL_MS = 15 * 60 * 1000; // a claim older than this is stale/steal-able
const RECHECK_DELAY_MS = 2000; // wait before confirming a claim stuck

// Exit codes: 0 ok, 1 API/runtime error, 2 usage error, 3 claim lost.
const EXIT = { OK: 0, ERROR: 1, USAGE: 2, CLAIM_LOST: 3 };

function fail(code, message) {
  process.stderr.write(`${message}\n`);
  process.exit(code);
}

function token() {
  if (process.env.AIRTABLE_TOKEN) return process.env.AIRTABLE_TOKEN.trim();
  const path = process.env.AIRTABLE_TOKEN_FILE || join(homedir(), '.codex-outreach-airtable-token');
  try {
    return readFileSync(path, 'utf8').trim();
  } catch {
    fail(EXIT.USAGE, `No token: set AIRTABLE_TOKEN or create ${path}`);
  }
}

const TOKEN = token();

// --- Airtable REST helper (with one 429 back-off retry) ------------------------

async function api(method, table, { search, body } = {}) {
  let url = `https://api.airtable.com/v0/${BASE}/${table}`;
  if (search) url += `?${search}`;
  const init = {
    method,
    headers: { Authorization: `Bearer ${TOKEN}` },
  };
  if (body) {
    init.headers['Content-Type'] = 'application/json';
    init.body = JSON.stringify(body);
  }
  for (let attempt = 0; attempt < 2; attempt++) {
    const res = await fetch(url, init);
    if (res.status === 429) {
      // Airtable caps at 5 req/s per base; back off the documented 30s once.
      if (attempt === 0) {
        await sleep(30_000);
        continue;
      }
    }
    const text = await res.text();
    if (!res.ok) {
      fail(EXIT.ERROR, `Airtable ${method} ${table} -> ${res.status}: ${text}`);
    }
    return text ? JSON.parse(text) : {};
  }
}

// Escape a value for use inside an Airtable formula string literal. Our values
// never contain double quotes, so wrapping in double quotes avoids apostrophe
// breakage (e.g. statuses/keys are safe; free text has no `"`).
const lit = (value) => `"${String(value).replace(/"/g, '\\"')}"`;

async function getRecords(table, { filterByFormula, fields } = {}) {
  const records = [];
  let offset;
  do {
    const params = new URLSearchParams({ pageSize: '100' });
    if (filterByFormula) params.set('filterByFormula', filterByFormula);
    if (fields) for (const f of fields) params.append('fields[]', f);
    if (offset) params.set('offset', offset);
    const data = await api('GET', table, { search: params.toString() });
    records.push(...data.records);
    offset = data.offset;
  } while (offset);
  return records;
}

async function resolveTarget(key) {
  const [record] = await getRecords(TARGETS, { filterByFormula: `{Key}=${lit(key)}` });
  if (!record) fail(EXIT.ERROR, `No target with Key=${key}`);
  return record;
}

// Upsert on Key so concurrent writers merge into one row instead of duplicating.
async function upsertTarget(fields) {
  return api('PATCH', TARGETS, {
    body: {
      performUpsert: { fieldsToMergeOn: ['Key'] },
      records: [{ fields }],
      typecast: true,
    },
  });
}

async function appendLog({ target, workflow, action, result, link }) {
  const fields = {
    Event: `${action} — ${target}`,
    Timestamp: new Date().toISOString(),
    Workflow: workflow || '',
    Action: action,
  };
  if (result) fields.Result = result;
  if (link) fields.Link = link;
  // Link to the Target record when it exists (log is append-only).
  const [rec] = await getRecords(TARGETS, { filterByFormula: `{Key}=${lit(target)}`, fields: ['Key'] });
  if (rec) fields.Target = [rec.id];
  return api('POST', LOG, { body: { records: [{ fields }], typecast: true } });
}

// --- Arg parsing ---------------------------------------------------------------

function parseArgs(argv) {
  const positionals = [];
  const flags = {};
  for (let i = 0; i < argv.length; i++) {
    const tok = argv[i];
    if (tok.startsWith('--')) {
      const eq = tok.indexOf('=');
      if (eq !== -1) {
        flags[tok.slice(2, eq)] = tok.slice(eq + 1);
      } else {
        const name = tok.slice(2);
        const next = argv[i + 1];
        if (next !== undefined && !next.startsWith('--')) {
          flags[name] = next;
          i++;
        } else {
          flags[name] = true;
        }
      }
    } else {
      positionals.push(tok);
    }
  }
  return { positionals, flags };
}

const asBool = (v) => !(v === false || v === 'false' || v === '0' || v === 'no');

// Map --flags to Target field names.
function fieldsFromFlags(flags) {
  const map = {
    name: 'Name',
    channel: 'Channel',
    status: 'Status',
    priority: 'Priority',
    link: 'Link',
    'next-action': 'Next Action',
    'last-version-told': 'Last Version Told',
    notes: 'Notes',
  };
  const fields = {};
  for (const [flag, col] of Object.entries(map)) {
    if (flags[flag] !== undefined) fields[col] = flags[flag];
  }
  if (flags['last-checked'] !== undefined) fields['Last Checked'] = flags['last-checked'];
  if (flags.owned !== undefined) fields['Owned?'] = asBool(flags.owned);
  return fields;
}

// --- Output --------------------------------------------------------------------

const COLS = ['Key', 'Name', 'Status', 'Priority', 'Channel', 'Owned?', 'Claimed By', 'Last Checked', 'Next Action'];

function printTable(records) {
  if (!records.length) {
    process.stdout.write('(no matching targets)\n');
    return;
  }
  const rows = records.map((r) => COLS.map((c) => {
    const v = r.fields[c];
    if (v === true) return 'yes';
    if (v === undefined || v === false) return '';
    return String(v);
  }));
  const widths = COLS.map((c, i) => Math.min(40, Math.max(c.length, ...rows.map((row) => row[i].length))));
  const fmt = (cells) => cells.map((cell, i) => cell.slice(0, widths[i]).padEnd(widths[i])).join('  ');
  process.stdout.write(`${fmt(COLS)}\n`);
  process.stdout.write(`${widths.map((w) => '-'.repeat(w)).join('  ')}\n`);
  for (const row of rows) process.stdout.write(`${fmt(row)}\n`);
  process.stdout.write(`\n${records.length} target(s)\n`);
}

// --- Commands ------------------------------------------------------------------

async function cmdList(flags) {
  const clauses = [];
  if (flags.status) clauses.push(`{Status}=${lit(flags.status)}`);
  if (flags.priority) clauses.push(`{Priority}=${lit(flags.priority)}`);
  if (flags.channel) clauses.push(`{Channel}=${lit(flags.channel)}`);
  if (flags.owned) clauses.push('{Owned?}=1');
  const filterByFormula = clauses.length ? (clauses.length === 1 ? clauses[0] : `AND(${clauses.join(',')})`) : undefined;
  const records = await getRecords(TARGETS, { filterByFormula });
  records.sort((a, b) => (a.fields.Key || '').localeCompare(b.fields.Key || ''));
  if (flags.json) {
    process.stdout.write(`${JSON.stringify(records.map((r) => r.fields), null, 2)}\n`);
  } else {
    printTable(records);
  }
}

async function cmdGet(positionals, flags) {
  const key = positionals[0];
  if (!key) fail(EXIT.USAGE, 'usage: get <key>');
  const rec = await resolveTarget(key);
  if (flags.json) process.stdout.write(`${JSON.stringify(rec.fields, null, 2)}\n`);
  else printTable([rec]);
}

async function cmdClaim(positionals, flags) {
  const key = positionals[0];
  const by = flags.by;
  if (!key || !by || by === true) fail(EXIT.USAGE, 'usage: claim <key> --by <workflowId>');
  const rec = await resolveTarget(key);
  const holder = rec.fields['Claimed By'];
  const at = rec.fields['Claimed At'];
  const fresh = at && Date.now() - new Date(at).getTime() < CLAIM_TTL_MS;
  if (holder && holder !== by && fresh) {
    fail(EXIT.CLAIM_LOST, `Claim lost: ${key} is held by ${holder} (claimed ${at}).`);
  }
  await upsertTarget({ Key: key, 'Claimed By': by, 'Claimed At': new Date().toISOString() });
  // Confirm the write stuck and no one raced us in the same window.
  await sleep(RECHECK_DELAY_MS);
  const after = await resolveTarget(key);
  if (after.fields['Claimed By'] !== by) {
    fail(EXIT.CLAIM_LOST, `Claim lost: ${key} is now held by ${after.fields['Claimed By']}.`);
  }
  await appendLog({ target: key, workflow: by, action: 'Claimed' });
  process.stdout.write(`Claimed ${key} as ${by}.\n`);
}

async function cmdRelease(positionals, flags) {
  const key = positionals[0];
  const by = flags.by;
  if (!key || !by || by === true) fail(EXIT.USAGE, 'usage: release <key> --by <workflowId>');
  await upsertTarget({ Key: key, 'Claimed By': '', 'Claimed At': null });
  await appendLog({ target: key, workflow: by, action: 'Released Claim' });
  process.stdout.write(`Released ${key}.\n`);
}

async function cmdUpsert(positionals, flags) {
  const key = positionals[0];
  if (!key) fail(EXIT.USAGE, 'usage: upsert <key> [--name ... --status ... ...]');
  const fields = { Key: key, ...fieldsFromFlags(flags) };
  await upsertTarget(fields);
  process.stdout.write(`Upserted ${key}.\n`);
}

async function cmdSetStatus(positionals) {
  const [key, status] = positionals;
  if (!key || !status) fail(EXIT.USAGE, 'usage: set-status <key> <status>');
  await upsertTarget({ Key: key, Status: status });
  await appendLog({ target: key, action: 'Status Change', result: `-> ${status}` });
  process.stdout.write(`Set ${key} status to ${status}.\n`);
}

async function cmdLog(flags) {
  const target = flags.target;
  const action = flags.action;
  if (!target || target === true || !action || action === true) {
    fail(EXIT.USAGE, 'usage: log --target <key> --workflow <id> --action <A> [--result T] [--link URL]');
  }
  await appendLog({
    target,
    workflow: flags.workflow === true ? '' : flags.workflow,
    action,
    result: flags.result === true ? undefined : flags.result,
    link: flags.link === true ? undefined : flags.link,
  });
  process.stdout.write(`Logged "${action}" for ${target}.\n`);
}

// --- Dispatch ------------------------------------------------------------------

async function main() {
  const [command, ...rest] = process.argv.slice(2);
  const { positionals, flags } = parseArgs(rest);
  switch (command) {
    case 'list': return cmdList(flags);
    case 'get': return cmdGet(positionals, flags);
    case 'claim': return cmdClaim(positionals, flags);
    case 'release': return cmdRelease(positionals, flags);
    case 'upsert': return cmdUpsert(positionals, flags);
    case 'set-status': return cmdSetStatus(positionals);
    case 'log': return cmdLog(flags);
    default:
      process.stderr.write('Commands: list | get | claim | release | upsert | set-status | log\n');
      process.exit(command ? EXIT.USAGE : EXIT.OK);
  }
}

main().catch((err) => fail(EXIT.ERROR, err?.stack || String(err)));
