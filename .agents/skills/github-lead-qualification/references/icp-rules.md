# GitHub Lead Qualification ICP Rules

Use these rules to score `codex-profiles` candidates. The product is an
open-source developer CLI for named Codex homes and, on macOS, named ChatGPT
windows with separate local state. Codex CLI commands remain Codex-only; named
app launches apply across Chat, Work, and Codex. It is not an official OpenAI
project and does not create an account or operating-system isolation boundary.

## ICP: yes

- Codex, OpenAI Codex, AI coding agent, CLI, terminal, package, shell,
  developer workflow, and open-source devtool catalogs.
- Awesome lists or directories with a maintained section for CLI tools,
  terminal agents, AI coding tools, local developer workflow tools, or Codex
  resources.
- Targets with a clear contribution route and enough evidence to explain why
  `codex-profiles` helps the target audience.

## ICP: maybe

- Broad AI, productivity, or developer-tool directories with a free structured
  category that may truthfully list an open-source CLI.
- Ambiguous awesome lists where an issue-first scope check is safer than a PR.
- Account-gated, OAuth-gated, CAPTCHA-gated, paid, or unclear submission flows.

## ICP: no

- Startup maps, founder directories, accelerators, incubators, investor
  networks, funding or venture media, regional startup ecosystems, startup
  events, and generic launch boards without a developer-tool category.
- Social-post-only channels with no durable repository, listing, or catalog.
- Targets that require company, funding, traction, geography, sponsorship, or
  customer claims not already documented in the repository.

## Truthfulness gate

- Do not invent a company, startup, region, market, customer story, customer
  count, founder identity, or paid sponsorship angle.
- State only what the repo supports: named `CODEX_HOME` directories, separate
  Codex CLI profiles, named ChatGPT windows on macOS, macOS/Linux CLI support,
  no auth-file copying, and dependency-free Bash.
- State the boundary when relevant: app launches select local ChatGPT state for
  the whole window; SSH keys, GitHub CLI auth, browser cookies, OS credentials,
  and server-side account state remain outside the isolation boundary.
- If the target would require unsupported claims, mark `ICP: no` or
  `ICP: maybe` with the blocker instead of forcing a fit.

## Priority

- `P0`: direct Codex, agent, CLI, or maintained awesome-list fit.
- `P1`: likely Codex, `CODEX_HOME`, AI agent CLI, or developer workflow fit.
- `P2`: broader devtool visibility with a real but less direct audience match.
