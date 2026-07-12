# Launch Playbook

Use this when sharing `codex-profiles` with developer communities. The goal is
developer credibility first: clear problem, quick install, concrete demo, and
public feedback loops.

## Current Handoff

- Live operating file: `LAUNCH.md`.
- Full historical evidence: [`archive/launch-ledger-history.md`](archive/launch-ledger-history.md).
- Current outreach posture: broad near-identical awesome-list PRs are paused.
  Prefer issue-first unless the target is Codex-specific, explicitly requests
  Codex CLI or ChatGPT Desktop workflow tooling, or has a structured registry/package
  format.
- Product-copy freeze: do not resume promotion until v0.7.0 is published and
  the signed ChatGPT app test matrix passes. Existing listings that describe
  Codex app clones or Codex-only Desktop switching need correction after the
  release; preserve their historical submission records.
- Before any PR or issue-to-PR conversion, follow the template-compliance gate
  below and record the inspected paths/checks in this ledger.
- Treat every "last ledger status" row as stale until reverified with GitHub
  CLI or the target site. Do not duplicate existing issues or PRs.

## Positioning

One-line pitch:

> Use named Codex homes and ChatGPT windows with separate local state, without
> copying token files or modifying the signed app.

Best audience:

- Developers using Codex across work, personal, education, or client contexts.
- ChatGPT desktop users who need named local windows across Chat, Work, and
  Codex, with matching Codex homes.
- CLI users who already understand why local-state separation matters.

Avoid positioning it as:

- An official OpenAI project.
- A full security sandbox for external tools like SSH, GitHub CLI, npm, AWS, or
  browser credentials.
- A replacement for Codex config profiles.
- A server-side ChatGPT workspace, plan, history, memory, connector, or policy
  switcher.
- A tool that verifies that CLI and Desktop sessions use the same account.
- A Codex-mode-only Desktop switcher: named `app` launches affect the whole
  ChatGPT window.

## Launch Readiness

- GitHub releases are published for tagged versions.
- The npm registry package is published as `codex-profile`.
- GitHub Discussions are enabled for questions and workflow feedback.
- Public feedback thread:
  <https://github.com/Ducksss/codex-profiles/discussions/1>
- Repo topics include `ai-tools`, `automation`, `bash`, `chatgpt`, `cli`,
  `codex`, `codex-cli`, `chatgpt-desktop`, `codex-profiles`,
  `developer-tools`, `linux`, `macos`, `openai`, `openai-codex`,
  `productivity`, `shell-script`, and `vibe-coding`.
- Install paths:

```sh
npm install -g codex-profile
```

```sh
brew install Ducksss/tap/codex-profile
```

```sh
git clone https://github.com/Ducksss/codex-profiles.git
cd codex-profiles
make install
```

The npm package is singular: `codex-profile`. It installs both
`codex-profile` and `codex-profiles` commands. Do not point users at the
plural npm package name because that package belongs to another project.

Quick verification:

```sh
codex-profile doctor
codex-profile path personal
```

Npm registry verification:

```sh
npm install -g codex-profile
codex-profile doctor
```

## Release Gate

Before a live release, complete the current signed-app matrix:

1. `app default` preserves the existing stock session.
2. A named profile persists across relaunches.
3. Two different names run concurrently without local-state crossover.
4. Chat, Work, and Codex stay in the same named window context.
5. CLI commands do not switch any open Desktop window.
6. The installed signed application remains byte-for-byte unchanged.

Run the `Release` workflow with its default `dry_run: true` first. That path
rehearses the complete behavior/lint suite, standalone fixture installer,
Homebrew formula transformation, pinned AUR metadata and package, npm tarball
installation, and complete clean-tree check. It runs with read-only repository
permissions and no persisted checkout credential. It never tags, publishes,
pushes a tap, creates a GitHub Release, or deploys Pages.

For `dry_run: false`, the only permitted
`desktop_smoke_attestation` contents are the public app version and bundle ID,
formatted exactly as:

```text
ChatGPT version 1.2026.168; bundle ID com.openai.codex
```

