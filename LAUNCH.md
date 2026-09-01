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
- Lead qualification gate: treat `codex-profiles` as an open-source developer
  CLI/Codex workflow tool, not a startup. Startup maps, founder directories,
  accelerator databases, investor networks, regional startup ecosystems, and
  generic launch boards stay out of active outreach unless they have a concrete
  developer-tool category that fits without unsupported company, geography, or
  funding claims.
- Before any PR or issue-to-PR conversion, follow the template-compliance gate
  below and record the inspected paths/checks in this ledger.
- Treat every "last ledger status" row as stale until reverified with GitHub
  CLI or the target site. Do not duplicate existing issues or PRs.
- 2026-07-13 stale-route conversion: three reviewed high/medium-fit direct PRs
  are open as drafts and clean: CodexForWork/awesome-codex-work#2,
  linsa-io/command-line-tools#40, and
  sudharsan-007/Awesome-DevTerminal#2. Monitor the PRs only; do not bump their
  original scope-check issues. Airtable target rows and three matching log
  records are current. Other reviewed routes remain issue-first because their
  inclusion criteria require an LLM client, coding agent, or agent integration
  that codex-profiles does not claim to provide.

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

- Airtable is the source of truth. `LAUNCH.md` is a compact handoff after the
  Airtable `Targets` and append-only `Log` records are current.
- Before any outreach, record an ICP decision. Keep `Backlog` only for clear
  `ICP: yes` targets, use `Deferred` for temporary blockers or strong
  `ICP: maybe` targets, and use `Dead` for permanent non-ICP mismatches.
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
| P0 | Awesome Codex CLI | PR open and clean on 2026-07-06 after 2026-07-01 bump | <https://github.com/RoggeOhta/awesome-codex-cli/pull/40> | Monitor; respond only to maintainer feedback. |
| P0 | CLIhub | PR open and clean on 2026-07-06 | <https://github.com/clihub-ai/clihub/pull/4> | Monitor registry review; no bump without maintainer activity. |
| P0 | Awesome Agentic Coding CLI | PR open and clean on 2026-07-06 after 2026-07-01 bump | <https://github.com/yubing744/awesome-agentic-coding-cli/pull/3> | Monitor; do not use this as a template for broad list PRs. |
| P0 | Awesome CLI Apps in a CSV | PR open and clean on 2026-07-06 after conflict fix | <https://github.com/toolleeo/awesome-cli-apps-in-a-csv/pull/267> | Monitor structured CSV submission. |
| P0 | OpenAI Developer Community | Existing Codex / Codex CLI topic reverified by forum search on 2026-06-11 | <https://community.openai.com/t/codex-profiles-switch-codex-accounts-without-copying-auth-json/1380415> | Monitor replies; do not repost duplicate topic. |
| P1 | Hacker News Show HN | URL-only Show HN posted on 2026-07-08 | <https://news.ycombinator.com/item?id=48828259> | Monitor comments; do not repost duplicate Show HN. |
| P1 | Product Hunt | Draft completed and successfully scheduled on 2026-07-07 for July 8, 2026 | <https://www.producthunt.com/posts/new/submission> | Monitor the July 8 launch; use the launch-day dashboard for replies only. |
| P1 | Unikorn.vn | Listed on 2026-07-02; URL redirected to site maintenance on 2026-07-06 | <https://unikorn.vn/p/codex-profiles> | Recheck after maintenance clears; do not resubmit blindly. |
| P1 | OpenAgent.bot | No exact-name listing found in sitemap on 2026-06-22 after 2026-06-02 submission | <https://www.openagent.bot/submit/> | Wait for editorial review or contact response; do not resubmit blindly. |
| P1 | CLIHunt | No exact-name listing found on homepage on 2026-06-22 after 2026-06-02 submission | <https://clihunt.dev/> | Wait or contact before duplicate submission. |
| P2 | ToolHunter | Authenticated free-quota draft filled on 2026-07-07; category widget did not accept typed category | <https://toolhunter.ai/profile?tab=submissions&action=new> | Resume only if the category widget can select an accepted category; use free quota only. |

### 2026-07-07 Authenticated Non-GitHub Submission Run

Airtable `Targets` and append-only `Log` rows are current for all 20 existing
non-GitHub targets. No GitHub outreach, paid action, badge/backlink action,
CAPTCHA bypass, or duplicate submission was made.

Submitted, scheduled, or posted:

- TinyLaunch: free Standard launch scheduled for Aug 10, 2026 and pending
  review. <https://www.tinylaunch.com/dashboard/launches/17489/success>
- Launching Next: free submission received as `i=139955`; in queue with a
  4-month estimate; $99 fast-track skipped.
  <https://www.launchingnext.com/thanks/?i=139955>
