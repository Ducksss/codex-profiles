# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project follows semantic versioning for tagged releases.

## Unreleased

### Added

- Gave each macOS menu profile a colour and symbol. New profiles get a
  stable colour from their name, with `default` in graphite, and show their
  initial; **Appearance…** in a profile's actions chooses one of eight
  colours and twelve symbols, applied at once. The palette leaves out red,
  orange and yellow, which mean low quota.
- Added `codex-profile appearance` so a profile's colour and symbol live with
  the CLI and every tool shows the same ones: the menu-bar app reads and
  writes them there, `shell-init --prompt` puts a dot in the profile's colour
  before `[codex:<profile>]` (omitted with `NO_COLOR`), `env` exports
  `CODEX_PROFILE_COLOR`, Raycast's Open Profile tints each profile's icon,
  and `launcher create` defaults to the profile's colour. Launcher colours
  gain `indigo` and `brown`. Choices are stored privately in `appearance.tsv`
  and forgotten by `remove`.
- Added **Quota in menu bar**, an opt-in gear-menu toggle that shows the
  lowest remaining Codex quota beside the menu-bar icon and keeps usage
  current with the same five-minute background read as alerts.
- A low profile row in the macOS menu now names a healthier profile, such as
  `5h limit low · personal has 70%`, using the same fresh-reading rule as
  low-quota notifications. It only suggests and never switches profiles.
- Added an opt-in **Keyboard shortcut ⌃⌥⌘P** in the gear menu that opens the
  menu from any app. It needs no Accessibility permission, stays off by
  default, follows the keyboard layout's P, and is refused with a message
  when another app holds the keys.

### Changed

- Redesigned the project website as a dark ASCII page drawn live with WebGL:
  an orbiting planet with one moon per profile, live phase moons for each
  Codex home, an install trajectory and a dawn horizon, all reacting to the
  cursor. The menu bar section switches between the app's screenshot and real
  `codex-profile usage` and `workspace list` output. Static ASCII art replaces
  the scenes without WebGL or JavaScript, and the FAQ, project facts and safety
  boundaries stay in the HTML.
- Redrew the link preview image to match: the site's ASCII planet and its
  default, personal and work moons, drawn by the page's own WebGL engine, with
  the headline and the three Codex homes.
- Answered the questions people search for on the website and in `llms.txt`:
  using multiple Codex accounts, how a profile differs from Codex's own
  `--profile` option, checking usage limits per profile, and why nothing
  switches accounts automatically. The page description and structured data
  now state that each profile has its own sign-in and nothing copies
  `auth.json`.
- Redesigned the macOS menu around profiles. Each profile now leads a group
  with its workspaces nested beneath it, replacing the profile filter, and a
  search selects its first match so Return's target is visible. Clicking a
  row opens it; ⌘Return and ⌘-click open the other destination, and the gear
  menu's **Return opens in** replaces the ChatGPT/Terminal control. Rows drop
  their Open buttons and reveal actions on hover, selection or right-click.
  Each profile shows its tightest Codex window as a figure and ring, in a
  darker orange or red when low so the number keeps its contrast, and the
  profile's actions list every window with its reset time. The popover is
  360 points wide, and previews render at 2x.
- Improved search and AI discovery with consistent app/CLI metadata, a real
  maintainer identity, linked setup and security sources, release-feed
  discovery, and editorial dates distinct from software release dates.
  CONTRIBUTING.md now covers the site checks, the GitHub Pages host-root
  robots.txt and the search console handoff.
- Allowed raw Markdown source links through release validation while retaining
  exact release-tag requirements for executable installer references,
  including percent-encoded installer paths.
- Made the macOS menu-bar app the README's main entry point, with native
  previews, source installation and menu workflows before the CLI reference.
  Followed Best-README-Template's project, setup and contributor structure.
- Refined the app introduction with its native icon, a shorter first-run guide
  and expandable CLI details, keeping the menu-bar workflow in focus.
- Pointed readers who would rather not build the app to the one-command
  Homebrew or npm CLI install from Getting started, and removed a stale note
  that the `v1.3.0` release tag was unpublished.
- Refined the macOS menu's typography and rhythm. One type scale lets weight
  carry the hierarchy, every row is 48 points high, profiles get monogram
  marks and workspaces folder tiles, and the quota column sets a quieter
  percent sign. Hover and keyboard selection use an inset rounded plate, rules
  start at the title column and step aside beside it, and space rather than
  rules separates groups.
- The npm package no longer ships the unused `docs/welcome.svg`.

### Fixed

- `launcher remove` now clears a launcher record it cannot read, such as one
  created under a different `CODEX_PROFILE_LAUNCHER_ROOT`, so `remove` is no
  longer blocked by it. Only the record is cleared; the app it named is left
  in place and its path is printed.
- Launchers keep working after `codex-profile` moves, for example after a Node
  version switch: when the recorded copy is gone they look in `~/.local/bin`,
  `/opt/homebrew/bin`, `/usr/local/bin` and the login shell's `PATH`. Existing
  launchers pick this up when recreated with `launcher create --force`.
