#!/usr/bin/env node

import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { createHash, createPrivateKey } from 'node:crypto';
import {
  chmodSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  statSync,
  writeFileSync,
} from 'node:fs';
import { createServer } from 'node:http';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = fileURLToPath(new URL('../..', import.meta.url));
const SCRIPT = join(ROOT, 'scripts', 'migrate-outreach-to-neon.mjs');
const temporary = mkdtempSync(join(tmpdir(), 'outreach-neon-migration-'));
const snapshotPath = join(temporary, 'snapshot.json');
const secondPath = join(temporary, 'second.json');
const keyPath = join(temporary, 'private.pem');
const jwksPath = join(temporary, 'jwks.json');
const psqlArgumentsPath = join(temporary, 'psql-arguments');
const fakePsqlPath = join(temporary, 'psql');
const token = 'migration-test-secret';
const tableSchemas = [
  { id: 'tblHOr51tpYHiaYWQ', name: 'Targets', fields: [{ id: 'fldKey', name: 'Key', type: 'singleLineText' }] },
  { id: 'tbloEavouTn5Z7fOw', name: 'Log', fields: [{ id: 'fldTarget', name: 'Target', type: 'multipleRecordLinks' }] },
  { id: 'tbl9kfzSOr39zRo0e', name: 'Bots', fields: [] },
  { id: 'tblsPk05Ts4VlwXEo', name: 'Merge Queue', fields: [] },
  { id: 'tbleL9s7CGUpxJDY7', name: 'Claims', fields: [] },
];
const records = {
  tblHOr51tpYHiaYWQ: [
    { id: 'target-b', createdTime: '2026-01-01T00:00:01.000Z', fields: { Key: 'b', Name: 'quotes " slash \\ newline\nvalue', Bots: ['bot-1'] } },
    { id: 'target-a', createdTime: '2026-01-01T00:00:00.000Z', fields: { Key: 'a' } },
  ],
  tbloEavouTn5Z7fOw: [
    { id: 'log-1', createdTime: '2026-01-02T00:00:00.000Z', fields: { Target: ['target-a', 'target-b'] } },
    { id: 'log-2', createdTime: '2026-01-02T00:00:01.000Z', fields: {} },
  ],
  tbl9kfzSOr39zRo0e: [{ id: 'bot-1', createdTime: '2026-01-03T00:00:00.000Z', fields: { Name: 'bot' } }],
  tblsPk05Ts4VlwXEo: [{
    id: 'queue-1', createdTime: '2026-01-04T00:00:00.000Z',
    fields: { Key: 'q', 'Proposed By': ['bot-1'], 'Linked Target': ['target-a'] },
  }],
  tbleL9s7CGUpxJDY7: [{
    id: 'claim-1', createdTime: '2026-01-05T00:00:00.000Z',
    fields: { Target: ['target-a'], 'Target Key': ['a'] },
  }],
};
let rateLimitMetadata = true;
let leakToken = false;

function canonical(value) {
  if (Array.isArray(value)) return `[${value.map(canonical).join(',')}]`;
  if (value && typeof value === 'object') {
    return `{${Object.keys(value).sort().map((key) =>
      `${JSON.stringify(key)}:${canonical(value[key])}`).join(',')}}`;
  }
  return JSON.stringify(value);
}

function send(response, status, body, headers = {}) {
  response.writeHead(status, { 'content-type': 'application/json', ...headers });
  response.end(JSON.stringify(body));
}

const server = createServer((request, response) => {
  assert.equal(request.headers.authorization, `Bearer ${token}`);
  const url = new URL(request.url, 'http://localhost');
  if (leakToken) {
    leakToken = false;
    send(response, 500, { error: `failure includes ${token}` });
    return;
  }
  if (url.pathname.endsWith('/meta/bases/test-base/tables')) {
    if (rateLimitMetadata) {
      rateLimitMetadata = false;
      send(response, 429, { error: 'slow down' }, { 'retry-after': '0' });
      return;
    }
    send(response, 200, { tables: tableSchemas });
    return;
  }
  const table = url.pathname.split('/').at(-1);
  const tableRecords = records[table];
  if (!tableRecords) return send(response, 404, { error: 'unknown table' });
  const offset = url.searchParams.get('offset');
  if (tableRecords.length > 1 && !offset) {
    send(response, 200, { records: [tableRecords[0]], offset: 'next' });
  } else {
    send(response, 200, { records: tableRecords.length > 1 ? tableRecords.slice(1) : tableRecords });
  }
});

