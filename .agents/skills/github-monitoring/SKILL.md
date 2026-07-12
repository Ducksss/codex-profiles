---
name: github-monitoring
description: Use when reconciling existing GitHub PRs, issues, listings, or Airtable outreach targets for codex-profiles after submission or review. Not for lead discovery, qualification, drafting, or outreach.
---

# GitHub Monitoring

## Purpose

Recheck existing GitHub outreach work, reconcile Airtable, and route any new
work back to the correct phase. This skill does not create leads or drafts.

## Required Context

Read policy gates in `LAUNCH.md`, the live Airtable target, and the existing PR,
issue, listing, or submission URL. Load `references/status-map.md` before
updating status.

## Boundaries

- Recheck existing PRs, issues, listings, and Airtable target links.
- Update Airtable `Targets` and append `Log` entries only.
- Use `Log.Workflow = monitoring` for every meaningful recheck.
- Do not discover new leads.
- Do not draft PRs, issues, comments, emails, DMs, forum posts, listing submissions, or maintainer replies.
- Do not submit, open, post, comment, email, DM, or otherwise contact externally.

## Accepted Input

- Consume only targets in `Issue Open`, `PR Open`, or `Pending Review` with a
  recorded external URL and a dated recheck due in `Next Action`.
- Monitoring may route to `Run closing draft` or `Run lead qualification`, but
  it never performs those phases itself.

## Tracker Protocol

Create a unique `run-<UTC-timestamp>-<random-suffix>` `<run-id>` and list each
accepted status independently. Inspect the external state read-only, then claim
the target immediately before writing reconciliation results:

```sh
node scripts/outreach-tracker.mjs list --status "Issue Open" --json
node scripts/outreach-tracker.mjs list --status "PR Open" --json
node scripts/outreach-tracker.mjs list --status "Pending Review" --json
node scripts/outreach-tracker.mjs get <key> --json
node scripts/outreach-tracker.mjs claim <key> --by <run-id>
```

If claim exits 3, skip the target without writing or contacting externally.
Persist the observed status, stable phase log, and next action, then always
release:

```sh
node scripts/outreach-tracker.mjs upsert <key> --status "<status>" \
  --last-checked <YYYY-MM-DD> --next-action "<dated recheck or routed phase>" \
  --notes "<observed state and source>"
node scripts/outreach-tracker.mjs log --target <key> \
  --workflow monitoring --action Rechecked \
  --result "<observed state and next step>" --link "<source-url>"
node scripts/outreach-tracker.mjs release <key> --by <run-id>
```

## Workflow

1. Select existing targets in `Issue Open`, `PR Open`, or `Pending Review`,
   oldest `Last Checked` first.
2. Open the recorded PR, issue, listing, directory entry, or submission status.
3. Apply `references/status-map.md` to map the external state to Airtable.
4. Update `Status`, `Last Checked`, `Next Action`, and `Notes`:
   - Merged or accepted listing: set `Listed` and clear next action unless a
     follow-up is required.
   - Still open with no new information: keep `PR Open` or `Issue Open` and
     set a future recheck.
   - Maintainer asks for changes or new copy: set `Pending Review`; Set
     `Next Action = Run closing draft` when new drafting is needed.
   - Scope, eligibility, or fit changed: Set `Next Action = Run lead qualification`
     when fit must be rechecked.
   - Rejected or closed: set `Declined`, `Deferred`, or `Dead` using the status
     map.
5. Append a `monitoring` log entry with the observed state and source URL.

## Output

Return targets checked, status changes, stale blockers, wins, and handoffs to
lead qualification or closing draft.