- `usage` no longer counts a reply that arrives in pieces twice towards its
  1 MiB limit, which could reject a valid reply of around half that size.
- The macOS menu reads quota from the same replies as the CLI: a reply with
  only the Codex limit bucket, a window without a numeric `usedPercent`, or an
  `"error": null` field no longer shows the profile as unavailable.
- The Raycast extension no longer starts one `codex-profile path` process per
  profile, and reuses its last reading's profile count instead of running
  `list` before each quota read.
- `status --json` stays valid JSON when a profile's status fails or the Codex
  CLI is missing, and rejects invalid profile names instead of reporting them.
  Plain `status` reports a missing Codex CLI once instead of running an empty
  command for every profile.
- `launcher create` no longer reports success when a build step fails, for
  example from a copy that is not executable. Its default name now fits profile
  names that end in `.`, `-` or `_` or are very long; `--force` can change only
  the letter case of a name on a case-insensitive volume; and an interrupt no
  longer leaves a half-built bundle in `~/Applications`.
- `remove` refuses a differently cased spelling of a profile on a
  case-insensitive volume, which skipped its shared-configuration and
  workspace-binding checks.
- An exported `CDPATH` no longer breaks relative workspace paths. `workspace
  unbind` resolves a deleted folder through its surviving parent, as `bind`
  recorded it (for example `/tmp` or a symlinked projects folder). `app` never
  passes a workspace starting with `-` to `open` as an option, and
  `app-instance` or `app --instance` without a profile opens the picker as
  documented.
- `doctor --json` reports unreadable workspace state instead of exiting with
  no output.
- Two commands reclaiming the same stale state lock can no longer both
  proceed, and a lock with no recorded owner explains how to recover.
- `env` and `use` refuse a symlinked profile home, as every other command does.
- The Bash and Zsh `--prompt` indicator removes stale `[codex:…]` prefixes
  that tools such as Python venv restore with their saved prompt.
- `upgrade --prefix` resolves a relative prefix from the current directory
  instead of the upgrade cache, and `upgrade --ref` refuses a name that is not
  a commit instead of restoring a path with that name.
- Zsh completions saved as `_codex-profile` complete on every Tab instead of
  every other one, and `doctor` completion offers `-j`. Help lists the
  update-check environment variables.
- Menu-bar low-quota alerts no longer take a reading that is still refreshing
  as the baseline when another profile's reading arrives first, which could
  notify as soon as alerts were turned on.
- Raycast: a usage timeout is reported as a timeout, Open Workspace clears a
  profile filter whose last binding was removed, and copied commands use the
  `codex-profile` the extension found, including the menu-bar app's copy.
- Release automation: the AUR clean build now fails on namcap errors, and the
  Pages check reads the whole site before searching it. The outreach tracker
  accepts plain HTTP only for exactly `127.0.0.1`, and `list --owned false`
  lists unowned targets.

### Security

- Terminal launches from the menu-bar app and Raycast quote profile names and
  folder paths so fish reads them literally. AppleScript's `quoted form of` is
  POSIX-only, so under fish a folder name containing a backslash and a quote
  could run the rest of the name as commands.
- `clone-config` also refuses files with names such as `BRAVE_KEY` or
  `GITHUB_PAT`, `key` or `dsn` entries, credentials in URLs and common token
  prefixes, and its message and documentation now say it matches text anywhere
  in the file.
- `scripts/release/set-npm-token.sh` hands the token to npm on standard input
  instead of `env`'s argument list, where `ps` and exec audit logs could see it.

### Documented

- The network model now includes the GitHub Releases request that `upgrade`
  and `upgrade --dry-run` make, and the update check is described by whether
  output is a terminal. Corrected the `setup` defaults, plain `doctor` exit
  status, `list` output, launcher target and `usage` exit status, added
  maintenance commands to `llms.txt`, named the `USAGE.md` command reference in
  the sync rules, and noted that `main` must not move during a release.

### Tests

- Native tests tag their throwaway defaults suites and remove them afterwards,
  instead of leaving an empty plist in `~/Library/Preferences` on every run.

## 1.3.0 - 2026-10-12

### Added

- Native macOS menu-bar companion with a compact AppKit popover, system
  search and controls, profile filtering, persistent pins, keyboard launches,
  and explicit Open actions for named ChatGPT windows or Codex in Terminal.
  Rows stay unselected until keyboard navigation and use denser spacing with
  a clearer project, profile and folder hierarchy. Build it from a source
  checkout with `make menu-app`; this release has no signed app download.
- Profile creation, folder binding, optional CLI sign-in, and workspace
  actions to reveal, copy, reassign, relocate or remove a binding. Refreshes
  preserve loaded content and committed binding changes; missing folders and
  profiles show a repairable state. Profile operations delegate to the existing CLI.
  A row whose binding is changing shows progress and cannot launch until the
  CLI reports the outcome. Unavailable actions stay disabled in row menus.
