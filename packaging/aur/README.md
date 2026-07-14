# AUR publication runbook

The AUR handoff is deliberately maintainer-operated. GitHub Actions validates
the Arch package but never receives an AUR private key and never writes to the
AUR repository. Repository scripts prepare and verify artifacts; the operator
alone reviews, commits, and pushes them.

Use this runbook only after the matching immutable GitHub Release is public.
Never repair a tagged package in the AUR checkout. Fix the source repository,
publish a new release, and prepare that release instead.

## Prerequisites and trust boundary

You need `bash`, `curl`, `git`, `jq`, `tar`, OpenSSH, and either `sha256sum` or
`shasum`. Docker with a running daemon is required for the final clean Arch
build. Run from a clean clone of `Ducksss/codex-profiles`.

Use a dedicated, passphrase-protected Ed25519 key. Its private half is local
maintainer material: never put it in this repository, GitHub Actions, an issue,
chat, logs, or a shared artifact. Register only the `.pub` file in the AUR
account.

Create the key once, outside all repositories:

```bash
set -euo pipefail
umask 077
AUR_SSH_KEY="$HOME/.ssh/aur_codex_profile_ed25519"
test ! -e "$AUR_SSH_KEY" && test ! -L "$AUR_SSH_KEY"
ssh-keygen -t ed25519 -a 100 -f "$AUR_SSH_KEY" -C "AUR codex-profile"
test -f "$AUR_SSH_KEY" && test ! -L "$AUR_SSH_KEY"
test -s "$AUR_SSH_KEY.pub" && test ! -L "$AUR_SSH_KEY.pub"
chmod 600 "$AUR_SSH_KEY"
chmod 0644 "$AUR_SSH_KEY.pub"
```

