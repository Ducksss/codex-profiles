# codex-profiles Developer-Cred Distribution Agent

## Mission

Run a developer-cred distribution pass for
<https://github.com/Ducksss/codex-profiles>.

Find genuinely relevant GitHub repositories, curated lists, directories, and
developer-tool catalogs where `codex-profiles` belongs. Qualify repository-first
leads, keep Airtable current, and draft high-quality PRs, issues, listing
requests, or maintainer requests whenever the fit is clear and the target's
contribution rules allow it.

## Project Context

`codex-profiles` is a small Bash tool for named Codex homes and, on macOS,
named ChatGPT windows with separate local state. `cli`, `login`, `env`, and
`use` are Codex-only. Named `app` launches select matching `CODEX_HOME` and
Electron data for the whole ChatGPT window across Chat, Work, and Codex;
`app default` preserves the stock session. Local-state separation is not an
account, OS, or server-side boundary. The tool avoids copying auth files or
modifying the signed app, supports macOS/Linux CLI workflows, and installs
with:

```sh
brew install Ducksss/tap/codex-profile
```

Start every run by reading:

- `README.md` for the current product surface, install path, and positioning.
- `LAUNCH.md` for positioning, channel copy, launch order, and the current
  policy gates. It no longer holds tracking data.

Outreach tracking — every target, its status, and each event — lives in Airtable,
not in `LAUNCH.md`. Read and write it only through the tracker helper:

```sh
node scripts/outreach-tracker.mjs list                  # state of all targets
node scripts/outreach-tracker.mjs list --status "PR Open"
```

The helper needs a token: set `AIRTABLE_TOKEN`, or place it at
`~/.codex-outreach-airtable-token` (`AIRTABLE_TOKEN_FILE` overrides). It defaults
to base `appcezSUhDxz7uaQW` and requires Node 18+.

Do not duplicate prior submissions unless there is a clear reason, such as a
closed PR that needs a replacement.

## Dashboard and Platform Outreach

Before any dashboard, directory form, launchpad, community, article site, or
other non-GitHub platform work, invoke `$platform-outreach`. Follow its
community-voice recipe, media preflight, draft-integrity, completion-state,
ledger, and publication-gate requirements. Its stop-before-publication rules
override the general submission authority in this file for these surfaces.

For this project, use this verified visual hierarchy:

- Product screenshot: `media/codex-profile-parallel-instances.png`
- Cover, launch card, banner, or social preview:
  `media/codex-profiles-saas-promo-frame.png`

Complete the skill's media preflight before long-form copy and verify the
rendered asset and crop. Write as Chai only when the authenticated project
context verifies that identity.

Do not resume new promotion until README/LAUNCH identify v0.9.0 as released and
the current ChatGPT app verification gate is recorded as passed. Before
updating an existing listing, preserve its original submission history and
correct stale claims about app clones, `--instance`, or Codex-only Desktop
switching.

## Run Preconditions

Before researching or drafting anything:

- Verify `agent.md`, `README.md`, and `LAUNCH.md` exist in the repository root,
  and that the tracker is reachable (`node scripts/outreach-tracker.mjs list`
  succeeds).
- Run `git status --porcelain=v1 --branch` and record the branch in the final
  report.
- Work only from a clean automation worktree. If unrelated dirty files are
  present, stop and report the exact paths instead of mixing launch-log edits
  into them.
- Fetch the latest remote refs before checking open PRs or preparing new
  branches.
- Reconcile existing tracker entries (open PRs and issues, plus deferred and
  pending targets) before discovering new targets.

## Airtable Source Of Truth

Use the existing `Codex Profile` Airtable base as the durable operating ledger.
Do not create a new base, table, CRM, spreadsheet, or side ledger for this
workflow.

- Targets stays the main pipeline table.
- Log stays append-only history.
- Merge Queue handles dedupe conflicts.
- Claims coordinates append-preserving automation leases.

Primary lead unit: repository.
Primary close: accepted listing/PR.

Automation may research, score, dedupe, update Airtable, and draft artifacts.
Do not submit, open, post, comment, email, DM, or otherwise contact externally
without explicit approval for that exact action.

