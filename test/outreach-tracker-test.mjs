#!/usr/bin/env node

import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { createServer } from 'node:http';
import { setTimeout as sleep } from 'node:timers/promises';

const ROOT = new URL('..', import.meta.url).pathname;
const SCRIPT = `${ROOT}scripts/outreach-tracker.mjs`;
const TABLES = {
  targets: 'tblTargets',
  log: 'tblLog',
  claims: 'tblClaims',
};

let nextId = 1;
let createdTick = Date.now();
const records = new Map([
  [TABLES.targets, [
    makeRecord({ Key: 'alpha', Name: 'Alpha', Status: 'Backlog', Priority: 'P0' }),
    makeRecord({ Key: 'quote"slash\\key', Name: 'Escaped key', Status: 'Deferred' }),
  ]],
  [TABLES.log, []],
  [TABLES.claims, []],
]);
let failNext;
let rateLimitNext = false;
let rateLimitRequests = 0;

function makeRecord(fields) {
  return {
    id: `rec${nextId++}`,
    createdTime: new Date(createdTick++).toISOString(),
    fields: { ...fields },
  };
}

function formulaValue(raw) {
  return raw.replace(/\\(["\\])/g, '$1');
}

function matchesFormula(record, formula) {
  if (!formula) return true;
  const comparisons = [...formula.matchAll(/\{([^}]+)\}="((?:\\.|[^"\\])*)"/g)];
  return comparisons.every(([, field, raw]) => String(record.fields[field] ?? '') === formulaValue(raw));
}

async function readJson(request) {
  const chunks = [];
  for await (const chunk of request) chunks.push(chunk);
  return chunks.length ? JSON.parse(Buffer.concat(chunks).toString('utf8')) : {};
}

function send(response, status, body) {
  response.writeHead(status, { 'content-type': 'application/json' });
  response.end(JSON.stringify(body));
}

const server = createServer(async (request, response) => {
  const url = new URL(request.url, 'http://localhost');
  const [, apiVersion, base, table, recordId] = url.pathname.split('/');
  assert.equal(apiVersion, 'v0');
  assert.equal(base, 'test-base');

  if (failNext) {
    const failure = failNext;
    failNext = undefined;
    send(response, failure.status, { error: failure.message });
    return;
  }
  if (rateLimitNext) {
    rateLimitNext = false;
    rateLimitRequests++;
    send(response, 429, { error: 'rate limited' });
    return;
  }

  const tableRecords = records.get(table);
  if (!tableRecords) {
    send(response, 404, { error: 'unknown table' });
    return;
  }

  if (request.method === 'GET') {
    rateLimitRequests++;
    const filtered = tableRecords.filter((record) => matchesFormula(record, url.searchParams.get('filterByFormula')));
    const offset = url.searchParams.get('offset');
    const page = offset ? filtered.slice(1) : filtered.slice(0, 1);
    send(response, 200, {
      records: page,
      ...(filtered.length > 1 && !offset ? { offset: 'page-2' } : {}),
    });
    return;
  }

  if (request.method === 'POST') {
    const body = await readJson(request);
    const created = body.records.map(({ fields }) => makeRecord(fields));
    tableRecords.push(...created);
    send(response, 200, { records: created });
    return;
  }

  if (request.method === 'PATCH') {
    const body = await readJson(request);
    const updated = [];
    for (const item of body.records ?? [{ id: recordId, fields: body.fields }]) {
      let record = item.id ? tableRecords.find((candidate) => candidate.id === item.id) : undefined;
      if (!record && body.performUpsert) {
        record = tableRecords.find((candidate) =>
          body.performUpsert.fieldsToMergeOn.every((field) => candidate.fields[field] === item.fields[field]));
      }
      if (!record) {
        record = makeRecord(item.fields);
        tableRecords.push(record);
      } else {
        Object.assign(record.fields, item.fields);
      }
      updated.push(record);
    }
    send(response, 200, { records: updated });
    return;
  }

  send(response, 405, { error: 'method not allowed' });
});

await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
const address = server.address();
const env = {
  ...process.env,
  AIRTABLE_TOKEN: 'test-secret-token',
  AIRTABLE_BASE: 'test-base',
  AIRTABLE_API_ROOT: `http://127.0.0.1:${address.port}/v0`,
  AIRTABLE_TARGETS_TABLE: TABLES.targets,
  AIRTABLE_LOG_TABLE: TABLES.log,
  AIRTABLE_CLAIMS_TABLE: TABLES.claims,
  OUTREACH_CLAIM_TTL_MS: '800',
  OUTREACH_CLAIM_SETTLE_MS: '30',
  OUTREACH_RETRY_DELAY_MS: '1',
};

function run(args) {
  return new Promise((resolve, reject) => {
    const child = spawn(process.execPath, [SCRIPT, ...args], { cwd: ROOT, env });
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
  assert.equal(records.get(TABLES.targets).filter(({ fields }) => fields.Key === 'beta').length, 1);

  const invalidDate = await run(['upsert', 'beta', '--last-checked', '2026-99-99']);
  assert.equal(invalidDate.status, 2);
  assert.match(invalidDate.stderr, /YYYY-MM-DD/);
  const unknownOption = await run(['get', 'alpha', '--bogus']);
  assert.equal(unknownOption.status, 2);
  assert.match(unknownOption.stderr, /Unknown option: --bogus/);

  const logged = await run(['log', '--target', 'alpha', '--workflow', 'test-run', '--action', 'Rechecked', '--result', 'Still open']);
  assert.equal(logged.status, 0, logged.stderr);
  assert.deepEqual(records.get(TABLES.log).at(-1).fields.Target, [records.get(TABLES.targets)[0].id]);

  rateLimitRequests = 0;
  rateLimitNext = true;
  const retried = await run(['get', 'alpha', '--json']);
  assert.equal(retried.status, 0, retried.stderr);
  assert.ok(rateLimitRequests >= 2, `expected a retry, got ${rateLimitRequests} request(s)`);

  failNext = { status: 500, message: 'deliberate server failure' };
  const failed = await run(['get', 'alpha']);
  assert.equal(failed.status, 1);
  assert.match(failed.stderr, /500.*deliberate server failure/);
  assert.doesNotMatch(failed.stderr, /test-secret-token/);

  const contenders = await Promise.all([
    run(['claim', 'alpha', '--by', 'run-a']),
    run(['claim', 'alpha', '--by', 'run-b']),
  ]);
  assert.deepEqual(contenders.map(({ status }) => status).sort(), [0, 3]);
  const winner = contenders[0].status === 0 ? 'run-a' : 'run-b';

  const nonOwnerRelease = await run(['release', 'alpha', '--by', 'run-c']);
  assert.equal(nonOwnerRelease.status, 3);
  const blocked = await run(['claim', 'alpha', '--by', 'run-c']);
  assert.equal(blocked.status, 3);

  const released = await run(['release', 'alpha', '--by', winner]);
  assert.equal(released.status, 0, released.stderr);
  const releasedAgain = await run(['release', 'alpha', '--by', winner]);
  assert.equal(releasedAgain.status, 0, releasedAgain.stderr);

  const reclaimed = await run(['claim', 'alpha', '--by', 'run-c']);
  assert.equal(reclaimed.status, 0, reclaimed.stderr);
  await sleep(850);
  const afterExpiry = await run(['claim', 'alpha', '--by', 'run-d']);
  assert.equal(afterExpiry.status, 0, afterExpiry.stderr);

  const staleRelease = await run(['release', 'alpha', '--by', 'run-c']);
  assert.equal(staleRelease.status, 0, staleRelease.stderr);
  const stillBlocked = await run(['claim', 'alpha', '--by', 'run-e']);
  assert.equal(stillBlocked.status, 3);
} finally {
  server.close();
}