Substitute the installed public values. The version must have two or three
dot-separated numeric components; the bundle ID must start with `com.openai.`
and contain only safe alphanumeric, dot, or hyphen segments. Whitespace around
the value, newlines, and any extra text are rejected. Never include account
names or identifiers, email addresses, screenshots, tokens, cookies, histories,
logs, or private paths. A live run refuses missing or malformed evidence. It
then starts a separate write-capable job, rechecks the verified commit against
the current `origin/main` and remote tag, retries the published npm version with
bounded backoff in a fresh prefix, verifies both command aliases and the exact
GitHub Release tag, checks the tagged AUR files and Homebrew formula before tap
push, and requires a newly created immutable-tag Pages run plus its visible site
version. This repository validates AUR metadata, but external AUR publication
remains a maintainer action. Before creating the tag, the live job authenticates
the npm token and its package ownership, then authenticates a dedicated
fine-grained tap token and requires reported push access to
`Ducksss/homebrew-tap`; the tap token should select only that repository with
Contents read/write.

## Channel Copy

Do not publish this copy until the v0.7.0 release gate passes. The word `work`
in examples is a user-selected name, not the ChatGPT mode named Work.

Hacker News `Show HN` title:

```text
Show HN: codex-profiles - named Codex homes and ChatGPT desktop windows
```

Hacker News body:

```text
I built codex-profiles because copying auth.json between work, personal, and
education contexts is brittle. The wrapper gives each name its own CODEX_HOME.
On macOS, a named app launch also gets separate local Electron data for the
whole ChatGPT window across Chat, Work, and Codex.

Install:
npm install -g codex-profile
brew install Ducksss/tap/codex-profile

Examples:
codex-profile login personal
codex-profile cli work exec "review this repo"
codex-profile app edu

The default app profile preserves the stock ChatGPT session. Named windows use
the original signed app without cloning or re-signing it. CLI and Desktop can
authenticate separately; the tool does not inspect whether they match.

It is MIT-licensed, dependency-free, and tested on macOS + Ubuntu. It is not an
official OpenAI project, OS sandbox, or server-side workspace switcher.
Local-state separation is not an account, OS, or server-side boundary.
```

OpenAI Developer Community post:

```text
I made a tiny open-source helper for anyone using Codex and ChatGPT Desktop
across work, personal, education, or client contexts:
codex-profiles.

Instead of copying auth.json around, it selects a named CODEX_HOME for Codex.
On macOS, named app launches also use separate local Electron data for the
whole ChatGPT window:

npm install -g codex-profile
brew install Ducksss/tap/codex-profile
codex-profile login work
codex-profile cli work exec "review this repo"
codex-profile app personal

`app default` keeps the stock ChatGPT session. Named windows run through the
original signed app and can coexist. CLI and Desktop authentication remain
separate and are not compared. Feedback from other multi-account users would
be useful:
https://github.com/Ducksss/codex-profiles
```

DEV / Hashnode title:

```text
Named Codex homes and ChatGPT desktop windows without token copying
```

Short social post:

```text
Built codex-profiles: a tiny Bash wrapper for named Codex homes and ChatGPT
windows with separate local state.

No token copying or app re-signing. CLI commands remain Codex-only; named app
launches apply across Chat, Work, and Codex in that window.

npm install -g codex-profile
brew install Ducksss/tap/codex-profile
https://github.com/Ducksss/codex-profiles
```

Product Hunt tagline:

```text
Named Codex homes and ChatGPT windows without token copying
```

Product Hunt first comment:

```text
codex-profiles is a small open-source tool for developers who use Codex and
ChatGPT Desktop across work, personal, education, or client contexts. Each name
selects a CODEX_HOME; on macOS, a named app launch also selects local Electron
data for the whole ChatGPT window.

The design goal is boring and inspectable: no token parsing, no token copying,
no app clones or re-signing, and no runtime dependencies. `app default` keeps
the stock ChatGPT session. CLI and Desktop accounts may differ and are not
inspected or compared.
```

## Launch Order

