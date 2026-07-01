# Launch Ledger Historical Archive

This is the full pre-prune launch ledger snapshot archived on 2026-06-10.
Use it for audit history, old per-target evidence, and reconstruction.

**Frozen.** Active outreach tracking has since moved to Airtable (base
`appcezSUhDxz7uaQW`, tables `Targets` + `Log`), managed via
`scripts/outreach-tracker.mjs`. This file and the git history are the
pre-Airtable record; nothing is written here anymore. `LAUNCH.md` now holds only
positioning, channel copy, launch order, and policy.

---

## Archived Launch Playbook

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

- Status: replacement PR still open as of 2026-06-02.
- Why: highly relevant curated list with an existing `Account & Auth` section.
- Submission source: branch `Ducksss:pinzheng/add-codex-profiles-roggeohta`,
  commit `8510a07` adds `Ducksss/codex-profiles`.
- PR target: <https://github.com/RoggeOhta/awesome-codex-cli>
- PR: <https://github.com/RoggeOhta/awesome-codex-cli/pull/40>
- Note: original PR <https://github.com/RoggeOhta/awesome-codex-cli/pull/33>
  was closed and replaced after a fork-name collision with another
  `awesome-codex-cli` repository.

Awesome Codex CLI by milisp:

- Status: merged on 2026-05-18; upstream README entry verified on 2026-06-02.
- Why: second Codex-specific curated list with an existing `Development Tools`
  section that already includes config/account switching tools.
- Submission source: branch
  `pinzheng/add-codex-profiles`, commit `cd7b62d` adds `codex-profiles`.
- PR target: <https://github.com/milisp/awesome-codex-cli>
- PR: <https://github.com/milisp/awesome-codex-cli/pull/30>

Awesome CLI Apps:

- Status: not eligible yet as of 2026-06-02.
- Why: contribution rules require GitHub-hosted tools to be older than 90 days
  and have more than 20 stars. `codex-profiles` was created on 2026-04-25
  and currently has 18 stars.
- Resume path: revisit after the repo crosses the age/star threshold. The
  earliest age checkpoint is around 2026-07-24; submit to
  <https://github.com/agarrharr/awesome-cli-apps> only after the star threshold
  is also met.

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

- Status: closed on 2026-06-02.
- Why: active vibe-coding list with `CLI & Terminal Tools` and
  `Specialized CLI Tools` tables.
- Submission source: branch
  `pinzheng/add-codex-profiles`, commit `2804db2` adds `codex-profiles`.
- Follow-up: maintainer declined because the same `Add codex-profiles` change
  had been opened across many awesome lists and looked programmatic rather than
  an organic, single intentional placement. The maintainer said a fresh PR would
  be welcome if the project gets broader independent adoption.
- Distribution implication: pause broad near-identical awesome-list PRs and
  prefer Codex-specific placements, structured tool registries, issue-first
  suggestions, package ecosystems, and problem-led content.
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

- Status: merged on 2026-05-26; upstream README entry verified on 2026-06-02.
- Why: Codex ecosystem list that explicitly accepts plugins, MCP servers,
  workflows, integrations, and developer tools for OpenAI Codex.
- Submission source: branch `pinzheng/add-codex-profiles`, commit `4985656` adds
  `codex-profiles` to `Developer Tools`.
- Merge validation: verified the upstream README includes `codex-profiles` in a
  Developer Tools table.
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

- Status: deferred on 2026-05-18.
- Why: `codex-profiles` is Bash shell software, but the list is broad and has
  older open PRs. Keep it as a lower-priority target after Codex/AI-agent
  directories respond.
- Candidate target: <https://github.com/uhub/awesome-shell>

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
- Submission source: branch `pinzheng/add-codex-profiles-ai-for-dev-vibe`,
  commit `19c0153` adds `codex-profiles`.
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

- Status: skipped on 2026-05-18.
- Why: large and active Codex skill catalogue, but the contribution shape is a
  real reusable skill with `SKILL.md`. A plain `codex-profiles` product link
  would not satisfy the list's skill-centered scope.
- Duplicate check: searched open and closed PRs/issues for `codex-profiles`
  and `Ducksss/codex-profiles`; no real prior submission found.
- Deferred path: revisit only if creating an actual Codex skill wrapper around
  profile/account switching is desired.
- Reference: <https://github.com/ComposioHQ/awesome-codex-skills>

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

- Status: deferred on 2026-05-18.
- Why: skill-centric contribution process requires a documented and portable
  skill folder plus README update. A direct product link would not fit.
- Duplicate check: searched open and closed PRs/issues for `codex-profiles`
  and `Ducksss/codex-profiles`; no prior submission found.
