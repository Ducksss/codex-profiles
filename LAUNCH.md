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
- Repo topics include `ai-tools`, `automation`, `bash`, `chatgpt`, `cli`,
  `codex`, `codex-cli`, `codex-desktop`, `codex-home`, `codex-profiles`,
  `developer-tools`, `linux`, `macos`, `openai`, `openai-codex`,
  `productivity`, `shell-script`, and `vibe-coding`.
- Install paths:

```sh
npm install -g github:Ducksss/codex-profiles
```

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

Npm registry launch:

```sh
npm publish --access public
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
npm install -g github:Ducksss/codex-profiles
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

npm install -g github:Ducksss/codex-profiles
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

npm install -g github:Ducksss/codex-profiles
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
