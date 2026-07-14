#!/usr/bin/env node

// Outreach tracker: concurrency-safe read/write for the codex-profiles outreach
// ledger, which lives in Airtable (base "codex-profiles Outreach Tracker").
//
// This is operational tooling for the agent.md distribution agent. It is NOT part
// of the shipped CLI: it is excluded from the npm package (package.json `files`),
// and it deliberately uses only the Node standard library + global fetch (Node 18+)
// to stay dependency-free, matching test/site/geo-test.mjs.
//
// Why it exists: multiple outreach agents run in parallel. Editing a shared
// Markdown ledger would race (lost updates, duplicate submissions). Target
// upserts deduplicate on `Key`; append-preserving Claims records elect one live
// workflow per target without letting a stale release clear another workflow.
//
// Config (env):
//   AIRTABLE_TOKEN        Personal access token. If unset, read from a file.
//   AIRTABLE_TOKEN_FILE   Token file path (default ~/.codex-outreach-airtable-token).
//   AIRTABLE_BASE         Base id (default appcezSUhDxz7uaQW).
//   AIRTABLE_API_ROOT     API root override (used by the local test harness).
//   AIRTABLE_*_TABLE      Table id/name overrides (used by the local test harness).
//   OUTREACH_*_MS         Lease/retry timing overrides (used by tests).
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
import { randomUUID } from 'node:crypto';

const API_ROOT = (process.env.AIRTABLE_API_ROOT || 'https://api.airtable.com/v0').replace(/\/$/, '');
const BASE = process.env.AIRTABLE_BASE || 'appcezSUhDxz7uaQW';
const TARGETS = process.env.AIRTABLE_TARGETS_TABLE || 'tblHOr51tpYHiaYWQ';
const LOG = process.env.AIRTABLE_LOG_TABLE || 'tbloEavouTn5Z7fOw';
const CLAIMS = process.env.AIRTABLE_CLAIMS_TABLE || 'tbleL9s7CGUpxJDY7';
let activeToken = '';

function durationFromEnv(name, fallback) {
  const raw = process.env[name];
  if (raw === undefined) return fallback;
  const parsed = Number(raw);
  if (!Number.isSafeInteger(parsed) || parsed < 0) {
    process.stderr.write(`${name} must be a non-negative integer.\n`);
    process.exit(2);
  }
  return parsed;
}

const CLAIM_TTL_MS = durationFromEnv('OUTREACH_CLAIM_TTL_MS', 15 * 60 * 1000);
const CLAIM_SETTLE_MS = durationFromEnv('OUTREACH_CLAIM_SETTLE_MS', 2000);
const RETRY_DELAY_MS = durationFromEnv('OUTREACH_RETRY_DELAY_MS', 30_000);

// Exit codes: 0 ok, 1 API/runtime error, 2 usage error, 3 claim lost.
const EXIT = { OK: 0, ERROR: 1, USAGE: 2, CLAIM_LOST: 3 };

