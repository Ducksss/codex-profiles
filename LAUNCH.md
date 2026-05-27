# Launch Playbook

Use this when sharing `codex-profiles` with developer communities. The goal is
developer credibility first: clear problem, quick install, concrete demo, and
public feedback loops.

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

StackShare:

- Status: deferred on 2026-05-14.
- Why: StackShare requires sign-in before listing a tool. The GitHub OAuth flow
  opened, but the Codex in-app browser became unreliable for visibility/state,
  so the login could not be completed cleanly in-session.
- Resume path: use Chrome or a stable browser, sign in with GitHub, approve only
  the basic StackShare OAuth request for GitHub profile/email access, then use
  `List a Tool`.
- Listing angle: developer tool / AI coding agent utility for switching Codex
  CLI and Desktop accounts with isolated `CODEX_HOME` profiles.
- Listing URL: <https://stackshare.io/tools/new>

OpenAlternative:

- Status: deferred on 2026-05-14.
- Why: submit flow requires sign-in before reaching the listing form.
- Resume path: use a stable browser, sign in by email magic link, GitHub, or
  Google, then continue from <https://openalternative.co/submit>.

LibHunt:

- Status: deferred on 2026-05-14.
- Why: direct submit page stalled on Cloudflare verification in the Codex
  in-app browser.
- Resume path: open <https://www.libhunt.com/repo/submit> in a stable browser
  and submit `https://github.com/Ducksss/codex-profiles`.

SaaSHub:

- Status: deferred on 2026-05-14.
- Why: submit page also stalled on Cloudflare verification in the Codex in-app
  browser.
- Resume path: open <https://www.saashub.com/services/submit> in a stable
  browser and start with the GitHub repository URL.

Awesome Codex CLI:

- Status: replacement PR opened on 2026-05-18.
- Why: highly relevant curated list with an existing `Account & Auth` section.
- Submission source: branch `Ducksss:pinzheng/add-codex-profiles-roggeohta`,
  commit `8510a07` adds `Ducksss/codex-profiles`.
- PR target: <https://github.com/RoggeOhta/awesome-codex-cli>
- PR: <https://github.com/RoggeOhta/awesome-codex-cli/pull/40>
- Note: original PR <https://github.com/RoggeOhta/awesome-codex-cli/pull/33>
  was closed and replaced after a fork-name collision with another
  `awesome-codex-cli` repository.

Awesome Codex CLI by milisp:

- Status: merged on 2026-05-18.
- Why: second Codex-specific curated list with an existing `Development Tools`
  section that already includes config/account switching tools.
- Submission source: branch
  `pinzheng/add-codex-profiles`, commit `cd7b62d` adds `codex-profiles`.
- PR target: <https://github.com/milisp/awesome-codex-cli>
- PR: <https://github.com/milisp/awesome-codex-cli/pull/30>

Awesome CLI Apps:

- Status: not eligible yet as of 2026-05-18.
- Why: contribution rules require GitHub-hosted tools to be older than 90 days
  and have more than 20 stars. `codex-profiles` currently has 1 star.
- Resume path: revisit after the repo crosses the age/star threshold, then
  submit to <https://github.com/agarrharr/awesome-cli-apps>.

Awesome Codex Plugins:

- Status: not a fit as of 2026-05-18.
- Why: contribution rules require a real Codex plugin bundle under
  `plugins/<owner>/<repo>/` with `.codex-plugin/plugin.json` and an icon.
  `codex-profiles` is a standalone CLI helper, not a Codex plugin.
- Reference: <https://github.com/hashgraph-online/awesome-codex-plugins>

Awesome DevTools:

- Status: PR opened on 2026-05-18.
- Why: developer-tool list with `AI Coding Tools` and `CLIs & Terminal Tools`
  sections; no visible age/star gate.
- Submission source: branch
  `pinzheng/add-codex-profiles`, commit `c688e2a` adds `codex-profiles`.
- PR target: <https://github.com/devtoolsd/awesome-devtools>
- PR: <https://github.com/devtoolsd/awesome-devtools/pull/230>

Awesome AI-Driven Development:

- Status: PR opened on 2026-05-18.
- Why: active AI-development list with existing Codex, Codex Desktop, and
  Codex-adjacent CLI tools in `Terminal & CLI Agents`.
- Submission source: branch
  `pinzheng/add-codex-profiles`, commit `19ed072` adds `codex-profiles`.
- PR target: <https://github.com/eltociear/awesome-AI-driven-development>
- PR: <https://github.com/eltociear/awesome-AI-driven-development/pull/52>

Awesome Vibe Coding by no-fluff:

- Status: issue opened on 2026-05-22.
- Why: targeted list for agentic/vibe-coding workflows with an `Other tools`
  section for companion utilities around coding agents.
- Caveat: contribution notes ask users to open an issue first. Use the local
  candidate as source material, or open a PR if the maintainer accepts direct
  additions.
- Submission source: branch
  `pinzheng/add-codex-profiles`, commit `8c138eb` adds `codex-profiles`.
- Issue target: <https://github.com/no-fluff/awesome-vibe-coding>
- Issue: <https://github.com/no-fluff/awesome-vibe-coding/issues/115>

Awesome AI Coding Tools:

- Status: PR opened on 2026-05-18.
- Why: high-reach AI coding tools list with existing Codex CLI and
  Codex-adjacent developer productivity tools.
- Caveat: contribution rules prefer tools that are AI-powered or AI-enhanced.
  This is a borderline but defensible entry because `codex-profiles` is a
  Codex workflow helper rather than a standalone AI model/tool.
- Submission source: branch
  `pinzheng/add-codex-profiles`, commit `e7634ee` adds `codex-profiles`.
- PR target: <https://github.com/ai-for-developers/awesome-ai-coding-tools>
- PR: <https://github.com/ai-for-developers/awesome-ai-coding-tools/pull/330>

Awesome AI Coding Tools by LaunchApp:

- Status: PR opened on 2026-05-27.
- Why: current AI coding tools list with explicit `CLI & Terminal Coding
  Tools` coverage for lower-level terminal utilities that pair with coding
  agents or run solo. `codex-profiles` fits as a focused Codex CLI/Desktop
  account and profile-state utility.
- Duplicate check: searched open and closed PRs/issues for `codex-profiles`,
  `Ducksss/codex-profiles`, and `CODEX_HOME`; no prior submission found. A
  separate open PR for "Everything OpenAI Codex" was unrelated.
- Section: `CLI & Terminal Coding Tools`.
- Submission source: branch `pinzheng/add-codex-profiles` on fork
  <https://github.com/Ducksss/awesome-ai-coding-tools-launchapp>, commit
  `2d061b54cbfe40202c38186f3b6cc9e046f8c324` adds `codex-profiles`.
- Validation: reviewed repository metadata, README scope, and
  `contributing.md`; kept the maintainer-featured `Animus` entry first and
  sorted the remaining CLI tools alphabetically; ran `git diff --check`.
  `npx --yes markdownlint-cli README.md` reports pre-existing repository-wide
  README line-length issues, recorded as non-blocking. PR checks: no checks
  reported. GitHub merge state was `CLEAN` after opening.
- PR target: <https://github.com/launchapp-dev/awesome-ai-coding-tools>
- PR: <https://github.com/launchapp-dev/awesome-ai-coding-tools/pull/8>
- Reference: <https://github.com/launchapp-dev/awesome-ai-coding-tools>

AI IDEs & Coding Assistants:

- Status: merged on 2026-05-19.
- Why: small but current manually curated AI tools directory with a
  `Developer Productivity & Workflow` section.
- Submission source: branch
  `pinzheng/add-codex-profiles`, commit `08da146` adds `codex-profiles`.
- Follow-up: maintainer requested tracker submission instead of the direct PR,
  then generated and merged a directory PR from issue #53.
- Issue: <https://github.com/QAInsights/awesome-ai-tools/issues/53>
- Maintainer PR: <https://github.com/QAInsights/awesome-ai-tools/pull/54>
- Merge commit: `32bc2b44e370a718134fd1d7a3910bcd9cd9cbb1`.
- Validation: verified the upstream README lists `codex-profiles`.
- PR target: <https://github.com/QAInsights/awesome-ai-tools>
- Original PR: <https://github.com/QAInsights/awesome-ai-tools/pull/50>

Awesome Dev Tools by t18n:

- Status: not eligible on 2026-05-22.
- Why: general developer-tool list accepting useful developer utilities; lower
  priority than Codex/AI-agent-specific channels, but still relevant.
- Submission source: branch
  `pinzheng/add-codex-profiles`, commit `e3bb632` adds `codex-profiles`.
- Follow-up: repository is now archived, so no PR was opened.
- PR target: <https://github.com/t18n/awesome-dev-tools>

Awesome Terminals AI:

- Status: PR opened on 2026-05-18.
- Why: AI terminal workflow catalogue with a `Shell Enhancements` section;
  `codex-profiles` is a shell-level helper for Codex account/profile
  separation.
- Submission source: branch
  `pinzheng/add-codex-profiles`, commit `b64abeb` adds `codex-profiles`.
- PR target: <https://github.com/BNLNPPS/awesome-terminals-ai>
- PR: <https://github.com/BNLNPPS/awesome-terminals-ai/pull/8>

Awesome Vibe Coding by Taskade:

- Status: PR opened on 2026-05-18.
- Why: active vibe-coding list with `CLI & Terminal Tools` and
  `Specialized CLI Tools` tables.
- Submission source: branch
  `pinzheng/add-codex-profiles`, commit `2804db2` adds `codex-profiles`.
- PR target: <https://github.com/taskade/awesome-vibe-coding>
- PR: <https://github.com/taskade/awesome-vibe-coding/pull/22>

Awesome Vibe Coding by bluegalaxy111:

- Status: PR opened on 2026-05-18.
- Why: terminal-agent-focused vibe-coding handbook with Codex already listed
  in `AI Coding Agents > Terminal / CLI`.
- Submission source: branch `pinzheng/add-codex-profiles`, commit `24b3077` adds
  `codex-profiles`.
- PR target: <https://github.com/bluegalaxy111/awesome-vibe-coding>
- PR: <https://github.com/bluegalaxy111/awesome-vibe-coding/pull/8>

Awesome CLI Apps in a CSV:

- Status: PR opened on 2026-05-18.
- Why: high-reach CLI catalogue with an explicit `data/apps.csv` PR path and
  an existing `ai` category for terminal AI tools.