- Deferred path: revisit only if building an actual "Codex profile switching"
  skill.
- Reference: <https://github.com/Prat011/awesome-llm-skills>

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

- Status: merged on 2026-05-22; upstream README entry verified on 2026-06-02.
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
  issues, recorded as non-blocking. PR checks: no checks reported.
- Merge validation: verified the upstream README includes `codex-profiles` under
  command-line resources.
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

CLIhub:

- Status: PR opened on 2026-06-02.
- Why: structured CLI registry for AI agents and developer tooling, with
  `dev-tools` and `shell` categories and npm install metadata. This is a better
  fit than broad awesome-list outreach because it is a machine-readable CLI
  catalogue where `codex-profile` can be installed by name.
- Duplicate check: searched PRs and issues in `clihub-ai/clihub` for
  `codex-profile`, `codex-profiles`, `Ducksss/codex-profiles`, and
  `CODEX_HOME`; no prior submission found.
- Submission source: branch `Ducksss:PinZheng/add-codex-profile`, commit
  `3374b63` adds one `src/clihub/data/registry.json` entry.
- Validation: validated the entry cleanly against the pre-addition registry;
  ran `uv run --with pytest --with pydantic --with pyyaml --with rich --with
  click --with rapidfuzz pytest -q tests/test_registry.py
  tests/test_submit.py` with 14 passing tests; ran `git diff --check`.
- PR target: <https://github.com/clihub-ai/clihub>
- PR: <https://github.com/clihub-ai/clihub/pull/4>

Awesome Agentic Coding CLI by yubing744:

- Status: PR opened on 2026-06-02.
- Why: terminal-first agentic-coding CLI list with a direct CLI support-tool
  fit. The fit is plausible because `codex-profile` manages Codex CLI/Desktop
  account and state separation, but it is still close to the broad awesome-list
  outreach pattern that should now be used sparingly.
- Duplicate check: searched for `codex-profiles`, `Ducksss/codex-profiles`,
  `CODEX_HOME`, and `auth.json`; no prior target PR or issue found. Existing
  PR #2 was for `everything-openai-codex`, not this project.
- Submission source: branch `Ducksss:pinzheng/add-codex-profiles`, commit
  `6a94e34` adds `codex-profile` to English and Chinese README lists.
- Validation: reviewed README/contribution fit in a temp clone; verified PR #3
  is open and limited to README changes.
- PR target: <https://github.com/yubing744/awesome-agentic-coding-cli>
- PR: <https://github.com/yubing744/awesome-agentic-coding-cli/pull/3>
- Follow-up: leave open for now because the target is terminal-first and
  Codex-adjacent, but do not use it as a template for more broad list PRs.

LaunchApp Awesome AI Coding Tools:

- Status: existing prior PR found on 2026-06-02; no new PR opened in this pass.
- Why: AI coding tools list with workflow/tooling categories, but it is broad
  and now sits inside the paused near-identical awesome-list pattern.
- Existing PR: <https://github.com/launchapp-dev/awesome-ai-coding-tools/pull/8>
  from `Ducksss:pinzheng/add-codex-profiles`.
- Pass cleanup: a subagent accidentally pushed a separate fork branch
  `Ducksss/awesome-ai-coding-tools:PinZheng/add-codex-profiles` without opening
  a PR; deleted that stray branch on 2026-06-02.
- Follow-up: consider withdrawing PR #8 if maintaining reputation with broad
  awesome-list curators is more important than keeping every open submission.

OpenAgent.bot:

- Status: submitted for editorial review on 2026-06-02.
- Why: open-source AI-resource directory that explicitly accepts tools, with a
  `Tools` category and a source-first review process.
- Submission URL: <https://www.openagent.bot/submit/>
- Submitted fields: project name `codex-profile`; repository
  `https://github.com/Ducksss/codex-profiles`; homepage
  `https://github.com/Ducksss/codex-profiles#readme`; category `Tools`;
  summary describing Codex CLI/Desktop account switching through isolated
  `CODEX_HOME` profiles.
- Validation: Playwright form submission returned status text `Submitted. We
  will review it from the admin queue.`

CLIHunt:

- Status: submitted for review on 2026-06-02.
- Why: AI agent and developer-tool registry with CLI tooling in scope and an
  LLM-queryable API; better fit than generic launch directories because the
  project is an installable command-line utility.
- Submission URL: <https://clihunt.dev/>
- Submitted fields: name `codex-profile`; tagline `Switch Codex CLI and
  Desktop accounts with isolated CODEX_HOME profiles instead of copying
  auth.json.`; URL `https://github.com/Ducksss/codex-profiles`; category
  `Other`; install command `npm install -g codex-profile`.