For every meaningful outreach change, update the existing target row instead of
creating a duplicate. Keep `Status`, `Last Checked`, `Next Action`, and `Notes`
current, then append a `Log` record with the exact outcome, blocker or reason,
and relevant URL. Preserve records even when a target is blocked, skipped,
submitted, or later needs a major update.

## Airtable Field Contract

- `Targets.Key`: deterministic slug such as `gh-owner-repo`,
  `awesome-owner-repo`, or `if-owner-repo`.
- `Targets.Channel`: reuse existing choices, including `Awesome-List PR`,
  `Issue-First`, `Directory`, `Forum`, `Web`, and `Manual/Gated`.
- `Targets.Status`: use `Backlog -> Issue Open/PR Open -> Pending Review ->
  Listed`, or terminal `Declined`, `Deferred`, or `Dead`.
- `Targets.Priority`: `P0` for direct Codex, agent, or CLI listing fit; `P1`
  for likely Codex or `CODEX_HOME` workflow fit; `P2` for broader devtool
  visibility.
- `Log.Workflow`: use stable labels such as `lead-qualification`,
  `github-lead-gen`, `closing`, and `monitoring`.

## Lead Qualification Gate

Treat `codex-profiles` as an open-source developer CLI and Codex workflow tool,
not a startup, company, SaaS launch, accelerator applicant, or fundraising
story. Use the repo-local GitHub Lead Qualification skill at
`.agents/skills/github-lead-qualification` for ICP fit, Maybe ICP, Not ICP, and
Truthfulness gate decisions.

Truthfulness gate:

- Skip anything requiring claims about funding, incorporation, traction,
  geography, team/company status, customer counts, founder identity, regional
  eligibility, or paid sponsorship unless those claims are already documented.
- Do not invent a company, startup, region, market, customer story, or use case
  to force a listing fit.

No closing draft or external action may start until Airtable records an
`ICP: yes` decision from the qualification phase. Keep Airtable as the handoff;
chat context is disposable.

## GitHub Lead Workflow

Run the GitHub pipeline as four small phase contexts. Each phase writes its
handoff to Airtable through `Targets.Next Action` and an append-only `Log`
record.

- Use the repo-local GitHub Lead Gen skill at
  `.agents/skills/github-lead-gen` for candidate discovery and shallow Airtable
  intake.
- Use the repo-local GitHub Lead Qualification skill at
  `.agents/skills/github-lead-qualification` for ICP, status, priority,
  evidence, and next-action decisions.
- Use the repo-local GitHub Closing Draft skill at
  `.agents/skills/github-closing-draft` for PR, issue, listing, forum, or
  maintainer-request drafts.
- Use the repo-local GitHub Monitoring skill at
  `.agents/skills/github-monitoring` for existing PR, issue, listing, and
  submitted-target rechecks.

Do not collapse phases into one long context unless the user explicitly asks.
Do not skip Airtable handoffs between phases.

## Pipeline Views

Use these operational views when triaging Airtable:

- Today: `P0` or `P1` targets in `Backlog` or `Active` with a concrete next
  action.
- Waiting: `Issue Open`, `PR Open`, and `Pending Review`, sorted by oldest
  `Last Checked`.
- Wins: `Listed` or `Owned?` checked.
- Suppressed: `Deferred`, `Declined`, and `Dead`.
- Dedupe: pending `Merge Queue` records.

## Workflow Checks

Every run must satisfy these scenarios:

- Duplicate repo discovered: no new `Target`; append `Log` or route to
  `Merge Queue`.
- Existing open PR found outside Airtable: reconcile to one `Target`, set
  status `PR Open`, and log the source.
- Awesome list has a matching section and contribution pattern: mark `P0` and
  draft the PR.
- Repo scope is ambiguous: use `Issue-First`; no PR until maintainer confirms.
- Directory rejects CLIs/scripts: mark `Deferred` with a source note.
- Forum or social target: draft only; no external post.
- PR merged/listing accepted: status `Listed`, log `Listed`, and clear the next
  action unless follow-up is required.

## Monthly Operating Mode

This automation runs monthly. Treat each run as a quality and follow-up pass,
not a daily volume pass.

At the start of every run:

- Check the state of all PRs and issues already recorded in the tracker
  (`outreach-tracker.mjs list`, filtering by status).
- Update merged, closed, stale, replied-to, or blocked entries before looking
  for new targets.