- Row actions open a profile or workspace in the other destination without
  changing the default, and add a workspace directly from a profile.
- Open at Login in the gear menu. Login launches stay in the menu bar; opening
  the app again from Finder or Spotlight shows the menu.
- Profile-first setup and direct profile launches without choosing a project
  folder. Workspace bindings remain optional shortcuts; profile launches start
  in the home directory instead of inheriting the menu app's launch directory.
- System appearance and accent updates, Reduce Motion support, opaque selection
  for increased contrast or reduced transparency, and keyboard selection cues
  exposed to accessibility clients without relying on colour alone.
- Remaining Codex CLI quota beside each profile, with reported window
  durations, compact meters, reset countdowns and accessible descriptions.
  Low windows are emphasised and named with their reset time in the row.
  Usage reads delegate to the official app-server without reading
  credentials or sending inference requests. Cached background reads have
  bounded concurrency, deadlines and process cleanup; refreshes keep the
  previous reading visible and update rows in place; missing usage leaves
  launches available.
- `usage [--json] [profile...]` shows remaining Codex CLI quota for named or
  all initialized profiles on macOS and Linux: each reported window's duration,
  percentage left, low and critical marks, and reset time. Reads use the
  official Codex app-server, like the menu-bar companion, without reading
  credentials or sending inference requests; up to four run at once with a
  per-profile `CODEX_PROFILE_USAGE_TIMEOUT` (default 10 seconds). Signed-out
  and expired profiles name the `login` command to run, API-key profiles are
  reported as needing a ChatGPT sign-in, JSON states mirror `status --json`,
  and named profiles that cannot be read return nonzero. The command never
  switches profiles.
- Low-quota alerts in the macOS menu-bar companion. The menu-bar icon adds a
  badge when an initialized profile's Codex quota window is at 25% or less,
  with an exclamation mark at 10% or less; it stays a monochrome template
  image, and its tooltip and VoiceOver label name each profile, window and
  reset time. An opt-in **Low-quota alerts** toggle in the gear menu is off by
  default and asks for notification permission only when turned on; a denial
  explains how to allow notifications in System Settings. Notifications fire
  when a profile crosses into low or critical, at most once per level per
  reset period and never for quota already low at launch, name the reset
  time, and mention another profile with clearly more of the same window
  left. Clicking one opens the menu. While alerts are on, usage is checked
  about every five minutes through the existing bounded reader. The app never
  switches profiles or accounts automatically.
- Universal Apple silicon/Intel app and DMG builders with an Applications
  shortcut, SHA-256 checksum, and optional Developer ID signing and
  notarisation. A failed publication restores the previous image and checksum
  together. Local builds are unsigned development artifacts.
- Terminal launches explain how to allow Automation when macOS denies it.
- Raycast extension in `raycast/`, built from source for now
  (`cd raycast && npm install && npm run dev`). **Open Profile** opens a
  profile's ChatGPT window or its Codex CLI in Terminal and copies or reveals
  its `CODEX_HOME`; **Open Workspace** opens bound project folders with their
  profile; **Codex Usage** lists every quota window with Low, Critical and
  Limit reached tags, reset countdowns, and Codex CLI sign-in for profiles
  that are not signed in. Every operation delegates to the `codex-profile`
  CLI, found under Raycast's minimal `PATH` or inside the menu-bar app;
  background calls use argument lists, and Terminal launches quote values with
  AppleScript's `quoted form of`. The extension never reads auth data and
  never switches profiles by itself. The npm package does not include it.
- Native interaction, CLI integration, subprocess and packaging checks, plus
  light and dark layout previews with verified system backdrops. NSPopover
  supplies the live material without a duplicate visual-effect layer.

### Fixed

- Discover the Codex CLI in current ChatGPT Desktop bundle layouts as well
  as the legacy resource path. Finder-launched menu apps can read quota and
  start CLI actions without a separately installed CLI on PATH; diagnostics
  identify these engines as coming from the desktop bundle.

## 1.2.0 - 2026-09-15

### Added

- Initialized profile names and workspace guard mode in the terminal welcome
  context, alongside the current project, binding, and shell selection.
- Arrow-key profile selection with type-to-filter, Backspace editing, and
  Escape/Ctrl-C cancellation. Exact names and menu numbers remain supported,
  with the plain numbered picker retained for dumb or redirected terminals.
- Command-specific usage, options, and examples through `help <command>` and
  `<command> --help`/`-h`, including workspace and launcher subcommands.
  Upstream Codex arguments after a profile or `run --` remain unchanged.
- `list --details` profile overview cards showing Codex homes, bound projects,
  and managed launcher availability without probing login or reading
  authentication data.

### Fixed

- Preserve Ctrl-C cancellation status 130 through interactive CLI, Desktop,
  and unbound project launches, waiting for terminal restoration before
  returning. Escape, Ctrl-D, and q still return status 1.
- Release verification tolerates npm scanning and availability delays with
  separate 20-minute wait budgets for metadata and public installation,
  retrying every 30 seconds while preserving exact SHA-512 artifact integrity
  and installed command checks through both aliases.

