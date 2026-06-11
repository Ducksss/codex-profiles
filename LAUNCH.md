# Launch Playbook

Use this when sharing `codex-profiles` with developer communities. The goal is
developer credibility first: clear problem, quick install, concrete demo, and
public feedback loops.

## Current Handoff

- Live operating file: `LAUNCH.md`.
- Full historical evidence: [`archive/launch-ledger-history.md`](archive/launch-ledger-history.md).
- Current outreach posture: broad near-identical awesome-list PRs are paused.
  Prefer issue-first unless the target is Codex-specific, explicitly requests
  Codex CLI/Desktop workflow tooling, or has a structured registry/package
  format.
- Before any PR or issue-to-PR conversion, follow the template-compliance gate
  below and record the inspected paths/checks in this ledger.
- Treat every "last ledger status" row as stale until reverified with GitHub
  CLI or the target site. Do not duplicate existing issues or PRs.

## Positioning

One-line pitch:

> Switch Codex CLI and Desktop accounts with isolated `CODEX_HOME` profiles,
> without copying token files by hand.

Best audience:

- Developers using Codex across work, personal, education, or client accounts.
- Codex Desktop users who need profile-local auth, config, sessions, plugins,
  logs, and connector state.
- CLI users who already understand why state isolation matters.

Avoid positioning it as:

- An official OpenAI project.
- A full security sandbox for external tools like SSH, GitHub CLI, npm, AWS, or
  browser credentials.
- A replacement for Codex config profiles.

## Launch Readiness

- GitHub releases are published for tagged versions.
- The npm registry package is published as `codex-profile`.
- GitHub Discussions are enabled for questions and workflow feedback.
- Public feedback thread:
  <https://github.com/Ducksss/codex-profiles/discussions/1>
- Repo topics include `ai-tools`, `automation`, `bash`, `chatgpt`, `cli`,
  `codex`, `codex-cli`, `codex-desktop`, `codex-home`, `codex-profiles`,
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

## Channel Copy

Hacker News `Show HN` title:

```text
Show HN: codex-profiles - switch Codex accounts without copying token files
```

Hacker News body:

```text
I built codex-profiles because switching between work, personal, and education
Codex accounts by copying auth.json is brittle. Codex already supports a custom
CODEX_HOME, so this small Bash wrapper gives each profile its own auth, config,
sessions, plugins, logs, and local state.

Install:
npm install -g codex-profile
brew install Ducksss/tap/codex-profile

Examples:
codex-profile login personal
codex-profile cli work exec "review this repo"
codex-profile app edu

It is MIT-licensed, dependency-free, and tested on macOS + Ubuntu. It is not an
official OpenAI project and it is not full OS-level isolation.
```

OpenAI Developer Community post:

```text
I made a tiny open-source helper for anyone using Codex with multiple accounts:
codex-profiles.

Instead of copying auth.json around, it launches Codex CLI or Codex Desktop with
a named CODEX_HOME:

npm install -g codex-profile
brew install Ducksss/tap/codex-profile
codex-profile login work
codex-profile cli work exec "review this repo"
codex-profile app personal

Each profile gets separate auth, config, sessions, plugins, logs, and local
Codex state. Feedback from other multi-account Codex users would be useful:
https://github.com/Ducksss/codex-profiles
```

DEV / Hashnode title:

```text
Stop copying Codex auth files: use separate CODEX_HOME profiles
```

Short social post:

```text
Built codex-profiles: a tiny Bash wrapper for switching Codex CLI/Desktop
accounts with isolated CODEX_HOME directories.

No token copying. Separate auth, config, sessions, plugins, logs, and local
Codex state.

npm install -g codex-profile
brew install Ducksss/tap/codex-profile
https://github.com/Ducksss/codex-profiles
```

Product Hunt tagline:

```text
Switch Codex accounts without copying token files
```

Product Hunt first comment:

```text
codex-profiles is a small open-source tool for developers who use Codex across
multiple accounts or contexts. It wraps Codex's CODEX_HOME support so each
profile has separate auth, config, sessions, plugins, logs, and local state.

The design goal is boring and safe: no token parsing, no token copying, no extra
runtime dependencies. It just launches Codex CLI or Codex Desktop with the
right environment.
```

## Launch Order

1. Share in OpenAI/Codex developer spaces and collect practical feedback.
2. Post `Show HN` after confirming the npm registry install and Homebrew tap
   install both work.
