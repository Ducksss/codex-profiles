#!/usr/bin/env node

import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { generateKeyPairSync, verify } from 'node:crypto';
import { chmodSync, mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { createServer } from 'node:http';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { setTimeout as sleep } from 'node:timers/promises';
import { fileURLToPath } from 'node:url';

const ROOT = fileURLToPath(new URL('../..', import.meta.url));
const SCRIPT = join(ROOT, 'scripts', 'outreach-tracker.mjs');
const temporary = mkdtempSync(join(tmpdir(), 'outreach-neon-tracker-'));
const keyFile = join(temporary, 'private.pem');
const badKeyFile = join(temporary, 'bad-private.pem');
const { privateKey, publicKey } = generateKeyPairSync('rsa', {
  modulusLength: 2048,
  publicKeyEncoding: { type: 'spki', format: 'pem' },
  privateKeyEncoding: { type: 'pkcs8', format: 'pem' },
});
writeFileSync(keyFile, privateKey, { mode: 0o600 });
writeFileSync(badKeyFile, privateKey, { mode: 0o644 });
chmodSync(badKeyFile, 0o644);

const targets = new Map([
  ['alpha', { key: 'alpha', name: 'Alpha', status: 'Backlog', priority: 'P0', owned: false }],
  ['quote"slash\\key', { key: 'quote"slash\\key', name: 'Escaped key', status: 'Deferred', owned: false }],
]);
const logs = new Map();
const claims = [];
const queue = new Map();
let nextLogId = 1;
let failNext;
let failAfterNext;
let requests = 0;

function decodeJson(segment) {
  return JSON.parse(Buffer.from(segment, 'base64url').toString('utf8'));
}

function authenticate(request) {
  const authorization = request.headers.authorization || '';
  assert.match(authorization, /^Bearer /);
  const token = authorization.slice(7);
  const parts = token.split('.');
  assert.equal(parts.length, 3);
  const header = decodeJson(parts[0]);
  const payload = decodeJson(parts[1]);
  assert.equal(header.alg, 'RS256');
  assert.equal(header.typ, 'JWT');
  assert.ok(header.kid);
  assert.equal(payload.aud, 'codex-profiles-outreach');
  assert.equal(payload.sub, 'codex-profiles-outreach-agent');
  assert.equal(payload.role, 'outreach_tracker');
  assert.ok(payload.exp > Math.floor(Date.now() / 1000));
  assert.ok(payload.exp <= Math.floor(Date.now() / 1000) + 301);
  assert.ok(verify(
    'RSA-SHA256',
    Buffer.from(`${parts[0]}.${parts[1]}`),
    publicKey,
    Buffer.from(parts[2], 'base64url'),
  ));
  return token;
}

async function readJson(request) {
  const chunks = [];
  for await (const chunk of request) chunks.push(chunk);
  return chunks.length ? JSON.parse(Buffer.concat(chunks).toString('utf8')) : {};
}

function appendLog(operationId, values) {
  if (!logs.has(operationId)) logs.set(operationId, { log_id: nextLogId++, ...values });
  return logs.get(operationId);
}

function handleRpc(name, body) {
  const now = Date.now();
  if (name === 'tracker_list_targets') {
    return [...targets.values()].filter((target) =>
      (!body.p_status || target.status === body.p_status)
      && (!body.p_priority || target.priority === body.p_priority)
      && (!body.p_channel || target.channel === body.p_channel)
      && (body.p_owned === null || body.p_owned === undefined || target.owned === body.p_owned))
      .sort((a, b) => a.key.localeCompare(b.key));
  }
  if (name === 'tracker_get_target') return targets.has(body.p_key) ? [targets.get(body.p_key)] : [];
  if (name === 'tracker_upsert_target') {
    const patch = body.p_patch;
    const map = {
      Name: 'name', Channel: 'channel', Status: 'status', Priority: 'priority',
      Link: 'link', 'Owned?': 'owned', 'Last Version Told': 'last_version_told',
      'Last Checked': 'last_checked', 'Next Action': 'next_action', Notes: 'notes',
    };
    const target = targets.get(body.p_key) || { key: body.p_key, owned: false };
    for (const [field, column] of Object.entries(map)) if (field in patch) target[column] = patch[field];
    targets.set(body.p_key, target);
    return [target];
  }
  if (name === 'tracker_append_log') {
    return [appendLog(body.p_operation_id, body)];
  }
  if (name === 'tracker_set_status') {
    const target = targets.get(body.p_key) || { key: body.p_key, owned: false };
    target.status = body.p_status;
    targets.set(body.p_key, target);
    appendLog(body.p_operation_id, body);
    return [target];
  }
  if (name === 'tracker_claim') {
    if (!targets.has(body.p_key)) throw Object.assign(new Error('target missing'), { status: 404 });
    const active = claims.filter((claim) =>
      claim.target === body.p_key && !claim.released && claim.expires > now);
    const owned = active.find((claim) => claim.workflow === body.p_workflow);
    if (owned) return [{ outcome: 'owned', claim_key: owned.key, holder: owned.workflow }];
    if (active.length) return [{ outcome: 'lost', claim_key: active[0].key, holder: active[0].workflow }];
    const claim = {
      key: `${body.p_key}:${body.p_workflow}:${claims.length + 1}`,
      target: body.p_key,
      workflow: body.p_workflow,
      expires: now + body.p_ttl_ms,
      released: false,
    };
    claims.push(claim);
    appendLog(body.p_operation_id, body);
    return [{ outcome: 'claimed', claim_key: claim.key, holder: claim.workflow }];
  }
  if (name === 'tracker_release') {
    const owned = claims.filter((claim) => claim.target === body.p_key && claim.workflow === body.p_workflow);
    if (!owned.length) return [{ outcome: 'never', released_count: 0 }];
    const active = owned.filter((claim) => !claim.released && claim.expires > now);
    if (!active.length) return [{ outcome: 'inactive', released_count: 0 }];
    for (const claim of active) claim.released = true;
    appendLog(body.p_operation_id, body);
    return [{ outcome: 'released', released_count: active.length }];
  }
  if (name === 'tracker_list_queue') {
    return [...queue.values()].filter((item) => !body.p_status || item.status === body.p_status);
  }
  if (name === 'tracker_enqueue') {
    if (body.p_linked_target && !targets.has(body.p_linked_target)) {
      throw Object.assign(new Error('target missing'), { status: 404 });
    }
    const item = queue.get(body.p_key) || { key: body.p_key, proposed_at: new Date().toISOString() };
    Object.assign(item, {
      proposed_by_workflow: body.p_workflow,
      target_data: body.p_target_data,
      status: item.status || 'Pending',
      notes: body.p_notes || item.notes,
    });
    queue.set(body.p_key, item);
    return [item];
  }
  if (name === 'tracker_resolve_queue') {
    const item = queue.get(body.p_key);
    if (!item) throw Object.assign(new Error('queue item missing'), { status: 404 });
    Object.assign(item, {
      status: body.p_status,
      notes: body.p_notes || item.notes,
      resolved_at: new Date().toISOString(),
      resolved_by_workflow: body.p_workflow,
    });
    return [item];
  }
  throw Object.assign(new Error(`unknown RPC ${name}`), { status: 404 });
}

function send(response, status, body, headers = {}) {
  response.writeHead(status, { 'content-type': 'application/json', ...headers });
  response.end(JSON.stringify(body));
}

const server = createServer(async (request, response) => {
  requests++;
  const token = authenticate(request);
  const name = new URL(request.url, 'http://localhost').pathname.split('/').at(-1);
  const body = await readJson(request);
  if (failNext) {
    const failure = failNext;
    failNext = undefined;
    send(response, failure.status, { error: failure.includeToken ? token : failure.message }, failure.headers);
    return;
  }
  let result;
  try {
    result = handleRpc(name, body);
  } catch (error) {
    send(response, error.status || 500, { error: error.message });
    return;
  }
  if (failAfterNext === name) {
    failAfterNext = undefined;
    send(response, 503, { error: 'response lost after commit' });
    return;
  }
  const range = request.headers.range?.match(/^(\d+)-(\d+)$/);
  if (range && Array.isArray(result)) {
    const start = Number(range[1]);
    const end = Math.min(Number(range[2]), result.length - 1);
    send(response, 200, result.slice(start, end + 1), {
      'content-range': result.length ? `${start}-${end}/${result.length}` : '*/0',
    });
    return;
  }
  send(response, 200, result);
});

await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
const address = server.address();
const CLAIM_TTL_MS = 500;
const env = {
  ...process.env,
  NEON_DATA_API_URL: `http://127.0.0.1:${address.port}/rest/v1`,
  NEON_JWT_KEY_FILE: keyFile,
  OUTREACH_CLAIM_TTL_MS: String(CLAIM_TTL_MS),
  OUTREACH_RETRY_DELAY_MS: '1',
};

function run(args, overrides = {}) {
  return new Promise((resolve, reject) => {
    const child = spawn(process.execPath, [SCRIPT, ...args], {
      cwd: ROOT,
      env: { ...env, ...overrides },
    });
    let stdout = '';
    let stderr = '';
    child.stdout.on('data', (chunk) => { stdout += chunk; });
    child.stderr.on('data', (chunk) => { stderr += chunk; });
    child.on('error', reject);
    child.on('close', (status) => resolve({ status, stdout, stderr }));
  });
}

try {
  const listed = await run(['list', '--json']);
  assert.equal(listed.status, 0, listed.stderr);
  assert.deepEqual(JSON.parse(listed.stdout).map(({ Key }) => Key), ['alpha', 'quote"slash\\key']);

  const escaped = await run(['get', 'quote"slash\\key', '--json']);
  assert.equal(escaped.status, 0, escaped.stderr);
  assert.equal(JSON.parse(escaped.stdout).Name, 'Escaped key');

  const upserted = await run(['upsert', 'beta', '--name', 'Beta', '--status', 'Backlog', '--last-checked', '2026-07-13']);
  assert.equal(upserted.status, 0, upserted.stderr);
  assert.equal(targets.get('beta').last_checked, '2026-07-13');

  for (const [args, pattern] of [
    [['upsert', 'beta', '--last-checked', '2026-02-30'], /YYYY-MM-DD/],
    [['get', 'alpha', '--bogus'], /Unknown option/],
    [['upsert', 'beta', '--name'], /requires a value/],
    [['list', '--status'], /requires a value/],
    [['log', '--target', 'alpha', '--action', 'Rechecked'], /--workflow/],
    [['queue', 'resolve', 'x', '--by', 'test', '--status', 'Pending'], /Merged or Rejected/],
  ]) {
    const invalid = await run(args);
    assert.equal(invalid.status, 2);
    assert.match(invalid.stderr, pattern);
  }

  const beforeLog = logs.size;
  failAfterNext = 'tracker_append_log';
  const logged = await run(['log', '--target', 'alpha', '--workflow', 'test-run', '--action', 'Rechecked', '--result', 'Still open']);
  assert.equal(logged.status, 0, logged.stderr);
  assert.equal(logs.size, beforeLog + 1, 'retry duplicated a log mutation');

  requests = 0;
  failNext = { status: 429, message: 'rate limited', headers: { 'retry-after': '0' } };
  const retried = await run(['get', 'alpha', '--json']);
  assert.equal(retried.status, 0, retried.stderr);
  assert.ok(requests >= 2);

  failNext = { status: 500, includeToken: true };
  const failed = await run(['get', 'alpha']);
  assert.equal(failed.status, 1);
  assert.doesNotMatch(failed.stderr, /eyJ/);
  assert.match(failed.stderr, /\[REDACTED\]/);

  const insecure = await run(['get', 'alpha'], { NEON_JWT_KEY_FILE: badKeyFile });
  assert.equal(insecure.status, 2);
  assert.match(insecure.stderr, /mode 0600/);

  const contenders = await Promise.all([
    run(['claim', 'alpha', '--by', 'run-a']),
    run(['claim', 'alpha', '--by', 'run-b']),
  ]);
  assert.deepEqual(contenders.map(({ status }) => status).sort(), [0, 3]);
  const winner = contenders[0].status === 0 ? 'run-a' : 'run-b';

  assert.equal((await run(['release', 'alpha', '--by', 'run-c'])).status, 3);
  assert.equal((await run(['claim', 'alpha', '--by', 'run-c'])).status, 3);
  assert.equal((await run(['release', 'alpha', '--by', winner])).status, 0);
  assert.equal((await run(['release', 'alpha', '--by', winner])).status, 0);

  assert.equal((await run(['claim', 'alpha', '--by', 'run-c'])).status, 0);
  await sleep(CLAIM_TTL_MS + 100);
  assert.equal((await run(['claim', 'alpha', '--by', 'run-d'])).status, 0);
  assert.equal((await run(['release', 'alpha', '--by', 'run-c'])).status, 0);
  assert.equal((await run(['claim', 'alpha', '--by', 'run-e'])).status, 3);

  const enqueued = await run(['queue', 'enqueue', 'candidate-1', '--by', 'lead-gen', '--target-data', 'quotes " and \\ and\nlines', '--linked-target', 'alpha']);
  assert.equal(enqueued.status, 0, enqueued.stderr);
  const pending = await run(['queue', 'list', '--status', 'Pending', '--json']);
  assert.equal(pending.status, 0, pending.stderr);
  assert.equal(JSON.parse(pending.stdout)[0]['Target Data'], 'quotes " and \\ and\nlines');
  const resolved = await run(['queue', 'resolve', 'candidate-1', '--by', 'review', '--status', 'Merged', '--linked-target', 'alpha', '--notes', 'done']);
  assert.equal(resolved.status, 0, resolved.stderr);
  assert.equal(queue.get('candidate-1').status, 'Merged');
} finally {
  await new Promise((resolve) => server.close(resolve));
  rmSync(temporary, { recursive: true, force: true });
}