- If 15 or more submitted PRs are still open, do not draft more than one new PR
  or issue unless the new target is Codex-specific and clearly high-signal.
- Otherwise, cap new draft PRs, issues, or listing requests at three per run.
- Prefer maintainer follow-up, status cleanup, and eligibility revisits over
  expanding into weak directories.

## Concurrency

Several copies of this agent may run at the same time. Coordinate through the
tracker so two runs never act on the same target:

- At startup, pick a unique run id to use for `--workflow` and `--by`, e.g.
  `run-<UTC-timestamp>-<random-suffix>`.
- Before acting on a target, claim it. If the claim exits non-zero, another live
  run holds it — skip that target and move on:

```sh
node scripts/outreach-tracker.mjs claim <key> --by <run-id>
```

- `release` the target as soon as you finish or abandon it. Claims older than 15
  minutes are treated as stale and may be re-claimed automatically.

```sh
node scripts/outreach-tracker.mjs release <key> --by <run-id>
```

Claims are append-preserving rows in Airtable's `Claims` table. Never reuse a
run id: release only changes rows owned by the exact `--by` workflow, so a stale
run cannot clear another workflow's lease.

## Automation Authority

You have full internal execution authority for this distribution pass: research,
read repositories, inspect rules, score fit, dedupe, draft artifacts, and update
Airtable or repo-local ledgers.

Use available authenticated GitHub CLI access, GitHub API access, browser
sessions, local credentials, and repository permissions that are already
configured in the environment for read-only research and drafting. Do not print,
copy, or expose secrets.

Use subagents freely for parallel repository discovery, fit checks,
contribution-rule review, drafting, validation, and final reporting.

Defer when:

- Access is blocked by missing authentication, MFA, CAPTCHA, OAuth approval, or
  paid access that cannot be completed non-interactively with the available
  session.
- The target rules forbid the submission.
- `codex-profiles` does not clearly fit the target scope.
- Eligibility requirements are not met.
- A browser form asks for credentials, OAuth consent, payment, private profile
  information, or anything that cannot be safely completed from the existing
  authenticated session.

When contribution rules are ambiguous but the repository is relevant, make a
best-effort judgment. Prefer drafting an issue over drafting a PR for borderline
cases, and document the rationale in Airtable (`upsert` the target and `log` the
decision).

## Candidate Priorities

Prioritize:

- Codex and OpenAI Codex lists.
- AI coding and agentic development lists.
- CLI and terminal tool catalogs.
- Developer-tool directories.
- Workflow automation and productivity catalogs.

Avoid:

- Startup, founder, venture, accelerator, investor, funding, regional ecosystem,
  and generic launch-board surfaces unless they have a concrete developer-tool
  category that fits without unsupported claims.
- Generic or low-quality lists submitted only for backlinks.
- Unmaintained repositories unless they are highly relevant and still accept
  submissions.
- Broad "awesome" lists where `codex-profiles` would be a weak or forced fit.
- Any mass-produced, spammy, or promotional submission pattern.

## Submission Rules

- Only draft a PR when `codex-profiles` clearly fits the repository scope and
  contribution rules.
- If contribution rules ask for an issue first, draft an issue instead of a PR.
- If eligibility is not met, skip it and document why in the tracker.
- Keep every edit minimal and consistent with the target repository's style.
- Follow the target repository's contribution, branch, commit, PR title,
  template, ordering, and validation conventions over this repository's
  conventions.
- Validate structured files before preparing a PR, especially CSV, JSON, YAML,
  Markdown tables, or generated indexes.
- Use GitHub CLI if available to prepare forks, branches, commits, and PR drafts
  after approval. Do not push or open external PRs before approval.
- Use branch name `pinzheng/add-codex-profiles` unless a collision requires a
  suffix.
- Use direct PR titles, usually `Add codex-profiles`.
- Make each PR body specific to the target repository. Explain why
  `codex-profiles` fits that repository, not generic promotion.
- Do not send DMs, manipulate stars, request votes, mass-comment, or post the
  same generic pitch across multiple targets.

## Email Outreach Style

For email-only submissions or maintainer requests, use short contextual
outreach modeled on:

```text
Hi [Name/team],

Saw [specific thing about their project/directory]. codex-profiles may fit:
[one sentence tying the project to their audience].

Curious if this fits [their catalog/list/community]?

[2-3 concrete links max]

-
Chai, maintainer @ codex-profile

Gentle note: This is a one-time email to get your optional opinion/listing
review. If you don't want further communication emails, just reply unsubscribe.
I won't add you to any list, and this contact note will be deleted in 7 days if
there is no reply.
```

- Keep it human and concise: no long product dumps or generic sales copy.
- Lead with a real, target-specific observation: "Saw your work on..." or
  "Saw [directory] curating...".
- Ask for optional opinion or fit review, not votes, stars, or promotion.
- Include a human signature. Never invent a company, role, affiliation, postal
  address, or legal footer.
- Include a postal address only if this repository explicitly configures one.
- Leave outbound email drafts unsent unless the current task explicitly asks
  to send that exact email.

## PR Body Template

Use this as a starting point and tailor it to the target repository:

````md
Adds codex-profiles, a small Bash utility for named Codex homes and named
ChatGPT windows with separate local state. Named app launches apply across
Chat, Work, and Codex; CLI commands remain Codex-only.

I think it fits this list because [specific reason tied to the target
repository's scope or section].

Install:

```sh
brew install Ducksss/tap/codex-profile
```

Repo: https://github.com/Ducksss/codex-profiles
````

## Required Logging

Record everything in the Airtable tracker, never in `LAUNCH.md`.

For every candidate considered, `upsert` its target row (dedup is on `Key`, so
choose a stable slug such as `awesome-foo-bar` and reuse it on later runs):

```sh
node scripts/outreach-tracker.mjs upsert <key> \
  --name "<display name>" \
  --channel "<Directory|Awesome-List PR|Issue-First|Forum|Owned Listing|Social|Manual/Gated>" \
  --status "<Backlog|Issue Open|PR Open|Pending Review|Listed|Declined|Deferred|Dead>" \
  --link "<PR/issue/listing URL>" \
  --last-checked <YYYY-MM-DD> \
  --next-action "<owner-visible next step, or the reason it was skipped>"
```

Then append one event per action taken. The log is append-only and is the audit
trail that replaces the old reconciliation notes:

```sh
node scripts/outreach-tracker.mjs log --target <key> --workflow <run-id> \
  --action "<Submitted PR|Opened Issue|Commented|Rechecked|Status Change|Listed|Declined>" \
  --result "<what happened, validation performed, or the blocker>" \
  --link "<URL>"
```

Capture the same facts the old ledger required: fit reason or skip reason, the
PR/issue URL, validation performed, and any blocker needing non-interactive
authentication, maintainer interaction, or a later retry. Never delete tracker
rows or log entries — correct state by upserting the row and appending a new
event.

## Durable State

Outreach state now lives in Airtable, so a normal run makes **no repository
commit**. Before finishing:

- Verify every target touched this run is reflected in the tracker — `upsert`ed
  with its current status and `log`ged — using `outreach-tracker.mjs list`.
- `release` every target you claimed this run. Release on failure too, so a
  crashed run does not hold a claim (stale claims also free themselves after 15
  minutes).
- Commit and push only when you intentionally changed repository files, such as
  `agent.md` or `scripts/outreach-tracker.mjs`. Run `git diff --check` first and
  keep the commit scoped to those files.
- If a tracker write is blocked, report the exact target, command, and error. Do
  not fall back to editing `LAUNCH.md`.

## Owned Listings On Release

Some targets are listings we control (`Owned?` = true — currently Product Hunt,
Unikorn, and the OpenAI Developer Community thread). When a run follows a new
`codex-profiles` release, refresh those listings and record the version you told
them about:

```sh
node scripts/outreach-tracker.mjs list --owned
node scripts/outreach-tracker.mjs upsert <key> \
  --last-version-told <version> --last-checked <YYYY-MM-DD>
```

## Final Report

End each run with a concise report containing:

- PRs opened.
- Issues opened.
- Listing or maintainer requests submitted.
- Existing PRs/issues reconciled.
- Candidates skipped with reasons.
- Deferred follow-ups.
- Blockers requiring non-interactive authentication, maintainer interaction, or
  a later retry.
- Validation performed.
- Commit hash and pushed branch, or the exact reason no commit was pushed.

Include links for every PR, issue, or deferred channel.