- Submission source: branch
  `pinzheng/add-codex-profiles`, commit `e359888` adds `codex-profiles`.
- Validation: parsed `data/apps.csv` with Ruby CSV.
- PR target: <https://github.com/toolleeo/awesome-cli-apps-in-a-csv>
- PR: <https://github.com/toolleeo/awesome-cli-apps-in-a-csv/pull/267>

Awesome OpenAI Codex:

- Status: PR opened on 2026-05-18.
- Why: Codex-specific list with a `Tools & Integrations` section and explicit
  contribution rules for direct Codex ecosystem tools.
- Submission source: branch
  `pinzheng/add-codex-profiles`, commit `15322cb` adds `codex-profiles`.
- PR target: <https://github.com/vaderyang/awesome-openai-codex>
- PR: <https://github.com/vaderyang/awesome-openai-codex/pull/2>

Awesome Codex Plugins by darknorth-123:

- Status: merged on 2026-05-26.
- Why: Codex ecosystem list that explicitly accepts plugins, MCP servers,
  workflows, integrations, and developer tools for OpenAI Codex.
- Submission source: branch `pinzheng/add-codex-profiles`, commit `4985656` adds
  `codex-profiles` to `Developer Tools`.
- Merge commit: `d279cc3041eca41c14cc3ff167e213066df87d69`.
- Validation: verified the upstream README lists `codex-profiles`.
- PR target: <https://github.com/darknorth-123/Awesome-Codex-Plugins>
- PR: <https://github.com/darknorth-123/Awesome-Codex-Plugins/pull/2>

Awesome OpenAI Codex CLI by taahro:

- Status: PR opened on 2026-05-18.
- Why: Codex CLI resource list with a `New Features & Integrations` section.
- Submission source: branch `pinzheng/add-codex-profiles`, commit `c919693` adds
  `codex-profiles`.
- PR target: <https://github.com/taahro/awesome-openai-codex-cli>
- PR: <https://github.com/taahro/awesome-openai-codex-cli/pull/3>

Awesome Agentic Coding by tranhoangpich:

- Status: PR opened on 2026-05-18.
- Why: open-source agentic-coding list already containing Codex and adjacent
  account/session workflow tools.
- Submission source: branch `pinzheng/add-codex-profiles`, commit `8838169` adds
  `codex-profiles`.
- PR target: <https://github.com/tranhoangpich/awesome-agentic-coding>
- PR: <https://github.com/tranhoangpich/awesome-agentic-coding/pull/3>

Awesome AI Coding Agent Tools:

- Status: merged on 2026-05-20.
- Why: AI coding-agent ecosystem catalogue; `codex-profiles` fits as focused
  Codex CLI/Desktop tooling around profile and account isolation.
- Submission source: branch
  `pinzheng/add-codex-profiles`, commit `c031ecd` adds a `Codex CLI &
  Desktop Tooling` subsection.
- Merge commit: `198d9f0322674ece7a56ee0741a0a999d8b79f5a`.
- Validation: ran `npx --yes markdownlint-cli README.md`; later verified the
  PR merged through GitHub CLI.
- PR target: <https://github.com/namphuongtran/awesome-ai-coding-agent-tools>
- PR: <https://github.com/namphuongtran/awesome-ai-coding-agent-tools/pull/4>

Awesome CLI Coding Agents:

- Status: PR opened on 2026-05-18.
- Why: terminal-native coding-agent list with an `Agent infrastructure` section
  for tools that extend or support CLI coding agents.
- Submission source: branch
  `pinzheng/add-codex-profiles`, commit `7c2b638` adds `codex-profiles`.
- PR target: <https://github.com/bradAGI/awesome-cli-coding-agents>
- PR: <https://github.com/bradAGI/awesome-cli-coding-agents/pull/90>

Awesome AI Dev Tools:

- Status: PR opened on 2026-05-18.
- Why: broad AI developer-tools list that already includes OpenAI Codex and
  Codex CLI; `codex-profiles` is a Codex workflow utility rather than a
  generic promo entry.
- Submission source: branch `pinzheng/add-codex-profiles`, commit `135b228` adds
  `codex-profiles`.
- PR target: <https://github.com/PierrunoYT/awesome-ai-dev-tools>
- PR: <https://github.com/PierrunoYT/awesome-ai-dev-tools/pull/26>

Awesome AI Coding Assistants Playbook:

- Status: PR opened on 2026-05-18.
- Why: assistant configuration/resource playbook; `codex-profiles` manages
  Codex CLI/Desktop configuration boundaries through isolated `CODEX_HOME`
  profiles.
- Submission source: branch
  `pinzheng/add-codex-profiles`, commit `d3ab9f3` adds English and Portuguese
  entries.
- Validation: ran `git diff --check`; default `markdownlint-cli` reports
  pre-existing repository-wide README issues unrelated to this entry.
- PR target: <https://github.com/CodandoTV/awesome-ai-coding-assistants-playbook>
- PR: <https://github.com/CodandoTV/awesome-ai-coding-assistants-playbook/pull/8>

Awesome AI Coding by dalisoft:

- Status: merged on 2026-05-20.
- Why: AI coding catalogue that already lists Codex; `codex-profiles` fits the
  `Resources` section as a companion utility, not the AI-agent CLI table.
- Submission source: branch
  `pinzheng/add-codex-profiles`, commit `4b194bd` adds `codex-profiles`.
- Follow-up: maintainer closed the original PR but said the tool would be
  added when a new category landed; it was then included in maintainer PR #65.
- Maintainer PR: <https://github.com/dalisoft/awesome-ai-coding/pull/65>
- Merge commit: `672e7123baf3cb0a84fed612f7f63e0310199e1f`.
- Validation: verified the upstream README lists `codex-profiles`.
- PR target: <https://github.com/dalisoft/awesome-ai-coding>
- Original PR: <https://github.com/dalisoft/awesome-ai-coding/pull/64>

Awesome AI Coding by wsxiaoys:

- Status: PR opened on 2026-05-18.
- Why: high-reach AI-coding list whose `Projects` section includes open-source
  AI coding CLIs, editor tools, and workflow utilities.
- Submission source: branch
  `pinzheng/add-codex-profiles`, commit `8a781d3` adds `codex-profiles`.
- PR target: <https://github.com/wsxiaoys/awesome-ai-coding>
- PR: <https://github.com/wsxiaoys/awesome-ai-coding/pull/103>

Everything AI Coding:

- Status: skipped on 2026-05-18.
- Why: relevant AI-coding catalogue, but manual curated submissions are
  structured around MCP servers, skills, rules, and prompts. Adding
  `codex-profiles` as a Bash CLI helper would misclassify the project.
- Reference: <https://github.com/zgsm-ai/everything-ai-coding>

Awesome Coding Agents by wshobson:

- Status: skipped on 2026-05-18.
- Why: `wshobson/awesome-coding-agents` could not be resolved through GitHub,
  and no matching public repository was found under that owner.

Awesome Shell:

- Status: PR opened on 2026-05-27.
- Why: `codex-profiles` is Bash shell software and the repository accepts
  broad shell tooling entries. This is lower-signal than Codex-specific
  directories, but the user's explicit 2026-05-27 request was to do more
  outreach, and the entry is concise, truthful, and on-topic.
- Duplicate check: searched open and closed PRs/issues for `codex-profiles`,
  `Ducksss/codex-profiles`, `CODEX_HOME`, and Codex profile terms; no prior
  submission found.
- Submission source: fork `Ducksss/awesome-shell-uhub`, branch
  `pinzheng/add-codex-profiles`, commit
  `c82043bde2de628d566574749250df3b929457c3` adds one README entry.
- Validation: reviewed repository metadata and README structure; ran
  `git diff --check`. Repository-wide `markdownlint-cli` reports pre-existing
  README style issues, so it was recorded but not treated as a blocker.
- PR target: <https://github.com/uhub/awesome-shell>
- PR: <https://github.com/uhub/awesome-shell/pull/14>

Terminals Are Sexy:

- Status: skipped on 2026-05-18.
- Why: broad terminal resource list with an endorsement gate and many stale
  additions; `codex-profiles` is CLI-adjacent but less high-signal for that
  audience than Codex and AI-agent lists.
- Reference: <https://github.com/k4m4/terminals-are-sexy>

Awesome Harness Engineering:

- Status: PR opened on 2026-05-18.
- Why: harness-engineering list focused on context, environment control,
  state, resumability, and reliable agent operation. `codex-profiles` fits as
  Codex-specific profile/state isolation for repeatable CLI and Desktop runs.
- Duplicate check: searched open and closed PRs/issues for `codex-profiles`,
  `Ducksss/codex-profiles`, `CODEX_HOME`, and Codex profile terms; no prior
  submission found.
- Submission source: branch
  `pinzheng/add-codex-profiles-harness`, commit `a1fb549` adds
  `codex-profiles` to `Runtimes, Harnesses & Reference Implementations`.
- Validation: ran `git diff --check`.
- PR target: <https://github.com/walkinglabs/awesome-harness-engineering>
- PR: <https://github.com/walkinglabs/awesome-harness-engineering/pull/28>

Awesome Vibe Coding by ai-for-developers:

- Status: PR opened on 2026-05-18.
- Why: active vibe-coding tool list with a `CLI Tools` section already listing
  OpenAI Codex CLI and terminal coding-agent companions.
- Duplicate check: searched open and closed PRs/issues for `codex-profiles`,
  `Ducksss/codex-profiles`, `CODEX_HOME`, and Codex profile terms; no prior
  submission found.
- Note: README links a contribution guide, but `CONTRIBUTING.md` is absent/404;
  followed the existing simple bullet format and placed the entry at the end of
  the relevant category.
- Submission source: branch `pinzheng/add-codex-profiles-ai-for-dev-vibe`, commit `19c0153`
  adds `codex-profiles`.
- Validation: ran `git diff --check`.
- PR target: <https://github.com/ai-for-developers/awesome-vibe-coding>
- PR: <https://github.com/ai-for-developers/awesome-vibe-coding/pull/64>

Awesome Vibe Coding by filipecalegario:

- Status: PR opened on 2026-05-18.
- Why: high-reach vibe-coding list with a `Command Line Tools` section that
  already includes OpenAI Codex CLI and adjacent terminal coding agents.
- Duplicate check: searched open and closed PRs/issues for `codex-profiles`,
  `Ducksss/codex-profiles`, `CODEX_HOME`, and Codex profile terms; no prior
  submission found.