- Product Hunt: launch completed and successfully scheduled for July 8, 2026;
  no paid promotion or investor opt-in.
  <https://www.producthunt.com/posts/new/submission>
- Reddit r/codex: posted with Showcase flair.
  <https://old.reddit.com/r/codex/comments/1uqisp5/i_made_a_tiny_bash_wrapper_for_separate_codex/>

Drafted or attempted, then stopped:

- ProductWatch: product edit draft created, but metadata retrieval stayed stuck
  and no publish control appeared.
- J2TEAM Launch: form filled and submit clicked, but My Products stayed at 0.
- Smol Launch: product record created; free launch requires embedding their
  badge, so launch submission stopped.
- ToolHunter: free-quota draft filled; Continue stayed disabled because the
  category widget did not accept the typed Developer Tools category.
- StackShare: free List a Tool form completed with a square image, then rejected
  by the supported-category classifier; marked `Dead`.

Deferred blockers:

- DevHunt: current launch weeks were $49 and the form advertises a dofollow
  backlink.
- MicroLaunch: handoff tab still showed public Signup/New Launch only.
- Uneed and LibHunt: Cloudflare/Turnstile security checks.
- Peerlist Launchpad: `Get verified to Launch` gate.
- AlternativeTo: account finalization still required, with hCaptcha fields and
  a permanent username prompt.
- daily.dev: authenticated feed exposed Create Squad/Add to Feed; `/posts/new`
  returned 404.
- Indie Hackers: authenticated products page exposed no usable post/product
  submission path.
- Developer Kaki: no authenticated handoff tab; public path routes to the
  community/Facebook group.
- noobs.wiki: contact/community directory page only; no post path.
- Reddit r/commandline: requires subreddit rules agreement and flair before
  posting.

### 2026-07-08 Next Non-GitHub Outreach Batch

Airtable `Targets` and append-only `Log` rows are current for all 20 batch
targets with `Last Checked = 2026-07-08`. No GitHub outreach, paid action,
badge/backlink action, CAPTCHA/Cloudflare bypass, or forced weak-fit post was
made.

Submitted, posted, or pending review:

- OSS AI Hub: free repo submission sent to the review queue; no payment, badge,
  backlink, or CAPTCHA shown. <https://ossaihub.com/submit/>
- Hacker News Show HN: URL-only post published.
  <https://news.ycombinator.com/item?id=48828259>
- Reddit r/SideProject: value-first feedback post published.
  <https://old.reddit.com/r/SideProject/comments/1uqkhy1/codexprofiles_tiny_cli_for_separate_codex/>
- DEV Community: practical technical article published with `bash`, `cli`, and
  `ai` tags.
  <https://dev.to/chaipinzheng/isolating-codex-cli-and-desktop-profiles-with-codexhome-2ikj>

Drafted:

- None. Article routes were held unless there was a clear editor-ready path.

Skipped or deferred:

- Altern.ai: authenticated submit form filled, but submit stayed disabled until
  selecting a paid $19/$99 listing plan.
- Flaex AI: submit flow analyzed the URL, then only showed paid listing CTAs
  starting at $0.99.
- TAAFT: `/submit` redirected to `theresanaiforthat.com/launch/` and browser
  security policy blocked automation; no workaround attempted.
- Futurepedia: submit/check page stopped by Cloudflare; no bypass attempted.
- DevToolLab AI Tools, Hashnode, HackerNoon, DZone, and Lobsters: current
  authenticated state was still login, onboarding, registration, or invite
  gated.
- Medium, Level Up Coding, freeCodeCamp News, Towards AI, and Artificial
  Corner: article/publication routes held until there is a full suitable
  tutorial and canonical plan.
- Reddit r/SaaS: rules push feedback/promotional content to recurring threads;
  skipped standalone post.
- Reddit r/commandline: rules require agreement/flair and disallow weak/new or
  AI-related project posts unless clearly compliant; skipped standalone post.

Resolution cleanup:

- Dead: Altern.ai and Flaex AI are paid-only listing paths; Reddit r/SaaS is a
  poor standalone-post fit because rules push promotion/feedback to recurring
  threads.
- Deferred: TAAFT still redirects to a browser-policy-blocked launch page;
  Futurepedia remains Cloudflare-blocked; DevToolLab, Hashnode, HackerNoon,
  Lobsters, and Reddit r/commandline remain auth/onboarding/invite/rules gated.
- Backlog: Medium, Level Up Coding, DZone, freeCodeCamp News, Towards AI, and
  Artificial Corner are viable only with a full tutorial/canonical plan titled
  `How to Isolate Codex CLI and Desktop State with CODEX_HOME`.

Second retry on 2026-07-09:

- TAAFT, Futurepedia, DevToolLab AI Tools, Hashnode, HackerNoon, Lobsters, and
  Reddit r/commandline all remain `Deferred`.