1. Share in OpenAI/Codex developer spaces and collect practical feedback.
2. Post `Show HN` after confirming the npm registry install and Homebrew tap
   install both work.
3. Publish the DEV/Hashnode technical write-up and link back to the HN thread
   only as context, not as vote solicitation.
4. Publish new sanitized integrated-ChatGPT media only after the current
   signed-app behavior is validated. Do not reuse the pre-integration clone
   demo as current product evidence.
5. Submit to relevant curated lists or tool directories only where the tool
   clearly fits.
6. Launch on Product Hunt after the README, install paths, whole-window scope
   copy, and sanitized current media have all been verified.

## Distribution Channel Tracking

This section is the live queue for future agents. The detailed historical
ledger was archived to
[`archive/launch-ledger-history.md`](archive/launch-ledger-history.md) on
2026-06-10.

Update rule:

- Keep `LAUNCH.md` short: current status, link, owner-visible next action.
- Put long evidence, clone notes, screenshots, and per-target research in the
  archive or a dated companion note.
- Use exact dates for status claims. Use "last ledger status" when a link has
  not been rechecked in the current pass.
- Do not remove active links until they are merged, closed, withdrawn, or
  intentionally abandoned with a dated reason.

### Current Policy Gates

- Broad awesome-list PRs remain paused after Taskade declined PR #22 on
  2026-06-02 and cited the pattern of near-identical `Add codex-profiles` PRs.
- Direct PRs are allowed only when the target is Codex-specific, explicitly
  requests Codex CLI or ChatGPT Desktop workflow tooling, or has a structured registry or
  package format that the project cleanly satisfies.
- Issue-first is the default for broad or ambiguous lists, especially while the
  external open-PR backlog remains high.
- Before opening any PR or converting an issue to a PR, inspect PR templates,
  issue templates, `CONTRIBUTING*`, README contribution sections, recent
  accepted PRs, duplicate PRs/issues, category/sort rules, metadata files, and
  required checks.
- Use target templates verbatim. Preserve headings and checkboxes. Mark `N/A`
  only when it is genuinely true. If a template cannot be satisfied truthfully,
  skip or use issue-first if allowed.

### Priority Follow-Up

| Priority | Target | Last ledger status | Link | Next action |
| - | - | - | - | - |
| P0 | Awesome Codex CLI | Replacement PR open on 2026-06-02 | <https://github.com/RoggeOhta/awesome-codex-cli/pull/40> | Monitor; respond only to maintainer feedback. |
| P0 | CLIhub | PR open on 2026-06-02 | <https://github.com/clihub-ai/clihub/pull/4> | Monitor registry review; preserve schema/tests if changes are requested. |
| P0 | Awesome Agentic Coding CLI | PR open on 2026-06-02 | <https://github.com/yubing744/awesome-agentic-coding-cli/pull/3> | Monitor; do not use this as a template for broad list PRs. |
| P0 | Awesome CLI Apps in a CSV | PR open on 2026-06-02 | <https://github.com/toolleeo/awesome-cli-apps-in-a-csv/pull/267> | Monitor structured CSV submission. |
| P0 | OpenAI Developer Community | Existing Codex / Codex CLI topic reverified by forum search on 2026-06-11 | <https://community.openai.com/t/codex-profiles-switch-codex-accounts-without-copying-auth-json/1380415> | Monitor replies; do not repost duplicate topic. |
| P1 | Hacker News Show HN | Submit attempt and same-day retry reached HN temporary Show HN restriction page on 2026-06-11 | <https://news.ycombinator.com/showlim> | Retry only after account/community readiness; do not bypass restriction. |
| P1 | Product Hunt | Launch draft fully prepared on 2026-06-23; scheduling the Jun 24 launch returned a Product Hunt 403 after confirmation | <https://www.producthunt.com/posts/new/submission> | Finish scheduling manually in the open browser tab or retry once Product Hunt clears the 403; avoid duplicate listing. |
| P1 | Unikorn.vn | Product submitted on 2026-06-24; Unikorn shows `codex-profiles` pending AI/manual review after accepting logo, screenshots, category, tags, tech stack, and GitHub link | <https://unikorn.vn/p/codex-profiles> | Monitor approval notification or profile page; publish the public link after approval. |
| P1 | OpenAgent.bot | No exact-name listing found in sitemap on 2026-06-22 after 2026-06-02 submission | <https://www.openagent.bot/submit/> | Wait for editorial review or contact response; do not resubmit blindly. |
| P1 | CLIHunt | No exact-name listing found on homepage on 2026-06-22 after 2026-06-02 submission | <https://clihunt.dev/> | Wait or contact before duplicate submission. |
| P2 | ToolHunter | Draft deferred on 2026-06-02 | <https://toolhunter.ai/submit-a-tool> | Resume only with an approved project contact email. |