- Submission source: branch
  `pinzheng/add-codex-profiles-filipe-vibe`, commit `62ad2bb` adds
  `codex-profiles` at the bottom of `Command Line Tools` per
  `contributing.md`.
- Validation: ran `git diff --check`.
- PR target: <https://github.com/filipecalegario/awesome-vibe-coding>
- PR: <https://github.com/filipecalegario/awesome-vibe-coding/pull/187>

Awesome AI DevTools by jamesmurdza:

- Status: PR opened on 2026-05-18.
- Why: active AI developer-tools list with an `Agent Infrastructure >
  Configuration & Context Management` section. `codex-profiles` fits as a
  developer-focused Codex runtime-state/profile utility.
- Duplicate check: searched open and closed PRs/issues for `codex-profiles`,
  `Ducksss/codex-profiles`, `CODEX_HOME`, and Codex profile terms; no prior
  submission found. An unrelated PR surfaced on broad terms only.
- Submission source: branch
  `pinzheng/add-codex-profiles-ai-devtools`, commit `00832a2` adds
  `codex-profiles`.
- Validation: ran `git diff --check`.
- PR target: <https://github.com/jamesmurdza/awesome-ai-devtools>
- PR: <https://github.com/jamesmurdza/awesome-ai-devtools/pull/554>

Awesome Codex Workflows by shinpr:

- Status: closed on 2026-05-19.
- Why: Codex-first workflow and orchestration list where contribution guidance
  prefers an issue before a PR for new repository suggestions. Fit is relevant
  but borderline because `codex-profiles` is workflow infrastructure rather
  than an orchestration model.
- Duplicate check: searched open and closed PRs/issues for `codex-profiles`,
  `Ducksss/codex-profiles`, `codex profiles`, and `CODEX_HOME`; no prior
  submission found.
- Suggested category: `Workflow Infrastructure & Design`.
- Follow-up: maintainer passed because the list focuses on orchestration,
  planning, review, handoff, runtime containment, and adjacent workflow
  machinery; `codex-profiles` sits one layer below that as a focused profile
  isolation utility. Acknowledged the scope boundary and left no replacement
  action unless the list later adds lower-level Codex environment utilities.
- Issue target: <https://github.com/shinpr/awesome-codex-workflows>
- Issue: <https://github.com/shinpr/awesome-codex-workflows/issues/13>

ComposioHQ Awesome Codex Skills:

- Status: PR opened on 2026-05-27.
- Why: large and active Codex skill catalogue. The earlier direct product-link
  path was not valid for this repository, so this pass created a real reusable
  `codex-profile-switching` skill with `SKILL.md` instead of submitting a plain
  link.
- Duplicate check: searched open and closed PRs/issues for `codex-profiles`
  and `Ducksss/codex-profiles`; no real prior submission found. The existing
  PR queue did not contain a Codex profile switching skill.
- Submission source: fork `Ducksss/awesome-codex-skills-codex-profiles`,
  branch `pinzheng/add-codex-profile-switching`, commit
  `de1bb23f499827bff57fda1deda2b1753f754baa` adds
  `codex-profile-switching/SKILL.md` and the README entry.
- Validation: ran the system skill validator
  `quick_validate.py codex-profile-switching`, ran `markdownlint-cli` against
  `codex-profile-switching/SKILL.md`, and ran `git diff --check`.
  Repository-wide `markdownlint-cli` reports pre-existing README style issues.
  GitHub reported `Socket Security: Project Report` and
  `Socket Security: Pull Request Alerts` passing at final verification time.
- Reference: <https://github.com/ComposioHQ/awesome-codex-skills>
- PR: <https://github.com/ComposioHQ/awesome-codex-skills/pull/86>

VoltAgent Awesome Codex Subagents:

- Status: skipped on 2026-05-18.
- Why: catalogue is for Codex-native subagent definitions. `codex-profiles` is
  a CLI/profile manager, not a subagent.
- Duplicate check: searched open and closed PRs/issues for `codex-profiles`
  and `Ducksss/codex-profiles`; no prior submission found.
- Reference: <https://github.com/VoltAgent/awesome-codex-subagents>

Antigravity Awesome Skills:

- Status: deferred on 2026-05-18.
- Why: very active cross-agent skill library, but a valid submission would need
  a source-only skill under `skills/<name>/SKILL.md`; that is a new agent skill
  artifact rather than a direct curated-list entry for the existing project.
- Duplicate check: searched open and closed PRs/issues for `codex-profiles`
  and `Ducksss/codex-profiles`; no real prior submission found.
- Deferred path: create and validate a dedicated "Codex profile switching"
  skill only if the project owner wants codex-profiles distributed as an
  installable agent skill.
- Reference: <https://github.com/sickn33/antigravity-awesome-skills>

Sourcegraph Awesome Code AI:

- Status: skipped on 2026-05-18.
- Why: relevant AI coding tools list, but the repository is archived and the
  README explicitly says submissions are closed.
- Duplicate check: searched open and closed PRs/issues for `codex-profiles`,
  `Ducksss/codex-profiles`, `CODEX_HOME`, and Codex profile terms; no prior
  submission found.
- Reference: <https://github.com/sourcegraph/awesome-code-ai>

Kyrolabs Awesome Agents:

- Status: deferred on 2026-05-18.
- Why: active AI-agent list, but mostly catalogs agent frameworks and products.
  `codex-profiles` is a narrow Codex profile manager rather than an agent, and
  the repo's stated bar is higher for brand-new/low-traction projects.
- Duplicate check: searched open and closed PRs/issues for `codex-profiles`,
  `Ducksss/codex-profiles`, `CODEX_HOME`, and Codex profile terms; no prior
  submission found.
- Deferred path: revisit after `codex-profiles` has more traction or if the
  list adds an explicit tooling/configuration category.
- Reference: <https://github.com/kyrolabs/awesome-agents>

E2B Awesome AI Agents:

- Status: skipped on 2026-05-18.
- Why: high-reach AI-agent list, but it is explicitly for AI assistants and
  agents. Tool/framework additions belong in a separate E2B SDK/tool list, and
  `codex-profiles` is not an autonomous agent.
- Duplicate check: searched open and closed PRs/issues for `codex-profiles`
  and `Ducksss/codex-profiles`; no prior submission found. Broad Codex/profile
  terms matched unrelated open PRs only.
- Reference: <https://github.com/e2b-dev/awesome-ai-agents>

Awesome LLM Skills by Prat011:

- Status: PR opened on 2026-05-27.
- Why: skill-centric contribution process requires a documented and portable
  skill folder plus README update. The earlier direct product-link path was not
  valid, so this pass created a real `codex-profile-switching` skill that
  teaches safe Codex CLI/Desktop profile management with isolated `CODEX_HOME`
  directories.
- Duplicate check: searched open and closed PRs/issues for `codex-profiles`
  and `Ducksss/codex-profiles`; no prior submission found. The existing PR
  queue did not contain a Codex profile switching skill.
- Submission source: fork `Ducksss/awesome-llm-skills-codex-profiles`, branch
  `pinzheng/add-codex-profile-switching`, commit
  `3291f6e62385fc9f983525ef598426e2125132ac` adds
  `codex-profile-switching/SKILL.md` and the README entry.
- Validation: ran the system skill validator
  `quick_validate.py codex-profile-switching`, ran `markdownlint-cli` against
  `codex-profile-switching/SKILL.md`, and ran `git diff --check`.
  Repository-wide `markdownlint-cli` reports pre-existing README style issues.
  GitHub reported `GitGuardian Security Checks` passing at final verification
  time.
- Reference: <https://github.com/Prat011/awesome-llm-skills>
- PR: <https://github.com/Prat011/awesome-llm-skills/pull/132>

Awesome Gemini CLI:

- Status: skipped on 2026-05-18.
- Why: active Gemini CLI list, but `codex-profiles` is Codex-specific and does
  not currently support Gemini CLI.
- Duplicate check: searched open and closed PRs/issues for `codex-profiles`
  and `Ducksss/codex-profiles`; no prior submission found.
- Reference: <https://github.com/Piebald-AI/awesome-gemini-cli>

Awesome Vibe Coding Tools by jiji262:

- Status: PR opened on 2026-05-21.
- Why: focused vibe-coding tools catalogue with `Terminal-Based AI Agents` and
  `CLI Workflow Systems & Agent Enhancers` sections. It already lists Codex CLI
  and Codex-adjacent workflow enhancers such as `oh-my-codex`, so
  `codex-profiles` is a plausible fit as a small Codex CLI/Desktop profile
  isolation utility.
- Duplicate check: searched open and closed PRs/issues for `codex-profiles`,
  `Ducksss/codex-profiles`, and `CODEX_HOME`; no prior submission found.
- Contribution notes: README invites direct PRs, asks for an official URL,
  concise description, appropriate category, and AI coding/development
  relevance.
- Section: `CLI Workflow Systems & Agent Enhancers`.
- Submission source: branch `pinzheng/add-codex-profiles`, commit `e1e637d` adds
  `codex-profiles`.
- Validation: reviewed repository metadata, README sections, contribution
  notes, and duplicate history with GitHub CLI; ran `git diff --check`.
  `npx --yes markdownlint-cli README.md` reports existing repository-wide
  README style issues in the target project, so it was recorded but not treated
  as a blocker.
- PR target: <https://github.com/jiji262/awesome-vibe-coding-tools>
- PR: <https://github.com/jiji262/awesome-vibe-coding-tools/pull/22>
- Reference: <https://github.com/jiji262/awesome-vibe-coding-tools>

Awesome Vibe Coding by 0xWelt:

- Status: PR opened on 2026-05-22.
- Why: active curated vibe-coding list with a detailed `CLI Tools` area that
  already includes OpenAI Codex and a later `Supporting Tools` section.
  `codex-profiles` could fit as a companion utility near Codex CLI or as
  supporting tooling for developers switching Codex accounts/contexts.
- Duplicate check: searched open and closed PRs/issues for `codex-profiles`,
  `Ducksss/codex-profiles`, and `CODEX_HOME`; no prior submission found.
- Contribution notes: no separate contribution guide found during this pass;
  direct PR rules are not explicit from the inspected README.
- Section: `CLI Tools` near `OpenAI Codex`.
- Submission source: branch
  `pinzheng/add-codex-profiles`, commit `55fb7c0` adds `codex-profiles`.
- Validation: reviewed repository metadata, README structure, and duplicate
  history with GitHub CLI; ran `git diff --check`. `npx --yes
  markdownlint-cli README.md` reports pre-existing repository-wide README style
  issues, recorded as non-blocking. PR checks: no checks reported; GitHub merge
  state was `UNSTABLE` immediately after opening.