## 1.1.0 - 2026-09-14

### Added

- A dedicated 10-second Remotion README loop linked to the full launch video,
  with a seamless repeat and the CLI welcome screen in an expandable section.
- Optional terminal integration during `setup`, with an exact snippet preview
  before appending shell startup configuration for profile prompts,
  completions, terminal titles, and completion notifications. Repeated setup
  appends only missing integration lines and never executes startup files.
- `shell-init --completions` for Bash, Zsh, and Fish, usable alone or with
  `--prompt` to load both features in the current shell.
- Terminal welcome context showing the project binding, current shell profile,
  and relevant launch commands without checking login state.
- Interactive recovery for unbound `run` and `run --app`: choose a profile,
  optionally save the binding, and launch it. Noninteractive failures remain
  unchanged.

### Changed

- Profile pickers accept exact names and menu numbers (`#N` disambiguates
  numeric names), distinguish project and
  shell selections, and use the shell profile as the default when no workspace
  is bound. Cancellation no longer displays an error; it retains exit status 1.
- Shell completion suggests initialized profiles for launch commands and
  completes supported options in their relevant argument positions.

## 1.0.0 - 2026-09-13

### Added

- Opt-in CLI terminal titles (`CODEX_PROFILE_TERMINAL_TITLE=1`) showing the
  profile and launch directory, plus terminal completion notifications
  (`CODEX_PROFILE_NOTIFY=1`) for `exec`/`e` through `cli` and `run`. Notifications
  preserve the command exit status; both features keep redirected streams free
  of feedback and default to off.

### Changed

- Reorganized the README around guided setup, everyday CLI and Desktop
  workflows, and a captured terminal welcome screen. Preserved the detailed
  reference in `USAGE.md`, included with npm installations.

## 0.11.1 - 2026-09-12

### Changed

- Replaced the no-argument help dump with a compact welcome screen, a new
  terminal wordmark, and quick-start commands. Full help groups commands by
  task and formats environment overrides on readable rows, with wrapping for
  narrow terminals, monochrome support via `NO_COLOR`, and plain piped output.

## 0.11.0 - 2026-09-09

### Added

- Added terminal profile pickers for no-argument `cli` and `app` launches,
  marking the nearest workspace binding and accepting Enter for that profile.
- Added `detach <profile>` to replace allowlisted shared configuration links
  with independent copies without changing ordinary files or private state.
- Added opt-in `shell-init <bash|zsh|fish> --prompt` to show the active managed
  profile in the existing shell prompt without editing startup files.
- Added terminal-only `setup <profile>` for initialization, optional CLI login,
  workspace binding, and macOS launcher creation using the existing commands.

### Changed

- Added an explicit maintainer waiver for unavailable real Desktop smoke checks,
  recorded as unverified in workflow summaries and public release notes while
  retaining all automated release checks.

- Removed obsolete pre-v0.7 media, completed implementation plans, the frozen
  launch-ledger archive, the unused design brief, and self-referential GEO
  process documents. The project page no longer presents legacy Codex Desktop
  imagery as proof of current ChatGPT behavior.
- Reworded visible homepage isolation terminology as separate local state so
  the project page matches the documented security boundary.
- Repaired outreach skill references after the launch playbook move and removed
  the unavailable platform-outreach dependency and stale media guidance.
- Replaced the root outreach automation prompt with a user-facing agent setup
  guide that covers prerequisites, installation, verification, and profile
  creation. Moved the project-internal outreach prompt, launch playbook, and
  tracker runbook under `ops/outreach/`, and stopped shipping the full GitHub
  Pages source in the npm package.

## 0.10.0 - 2026-09-02

### Added

- Added a dependency-free Airtable-to-Neon migration utility, restricted Neon
  schema, public RS256 JWKS, Merge Queue commands, and integration coverage for
  transactional imports, RLS/grants, append-only history, and atomic claims.
- Added `doctor` diagnostics for symlinked profile homes and symlinked or
  hard-linked private state such as `auth.json`, `sessions/`, and
  `state_5.sqlite`, without flagging the documented `init --share-with`
  configuration allowlist.
- Added `doctor --check`, top-level JSON health, and an explicit version for
  workspace, guard, and launcher state so automation can distinguish
  diagnostics from a passing health check and reject incompatible state.

### Changed

- Moved the operational outreach source of truth from Airtable to a dedicated
  Neon Data API project while preserving legacy records, raw source snapshots,
  command output, exit codes, relationships, and the 30-day deletion gate.
- Removed unreferenced landing-page concept renders after the editorial design
  direction was captured in `DESIGN.md` and implemented in the site.
- Made source upgrades resolve the latest immutable final GitHub Release by
  default, kept `--ref main` as an explicit development path, and pinned the
  documented standalone and Nix install commands to the current release.
- Made `init` the sole profile-creation command. CLI, login, Desktop launch,
  and configuration-copy commands now require initialized profiles instead of
  silently creating a missing name.