### Broad Open PR Backlog

These PRs are historical submissions from before the broad-list pause. Reverify
state before touching them, avoid new broad-list PRs, and consider withdrawal if
maintainer feedback suggests reputation risk.

| Target | Last ledger status | Link | Next action |
| - | - | - | - |
| Awesome DevTools | PR open on 2026-06-02 | <https://github.com/devtoolsd/awesome-devtools/pull/230> | Monitor only. |
| Awesome AI Coding Tools | PR open on 2026-06-02 | <https://github.com/ai-for-developers/awesome-ai-coding-tools/pull/330> | Monitor only. |
| Awesome Terminals AI | PR open on 2026-06-02 | <https://github.com/BNLNPPS/awesome-terminals-ai/pull/8> | Monitor only. |
| Awesome Vibe Coding by bluegalaxy111 | PR open on 2026-06-02 | <https://github.com/bluegalaxy111/awesome-vibe-coding/pull/8> | Monitor only. |
| Awesome OpenAI Codex | PR open on 2026-06-02 | <https://github.com/vaderyang/awesome-openai-codex/pull/2> | Monitor only. |
| Awesome OpenAI Codex CLI by taahro | PR open on 2026-06-02 | <https://github.com/taahro/awesome-openai-codex-cli/pull/3> | Monitor only. |
| Awesome Agentic Coding by tranhoangpich | Still inaccessible on 2026-06-22 | <https://github.com/tranhoangpich/awesome-agentic-coding/pull/3> | Treat as dead unless the repo reappears. |
| Awesome CLI Coding Agents | PR open on 2026-06-02 | <https://github.com/bradAGI/awesome-cli-coding-agents/pull/90> | Monitor only. |
| Awesome AI Dev Tools | PR open on 2026-06-02 | <https://github.com/PierrunoYT/awesome-ai-dev-tools/pull/26> | Monitor only. |
| Awesome AI Coding Assistants Playbook | PR open on 2026-06-02 | <https://github.com/CodandoTV/awesome-ai-coding-assistants-playbook/pull/8> | Monitor only. |
| Awesome AI Coding by wsxiaoys | PR open on 2026-06-02 | <https://github.com/wsxiaoys/awesome-ai-coding/pull/103> | Monitor only. |
| Awesome Harness Engineering | PR open on 2026-06-02 | <https://github.com/walkinglabs/awesome-harness-engineering/pull/28> | Monitor only. |
| Awesome Vibe Coding by ai-for-developers | PR open on 2026-06-02 | <https://github.com/ai-for-developers/awesome-vibe-coding/pull/64> | Monitor only. |
| Awesome Vibe Coding by filipecalegario | PR open on 2026-06-02 | <https://github.com/filipecalegario/awesome-vibe-coding/pull/187> | Monitor only. |
| Awesome AI DevTools by jamesmurdza | PR open on 2026-06-02 | <https://github.com/jamesmurdza/awesome-ai-devtools/pull/554> | Monitor only. |
| Awesome Vibe Coding Tools by jiji262 | PR open on 2026-06-02 | <https://github.com/jiji262/awesome-vibe-coding-tools/pull/22> | Monitor only. |
| Awesome Vibe Coding by 0xWelt | PR open on 2026-06-02 | <https://github.com/0xWelt/Awesome-Vibe-Coding/pull/176> | Monitor only. |
| Awesome OpenAI Codex by KarelDO | PR open on 2026-06-02 | <https://github.com/KarelDO/awesome-codex/pull/15> | Monitor only. |
| Awesome Vibe Coding Tools by furudo-erika | PR open on 2026-06-02 | <https://github.com/furudo-erika/awesome-vibe-coding-tools/pull/4> | Monitor only. |
| LaunchApp Awesome AI Coding Tools | Existing prior PR found on 2026-06-02 | <https://github.com/launchapp-dev/awesome-ai-coding-tools/pull/8> | Monitor or withdraw if broad-list reputation risk rises. |