- PR target: <https://github.com/0xWelt/Awesome-Vibe-Coding>
- PR: <https://github.com/0xWelt/Awesome-Vibe-Coding/pull/176>
- Reference: <https://github.com/0xWelt/Awesome-Vibe-Coding>

Awesome Vibe Coding Resources by acvnace:

- Status: merged on 2026-05-22.
- Why: active resource list with `Command Line Tools` entries for Codex-adjacent
  utilities such as Agent FM, MUSE, SwarmClaw, SwarmVault, and agenttrace.
  `codex-profiles` may fit as a command-line workflow utility for Codex users,
  but the list is broad and no contribution rules were visible in the inspected
  README.
- Duplicate check: searched open and closed PRs/issues for `codex-profiles`,
  `Ducksss/codex-profiles`, and `CODEX_HOME`; no prior submission found.
- Section: `Command Line Tools`.
- Submission source: branch
  `pinzheng/add-codex-profiles`, commit `d332134` adds `codex-profiles`.
- Validation: reviewed repository metadata, README sections, and duplicate
  history with GitHub CLI; ran `git diff --check`. `npx --yes
  markdownlint-cli README.md` reports pre-existing repository-wide README style
  issues, recorded as non-blocking. PR checks: no checks reported. Later
  verified the upstream README lists `codex-profiles`.
- Merge commit: `e9649ed58c9e799bd5a0b12c0a6d592b87d2f0e2`.
- PR target: <https://github.com/acvnace/awesome-vibe-coding-resources>
- PR: <https://github.com/acvnace/awesome-vibe-coding-resources/pull/20>
- Reference: <https://github.com/acvnace/awesome-vibe-coding-resources>

Awesome OpenAI Codex by KarelDO:

- Status: PR opened on 2026-05-22.
- Why: Codex-specific product/demo/tool list with a `Products & tools` section
  and README text inviting PRs for relevant links. However, the repository
  appears stale, with the latest push observed from 2023, and its positioning
  is rooted in the older OpenAI Codex era rather than current Codex CLI/Desktop
  workflows.
- Duplicate check: searched open and closed PRs/issues for `codex-profiles`,
  `Ducksss/codex-profiles`, and `CODEX_HOME`; no prior submission found.
- Section: `Products & tools`.
- Submission source: branch
  `pinzheng/add-codex-profiles`, commit `781f881` adds `codex-profiles`.
- Validation: reviewed repository metadata, README scope, and duplicate history
  with GitHub CLI; ran `git diff --check`. `npx --yes markdownlint-cli
  README.md` reports pre-existing repository-wide README style issues, recorded
  as non-blocking. PR checks: no checks reported.
- PR target: <https://github.com/KarelDO/awesome-codex>
- PR: <https://github.com/KarelDO/awesome-codex/pull/15>
- Reference: <https://github.com/KarelDO/awesome-codex>

Awesome Codex Automations:

- Status: not a fit on 2026-05-21.
- Why: repository accepts Codex automation definitions with grounding rules and
  a specific automation template. `codex-profiles` is a standalone Bash CLI
  helper, not an automation definition.
- Duplicate check: searched open and closed PRs/issues for `codex-profiles`,
  `Ducksss/codex-profiles`, and `CODEX_HOME`; no prior submission found.
- Deferred path: revisit only if creating a real automation that uses
  `codex-profiles` as supporting context, such as a profile hygiene or
  multi-account setup checker.
- Validation: reviewed repository metadata, README, contribution guide, and
  duplicate history with GitHub CLI.
- Reference: <https://github.com/onurkanbakirci/awesome-codex-automations>

Awesome Vibe Coding Guide by analyticalrohit:

- Status: not a fit on 2026-05-21.
- Why: repository is a best-practices guide with contribution folders for
  planning, prompting, testing, debugging, version control, and deployment.
  Although it has a small `Top 10 Vibe Coding Tools` section, the contribution
  model is guide content rather than a durable tool catalogue, and adding a
  narrow Codex profile manager would be forced.
- Duplicate check: searched open and closed PRs/issues for `codex-profiles`,
  `Ducksss/codex-profiles`, and `CODEX_HOME`; no prior submission found.
- Validation: reviewed repository metadata, README, contribution section, and
  duplicate history with GitHub CLI.
- Reference: <https://github.com/analyticalrohit/awesome-vibe-coding-guide>

Awesome Vibe Coding CLI by vanna-ai:

- Status: not a fit on 2026-05-21.
- Why: repository tracks AI coding CLI agents compatible with Remote-Code and
  summarizes provider/sample-output behavior. `codex-profiles` wraps Codex
  profile state but is not itself a coding agent, provider-compatible CLI, or
  benchmarkable Remote-Code target.
- Duplicate check: searched open and closed PRs/issues for `codex-profiles`,
  `Ducksss/codex-profiles`, and `CODEX_HOME`; no prior submission found.
- Validation: reviewed repository metadata, README scope, sections, and
  duplicate history with GitHub CLI.
- Reference: <https://github.com/vanna-ai/Awesome-Vibe-Coding-CLI>

Awesome Vibe Coding Tools by furudo-erika:

- Status: PR opened on 2026-05-22.
- Why: vibe-coding tools list with a `Terminal & Command Line` section and
  contribution guidance for direct PRs. `codex-profiles` fits as a
  command-line Codex workflow helper for users separating Codex account and
  local state across contexts.
- Duplicate check: searched open and closed PRs/issues for `codex-profiles`,
  `Ducksss/codex-profiles`, and `CODEX_HOME`; no prior submission found.
- Submission source: branch `pinzheng/add-codex-profiles`, commit `366d1f4` adds
  `codex-profiles`.
- Validation: reviewed repository metadata, README scope, contribution notes,
  and duplicate history with GitHub CLI; ran `git diff --check`. `npx --yes
  markdownlint-cli README.md` reports pre-existing repository-wide README style
  issues, recorded as non-blocking.
- PR target: <https://github.com/furudo-erika/awesome-vibe-coding-tools>
- PR: <https://github.com/furudo-erika/awesome-vibe-coding-tools/pull/4>

Awesome Vibe Coding by techiediaries:

- Status: not a fit on 2026-05-22.
- Why: list focuses on AI coding assistants, AI IDEs, prompt-driven code
  generation tools, and UI generation products. `codex-profiles` is a Codex
  state/profile utility rather than an AI coding assistant or generator.
- Duplicate check: searched open and closed PRs/issues for `codex-profiles`,
  `Ducksss/codex-profiles`, and `CODEX_HOME`; no prior submission found.
- Validation: reviewed repository metadata, README scope, and duplicate history
  with GitHub CLI.
- Reference: <https://github.com/techiediaries/awesome-vibe-coding>

Awesome AI Coding Agents by brandonhimpfen:

- Status: not a fit on 2026-05-22.
- Why: contribution guidance emphasizes long-term relevance and strict taxonomy
  fit for AI coding agents, platforms, and agent infrastructure.
  `codex-profiles` is useful Codex workflow tooling but not itself an agent,
  agent framework, benchmark, or infrastructure platform in that taxonomy.
- Duplicate check: searched open and closed PRs/issues for `codex-profiles`,
  `Ducksss/codex-profiles`, and `CODEX_HOME`; no prior submission found.
- Validation: reviewed repository metadata, README sections, contribution
  guide, and duplicate history with GitHub CLI.
- Reference: <https://github.com/brandonhimpfen/awesome-ai-coding-agents>

Awesome AI Coding Agents by vinkius-labs:

- Status: not a fit on 2026-05-22.
- Why: table-based catalogue is for IDE-based, terminal-based, autonomous,
  multi-agent, code-review, and specialized AI coding agents. `codex-profiles`
  supports Codex account/profile switching but is not a coding agent.
- Duplicate check: searched open and closed PRs/issues for `codex-profiles`,
  `Ducksss/codex-profiles`, and `CODEX_HOME`; no prior submission found.
- Validation: reviewed repository metadata, README sections, and duplicate
  history with GitHub CLI.
- Reference: <https://github.com/vinkius-labs/awesome-ai-coding-agents>

Awesome AI Coding Agents by BrethofAI:

- Status: not a fit on 2026-05-22.
- Why: repository is an opinionated comparison/review page for coding
  assistants. `codex-profiles` is not a coding assistant and would not fit the
  review table or tool-profile format.
- Duplicate check: searched open and closed PRs/issues for `codex-profiles`,
  `Ducksss/codex-profiles`, and `CODEX_HOME`; no prior submission found.
- Validation: reviewed repository metadata, README sections, and duplicate
  history with GitHub CLI.
- Reference: <https://github.com/BrethofAI/awesome-ai-coding-agents>

## Outreach Candidate Backlog

2026-05-22 new repo discovery:

- Status: deferred backlog; no PRs, issues, listing requests, or maintainer
  requests were opened for these 50 repositories.
- Scope: new repositories not already recorded elsewhere in this ledger at
  discovery time.
- Validation: used GitHub CLI repository search metadata and excluded archived
  repositories plus every GitHub repository URL already present in `LAUNCH.md`.
- Blocker: GitHub returned secondary/API rate-limit errors during broader
  expansion, so this backlog uses the successful search pool only. Before any
  outreach, re-check the target README/contribution rules and search that
  target's open/closed PRs and issues for `codex-profiles`,
  `Ducksss/codex-profiles`, and `CODEX_HOME`.
- Outreach rule: prefer direct PRs only for clear list/category matches with
  direct contribution guidance; otherwise open an issue first.

