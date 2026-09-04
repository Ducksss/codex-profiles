#!/usr/bin/env node

import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('../..', import.meta.url));
const agentPath = 'ops/outreach/agent.md';
const agent = readFileSync(join(root, agentPath), 'utf8');
const normalizedAgent = agent.replace(/\s+/g, ' ');

const mustContain = [
  'Targets stays the main pipeline table',
  'Log stays append-only history',
  'Merge Queue handles dedupe conflicts',
  'Claims coordinates append-preserving automation leases',
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
  'Use the repo-local GitHub Lead Gen skill at `.agents/skills/github-lead-gen`',
  'Use the repo-local GitHub Lead Qualification skill at `.agents/skills/github-lead-qualification`',
  'Use the repo-local GitHub Closing Draft skill at `.agents/skills/github-closing-draft`',
  'Use the repo-local GitHub Monitoring skill at `.agents/skills/github-monitoring`',
  'Lead Qualification Gate',
  'not a startup, company, SaaS launch, accelerator applicant, or fundraising story',
  'ICP fit',
  'Maybe ICP',
  'Not ICP',
  'Truthfulness gate',
  'No closing draft or external action may start until the tracker records an `ICP: yes` decision',
  'Do not invent a company, startup, region, market, customer story, or use case',
  '`Active` for an in-progress, unsubmitted target',
  'Backlog -> Issue Open/PR Open -> Pending Review -> Listed',
  'candidate discovery and shallow tracker intake',
  'ICP, status, priority, evidence, and next-action decisions',
  'PR, issue, listing, forum, or maintainer-request drafts',
  'existing PR, issue, listing, and submitted-target rechecks',
  'Do not collapse phases into one long context',
  'Do not skip tracker handoffs between phases',
  'Today',
  'Waiting',
  'Wins',
  'Suppressed',
  'Dedupe',
  'Duplicate repo discovered',
  'Existing open PR found outside the tracker',
  'NEON_DATA_API_URL',
  'NEON_JWT_KEY_FILE',
  'Outreach Tracker Source Of Truth',
  'Directory rejects CLIs/scripts',
  'PR merged/listing accepted',
  'If the claim exits 3',
  'For any other nonzero exit',
  'There is no approved current product screenshot',
  '`docs/og-image.png` may be used only as a generic project cover',
];

for (const text of mustContain) {
  assert.ok(normalizedAgent.includes(text), `${agentPath} should contain: ${text}`);
}

const forbidden = [
  'Do not ask the project owner for permission before opening PRs',
  'Act without waiting for manual approval',
  '$platform-outreach',
  'media/codex-profile-parallel-instances.png',
  'media/codex-profiles-saas-promo-frame.png',
];

for (const text of forbidden) {
  assert.ok(!normalizedAgent.includes(text), `${agentPath} should not contain: ${text}`);
}
