#!/usr/bin/env node

// Concurrency-safe outreach ledger backed by Neon Postgres through its Data API.
// This is operational tooling and is excluded from the published CLI package.
// It intentionally uses only Node's standard library and global fetch.
//
// Config:
//   NEON_DATA_API_URL    Branch Data API URL ending in /rest/v1.
//   NEON_JWT_KEY_FILE    RS256 private key (default ~/.codex-outreach-neon-private.pem).
//   OUTREACH_CLAIM_TTL_MS      Lease duration (default 15 minutes).
//   OUTREACH_RETRY_DELAY_MS    Initial transient retry delay (default 500ms).
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
//   queue list [--status Pending|Merged|Rejected] [--json]
//   queue enqueue <key> --by <workflow> --target-data <text>
//                 [--linked-target <target-key>] [--notes <text>]
//   queue resolve <key> --by <workflow> --status Merged|Rejected
//                 [--linked-target <target-key>] [--duplicate-of <queue-key>]
//                 [--notes <text>]

import { createHash, createPublicKey, randomUUID, sign } from 'node:crypto';
import { readFileSync, statSync } from 'node:fs';
import { homedir } from 'node:os';
import { join } from 'node:path';
import { setTimeout as sleep } from 'node:timers/promises';

const EXIT = { OK: 0, ERROR: 1, USAGE: 2, CLAIM_LOST: 3 };
const JWT_AUDIENCE = 'codex-profiles-outreach';
const JWT_SUBJECT = 'codex-profiles-outreach-agent';
const JWT_ROLE = 'outreach_tracker';
const PAGE_SIZE = 1000;
let activePrivateKey = '';
let activeJwt = '';

function durationFromEnv(name, fallback) {
  const raw = process.env[name];
  if (raw === undefined) return fallback;
  const parsed = Number(raw);
  if (!Number.isSafeInteger(parsed) || parsed < 0) {
    process.stderr.write(`${name} must be a non-negative integer.\n`);
    process.exit(EXIT.USAGE);
  }
  return parsed;
}

const CLAIM_TTL_MS = durationFromEnv('OUTREACH_CLAIM_TTL_MS', 15 * 60 * 1000);
const RETRY_DELAY_MS = durationFromEnv('OUTREACH_RETRY_DELAY_MS', 500);

function fail(code, message) {
  let safeMessage = String(message);
  for (const secret of new Set([activePrivateKey, activeJwt])) {
    if (secret) safeMessage = safeMessage.split(secret).join('[REDACTED]');
  }
  process.stderr.write(`${safeMessage}\n`);
  process.exit(code);
}

function dataApiUrl() {
  const value = process.env.NEON_DATA_API_URL?.replace(/\/$/, '');
  if (!value) fail(EXIT.USAGE, 'No Neon endpoint: set NEON_DATA_API_URL.');
  if (!/^https:\/\//.test(value) && !/^http:\/\/127\.0\.0\.1(?::\d+)?/.test(value)) {
    fail(EXIT.USAGE, 'NEON_DATA_API_URL must use HTTPS.');
  }
  return value;
}

function base64url(value) {
  return Buffer.from(value).toString('base64url');
}

function jwkThumbprint(jwk) {
  const canonical = JSON.stringify({ e: jwk.e, kty: jwk.kty, n: jwk.n });
  return createHash('sha256').update(canonical).digest('base64url');
}

function privateKey() {
  if (activePrivateKey) return activePrivateKey;
  const path = process.env.NEON_JWT_KEY_FILE
    || join(homedir(), '.codex-outreach-neon-private.pem');
  let info;
  try {
    info = statSync(path);
    activePrivateKey = readFileSync(path, 'utf8');
  } catch {
    fail(EXIT.USAGE, `No signing key: create ${path} or set NEON_JWT_KEY_FILE.`);
  }
  if (!info.isFile()) fail(EXIT.USAGE, `Signing key is not a regular file: ${path}`);
  if ((info.mode & 0o077) !== 0) {
    fail(EXIT.USAGE, `Signing key must have mode 0600: ${path}`);
  }
  try {
    const jwk = createPublicKey(activePrivateKey).export({ format: 'jwk' });
    if (jwk.kty !== 'RSA') fail(EXIT.USAGE, 'Signing key must be RSA.');
  } catch (error) {
    fail(EXIT.USAGE, `Invalid signing key: ${error.message}`);
  }
  return activePrivateKey;
}