| # | Repository | Status | Why it may fit | Suggested outreach |
| - | - | - | - | - |
| 1 | <https://github.com/colicveinmedicine640/awesome-codex-cli> | deferred candidate | Codex CLI list with tools, skills, subagents, plugins, and resources; likely mirrors an existing Codex list, so verify originality before outreach. | Issue first unless README clearly allows direct tool PRs. |
| 2 | <https://github.com/commonplace-middledistance109/awesome-codex-cli> | deferred candidate | Codex CLI resource list with many tools and plugins; `codex-profiles` fits only if the repo is independently maintained. | Issue first after clone/originality check. |
| 3 | <https://github.com/AlexZander-666/awesome-codex-agents> | deferred candidate | Codex-agent collection; `codex-profiles` may fit as Codex CLI profile/account support if it has a tooling/support section. | Issue first; avoid direct PR if agent-only. |
| 4 | <https://github.com/furudo-erika/awesome-ai-coding-tools> | deferred candidate | AI coding tools list from an owner that also maintains a vibe-coding tools list; likely has terminal/developer tooling categories. | Direct PR if README category fits; otherwise issue. |
| 5 | <https://github.com/tyler-j-dao/awesome-ai-coding-tools> | deferred candidate | AI coding tools catalogue; possible fit if it accepts workflow utilities around coding agents. | Issue first due sparse metadata. |
| 6 | <https://github.com/danielrosehill/Awesome-AI-Coding-Tools> | deferred candidate | Snapshot-style AI coding tools list; may accept Codex workflow utilities if still maintained. | Issue first; check current contribution stance. |
| 7 | <https://github.com/launchapp-dev/awesome-ai-coding-tools> | deferred candidate | AI coding tools list explicitly includes editors, agents, code review, testing, CLI tools, and workflow automation. | Direct PR likely if CLI/workflow section exists. |
| 8 | <https://github.com/Icloudeng/awesome-ai-coding-tools> | deferred candidate | AI developer-tool list covers workflow automation and productivity. | Issue first unless README has clear category and PR guidance. |
| 9 | <https://github.com/tomrzv/Awesome-AI-Coding-Tools> | deferred candidate | AI coding tools list includes developer productivity and app-building tools. | Issue first; verify activity and category. |
| 10 | <https://github.com/Web4application/awesome-ai-coding-tools> | deferred candidate | AI coding tools catalogue; possible low-priority fit if terminal/helper tools are included. | Issue first. |
| 11 | <https://github.com/runaicode/awesome-ai-coding-tools> | deferred candidate | Weekly-updated AI coding tools list; possible fit if Codex/CLI helpers are accepted. | Direct PR only if README has CLI/workflow section. |
| 12 | <https://github.com/kax168/awesome-ai-coding-tools-2026> | deferred candidate | 2026 AI coding/productivity tools list; possible fit for current Codex helper. | Issue first due low signal. |
| 13 | <https://github.com/JohannFreddyLoayzaHuana/awesome-ai-coding-tools> | deferred candidate | AI coding workflow/tool list updated recently; may accept developer productivity boosters. | Issue first unless README accepts direct PRs. |
| 14 | <https://github.com/dingjiu1989-hue/awesome-ai-coding-tools> | deferred candidate | AI coding assistants and developer AI tools list; possible fit as Codex workflow utility. | Issue first. |
| 15 | <https://github.com/kax168/awesome-ai-coding-agents> | deferred candidate | AI coding-agent list; `codex-profiles` fits only if it has infrastructure/support tooling. | Issue first; skip if agent-only. |
| 16 | <https://github.com/kax168/awesome-ai-coding-assistants-2026> | deferred candidate | 2026 coding assistants/tools list; possible fit if it has helper/tooling categories. | Issue first. |
| 17 | <https://github.com/ColinEberhardt/awesome-ai-developer-tools> | deferred candidate | More mature AI developer-tool list; relevant if it includes AI coding workflow utilities. | Issue first; quality bar likely higher. |
| 18 | <https://github.com/dbpunk-labs/awesome-ai-developer-tools> | deferred candidate | AI developer tools list; possible if it accepts CLI/productivity utilities. | Issue first due sparse metadata. |
| 19 | <https://github.com/yeaight7/awesome-ai-devtools> | deferred candidate | Open-source map of AI developer tooling ecosystem; likely good fit if taxonomy includes workflow/configuration. | Direct PR if category exists; otherwise issue. |
| 20 | <https://github.com/Ravi-Chandraa/awesome-ai-devtools> | deferred candidate | AI devtools list; possible lower-priority fit for Codex helper tooling. | Issue first. |
| 21 | <https://github.com/tamilselvanarjun/awesome-ai-devtools> | deferred candidate | AI devtools list; possible lower-priority fit. | Issue first. |
| 22 | <https://github.com/buainoai/awesome-ai-devtools-multilingual> | deferred candidate | Multilingual AI devtools list with coding agents and code-review categories; could fit if tool entries are language-synced. | Issue first; direct PR may require multi-language updates. |
| 23 | <https://github.com/yasir27uk/awesome-ai-devtools> | deferred candidate | AI devtools list; possible lower-priority fit. | Issue first. |
| 24 | <https://github.com/Transcenda/awesome-agentic-coding> | deferred candidate | Agentic coding adoption list; may accept workflow/account-state utilities for coding agents. | Issue first; verify contribution style. |
| 25 | <https://github.com/fecet/awesome-agentic-coding> | deferred candidate | Agentic coding list; possible fit if it includes tools and support utilities. | Issue first. |
| 26 | <https://github.com/191086/awesome_agentic_coding> | deferred candidate | Rules/skills/commands/hooks for agentic coding; `codex-profiles` may fit only as environment support. | Issue first; skip if rules/skills-only. |
| 27 | <https://github.com/Supersynergy/awesome-agentic-coding> | deferred candidate | Claude Code focused agentic-coding bundle; possible cross-agent fit only if Codex tooling is accepted. | Issue first; likely borderline. |
| 28 | <https://github.com/li0nel/awesome-agentic-coding> | deferred candidate | Agentic coding list; low-metadata but potentially relevant. | Issue first. |
| 29 | <https://github.com/yubing744/awesome-agentic-coding-cli> | deferred candidate | Terminal-first agentic coding CLI list; strong thematic fit for Codex CLI account/profile helper. | Direct PR if README accepts CLI support tools. |
| 30 | <https://github.com/quome-cloud/awesome-coding-agents> | deferred candidate | Coding-agent list; possible fit if it has resources/tools around agents. | Issue first; skip if agent-only. |
| 31 | <https://github.com/closedloop-technologies/awesome-coding-agents> | deferred candidate | Coding-agent list; possible but low metadata. | Issue first. |
| 32 | <https://github.com/outer-joined/awesome-coding-agents> | deferred candidate | Coding-agent list updated recently; possible fit if support tooling is allowed. | Issue first. |
| 33 | <https://github.com/Caldalis/awesome-coding-agents> | deferred candidate | Resource list for learning Codex and Claude Code; potential fit as practical Codex CLI/Desktop utility. | Direct PR if tools/resources section exists. |
| 34 | <https://github.com/wdzhwsh4067/awesome-coding-agents> | deferred candidate | LLM coding agents, benchmarks, harness design, and workflow integration list; possible fit as workflow integration support. | Issue first; taxonomy may be research-heavy. |
| 35 | <https://github.com/tiennm99/awesome-coding-agents> | deferred candidate | Daily-updated ranking of AI agent coding tools; possible fit only if non-agent helper tools are accepted. | Issue first; likely borderline. |
| 36 | <https://github.com/YuyaoGe/Awesome-Vibe-Coding> | deferred candidate | Higher-star vibe-coding list; likely has tools/CLI categories. | Direct PR if Codex/CLI category exists. |
| 37 | <https://github.com/adriannoes/awesome-vibe-coding> | deferred candidate | AI-assisted development resources across Cursor, Claude Code, skills, notebooks, and reports; possible fit as Codex workflow utility. | Issue first; verify taxonomy. |
| 38 | <https://github.com/tysoncung/awesome-vibe-coding> | deferred candidate | AI coding assistants/tools list with 100+ entries; possible fit if terminal/CLI tools included. | Direct PR if category exists. |
| 39 | <https://github.com/Qbeczek1/awesome-vibe-coding> | deferred candidate | Vibe-coded apps/tools/projects list; possible fit if tool listings are accepted, not just built projects. | Issue first. |
| 40 | <https://github.com/tusharjadhav124/awesome-vibe-coding-tools> | deferred candidate | Recently updated vibe-coding tools/plugins list; likely good fit for Codex CLI/Desktop helper. | Direct PR if README has terminal/workflow category. |
| 41 | <https://github.com/vibe-coding-labs/awesome-vibe-coding> | deferred candidate | Vibe-coding AI programming resources; possible fit if multilingual/resources list accepts CLI helpers. | Issue first. |
| 42 | <https://github.com/andi-nugroho/awesome-vibe-coding> | deferred candidate | Vibe-coding references list; possible but lower priority because last update was 2025. | Issue first. |
| 43 | <https://github.com/peteresmond/awesome-vibe-coding> | deferred candidate | Vibe-coding resources list; possible fit if tool sections exist. | Issue first. |
| 44 | <https://github.com/byeadro/awesome-vibe-coding> | deferred candidate | Tools, prompts, and patterns for non-technical founders shipping with AI; possible fit only if developer tools are in scope. | Issue first; likely borderline. |
| 45 | <https://github.com/Feilul6656/awesome-vibe-coding> | deferred candidate | Very recent vibe-coding resources list for AI agents and development workflows. | Issue first; verify quality before PR. |
| 46 | <https://github.com/tangyuan-dev/awesome-vibe-coding> | deferred candidate | Vibe-coding tools/tutorials/prompt templates list; possible fit if CLI tools are accepted. | Issue first. |
| 47 | <https://github.com/alimaliai/awesome-vibe-coding> | deferred candidate | Recently updated AI coding assistants/tools/resources list; possible fit for Codex helper. | Issue first unless README has direct PR guidance. |
| 48 | <https://github.com/EffectiveVibeCoding/awesome-vibe-coding> | deferred candidate | Vibe-coding list; possible but lower priority due older activity and sparse metadata. | Issue first. |
| 49 | <https://github.com/rubylikeya/awesome-vibe-coding> | deferred candidate | Vibe Coding cases, tools, and best practices directory; possible fit as tool entry. | Issue first. |
| 50 | <https://github.com/di-su/awesome-vibe-coding> | deferred candidate | Vibe-coding resources, AI coding tools, and remote developer jobs list; possible tool fit. | Issue first. |

2026-05-27 scheduled release backlog addendum:

- Status: deferred scheduled backlog; no PRs, issues, listing requests, or
  maintainer requests were opened for these 50 repositories.
- Scope: additional repositories not already recorded elsewhere in this ledger
  at addendum time, intended for slow scheduled release after the current open
  PR queue cools down or when the user explicitly requests another volume pass.
- Suggested cadence: one wave per week, five repositories per wave, starting
  2026-06-03. Keep each wave below the spam threshold by checking fit and
  contribution rules immediately before outreach.
