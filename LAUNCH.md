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
- GitHub Discussions are enabled for questions and workflow feedback.
- Public feedback thread:
  <https://github.com/Ducksss/codex-profiles/discussions/1>
- Repo topics include `bash`, `cli`, `codex`, `codex-cli`, `codex-desktop`,
  `codex-home`, `developer-tools`, `linux`, `macos`, `openai`, and
  `openai-codex`.
- Install paths:

```sh
brew install Ducksss/tap/codex-profile
```

```sh
git clone https://github.com/Ducksss/codex-profiles.git
cd codex-profiles
make install
```

Quick verification:

```sh
codex-profile doctor
codex-profile path personal
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
2. Post `Show HN` after confirming the Homebrew install works from the public
   tap.
3. Publish the DEV/Hashnode technical write-up and link back to the HN thread
   only as context, not as vote solicitation.
4. Repost the short demo clip on X, Bluesky, Mastodon, and LinkedIn with the
   Homebrew command and GitHub link.
5. Submit to relevant curated lists or tool directories only where the tool
   clearly fits.
6. Launch on Product Hunt after screenshots, demo video, README, and install
   path have all been click-tested.

## Deferred Channels

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
- Branch: `Ducksss:pinzheng/add-codex-profiles-roggeohta`.
- Commit: `8510a07` adds `Ducksss/codex-profiles`.
- PR target: <https://github.com/RoggeOhta/awesome-codex-cli>
- PR: <https://github.com/RoggeOhta/awesome-codex-cli/pull/40>
- Note: original PR <https://github.com/RoggeOhta/awesome-codex-cli/pull/33>
  was closed and replaced after a fork-name collision with another
  `awesome-codex-cli` repository.

Awesome Codex CLI by milisp:

- Status: merged on 2026-05-18.
- Why: second Codex-specific curated list with an existing `Development Tools`
  section that already includes config/account switching tools.
- Resume path: temporary clone at `/tmp/milisp-awesome-codex-cli`, branch
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
- Resume path: temporary clone at `/tmp/awesome-devtools`, branch
  `pinzheng/add-codex-profiles`, commit `c688e2a` adds `codex-profiles`.
- PR target: <https://github.com/devtoolsd/awesome-devtools>
- PR: <https://github.com/devtoolsd/awesome-devtools/pull/230>

Awesome AI-Driven Development:

- Status: PR opened on 2026-05-18.
- Why: active AI-development list with existing Codex, Codex Desktop, and
  Codex-adjacent CLI tools in `Terminal & CLI Agents`.
- Resume path: temporary clone at `/tmp/awesome-AI-driven-development`, branch
  `pinzheng/add-codex-profiles`, commit `19ed072` adds `codex-profiles`.
- PR target: <https://github.com/eltociear/awesome-AI-driven-development>
- PR: <https://github.com/eltociear/awesome-AI-driven-development/pull/52>

Awesome Vibe Coding by no-fluff:

- Status: PR candidate prepared locally on 2026-05-18.
- Why: targeted list for agentic/vibe-coding workflows with an `Other tools`
  section for companion utilities around coding agents.
- Caveat: contribution notes ask users to open an issue first. Use the local
  candidate as source material, or open a PR if the maintainer accepts direct
  additions.
- Resume path: temporary clone at `/tmp/awesome-vibe-coding`, branch
  `pinzheng/add-codex-profiles`, commit `8c138eb` adds `codex-profiles`.
- PR or issue target: <https://github.com/no-fluff/awesome-vibe-coding>

Awesome AI Coding Tools:

- Status: PR opened on 2026-05-18.
- Why: high-reach AI coding tools list with existing Codex CLI and
  Codex-adjacent developer productivity tools.
- Caveat: contribution rules prefer tools that are AI-powered or AI-enhanced.
  This is a borderline but defensible entry because `codex-profiles` is a
  Codex workflow helper rather than a standalone AI model/tool.
- Resume path: temporary clone at `/tmp/awesome-ai-coding-tools`, branch
  `pinzheng/add-codex-profiles`, commit `e7634ee` adds `codex-profiles`.
- PR target: <https://github.com/ai-for-developers/awesome-ai-coding-tools>
- PR: <https://github.com/ai-for-developers/awesome-ai-coding-tools/pull/330>

AI IDEs & Coding Assistants:

- Status: PR opened on 2026-05-18.
- Why: small but current manually curated AI tools directory with a
  `Developer Productivity & Workflow` section.
- Resume path: temporary clone at `/tmp/awesome-ai-tools`, branch
  `pinzheng/add-codex-profiles`, commit `08da146` adds `codex-profiles`.
- PR target: <https://github.com/QAInsights/awesome-ai-tools>
- PR: <https://github.com/QAInsights/awesome-ai-tools/pull/50>

Awesome Dev Tools by t18n:

- Status: PR candidate prepared locally on 2026-05-18.
- Why: general developer-tool list accepting useful developer utilities; lower
  priority than Codex/AI-agent-specific channels, but still relevant.
- Resume path: temporary clone at `/tmp/t18n-awesome-dev-tools`, branch
  `pinzheng/add-codex-profiles`, commit `e3bb632` adds `codex-profiles`.
- PR target: <https://github.com/t18n/awesome-dev-tools>

Awesome Terminals AI:

- Status: PR opened on 2026-05-18.
- Why: AI terminal workflow catalogue with a `Shell Enhancements` section;
  `codex-profiles` is a shell-level helper for Codex account/profile
  separation.
- Resume path: temporary clone at `/tmp/awesome-terminals-ai`, branch
  `pinzheng/add-codex-profiles`, commit `b64abeb` adds `codex-profiles`.
- PR target: <https://github.com/BNLNPPS/awesome-terminals-ai>
- PR: <https://github.com/BNLNPPS/awesome-terminals-ai/pull/8>

Awesome Vibe Coding by Taskade:

- Status: PR opened on 2026-05-18.
- Why: active vibe-coding list with `CLI & Terminal Tools` and
  `Specialized CLI Tools` tables.
- Resume path: temporary clone at `/tmp/taskade-awesome-vibe-coding`, branch
  `pinzheng/add-codex-profiles`, commit `2804db2` adds `codex-profiles`.
- PR target: <https://github.com/taskade/awesome-vibe-coding>
- PR: <https://github.com/taskade/awesome-vibe-coding/pull/22>

Awesome Vibe Coding by bluegalaxy111:

- Status: PR opened on 2026-05-18.
- Why: terminal-agent-focused vibe-coding handbook with Codex already listed
  in `AI Coding Agents > Terminal / CLI`.
- Resume path: temporary clone at `/tmp/bluegalaxy-awesome-vibe-coding`,
  branch `pinzheng/add-codex-profiles`, commit `24b3077` adds
  `codex-profiles`.
- PR target: <https://github.com/bluegalaxy111/awesome-vibe-coding>
- PR: <https://github.com/bluegalaxy111/awesome-vibe-coding/pull/8>

Awesome CLI Apps in a CSV:

- Status: PR opened on 2026-05-18.
- Why: high-reach CLI catalogue with an explicit `data/apps.csv` PR path and
  an existing `ai` category for terminal AI tools.
- Resume path: temporary clone at `/tmp/awesome-cli-apps-in-a-csv`, branch
  `pinzheng/add-codex-profiles`, commit `e359888` adds `codex-profiles`.
- Validation: parsed `data/apps.csv` with Ruby CSV.
- PR target: <https://github.com/toolleeo/awesome-cli-apps-in-a-csv>
- PR: <https://github.com/toolleeo/awesome-cli-apps-in-a-csv/pull/267>

Awesome OpenAI Codex:

- Status: PR opened on 2026-05-18.
- Why: Codex-specific list with a `Tools & Integrations` section and explicit
  contribution rules for direct Codex ecosystem tools.
- Resume path: temporary clone at `/tmp/awesome-openai-codex`, branch
  `pinzheng/add-codex-profiles`, commit `15322cb` adds `codex-profiles`.
- PR target: <https://github.com/vaderyang/awesome-openai-codex>
- PR: <https://github.com/vaderyang/awesome-openai-codex/pull/2>

Awesome Codex Plugins by darknorth-123:

- Status: PR opened on 2026-05-18.
- Why: Codex ecosystem list that explicitly accepts plugins, MCP servers,
  workflows, integrations, and developer tools for OpenAI Codex.
- Resume path: temporary clone at `/tmp/darknorth-awesome-codex-plugins`,
  branch `pinzheng/add-codex-profiles`, commit `4985656` adds
  `codex-profiles` to `Developer Tools`.
- PR target: <https://github.com/darknorth-123/Awesome-Codex-Plugins>
- PR: <https://github.com/darknorth-123/Awesome-Codex-Plugins/pull/2>

Awesome OpenAI Codex CLI by taahro:

- Status: PR opened on 2026-05-18.
- Why: Codex CLI resource list with a `New Features & Integrations` section.
- Resume path: temporary clone at `/tmp/taahro-awesome-openai-codex-cli`,
  branch `pinzheng/add-codex-profiles`, commit `c919693` adds
  `codex-profiles`.
- PR target: <https://github.com/taahro/awesome-openai-codex-cli>
- PR: <https://github.com/taahro/awesome-openai-codex-cli/pull/3>

Awesome Agentic Coding by tranhoangpich:

- Status: PR opened on 2026-05-18.
- Why: open-source agentic-coding list already containing Codex and adjacent
  account/session workflow tools.
- Resume path: temporary clone at `/tmp/awesome-agentic-coding-tranhoangpich`,
  branch `pinzheng/add-codex-profiles`, commit `8838169` adds
  `codex-profiles`.
- PR target: <https://github.com/tranhoangpich/awesome-agentic-coding>
- PR: <https://github.com/tranhoangpich/awesome-agentic-coding/pull/3>

Awesome AI Coding Agent Tools:

- Status: PR opened on 2026-05-18.
- Why: AI coding-agent ecosystem catalogue; `codex-profiles` fits as focused
  Codex CLI/Desktop tooling around profile and account isolation.
- Resume path: temporary clone at `/tmp/awesome-ai-coding-agent-tools`, branch
  `pinzheng/add-codex-profiles`, commit `c031ecd` adds a `Codex CLI &
  Desktop Tooling` subsection.
- Validation: ran `npx --yes markdownlint-cli README.md`.
- PR target: <https://github.com/namphuongtran/awesome-ai-coding-agent-tools>
- PR: <https://github.com/namphuongtran/awesome-ai-coding-agent-tools/pull/4>

Awesome CLI Coding Agents:

- Status: PR opened on 2026-05-18.
- Why: terminal-native coding-agent list with an `Agent infrastructure` section
  for tools that extend or support CLI coding agents.
- Resume path: temporary clone at `/tmp/awesome-cli-coding-agents`, branch
  `pinzheng/add-codex-profiles`, commit `7c2b638` adds `codex-profiles`.
- PR target: <https://github.com/bradAGI/awesome-cli-coding-agents>
- PR: <https://github.com/bradAGI/awesome-cli-coding-agents/pull/90>

Awesome AI Dev Tools:

- Status: PR opened on 2026-05-18.
- Why: broad AI developer-tools list that already includes OpenAI Codex and
  Codex CLI; `codex-profiles` is a Codex workflow utility rather than a
  generic promo entry.
- Resume path: temporary clone at `/tmp/pierrunoyt-awesome-ai-dev-tools`,
  branch `pinzheng/add-codex-profiles`, commit `135b228` adds
  `codex-profiles`.
- PR target: <https://github.com/PierrunoYT/awesome-ai-dev-tools>
- PR: <https://github.com/PierrunoYT/awesome-ai-dev-tools/pull/26>

Awesome AI Coding Assistants Playbook:

- Status: PR opened on 2026-05-18.
- Why: assistant configuration/resource playbook; `codex-profiles` manages
  Codex CLI/Desktop configuration boundaries through isolated `CODEX_HOME`
  profiles.
- Resume path: temporary clone at
  `/tmp/codandotv-awesome-ai-coding-assistants-playbook`, branch
  `pinzheng/add-codex-profiles`, commit `d3ab9f3` adds English and Portuguese
  entries.
- Validation: ran `git diff --check`; default `markdownlint-cli` reports
  pre-existing repository-wide README issues unrelated to this entry.
- PR target: <https://github.com/CodandoTV/awesome-ai-coding-assistants-playbook>
- PR: <https://github.com/CodandoTV/awesome-ai-coding-assistants-playbook/pull/8>

Awesome AI Coding by dalisoft:

- Status: PR opened on 2026-05-18.
- Why: AI coding catalogue that already lists Codex; `codex-profiles` fits the
  `Resources` section as a companion utility, not the AI-agent CLI table.
- Resume path: temporary clone at `/tmp/dalisoft-awesome-ai-coding`, branch
  `pinzheng/add-codex-profiles`, commit `4b194bd` adds `codex-profiles`.
- PR target: <https://github.com/dalisoft/awesome-ai-coding>
- PR: <https://github.com/dalisoft/awesome-ai-coding/pull/64>

Awesome AI Coding by wsxiaoys:

- Status: PR opened on 2026-05-18.
- Why: high-reach AI-coding list whose `Projects` section includes open-source
  AI coding CLIs, editor tools, and workflow utilities.
- Resume path: temporary clone at `/tmp/wsxiaoys-awesome-ai-coding`, branch
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
