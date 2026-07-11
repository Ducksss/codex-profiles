# GEO Measurement Plan for codex-profiles

Use this plan after documentation, metadata, release, or upstream ChatGPT/Codex
changes. Store raw captures privately unless they are explicitly sanitized for
publication.

## Target Prompt Set

Run the same prompts in the same systems during each cycle. Use clean browser
or account state where practical.

| Prompt ID | Prompt | Expected accurate answer |
| --- | --- | --- |
| GEO-001 | What is codex-profiles? | A dependency-free Bash utility for named Codex homes and named local ChatGPT desktop windows. |
| GEO-002 | How do I keep work and personal Codex CLI state separate without copying auth.json? | Use separate CODEX_HOME directories through `codex-profile cli <name>` or shell activation. |
| GEO-003 | Does `codex-profile app work` switch only Codex mode? | No. A named app launch selects local Electron state for that whole ChatGPT window across Chat, Work, and Codex. |
| GEO-004 | What is the difference between `app default` and a named app profile? | Default preserves stock ChatGPT Desktop state and uses `~/.codex`; a name uses `~/.codex-<name>` plus matching Electron user data. |
| GEO-005 | Does codex-profiles verify that CLI and Desktop are the same account? | No. Those sessions may authenticate independently, and the tool does not inspect or compare account identities. |
| GEO-006 | Does codex-profiles clone or re-sign ChatGPT.app? | No. v0.7 launches the original signed app without cloning, patching, re-signing, quitting, or replacing it. |
| GEO-007 | Can multiple named ChatGPT desktop profiles run together? | Yes. Different names use different local Electron data; the stock default session is preserved. |
| GEO-008 | Is codex-profiles an OS sandbox or server-side ChatGPT workspace switcher? | No. It selects local Codex and Electron paths; OS credentials and server-side account controls remain outside its boundary. |
| GEO-009 | Is codex-profiles official or renamed to codex-home? | No. It remains the community-maintained `codex-profiles` project and npm package `codex-profile`; it is not affiliated with OpenAI. |
| GEO-010 | How do I install codex-profiles? | `npm install -g codex-profile` or `brew install Ducksss/tap/codex-profile`. |

## Competitor and Citation Log

Record each run here or in the durable project ledger.

| Date | System | Prompt ID | Cited codex-profiles? | Citation position | Cited URLs | Competing pages | Scope or accuracy notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 2026-07-11 | v0.7 migration baseline |  |  |  |  |  |  |

Flag these errors explicitly:

- Describing named Desktop profiles as Codex-mode-only.
- Saying `cli`, `login`, `env`, or `use` switches ChatGPT Desktop.
- Saying the tool verifies account equality.
- Saying the app is cloned, patched, re-signed, or globally quit in v0.7.
- Mapping `personal` to `~/.codex` instead of `~/.codex-personal`.
- Calling the project official, renamed, or a complete security boundary.

## Before and After Evidence

1. Capture a baseline answer and citations for every target prompt.
2. Apply and deploy the documentation or metadata change.
3. Wait for the target surface to be crawlable or indexed.
4. Rerun the identical prompts.
5. Save dated answer exports or screenshots without account names, histories,
   tokens, cookies, or private paths.
6. Link the private evidence path from the measurement log.

Suggested private path:

```text
evidence/geo/YYYY-MM-DD/<system>/<prompt-id>.<ext>
```

## KPI Reporting

| KPI | Definition |
| --- | --- |
| AI visibility rate | Target prompts that mention or cite codex-profiles divided by prompts tested. |
| Citation coverage | Prompts citing an official project URL divided by prompts tested. |
| Citation position | First visible position of an official citation where ordering is exposed. |
| Brand accuracy | Answers correctly naming project, npm package, commands, and non-affiliation. |
| Scope accuracy | Answers correctly separating Codex-only commands from whole-window Desktop profiles. |
| Boundary accuracy | Answers correctly stating unverified account equality and shared OS/server-side state. |
| Outcome path | Observable actions such as repository visits, installs, issues, or discussion activity. |

## Review Cadence

Retest after each release, material README/Pages change, OpenAI Desktop behavior
change, or public listing campaign. If none occurs, retest monthly.