- Validation: Playwright form submission produced the browser alert `Thanks!
  Your tool has been submitted for review.`

ToolHunter:

- Status: deferred on 2026-06-02 after filling draft details.
- Why: AI-tool directory with a `Developer Tools` category, but the final
  submission step requires an email address.
- Submission URL: <https://toolhunter.ai/submit-a-tool>
- Prepared draft details: name `codex-profile`, README homepage, one-liner,
  `Developer Tools` category, `Free` pricing, target audience, one feature, and
  one highlight.
- Blocker: required email field. Do not submit with a personal email by
  assumption; resume only with an approved contact email or project contact.

Non-GitHub Directory Feasibility Sweep:

- Status: read-only feasibility pass completed on 2026-06-02.
- Best no-auth targets found: OpenAgent.bot and CLIHunt, both submitted during
  this pass; ToolHunter was deferred on required email.
- Good gated targets for later: DevHunt, Product Hunt, Uneed, SaaSHub, and
  StackShare require account setup, OAuth, paid queueing, verification, or a
  stable browser session.
- Other channel findings:
  - Codexlog: medium fit for a guide/article, but no public submit path found.
  - CLIs Finder: high fit as a CLI directory, but no public submit path found.
  - ToolShelf: high fit, submit page exists, but the form rendered as loading
    during inspection.
  - OpenAlternative: sign-in gated and weaker fit unless positioned as an
    open-source alternative to manual auth-file copying.
  - LibHunt: requires suggesting the project as an alternative to an existing
    LibHunt project.
  - OSS AI Hub: submit page exists but requires JavaScript; fields were not
    visible in text inspection.
  - OpenAgent.bot: submitted.
  - AgDex: accepts email submissions, but no email was sent in this pass.
  - OpenSourceAI.tech and Freemium.Tools: low fit or no submit path found.

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

2026-06-02 broad-outreach policy update:

- Status: broad awesome-list outreach paused.
- Why: Taskade declined PR #22 and explicitly cited the pattern of many
  near-identical `Add codex-profiles` PRs across awesome lists as below its
  curation bar. Treat this as a reputation signal, not just a single rejection.
- New outreach rule: do not open more broad or near-identical awesome-list PRs
  unless the target is Codex-specific, explicitly asks for Codex CLI/Desktop
  workflow tooling, or has a unique structured registry/package format.
- Preferred channels from here: Codex-specific issues/discussions, structured
  CLI/tool registries, package ecosystems, targeted maintainer issues, and
  problem-led content around `CODEX_HOME`, account switching, and avoiding
  `auth.json` copying.
- Subagent coverage:
  - Codex-specific sweep opened `yubing744/awesome-agentic-coding-cli#3` and
    skipped generated-looking mirrors, agent-only repos, and source-level
    documentation projects.
  - AI coding/devtools sweep opened no new PRs; it found existing
    `launchapp-dev/awesome-ai-coding-tools#8` and deleted a stray un-PR'd fork
    branch created during the pass.
  - Agentic-coding sweep opened no PRs and recommended skipping backlog #24-35
    under the new broad-list rule.
  - Vibe-coding sweep opened no PRs, found existing
    `adriannoes/awesome-vibe-coding#3`, and hit GitHub API rate limits during
    later duplicate checks.

2026-06-10 template-compliance workflow update:

- Status: mandatory pre-submit gate for every future direct PR and every
  issue-to-PR conversion.
- Why: maintainer feedback now includes process fit, not only list fit. Future
  outreach must respect the target repository's PR template, issue template,
  and contribution flow before adding another submission.
- Required inspection before drafting:
  - PR templates: `.github/pull_request_template.md`,
    `.github/PULL_REQUEST_TEMPLATE/*`, repository-level
    `pull_request_template.md`, and the rendered GitHub PR form if no template
    file is visible in the checkout.
  - Issue templates/forms: `.github/ISSUE_TEMPLATE/*` and the rendered GitHub
    issue choices when the workflow is issue-first.
  - Contribution rules: `CONTRIBUTING*`, README contribution sections, recent
    accepted PRs, closed similar submissions, sorting rules, category rules,
    and metadata requirements.
- Submission rule: use the target's template verbatim, preserve headings and
  checkboxes, fill every required section truthfully, and write `N/A` only when
  the section genuinely does not apply. If a template or guide asks for tests,
  lint, screenshots, duplicate checks, alphabetical sorting, multi-file
  metadata, language mirrors, or issue links, complete and document those items
  before opening the PR.