3. Publish the DEV/Hashnode technical write-up and link back to the HN thread
   only as context, not as vote solicitation.
4. Repost the short demo clip on X, Bluesky, Mastodon, and LinkedIn with the
   npm or Homebrew command and GitHub link.
5. Submit to relevant curated lists or tool directories only where the tool
   clearly fits.
6. Launch on Product Hunt after screenshots, demo video, README, and install
   path have all been click-tested.

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
  requests Codex CLI/Desktop workflow tooling, or has a structured registry or
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
| P0 | Awesome AI DevTools by yeaight7 | PR open on 2026-06-11 after maintainer green light | <https://github.com/yeaight7/awesome-ai-devtools/pull/11> | Monitor CI/review; PR closes issue #8. |
| P0 | OpenAI Developer Community | Existing Codex / Codex CLI topic reverified by forum search on 2026-06-11 | <https://community.openai.com/t/codex-profiles-switch-codex-accounts-without-copying-auth-json/1380415> | Monitor replies; do not repost duplicate topic. |
| P1 | Hacker News Show HN | Submit attempt reached HN temporary Show HN restriction page on 2026-06-11 | <https://news.ycombinator.com/showlim> | Retry only after account/community readiness; do not bypass restriction. |
| P1 | OpenAgent.bot | No public listing found in sitemap/search on 2026-06-11 after 2026-06-02 submission | <https://www.openagent.bot/submit/> | Wait for editorial review or contact response; do not resubmit blindly. |
| P1 | CLIHunt | No public listing found via API search on 2026-06-11 after 2026-06-02 submission | <https://clihunt.dev/> | Wait or contact before duplicate submission; API search returned 0. |
| P2 | ToolHunter | Draft deferred on 2026-06-02 | <https://toolhunter.ai/submit-a-tool> | Resume only with an approved project contact email. |

### Broad Open PR Backlog

These PRs are historical submissions from before the broad-list pause. Reverify
state before touching them, avoid new broad-list PRs, and consider withdrawal if
maintainer feedback suggests reputation risk.

| Target | Last ledger status | Link | Next action |
| - | - | - | - |
| Awesome DevTools | PR open on 2026-06-02 | <https://github.com/devtoolsd/awesome-devtools/pull/230> | Monitor only. |
| Awesome AI-Driven Development | PR open on 2026-06-02 | <https://github.com/eltociear/awesome-AI-driven-development/pull/52> | Monitor only. |
| Awesome AI Coding Tools | PR open on 2026-06-02 | <https://github.com/ai-for-developers/awesome-ai-coding-tools/pull/330> | Monitor only. |
| Awesome Terminals AI | PR open on 2026-06-02 | <https://github.com/BNLNPPS/awesome-terminals-ai/pull/8> | Monitor only. |
| Awesome Vibe Coding by bluegalaxy111 | PR open on 2026-06-02 | <https://github.com/bluegalaxy111/awesome-vibe-coding/pull/8> | Monitor only. |
| Awesome OpenAI Codex | PR open on 2026-06-02 | <https://github.com/vaderyang/awesome-openai-codex/pull/2> | Monitor only. |
| Awesome OpenAI Codex CLI by taahro | PR open on 2026-06-02 | <https://github.com/taahro/awesome-openai-codex-cli/pull/3> | Monitor only. |
| Awesome Agentic Coding by tranhoangpich | Inaccessible during 2026-06-02 reconciliation | <https://github.com/tranhoangpich/awesome-agentic-coding/pull/3> | Recheck existence before any action. |
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
| Awesome AI DevTools by yeaight7 | Maintainer green-lit PR on 2026-06-09; PR open on 2026-06-11 | <https://github.com/yeaight7/awesome-ai-devtools/issues/8> | PR #11 is open; no duplicate outreach. |
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
| Awesome Vibe Coding by adriannoes | Closed with maintainer inclusion plan and upstream-install reply posted on 2026-06-11 | <https://github.com/adriannoes/awesome-vibe-coding/issues/3> | Monitor maintainer PR; avoid duplicate snapshot unless requested. |

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

- 2026-06-11, current outreach wave: opened
  <https://github.com/yeaight7/awesome-ai-devtools/pull/11>, replied on
  <https://github.com/adriannoes/awesome-vibe-coding/issues/3>, checked
  OpenAgent.bot sitemap/search and CLIHunt API search, reverified the existing
  OpenAI Developer Community topic, and attempted Hacker News Show HN. HN
  redirected to its temporary `showlim` restriction page before publishing.
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
