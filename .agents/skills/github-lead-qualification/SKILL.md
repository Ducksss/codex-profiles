---
name: github-lead-qualification
description: Use when qualifying Airtable GitHub lead candidates for codex-profiles after lead generation and before any closing draft. Not for discovery, drafting, outreach, submission, or monitoring.
---

# GitHub Lead Qualification

## Purpose

Decide whether GitHub lead-gen candidates are real fits for `codex-profiles`,
then update Airtable with evidence and a next phase. This skill consumes
Airtable targets whose `Next Action = Run lead qualification`.

## Required Context

Read `README.md` for current product positioning, `LAUNCH.md` for policy gates,
and the selected Airtable target for live outreach state. Load
`references/icp-rules.md` before scoring.

## Boundaries

- Update Airtable `Targets` and append `Log` entries only.
- Consume Airtable targets whose `Next Action = Run lead qualification`.
- Use `Log.Workflow = lead-qualification` for every meaningful decision.
- Assign exactly one of `ICP: yes`, `ICP: maybe`, or `ICP: no`.
- Set `Priority`, `Status`, `Last Checked`, `Next Action`, and evidence.
- Do not discover new leads.
- Do not draft PRs, issues, comments, emails, DMs, forum posts, listing submissions, or maintainer replies.
- Do not contact externally.

## Accepted Input

- Consume only `Backlog` or `Deferred` targets whose
  `Next Action = Run lead qualification`.
- Leave ready `ICP: yes` targets as `Backlog` with
  `Next Action = Run closing draft`; leave all other outcomes with a concrete
  recheck, blocker, or terminal next action.
- Issue-first is a valid closing-draft route when the target is a truthful fit,
  requires an issue before a PR, and has no existing submission.

## Tracker Protocol

Create a unique `run-<UTC-timestamp>-<random-suffix>` `<run-id>`, list candidate
rows, and inspect each selected row before claiming it:

```sh
node scripts/outreach-tracker.mjs list --json
node scripts/outreach-tracker.mjs list --status Backlog --json
node scripts/outreach-tracker.mjs list --status Deferred --json
node scripts/outreach-tracker.mjs get <key> --json
node scripts/outreach-tracker.mjs claim <key> --by <run-id>
```

If claim exits 3, skip the target without writing or contacting externally.
After a successful claim, use a shell trap or equivalent finally cleanup to
release on every exit path, including partial persistence or logging failure.
After qualification, persist the decision and stable phase log:

```sh
node scripts/outreach-tracker.mjs upsert <key> --status "<status>" \
  --priority "<P0|P1|P2>" --last-checked <YYYY-MM-DD> \
  --next-action "<next phase, blocker, recheck, or terminal action>" \
  --notes "<ICP decision, rationale, and evidence>"
node scripts/outreach-tracker.mjs log --target <key> \
  --workflow lead-qualification --action Rechecked \
  --result "<ICP decision, reason, and next step>" --link "<evidence-url>"
node scripts/outreach-tracker.mjs release <key> --by <run-id>
```

Target upserts are idempotent by `Key`, so retry an upsert after a definite
failure. Logs are append-only: retry a log only when the first request definitely
failed; if its outcome is ambiguous, preserve the decision in target notes,
report the partial audit blocker, and do not append a possible duplicate blindly.

## Workflow

1. Select unqualified GitHub targets whose next action is lead qualification.
2. Read the target repository, list, directory, or guidelines enough to judge
   fit and contribution route.
3. Check GitHub for existing open PRs and issues and Airtable for duplicate
   repository URLs or keys before marking a target drafting-ready.
   - If an existing submission is open, preserve the target and history, set
     `Issue Open` or `PR Open` and route the canonical link to monitoring. Do
     not create a closing draft.
   - If multiple Airtable rows describe the same repository, preserve them,
     set a concrete dedupe blocker, and route the conflict through `Merge Queue`.
4. Apply `references/icp-rules.md`; record evidence links and the truthful-fit
   rationale.
5. Set `Status`:
   - `Backlog` only for `ICP: yes` with a valid PR-first or issue-first route,
     no duplicate open PR or issue, and a concrete next action.
   - `Deferred` for `ICP: maybe`, temporary blockers, gated flows, or
     unresolved Airtable dedupe conflicts.
   - `Dead` for permanent `ICP: no` mismatches.
6. Set `Priority`: `P0` for direct Codex, agent, or CLI listing fit; `P1` for
   likely Codex or `CODEX_HOME` workflow fit; `P2` for broader devtool
   visibility.
7. Set `Next Action = Run closing draft` only for `ICP: yes` targets ready for
   drafting. Otherwise set a specific recheck, blocker, or terminal note.
8. Append a `Log` entry with the decision, reason, evidence URL, and next step.

## Output

Return a concise Airtable handoff: targets qualified, ICP counts, blockers,
targets ready for closing draft, and any records that need dedupe cleanup.