function jwt() {
  const key = privateKey();
  const publicJwk = createPublicKey(key).export({ format: 'jwk' });
  const now = Math.floor(Date.now() / 1000);
  const header = base64url(JSON.stringify({
    alg: 'RS256', typ: 'JWT', kid: jwkThumbprint(publicJwk),
  }));
  const payload = base64url(JSON.stringify({
    aud: JWT_AUDIENCE,
    sub: JWT_SUBJECT,
    role: JWT_ROLE,
    iat: now,
    nbf: now - 30,
    exp: now + 300,
    jti: randomUUID(),
  }));
  const signingInput = `${header}.${payload}`;
  activeJwt = `${signingInput}.${sign('RSA-SHA256', Buffer.from(signingInput), key).toString('base64url')}`;
  return activeJwt;
}

function transientStatus(status) {
  return status === 429 || status === 502 || status === 503 || status === 504;
}

async function rpcRequest(name, body, { start } = {}) {
  const url = `${dataApiUrl()}/rpc/${name}`;
  let lastError;
  for (let attempt = 0; attempt < 3; attempt++) {
    const token = jwt();
    const headers = {
      Authorization: `Bearer ${token}`,
      Accept: 'application/json',
      'Content-Type': 'application/json',
    };
    if (start !== undefined) {
      headers.Range = `${start}-${start + PAGE_SIZE - 1}`;
      headers.Prefer = 'count=exact';
    }
    try {
      const response = await fetch(url, {
        method: 'POST', headers, body: JSON.stringify(body),
      });
      const text = await response.text();
      if (response.ok) {
        return {
          rows: text ? JSON.parse(text) : [],
          contentRange: response.headers.get('content-range'),
        };
      }
      lastError = new Error(`Neon RPC ${name} -> ${response.status}: ${text}`);
      if (!transientStatus(response.status) || attempt === 2) throw lastError;
      const retryAfter = Number(response.headers.get('retry-after'));
      await sleep(Number.isFinite(retryAfter) ? retryAfter * 1000 : RETRY_DELAY_MS * 2 ** attempt);
    } catch (error) {
      lastError = error;
      if (attempt === 2 || /Neon RPC/.test(error.message)) throw error;
      await sleep(RETRY_DELAY_MS * 2 ** attempt);
    }
  }
  throw lastError;
}

function rowArray(value) {
  if (Array.isArray(value)) return value;
  if (value === null || value === undefined) return [];
  return [value];
}

async function rpcRows(name, body, { paginate = false } = {}) {
  if (!paginate) return rowArray((await rpcRequest(name, body)).rows);
  const rows = [];
  for (let start = 0; ; start += PAGE_SIZE) {
    const page = await rpcRequest(name, body, { start });
    const pageRows = rowArray(page.rows);
    rows.push(...pageRows);
    const totalMatch = page.contentRange?.match(/\/(\d+)$/);
    if (pageRows.length < PAGE_SIZE || (totalMatch && rows.length >= Number(totalMatch[1]))) break;
  }
  return rows;
}

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

function fieldsFromFlags(flags) {
  const map = {
    name: 'Name', channel: 'Channel', status: 'Status', priority: 'Priority',
    link: 'Link', 'next-action': 'Next Action',
    'last-version-told': 'Last Version Told', notes: 'Notes',
  };
  const fields = {};
  for (const [flag, column] of Object.entries(map)) {
    if (flags[flag] !== undefined) fields[column] = flags[flag];
  }
  if (flags['last-checked'] !== undefined) {
    if (flags['last-checked'] === true) fail(EXIT.USAGE, '--last-checked requires YYYY-MM-DD.');
    assertDate(flags['last-checked'], 'last-checked');
    fields['Last Checked'] = flags['last-checked'];
  }
  if (flags.owned !== undefined) fields['Owned?'] = asBool(flags.owned);
  return fields;
}

function setIf(fields, key, value, { boolean = false } = {}) {
  if (value !== null && value !== undefined && (!boolean || value === true)) fields[key] = value;
}

function targetFields(row) {
  const fields = { Key: row.key };
  setIf(fields, 'Name', row.name);
  setIf(fields, 'Status', row.status);
  setIf(fields, 'Priority', row.priority);
  setIf(fields, 'Channel', row.channel);
  setIf(fields, 'Link', row.link);
  setIf(fields, 'Owned?', row.owned, { boolean: true });
  setIf(fields, 'Last Checked', row.last_checked);
  setIf(fields, 'Next Action', row.next_action);
  setIf(fields, 'Last Version Told', row.last_version_told);
  setIf(fields, 'Notes', row.notes);
  return fields;
}