- Validation: used live GitHub/web search plus GitHub CLI repository metadata,
  excluded archived repositories, and excluded every GitHub repository URL
  already present in `LAUNCH.md`. Before any outreach, re-check each target's
  README/contribution rules and search open/closed PRs and issues for
  `codex-profiles`, `Ducksss/codex-profiles`, and `CODEX_HOME`.
- Outreach rule: direct PR only when the list has an obvious CLI, Codex,
  agent-infrastructure, skill, or developer-tool category. Use an issue first
  for broad AI-agent lists, Claude-specific lists, generated indexes, or any
  repository with ambiguous contribution rules.

| # | Wave | Repository | Status | Why it may fit | Suggested outreach |
| - | - | - | - | - | - |
| 1 | 2026-06-03 | <https://github.com/ComposioHQ/awesome-agent-clis> | scheduled candidate | Curates CLIs that humans and AI agents can use; `codex-profiles` is an agent-friendly CLI with deterministic profile/status commands. | Direct PR with a CLI skill folder if required by repo style; otherwise concise CLI entry. |
| 2 | 2026-06-03 | <https://github.com/Ariestar/awesome-agent-cli> | scheduled candidate | Agent-ready CLI list with categories, risks, effects, and guardrails; profile switching and isolated `CODEX_HOME` state fit the guardrail angle. | Direct PR if README table accepts agent-ready utilities; include safe-use notes. |
| 3 | 2026-06-03 | <https://github.com/shuyhere/awesome-agent-cli> | scheduled candidate | CLI tools for AI agents across productivity, research, project management, and dev tools; `codex-profiles` belongs as a developer workflow CLI. | Direct PR if dev-tools category exists; otherwise issue first. |
| 4 | 2026-06-03 | <https://github.com/agentablesh/awesome-agent-cli> | scheduled candidate | Cross-platform CLI tools suitable for AI agent workflows; isolated Codex profile switching is a workflow-support utility. | Direct PR with scriptability/JSON-output emphasis. |
| 5 | 2026-06-03 | <https://github.com/Baccivorous-shadiness115/awesome-agent-cli> | scheduled candidate | Agent CLI list with structured-output and dev-tool categories; `codex-profiles` can be positioned as a Codex account/profile management CLI. | Issue first because repository quality should be rechecked before editing. |
| 6 | 2026-06-10 | <https://github.com/shawnesquivel/awesome-agent-clis> | scheduled candidate | Small agent-CLI list; possible fit if it accepts companion utilities that help agents operate local tools safely. | Issue first due sparse metadata. |
| 7 | 2026-06-10 | <https://github.com/agenmod/awesome-agent-cli> | scheduled candidate | Agent-CLI catalogue; possible fit as a small shell utility for Codex profile isolation. | Issue first and skip if README is only a mirror or stub. |
| 8 | 2026-06-10 | <https://github.com/noahfraiture/awesome-codex-plugins> | scheduled candidate | Codex plugin/resource list; `codex-profiles` can fit as Codex ecosystem tooling even if not a plugin. | Direct PR only if non-plugin tools are accepted; otherwise issue first. |
| 9 | 2026-06-10 | <https://github.com/LeorickCoder/awesome-codex-skills> | scheduled candidate | Codex skill catalogue; the existing `codex-profile-switching` skill artifact can be adapted if the repo accepts practical Codex workflow skills. | Direct PR with validated `SKILL.md`. |
| 10 | 2026-06-10 | <https://github.com/anup4khandelwal/awesome-codex-skills> | scheduled candidate | Codex skills list; profile switching is a repeatable Codex setup/troubleshooting workflow. | Direct PR with validated `SKILL.md` after checking folder format. |
| 11 | 2026-06-17 | <https://github.com/joe-qai/awesome-codex-skills-cn> | scheduled candidate | Chinese Codex skills/resource list; possible localized variant of the `codex-profile-switching` skill. | Issue first unless bilingual contribution pattern is clear. |
| 12 | 2026-06-17 | <https://github.com/kailiu42/awesome-coding-agents> | scheduled candidate | Coding-agent list that explicitly includes supplementary tools; `codex-profiles` may fit as Codex support tooling. | Direct PR if a supplementary-tools section exists; otherwise issue first. |
| 13 | 2026-06-17 | <https://github.com/tatn/awesome-ai-coding-cli> | scheduled candidate | AI coding CLI catalogue; `codex-profiles` is directly CLI-facing and Codex-specific. | Direct PR after checking table schema/star-history format. |
| 14 | 2026-06-17 | <https://github.com/XD3an/awesome-ai-coding-all-in-one> | scheduled candidate | AI coding tools/configurations/resources list; profile isolation fits as Codex configuration tooling. | Issue first because it may sync from upstream sources. |
| 15 | 2026-06-17 | <https://github.com/AnswerZhao/ai-coding-playbook> | scheduled candidate | AI coding frameworks, workflows, patterns, and tools; `codex-profiles` can be positioned as a Codex workflow setup utility. | Issue first; direct PR only if external tools are listed. |
| 16 | 2026-06-24 | <https://github.com/KnoSkillz/awesome-ai-coding-tools> | scheduled candidate | AI coding tools list with reviews; possible fit if terminal/Codex helper utilities are accepted. | Issue first to avoid unsolicited review-format edits. |
| 17 | 2026-06-24 | <https://github.com/LiuBoyu/awesome-ai-coding> | scheduled candidate | AI coding resource hub; possible fit as a Codex helper if CLI/tool sections exist. | Issue first due sparse metadata. |
| 18 | 2026-06-24 | <https://github.com/shalk/awesome-ai-coding> | scheduled candidate | AI coding tools and developer productivity list; `codex-profiles` can fit under CLI/productivity if present. | Issue first; skip if list requires AI-powered tools only. |
| 19 | 2026-06-24 | <https://github.com/houbb/awesome-ai-coding> | scheduled candidate | AI coding exploration/resource list; possible fit as Codex workflow utility for Chinese-speaking Codex users. | Issue first; direct PR only with matching category. |
| 20 | 2026-06-24 | <https://github.com/chendongqi/awesome-ai-coding> | scheduled candidate | AI coding resource hub; possible fit if Codex CLI helper tools are accepted. | Issue first due broad scope. |
| 21 | 2026-07-01 | <https://github.com/alexanderop/awesome-ai-coding> | scheduled candidate | AI coding resources list; possible fit if it includes practical tools, not only articles/people. | Issue first. |
| 22 | 2026-07-01 | <https://github.com/TomGranot/awesome-ai-coding> | scheduled candidate | AI coding assistants and development tools list; possible fit as Codex workflow tooling. | Issue first; skip if assistant-only. |
| 23 | 2026-07-01 | <https://github.com/nandhakt/awesome-ai-coding-resources> | scheduled candidate | AI coding tutorials/resources list; possible fit if tool/resource sections are open to utility links. | Issue first. |
| 24 | 2026-07-01 | <https://github.com/kuku0922/awesome-ai-coding-enhance> | scheduled candidate | Mentions Claude Code, Codex, CLI tools, IDEs, and web chat; `codex-profiles` is a Codex CLI enhancement. | Direct PR if README has a CLI tools section; otherwise issue first. |
| 25 | 2026-07-01 | <https://github.com/jim-schwoebel/awesome_ai_agents> | scheduled candidate | Large AI-agent tools/resources catalogue; possible fit as tooling around coding agents. | Issue first; only PR if there is an agent tooling/utilities section. |
| 26 | 2026-07-08 | <https://github.com/slavakurilyak/awesome-ai-agents> | scheduled candidate | Agentic AI resources list; possible fit only under tools supporting AI coding agents. | Issue first; likely skip if agent-only. |
| 27 | 2026-07-08 | <https://github.com/Jenqyang/Awesome-AI-Agents> | scheduled candidate | Autonomous-agent catalogue with broad tool/resource coverage; possible fit as local Codex agent support. | Issue first. |
| 28 | 2026-07-08 | <https://github.com/caramaschiHG/awesome-ai-agents-2026> | scheduled candidate | 2026 AI agents list with many categories; possible fit if coding/tooling or developer-agent support sections exist. | Issue first. |
| 29 | 2026-07-08 | <https://github.com/ARUNAGIRINATHAN-K/awesome-ai-agents-2026> | scheduled candidate | AI agents list covering coding and developer agents; possible fit as Codex profile-management support tooling. | Issue first; direct PR only with coding-tools category. |
| 30 | 2026-07-08 | <https://github.com/ChatTeach/Awesome-AI-Agents> | scheduled candidate | Weekly-updated open-source AI-agent projects list; possible fit if it includes supporting devtools. | Issue first. |
| 31 | 2026-07-15 | <https://github.com/Zijian-Ni/awesome-ai-agents-2026> | scheduled candidate | AI agent frameworks/tools/platforms list; possible fit under coding-agent tooling if present. | Issue first. |
| 32 | 2026-07-15 | <https://github.com/NipunaRanasinghe/awesome-ai-agents> | scheduled candidate | Developer-oriented AI-agent tools/resources list; possible fit as Codex agent workflow utility. | Issue first. |
| 33 | 2026-07-15 | <https://github.com/Deep-Insight-Labs/awesome-ai-agents> | scheduled candidate | Practical AI-agent resources and utilities list; possible fit if coding-agent support tools are accepted. | Issue first. |
| 34 | 2026-07-15 | <https://github.com/korchasa/awesome-ai-agents> | scheduled candidate | Tools/frameworks list for building AI agents; possible fit only if local agent developer utilities are included. | Issue first; skip if framework-only. |
| 35 | 2026-07-15 | <https://github.com/brandonhimpfen/awesome-ai-agents> | scheduled candidate | AI-agent frameworks/tools/platforms list by an owner with adjacent coding-agent lists; possible fit under tools. | Issue first; respect strict taxonomy if present. |
| 36 | 2026-07-22 | <https://github.com/PathOnAIOrg/awesome-ai-agents> | scheduled candidate | AI-agent materials/resources list; possible fit under practical tools for coding agents. | Issue first. |
| 37 | 2026-07-22 | <https://github.com/shahshrey/awesome-ai-agents> | scheduled candidate | AI agents tools/resources list; possible fit as local Codex workflow utility if developer tools are accepted. | Issue first. |
| 38 | 2026-07-22 | <https://github.com/openbotai/awesome-ai-agents> | scheduled candidate | AI agents list; possible fit if utility/tooling categories include local developer-agent support. | Issue first. |
| 39 | 2026-07-22 | <https://github.com/buntys2010/awesome-ai-agents> | scheduled candidate | Open-source AI agent frameworks/tools list; possible fit if helper utilities are included. | Issue first; likely skip if framework-only. |
| 40 | 2026-07-22 | <https://github.com/ai-agents-simplified/Awesome-AI-Agents> | scheduled candidate | AI agents, frameworks, and tools list; possible fit under coding-agent support tools. | Issue first. |
| 41 | 2026-07-29 | <https://github.com/groovy-web/awesome-ai-agents> | scheduled candidate | AI-agent frameworks/tools/platforms list; possible fit under tools if it accepts small utilities. | Issue first. |
| 42 | 2026-07-29 | <https://github.com/aloth/awesome-ai-agents> | scheduled candidate | AI-agent frameworks, tools, platforms, papers, and resources; possible fit if developer-agent tooling section exists. | Issue first. |
| 43 | 2026-07-29 | <https://github.com/cjtdawn-cn/awesome-ai-agents> | scheduled candidate | AI-agent frameworks, Claude Code, agent skills, and multi-agent resources; possible fit as Codex skill/tooling reference. | Issue first; direct PR only if Codex resources are welcome. |
| 44 | 2026-07-29 | <https://github.com/zhangchuanteng/awesome-ai-agents> | scheduled candidate | Chinese AI-agent framework/platform/tutorial resource directory; possible fit if it has developer tools. | Issue first. |
| 45 | 2026-07-29 | <https://github.com/Correia-jpv/fucking-awesome-cli-apps> | scheduled candidate | Fork/variant of command-line apps list with stars/forks metadata; `codex-profiles` is a shell CLI app. | Direct PR if source format is editable and not generated-only. |
| 46 | 2026-08-05 | <https://github.com/moimikey/awesome-devtools> | scheduled candidate | Developer tools/resources list for full-stack engineers; possible fit as local CLI productivity utility. | Issue first; likely lower priority than AI/Codex lists. |
| 47 | 2026-08-05 | <https://github.com/minouou/awesome-devtools> | scheduled candidate | Developer tools list including AI coding assistants and productivity utilities; possible fit under AI/dev productivity. | Issue first; direct PR only if categories are clear. |
| 48 | 2026-08-05 | <https://github.com/spinov001-art/awesome-developer-tools-2026> | scheduled candidate | 2026 developer tools list with AI, DevOps, and CLI utilities; possible fit as Codex CLI helper. | Issue first due low metadata. |
| 49 | 2026-08-05 | <https://github.com/spinov001-art/awesome-developer-tools-2025> | scheduled candidate | Developer tools list with CLI utilities, AI tools, and automation; possible fit as Codex workflow automation CLI. | Issue first due low metadata. |
| 50 | 2026-08-05 | <https://github.com/Dev-Amjad/awesome-dev-tools> | scheduled candidate | Developer tools/resources list; possible fit as a small command-line productivity tool for Codex users. | Issue first; skip if list is inactive or too generic. |

