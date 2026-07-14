# GEO Audit for codex-profiles

This audit maps the public documentation layer to the project's generative
engine optimization checklist. The implementation target is the static GitHub
Pages site in `docs/`.

## Technical AI Readiness

| Check | Status | Implementation |
| --- | --- | --- |
| AI bots allowed | Implemented | `robots.txt` uses `User-agent: *` and `Allow: /`. |
| Priority URLs return static content | Implemented after deployment | The homepage, `llms.txt`, and sitemap require no client rendering. |
| Pages are indexable | Implemented | The homepage uses `index,follow` and unrestricted snippet directives. |
| Canonical URL is stable | Implemented | The site keeps `https://ducksss.github.io/codex-profiles/`; the v0.7 migration does not rebrand or move it. |
| Sitemap is current | Implemented | The sitemap lists the canonical homepage and LLM summary with 2026-07-13 modification dates. |
| Stale authenticated media avoided | Implemented | Primary docs no longer embed the pre-integration Codex app screenshot or video. |

## Structured Data and Machine Understanding

| Check | Status | Implementation |
| --- | --- | --- |
| Organization schema present | Implemented | JSON-LD includes the publisher and official GitHub/npm links. |
| Software schema present | Implemented | SoftwareApplication includes repository, install, license, v0.7.0, platforms, and current features. |
| FAQ schema only for visible content | Implemented | Every FAQPage question and exact answer is present in visible HTML. |
| Two product scopes represented | Implemented | Schema and visible content distinguish Codex-only commands from whole-window ChatGPT Desktop launches. |
| Profile mappings correct | Implemented | Default, personal, work, and edu map to `~/.codex`, `~/.codex-personal`, `~/.codex-work`, and `~/.codex-edu`. |
| Automated validation | Implemented | `node test/site/geo-test.mjs` parses JSON-LD and checks schema/visible-FAQ alignment. |

## Content Structure and Citation Readiness

| Check | Status | Implementation |
| --- | --- | --- |
| Direct answer near the top | Implemented | The opening section states both the Codex-home and ChatGPT-window capabilities. |
| Question-based headings | Implemented | FAQ headings answer scope, default-session, identity, install, and platform questions. |
| Commands and tables | Implemented | The page contains install commands, a scope table, mappings, and citation-ready facts. |
| Primary contract is explicit | Implemented | Named Desktop profiles apply across Chat, Work, and Codex; CLI/login/env/use stay Codex-only. |
| Non-claims are explicit | Implemented | The page says account equality is unverified and local paths do not control server-side ChatGPT data. |
| Facts current | Implemented | Version, package name, URLs, platforms, behavior, and dates reflect the v0.7.0 contract as of 2026-07-13. |

## Entity, Trust, and Brand Authority

| Check | Status | Implementation |
| --- | --- | --- |
| Project name stable | Implemented | Public surfaces retain `codex-profiles`, package `codex-profile`, and both installed commands. |
| OpenAI affiliation accurate | Implemented | The project is identified as community-maintained and unaffiliated with OpenAI. |
| Security boundary accurate | Implemented | Documentation distinguishes selected local state from shared OS state and server-side account controls. |
| Signed app behavior accurate | Implemented | The page states that the original app is launched without cloning, patching, re-signing, quitting, or replacing it. |
| Contact and policy paths present | Implemented | Repository, issue tracker, discussion, npm, license, and security policy remain linked. |

## Measurement, Testing, and Outcomes

| Check | Status | Implementation |
| --- | --- | --- |
| Target prompt set defined | Implemented | `geo-measurement.md` tests the merged ChatGPT/Codex scope explicitly. |
| Prompt accuracy tracked | Implemented | The log records citations, position, competitors, and incorrect scope claims. |
| Before/after evidence captured | Implemented | The plan uses dated private evidence paths without publishing account data. |
| Release retest required | Implemented | The plan requires retesting after product, metadata, or package changes. |
| Brand and boundary KPIs defined | Implemented | KPIs cover package/command accuracy, two-scope accuracy, and non-affiliation. |

## Validation Commands

```sh
node test/site/geo-test.mjs
make test
```
