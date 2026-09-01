#!/usr/bin/env node

import assert from 'node:assert/strict';
import { spawn, spawnSync } from 'node:child_process';
import { createHash, randomUUID } from 'node:crypto';
import { chmodSync, mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { setTimeout as sleep } from 'node:timers/promises';
import { fileURLToPath } from 'node:url';

const ROOT = fileURLToPath(new URL('../..', import.meta.url));
const MIGRATION = join(ROOT, 'scripts', 'migrate-outreach-to-neon.mjs');
const requiredCommands = ['initdb', 'pg_ctl', 'psql'];
if (requiredCommands.some((command) => spawnSync(command, ['--version']).error?.code === 'ENOENT')) {
  process.stdout.write('skip: PostgreSQL tools are not installed\n');
  process.exit(0);
}

const temporary = mkdtempSync(join(tmpdir(), 'outreach-neon-schema-'));
const data = join(temporary, 'data');
const socket = join(temporary, 'socket');
const serverLog = join(temporary, 'postgres.log');
const snapshotPath = join(temporary, 'snapshot.json');
const badSnapshotPath = join(temporary, 'bad-snapshot.json');
const deletedSnapshotPath = join(temporary, 'deleted-snapshot.json');
const port = 49152 + (process.pid % 10000);
const pgEnv = {
  ...process.env,
  PGHOST: socket,
  PGPORT: String(port),
  PGUSER: 'postgres',
  PGDATABASE: 'neondb',
};
const migrationEnv = { ...pgEnv, NEON_DATABASE_URL: 'neondb' };

function canonical(value) {
  if (Array.isArray(value)) return `[${value.map(canonical).join(',')}]`;
  if (value && typeof value === 'object') {
    return `{${Object.keys(value).sort().map((key) =>
      `${JSON.stringify(key)}:${canonical(value[key])}`).join(',')}}`;
  }
  return JSON.stringify(value);
}

function signSnapshot(snapshot) {
  const signed = structuredClone(snapshot);
  delete signed.sha256;
  signed.sha256 = createHash('sha256').update(canonical(signed)).digest('hex');
  return signed;
}

function writeSnapshot(path, snapshot) {
  writeFileSync(path, `${JSON.stringify(signSnapshot(snapshot), null, 2)}\n`, { mode: 0o600 });
  chmodSync(path, 0o600);
}

function run(command, args, options = {}) {
  return spawnSync(command, args, {
    cwd: ROOT,
    env: options.env || pgEnv,
    encoding: 'utf8',
    maxBuffer: 128 * 1024 * 1024,
  });
}

function mustRun(command, args, options) {
  const result = run(command, args, options);
  assert.equal(result.status, 0, `${command} ${args.join(' ')}\n${result.stdout}\n${result.stderr}`);
  return result.stdout.trim();
}

function psqlArgs(statement, tuples = true) {
  const args = ['-X', '-v', 'ON_ERROR_STOP=1'];
  if (tuples) args.push('-qAt');
  for (const part of [statement].flat()) args.push('-c', part);
  return args;
}

function sql(statement, { tuples = true } = {}) {
  return mustRun('psql', psqlArgs(statement, tuples));
}

function sqlAsync(statement) {
  return new Promise((resolve, reject) => {
    const child = spawn('psql', psqlArgs(statement), {
      cwd: ROOT,
      env: pgEnv,
    });
    let stdout = '';
    let stderr = '';
    child.stdout.on('data', (chunk) => { stdout += chunk; });
    child.stderr.on('data', (chunk) => { stderr += chunk; });
    child.on('error', reject);
    child.on('close', (status) => resolve({ status, stdout: stdout.trim(), stderr }));
  });
}

function trackerTransaction(statement, subject = 'codex-profiles-outreach-agent') {
  return [
    'BEGIN',
    'SET LOCAL ROLE outreach_tracker',
    `SET LOCAL request.jwt.claim.sub = '${subject}'`,
    statement,
    'COMMIT',
  ];
}

const records = {
  targets: [
    {
      id: 'recTarget1', createdTime: '2026-01-01T00:00:00.000Z',
      fields: {
        Key: 'dead-target', Name: 'Quotes " backslash \\ and\nmultiple lines',
        Status: 'Dead', Priority: 'P0', Channel: 'Directory', Bots: ['recBot1'],
      },
    },
    { id: 'recTarget2', createdTime: '2026-01-01T00:00:01.000Z', fields: { Key: 'minimal-target' } },
  ],
  logEvents: [
    {
      id: 'recLog1', createdTime: '2026-01-02T00:00:00.000Z',
      fields: {
        Event: 'Rechecked — two targets', Timestamp: '2026-01-02T00:00:00.000Z',
        Workflow: 'fixture', Action: 'Rechecked', Result: 'line 1\nline 2',
        Target: ['recTarget1', 'recTarget2'],
      },
    },
    {
      id: 'recLog2', createdTime: '2026-01-02T00:00:01.000Z',
      fields: { Event: 'Unlinked', Timestamp: '2026-01-02T00:00:01.000Z', Action: 'Error' },
    },
  ],
  bots: [{
    id: 'recBot1', createdTime: '2026-01-03T00:00:00.000Z',
    fields: { Name: 'Agent', Type: 'Automation', Active: true, 'Contact Info': 'none' },
  }],
  mergeQueue: [
    {
      id: 'recQueue1', createdTime: '2026-01-04T00:00:00.000Z',
      fields: {
        Key: 'queue-one', Timestamp: '2026-01-04T00:00:00.000Z',
        'Target Data': 'first', Status: 'Pending', 'Proposed By': ['recBot1'],
        'Linked Target': ['recTarget1'],
      },
    },
    {
      id: 'recQueue2', createdTime: '2026-01-04T00:00:01.000Z',
      fields: { Key: 'queue-two', 'Target Data': 'duplicate', Status: 'Rejected', 'Duplicate Of': ['recQueue1'] },
    },
  ],
  claims: [{
    id: 'recClaim1', createdTime: '2026-01-05T00:00:00.000Z',
    fields: {
      Key: 'old-claim', Target: ['recTarget1'], 'Target Key': ['dead-target'],
      Workflow: 'old-run', 'Claimed At': '2026-01-05T00:00:00.000Z',
      'Expires At': '2026-01-05T00:01:00.000Z', 'Released At': '2026-01-05T00:00:30.000Z',
    },
  }],
};
const links = {
  logTargets: [
    { logId: 'recLog1', targetId: 'recTarget1' },
    { logId: 'recLog1', targetId: 'recTarget2' },
  ],
  targetBots: [{ targetId: 'recTarget1', botId: 'recBot1' }],
  queueProposers: [{ queueId: 'recQueue1', botId: 'recBot1' }],
  queueDuplicates: [{ queueId: 'recQueue2', duplicateOfId: 'recQueue1' }],
  queueTargets: [{ queueId: 'recQueue1', targetId: 'recTarget1' }],
  claimTargets: [{ claimId: 'recClaim1', targetId: 'recTarget1' }],
};
const counts = {
  targets: 2, logEvents: 2, bots: 1, mergeQueue: 2, claims: 1,
  totalRecords: 8, unlinkedLogs: 1,
  relationships: Object.fromEntries(Object.entries(links).map(([key, value]) => [key, value.length])),
};
const snapshot = {
  format: 'codex-profiles-airtable-snapshot-v1',
  source: { service: 'airtable', baseId: 'fixture-base' },
  exportedAt: '2026-01-06T00:00:00.000Z',
  schema: { tables: [] },
  tables: Object.fromEntries(Object.entries(records).map(([key, value]) => [key, {
    id: `table-${key}`, name: key, records: value,
  }])),
  links,
  counts,
};

writeSnapshot(snapshotPath, snapshot);

let started = false;
try {
  mustRun('mkdir', ['-p', socket]);
  mustRun('initdb', ['-D', data, '-U', 'postgres', '-A', 'trust', '--no-locale', '-E', 'UTF8']);
  mustRun('pg_ctl', ['-D', data, '-l', serverLog, '-o', `-F -k ${socket} -h '' -p ${port}`, '-w', 'start']);
  started = true;
  mustRun('psql', ['-X', '-v', 'ON_ERROR_STOP=1', '-d', 'postgres', '-c', 'CREATE DATABASE neondb']);
  sql("CREATE SCHEMA auth; CREATE FUNCTION auth.user_id() RETURNS text LANGUAGE sql STABLE AS $$ SELECT current_setting('request.jwt.claim.sub', true) $$;");

  const imported = run(process.execPath, [MIGRATION, 'import', '--in', snapshotPath], { env: migrationEnv });
  assert.equal(imported.status, 0, imported.stderr);
  assert.match(imported.stdout, /Imported 8 records; verification passed/);
  assert.equal(sql('SELECT count(*) FROM public.targets'), '2');
  assert.equal(sql('SELECT count(*) FROM public.log_events'), '2');
  assert.equal(sql('SELECT count(*) FROM public.log_targets'), '2');
  assert.equal(sql('SELECT count(*) FROM public.log_events l WHERE NOT EXISTS (SELECT FROM public.log_targets x WHERE x.log_id = l.id)'), '1');
  assert.equal(sql("SELECT name FROM public.targets WHERE key = 'dead-target'"), 'Quotes " backslash \\ and\nmultiple lines');

  const duplicateImport = run(process.execPath, [MIGRATION, 'import', '--in', snapshotPath], { env: migrationEnv });
  assert.notEqual(duplicateImport.status, 0);
  assert.match(duplicateImport.stderr, /destination is not empty/);

  for (let attempt = 0; attempt < 2; attempt++) {
    const synced = run(process.execPath, [MIGRATION, 'sync', '--in', snapshotPath, '--against', snapshotPath], { env: migrationEnv });
    assert.equal(synced.status, 0, synced.stderr);
  }

  const verified = run(process.execPath, [MIGRATION, 'verify', '--in', snapshotPath], { env: migrationEnv });
  assert.equal(verified.status, 0, verified.stderr);
  const report = JSON.parse(verified.stdout);
  assert.equal(report.ok, true);
  assert.equal(report.actualUnlinkedLogs, 1);
  assert.equal(report.relationshipMismatches, 0);
  assert.equal(report.activeClaims, 0);

  const deleted = structuredClone(snapshot);
  deleted.tables.targets.records.pop();
  deleted.counts.targets--;
  deleted.counts.totalRecords--;
  deleted.links.logTargets = deleted.links.logTargets.filter(({ targetId }) => targetId !== 'recTarget2');
  deleted.counts.relationships.logTargets--;
  writeSnapshot(deletedSnapshotPath, deleted);
  const refusedDeletion = run(process.execPath, [MIGRATION, 'sync', '--in', deletedSnapshotPath, '--against', snapshotPath], { env: migrationEnv });
  assert.notEqual(refusedDeletion.status, 0);
  assert.match(refusedDeletion.stderr, /Source deletion detected/);

  const bad = structuredClone(snapshot);
  bad.tables.targets.records[0].fields.Status = 'Not A Status';
  writeSnapshot(badSnapshotPath, bad);
  const rolledBack = run(process.execPath, [MIGRATION, 'sync', '--in', badSnapshotPath, '--against', snapshotPath], { env: migrationEnv });
  assert.notEqual(rolledBack.status, 0);
  assert.equal(sql("SELECT status FROM public.targets WHERE key = 'dead-target'"), 'Dead');

  assert.equal(sql("SELECT relrowsecurity FROM pg_class WHERE oid = 'public.targets'::regclass"), 't');
  assert.equal(sql("SELECT has_table_privilege('outreach_tracker', 'public.targets', 'SELECT')"), 'f');
  assert.equal(sql("SELECT has_table_privilege('outreach_tracker', 'outreach_private.migration_snapshots', 'SELECT')"), 'f');
  assert.equal(sql("SELECT has_function_privilege('public', 'public.tracker_claim(text,text,bigint,uuid)', 'EXECUTE')"), 'f');
  assert.equal(sql("SELECT count(*) FROM pg_proc WHERE proname LIKE 'tracker_%' AND NOT (proconfig @> ARRAY['search_path=pg_catalog, public, outreach_private'])"), '0');

  const wrongIdentity = run('psql', psqlArgs(trackerTransaction('SELECT count(*) FROM public.tracker_list_targets()', 'wrong')));
  assert.notEqual(wrongIdentity.status, 0);
  assert.match(wrongIdentity.stderr, /outreach tracker identity required/);
  assert.equal(sql(trackerTransaction('SELECT count(*) FROM public.tracker_list_targets()')), '2');

  const logMutation = run('psql', ['-X', '-qAt', '-v', 'ON_ERROR_STOP=1', '-c', 'UPDATE public.log_events SET result = \'changed\' WHERE legacy_airtable_id = \'recLog1\'']);
  assert.notEqual(logMutation.status, 0);
  assert.match(logMutation.stderr, /append-only/);
  const claimDelete = run('psql', ['-X', '-qAt', '-v', 'ON_ERROR_STOP=1', '-c', "DELETE FROM public.claims WHERE key = 'old-claim'"]);
  assert.notEqual(claimDelete.status, 0);
  assert.match(claimDelete.stderr, /append-only/);

  const op = randomUUID();
  sql(trackerTransaction(`SELECT public.tracker_set_status('dead-target', 'Dead', '${op}'); SELECT public.tracker_set_status('dead-target', 'Dead', '${op}')`));
  assert.equal(sql(`SELECT count(*) FROM public.log_events WHERE operation_id = '${op}'`), '1');

  const claimSql = (workflow) => trackerTransaction(`SELECT outcome FROM public.tracker_claim('dead-target', '${workflow}', 5000, '${randomUUID()}')`);
  const contenders = await Promise.all([sqlAsync(claimSql('concurrent-a')), sqlAsync(claimSql('concurrent-b'))]);
  assert.deepEqual(contenders.map(({ status }) => status), [0, 0]);
  assert.deepEqual(contenders.map(({ stdout }) => stdout).sort(), ['claimed', 'lost']);
  const winner = contenders.find(({ stdout }) => stdout === 'claimed');
  const winnerName = winner === contenders[0] ? 'concurrent-a' : 'concurrent-b';
  const loserName = winnerName === 'concurrent-a' ? 'concurrent-b' : 'concurrent-a';

  const releaseSql = (workflow) => trackerTransaction(`SELECT outcome FROM public.tracker_release('dead-target', '${workflow}', '${randomUUID()}')`);
  assert.equal((await sqlAsync(releaseSql(loserName))).stdout, 'never');
  assert.equal((await sqlAsync(releaseSql(winnerName))).stdout, 'released');
  assert.equal((await sqlAsync(releaseSql(winnerName))).stdout, 'inactive');

  const shortClaim = await sqlAsync(trackerTransaction(`SELECT outcome FROM public.tracker_claim('dead-target', 'stale', 10, '${randomUUID()}')`));
  assert.equal(shortClaim.stdout, 'claimed');
  await sleep(30);
  assert.equal((await sqlAsync(claimSql('new-holder'))).stdout, 'claimed');
  assert.equal((await sqlAsync(releaseSql('stale'))).stdout, 'inactive');
  assert.equal((await sqlAsync(claimSql('blocked-after-stale-release'))).stdout, 'lost');

  const queued = sql(trackerTransaction("SELECT key FROM public.tracker_enqueue('live-queue', 'test', 'payload', 'dead-target', NULL)"));
  assert.equal(queued, 'live-queue');
  const resolved = sql(trackerTransaction("SELECT status FROM public.tracker_resolve_queue('live-queue', 'test', 'Merged', 'dead-target', NULL, 'done')"));
  assert.equal(resolved, 'Merged');
} finally {
  if (started) run('pg_ctl', ['-D', data, '-m', 'fast', '-w', 'stop']);
  rmSync(temporary, { recursive: true, force: true });
}
