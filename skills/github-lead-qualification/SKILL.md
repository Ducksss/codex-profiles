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

Read `README.md` for current product positioning and `LAUNCH.md` for prior
outreach state. Load `references/icp-rules.md` before scoring.

## Boundaries

- Update Airtable `Targets` and append `Log` entries only.
- Consume Airtable targets whose `Next Action = Run lead qualification`.
- Use `Log.Workflow = lead-qualification` for every meaningful decision.
- Assign exactly one of `ICP: yes`, `ICP: maybe`, or `ICP: no`.
- Set `Priority`, `Status`, `Last Checked`, `Next Action`, and evidence.
- Do not discover new leads.
- Do not draft PRs, issues, comments, emails, DMs, forum posts, listing submissions, or maintainer replies.
- Do not contact externally.

## Workflow

1. Select unqualified GitHub targets whose next action is lead qualification.
2. Read the target repository, list, directory, or guidelines enough to judge
   fit and contribution route.
3. Apply `references/icp-rules.md`; record evidence links and the truthful-fit
   rationale.
4. Set `Status`:
   - `Backlog` only for `ICP: yes` with a valid route, no duplicate open PR or
     issue, and a concrete next action.
   - `Deferred` for `ICP: maybe`, temporary blockers, gated flows, or
     issue-first-only cases.
   - `Dead` for permanent `ICP: no` mismatches.
5. Set `Priority`: `P0` for direct Codex, agent, or CLI listing fit; `P1` for
   likely Codex or `CODEX_HOME` workflow fit; `P2` for broader devtool
   visibility.
6. Set `Next Action = Run closing draft` only for `ICP: yes` targets ready for
   drafting. Otherwise set a specific recheck, blocker, or terminal note.
7. Append a `Log` entry with the decision, reason, evidence URL, and next step.

## Output

Return a concise Airtable handoff: targets qualified, ICP counts, blockers,
targets ready for closing draft, and any records that need dedupe cleanup.
