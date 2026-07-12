#!/usr/bin/env node

import assert from 'node:assert/strict';
import { readFileSync, statSync } from 'node:fs';
import { join } from 'node:path';

const root = new URL('..', import.meta.url).pathname;
const read = (path) => readFileSync(join(root, path), 'utf8');
const exists = (path) => {
  try {
    return statSync(join(root, path)).isFile();
  } catch {
    return false;
  }
};
const normalized = (text) => text.replace(/\s+/g, ' ');

const skills = [
  {
    name: 'github-lead-gen',
    displayName: 'GitHub Lead Gen',
    reference: 'references/search-patterns.md',
    required: [
      'Create or update Airtable `Targets` only',
      '`Log.Workflow = github-lead-gen`',
      '`Next Action = Run lead qualification`',
      'Do not draft PRs, issues, comments, emails, DMs, forum posts, or listing submissions',
      'Do not contact externally',
      'Dedupe against existing Airtable targets',
      'Load `references/search-patterns.md`',
      'The next workflow is lead qualification',
    ],
  },
  {
    name: 'github-lead-qualification',
    displayName: 'GitHub Lead Qualification',
    reference: 'references/icp-rules.md',
    required: [
      'Consume Airtable targets whose `Next Action = Run lead qualification`',
      '`Log.Workflow = lead-qualification`',
      '`ICP: yes`',
      '`ICP: maybe`',
      '`ICP: no`',
      'Set `Priority`',
      'Set `Next Action = Run closing draft`',
      'Do not discover new leads',
      'Do not draft PRs, issues, comments, emails, DMs, forum posts, listing submissions, or maintainer replies',
      'Do not contact externally',
      'Load `references/icp-rules.md`',
    ],
  },
  {
    name: 'github-closing-draft',
    displayName: 'GitHub Closing Draft',
    reference: 'references/draft-rules.md',
    required: [
      'Consume only Airtable targets with `ICP: yes`',
      '`Log.Workflow = closing`',
      'Set `Next Action = Await approval to submit draft`',
      'Do not perform lead discovery',
      'Do not qualify `ICP: maybe` or `ICP: no` targets',
      'Do not submit, open, post, comment, email, DM, or otherwise contact externally',
      "Follow the target repository's conventions over `codex-profiles` conventions",
      'Load `references/draft-rules.md`',
    ],
  },
  {
    name: 'github-monitoring',
    displayName: 'GitHub Monitoring',
    reference: 'references/status-map.md',
    required: [
      'Recheck existing PRs, issues, listings, and Airtable target links',
      '`Log.Workflow = monitoring`',
      'Set `Next Action = Run closing draft` when new drafting is needed',
      'Set `Next Action = Run lead qualification` when fit must be rechecked',
      'Do not discover new leads',
      'Do not draft PRs, issues, comments, emails, DMs, forum posts, listing submissions, or maintainer replies',
      'Do not submit, open, post, comment, email, DM, or otherwise contact externally',
      'Load `references/status-map.md`',
    ],
  },
];

for (const config of skills) {
  const skillPath = `skills/${config.name}/SKILL.md`;
  const metadataPath = `skills/${config.name}/agents/openai.yaml`;
  const referencePath = `skills/${config.name}/${config.reference}`;

  assert.ok(exists(skillPath), `${config.name} skill should exist`);
  assert.ok(exists(metadataPath), `${config.name} UI metadata should exist`);
  assert.ok(exists(referencePath), `${config.name} reference should exist`);

  const skill = read(skillPath);
  const skillText = normalized(skill);
  const frontmatter = skill.match(/^---\n([\s\S]*?)\n---/);
  assert.ok(frontmatter, `${config.name} should have YAML frontmatter`);
  assert.match(frontmatter[1], new RegExp(`^name:\\s*${config.name}$`, 'm'));
  assert.match(frontmatter[1], /^description:\s*Use when .+/m);

  for (const required of config.required) {
    assert.ok(skillText.includes(required), `${config.name} should contain: ${required}`);
  }

  const metadata = read(metadataPath);
  assert.ok(metadata.includes(`display_name: "${config.displayName}"`));
  assert.ok(metadata.includes(`$${config.name}`));
}

const patterns = read('skills/github-lead-gen/references/search-patterns.md');
for (const required of [
  'Codex/Codex CLI/CODEX_HOME repositories',
  'AI coding agent CLI lists',
  'Awesome lists for Codex, terminal agents, CLI tools, and devtools',
  'Repos discussing multi-account/profile workflow tooling',
]) {
  assert.ok(patterns.includes(required), `search patterns should contain: ${required}`);
}

const qualification = read('skills/github-lead-qualification/references/icp-rules.md');
const qualificationText = normalized(qualification);
for (const required of [
  'ICP: yes',
  'ICP: maybe',
  'ICP: no',
  'Truthfulness gate',
  'named ChatGPT windows',
  'does not create an account or operating-system isolation boundary',
]) {
  assert.ok(qualificationText.includes(required), `qualification rules should contain: ${required}`);
}
assert.ok(!qualificationText.includes('Codex Desktop'), 'qualification rules should not use stale Desktop positioning');

const closing = read('skills/github-closing-draft/references/draft-rules.md');
const closingText = normalized(closing);
for (const required of [
  'Draft only',
  'approval',
  'unsupported claims',
  'commit conventions',
  'PR title format',
  'named ChatGPT windows',
  'no OS or account isolation',
]) {
  assert.ok(closingText.includes(required), `draft rules should contain: ${required}`);
}
assert.ok(!closingText.includes('CLI/Desktop support'), 'draft rules should not use stale Desktop positioning');

const monitoring = read('skills/github-monitoring/references/status-map.md');
for (const required of ['PR Open', 'Issue Open', 'Pending Review', 'Listed', 'Declined']) {
  assert.ok(monitoring.includes(required), `status map should contain: ${required}`);
}

const agent = read('agent.md');
for (const config of skills) {
  assert.ok(
    normalized(agent).includes(`Use the repo-local ${config.displayName} skill at \`skills/${config.name}\``),
    `agent.md should point ${config.name} runs at the repo-local skill`
  );
}

for (const file of ['skills/github-lead-gen/.DS_Store']) {
  assert.ok(!exists(file), `${file} should not be present`);
}