function fail(code, message) {
  let safeMessage = String(message);
  for (const secret of new Set([activeToken, process.env.AIRTABLE_TOKEN?.trim()])) {
    if (secret) safeMessage = safeMessage.split(secret).join('[REDACTED]');
  }
  process.stderr.write(`${safeMessage}\n`);
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
activeToken = TOKEN;

// --- Airtable REST helper (with one 429 back-off retry) ------------------------

async function api(method, table, { search, body } = {}) {
  let url = `${API_ROOT}/${encodeURIComponent(BASE)}/${encodeURIComponent(table)}`;
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
        await sleep(RETRY_DELAY_MS);
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

// Escape a value for use inside an Airtable formula string literal.
const lit = (value) => `"${String(value)
  .replace(/\\/g, '\\\\')
  .replace(/"/g, '\\"')
  .replace(/\r/g, '\\r')
  .replace(/\n/g, '\\n')}"`;

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

async function upsertClaim(fields) {
  return api('PATCH', CLAIMS, {
    body: {
      performUpsert: { fieldsToMergeOn: ['Key'] },
      records: [{ fields }],
      typecast: true,
    },
  });
}

async function updateClaims(records) {
  if (!records.length) return { records: [] };
  return api('PATCH', CLAIMS, {
    body: { records, typecast: true },
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

function assertFlags(flags, allowed) {
  for (const flag of Object.keys(flags)) {
    if (!allowed.includes(flag)) fail(EXIT.USAGE, `Unknown option: --${flag}`);
  }
}

function assertPositionals(positionals, min, max, usage) {
  if (positionals.length < min || positionals.length > max) fail(EXIT.USAGE, usage);
}

function requiredFlag(flags, name, usage) {
  const value = flags[name];
  if (value === undefined || value === true || value === '') fail(EXIT.USAGE, usage);
  return value;
}

function asBool(value) {
  if (value === true || value === 'true' || value === '1' || value === 'yes') return true;
  if (value === false || value === 'false' || value === '0' || value === 'no') return false;
  fail(EXIT.USAGE, `Expected a boolean value, got: ${value}`);
}

function assertDate(value, flag) {
  const parsed = new Date(`${value}T00:00:00Z`);
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)
    || Number.isNaN(parsed.getTime())
    || parsed.toISOString().slice(0, 10) !== value) {
    fail(EXIT.USAGE, `--${flag} must use YYYY-MM-DD.`);
  }
}

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
  if (flags['last-checked'] !== undefined) {
    if (flags['last-checked'] === true) fail(EXIT.USAGE, '--last-checked requires YYYY-MM-DD.');
    assertDate(flags['last-checked'], 'last-checked');
    fields['Last Checked'] = flags['last-checked'];
  }
  if (flags.owned !== undefined) fields['Owned?'] = asBool(flags.owned);
  return fields;
}

// --- Output --------------------------------------------------------------------

const COLS = ['Key', 'Name', 'Status', 'Priority', 'Channel', 'Owned?', 'Last Checked', 'Next Action'];

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
  assertFlags(flags, ['status', 'priority', 'channel', 'owned', 'json']);
  for (const name of ['status', 'priority', 'channel']) {
    if (flags[name] !== undefined) requiredFlag(flags, name, `--${name} requires a value.`);
  }
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
  assertFlags(flags, ['json']);
  assertPositionals(positionals, 1, 1, 'usage: get <key> [--json]');
  const key = positionals[0];
  const rec = await resolveTarget(key);
  if (flags.json) process.stdout.write(`${JSON.stringify(rec.fields, null, 2)}\n`);
  else printTable([rec]);
}

async function targetClaims(key) {
  return getRecords(CLAIMS, { filterByFormula: `{Target Key}=${lit(key)}` });
}

function isActiveClaim(record, now = Date.now()) {
  const expiresAt = Date.parse(record.fields['Expires At'] || '');
  return !record.fields['Released At'] && Number.isFinite(expiresAt) && expiresAt > now;
}

function compareClaims(a, b) {
  const created = Date.parse(a.createdTime) - Date.parse(b.createdTime);
  if (created !== 0) return created;
  return String(a.fields.Key).localeCompare(String(b.fields.Key));
}

async function cmdClaim(positionals, flags) {
  assertFlags(flags, ['by']);
  assertPositionals(positionals, 1, 1, 'usage: claim <key> --by <workflowId>');
  const key = positionals[0];
  const by = requiredFlag(flags, 'by', 'usage: claim <key> --by <workflowId>');
  const target = await resolveTarget(key);
  const existing = (await targetClaims(key)).filter((claim) => isActiveClaim(claim));
  const owned = existing.find((claim) => claim.fields.Workflow === by);
  if (owned) {
    process.stdout.write(`Claimed ${key} as ${by} (${owned.fields.Key}).\n`);
    return;
  }
  if (existing.length) {
    const holder = existing.sort(compareClaims)[0];
    fail(EXIT.CLAIM_LOST, `Claim lost: ${key} is held by ${holder.fields.Workflow}.`);
  }

  const claimedAt = new Date();
  const claimKey = `${key}:${by}:${randomUUID()}`;
  await upsertClaim({
    Key: claimKey,
    'Target Key': key,
    Target: [target.id],
    Workflow: by,
    'Claimed At': claimedAt.toISOString(),
    'Expires At': new Date(claimedAt.getTime() + CLAIM_TTL_MS).toISOString(),
  });

  await sleep(CLAIM_SETTLE_MS);
  const contenders = (await targetClaims(key)).filter((claim) => isActiveClaim(claim)).sort(compareClaims);
  const winner = contenders[0];
  if (!winner || winner.fields.Key !== claimKey) {
    const own = contenders.find((claim) => claim.fields.Key === claimKey);
    if (own) await updateClaims([{ id: own.id, fields: { 'Released At': new Date().toISOString() } }]);
    fail(EXIT.CLAIM_LOST, `Claim lost: ${key} is held by ${winner?.fields.Workflow || 'another workflow'}.`);
  }
  await appendLog({ target: key, workflow: by, action: 'Claimed' });
  process.stdout.write(`Claimed ${key} as ${by} (${claimKey}).\n`);
}

async function cmdRelease(positionals, flags) {
  assertFlags(flags, ['by']);
  assertPositionals(positionals, 1, 1, 'usage: release <key> --by <workflowId>');
  const key = positionals[0];
  const by = requiredFlag(flags, 'by', 'usage: release <key> --by <workflowId>');
  await resolveTarget(key);
  const claims = await targetClaims(key);
  const owned = claims.filter((claim) => claim.fields.Workflow === by);
  if (!owned.length) fail(EXIT.CLAIM_LOST, `Release refused: ${by} has never claimed ${key}.`);
  const active = owned.filter((claim) => isActiveClaim(claim));
  if (!active.length) {
    process.stdout.write(`No active claim for ${key} as ${by}.\n`);
    return;
  }
  const releasedAt = new Date().toISOString();
  await updateClaims(active.map((claim) => ({ id: claim.id, fields: { 'Released At': releasedAt } })));
  await appendLog({ target: key, workflow: by, action: 'Released Claim' });
  process.stdout.write(`Released ${key}.\n`);
}

async function cmdUpsert(positionals, flags) {
  assertFlags(flags, ['name', 'channel', 'status', 'priority', 'link', 'owned', 'last-checked', 'next-action', 'last-version-told', 'notes']);
  assertPositionals(positionals, 1, 1, 'usage: upsert <key> [--name ... --status ... ...]');
  for (const name of Object.keys(flags)) {
    requiredFlag(flags, name, `--${name} requires a value.`);
  }
  const key = positionals[0];
  const fields = { Key: key, ...fieldsFromFlags(flags) };
  await upsertTarget(fields);
  process.stdout.write(`Upserted ${key}.\n`);
}

async function cmdSetStatus(positionals, flags) {
  assertFlags(flags, []);
  assertPositionals(positionals, 2, 2, 'usage: set-status <key> <status>');
  const [key, status] = positionals;
  await upsertTarget({ Key: key, Status: status });
  await appendLog({ target: key, action: 'Status Change', result: `-> ${status}` });
  process.stdout.write(`Set ${key} status to ${status}.\n`);
}

async function cmdLog(flags) {
  assertFlags(flags, ['target', 'workflow', 'action', 'result', 'link']);
  const usage = 'usage: log --target <key> --workflow <id> --action <A> [--result T] [--link URL]';
  const target = requiredFlag(flags, 'target', usage);
  const workflow = requiredFlag(flags, 'workflow', usage);
  const action = requiredFlag(flags, 'action', usage);
  for (const name of ['result', 'link']) {
    if (flags[name] !== undefined) requiredFlag(flags, name, `--${name} requires a value.`);
  }
  await appendLog({
    target,
    workflow,
    action,
    result: flags.result,
    link: flags.link,
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
    case 'set-status': return cmdSetStatus(positionals, flags);
    case 'log': return cmdLog(flags);
    default:
      process.stderr.write('Commands: list | get | claim | release | upsert | set-status | log\n');
      process.exit(command ? EXIT.USAGE : EXIT.OK);
  }
}

main().catch((err) => fail(EXIT.ERROR, err?.stack || String(err)));
