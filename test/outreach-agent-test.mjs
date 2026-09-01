#!/usr/bin/env node

import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';

const root = new URL('..', import.meta.url).pathname;
const agent = readFileSync(join(root, 'agent.md'), 'utf8');
const normalizedAgent = agent.replace(/\s+/g, ' ');

const mustContain = [
  'Targets stays the main pipeline table',
  'Log stays append-only history',
  'Merge Queue handles dedupe conflicts',
  'Bots coordinates automation claims',
  'Primary lead unit: repository',
  'Primary close: accepted listing/PR',
  'Do not submit, open, post, comment, email, DM, or otherwise contact externally without explicit approval',
  '`Targets.Key`',
  '`Targets.Channel`',
  '`Targets.Status`',
  '`Targets.Priority`',
  '`Log.Workflow`',
  'github-lead-gen',
  'lead-qualification',
  'closing',
  'monitoring',
  'Lead Qualification Gate',
  'not a startup, company, SaaS launch, accelerator applicant, or fundraising story',
  'ICP fit',
  'Maybe ICP',
  'Not ICP',
  'Truthfulness gate',
  'Keep `Backlog` only for `ICP: yes` targets',
  'Use `Deferred` for `ICP: maybe` targets',
  'Use `Dead` for permanent `ICP: no` mismatches',
  'Do not invent a company, startup, region, market, customer story, or use case',
  'Backlog -> Issue Open/PR Open -> Pending Review -> Listed',
  'Clear awesome-list fit: draft a PR',
  'Ambiguous scope: draft an issue first',
  'Directory: draft only if guidelines allow CLI/devtool projects',
  'Forum, social, or manual/gated target: draft only and hold for approval',
  'Today',
  'Waiting',
  'Wins',
  'Suppressed',
  'Dedupe',
  'Duplicate repo discovered',
  'Existing open PR found outside Airtable',
  'Directory rejects CLIs/scripts',
  'PR merged/listing accepted',
];

for (const text of mustContain) {
  assert.ok(normalizedAgent.includes(text), `agent.md should contain: ${text}`);
}

const forbidden = [
  'Do not ask the project owner for permission before opening PRs',
  'Act without waiting for manual approval',
];

for (const text of forbidden) {
  assert.ok(!agent.includes(text), `agent.md should not contain: ${text}`);
}
