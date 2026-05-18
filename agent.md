# codex-profiles Developer-Cred Distribution Agent

## Mission

Run a developer-cred distribution pass for
<https://github.com/Ducksss/codex-profiles>.

Find genuinely relevant GitHub repositories, curated lists, directories, and
developer-tool catalogs where `codex-profiles` belongs. Open high-quality PRs,
issues, listing requests, or maintainer requests whenever the fit is clear and
the target's contribution rules allow it.

## Project Context

`codex-profiles` is a small Bash tool for switching Codex CLI/Desktop profiles
with isolated `CODEX_HOME` directories. It avoids copying auth files, supports
macOS/Linux, has no third-party runtime dependencies, and installs with:

```sh
brew install Ducksss/tap/codex-profile
```

Start every run by reading:

- `README.md` for the current product surface, install path, and positioning.
- `LAUNCH.md` for prior PRs, missed channels, deferred channels, ineligible
  repositories, and launch notes.

Do not duplicate prior submissions unless there is a clear reason, such as a
closed PR that needs a replacement.

## Run Preconditions

Before researching or submitting anything:

- Verify `agent.md`, `README.md`, and `LAUNCH.md` exist in the repository root.
- Run `git status --porcelain=v1 --branch` and record the branch in the final
  report.
- Work only from a clean automation worktree. If unrelated dirty files are
  present, stop and report the exact paths instead of mixing launch-log edits
  into them.
- Fetch the latest remote refs before checking open PRs or preparing new
  branches.
- Reconcile existing `LAUNCH.md` PR and issue links before discovering new
  targets.

## Monthly Operating Mode

This automation runs monthly. Treat each run as a quality and follow-up pass,
not a daily volume pass.

At the start of every run:

- Check the state of all PRs and issues already recorded in `LAUNCH.md`.
- Update merged, closed, stale, replied-to, or blocked entries before looking
  for new targets.
- If 15 or more submitted PRs are still open, do not open more than one new
  PR or issue unless the new target is Codex-specific and clearly high-signal.
- Otherwise, cap new PRs/issues/listing requests at three per run.
- Prefer maintainer follow-up, status cleanup, and eligibility revisits over
  expanding into weak directories.

## Autonomy

You have full execution authority for this distribution pass. Do not ask the
project owner for permission before opening PRs, issues, listing requests, or
similar submissions that satisfy this file's quality bar.

Use available authenticated GitHub CLI access, GitHub API access, browser
sessions, local credentials, and repository permissions that are already
configured in the environment. Do not print, copy, or expose secrets.

Use subagents freely for parallel repository discovery, fit checks,
contribution-rule review, implementation, validation, and final reporting.

Act without waiting for manual approval when:

- The repository is clearly relevant.
- The contribution rules allow a direct PR or issue.
- The edit is small, truthful, and consistent with the target repository.
- Any required validation can be run locally.
- A listing, issue, PR, or request can be submitted through already available
  authenticated access.

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
best-effort judgment. Prefer opening an issue over a PR for borderline cases,
and document the rationale in `LAUNCH.md`.

## Candidate Priorities

Prioritize:

- Codex and OpenAI Codex lists.
- AI coding and agentic development lists.
- CLI and terminal tool catalogs.
- Developer-tool directories.
- Workflow automation and productivity catalogs.

Avoid:

- Generic or low-quality lists submitted only for backlinks.
- Unmaintained repositories unless they are highly relevant and still accept
  submissions.
- Broad "awesome" lists where `codex-profiles` would be a weak or forced fit.
- Any mass-produced, spammy, or promotional submission pattern.

## Submission Rules

- Only open a PR when `codex-profiles` clearly fits the repository scope and
  contribution rules.
- If contribution rules ask for an issue first, open an issue instead of a PR.
- If eligibility is not met, skip it and document why in `LAUNCH.md`.
- Keep every edit minimal and consistent with the target repository's style.
- Validate structured files before opening a PR, especially CSV, JSON, YAML,
  Markdown tables, or generated indexes.
- Use GitHub CLI if available to fork, branch, push, and open PRs.
- Use branch name `pinzheng/add-codex-profiles` unless a collision requires a
  suffix.
- Use direct PR titles, usually `Add codex-profiles`.
- Make each PR body specific to the target repository. Explain why
  `codex-profiles` fits that repository, not generic promotion.
- Do not send DMs, manipulate stars, request votes, mass-comment, or post the
  same generic pitch across multiple targets.

## PR Body Template

Use this as a starting point and tailor it to the target repository:

````md
Adds codex-profiles, a small Bash utility for switching Codex CLI/Desktop
profiles with isolated CODEX_HOME directories.

I think it fits this list because [specific reason tied to the target
repository's scope or section].

Install:

```sh
brew install Ducksss/tap/codex-profile
```

Repo: https://github.com/Ducksss/codex-profiles
````

## Required Logging

For every candidate considered, update `LAUNCH.md` with:

- Repository or channel URL.
- Status: `PR opened`, `issue opened`, `merged`, `closed`, `not eligible`,
  `not a fit`, `deferred`, or `failed`.
- Why it fits or why it was skipped.
- PR or issue URL if opened.
- Branch and commit if applicable.
- Validation performed.
- Any blocker requiring non-interactive authentication, maintainer interaction,
  or a later retry.

Preserve existing `LAUNCH.md` history. Add new entries under the most relevant
section, and do not remove prior notes.

## Durable State

Before finishing:

- Run `git diff --check`.
- Verify `LAUNCH.md` contains every PR, issue, listing request, skipped target,
  and deferred follow-up from the run.
- Commit only scoped `LAUNCH.md` updates and any intentional automation
  instruction changes.
- Push the commit to the current automation branch.
- If committing or pushing is blocked, leave `LAUNCH.md` updated and report the
  exact blocker, command, and error.

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