2026-05-27 candidate checks:

- <https://github.com/launchapp-dev/awesome-ai-coding-tools>
  - Status: PR opened; see "Awesome AI Coding Tools by LaunchApp" above.
  - Validation: reviewed repository metadata, README, contribution rules,
    duplicate PR/issue history, and PR checks.
- <https://github.com/colicveinmedicine640/awesome-codex-cli>
  - Status: not a fit on 2026-05-27.
  - Why skipped: despite Codex CLI wording, the README is primarily a
    "download for Windows" wrapper around a raw ZIP asset rather than a normal
    curated awesome-list contribution target.
  - Validation: reviewed repository metadata and README; skipped before a
    duplicate PR/issue check because the channel quality was below the outreach
    bar.
- <https://github.com/commonplace-middledistance109/awesome-codex-cli>
  - Status: not a fit on 2026-05-27.
  - Why skipped: similar to the prior candidate, the README points users at a
    raw ZIP download flow and does not expose a credible curated-list structure
    for a `codex-profiles` entry.
  - Validation: reviewed repository metadata and README; skipped before a
    duplicate PR/issue check because the channel quality was below the outreach
    bar.
- <https://github.com/AlexZander-666/awesome-codex-agents>
  - Status: not a fit on 2026-05-27.
  - Why skipped: repository is an installable Codex subagent collection, not a
    tool directory. `codex-profiles` is a profile/account utility and would not
    be a valid agent entry.
  - Validation: reviewed repository metadata and README.
- <https://github.com/Caldalis/awesome-coding-agents>
  - Status: not a fit on 2026-05-27.
  - Why skipped: repository is a source-level documentation project about
    coding-agent runtime architecture, not a product/tool catalogue.
  - Validation: reviewed repository metadata and README.
- <https://github.com/furudo-erika/awesome-ai-coding-tools>
  - Status: deferred on 2026-05-27.
  - Why deferred: possible AI-coding-tools fit, but the repo had lower current
    signal than LaunchApp's list, and this pass was constrained by the
    existing open-PR gate.
  - Validation: reviewed repository metadata; no PR or issue opened.
- <https://github.com/yubing744/awesome-agentic-coding-cli>
  - Status: deferred on 2026-05-27.
  - Why deferred: terminal-first agentic coding CLI list is thematically
    relevant, but issues are disabled and `codex-profiles` is a companion
    utility rather than a coding agent CLI. Revisit only if opening another
    direct PR is warranted.
  - Validation: reviewed repository metadata and README; no PR opened.
- <https://github.com/tusharjadhav124/awesome-vibe-coding-tools>
  - Status: not a fit on 2026-05-27.
  - Why skipped: README is a generic download/install page centered on a raw
    ZIP asset, not a credible curated developer-tool list.
  - Validation: reviewed repository metadata and README.
- <https://github.com/runaicode/awesome-ai-coding-tools>
  - Status: not a fit on 2026-05-27.
  - Why skipped: repository focuses on AI-powered coding assistants and
    AI-assisted developer tools. `codex-profiles` is useful for Codex users,
    but it is not itself AI-powered or a coding assistant.
  - Validation: reviewed repository metadata and README; no PR opened.
- <https://github.com/tysoncung/awesome-vibe-coding>
  - Status: not a fit on 2026-05-27.
  - Why skipped: repository focuses on AI-assisted coding products and
    resources. `codex-profiles` is profile isolation infrastructure rather than
    an AI-assisted coding product.
  - Validation: reviewed repository metadata and README; no PR opened.
- <https://github.com/yeaight7/awesome-ai-devtools>
  - Status: not a fit on 2026-05-27.
  - Why skipped: repository generates its directory from structured tool data
    and focuses on AI-powered devtools. Adding `codex-profiles` would be a
    taxonomy mismatch.
  - Validation: reviewed repository structure and README; no PR opened.
- <https://github.com/ColinEberhardt/awesome-ai-developer-tools>
  - Status: not a fit on 2026-05-27.
  - Why skipped: mature AI-developer-tools list with a higher bar and existing
    Codex-related submissions; `codex-profiles` is a lower-level profile
    utility, not an AI developer tool by itself.
  - Validation: reviewed README scope and open PR queue; no PR opened.
- <https://github.com/wdzhwsh4067/awesome-coding-agents>
  - Status: not a fit on 2026-05-27.
  - Why skipped: contribution scope is coding-agent systems, papers, and
    documentation. `codex-profiles` is a companion profile/account utility
    rather than a coding agent.
  - Validation: reviewed contribution rules and README taxonomy; no PR opened.
- <https://github.com/alebcay/awesome-shell>
  - Status: not eligible on 2026-05-27.
  - Why skipped: contribution rules require shell tools to have at least 50
    GitHub stars. `Ducksss/codex-profiles` had 16 stars at review time.
  - Validation: reviewed contribution rules and repository stats; no PR opened.

## Monthly Reconciliation

2026-05-27 automation pass:

- Status: reconciliation plus four new outreach PRs.
- Branch checked: `pinzheng/outreach-2026-05-27`.
- Clean worktree note: the primary checkout had unrelated untracked
  `exports/` and `outputs/` directories, so this run used a separate clean
  worktree at `/Users/chaipinzheng/Dev/codex-profiles-outreach-2026-05-27`.
- Outreach limit: 22 recorded distribution PRs were still open before the new
  submission, exceeding the monthly gate of 15. This pass first opened one
  stronger fit from the backlog. After the user's explicit "more outreach"
  request, it opened three additional submissions that had a valid contribution
  shape: two real skill artifacts plus one broad shell-tool listing. 26
  distribution PRs are open after the expanded pass.
- New PRs opened:
  <https://github.com/launchapp-dev/awesome-ai-coding-tools/pull/8>,
  <https://github.com/Prat011/awesome-llm-skills/pull/132>,
  <https://github.com/ComposioHQ/awesome-codex-skills/pull/86>, and
  <https://github.com/uhub/awesome-shell/pull/14>.
- Scheduled backlog addendum: after the user requested a slow-release queue,
  added 50 additional GitHub repository candidates, deduped against every
  GitHub URL already recorded in this ledger, and grouped them into ten weekly
  five-repository waves from 2026-06-03 through 2026-08-05. No submissions
  were opened for these backlog candidates.
- Open issue confirmed:
  <https://github.com/no-fluff/awesome-vibe-coding/issues/115>.
- Open PRs confirmed:
  <https://github.com/0xWelt/Awesome-Vibe-Coding/pull/176>,
  <https://github.com/BNLNPPS/awesome-terminals-ai/pull/8>,
  <https://github.com/CodandoTV/awesome-ai-coding-assistants-playbook/pull/8>,
  <https://github.com/ComposioHQ/awesome-codex-skills/pull/86>,
  <https://github.com/KarelDO/awesome-codex/pull/15>,
  <https://github.com/PierrunoYT/awesome-ai-dev-tools/pull/26>,
  <https://github.com/Prat011/awesome-llm-skills/pull/132>,
  <https://github.com/RoggeOhta/awesome-codex-cli/pull/40>,
  <https://github.com/ai-for-developers/awesome-ai-coding-tools/pull/330>,
  <https://github.com/ai-for-developers/awesome-vibe-coding/pull/64>,
  <https://github.com/bluegalaxy111/awesome-vibe-coding/pull/8>,
  <https://github.com/bradAGI/awesome-cli-coding-agents/pull/90>,
  <https://github.com/devtoolsd/awesome-devtools/pull/230>,
  <https://github.com/eltociear/awesome-AI-driven-development/pull/52>,
  <https://github.com/filipecalegario/awesome-vibe-coding/pull/187>,
  <https://github.com/furudo-erika/awesome-vibe-coding-tools/pull/4>,
  <https://github.com/jamesmurdza/awesome-ai-devtools/pull/554>,
  <https://github.com/jiji262/awesome-vibe-coding-tools/pull/22>,
  <https://github.com/launchapp-dev/awesome-ai-coding-tools/pull/8>,
  <https://github.com/taahro/awesome-openai-codex-cli/pull/3>,
  <https://github.com/taskade/awesome-vibe-coding/pull/22>,
  <https://github.com/toolleeo/awesome-cli-apps-in-a-csv/pull/267>,
  <https://github.com/uhub/awesome-shell/pull/14>,
  <https://github.com/vaderyang/awesome-openai-codex/pull/2>,
  <https://github.com/walkinglabs/awesome-harness-engineering/pull/28>,
  and <https://github.com/wsxiaoys/awesome-ai-coding/pull/103>.
