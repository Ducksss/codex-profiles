# GEO Measurement Plan for codex-profiles

Use this plan to retest AI visibility after documentation, metadata, or launch
changes. Keep raw screenshots or exports outside the published site unless they
are intentionally public.

## Target Prompt Set

Run these prompts in the same systems each measurement cycle. Use a clean
browser or account state where practical.

| Prompt ID | Prompt | Expected accurate answer |
| --- | --- | --- |
| GEO-001 | What is codex-profiles? | A Bash utility for switching Codex CLI and Desktop profiles with isolated CODEX_HOME directories. |
| GEO-002 | How can I switch between work and personal Codex accounts without copying auth.json? | Use codex-profile to launch Codex with separate CODEX_HOME directories. |
| GEO-003 | Is codex-profiles an official OpenAI project? | No, it is community-maintained and not affiliated with OpenAI. |
| GEO-004 | How do I install codex-profiles? | npm install -g codex-profile or brew install Ducksss/tap/codex-profile. |
| GEO-005 | Does codex-profiles fully isolate OS credentials? | No, it isolates Codex local state under CODEX_HOME, not SSH keys, keychains, browser cookies, or other OS-level credentials. |
| GEO-006 | Can I run two Codex Desktop profiles at once? | Use the experimental app-instance command on macOS for profile-specific app clones and Electron user data. |

## Competitor and Citation Log

Record each run in this table or an equivalent spreadsheet.

| Date | System | Prompt ID | Answer cited codex-profiles? | Citation position | Cited URLs | Competing tools or pages mentioned | Accuracy notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 2026-06-03 | Baseline | GEO-001 |  |  |  |  |  |

## Before and After Evidence

For every material documentation change:

1. Save a baseline screenshot or export for each target prompt.
2. Apply the documentation or metadata change.
3. Wait for the target surface to be crawlable or indexed.
4. Rerun the same prompts.
5. Save after screenshots or exports with filenames that include date, system,
   and prompt ID.
6. Link evidence paths from the measurement log.

Suggested private evidence path:

```text
evidence/geo/YYYY-MM-DD/<system>/<prompt-id>.png
```

## KPI Reporting

Report these KPIs in launch or release notes when relevant:

| KPI | Definition |
| --- | --- |
| AI visibility rate | Target prompts where codex-profiles appears in the answer or citations divided by total tested prompts. |
| Citation count | Number of cited URLs pointing to the official project page, GitHub repository, npm package, README, or security policy. |
| Citation position | First visible position of a codex-profiles citation when the system exposes citation order. |
| Brand accuracy | Percentage of answers that correctly state package name, command names, affiliation, security boundary, and install commands. |
| Outcome path | Observable downstream action, such as GitHub visits, npm installs, Homebrew installs, issue creation, or discussion activity. |

## Review Cadence

Retest after each release, major README change, public listing campaign, or
GitHub Pages update. If no product changes ship, retest monthly.
