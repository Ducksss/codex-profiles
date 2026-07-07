---
name: github-lead-gen
description: Use when running GitHub lead generation for codex-profiles. Finds repository candidates and performs shallow Airtable intake before lead qualification. Not for drafting, outreach, or monitoring.
---

# GitHub Lead Gen

## Purpose

Find GitHub repository candidates for `codex-profiles`, dedupe them against
Airtable, and hand them off for later qualification. This skill only handles
candidate discovery and shallow intake.

## Required Context

Before searching, read the local project positioning from `README.md` and the
current distribution state from `LAUNCH.md`. Load
`references/search-patterns.md` for approved search lanes and example queries.

## Boundaries

- Create or update Airtable `Targets` only.
- Dedupe against existing Airtable targets before creating records.
- Use `Log.Workflow = github-lead-gen` for every meaningful intake decision.
- Set `Next Action = Run lead qualification` on every accepted candidate.
- Record only a shallow candidate reason; do not assign final ICP.
- Do not draft PRs, issues, comments, emails, DMs, forum posts, or listing submissions.
- Do not contact externally.
- Do not change `LAUNCH.md` unless the user explicitly asks for a repo-local handoff.

## Workflow

1. Search GitHub using the approved lanes in `references/search-patterns.md`.
2. Keep repository-first candidates only; ignore startup, funding, event, and
   social-only surfaces.
3. For each candidate, capture the repository URL, likely channel, shallow
   reason, evidence URL, and duplicate key.
4. Search Airtable `Targets` by deterministic key and repository URL.
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
7. Stop after Airtable intake. The next workflow is lead qualification.

## Output

Return a concise handoff:

- Candidates added.
- Existing targets updated.
- Duplicates skipped.
- Search lanes tried.
- Any Airtable or GitHub access blockers.