await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
const address = server.address();
const env = {
  ...process.env,
  AIRTABLE_TOKEN: token,
  AIRTABLE_BASE: 'test-base',
  AIRTABLE_API_ROOT: `http://127.0.0.1:${address.port}/v0`,
  AIRTABLE_RETRY_DELAY_MS: '1',
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
  const exported = await run(['export', '--out', snapshotPath]);
  assert.equal(exported.status, 0, exported.stderr);
  assert.equal(statSync(snapshotPath).mode & 0o777, 0o600);
  const snapshot = JSON.parse(readFileSync(snapshotPath, 'utf8'));
  assert.equal(snapshot.format, 'codex-profiles-airtable-snapshot-v1');
  assert.equal(snapshot.counts.totalRecords, 7);
  assert.equal(snapshot.counts.unlinkedLogs, 1);
  assert.equal(snapshot.counts.relationships.logTargets, 2);
  assert.equal(snapshot.tables.targets.records[0].id, 'target-a');
  assert.equal(snapshot.tables.targets.records[1].fields.Name, 'quotes " slash \\ newline\nvalue');
  assert.deepEqual(snapshot.links.claimTargets, [{ claimId: 'claim-1', targetId: 'target-a' }]);
  assert.equal(snapshot.schema.tables.find(({ id }) => id === 'tblHOr51tpYHiaYWQ').fields[0].name, 'Key');
  const unsigned = { ...snapshot };
  delete unsigned.sha256;
  assert.equal(snapshot.sha256, createHash('sha256').update(canonical(unsigned)).digest('hex'));

  const overwrite = await run(['export', '--out', snapshotPath]);
  assert.notEqual(overwrite.status, 0);
  assert.match(overwrite.stderr, /Refusing to overwrite/);

  const generated = await run(['keygen', '--key-file', keyPath, '--jwks-out', jwksPath]);
  assert.equal(generated.status, 0, generated.stderr);
  assert.equal(statSync(keyPath).mode & 0o777, 0o600);
  assert.equal(createPrivateKey(readFileSync(keyPath)).asymmetricKeyDetails.modulusLength, 3072);
  const jwks = JSON.parse(readFileSync(jwksPath, 'utf8'));
  assert.equal(jwks.keys[0].alg, 'RS256');
  for (const privateField of ['d', 'p', 'q', 'dp', 'dq', 'qi']) assert.equal(jwks.keys[0][privateField], undefined);

  chmodSync(snapshotPath, 0o644);
  const insecure = await run(['import', '--in', snapshotPath], { NEON_DATABASE_URL: 'unused' });
  assert.notEqual(insecure.status, 0);
  assert.match(insecure.stderr, /mode-0600/);
  chmodSync(snapshotPath, 0o600);

  writeFileSync(fakePsqlPath, `#!/bin/sh
printf '%s\\n' "$@" > "$PSQL_ARGS_FILE"
printf '%s\\n' '{"ok":true}'
`, { mode: 0o700 });
  const databaseUrl = 'postgresql://owner:secret@example.test/neondb?sslmode=require';
  const verified = await run(['verify', '--in', snapshotPath], {
    NEON_DATABASE_URL: databaseUrl,
    PATH: `${temporary}:${process.env.PATH}`,
    PSQL_ARGS_FILE: psqlArgumentsPath,
  });
  assert.equal(verified.status, 0, verified.stderr);
  assert.ok(readFileSync(psqlArgumentsPath, 'utf8').split('\n').includes(databaseUrl));

  const tampered = JSON.parse(readFileSync(snapshotPath, 'utf8'));
  tampered.tables.targets.records[0].fields.Key = 'tampered';
  writeFileSync(secondPath, JSON.stringify(tampered), { mode: 0o600 });
  const invalidDigest = await run(['import', '--in', secondPath], { NEON_DATABASE_URL: 'unused' });
  assert.notEqual(invalidDigest.status, 0);
  assert.match(invalidDigest.stderr, /SHA-256 mismatch/);

  leakToken = true;
  const leaked = await run(['export', '--out', secondPath, '--force']);
  assert.notEqual(leaked.status, 0);
  assert.doesNotMatch(leaked.stderr, new RegExp(token));
  assert.match(leaked.stderr, /\[REDACTED\]/);
} finally {
  await new Promise((resolve) => server.close(resolve));
  rmSync(temporary, { recursive: true, force: true });
}