- Made profile removal refuse to orphan managed launchers or profiles that
  still supply linked configuration to another profile.
- Restricted source-style self-upgrades to source-owned executables or an
  explicitly authorized install prefix; package-managed installations now
  direct users back to their package manager.
- Restricted release and Pages jobs to protected `main` environments. Pages
  now accepts only immutable release tags whose resolved commits belong to
  `main`, and treats them as artifact input instead of workflow code.
- Made the clean AUR verifier select `linux/amd64` explicitly and accommodate
  pacman under QEMU emulation on Apple Silicon.

### Fixed

- Cleared an inherited `CODEX_ELECTRON_USER_DATA_PATH` when launching
  `app default`, so it reliably preserves the stock ChatGPT Desktop session.
- Kept AUR checksums pinned to immutable tagged sources after unreleased CLI
  changes, and made package tests distinguish published tags from new release
  candidates.
- Honored configured retry backoff when Neon or Airtable omits `Retry-After`,
  rejected credential-bearing non-URL database strings, and stopped placing
  the Neon database password in `psql` process arguments.
- Refused symlinked Desktop log parent directories and symlinked, non-regular,
  or multiply-linked log files before launch or inspection, preventing log
  redirection from overwriting or reading another file.
- Serialized workspace, guard, launcher, initialization, configuration-copy,
  and removal mutations so overlapping processes cannot lose registry updates
  or make lifecycle decisions against stale state.
- Passed Neon database names through `psql --dbname`, rejected option-shaped
  names, and added complete leading indexes for every outreach foreign key.

### Security

- Enabled a concrete private vulnerability-reporting path and added release,
  Pages, local-log, database-argument, and deployment-trust regression checks.

## 0.9.1 - 2026-08-30

### Documented

- Explained that store-level session-store symlinks under a named `CODEX_HOME`
  fail current Codex Desktop path containment, so fork and side chats break. A
  shared `state_5.sqlite` also breaks archive and delete, which mention the
  `sessions` directory in the error. `init --share-with` does not create those
  links. Desktop account identity follows `CODEX_HOME/auth.json`, not Electron
  user-data alone; this tool still does not copy `auth.json`.

### Tests

- The npm package smoke test now gives `npm pack` the same throwaway cache the
  install step already used, so a broken or unwritable user npm cache no longer
  fails the test for reasons unrelated to the package.

## 0.9.0 - 2026-08-23

### Added

- Added managed macOS profile launchers with custom display names and a fixed
  eight-color icon palette. Launchers keep the installed signed ChatGPT bundle
  untouched, route to an initialized profile, and can be listed, inspected,
  replaced, or removed without deleting profile data.

### Changed

- Named ChatGPT launches now mirror their Electron data directory through
  `CODEX_ELECTRON_USER_DATA_PATH` as well as `--user-data-dir`. The integrated
  app treats that variable as the authoritative Electron user-data path, so the
  selected `CODEX_HOME` also survives the app's login-shell environment load.
  Repeat launches of one named profile now focus that profile's existing window
  instead of starting a second instance against the same Electron data.
- Launcher records survive a launcher deleted outside the CLI: `launcher list`
  skips a stale record on stderr instead of failing the whole listing and
  emitting truncated JSON, `launcher create` rebuilds the missing app, and
  `launcher remove` clears the leftover record.
- Release dry runs now preflight the npm and Homebrew tap credentials, so a
  missing or unauthorized publish secret fails before a live run reaches the
  tag and publish steps. The secrets stay scoped to that step rather than the
  whole verification job.
- Added a `skip_homebrew` release input that publishes npm, the GitHub Release,
  and Pages without touching the Homebrew tap. A skipped release neither
  requires nor consults tap credentials, and both run summaries state that the
  tap keeps its current version.

## 0.8.0 - 2026-07-15

### Added

- Added `init <profile> --share-with <source-profile>` for linked profiles that
  share only an explicit configuration allowlist while keeping authentication,
  sessions, logs, Desktop data, caches, and connector/app state separate.
- Added private workspace-to-profile bindings with nearest-ancestor resolution,
  `run`/`run --app` automatic routing, warn/strict/off mismatch guards,
  machine-readable inspection, profile-removal cleanup, doctor diagnostics,
  and Bash/Zsh/Fish completion support. Bindings contain only canonical paths
  and profile names; they never inspect or move authentication or cookies.

### Changed

- Consolidated repository verification behind `scripts/check` and `make check`,
  organized tests by product and operational responsibility, moved release
  behavior into directly tested channel scripts, and replaced executable AUR
  Markdown with non-pushing preparation and read-only verification commands.
- Added practical GitHub Q&A guides for separate Codex CLI profiles, named
  ChatGPT Desktop windows, and the local-state isolation boundary.
- Hardened release publication with bounded network requests, destination-
  pinned npm and GitHub operations, secret-safe Homebrew authentication,
  portable SHA-256 calculation, exact remote-tag postconditions, explicit
  unset-input handling, and byte-for-byte public AUR verification against
  immutable prepared package files.