- No submit/post was made: TAAFT is still browser-policy blocked, Futurepedia
  is still Cloudflare-blocked, DevToolLab/Lobsters are still login or automation
  gated, Hashnode is signed out, HackerNoon lacks an authenticated editor, and
  r/commandline remains rules/flair/AI-policy gated.

Auth-resume on 2026-07-09:

- Posted existing: Hashnode is authenticated and already shows a published
  Codex/CODEX_HOME profile article from May 7; no duplicate post was created.
- Dead: DevToolLab AI Tools is now confirmed paid-only via
  `https://devtoollab.com/ai-tools/submit`; no free listing path was used.
- Deferred/auth needed: HackerNoon `/new` still shows login/signup instead of an
  authenticated editor, and Lobsters remains on the login/invite gate.

### 2026-07-09 Next 20 Non-GitHub Batch

Airtable `Targets` and append-only `Log` rows are current for the 20 primary
targets plus one backup. No GitHub outreach, paid action, reciprocal
badge/backlink action, CAPTCHA/Cloudflare bypass, or duplicate listing was
made. Airtable status uses `Pending Review` for submitted directory listings
because the `Targets.Status` select field has no `Submitted` option.

Submitted or pending review:

- DevExplore: free tools-directory listing submitted; page confirmed `Tool
  submitted successfully!` and says editorial review takes a few business days.
  <https://devexplore.com/tools-directory/submit>

Dead:

- GPTBot: Standard Free submission is shown as `Currently unavailable`; the only
  actionable path was a $29 Fast Track/waitlist option.
  <https://gptbot.io/submit-ai-tool>

Deferred:

- DevPages, AI-Hunter, TipSeason, AI Review Battle, AI SuperHub, FreeAIO, AI
  ToolsXplorer, The Rundown AI / Supertools, and PoweredByAI require a visible
  public/contact email before submission can complete.
- The Next AI requires a contact email plus a human-check field; no bypass was
  attempted.
- ITHub Directory, ToolScout, and AIDude are login/signup gated before the
  submit form.
- HyzenPro is a relevant free multi-step editorial intake, but its workflow
  includes an `About you` name/email step.
- DropYourAI requires email and image upload before listing options; paid
  $19/$39 boosts were left untouched.
- PrimeDev.Tools timed out in Chrome and direct HTTP, so the form could not be
  inspected.
- chengxu.me accepted the project URL, then final submit returned `Something
  went wrong. Please try again.`
- Launch Llama Tools advertises a free listing, but `Prefill with AI` and
  `Submit` did not open a listing form in the current session; `/submit`
  resolves to the homepage.

Backup used:

- ToolDisk: relevant form and Free pricing were visible, but it requires media,
  categories, platforms, and a second submission-type step. Chrome automation
  was blocked by an overlay before completion; no submission was made.

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
- Verified accepted/listed on 2026-07-06:
  <https://github.com/ishandutta2007/Awesome-CLI-Coding-Agents/pull/3>.
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

- 2026-07-06, full monitoring-only reconciliation: checked 45 `PR Open`
  rows, 71 `Issue Open` rows, 7 `Pending Review` rows, and requalified 9
  `Backlog` rows. Outcomes: wins 0; declines/deferred 2 closed issues
  (1 `Declined`, 1 `Deferred`); blocked/dead rows 10 (1 missing GitHub repo
  plus 9 non-ICP startup/regional/ecosystem backlog rows); still open 45 PRs
  and 68 issues; pending reviews still 7; Airtable updates/logs 120 each;
  external actions 0.
- 2026-07-06, lead-qualification cleanup: Airtable moved 95 startup, venture,
  accelerator, regional ecosystem, funding/media, and generic startup/listing
  surfaces to `Dead` with `ICP: no` notes, `Last Checked = 2026-07-06`, and 95
  matching `lead-qualification` log records. P0/P1 `Backlog` is now 0. The
  remaining P0/P1 `Deferred` rows are not active outreach; they require a
  confirmed developer-tool category, useful technical content, owner login, a
  free path, or maintainer/admin approval before any action. Open monitoring
  remains 45 PRs and 71 issues in Airtable. New PRs, issues, listings,
  comments, emails, social posts, payments, and account creations: 0.
- 2026-07-06, Airtable-ledger reconciliation: updated 19 target rows and
  appended 19 log records in Airtable. Rechecked 7 P0/P1 PRs, moved
  <https://github.com/ishandutta2007/Awesome-CLI-Coding-Agents/pull/3> to
  listed after merge, kept 2 issue-first rows open, found no exact public
  listings yet for Terminal Trove, Changelog News, CLIHunt, or OpenAgent.bot,
  and deferred the top 5 startup-profile backlog candidates because they
  require truthful startup/company or geography claims not supplied here.
  External submissions, comments, social posts, emails, payments, and account
  creations: 0.
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