### Issue-First Queue

Convert any of these to a PR only after maintainer confirmation and a fresh
pass through the template-compliance gate.

| Target | Last ledger status | Link | Next action |
| - | - | - | - |
| Awesome Vibe Coding by no-fluff | Issue open on 2026-05-22 | <https://github.com/no-fluff/awesome-vibe-coding/issues/115> | Wait for maintainer scope confirmation. |
| Awesome Codex Agents by AlexZander-666 | Issue open on 2026-06-09 | <https://github.com/AlexZander-666/awesome-codex-agents/issues/2> | Wait for maintainer scope confirmation. |
| Awesome AI Coding Tools by furudo-erika | Issue open on 2026-06-09 | <https://github.com/furudo-erika/awesome-ai-coding-tools/issues/6> | Wait for maintainer scope confirmation. |
| Awesome AI Coding Tools by runaicode | Issue open on 2026-06-09 | <https://github.com/runaicode/awesome-ai-coding-tools/issues/4> | Wait for maintainer scope confirmation. |
| Awesome AI Developer Tools by ColinEberhardt | Issue open on 2026-06-09 | <https://github.com/ColinEberhardt/awesome-ai-developer-tools/issues/30> | Wait for maintainer scope confirmation. |
| Awesome Vibe Coding by tysoncung | Issue open on 2026-06-09 | <https://github.com/tysoncung/awesome-vibe-coding/issues/6> | Wait for maintainer scope confirmation. |
| Awesome AI Coding Tools by Icloudeng | Issue open on 2026-06-09 | <https://github.com/Icloudeng/awesome-ai-coding-tools/issues/11> | Wait for maintainer scope confirmation. |
| Awesome AI Coding Tools by tomrzv | Issue open on 2026-06-09 | <https://github.com/tomrzv/Awesome-AI-Coding-Tools/issues/8> | Wait for maintainer scope confirmation. |
| Awesome AI Coding Tools by danielrosehill | Issue open on 2026-06-09 | <https://github.com/danielrosehill/Awesome-AI-Coding-Tools/issues/6> | Wait for maintainer scope confirmation. |
| Awesome AI Coding Tools by tyler-j-dao | Issue open on 2026-06-09 | <https://github.com/tyler-j-dao/awesome-ai-coding-tools/issues/5> | Wait for maintainer scope confirmation. |
| Awesome Vibe Coding by tangyuan-dev | Issue open on 2026-06-09 | <https://github.com/tangyuan-dev/awesome-vibe-coding/issues/1> | Wait for maintainer scope confirmation. |
| Awesome AI Coding Tools 2026 by kax168 | Issue open on 2026-06-09 | <https://github.com/kax168/awesome-ai-coding-tools-2026/issues/4> | Wait for maintainer scope confirmation. |
| Awesome AI Coding Tools by dingjiu1989-hue | Issue open on 2026-06-09 | <https://github.com/dingjiu1989-hue/awesome-ai-coding-tools/issues/3> | Wait for maintainer scope confirmation. |
| Awesome AI DevTools by Ravi-Chandraa | Issue open on 2026-06-09 | <https://github.com/Ravi-Chandraa/awesome-ai-devtools/issues/2> | Wait for maintainer scope confirmation. |
| Awesome AI DevTools Multilingual | Issue open on 2026-06-09 | <https://github.com/buainoai/awesome-ai-devtools-multilingual/issues/12> | Confirm scope and language coverage before PR. |
| Awesome AI DevTools by yasir27uk | Issue open on 2026-06-09 | <https://github.com/yasir27uk/awesome-ai-devtools/issues/1> | Wait for maintainer scope confirmation. |
| Awesome Coding Agents by quome-cloud | Issue open on 2026-06-09 | <https://github.com/quome-cloud/awesome-coding-agents/issues/7> | Wait for maintainer scope confirmation. |
| Awesome Coding Agents by wdzhwsh4067 | Issue open on 2026-06-09 | <https://github.com/wdzhwsh4067/awesome-coding-agents/issues/4> | Wait for maintainer scope confirmation. |
| Awesome Vibe Coding by YuyaoGe | Issue open on 2026-06-09 | <https://github.com/YuyaoGe/Awesome-Vibe-Coding/issues/8> | Wait for maintainer scope confirmation. |
| Awesome Vibe Coding by vibe-coding-labs | Issue open on 2026-06-09 | <https://github.com/vibe-coding-labs/awesome-vibe-coding/issues/1> | Wait for maintainer scope confirmation. |
| Awesome Code Agents by EuniAI | Issue open on 2026-06-22 | <https://github.com/EuniAI/awesome-code-agents/issues/299> | Wait for maintainer scope confirmation. |
| Awesome Code Agents by sorrycc | Issue open on 2026-06-22 | <https://github.com/sorrycc/awesome-code-agents/issues/32> | Wait for maintainer scope confirmation. |
| Awesome Terminal Agents | Issue open on 2026-06-22 | <https://github.com/EnigmaYYYY/awesome-terminal-agents/issues/1> | Wait for maintainer scope confirmation. |
| Awesome AI Developer Tools by ayushrajdev9-cmyk | Issue open on 2026-06-22 | <https://github.com/ayushrajdev9-cmyk/awesome-ai-developer-tools/issues/4> | Wait for maintainer scope confirmation. |
| Awesome AI Coding Tools by klymaxltd-ctrl | Issue open on 2026-06-22 | <https://github.com/klymaxltd-ctrl/awesome-ai-coding-tools/issues/3> | Wait for maintainer scope confirmation. |
| Awesome AI Coding Tools by KnoSkillz | Issue open on 2026-06-22 | <https://github.com/KnoSkillz/awesome-ai-coding-tools/issues/1> | Wait for maintainer scope confirmation. |
| Awesome AI DevTools by tamilselvanarjun | Issue open on 2026-06-22 | <https://github.com/tamilselvanarjun/awesome-ai-devtools/issues/3> | Wait for maintainer scope confirmation. |
| Awesome AI Developer Tools by dbpunk-labs | Issue open on 2026-06-22 | <https://github.com/dbpunk-labs/awesome-ai-developer-tools/issues/4> | Wait for maintainer scope confirmation. |
| Awesome Agentic Coding by Supersynergy | Issue open on 2026-06-22 | <https://github.com/Supersynergy/awesome-agentic-coding/issues/1> | Wait for maintainer scope confirmation. |
| Awesome Coding Agents by tiennm99 | Issue open on 2026-06-22 | <https://github.com/tiennm99/awesome-coding-agents/issues/2> | Wait for maintainer scope confirmation. |
| Awesome Coding Agents by closedloop-technologies | Issue open on 2026-06-22 | <https://github.com/closedloop-technologies/awesome-coding-agents/issues/5> | Wait for maintainer scope confirmation. |
| Awesome Coding Agents by outer-joined | Issue open on 2026-06-22 | <https://github.com/outer-joined/awesome-coding-agents/issues/1> | Wait for maintainer scope confirmation. |
| Awesome Coding Agents by Caldalis | Issue open on 2026-06-22 | <https://github.com/Caldalis/awesome-coding-agents/issues/1> | Wait for maintainer scope confirmation. |
| Awesome Agentic Coding by fecet | Issue open on 2026-06-22 | <https://github.com/fecet/awesome-agentic-coding/issues/1> | Wait for maintainer scope confirmation. |
| Awesome Agentic Coding by li0nel | Issue open on 2026-06-22 | <https://github.com/li0nel/awesome-agentic-coding/issues/1> | Wait for maintainer scope confirmation. |

