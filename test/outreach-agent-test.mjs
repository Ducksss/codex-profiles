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
  'Use the repo-local GitHub Lead Gen skill at `skills/github-lead-gen`',
  'Use the repo-local GitHub Lead Qualification skill at `skills/github-lead-qualification`',
  'Use the repo-local GitHub Closing Draft skill at `skills/github-closing-draft`',
  'Use the repo-local GitHub Monitoring skill at `skills/github-monitoring`',
  'Lead Qualification Gate',
  'not a startup, company, SaaS launch, accelerator applicant, or fundraising story',
  'ICP fit',
  'Maybe ICP',
  'Not ICP',
  'Truthfulness gate',
  'No closing draft or external action may start until Airtable records an `ICP: yes` decision',
  'Do not invent a company, startup, region, market, customer story, or use case',
  'Backlog -> Issue Open/PR Open -> Pending Review -> Listed',
  'candidate discovery and shallow Airtable intake',
  'ICP, status, priority, evidence, and next-action decisions',
  'PR, issue, listing, forum, or maintainer-request drafts',
  'existing PR, issue, listing, and submitted-target rechecks',
  'Do not collapse phases into one long context',
  'Do not skip Airtable handoffs between phases',
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