- Stop conditions: do not open a PR if the repository says "issue first",
  prohibits self-submission or self-promotion, requires maintainer invitation,
  requires facts we cannot verify, or has a template we cannot satisfy without
  invented claims. Open a scope-check issue only when issue templates allow it;
  otherwise skip and record the skip.
- Ledger requirement: each future outreach row or reconciliation entry must
  record the inspected template/guideline paths, duplicate-search terms,
  required checks, template-compliance outcome, and the exact reason for PR,
  issue-first, or skip.

| # | Repository | Status | Why it may fit | Suggested outreach |
| - | - | - | - | - |
| 1 | <https://github.com/colicveinmedicine640/awesome-codex-cli> | deferred candidate | Codex CLI list with tools, skills, subagents, plugins, and resources; likely mirrors an existing Codex list, so verify originality before outreach. | Issue first unless README clearly allows direct tool PRs. |
| 2 | <https://github.com/commonplace-middledistance109/awesome-codex-cli> | deferred candidate | Codex CLI resource list with many tools and plugins; `codex-profiles` fits only if the repo is independently maintained. | Issue first after clone/originality check. |
| 3 | <https://github.com/AlexZander-666/awesome-codex-agents> | issue opened on 2026-06-09 | Codex-agent collection; `codex-profiles` may fit as Codex CLI profile/account support for users running different agent teams across isolated environments. | Issue: <https://github.com/AlexZander-666/awesome-codex-agents/issues/2>. Send a PR only if the maintainer confirms scope. |
| 4 | <https://github.com/furudo-erika/awesome-ai-coding-tools> | issue opened on 2026-06-09 | AI coding tools list from an owner that also maintains a vibe-coding tools list; README references CLI integration points and terminal helpers, but broad-list policy now favors maintainer confirmation before PRs. | Issue: <https://github.com/furudo-erika/awesome-ai-coding-tools/issues/6>. Send a PR only if the maintainer confirms scope. |
| 5 | <https://github.com/tyler-j-dao/awesome-ai-coding-tools> | issue opened on 2026-06-09 | AI coding tools catalogue with shell/CLI assistant and coding-agent categories; possible fit as Codex CLI/Desktop support tooling. | Issue: <https://github.com/tyler-j-dao/awesome-ai-coding-tools/issues/5>. Send a PR only if the maintainer confirms scope. |
| 6 | <https://github.com/danielrosehill/Awesome-AI-Coding-Tools> | issue opened on 2026-06-09 | Snapshot-style AI coding tools list with agent-unification, CLI, context-tool, and developer-utility sections; possible fit as a Codex CLI accessory. | Issue: <https://github.com/danielrosehill/Awesome-AI-Coding-Tools/issues/6>. Send a PR only if the maintainer confirms scope. |
| 7 | <https://github.com/launchapp-dev/awesome-ai-coding-tools> | existing PR found | AI coding tools list explicitly includes editors, agents, code review, testing, CLI tools, and workflow automation, but it is broad and now subject to the 2026-06-02 pause on near-identical awesome-list PRs. | Existing PR #8 is open; do not open another. Consider withdrawing if broad-list reputation risk outweighs keeping the submission. |
| 8 | <https://github.com/Icloudeng/awesome-ai-coding-tools> | issue opened on 2026-06-09 | AI developer-tool list covers workflow automation, autonomous agents, and several CLI-tagged entries; possible fit as Codex workflow/account-state support. | Issue: <https://github.com/Icloudeng/awesome-ai-coding-tools/issues/11>. Send a PR only if the maintainer confirms scope. |
| 9 | <https://github.com/tomrzv/Awesome-AI-Coding-Tools> | issue opened on 2026-06-09 | AI coding tools list includes developer productivity, workflow utilities, and a `Terminal & CLI Tools` section. | Issue: <https://github.com/tomrzv/Awesome-AI-Coding-Tools/issues/8>. Send a PR only if the maintainer confirms scope. |
| 10 | <https://github.com/Web4application/awesome-ai-coding-tools> | deferred candidate | AI coding tools catalogue; possible low-priority fit if terminal/helper tools are included. | Issue first. |
| 11 | <https://github.com/runaicode/awesome-ai-coding-tools> | issue opened on 2026-06-09 | Weekly-updated AI coding tools list with an `AI Terminal & CLI Tools` section and Codex CLI already listed elsewhere in the README. | Issue: <https://github.com/runaicode/awesome-ai-coding-tools/issues/4>. Send a PR only if the maintainer confirms scope. |
| 12 | <https://github.com/kax168/awesome-ai-coding-tools-2026> | issue opened on 2026-06-09 | 2026 AI coding/productivity tools list; possible fit as a narrow Codex CLI/Desktop productivity helper. | Issue: <https://github.com/kax168/awesome-ai-coding-tools-2026/issues/4>. Send a PR only if the maintainer confirms scope. |
| 13 | <https://github.com/JohannFreddyLoayzaHuana/awesome-ai-coding-tools> | skipped on 2026-06-09 | AI coding workflow/tool list updated recently, but inspected README routes support/contribution links to a raw ZIP installer URL instead of a normal issue or contribution page. | Do not contact unless the repository changes to a normal curated-list contribution flow. |
| 14 | <https://github.com/dingjiu1989-hue/awesome-ai-coding-tools> | issue opened on 2026-06-09 | AI coding assistants and developer AI tools list with an `AI-Powered CLI Tools` section; possible fit as Codex workflow utility. | Issue: <https://github.com/dingjiu1989-hue/awesome-ai-coding-tools/issues/3>. Send a PR only if the maintainer confirms scope. |
| 15 | <https://github.com/kax168/awesome-ai-coding-agents> | deferred candidate | AI coding-agent list; `codex-profiles` fits only if it has infrastructure/support tooling. | Issue first; skip if agent-only. |
| 16 | <https://github.com/kax168/awesome-ai-coding-assistants-2026> | deferred candidate | 2026 coding assistants/tools list; possible fit if it has helper/tooling categories. | Issue first. |
| 17 | <https://github.com/ColinEberhardt/awesome-ai-developer-tools> | issue opened on 2026-06-09 | More mature AI developer-tool list; possible fit only if the maintainer accepts narrow Codex workflow utilities alongside full AI developer products. | Issue: <https://github.com/ColinEberhardt/awesome-ai-developer-tools/issues/30>. Send a PR only if the maintainer confirms scope. |
| 18 | <https://github.com/dbpunk-labs/awesome-ai-developer-tools> | deferred candidate | AI developer tools list; possible if it accepts CLI/productivity utilities. | Issue first due sparse metadata. |
| 19 | <https://github.com/yeaight7/awesome-ai-devtools> | issue opened on 2026-06-09 | Open-source map of AI developer tooling ecosystem with terminal-agent, agent-skills/plugins, and repo-automation coverage; possible fit as Codex workflow isolation support. | Issue: <https://github.com/yeaight7/awesome-ai-devtools/issues/8>. Send a PR only if the maintainer confirms scope. |
| 20 | <https://github.com/Ravi-Chandraa/awesome-ai-devtools> | issue opened on 2026-06-09 | AI devtools list with command-line, shell assistant, agent, and workflow-tool coverage; possible fit as Codex profile isolation tooling. | Issue: <https://github.com/Ravi-Chandraa/awesome-ai-devtools/issues/2>. Send a PR only if the maintainer confirms scope. |
| 21 | <https://github.com/tamilselvanarjun/awesome-ai-devtools> | deferred candidate | AI devtools list; possible lower-priority fit. | Issue first. |
| 22 | <https://github.com/buainoai/awesome-ai-devtools-multilingual> | issue opened on 2026-06-09 | Multilingual AI devtools list with command-line, agent, Codex, Claude Code, token-usage, and skill-sync entries; possible fit as Codex profile isolation tooling. | Issue: <https://github.com/buainoai/awesome-ai-devtools-multilingual/issues/12>. Send a PR only if the maintainer confirms scope and preferred language coverage. |
| 23 | <https://github.com/yasir27uk/awesome-ai-devtools> | issue opened on 2026-06-09 | AI devtools list with command-line, desktop, OpenAI, and agent-tool sections; possible lower-priority fit as Codex profile isolation tooling. | Issue: <https://github.com/yasir27uk/awesome-ai-devtools/issues/1>. Send a PR only if the maintainer confirms scope. |
| 24 | <https://github.com/Transcenda/awesome-agentic-coding> | deferred candidate | Agentic coding adoption list; may accept workflow/account-state utilities for coding agents. | Issue first; verify contribution style. |
| 25 | <https://github.com/fecet/awesome-agentic-coding> | deferred candidate | Agentic coding list; possible fit if it includes tools and support utilities. | Issue first. |
| 26 | <https://github.com/191086/awesome_agentic_coding> | deferred candidate | Rules/skills/commands/hooks for agentic coding; `codex-profiles` may fit only as environment support. | Issue first; skip if rules/skills-only. |
| 27 | <https://github.com/Supersynergy/awesome-agentic-coding> | deferred candidate | Claude Code focused agentic-coding bundle; possible cross-agent fit only if Codex tooling is accepted. | Issue first; likely borderline. |
| 28 | <https://github.com/li0nel/awesome-agentic-coding> | deferred candidate | Agentic coding list; low-metadata but potentially relevant. | Issue first. |
| 29 | <https://github.com/yubing744/awesome-agentic-coding-cli> | PR opened | Terminal-first agentic coding CLI list; strong thematic fit for Codex CLI account/profile helper, but still close to the broad awesome-list pattern. | PR #3 opened on 2026-06-02; do not use as a template for more broad list PRs. |
| 30 | <https://github.com/quome-cloud/awesome-coding-agents> | issue opened on 2026-06-09 | Coding-agent list with a `Tools & Frameworks` section; possible fit as support tooling rather than an agent. | Issue: <https://github.com/quome-cloud/awesome-coding-agents/issues/7>. Existing unrelated PR #6 is for another Codex project; send a PR only if the maintainer confirms scope. |
| 31 | <https://github.com/closedloop-technologies/awesome-coding-agents> | deferred candidate | Coding-agent list; possible but low metadata. | Issue first. |
| 32 | <https://github.com/outer-joined/awesome-coding-agents> | deferred candidate | Coding-agent list updated recently; possible fit if support tooling is allowed. | Issue first. |
| 33 | <https://github.com/Caldalis/awesome-coding-agents> | deferred candidate | Resource list for learning Codex and Claude Code; potential fit as practical Codex CLI/Desktop utility. | Direct PR if tools/resources section exists. |
| 34 | <https://github.com/wdzhwsh4067/awesome-coding-agents> | issue opened on 2026-06-09 | LLM coding agents, benchmarks, harness design, and workflow integration list; possible fit as Codex workflow infrastructure. | Issue: <https://github.com/wdzhwsh4067/awesome-coding-agents/issues/4>. Existing unrelated PR #2 is for another Codex project; send a PR only if the maintainer confirms scope. |
| 35 | <https://github.com/tiennm99/awesome-coding-agents> | deferred candidate | Daily-updated ranking of AI agent coding tools; possible fit only if non-agent helper tools are accepted. | Issue first; likely borderline. |
| 36 | <https://github.com/YuyaoGe/Awesome-Vibe-Coding> | issue opened on 2026-06-09 | Higher-star vibe-coding survey/list with `Development Environment of Coding Agent` and isolated-runtime themes; possible fit only if concrete Codex runtime tooling is in scope. | Issue: <https://github.com/YuyaoGe/Awesome-Vibe-Coding/issues/8>. Send a PR only if the maintainer confirms scope. |
| 37 | <https://github.com/adriannoes/awesome-vibe-coding> | existing issue found | AI-assisted development resources across Cursor, Claude Code, skills, notebooks, and reports; possible fit as Codex workflow utility. | Existing issue #3 asks about including a Codex profile-switching utility; do not duplicate. |
| 38 | <https://github.com/tysoncung/awesome-vibe-coding> | issue opened on 2026-06-09 | AI coding assistants/tools list with explicit `CLI Tools`, terminal-agent, and workflow-integration coverage. | Issue: <https://github.com/tysoncung/awesome-vibe-coding/issues/6>. Send a PR only if the maintainer confirms scope. |
| 39 | <https://github.com/Qbeczek1/awesome-vibe-coding> | deferred candidate | Vibe-coded apps/tools/projects list; possible fit if tool listings are accepted, not just built projects. | Issue first. |
| 40 | <https://github.com/tusharjadhav124/awesome-vibe-coding-tools> | skipped on 2026-06-09 | Recently updated repository, but inspected README is a generic download/install page pointing to raw ZIP assets rather than a credible curated-list contribution target. | Do not contact unless the repository changes to a normal curated-list contribution flow. |
| 41 | <https://github.com/vibe-coding-labs/awesome-vibe-coding> | issue opened on 2026-06-09 | Chinese vibe-coding AI programming resources list with `Terminal`, OpenAI Codex, and professional developer-tool sections; possible fit as a Codex CLI profile helper. | Issue: <https://github.com/vibe-coding-labs/awesome-vibe-coding/issues/1>. Send a PR only if the maintainer confirms scope. |
| 42 | <https://github.com/andi-nugroho/awesome-vibe-coding> | deferred candidate | Vibe-coding references list; possible but lower priority because last update was 2025. | Issue first. |
| 43 | <https://github.com/peteresmond/awesome-vibe-coding> | deferred candidate | Vibe-coding resources list; possible fit if tool sections exist. | Issue first. |
| 44 | <https://github.com/byeadro/awesome-vibe-coding> | deferred candidate | Tools, prompts, and patterns for non-technical founders shipping with AI; possible fit only if developer tools are in scope. | Issue first; likely borderline. |
| 45 | <https://github.com/Feilul6656/awesome-vibe-coding> | skipped on 2026-06-09 | Very recent vibe-coding resources list, but inspected README is generic, issues are disabled, and the repo did not show a credible targeted contribution path. | Do not contact unless the repository changes to a normal curated-list contribution flow. |
| 46 | <https://github.com/tangyuan-dev/awesome-vibe-coding> | issue opened on 2026-06-09 | Chinese vibe-coding tools/tutorials/prompt-template list with AI programming tools and helper-tool categories; possible fit as a Codex CLI profile helper. | Issue: <https://github.com/tangyuan-dev/awesome-vibe-coding/issues/1>. Send a PR only if the maintainer confirms scope. |
| 47 | <https://github.com/alimaliai/awesome-vibe-coding> | skipped on 2026-06-09 | Recently updated repository, but inspected README routes support/contribution links to a raw ZIP asset and issues are disabled. | Do not contact unless the repository changes to a normal curated-list contribution flow. |
| 48 | <https://github.com/EffectiveVibeCoding/awesome-vibe-coding> | deferred candidate | Vibe-coding list; possible but lower priority due older activity and sparse metadata. | Issue first. |
| 49 | <https://github.com/rubylikeya/awesome-vibe-coding> | deferred candidate | Vibe Coding cases, tools, and best practices directory; possible fit as tool entry. | Issue first. |
| 50 | <https://github.com/di-su/awesome-vibe-coding> | deferred candidate | Vibe-coding resources, AI coding tools, and remote developer jobs list; possible tool fit. | Issue first. |