### Manual Or Gated Directories

| Target | Last ledger status | Link | Next action |
| - | - | - | - |
| StackShare | Deferred on 2026-05-14 | <https://stackshare.io/tools/new> | Requires stable browser and GitHub OAuth. |
| OpenAlternative | Deferred on 2026-05-14 | <https://openalternative.co/submit> | Requires sign-in. |
| LibHunt | Deferred on 2026-05-14 | <https://www.libhunt.com/repo/submit> | Requires stable browser; position as alternative to a relevant project. |
| SaaSHub | Deferred on 2026-05-14 | <https://www.saashub.com/services/submit> | Requires stable browser and verification. |
| Gated targets | Gated 2026-06-02 | See archive | Requires account setup. |

### Accepted Or Listed

No current action unless a listed link breaks or a maintainer requests changes.

- Verified accepted/listed by 2026-06-02:
  <https://github.com/milisp/awesome-codex-cli/pull/30>,
  <https://github.com/QAInsights/awesome-ai-tools/pull/54>,
  <https://github.com/darknorth-123/Awesome-Codex-Plugins/pull/2>,
  <https://github.com/namphuongtran/awesome-ai-coding-agent-tools/pull/4>,
  <https://github.com/dalisoft/awesome-ai-coding/pull/65>, and
  <https://github.com/acvnace/awesome-vibe-coding-resources/pull/20>.