Create a dedicated `~/.ssh/aur_codex_profile_known_hosts`. Obtain the current
`aur.archlinux.org` key through a trusted channel and compare its fingerprint
with the current fingerprint on the
[official AUR homepage](https://aur.archlinux.org/). Do not trust an
interactive first connection or an unverified `ssh-keyscan` result.

For the manual clone and push below, isolate SSH from the agent, other keys,
user configuration, and general `known_hosts` file:

```bash
export AUR_SSH_KEY="$HOME/.ssh/aur_codex_profile_ed25519"
export AUR_KNOWN_HOSTS="$HOME/.ssh/aur_codex_profile_known_hosts"
test -f "$AUR_SSH_KEY" && test ! -L "$AUR_SSH_KEY"
test -s "$AUR_KNOWN_HOSTS" && test ! -L "$AUR_KNOWN_HOSTS"
ssh-keygen -F aur.archlinux.org -f "$AUR_KNOWN_HOSTS" >/dev/null
```

```bash
AUR_SSH_WRAPPER="$(mktemp)"
cat >"$AUR_SSH_WRAPPER" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
exec ssh -F /dev/null -i "$AUR_SSH_KEY" -o IdentitiesOnly=yes \
  -o StrictHostKeyChecking=yes -o UserKnownHostsFile="$AUR_KNOWN_HOSTS" "$@"
SH
chmod 0700 "$AUR_SSH_WRAPPER"
export GIT_SSH="$AUR_SSH_WRAPPER"
export GIT_SSH_VARIANT=ssh
```

## Prepare the immutable release

Choose the exact release. New upstream versions normally use `pkgrel=1`; that
value is read from the tagged `PKGBUILD` and verified against `.SRCINFO`.

```bash
set -euo pipefail
VERSION=0.7.0
WORK_ROOT="$(mktemp -d)"
curl -fsSL "https://api.github.com/repos/Ducksss/codex-profiles/releases/tags/v$VERSION" \
  -o "$WORK_ROOT/release.json"
curl -fsSL "https://github.com/Ducksss/codex-profiles/archive/refs/tags/v$VERSION.tar.gz" \
  -o "$WORK_ROOT/release.tar.gz"
scripts/aur/prepare.sh --version "$VERSION" \
  --release-json "$WORK_ROOT/release.json" --archive "$WORK_ROOT/release.tar.gz" \
  --output "$WORK_ROOT/staged"
```

`prepare.sh` requires an immutable, non-draft, non-prerelease GitHub Release;
extracts only `PKGBUILD`, `.SRCINFO`, `LICENSE`, and the checksum source from
the archive; verifies versioned source URLs and SHA-256 values; and writes only
the new output directory. It never uses SSH, touches an AUR checkout, commits,
or pushes.

Review the printed version, `pkgrel`, file list, and checksums. The output must
contain exactly `PKGBUILD`, `.SRCINFO`, and `LICENSE`.

## Prove the AUR ownership state

Fetch the package's public RPC state without credentials:

```bash
curl -fsSL --get --data-urlencode 'arg[]=codex-profile' \
  https://aur.archlinux.org/rpc/v5/info -o "$WORK_ROOT/aur-before.json"
```

For a first publication, the name must be unclaimed:

```bash
scripts/aur/verify.sh --version "$VERSION" --checkout "$WORK_ROOT/staged" \
  --rpc-json "$WORK_ROOT/aur-before.json" --rpc-state unclaimed \
  --container auto
```

For an update, exactly one package must be owned by `Ducksss`; an unexpected
owner, package base, or result count is a hard stop:

```bash
scripts/aur/verify.sh --version "$VERSION" --checkout "$WORK_ROOT/staged" \
  --rpc-json "$WORK_ROOT/aur-before.json" --rpc-state owned \
  --container auto
```

`--container auto` performs the clean Arch build when Docker is available and
states clearly when only deterministic metadata checks ran. Use
`--container always` for the required final verification. `--container never`
is useful in constrained environments but does not claim a clean package
build.

## Clone, inspect, and stage

Clone through the isolated SSH wrapper. On first publication, the legitimate
result is an empty unborn `master`; on update, it is a clean existing `master`
owned by the expected package. Stop on unexpected history, branch, remote, or
content.

```bash
AUR_DIR="$WORK_ROOT/aur"
git -c init.defaultBranch=master clone \
  ssh://aur@aur.archlinux.org/codex-profile.git "$AUR_DIR"
git -C "$AUR_DIR" branch --show-current
git -C "$AUR_DIR" status --short --untracked-files=all
git -C "$AUR_DIR" remote -v
git -C "$AUR_DIR" log --oneline --decorate -10
```

Copy only the prepared publication files and prove the copies are exact:

```bash
cp "$WORK_ROOT/staged/PKGBUILD" "$AUR_DIR/PKGBUILD"
cp "$WORK_ROOT/staged/.SRCINFO" "$AUR_DIR/.SRCINFO"
cp "$WORK_ROOT/staged/LICENSE" "$AUR_DIR/LICENSE"
cmp "$WORK_ROOT/staged/PKGBUILD" "$AUR_DIR/PKGBUILD"
cmp "$WORK_ROOT/staged/.SRCINFO" "$AUR_DIR/.SRCINFO"
cmp "$WORK_ROOT/staged/LICENSE" "$AUR_DIR/LICENSE"
```

## Review, commit, and push

Set identity only in the AUR checkout. Review the complete staged diff; it
must contain only the three prepared files and no key, source archive, package,
log, or unrelated content. An empty update means the version is already
published and must not create an empty commit.

```bash
git -C "$AUR_DIR" config user.name Ducksss
git -C "$AUR_DIR" config user.email \
  58126222+Ducksss@users.noreply.github.com
git -C "$AUR_DIR" add PKGBUILD .SRCINFO LICENSE
git -C "$AUR_DIR" diff --cached --check
git -C "$AUR_DIR" status --short
git -C "$AUR_DIR" diff --cached
```

After that human review—and only then—commit and perform the one external
mutation in this runbook:

```bash
PKGREL="$(sed -n 's/^pkgrel=//p' "$AUR_DIR/PKGBUILD")"
git -C "$AUR_DIR" commit -m "codex-profile $VERSION-$PKGREL"
git -C "$AUR_DIR" show --stat --oneline --decorate HEAD
git -C "$AUR_DIR" push origin master
```

Never force-push, amend a published AUR commit, rewrite `master`, or continue
after an identity, ownership, history, or content mismatch.

## Verify the public result

Fetch fresh public state and clone anonymously. Final verification requires
the exact `VERSION-pkgrel`, expected maintainer, regenerated `.SRCINFO`, valid
sources and checksums, a clean package build, the installed license, and the
relative `codex-profiles -> codex-profile` alias.

```bash
curl -fsSL --get --data-urlencode 'arg[]=codex-profile' \
  https://aur.archlinux.org/rpc/v5/info -o "$WORK_ROOT/aur-after.json"
PUBLIC_DIR="$WORK_ROOT/public"
git clone https://aur.archlinux.org/codex-profile.git "$PUBLIC_DIR"
scripts/aur/verify.sh --version "$VERSION" --checkout "$PUBLIC_DIR" \
  --rpc-json "$WORK_ROOT/aur-after.json" --rpc-state exact \
  --container always
```

Compare the public commit with the commit just pushed and compare all three
public files with the prepared directory before declaring the handoff done.

## Recovery and troubleshooting

- If preparation or verification fails, do not edit the tagged files. Fix the
  source repository and issue a new release.
- Before the push, cleanup is simple: remove the disposable directories; no
  external state changed.
- If the push result is uncertain, never push blindly. Fetch the public AUR
  repository and RPC state, compare the public commit and files, then run the
  exact post-publication verification.
- A mutable/draft release, checksum mismatch, unexpected owner, dirty or
  non-`master` checkout, regenerated `.SRCINFO` difference, `namcap` error, or
  broken alias is a stop condition—not something to waive.
- Docker-unavailable `auto` output is not the final build attestation. Start
  Docker and rerun with `--container always`.
- Remove the temporary SSH wrapper and work root when verification succeeds;
  retain no private-key copies or credential-bearing logs.