- Made canonical repository checks fail closed on inventory-discovery errors,
  and reject option-like archive members before AUR extraction.

## 0.7.0 - 2026-07-13

### Added

- Repo-local GitHub pipeline skill set for lead generation, lead
  qualification, closing drafts, and monitoring, with Airtable handoffs and
  approval-gated external actions enforced by tests.
- Repo-local `github-lead-gen` skill for GitHub candidate discovery, with
  Airtable-only intake boundaries and search-lane references.
- Airtable-first GitHub lead workflow instructions for the outreach agent,
  including repository-first qualification, ICP/truthfulness gates,
  approval-gated external actions, pipeline views, and a regression test that
  keeps `agent.md` aligned with the workflow.
- Additional install channels: a `curl | sh` installer (`install.sh`, fetches
  the latest release into `~/.local/bin`), a Nix flake
  (`nix run github:Ducksss/codex-profiles`), and an AUR `PKGBUILD` under
  `packaging/aur/`. The installer and flake track the current version
  automatically (the flake reads `package.json`), so they add no release drift;
  `install.sh` is covered by ShellCheck in CI.
- A permanent [AUR publication and update runbook](packaging/aur/README.md)
  covering dedicated credentials, immutable tagged inputs, clean non-root Arch
  builds, metadata and alias validation, first publication, subsequent updates,
  and public post-push verification.

### Changed

- Adapted Desktop launching to OpenAI's integrated ChatGPT app. `app default`
  launches the original signed application with `CODEX_HOME=~/.codex` and no
  custom Electron user-data directory, preserving the stock ChatGPT session.
- Named `app <profile>` launches now use both `~/.codex-<profile>` and matching
  `electron-user-data` for the entire ChatGPT window across Chat, Work, and
  Codex. Different names can coexist; reopening one name reuses its context.
- Desktop discovery now prefers `CHATGPT_APP`, accepts legacy `CODEX_APP`, and
  detects `/Applications/ChatGPT.app` before legacy `Codex.app`.
- CLI resolution now validates candidates: an explicit `CODEX_CLI` must be
  healthy; otherwise the wrapper can fall back from `PATH` to an explicit
  bundled candidate or the CLI inside the detected Desktop app.
- Documentation, security guidance, support templates, GEO structured data,
  launch copy, and AI-readable facts now distinguish Codex-only commands from
  whole-window ChatGPT Desktop profiles.
- Version metadata is aligned on `0.7.0` without changing the project,
  repository, npm package, commands, or profile-directory names.
- Source, standalone, npm, Nix, AUR, and Homebrew release paths now preserve
  both `codex-profile` and `codex-profiles` command spellings. CI validates the
  aliases and synchronized package metadata on Linux and macOS.
- Releases are now explicit, version-validated workflow dispatches from
  `main`; the workflow verifies the dated changelog, publishes idempotently,
  updates Homebrew, and deploys Pages from the immutable release tag.
- The npm tarball excludes historical pre-v0.7 screenshot and video assets;
  those files remain in the repository for release-history context.
- Clarified current product copy, CLI diagnostics, and package metadata to
  describe local-state separation without implying a verified account or
  security boundary.
- Expanded the default release dry run to rehearse the standalone installer,
  npm package, Homebrew helper, and pinned AUR package paths. Live releases now
  require a strict, sanitized signed-app version/bundle attestation,
  preflight the npm owner identity and reported GitHub account access, recheck
  main and tag state immediately before tagging, and verify the published npm
  aliases with bounded registry retries, the exact immutable GitHub Release as
  latest with non-empty notes, the public standalone installer's latest-release
  path in a fresh prefix, and a newly dispatched Pages run and version; external
  AUR publication remains a maintainer action.
- Split default release verification into a credentialless, read-only job and
  live publication into a separately gated write job that revalidates
  `origin/main` and remote tag state. Registry, tag, and GitHub Release lookups
  now fail closed while safely accepting only exact-version concurrent results.
- Made the standalone installer validate exact release tags and payload
  versions, then replace both installed command aliases transactionally with
  rollback if any late install or verification step fails.

### Removed

- Removed Desktop app copying, bundle metadata patching, ad-hoc signing,
  canonical-app quitting, and broad process-kill behavior. The installed signed
  application is never modified or replaced.
- Removed stale clone-based screenshot and video references from primary
  documentation. Historical release and outreach records remain intact.

### Deprecated

- `app --instance`, `app --rebuild`, and `app-instance` remain accepted
  compatibility spellings but use the ordinary named launcher. Named launches
  are already parallel-capable, and `--rebuild` is now a no-op because no app
  clone exists.
- `CODEX_APP_BIN` remains a compatibility override only for an executable
  inside an application bundle. Prefer the `CHATGPT_APP` bundle override.

### Fixed

- Corrected the AI-readable profile graph so `personal` maps to
  `~/.codex-personal` rather than `~/.codex`; `default` remains the only name
  mapped to `~/.codex`.
- Clarified that `status` describes Codex-local authentication and that the
  tool does not inspect or verify equality between CLI and Desktop accounts.