## Monthly Reconciliation

2026-06-10 workflow hardening:

- Status: workflow-only update; no external PRs, issues, directory
  submissions, or form submissions were opened in this pass.
- Branch checked: `PinZheng/update-outreach-template-workflow`.
- Why: user reported maintainer feedback that submissions should follow target
  repository PR templates and contribution rules. This reconciles that feedback
  into the launch workflow before the next outreach pass.
- Policy change: future direct PRs and issue-to-PR conversions now require
  explicit inspection of PR/issue templates, `CONTRIBUTING*` files, README
  contribution sections, required checkboxes/checks, and recent accepted PR
  style before submission. If the target workflow cannot be satisfied
  truthfully, the target must be issue-first or skipped.
- Validation: searched open `codex-profile(s)` PRs for template/contribution
  feedback, then updated this ledger as the source of truth for future outreach.

2026-06-09 second issue-first outreach pass:

- Status: opened 10 additional targeted maintainer issues; no new PRs,
  directory submissions, or form submissions were opened in this pass.
- Branch checked: `PinZheng/outreach-2026-06-09-second-pass`.
- Why issue-first: continued the June 9 maintainer-confirmation pattern for
  broad or ambiguous lists while the external PR backlog remains high.
- Issues opened:
  <https://github.com/AlexZander-666/awesome-codex-agents/issues/2>,
  <https://github.com/kax168/awesome-ai-coding-tools-2026/issues/4>,
  <https://github.com/dingjiu1989-hue/awesome-ai-coding-tools/issues/3>,
  <https://github.com/Ravi-Chandraa/awesome-ai-devtools/issues/2>,
  <https://github.com/buainoai/awesome-ai-devtools-multilingual/issues/12>,
  <https://github.com/yasir27uk/awesome-ai-devtools/issues/1>,
  <https://github.com/quome-cloud/awesome-coding-agents/issues/7>,
  <https://github.com/wdzhwsh4067/awesome-coding-agents/issues/4>,
  <https://github.com/YuyaoGe/Awesome-Vibe-Coding/issues/8>, and
  <https://github.com/vibe-coding-labs/awesome-vibe-coding/issues/1>.