function queueFields(row) {
  const fields = { Key: row.key, Status: row.status };
  setIf(fields, 'Timestamp', row.proposed_at);
  setIf(fields, 'Proposed By Workflow', row.proposed_by_workflow);
  setIf(fields, 'Target Data', row.target_data);
  setIf(fields, 'Notes', row.notes);
  setIf(fields, 'Resolved At', row.resolved_at);
  setIf(fields, 'Resolved By Workflow', row.resolved_by_workflow);
  if (row.proposed_by?.length) fields['Proposed By'] = row.proposed_by;
  if (row.linked_targets?.length) fields['Linked Target'] = row.linked_targets;
  if (row.duplicate_of?.length) fields['Duplicate Of'] = row.duplicate_of;
  return fields;
}

const COLS = ['Key', 'Name', 'Status', 'Priority', 'Channel', 'Owned?', 'Last Checked', 'Next Action'];

function printTable(records) {
  if (!records.length) {
    process.stdout.write('(no matching targets)\n');
    return;
  }
  const rows = records.map((record) => COLS.map((column) => {
    const value = record[column];
    if (value === true) return 'yes';
    if (value === undefined || value === false) return '';
    return String(value);
  }));
  const widths = COLS.map((column, index) => Math.min(40,
    Math.max(column.length, ...rows.map((row) => row[index].length))));
  const format = (cells) => cells.map((cell, index) =>
    cell.slice(0, widths[index]).padEnd(widths[index])).join('  ');
  process.stdout.write(`${format(COLS)}\n`);
  process.stdout.write(`${widths.map((width) => '-'.repeat(width)).join('  ')}\n`);
  for (const row of rows) process.stdout.write(`${format(row)}\n`);
  process.stdout.write(`\n${records.length} target(s)\n`);
}

function printQueue(records) {
  if (!records.length) {
    process.stdout.write('(no matching queue items)\n');
    return;
  }
  for (const record of records) {
    process.stdout.write(`${record.Key}\t${record.Status}\t${record['Target Data'] || ''}\n`);
  }
  process.stdout.write(`\n${records.length} queue item(s)\n`);
}

async function cmdList(flags) {
  assertFlags(flags, ['status', 'priority', 'channel', 'owned', 'json']);
  for (const name of ['status', 'priority', 'channel']) {
    if (flags[name] !== undefined) requiredFlag(flags, name, `--${name} requires a value.`);
  }
  const rows = await rpcRows('tracker_list_targets', {
    p_status: flags.status || null,
    p_priority: flags.priority || null,
    p_channel: flags.channel || null,
    p_owned: flags.owned ? true : null,
  }, { paginate: true });
  const records = rows.map(targetFields);
  if (flags.json) process.stdout.write(`${JSON.stringify(records, null, 2)}\n`);
  else printTable(records);
}

async function getTarget(key) {
  const [row] = await rpcRows('tracker_get_target', { p_key: key });
  if (!row) fail(EXIT.ERROR, `No target with Key=${key}`);
  return targetFields(row);
}

async function cmdGet(positionals, flags) {
  assertFlags(flags, ['json']);
  assertPositionals(positionals, 1, 1, 'usage: get <key> [--json]');
  const record = await getTarget(positionals[0]);
  if (flags.json) process.stdout.write(`${JSON.stringify(record, null, 2)}\n`);
  else printTable([record]);
}

async function cmdClaim(positionals, flags) {
  assertFlags(flags, ['by']);
  assertPositionals(positionals, 1, 1, 'usage: claim <key> --by <workflowId>');
  const key = positionals[0];
  const by = requiredFlag(flags, 'by', 'usage: claim <key> --by <workflowId>');
  const [result] = await rpcRows('tracker_claim', {
    p_key: key,
    p_workflow: by,
    p_ttl_ms: CLAIM_TTL_MS,
    p_operation_id: randomUUID(),
  });
  if (result?.outcome === 'lost') {
    fail(EXIT.CLAIM_LOST, `Claim lost: ${key} is held by ${result.holder}.`);
  }
  if (!result || !['claimed', 'owned'].includes(result.outcome)) {
    fail(EXIT.ERROR, `Unexpected claim result for ${key}.`);
  }
  process.stdout.write(`Claimed ${key} as ${by} (${result.claim_key}).\n`);
}

async function cmdRelease(positionals, flags) {
  assertFlags(flags, ['by']);
  assertPositionals(positionals, 1, 1, 'usage: release <key> --by <workflowId>');
  const key = positionals[0];
  const by = requiredFlag(flags, 'by', 'usage: release <key> --by <workflowId>');
  const [result] = await rpcRows('tracker_release', {
    p_key: key, p_workflow: by, p_operation_id: randomUUID(),
  });
  if (result?.outcome === 'never') {
    fail(EXIT.CLAIM_LOST, `Release refused: ${by} has never claimed ${key}.`);
  }
  if (result?.outcome === 'inactive') {
    process.stdout.write(`No active claim for ${key} as ${by}.\n`);
    return;
  }
  if (result?.outcome !== 'released') fail(EXIT.ERROR, `Unexpected release result for ${key}.`);
  process.stdout.write(`Released ${key}.\n`);
}

