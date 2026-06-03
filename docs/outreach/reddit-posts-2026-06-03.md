# Reddit Outreach Drafts - 2026-06-03

Use the double-Codex image for the `r/codex` post:

- Local asset:
  `media/codex-profile-parallel-instances.png`
- Raw GitHub URL:
  `https://raw.githubusercontent.com/Ducksss/codex-profiles/main/media/codex-profile-parallel-instances.png`

## r/codex

Post type: image post with body text.

Title:

```text
I made a small Codex profile switcher for separate work/personal accounts
```

Body:

```text
I kept running into Codex account switching workflows that were basically
"copy or swap auth.json", which felt brittle.

Codex already supports CODEX_HOME, so I wrapped that into a small Bash CLI:

npm install -g codex-profile

Examples:

codex-profile login personal
codex-profile login work
codex-profile cli work exec "review this repo"
codex-profile app personal

Each profile gets its own Codex home, so auth, config, sessions, plugins,
connector state, logs, and caches stay separate.

It is not seamless in-place account switching inside an already-running app.
It is a clean next-launch/profile boundary, which is the safer model if you
want work, personal, education, or client state separated.

Repo:
https://github.com/Ducksss/codex-profiles

Would be useful to hear from other multi-account Codex users where this still
falls short.
```

Optional first comment if the image post body is hard to read:

```text
Install:

npm install -g codex-profile

Homebrew:

brew install Ducksss/tap/codex-profile

It is MIT-licensed, Bash, dependency-free at runtime, and it does not parse,
print, copy, or migrate tokens.
```

## r/ChatGPTCoding Self-Promotion Thread

Post type: comment in the active self-promotion thread.

Comment:

```text
I built codex-profiles, a small open-source helper for switching Codex CLI and
Desktop accounts without copying auth.json files.

It launches Codex with a named CODEX_HOME, so each profile has separate auth,
config, sessions, plugins, connector state, logs, caches, and local state.

Install:

npm install -g codex-profile

Examples:

codex-profile login personal
codex-profile cli work exec "review this repo"
codex-profile app personal

Repo:
https://github.com/Ducksss/codex-profiles

Useful if you use Codex across work, personal, education, or client accounts
and want a cleaner boundary than copying token files around.
```

## Posting Notes

- Reddit blocked the Playwright browser with `You've been blocked by network
  security` on both `www.reddit.com` and `old.reddit.com`.
- Post manually from a normal browser/account session.
- For `r/codex`, attach the local image asset instead of only linking the raw
  image if Reddit's composer supports image uploads.
- For `r/ChatGPTCoding`, keep it as a comment in the self-promotion thread
  unless the subreddit rules explicitly allow standalone project posts.