- Verified independently listed on 2026-06-11:
  <https://github.com/Jenqyang/Awesome-AI-Agents> includes `codex-profiles`
  in its Tools section.
- Verified accepted/listed on 2026-06-22:
  <https://github.com/eltociear/awesome-AI-driven-development/pull/52>,
  <https://github.com/yeaight7/awesome-ai-devtools/pull/11>, and
  <https://github.com/adriannoes/awesome-vibe-coding/pull/4>. The related
  yeaight7 issue #8 and adriannoes issue #3 are closed as completed.
- Closed or declined items, skipped targets, rejected fits, and detailed
  validation logs are archived in
  [`archive/launch-ledger-history.md`](archive/launch-ledger-history.md).

## Outreach Candidate Backlog

The detailed 50-repository discovery table is archived. Do not use archived
candidates directly for new outreach; treat them as stale leads.

Current backlog posture:

- The June 9 passes already opened 20 targeted maintainer issues. Do not create
  duplicate issues or PRs for those repositories.
- 2026-06-11 fresh discovery note: `vanna-ai/Awesome-Vibe-Coding-CLI` is a
  possible but lower-priority CLI list with stale open PRs; use issue-first or
  wait for maintainer activity. `techiediaries/awesome-vibe-coding` is broad
  and has a stale open-PR backlog; skip unless maintainers become active.
  `onurkanbakirci/awesome-codex-automations` is Codex-specific but scoped to
  automation templates, not profile-switching tooling.
- Remaining uncontacted candidates from the archived table were lower-confidence
  or deferred. Re-run discovery and duplicate checks before using any of them.
- For each new candidate, record only: repository, fit reason, inspected
  template/guideline paths, duplicate terms, chosen channel, and next action.
- Skip targets with disabled issues and no credible contribution flow, generic
  raw-ZIP download pages, archived repositories, or rules that prohibit the
  submission.

## Monthly Reconciliation

Keep this list compact. Full dated notes are archived.