- Newly merged since the prior ledger update:
  <https://github.com/acvnace/awesome-vibe-coding-resources/pull/20> and
  <https://github.com/darknorth-123/Awesome-Codex-Plugins/pull/2>.
- Candidates skipped or deferred: LaunchApp accepted for PR; skipped
  `colicveinmedicine640/awesome-codex-cli`,
  `commonplace-middledistance109/awesome-codex-cli`,
  `AlexZander-666/awesome-codex-agents`,
  `Caldalis/awesome-coding-agents`, and
  `tusharjadhav124/awesome-vibe-coding-tools`; deferred
  `furudo-erika/awesome-ai-coding-tools` and
  `yubing744/awesome-agentic-coding-cli`; skipped `runaicode/awesome-ai-coding-tools`,
  `tysoncung/awesome-vibe-coding`, `yeaight7/awesome-ai-devtools`,
  `ColinEberhardt/awesome-ai-developer-tools`, and
  `wdzhwsh4067/awesome-coding-agents`; skipped `alebcay/awesome-shell` because
  its 50-star eligibility gate is not yet met.
- Validation: ran `git fetch --all --prune`; checked recorded GitHub PR and
  issue URLs with GitHub CLI; inspected open PR comment/review counts for
  actionable maintainer feedback; verified accepted entries in upstream
  READMEs for the two newly merged PRs; reviewed target README/contribution
  rules and duplicate history for the new LaunchApp PR; built and validated
  `codex-profile-switching` skills for the Prat011 and ComposioHQ catalogues
  with `quick_validate.py`, `markdownlint-cli`, and `git diff --check`; ran
  `git diff --check` in the Awesome Shell target fork and this repository.
  For the scheduled backlog addendum, used live web/GitHub search plus GitHub
  CLI repository metadata, excluded archived repositories, and excluded
  repositories already present in `LAUNCH.md`. Target repository-wide
  `markdownlint-cli` reports pre-existing README style issues. GitHub security
  checks for the two skill-catalog PRs passed at final verification time; the
  Awesome Shell PR reported no configured checks.
- Deferred channels retained without action: StackShare, OpenAlternative,
  LibHunt, SaaSHub, Antigravity Awesome Skills, and Kyrolabs Awesome Agents.

2026-05-21 automation pass:

- Status: reconciliation-only pass; no new PRs, issues, listing requests, or
  maintainer requests were opened.
- Ledger-first addendum: after user follow-up, added seven additional
  candidates/skips to the ledger without submitting them.
- Outreach addendum: after user requested outreach, opened one high-signal PR
  to <https://github.com/jiji262/awesome-vibe-coding-tools/pull/22>; no other
  new submissions were opened because the open-PR gate remains above 15.
- Mass outreach addendum on 2026-05-22: after explicit user request to do mass
  outreach, opened four additional PRs and one issue:
  <https://github.com/0xWelt/Awesome-Vibe-Coding/pull/176>,
  <https://github.com/acvnace/awesome-vibe-coding-resources/pull/20>,
  <https://github.com/KarelDO/awesome-codex/pull/15>,
  <https://github.com/furudo-erika/awesome-vibe-coding-tools/pull/4>, and
  <https://github.com/no-fluff/awesome-vibe-coding/issues/115>. Also logged
  five skipped or ineligible targets from the discovery sweep.
- Branch checked: `pinzheng/update-launch-pr-log`.
- Outreach limit: 20 recorded distribution PRs are still open, exceeding the
  monthly gate of 15 open submitted PRs; this pass used the allowed single new
  high-signal outreach item and stopped there.
- Validation: ran `git fetch --all --prune`; checked every recorded GitHub PR
  and issue URL with GitHub CLI; inspected maintainer comments on closed
  submissions; verified accepted entries in upstream READMEs where PRs were
  closed but maintainer-side listings landed; ran `git diff --check`.
- Open PRs confirmed:
  <https://github.com/BNLNPPS/awesome-terminals-ai/pull/8>,
  <https://github.com/CodandoTV/awesome-ai-coding-assistants-playbook/pull/8>,
  <https://github.com/PierrunoYT/awesome-ai-dev-tools/pull/26>,
  <https://github.com/RoggeOhta/awesome-codex-cli/pull/40>,
  <https://github.com/ai-for-developers/awesome-ai-coding-tools/pull/330>,
  <https://github.com/ai-for-developers/awesome-vibe-coding/pull/64>,
  <https://github.com/bluegalaxy111/awesome-vibe-coding/pull/8>,
  <https://github.com/bradAGI/awesome-cli-coding-agents/pull/90>,
  <https://github.com/darknorth-123/Awesome-Codex-Plugins/pull/2>,
  <https://github.com/devtoolsd/awesome-devtools/pull/230>,
  <https://github.com/eltociear/awesome-AI-driven-development/pull/52>,
  <https://github.com/filipecalegario/awesome-vibe-coding/pull/187>,
  <https://github.com/jamesmurdza/awesome-ai-devtools/pull/554>,
  <https://github.com/taahro/awesome-openai-codex-cli/pull/3>,
  <https://github.com/taskade/awesome-vibe-coding/pull/22>,
  <https://github.com/toolleeo/awesome-cli-apps-in-a-csv/pull/267>,
  <https://github.com/tranhoangpich/awesome-agentic-coding/pull/3>,
  <https://github.com/vaderyang/awesome-openai-codex/pull/2>,
  <https://github.com/walkinglabs/awesome-harness-engineering/pull/28>,
  and <https://github.com/wsxiaoys/awesome-ai-coding/pull/103>.
- Newly accepted or merged since the prior ledger update:
  <https://github.com/QAInsights/awesome-ai-tools/pull/54>,
  <https://github.com/namphuongtran/awesome-ai-coding-agent-tools/pull/4>,
  and <https://github.com/dalisoft/awesome-ai-coding/pull/65>.
- Closed or superseded submissions reconciled:
  <https://github.com/QAInsights/awesome-ai-tools/pull/50> was closed after
  the maintainer requested issue-tracker submission;
  <https://github.com/dalisoft/awesome-ai-coding/pull/64> was closed after the
  maintainer added the tool through PR #65; and
  <https://github.com/shinpr/awesome-codex-workflows/issues/13> was closed as
  out of current list scope.
- Deferred channels retained without action: StackShare, OpenAlternative,
  LibHunt, SaaSHub, Awesome Shell, Antigravity Awesome Skills, Kyrolabs
  Awesome Agents, and Awesome LLM Skills by Prat011.

2026-05-18 automation pass:

- Status: reconciliation-only pass; no new PRs, issues, listing requests, or
  maintainer requests were opened.
- Branch checked: `pinzheng/update-launch-pr-log`.
- Why no new outreach: 23 recorded distribution PRs are still open, exceeding
  the monthly gate of 15 open submitted PRs.
- Validation: ran `git fetch --all --prune`; checked every recorded GitHub PR
  and issue URL with GitHub CLI; ran `git diff --check`.
- Open PRs confirmed:
  <https://github.com/BNLNPPS/awesome-terminals-ai/pull/8>,
  <https://github.com/CodandoTV/awesome-ai-coding-assistants-playbook/pull/8>,
  <https://github.com/PierrunoYT/awesome-ai-dev-tools/pull/26>,
  <https://github.com/QAInsights/awesome-ai-tools/pull/50>,
  <https://github.com/RoggeOhta/awesome-codex-cli/pull/40>,
  <https://github.com/ai-for-developers/awesome-ai-coding-tools/pull/330>,
  <https://github.com/ai-for-developers/awesome-vibe-coding/pull/64>,
  <https://github.com/bluegalaxy111/awesome-vibe-coding/pull/8>,
  <https://github.com/bradAGI/awesome-cli-coding-agents/pull/90>,
  <https://github.com/dalisoft/awesome-ai-coding/pull/64>,
  <https://github.com/darknorth-123/Awesome-Codex-Plugins/pull/2>,
  <https://github.com/devtoolsd/awesome-devtools/pull/230>,
  <https://github.com/eltociear/awesome-AI-driven-development/pull/52>,
  <https://github.com/filipecalegario/awesome-vibe-coding/pull/187>,
  <https://github.com/jamesmurdza/awesome-ai-devtools/pull/554>,
  <https://github.com/namphuongtran/awesome-ai-coding-agent-tools/pull/4>,
  <https://github.com/taahro/awesome-openai-codex-cli/pull/3>,
  <https://github.com/taskade/awesome-vibe-coding/pull/22>,
  <https://github.com/toolleeo/awesome-cli-apps-in-a-csv/pull/267>,
  <https://github.com/tranhoangpich/awesome-agentic-coding/pull/3>,
  <https://github.com/vaderyang/awesome-openai-codex/pull/2>,
  <https://github.com/walkinglabs/awesome-harness-engineering/pull/28>,
  and <https://github.com/wsxiaoys/awesome-ai-coding/pull/103>.
- Open issue confirmed:
  <https://github.com/shinpr/awesome-codex-workflows/issues/13>.
- Merged PR confirmed:
  <https://github.com/milisp/awesome-codex-cli/pull/30>.
- Closed superseded PR confirmed:
  <https://github.com/RoggeOhta/awesome-codex-cli/pull/33>.
- Follow-up note: <https://github.com/QAInsights/awesome-ai-tools/pull/50>
  has a Vercel deployment authorization bot comment only; no maintainer action
  or reply is needed from `codex-profiles`.
- Deferred channels retained without action: StackShare, OpenAlternative,
  LibHunt, SaaSHub, Awesome Shell, Antigravity Awesome Skills, Kyrolabs
  Awesome Agents, and Awesome LLM Skills by Prat011.

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