- Normalized current logged-out CLI messages, prevented update notices from
  polluting `status --json` and `doctor --json`, and expanded doctor output
  with detected app metadata, CLI source/health, and explicit scope fields.
- Rejected symlinked managed profile and Electron user-data directories before
  creating files or changing permissions.
- Made source installs refuse command-directory and canonical-symlink
  destinations, verify both installed aliases, and smoke-test updates without
  masking producer failures.
- Restored deprecated `app-instance` discovery in all shell completions,
  registered completions for both executable aliases, and rejected legacy
  `CODEX_APP_BIN` values that do not name the bundle's declared executable.

### Security

- Replaced overbroad isolation claims with an explicit local-state model.
  Named Electron data is not an operating-system sandbox or a server-side
  ChatGPT workspace boundary; keychains, external credentials, filesystem
  access, and OpenAI-managed state remain shared or outside the tool's control.
- Desktop launch now refuses an inherited `CODEX_ACCESS_TOKEN` so a shell
  access token cannot silently override the selected window's authentication
  context.

## 0.6.0 - 2026-07-01

### Changed

- Parallel Codex Desktop launch is now an opt-in flag on the primary command:
  `codex-profile app <profile> --instance` (with `--rebuild` still available,
  only valid together with `--instance`). Plain `codex-profile app` remains the
  cheap, notarized single-app switcher and stays the default. This collapses the
  two co-equal launch commands into one verb with an advanced flag, matching how
  GUI apps (Firefox `-no-remote`, Chrome/VS Code `--user-data-dir`) expose
  parallel-instance launching, and keeps the `--instance` naming consistent with
  the existing `logs <profile> --instance` and `CODEX_PROFILE_APP_INSTANCE_ROOT`.
- Help, examples, and shell completions now lead with `app` and present
  `--instance`/`--rebuild` as its flags; `app-instance` is no longer advertised.

### Deprecated

- `codex-profile app-instance <profile>` is now a deprecated, undocumented alias
  for `codex-profile app <profile> --instance`. Existing scripts and muscle
  memory keep working; prefer the flag form going forward.

## 0.5.0 - 2026-07-01

### Changed

- The release workflow now updates the Homebrew tap (`Ducksss/homebrew-tap`)
  after publishing, so `brew` installs track the latest version. Requires a
  `TAP_TOKEN` repo secret with write access to the tap; the step is skipped
  when the secret is absent.
- Release workflow runs on `actions/setup-node@v6` / Node 22, clearing the
  Node 20 runtime deprecation warning.

## 0.4.2 - 2026-07-01

### Fixed

- The fish `use` wrapper emitted by `shell-init fish` piped `env ... | source`,
  so it returned `source`'s exit status (always 0) and swallowed `env`'s
  failure — `use <invalid>` or `use` with no argument reported success in fish
  while bash/zsh correctly returned non-zero. It now captures `env`'s output and
  propagates the failure status, restoring cross-shell parity.

## 0.4.1 - 2026-07-01

### Added

- In-shell activation. `env <profile>` prints shell code (`export CODEX_HOME=...`,
  or `set -gx ...` with `--shell fish`) to evaluate so the current shell is pinned
  to a profile without prefixing every command; it also exports an informational
  `CODEX_PROFILE_NAME` marker (never read by the tool) for prompts. `shell-init
  <bash|zsh|fish>` prints a shell wrapper that enables the shorter `use <profile>`
  verb; run without the wrapper, `use` prints setup guidance instead of failing.
  Both stay within the existing boundary — the tool only ever sets `CODEX_HOME`.
  Uninitialized profiles warn on stderr so evaluated stdout stays clean. Completion
  generators, README, and `docs/llms.txt` updated for the new commands.

### Changed

- Releases are now automated. Pushing a change under `bin/**` to `main` (or a
  manual workflow dispatch) auto-increments the patch version, bumps every
  version file in lockstep, runs `make test`, commits, tags, publishes to npm,
  and creates the GitHub Release. Replaces the tag-triggered publish workflow.
  A workflow-dispatch `version` input can force a minor/major bump.

## 0.4.0 - 2026-07-01

### Added

- Update check: interactive runs query the npm registry at most once per day
  (in the background, result cached) and print a one-line notice to stderr when
  a newer release is available. It stays silent in non-interactive use (scripts,
  pipes, CI, `--json`) and can be disabled with `CODEX_PROFILE_NO_UPDATE_CHECK`
  or `DO_NOT_TRACK`. See README "Update Checks" and SECURITY.md "Network
  Activity".
- GitHub Actions workflow that publishes the `codex-profile` npm package on
  `v*` tag pushes (or manual dispatch), gated on `make test` and verifying the
  tag matches `package.json`, with npm provenance.
- Release-drift guard: `make test` now asserts that `bin/codex-profile`'s
  `VERSION` matches `package.json` (which already had to match the docs
  `softwareVersion`), so a version bump can't ship a CLI that reports a stale
  version. Added `doctor` happy-path and `upgrade` missing-Makefile test cases.