async function cmdUpsert(positionals, flags) {
  assertFlags(flags, ['name', 'channel', 'status', 'priority', 'link', 'owned',
    'last-checked', 'next-action', 'last-version-told', 'notes']);
  assertPositionals(positionals, 1, 1, 'usage: upsert <key> [--name ... --status ... ...]');
  for (const name of Object.keys(flags)) requiredFlag(flags, name, `--${name} requires a value.`);
  const key = positionals[0];
  await rpcRows('tracker_upsert_target', { p_key: key, p_patch: fieldsFromFlags(flags) });
  process.stdout.write(`Upserted ${key}.\n`);
}

async function cmdSetStatus(positionals, flags) {
  assertFlags(flags, []);
  assertPositionals(positionals, 2, 2, 'usage: set-status <key> <status>');
  const [key, status] = positionals;
  await rpcRows('tracker_set_status', {
    p_key: key, p_status: status, p_operation_id: randomUUID(),
  });
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
  await rpcRows('tracker_append_log', {
    p_target_key: target,
    p_workflow: workflow,
    p_action: action,
    p_result: flags.result || null,
    p_link: flags.link || null,
    p_operation_id: randomUUID(),
  });
  process.stdout.write(`Logged "${action}" for ${target}.\n`);
}

async function cmdQueue(positionals, flags) {
  const [subcommand, key, ...extra] = positionals;
  if (extra.length) fail(EXIT.USAGE, `Unexpected queue argument: ${extra[0]}`);
  if (subcommand === 'list') {
    assertPositionals(positionals, 1, 1, 'usage: queue list [--status Pending|Merged|Rejected] [--json]');
    assertFlags(flags, ['status', 'json']);
    if (flags.status !== undefined) requiredFlag(flags, 'status', '--status requires a value.');
    const rows = await rpcRows('tracker_list_queue', { p_status: flags.status || null }, { paginate: true });
    const records = rows.map(queueFields);
    if (flags.json) process.stdout.write(`${JSON.stringify(records, null, 2)}\n`);
    else printQueue(records);
    return;
  }
  if (subcommand === 'enqueue') {
    const usage = 'usage: queue enqueue <key> --by <workflow> --target-data <text> [--linked-target <target-key>] [--notes <text>]';
    assertPositionals(positionals, 2, 2, usage);
    assertFlags(flags, ['by', 'target-data', 'linked-target', 'notes']);
    const by = requiredFlag(flags, 'by', usage);
    const targetData = requiredFlag(flags, 'target-data', usage);
    for (const name of ['linked-target', 'notes']) {
      if (flags[name] !== undefined) requiredFlag(flags, name, `--${name} requires a value.`);
    }
    await rpcRows('tracker_enqueue', {
      p_key: key,
      p_workflow: by,
      p_target_data: targetData,
      p_linked_target: flags['linked-target'] || null,
      p_notes: flags.notes || null,
    });
    process.stdout.write(`Queued ${key}.\n`);
    return;
  }
  if (subcommand === 'resolve') {
    const usage = 'usage: queue resolve <key> --by <workflow> --status Merged|Rejected [--linked-target <target-key>] [--duplicate-of <queue-key>] [--notes <text>]';
    assertPositionals(positionals, 2, 2, usage);
    assertFlags(flags, ['by', 'status', 'linked-target', 'duplicate-of', 'notes']);
    const by = requiredFlag(flags, 'by', usage);
    const status = requiredFlag(flags, 'status', usage);
    if (!['Merged', 'Rejected'].includes(status)) fail(EXIT.USAGE, '--status must be Merged or Rejected.');
    for (const name of ['linked-target', 'duplicate-of', 'notes']) {
      if (flags[name] !== undefined) requiredFlag(flags, name, `--${name} requires a value.`);
    }
    await rpcRows('tracker_resolve_queue', {
      p_key: key,
      p_workflow: by,
      p_status: status,
      p_linked_target: flags['linked-target'] || null,
      p_duplicate_of: flags['duplicate-of'] || null,
      p_notes: flags.notes || null,
    });
    process.stdout.write(`Resolved ${key} as ${status}.\n`);
    return;
  }
  fail(EXIT.USAGE, 'usage: queue list|enqueue|resolve ...');
}

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
    case 'queue': return cmdQueue(positionals, flags);
    default:
      process.stderr.write('Commands: list | get | claim | release | upsert | set-status | log | queue\n');
      process.exit(command ? EXIT.USAGE : EXIT.OK);
  }
}

main().catch((error) => fail(EXIT.ERROR, error?.stack || String(error)));