- 2026-06-22, 15-repo issue-first outreach wave: opened scope-check issues
  with no PRs and no directory submissions. Targets had issues enabled, no
  visible issue templates, and no duplicate `codex-profile(s)` issue/PR history
  in fresh checks. Opened:
  <https://github.com/EuniAI/awesome-code-agents/issues/299>,
  <https://github.com/sorrycc/awesome-code-agents/issues/32>,
  <https://github.com/EnigmaYYYY/awesome-terminal-agents/issues/1>,
  <https://github.com/ayushrajdev9-cmyk/awesome-ai-developer-tools/issues/4>,
  <https://github.com/klymaxltd-ctrl/awesome-ai-coding-tools/issues/3>,
  <https://github.com/KnoSkillz/awesome-ai-coding-tools/issues/1>,
  <https://github.com/tamilselvanarjun/awesome-ai-devtools/issues/3>,
  <https://github.com/dbpunk-labs/awesome-ai-developer-tools/issues/4>,
  <https://github.com/Supersynergy/awesome-agentic-coding/issues/1>,
  <https://github.com/tiennm99/awesome-coding-agents/issues/2>,
  <https://github.com/closedloop-technologies/awesome-coding-agents/issues/5>,
  <https://github.com/outer-joined/awesome-coding-agents/issues/1>,
  <https://github.com/Caldalis/awesome-coding-agents/issues/1>,
  <https://github.com/fecet/awesome-agentic-coding/issues/1>, and
  <https://github.com/li0nel/awesome-agentic-coding/issues/1>. Skipped quick
  candidates with issues disabled, duplicate PR history, or narrower plugin,
  skill, ACP, pet, paper, prompt, or raw-rule scope.
- 2026-06-22, GitHub status audit: verified
  <https://github.com/eltociear/awesome-AI-driven-development/pull/52> and
  <https://github.com/yeaight7/awesome-ai-devtools/pull/11> are merged, and
  <https://github.com/adriannoes/awesome-vibe-coding/issues/3> closed after
  maintainer PR <https://github.com/adriannoes/awesome-vibe-coding/pull/4>
  merged. Moved those items out of active follow-up. Rechecked
  <https://github.com/tranhoangpich/awesome-agentic-coding/pull/3>; it remains
  inaccessible. Exact-name checks still found no OpenAgent.bot or CLIHunt
  listing. External comments/submissions: 0.
- 2026-06-11, current outreach wave: opened
  <https://github.com/yeaight7/awesome-ai-devtools/pull/11>, replied on
  <https://github.com/adriannoes/awesome-vibe-coding/issues/3>, checked
  OpenAgent.bot sitemap/search and CLIHunt API search, reverified the existing
  OpenAI Developer Community topic, and attempted Hacker News Show HN. HN
  redirected to its temporary `showlim` restriction page before publishing;
  the same-day retry reached the normal submit form but redirected back to
  `showlim` after submit.
  External submissions: 1 PR, 1 issue comment, 0 directory resubmissions,
  0 new forum posts, 0 HN posts published.
- 2026-06-10, this pruning pass: archived full ledger history and slimmed
  `LAUNCH.md` for next-agent handoff. External submissions: 0.
- 2026-06-10, <https://github.com/Ducksss/codex-profiles/pull/12>: added the
  mandatory template/contribution-guideline compliance gate. External
  submissions: 0.
- 2026-06-09, <https://github.com/Ducksss/codex-profiles/pull/11>: opened 10
  additional maintainer-scope issues. New PRs: 0.
- 2026-06-09, <https://github.com/Ducksss/codex-profiles/pull/8>: opened 10
  maintainer-scope issues. New PRs: 0.
- 2026-06-02, `PinZheng/distribution-pass-2026-06-02`: opened 2 PRs, submitted
  to OpenAgent.bot and CLIHunt, and paused broad-list PRs after maintainer
  warning.
- 2026-05-21/22, `pinzheng/update-launch-pr-log`: reconciled open PRs and
  added a limited high-signal outreach wave.
- 2026-05-18, archived automation pass: established the original distribution
  ledger and later open-PR gate.

## Metrics

Track these for each channel:

- GitHub stars and watchers.
- Unique cloners.
- Release downloads.
- Homebrew tap installs or GitHub traffic to `Ducksss/homebrew-tap`.
- GitHub Discussions comments.
- Issues opened by real users.
- Follow-up links from newsletters, directories, and curated lists.

Success signal:

- A developer can understand the problem in under 10 seconds.
- A new user can install and run `codex-profile doctor` without reading source.
- Feedback is about real workflows, not basic project trust or install friction.