- Selection notes: used diverse owners and skipped issue-disabled or already
  contacted rows; `quome-cloud/awesome-coding-agents` and
  `wdzhwsh4067/awesome-coding-agents` had unrelated open PRs for another Codex
  project, so this pass used scope-check issues rather than PRs.
- Validation: checked current backlog status, repository metadata, README
  category fit, issue availability, duplicate `codex-profile(s)` history, and
  verified all 10 new issue URLs are open through GitHub CLI.

2026-06-09 issue-first outreach pass:

- Status: opened 10 targeted maintainer issues; no new PRs, directory
  submissions, or form submissions were opened in this pass.
- Branch checked: `PinZheng/outreach-2026-06-09`.
- Why issue-first: GitHub search currently shows 47 open external
  `codex-profile(s)` PRs authored by `Ducksss`, and the 2026-06-02 policy
  pause remains in force after maintainer feedback on broad near-identical
  awesome-list PRs. Today used maintainer-scope questions instead of adding
  more PR burden.
- Issues opened:
  <https://github.com/furudo-erika/awesome-ai-coding-tools/issues/6>,
  <https://github.com/runaicode/awesome-ai-coding-tools/issues/4>,
  <https://github.com/ColinEberhardt/awesome-ai-developer-tools/issues/30>,
  <https://github.com/yeaight7/awesome-ai-devtools/issues/8>,
  <https://github.com/tysoncung/awesome-vibe-coding/issues/6>,
  <https://github.com/Icloudeng/awesome-ai-coding-tools/issues/11>,
  <https://github.com/tomrzv/Awesome-AI-Coding-Tools/issues/8>,
  <https://github.com/danielrosehill/Awesome-AI-Coding-Tools/issues/6>,
  <https://github.com/tyler-j-dao/awesome-ai-coding-tools/issues/5>, and
  <https://github.com/tangyuan-dev/awesome-vibe-coding/issues/1>.