### Changed

- `clone-config` allowlist now matches current Codex instruction-file
  conventions: dropped the obsolete `instructions.md` and
  `custom-instructions.md` entries, leaving `config.toml` and the global
  `AGENTS.md` (Codex consolidated global user instructions onto `AGENTS.md`).
- `app` and `app-instance` now fail with a clear "only available on macOS"
  message on non-macOS systems instead of a Codex-path "not found" error.
- `help` is now listed in `codex-profile help` output, and the README
  Platform Support list includes `version` and `help`.

## 0.3.0 - 2026-06-30

### Added

- AI-native onboarding: a root `AGENTS.md` that gives AI coding agents working in
  the repository the project overview, setup, test, run, convention, and safety
  guidance in the format Codex and similar agents read automatically.
- README "Run It With an AI Assistant" section with a ready-to-paste prompt for
  chatbots and an expandable copy-paste answer block for "how do I run this?".
- `llms.txt` "How to run" answer template and an AI-assistant FAQ entry on the
  GitHub Pages project page.
- npm package metadata and public install documentation for the published
  `codex-profile` package.
- Experimental `app-instance` command for launching profile-specific Codex
  Desktop app clones with isolated `CODEX_HOME`, Electron user data, and
  profile-local instance logs.
- `logs <profile> --instance` for reading experimental app-instance logs.
- Branded README demo asset showing two scoped Codex Desktop profile instances
  side by side.
- README launch-mode and isolation-boundary tables for the experimental
  parallel Desktop workflow.
- README origin-story section explaining the real multi-account workflow that
  motivated the project.
- GitHub Pages-ready GEO documentation with canonical metadata, JSON-LD,
  `robots.txt`, `sitemap.xml`, `llms.txt`, a public audit matrix, and a
  measurement plan.
- Pages deployment workflow for publishing the static GEO documentation.

### Changed

- Refreshed README positioning around profile-scoped Codex Desktop instances
  and included media assets in the npm package file list.
- Updated package homepage and package file list so the AI-readable docs ship
  with npm metadata.

### Fixed

- Desktop profile switching now escalates to a forced quit if Codex does not
  close cleanly after the initial quit request.
- Fixed experimental app-instance launches on macOS by preserving Codex's
  `CFBundleName` for Electron helper lookup and launching cloned bundles
  through `open -a` with workspace folders passed as documents.

### Tests

- Added npm package installation coverage.
- Added coverage for app-instance launch isolation, app clone rebuilds, and
  completion/help output.
- Added GEO documentation tests for canonical URLs, indexability directives,
  robots, sitemap, FAQ/schema alignment, `llms.txt`, measurement docs, and
  Pages deployment wiring.

## 0.2.0 - 2026-05-21

### Added

- `init` command for explicit profile home creation.
- `remove` command with profile-name confirmation and `--yes` automation mode.
- `logs` command for printing, tailing, or locating profile-local desktop logs.
- `clone-config` command for copying known non-secret config files between
  profiles without copying auth, sessions, plugins, logs, or caches.
- `status --json` and `doctor --json` for script-friendly diagnostics.
- `completions` command for Bash, Zsh, and Fish completion generation.
- `list` command for read-only initialized profile discovery.
- `version` and `--version` output.
- `upgrade` command for source-style self-updates from the project git
  repository, including `--dry-run`, `--prefix`, `--ref`, unversioned-candidate
  refusal, older-version refusal, and branch, tag, or commit-SHA refs.

### Changed

- Profile path mapping now treats only `default` as special. Every other valid
  name, including `dev`, `main`, and `edu`, maps directly to
  `.codex-<profile>`.
- All-profile `status` now skips invalid `.codex-*` directory names during
  discovery.
- `doctor` now accepts options and can emit machine-readable output.

### Tests

- Added coverage for CLI/login argument pass-through, invalid profile names,
  direct profile-name path mapping, list output, version output, hardened
  status discovery, JSON diagnostics, profile lifecycle commands, log
  inspection, completion generation, source upgrades, dirty upgrade checkout
  protection, commit-SHA refs, unversioned-candidate refusal, older-version
  refusal, and safe config cloning.

## 0.1.1 - 2026-04-25

### Fixed

- Desktop app switching now waits for both the main Codex app process and the
  bundled Codex app-server process to stop before launching a new profile.
- Profile directory permission setup now fails loudly if private permissions
  cannot be applied.
- `status` no longer creates missing profile directories.
- `status` now propagates unexpected Codex CLI failures while still treating
  "Not logged in" as a normal status result.

## 0.1.0 - 2026-04-25

### Added

- Initial `codex-profile` CLI.
- Profile-aware commands for Codex CLI, Codex Desktop, login, status, path, and
  doctor workflows.
- macOS and Ubuntu CI smoke tests.
- Profile-local desktop log handling.
- Public README with installation, usage, FAQ, and security boundary sections.
- Contribution and security documentation.
- GitHub issue and pull request templates.
