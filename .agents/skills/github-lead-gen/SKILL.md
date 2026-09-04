---
name: github-lead-gen
description: Use when running GitHub lead generation for codex-profiles. Finds repository candidates and performs shallow tracker intake before lead qualification. Not for drafting, outreach, or monitoring.
---

# GitHub Lead Gen

## Purpose

Find GitHub repository candidates for `codex-profiles`, dedupe them against
the outreach tracker, and hand them off for later qualification. This skill only handles
candidate discovery and shallow intake.

## Required Context

Before searching, read current product positioning from `README.md`, policy
gates from `ops/outreach/launch.md`, and live distribution state from the
outreach tracker.
Load `references/search-patterns.md` for approved search lanes and example
queries.

## Boundaries

- Create or update tracker `Targets` only.
- Dedupe against existing tracker targets before creating records.
- Use `Log.Workflow = github-lead-gen` for every meaningful intake decision.
- Set `Next Action = Run lead qualification` on every accepted candidate.
- Record only a shallow candidate reason; do not assign final ICP.
- Do not draft PRs, issues, comments, emails, DMs, forum posts, or listing submissions.
- Do not contact externally.
- Do not change `ops/outreach/launch.md` unless the user explicitly asks for a
  repo-local handoff.

## Accepted Input

- A new repository candidate with no matching tracker target, or an existing
  target that needs shallow lead-generation evidence refreshed.
- Do not overwrite a qualified or submitted target's `Status`, ICP decision, or
  phase-specific `Next Action`.
- Every accepted new target leaves this phase as `Status = Backlog` and
  `Next Action = Run lead qualification`.

## Tracker Protocol

Create one unique `run-<UTC-timestamp>-<random-suffix>` value and use it as
`<run-id>` for the whole invocation. Start with the complete ledger:

```sh
node scripts/outreach-tracker.mjs list --json
```

For an existing target, claim it before changing fields. For a new target,
atomically create the shallow row first, then claim it before adding evidence or
logging the handoff:

```sh
node scripts/outreach-tracker.mjs upsert <key> --name "<name>" \
  --channel "<channel>" --status Backlog \
  --next-action "Run lead qualification" --notes "<candidate reason and source>"
node scripts/outreach-tracker.mjs claim <key> --by <run-id>
```

If claim exits 3, skip the target without writing or contacting externally.
After a successful claim, record the stable phase label and always release,
including on failure:

```sh
node scripts/outreach-tracker.mjs log --target <key> \
  --workflow github-lead-gen --action Rechecked \
  --result "Candidate captured for lead qualification" --link "<evidence-url>"
node scripts/outreach-tracker.mjs release <key> --by <run-id>
```

## Workflow

1. Search GitHub using the approved lanes in `references/search-patterns.md`.
2. Keep repository-first candidates only; ignore startup, funding, event, and
   social-only surfaces.
3. For each candidate, capture the repository URL, likely channel, shallow
   reason, evidence URL, and duplicate key.
4. Search tracker `Targets` by deterministic key and repository URL using the
   tracker; do not maintain a side ledger.
5. If an existing target is found, update only stale lead-gen fields and append
   a `github-lead-gen` log entry.
6. If no target exists, create a `Targets` record with:
   - `Key`: deterministic slug such as `gh-owner-repo`,
     `awesome-owner-repo`, or `if-owner-repo`.
   - `Channel`: best existing lead-gen channel, usually `Awesome-List PR`,
     `Issue-First`, `Directory`, `Web`, or `Manual/Gated`.
   - `Status`: `Backlog` only for plausible repository leads awaiting
     qualification; otherwise skip.
   - `Priority`: leave blank unless the repository is obviously Codex-specific.
   - `Next Action`: `Run lead qualification`.
   - `Notes`: shallow candidate reason and source query.
7. Stop after tracker intake. The next workflow is lead qualification.

## Output

Return a concise handoff:

- Candidates added.
- Existing targets updated.
- Duplicates skipped.
- Search lanes tried.
- Any tracker or GitHub access blockers.