- Selection notes: skipped `JohannFreddyLoayzaHuana/awesome-ai-coding-tools`,
  `tusharjadhav124/awesome-vibe-coding-tools`, and
  `alimaliai/awesome-vibe-coding` because their inspected READMEs route
  support or contribution paths to raw ZIP assets; skipped
  `Feilul6656/awesome-vibe-coding` because issues are disabled and the README
  did not show a credible targeted contribution flow.
- Validation: checked GitHub auth, current `Ducksss/codex-profiles` repo
  metadata, existing PR/issue states, backlog repository metadata, README
  category fit, and duplicate PR/issue history for the issue-opened targets;
  verified all 10 new issue URLs are open through GitHub CLI.

2026-06-02 distribution pass:

- Status: quality-gated distribution pass with subagents; broad awesome-list
  expansion paused after a maintainer explicitly objected to near-identical PR
  patterns.
- Branch checked: `PinZheng/distribution-pass-2026-06-02`.
- Existing outreach reconciled:
  - Newly verified as merged/listed:
    <https://github.com/acvnace/awesome-vibe-coding-resources/pull/20> and
    <https://github.com/darknorth-123/Awesome-Codex-Plugins/pull/2>.
  - Still open:
    <https://github.com/RoggeOhta/awesome-codex-cli/pull/40>,
    <https://github.com/BNLNPPS/awesome-terminals-ai/pull/8>,
    <https://github.com/CodandoTV/awesome-ai-coding-assistants-playbook/pull/8>,
    <https://github.com/PierrunoYT/awesome-ai-dev-tools/pull/26>,
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
    <https://github.com/taahro/awesome-openai-codex-cli/pull/3>,
    <https://github.com/toolleeo/awesome-cli-apps-in-a-csv/pull/267>,
    <https://github.com/vaderyang/awesome-openai-codex/pull/2>,
    <https://github.com/walkinglabs/awesome-harness-engineering/pull/28>,
    <https://github.com/wsxiaoys/awesome-ai-coding/pull/103>,
    <https://github.com/launchapp-dev/awesome-ai-coding-tools/pull/8>,
    and <https://github.com/yubing744/awesome-agentic-coding-cli/pull/3>.
  - Closed with maintainer warning:
    <https://github.com/taskade/awesome-vibe-coding/pull/22>.
  - Inaccessible during reconciliation:
    <https://github.com/tranhoangpich/awesome-agentic-coding/pull/3>, because
    GitHub could not resolve `tranhoangpich/awesome-agentic-coding`.
- New PRs opened:
  <https://github.com/yubing744/awesome-agentic-coding-cli/pull/3> and
  <https://github.com/clihub-ai/clihub/pull/4>.
- Directory submissions:
  OpenAgent.bot and CLIHunt were submitted for review through no-auth forms.
  ToolHunter was deferred because the final step requires an email address.
- Cleanup:
  deleted stray fork branch
  `Ducksss/awesome-ai-coding-tools:PinZheng/add-codex-profiles`, which was
  pushed during the pass without an associated PR.
- Validation:
  ran `git fetch --all --prune`; checked recorded PR and issue statuses with
  GitHub CLI; verified accepted entries in upstream READMEs; used Playwright
  for submitted forms; validated the CLIhub registry entry against the
  pre-addition registry; ran `uv run --with pytest --with pydantic --with
  pyyaml --with rich --with click --with rapidfuzz pytest -q
  tests/test_registry.py tests/test_submit.py` in the CLIhub clone with 14
  passing tests; ran `git diff --check`.

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
