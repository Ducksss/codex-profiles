---
name: github-closing-draft
description: Use when drafting GitHub PRs, issues, listing copy, or maintainer requests for qualified codex-profiles Airtable targets. Not for discovery, qualification, monitoring, outreach, or submission.
---

# GitHub Closing Draft

## Purpose

Create target-specific draft artifacts for qualified `codex-profiles` leads and
leave them approval-gated in Airtable. This skill drafts only; it never opens,
posts, submits, comments, emails, or sends anything externally.

## Required Context

Read `README.md`, policy gates in `LAUNCH.md`, the live Airtable target, and the
target's contribution rules or submission guidelines. Load
`references/draft-rules.md` before writing copy.

## Boundaries

- Consume only Airtable targets with `ICP: yes`.
- Use `Log.Workflow = closing` for every meaningful draft decision.
- Update Airtable with the draft, evidence, and approval blocker.
- Set `Next Action = Await approval to submit draft` after a draft is ready.
- Follow the target repository's conventions over `codex-profiles` conventions.
- Do not perform lead discovery.
- Do not qualify `ICP: maybe` or `ICP: no` targets; route unclear fit back to
  lead qualification.
- Do not submit, open, post, comment, email, DM, or otherwise contact externally.

## Accepted Input

- Consume only `Status = Backlog` targets with `ICP: yes` recorded in `Notes`
  and `Next Action = Run closing draft`.
- Never draft for `ICP: maybe`, `ICP: no`, `Deferred`, `Declined`, or `Dead`
  targets; route unclear evidence back to lead qualification.

## Tracker Protocol

Create a unique `run-<UTC-timestamp>-<random-suffix>` `<run-id>`, select the
eligible target, inspect it, and acquire its lease before drafting:

```sh
node scripts/outreach-tracker.mjs list --status Backlog --json
node scripts/outreach-tracker.mjs get <key> --json
node scripts/outreach-tracker.mjs claim <key> --by <run-id>
```

If claim exits 3, skip the target without writing or contacting externally.
Store the draft or its repo-local path in `Notes`, hold it for approval, log the
stable phase label, and always release:

```sh
node scripts/outreach-tracker.mjs upsert <key> \
  --next-action "Await approval to submit draft" \
  --notes "<draft text or repo-local artifact path plus evidence>"
node scripts/outreach-tracker.mjs log --target <key> \
  --workflow closing --action Rechecked \
  --result "Draft prepared; explicit approval required" --link "<target-url>"
node scripts/outreach-tracker.mjs release <key> --by <run-id>
```

## Workflow

1. Select Airtable targets marked `ICP: yes` with `Next Action = Run closing draft`.
2. Recheck duplicate PRs, issues, or existing listings before drafting.
3. Read contribution rules, templates, accepted examples, and target scope.
4. Identify the target repository's file ordering, wording, commit conventions,
   branch conventions, PR title format, validation commands, and maintainer
   preference for issue-first vs PR-first.
5. Choose the draft route:
   - Clear awesome-list fit: prepare a PR diff and PR body draft.
   - Ambiguous scope: prepare an issue-first draft.
   - Directory: prepare listing copy only when guidelines allow CLI or devtool
     projects.
   - Forum, social, or manual-gated target: prepare copy only and hold.
6. Keep claims narrow and source-backed using `references/draft-rules.md`.
7. Update Airtable with the draft artifact location or text, set the approval
   next action, and append a `closing` log entry.

## Output

Return drafts grouped by target, the exact approval action needed, and any
targets routed back to qualification or monitoring.
