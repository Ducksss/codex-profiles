# GitHub Lead Qualification ICP Rules

Use these rules to score `codex-profiles` candidates. The product is an
open-source developer CLI for isolated `CODEX_HOME` profiles across Codex CLI
and Codex Desktop. It is not an official OpenAI project and does not provide
full operating-system isolation.

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
- State only what the repo supports: isolated `CODEX_HOME` directories,
  multiple Codex accounts or contexts, CLI/Desktop support, no auth-token
  copying, and dependency-free Bash.
- If the target would require unsupported claims, mark `ICP: no` or
  `ICP: maybe` with the blocker instead of forcing a fit.

## Priority

- `P0`: direct Codex, agent, CLI, or maintained awesome-list fit.
- `P1`: likely Codex, `CODEX_HOME`, AI agent CLI, or developer workflow fit.
- `P2`: broader devtool visibility with a real but less direct audience match.
