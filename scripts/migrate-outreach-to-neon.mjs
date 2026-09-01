#!/usr/bin/env node

// One-shot Airtable export and Neon import utility. Node 18+ and psql only.

import {
  createHash,
  createPublicKey,
  generateKeyPairSync,
  randomUUID,
} from 'node:crypto';
import {
  chmodSync,
  closeSync,
  existsSync,
  fsyncSync,
  openSync,
  readFileSync,
  renameSync,
  statSync,
  unlinkSync,
  writeFileSync,
} from 'node:fs';
import { homedir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { spawnSync } from 'node:child_process';
import { setTimeout as sleep } from 'node:timers/promises';
import { fileURLToPath } from 'node:url';
import { retryAfterDelay } from './retry-after.mjs';

const ROOT = fileURLToPath(new URL('..', import.meta.url));
const FORMAT = 'codex-profiles-airtable-snapshot-v1';
const DEFAULT_BASE = 'appcezSUhDxz7uaQW';
const DEFAULT_KEY_FILE = join(homedir(), '.codex-outreach-neon-private.pem');
const DEFAULT_JWKS_FILE = join(ROOT, 'docs', 'outreach-jwks.json');
const TABLES = {
  targets: { id: 'tblHOr51tpYHiaYWQ', name: 'Targets' },
  logEvents: { id: 'tbloEavouTn5Z7fOw', name: 'Log' },
  bots: { id: 'tbl9kfzSOr39zRo0e', name: 'Bots' },
  mergeQueue: { id: 'tblsPk05Ts4VlwXEo', name: 'Merge Queue' },
  claims: { id: 'tbleL9s7CGUpxJDY7', name: 'Claims' },
};
const RETRY_STATUSES = new Set([429, 502, 503, 504]);
const secrets = new Set();

function fail(message, code = 1) {
  let safe = String(message);
  for (const secret of secrets) if (secret) safe = safe.split(secret).join('[REDACTED]');
  process.stderr.write(`${safe}\n`);
  process.exit(code);
}

function usage(code = 0) {
  const text = `Usage:
  node scripts/migrate-outreach-to-neon.mjs keygen [--key-file PATH] [--jwks-out PATH] [--force]
  node scripts/migrate-outreach-to-neon.mjs export --out SNAPSHOT [--force]
  node scripts/migrate-outreach-to-neon.mjs import --in SNAPSHOT
  node scripts/migrate-outreach-to-neon.mjs sync --in SNAPSHOT --against BASELINE
  node scripts/migrate-outreach-to-neon.mjs verify --in SNAPSHOT [--against BASELINE]

Environment:
  AIRTABLE_TOKEN or AIRTABLE_TOKEN_FILE (export only)
  AIRTABLE_BASE (export only; defaults to the outreach base)
  NEON_DATABASE_URL (import, sync, and verify)
`;
  (code ? process.stderr : process.stdout).write(text);
  process.exit(code);
}

function parseArgs(argv) {
  const [mode, ...rest] = argv;
  const options = {};
  for (let i = 0; i < rest.length; i++) {
    const arg = rest[i];
    if (!arg.startsWith('--')) fail(`Unexpected argument: ${arg}`, 2);
    const equals = arg.indexOf('=');
    const name = arg.slice(2, equals === -1 ? undefined : equals);
    if (equals !== -1) options[name] = arg.slice(equals + 1);
    else if (name === 'force') options[name] = true;
    else if (rest[i + 1] && !rest[i + 1].startsWith('--')) options[name] = rest[++i];
    else fail(`--${name} requires a value.`, 2);
  }
  return { mode, options };
}

function onlyOptions(options, allowed) {
  for (const name of Object.keys(options)) {
    if (!allowed.includes(name)) fail(`Unknown option: --${name}`, 2);
  }
}

function required(options, name) {
  if (!options[name] || options[name] === true) fail(`--${name} is required.`, 2);
  return resolve(options[name]);
}

function canonical(value) {
  if (Array.isArray(value)) return `[${value.map(canonical).join(',')}]`;
  if (value && typeof value === 'object') {
    return `{${Object.keys(value).sort().map((key) =>
      `${JSON.stringify(key)}:${canonical(value[key])}`).join(',')}}`;
  }
  return JSON.stringify(value);
}

function digest(snapshot) {
  const unsigned = { ...snapshot };
  delete unsigned.sha256;
  return createHash('sha256').update(canonical(unsigned)).digest('hex');
}

function atomicWrite(path, contents, { force = false, mode = 0o600 } = {}) {
  if (!force && existsSync(path)) fail(`Refusing to overwrite ${path}; pass --force explicitly.`);
  const temporary = join(dirname(path), `.${path.split('/').at(-1)}.${process.pid}.${randomUUID()}.tmp`);
  let fd;
  try {
    fd = openSync(temporary, 'wx', mode);
    writeFileSync(fd, contents);
    fsyncSync(fd);
    closeSync(fd);
    fd = undefined;
    renameSync(temporary, path);
    chmodSync(path, mode);
  } catch (error) {
    if (fd !== undefined) closeSync(fd);
    if (existsSync(temporary)) unlinkSync(temporary);
    fail(`Could not write ${path}: ${error.message}`);
  }
}

function secureFile(path, label) {
  let info;
  try {
    info = statSync(path);
  } catch (error) {
    fail(`Cannot read ${label} ${path}: ${error.message}`);
  }
  if (!info.isFile() || (info.mode & 0o077) !== 0) {
    fail(`${label} must be a regular mode-0600 file: ${path}`);
  }
}

function readSnapshot(path) {
  secureFile(path, 'Snapshot');
  let snapshot;
  try {
    snapshot = JSON.parse(readFileSync(path, 'utf8'));
  } catch (error) {
    fail(`Invalid snapshot JSON in ${path}: ${error.message}`);
  }
  if (snapshot.format !== FORMAT || !/^[0-9a-f]{64}$/.test(snapshot.sha256 || '')) {
    fail(`Invalid snapshot envelope in ${path}.`);
  }
  const actual = digest(snapshot);
  if (actual !== snapshot.sha256) fail(`Snapshot SHA-256 mismatch in ${path}.`);
  return snapshot;
}

function token() {
  let value = process.env.AIRTABLE_TOKEN?.trim();
  if (!value) {
    const path = process.env.AIRTABLE_TOKEN_FILE
      || join(homedir(), '.codex-outreach-airtable-token');
    try {
      value = readFileSync(path, 'utf8').trim();
    } catch {
      fail(`No Airtable token: set AIRTABLE_TOKEN or create ${path}.`, 2);
    }
  }
  secrets.add(value);
  return value;
}

function retryDelay() {
  const value = Number(process.env.AIRTABLE_RETRY_DELAY_MS || 1000);
  if (!Number.isSafeInteger(value) || value < 0) fail('AIRTABLE_RETRY_DELAY_MS must be a non-negative integer.', 2);
  return value;
}

async function airtableGet(url, airtableToken) {
  for (let attempt = 0; attempt < 3; attempt++) {
    try {
      const response = await fetch(url, {
        headers: { Authorization: `Bearer ${airtableToken}` },
      });
      const text = await response.text();
      if (response.ok) return text ? JSON.parse(text) : {};
      if (!RETRY_STATUSES.has(response.status) || attempt === 2) {
        fail(`Airtable GET -> ${response.status}: ${text}`);
      }
      await sleep(retryAfterDelay(
        response.headers.get('retry-after'),
        retryDelay() * 2 ** attempt,
      ));
    } catch (error) {
      if (attempt === 2) fail(`Airtable GET failed: ${error.message}`);
      await sleep(retryDelay() * 2 ** attempt);
    }
  }
}

async function exportTable(apiRoot, base, table, airtableToken) {
  const records = [];
  let offset;
  do {
    const params = new URLSearchParams({ pageSize: '100' });
    if (offset) params.set('offset', offset);
    const page = await airtableGet(
      `${apiRoot}/${encodeURIComponent(base)}/${encodeURIComponent(table.id)}?${params}`,
      airtableToken,
    );
    if (!Array.isArray(page.records)) fail(`Airtable returned no records array for ${table.name}.`);
    records.push(...page.records);
    offset = page.offset;
  } while (offset);
  records.sort((a, b) => String(a.id).localeCompare(String(b.id)));
  return records;
}

function values(record, field) {
  return Array.isArray(record.fields?.[field]) ? record.fields[field] : [];
}

function linkPairs(tables) {
  const targetByKey = new Map(tables.targets.records.map((record) => [record.fields?.Key, record.id]));
  const pairs = {
    logTargets: tables.logEvents.records.flatMap((record) =>
      values(record, 'Target').map((targetId) => ({ logId: record.id, targetId }))),
    targetBots: tables.targets.records.flatMap((record) =>
      values(record, 'Bots').map((botId) => ({ targetId: record.id, botId }))),
    queueProposers: tables.mergeQueue.records.flatMap((record) =>
      values(record, 'Proposed By').map((botId) => ({ queueId: record.id, botId }))),
    queueDuplicates: tables.mergeQueue.records.flatMap((record) =>
      values(record, 'Duplicate Of').map((duplicateOfId) => ({ queueId: record.id, duplicateOfId }))),
    queueTargets: tables.mergeQueue.records.flatMap((record) =>
      values(record, 'Linked Target').map((targetId) => ({ queueId: record.id, targetId }))),
    claimTargets: tables.claims.records.flatMap((record) => {
      const direct = values(record, 'Target');
      const lookedUpKey = Array.isArray(record.fields?.['Target Key'])
        ? record.fields['Target Key'][0] : record.fields?.['Target Key'];
      const targetIds = direct.length ? direct : [targetByKey.get(lookedUpKey)].filter(Boolean);
      return targetIds.map((targetId) => ({ claimId: record.id, targetId }));
    }),
  };
  for (const list of Object.values(pairs)) {
    list.sort((a, b) => canonical(a).localeCompare(canonical(b)));
  }
  return pairs;
}

async function exportSnapshot(path, force) {
  const airtableToken = token();
  const base = process.env.AIRTABLE_BASE || DEFAULT_BASE;
  const apiRoot = (process.env.AIRTABLE_API_ROOT || 'https://api.airtable.com/v0').replace(/\/$/, '');
  const metadata = await airtableGet(`${apiRoot}/meta/bases/${encodeURIComponent(base)}/tables`, airtableToken);
  if (!Array.isArray(metadata.tables)) fail('Airtable metadata response has no tables array.');

  const tables = {};
  for (const [key, expected] of Object.entries(TABLES)) {
    const schema = metadata.tables.find((table) => table.id === expected.id);
    if (!schema || schema.name !== expected.name) fail(`Airtable table ${expected.id} (${expected.name}) is missing.`);
    tables[key] = { id: schema.id, name: schema.name, records: await exportTable(apiRoot, base, expected, airtableToken) };
  }
  const links = linkPairs(tables);
  const recordCounts = Object.fromEntries(Object.entries(tables).map(([key, table]) => [key, table.records.length]));
  const totalRecords = Object.values(recordCounts).reduce((sum, count) => sum + count, 0);
  const exportedAt = new Date().toISOString();
  const activeClaims = tables.claims.records.filter((record) => {
    const expiresAt = Date.parse(record.fields?.['Expires At'] || '');
    return !record.fields?.['Released At'] && Number.isFinite(expiresAt)
      && expiresAt > Date.parse(exportedAt);
  }).length;
  const snapshot = {
    format: FORMAT,
    source: { service: 'airtable', baseId: base },
    exportedAt,
    schema: { tables: metadata.tables.filter((table) => Object.values(TABLES).some(({ id }) => id === table.id)) },
    tables,
    links,
    counts: {
      ...recordCounts,
      totalRecords,
      activeClaims,
      unlinkedLogs: tables.logEvents.records.length - new Set(links.logTargets.map(({ logId }) => logId)).size,
      relationships: Object.fromEntries(Object.entries(links).map(([key, list]) => [key, list.length])),
    },
  };
  snapshot.sha256 = digest(snapshot);
  atomicWrite(path, `${JSON.stringify(snapshot, null, 2)}\n`, { force });
  process.stdout.write(`Exported ${totalRecords} records to ${path} (${snapshot.sha256}).\n`);
}

function keygen(options) {
  onlyOptions(options, ['key-file', 'jwks-out', 'force']);
  const keyFile = resolve(options['key-file'] || DEFAULT_KEY_FILE);
  const jwksFile = resolve(options['jwks-out'] || DEFAULT_JWKS_FILE);
  const force = options.force === true;
  if (!force && (existsSync(keyFile) || existsSync(jwksFile))) {
    fail('Key output already exists; pass --force only for an intentional rotation.');
  }
  const { privateKey, publicKey } = generateKeyPairSync('rsa', {
    modulusLength: 3072,
    publicKeyEncoding: { type: 'spki', format: 'pem' },
    privateKeyEncoding: { type: 'pkcs8', format: 'pem' },
  });
  const jwk = createPublicKey(publicKey).export({ format: 'jwk' });
  const kid = createHash('sha256')
    .update(JSON.stringify({ e: jwk.e, kty: jwk.kty, n: jwk.n }))
    .digest('base64url');
  atomicWrite(keyFile, privateKey, { force, mode: 0o600 });
  atomicWrite(jwksFile, `${JSON.stringify({ keys: [{ ...jwk, kid, use: 'sig', alg: 'RS256' }] }, null, 2)}\n`, { force, mode: 0o644 });
  process.stdout.write(`Created 3072-bit signing key ${keyFile} and public JWKS ${jwksFile}.\n`);
}

function compareSnapshots(baseline, next) {
  if (Number(next.counts?.activeClaims || 0) !== 0) {
    fail(`Source still has ${next.counts.activeClaims} active claim(s); sync refused.`);
  }
  const changes = {};
  for (const key of Object.keys(TABLES)) {
    const before = new Map(baseline.tables[key].records.map((record) => [record.id, record]));
    const after = new Map(next.tables[key].records.map((record) => [record.id, record]));
    const deleted = [...before.keys()].filter((id) => !after.has(id));
    if (deleted.length) fail(`Source deletion detected in ${key}: ${deleted.slice(0, 5).join(', ')}`);
    changes[key] = {
      added: [...after.keys()].filter((id) => !before.has(id)).length,
      changed: [...after].filter(([id, record]) => before.has(id) && canonical(before.get(id)) !== canonical(record)).length,
    };
  }
  return changes;
}

function databaseConnection() {
  const value = process.env.NEON_DATABASE_URL;
  if (!value) fail('NEON_DATABASE_URL is required.', 2);
  secrets.add(value);
  const env = { ...process.env };
  delete env.NEON_DATABASE_URL;
  if (!value.includes('://')) {
    if (/\s|=/.test(value)) {
      fail('NEON_DATABASE_URL must be a PostgreSQL URL or a plain database name.', 2);
    }
    return { argument: value, env };
  }
  let parsed;
  try {
    parsed = new URL(value);
  } catch (error) {
    fail(`Invalid NEON_DATABASE_URL: ${error.message}`, 2);
  }
  if (!['postgres:', 'postgresql:'].includes(parsed.protocol)) {
    fail('NEON_DATABASE_URL must use postgres:// or postgresql://.', 2);
  }
  if (parsed.password) {
    let password;
    try {
      password = decodeURIComponent(parsed.password);
    } catch (error) {
      fail(`Invalid password encoding in NEON_DATABASE_URL: ${error.message}`, 2);
    }
    secrets.add(password);
    env.PGPASSWORD = password;
    parsed.password = '';
  }
  return { argument: parsed.toString(), env };
}

function psql(args, input) {
  const connection = databaseConnection();
  for (let attempt = 0; attempt < 3; attempt++) {
    const result = spawnSync('psql', ['-X', connection.argument, ...args], {
      cwd: ROOT,
      env: connection.env,
      input,
      encoding: 'utf8',
      maxBuffer: 128 * 1024 * 1024,
    });
    if (result.error?.code === 'EPIPE' && attempt < 2) continue;
    if (result.error) fail(`Could not run psql: ${result.error.message}`);
    if (result.status !== 0) fail(result.stderr || `psql exited ${result.status}.`);
    return result.stdout.trim();
  }
}

function snapshotSql(snapshot, functionCall) {
  const csv = `"${JSON.stringify(snapshot).replaceAll('"', '""')}"`;
  return `BEGIN;
CREATE TEMP TABLE outreach_snapshot_input (payload jsonb NOT NULL);
\\copy outreach_snapshot_input (payload) FROM STDIN WITH (FORMAT csv)
${csv}
\\.
SELECT ${functionCall} FROM outreach_snapshot_input;
COMMIT;
`;
}

function parseReport(output) {
  const line = output.split('\n').filter(Boolean).at(-1);
  try {
    return JSON.parse(line);
  } catch {
    fail(`Neon returned an invalid verification report: ${line || '(empty)'}`);
  }
}

function applySchema() {
  psql(['-q', '-v', 'ON_ERROR_STOP=1', '-f', join(ROOT, 'scripts', 'outreach-neon-schema.sql')]);
}

function importSnapshot(snapshot, sync) {
  applySchema();
  const output = psql(
    ['-qAt', '-v', 'ON_ERROR_STOP=1'],
    snapshotSql(snapshot, `outreach_private.import_airtable_snapshot(payload, ${sync ? 'true' : 'false'})::text`),
  );
  const report = parseReport(output);
  if (!report.ok) fail(`Neon verification failed: ${JSON.stringify(report)}`);
  process.stdout.write(`${sync ? 'Synced' : 'Imported'} ${snapshot.counts.totalRecords} records; verification passed.\n`);
}

function verifySnapshot(snapshot) {
  const output = psql(
    ['-qAt', '-v', 'ON_ERROR_STOP=1'],
    snapshotSql(snapshot, 'outreach_private.verify_airtable_snapshot(payload)::text'),
  );
  const report = parseReport(output);
  if (!report.ok) fail(`Neon verification failed: ${JSON.stringify(report)}`);
  process.stdout.write(`${JSON.stringify(report, null, 2)}\n`);
}

async function main() {
  const { mode, options } = parseArgs(process.argv.slice(2));
  if (!mode || mode === 'help' || options.help) usage(mode ? 0 : 2);
  if (mode === 'keygen') return keygen(options);
  if (mode === 'export') {
    onlyOptions(options, ['out', 'force']);
    return exportSnapshot(required(options, 'out'), options.force === true);
  }
  if (mode === 'import') {
    onlyOptions(options, ['in']);
    return importSnapshot(readSnapshot(required(options, 'in')), false);
  }
  if (mode === 'sync') {
    onlyOptions(options, ['in', 'against']);
    const baseline = readSnapshot(required(options, 'against'));
    const snapshot = readSnapshot(required(options, 'in'));
    const changes = compareSnapshots(baseline, snapshot);
    process.stdout.write(`Source delta: ${JSON.stringify(changes)}\n`);
    return importSnapshot(snapshot, true);
  }
  if (mode === 'verify') {
    onlyOptions(options, ['in', 'against']);
    const snapshot = readSnapshot(required(options, 'in'));
    if (options.against) compareSnapshots(readSnapshot(resolve(options.against)), snapshot);
    return verifySnapshot(snapshot);
  }
  usage(2);
}

main().catch((error) => fail(error?.stack || String(error)));
