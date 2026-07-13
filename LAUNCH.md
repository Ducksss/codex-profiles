# Launch Playbook

Use this when sharing `codex-profiles` with developer communities. The goal is
developer credibility first: clear problem, quick install, concrete demo, and
public feedback loops.

## Where Tracking Lives

Outreach tracking moved to Airtable. This file holds only positioning, channel
copy, launch order, and policy — the parts that rarely change and are not
per-target state.

- Live tracker: Airtable base `appcezSUhDxz7uaQW` — `Targets` (one row per
  platform), `Log` (append-only event history), and `Claims`
  (append-preserving workflow leases).
- Read and write it through `scripts/outreach-tracker.mjs` (see `agent.md`), not
  by editing this file. Do not re-add tracking tables here: concurrent runs would
  race on them, which is exactly why tracking moved out.
- Pre-Airtable history:
  [`archive/launch-ledger-history.md`](archive/launch-ledger-history.md) and this
  file's git history.
- Current outreach posture: broad near-identical awesome-list PRs are paused.
  Prefer issue-first unless the target is Codex-specific, explicitly requests
  Codex CLI or ChatGPT Desktop workflow tooling, or has a structured registry
  or package format. See Policy Gates below.
- Product-copy freeze: do not resume promotion until v0.7.0 is published and
  the signed ChatGPT app test matrix passes. Existing listings that describe
  Codex app clones or Codex-only Desktop switching need correction after the
  release; preserve their historical submission records.

### 2026-07-13–14 GitHub Wave

- Published three owned Q&A guides:
  [separate CLI profiles](https://github.com/Ducksss/codex-profiles/discussions/28),
  [named macOS ChatGPT windows](https://github.com/Ducksss/codex-profiles/discussions/29),
  and [the isolation boundary](https://github.com/Ducksss/codex-profiles/discussions/30).
- Audited all 56 remaining P0/P1 GitHub issue routes. Airtable outcomes:
  10 draft PRs, 1 verified listing, 1 qualified route queued after the cap,
  6 issue-first monitor routes, 10 deferred routes, and 28 permanent non-ICP
  routes. Qualification totals were 4 high-confidence and 7 medium-confidence
  routes; 4 high and 6 medium were submitted.
- High-confidence draft PRs:
  [awesome-dev-tools #12](https://github.com/dinakars777/awesome-dev-tools/pull/12),
  [CodexGuide #26](https://github.com/freestylefly/CodexGuide/pull/26),
  [awesome-agentic-engineering #5](https://github.com/ashishkaloge/awesome-agentic-engineering/pull/5),
  and [awesome-llm-cli-apps #6](https://github.com/jsnyder/awesome-llm-cli-apps/pull/6).
- Medium-confidence draft PRs:
  [collective-ai-tools #259](https://github.com/Hyraze/collective-ai-tools/pull/259),
  [Awesome-independent-tools #82](https://github.com/yaolifeng0629/Awesome-independent-tools/pull/82),
  [dev-resource-hub #29](https://github.com/saikirantechy/dev-resource-hub/pull/29),
  [awesome-devtools #2](https://github.com/Alvaro1904200/awesome-devtools/pull/2),
  [ai-agent-stack #2](https://github.com/SelahattinSert/ai-agent-stack/pull/2),
  and [awesome-ChatGPT-repositories #181](https://github.com/taishi-i/awesome-ChatGPT-repositories/pull/181).
- The medium-confidence
  [athivvat/awesome-devtools route](https://github.com/athivvat/awesome-devtools/pull/41)
  was revalidated and converted from the queued issue into a one-line draft PR
  on 2026-07-14. The original issue was not bumped.
- Follow-up on 2026-07-14 verified that
  [awesome-ChatGPT-repositories #181](https://github.com/taishi-i/awesome-ChatGPT-repositories/pull/181)
  was owner-approved, merged, and is live under CLIs. Current external
  outreach state is now 11 open draft PRs, 1 merged listing from this wave,
  and 6 issue-first monitor routes. The other 9 original open drafts and all
  6 issues had no human replies.
- Continued discovery on 2026-07-14 found 24 third-party repositories with an
  exact codex-profiles link. Fifteen already matched Airtable, 7 missing hits
  were generated mirrors, copied skills, or one-off reports rather than leads,
  and 2 were real organic listings. Airtable now tracks
  [awesome-ai-rabbit-holes](https://github.com/gabrielmoreira/awesome-ai-rabbit-holes/blob/main/docs/rabbit-holes/ai-dev-extensions.md#L443)
  with no outreach and
  [Awesome-Agents-](https://github.com/voxxov222/Awesome-Agents-/pull/1)
  with a draft correction for outdated pre-v0.7 Desktop wording.
- The exact-link reconciliation also corrected the stale
  [awesome-ai-agent-tools](https://github.com/michielhdoteth/awesome-ai-agent-tools/blob/main/tools/catalog.json#L414-L421)
  Airtable row from `PR Open` to `Listed`: the owner closed PR #8 only after
  manually integrating it in commit `687776c` around catalog-refresh conflicts.
- The owned
  [GitHub guide PR #31](https://github.com/Ducksss/codex-profiles/pull/31)
  remains an open draft with all three CI jobs passing and no review yet.
- Verified
  [awesome-agent-clients](https://github.com/1shiharat/awesome-agent-clients#related-agents-frameworks--protocols)
  lists codex-profiles under adjacent tooling.
- Principal blockers: agent/client/MCP/plugin/skill/subagent scope mismatch;
  100-star and one-year age gates; stale or ambiguous companion-tool scope;
  unsupported scoring metadata; and a contribution policy that rejects
  AI-generated PRs. No new issues or reminder comments were posted.
- Airtable received 56 reviewed-target events plus 3 owned-discussion events.
  Readback verified all target fields and log links without mismatches.
- The 2026-07-14 follow-up updated 17 target rows and appended 17 linked log
  events. Readback found zero mismatches across status, last checked, next
  action, notes, links, and log relationships.
- Continued discovery created 2 deduplicated Airtable targets and 3 linked log
  events for the organic listings and copy-correction PR; readback verified
  both records and all 3 events.
- The stale awesome-ai-agent-tools row received one verified status update and
  one linked monitoring event while preserving its original issue and PR URLs.
- Wave-start traffic baseline: 51 stars, 7 forks, 1 watcher, 412 views with
  217 unique viewers, and 582 clones with 216 unique cloners over the
  available 14-day window.

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
remains a maintainer action. Before creating the tag, the live job preflights
the npm owner identity and reported GitHub account access, then rechecks main
and remote tag state. Those read-only probes do not prove granular token write
scope: the npm token must allow `codex-profile` publication, and the dedicated
tap token should select only `Ducksss/homebrew-tap` with Contents read/write.
The actual publish and push remain the authoritative write checks.

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

## Policy Gates

Apply these before any outreach action; record the specific target status in the
Airtable tracker, not here.

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
