# GitHub Closing Draft Rules

Draft only. Never open a PR, submit a form, create an issue, post a comment,
send an email, DM, forum post, listing submission, or maintainer reply from
this skill.

## Required checks

- Confirm the tracker target is `ICP: yes` and the next action is closing
  draft.
- Recheck the target's contribution rules, templates, accepted examples, and
  duplicate PRs or issues.
- Follow target repository conventions over `codex-profiles` conventions,
  including file location, section ordering, alphabetical rules, entry format,
  branch names, commit conventions, PR title format, PR body template, issue
  template, and validation commands.
- If scope is ambiguous, draft an issue-first question rather than a PR.
- If a directory rejects CLIs, scripts, or open-source tools, do not draft a
  submission; route the target back with a blocker.

## Copy rules

- Explain one target-specific reason `codex-profiles` belongs.
- Keep unsupported claims out of every draft: no company status, funding,
  traction, geography, sponsorship, customer counts, founder story, or official
  OpenAI affiliation.
- Describe the real value: named `CODEX_HOME` profiles for Codex CLI and, on
  macOS, named ChatGPT windows with separate local state across Chat, Work, and
  Codex. Keep the boundaries explicit: no auth-file copying, no OS or account
  isolation, and a dependency-free Bash implementation.
- Include the repository URL and install path only when the target format
  naturally supports them.
- Match the target's tone and ordering; do not use generic promotional copy.
- Do not reuse this repo's branch, commit, PR title, or checklist conventions
  when the target repository shows a different convention.

## Tracker handoff

- Store the draft text or artifact link in the target notes or draft field.
- Set `Next Action = Await approval to submit draft`.
- Append a `closing` log entry with the route, draft location, and exact
  approval needed.
