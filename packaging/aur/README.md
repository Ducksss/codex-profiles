# AUR publication and update runbook

The GitHub release workflow validates the tracked Arch package, but it does not
hold AUR credentials or write to the external AUR Git repository. A maintainer
must use this runbook after the immutable upstream release tag exists. The same
fail-closed staging and validation steps apply to the first publication and to
every later update.

Run the commands in one dedicated Bash shell from a clean clone of
`Ducksss/codex-profiles`. Stop on any unexpected output, metadata difference,
repository history, or package content. Never repair tagged files directly in
the AUR clone; fix the source repository and publish a new release instead.

## Prerequisites and credential boundary

The maintainer needs:

- an AUR account with its email address confirmed;
- `git`, OpenSSH, `curl`, `jq`, Docker, and a running Docker daemon;
- permission to pull and run the official `archlinux:base-devel` image; and
- the already-published, immutable upstream tag being handed to AUR.

Use a dedicated, passphrase-protected Ed25519 key for AUR publication. The
private key is local maintainer material: **never** put it in this repository,
a GitHub Actions secret, an issue or pull request, chat, shell output, or a
shared artifact. GitHub Actions intentionally has no AUR credential. Only the
public `.pub` file belongs in the AUR account's SSH Public Key field.

Create the key once outside every repository:

```bash
umask 077
mkdir -p "$HOME/.ssh"
ssh-keygen -t ed25519 -a 100 \
  -f "$HOME/.ssh/aur_codex_profile_ed25519" \
  -C "AUR codex-profile"
chmod 600 "$HOME/.ssh/aur_codex_profile_ed25519"
```

Register the contents of
`~/.ssh/aur_codex_profile_ed25519.pub` in the AUR account. Do not copy or
display the private file. On the first SSH connection, compare the presented
`aur.archlinux.org` host-key fingerprint with the current official AUR
documentation before accepting it.

Force every AUR Git operation to use only this identity:

```bash
export AUR_SSH_KEY="$HOME/.ssh/aur_codex_profile_ed25519"
[[ -f "$AUR_SSH_KEY" && ! -L "$AUR_SSH_KEY" ]]
export GIT_SSH_COMMAND="ssh -i $AUR_SSH_KEY -o IdentitiesOnly=yes"
```

`IdentitiesOnly=yes` prevents an agent or unrelated default key from silently
selecting a different AUR account.

## Select and extract the immutable release

Set the exact upstream version and Arch package release. The initial
publication uses `0.7.0-1`; later source releases normally reset `PKGREL` to
`1`.

```bash
set -euo pipefail

export PACKAGE_NAME=codex-profile
export VERSION=0.7.0
export PKGREL=1
export TAG="v$VERSION"
export EXPECTED_AUR_VERSION="$VERSION-$PKGREL"
export REPO_ROOT="$(git rev-parse --show-toplevel)"
export WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/codex-profile-aur.XXXXXX")"
export EXTRACT_DIR="$WORK_DIR/tag"
export RELEASE_DIR="$WORK_DIR/release"
export AUR_DIR="$WORK_DIR/aur"
trap 'rm -rf "$WORK_DIR"' EXIT

[[ -z "$(git -C "$REPO_ROOT" status --porcelain)" ]]
git -C "$REPO_ROOT" fetch --no-tags origin \
  "refs/tags/$TAG:refs/tags/$TAG"
[[ "$(git -C "$REPO_ROOT" cat-file -t "$TAG")" == tag ]]
git -C "$REPO_ROOT" cat-file -e "$TAG^{commit}"

mkdir -p "$EXTRACT_DIR" "$RELEASE_DIR"
git -C "$REPO_ROOT" archive --format=tar "$TAG" -- \
  packaging/aur/PKGBUILD packaging/aur/.SRCINFO LICENSE \
  | tar -xf - -C "$EXTRACT_DIR"
cp "$EXTRACT_DIR/packaging/aur/PKGBUILD" "$RELEASE_DIR/PKGBUILD"
cp "$EXTRACT_DIR/packaging/aur/.SRCINFO" "$RELEASE_DIR/.SRCINFO"
cp "$EXTRACT_DIR/LICENSE" "$RELEASE_DIR/LICENSE"
chmod 0644 "$RELEASE_DIR/PKGBUILD" "$RELEASE_DIR/.SRCINFO" \
  "$RELEASE_DIR/LICENSE"

grep -Fx "pkgname=$PACKAGE_NAME" "$RELEASE_DIR/PKGBUILD"
grep -Fx "pkgver=$VERSION" "$RELEASE_DIR/PKGBUILD"
grep -Fx "pkgrel=$PKGREL" "$RELEASE_DIR/PKGBUILD"
grep -Fx $'\tpkgver = '"$VERSION" "$RELEASE_DIR/.SRCINFO"
grep -Fx $'\tpkgrel = '"$PKGREL" "$RELEASE_DIR/.SRCINFO"
grep -F "v$VERSION/bin/codex-profile" "$RELEASE_DIR/PKGBUILD"
grep -F "v$VERSION/LICENSE" "$RELEASE_DIR/PKGBUILD"
```

The annotated-tag check deliberately rejects a branch, working-tree file, or
lightweight replacement as the publication source. The archive step extracts
`PKGBUILD`, `.SRCINFO`, and `LICENSE` from that tag rather than from `main`.

## Validate in a clean Arch container

Define this validator once in the same shell. It installs build tooling as
container root, then runs every `makepkg` and `namcap` operation as the
unprivileged `builder` user. It regenerates `.SRCINFO`, verifies pinned source
checksums, performs a clean build, and inspects the resulting package rather
than trusting metadata alone.

```bash
docker pull archlinux:base-devel

validate_aur_tree() {
  local package_dir="$1"
  [[ -f "$package_dir/PKGBUILD" ]]
  [[ -f "$package_dir/.SRCINFO" ]]
  [[ -f "$package_dir/LICENSE" ]]

  docker run --rm -i \
    --mount "type=bind,src=$package_dir,dst=/release,readonly" \
    archlinux:base-devel bash -s <<'CONTAINER'
set -euo pipefail
pacman -Syu --noconfirm namcap
useradd --create-home builder
install -d -o builder -g builder /build
cp /release/PKGBUILD /release/.SRCINFO /release/LICENSE /build/
chown -R builder:builder /build

runuser -u builder -- bash -s <<'BUILDER'
set -euo pipefail
cd /build

makepkg --printsrcinfo > .SRCINFO.generated
diff -u .SRCINFO .SRCINFO.generated
makepkg --verifysource
makepkg --cleanbuild --clean --noconfirm

mapfile -t package_files < <(makepkg --packagelist)
[[ "${#package_files[@]}" -eq 1 ]]
package_file="${package_files[0]}"
[[ -f "$package_file" ]]

namcap PKGBUILD | tee namcap-pkgbuild.log
namcap "$package_file" | tee namcap-package.log
if grep -Eq '(^|[[:space:]])E:' \
  namcap-pkgbuild.log namcap-package.log; then
  echo 'namcap reported an error' >&2
  exit 1
fi

package_root="$(mktemp -d)"
trap 'rm -rf "$package_root"' EXIT
bsdtar -xf "$package_file" -C "$package_root"
canonical="$package_root/usr/bin/codex-profile"
alias="$package_root/usr/bin/codex-profiles"
version="$(sed -n 's/^pkgver=//p' PKGBUILD)"

[[ -x "$canonical" ]]
[[ -L "$alias" ]]
[[ "$(readlink "$alias")" == codex-profile ]]
[[ -f "$package_root/usr/share/licenses/codex-profile/LICENSE" ]]
CODEX_PROFILE_NO_UPDATE_CHECK=1 "$canonical" version \
  | grep -Fx "codex-profile $version"
CODEX_PROFILE_NO_UPDATE_CHECK=1 "$alias" version \
  | grep -Fx "codex-profile $version"
BUILDER
CONTAINER
}

validate_aur_tree "$RELEASE_DIR"
```

Review every `namcap` warning printed by the container. All errors and all
actionable warnings must be resolved in the source repository and a new tag;
do not patch the extracted release or waive an unexplained result.

## First publication

Before creating `codex-profile`, prove that the name is unclaimed through the
AUR RPC. A nonzero result means stop: do not overwrite, adopt, or impersonate
an existing package.

```bash
rpc_payload="$(
  curl -fsS --get \
    --data-urlencode "arg[]=$PACKAGE_NAME" \
    https://aur.archlinux.org/rpc/v5/info
)"
jq -e '.resultcount == 0 and (.results | length == 0)' \
  <<<"$rpc_payload" >/dev/null
```

Clone the package's SSH URL. A legitimate first-publication clone is an unborn
`master` branch with no commit and no tracked or untracked content. This check
also closes the race between the RPC lookup and clone. **Stop immediately** if
any history or content appears.

```bash
git clone "ssh://aur@aur.archlinux.org/$PACKAGE_NAME.git" "$AUR_DIR"
[[ "$(git -C "$AUR_DIR" symbolic-ref --short HEAD)" == master ]]
if git -C "$AUR_DIR" rev-parse --verify HEAD >/dev/null 2>&1; then
  echo 'AUR repository unexpectedly has history; stopping' >&2
  exit 1
fi
[[ -z "$(git -C "$AUR_DIR" status --short --untracked-files=all)" ]]
```

Continue at [Commit and push `master`](#commit-and-push-master).

## Updating an existing package

For an update, require an existing exact package result before cloning. Then
inspect the AUR history before changing anything. Stop if the history, package
base, remote, or current maintainer state is not the expected continuation of
the previously published package.

```bash
rpc_payload="$(
  curl -fsS --get \
    --data-urlencode "arg[]=$PACKAGE_NAME" \
    https://aur.archlinux.org/rpc/v5/info
)"
jq -e --arg name "$PACKAGE_NAME" '
  .resultcount == 1 and
  .results[0].Name == $name and
  .results[0].PackageBase == $name
' <<<"$rpc_payload" >/dev/null

git clone "ssh://aur@aur.archlinux.org/$PACKAGE_NAME.git" "$AUR_DIR"
[[ "$(git -C "$AUR_DIR" branch --show-current)" == master ]]
git -C "$AUR_DIR" rev-parse --verify HEAD >/dev/null
[[ -z "$(git -C "$AUR_DIR" status --porcelain)" ]]
git -C "$AUR_DIR" remote -v
git -C "$AUR_DIR" log --oneline --decorate -10
```

The remote and history lines are a mandatory manual review gate. They are not
an invitation to force-push, reset, or rewrite unexpected AUR history.

## Commit and push `master`

Copy only the three tag-extracted files. Configure the AUR clone—not the global
Git configuration—with the public maintainer identity `Ducksss` and the GitHub
noreply address.

```bash
cp "$RELEASE_DIR/PKGBUILD" "$AUR_DIR/PKGBUILD"
cp "$RELEASE_DIR/.SRCINFO" "$AUR_DIR/.SRCINFO"
cp "$RELEASE_DIR/LICENSE" "$AUR_DIR/LICENSE"
chmod 0644 "$AUR_DIR/PKGBUILD" "$AUR_DIR/.SRCINFO" "$AUR_DIR/LICENSE"

cmp "$RELEASE_DIR/PKGBUILD" "$AUR_DIR/PKGBUILD"
cmp "$RELEASE_DIR/.SRCINFO" "$AUR_DIR/.SRCINFO"
cmp "$RELEASE_DIR/LICENSE" "$AUR_DIR/LICENSE"

git -C "$AUR_DIR" config user.name "Ducksss"
git -C "$AUR_DIR" config user.email \
  "58126222+Ducksss@users.noreply.github.com"
git -C "$AUR_DIR" add PKGBUILD .SRCINFO LICENSE
git -C "$AUR_DIR" diff --cached --check
git -C "$AUR_DIR" status --short
git -C "$AUR_DIR" diff --cached
```

Read the complete staged diff. It must match the tag exactly and contain no
key, generated package, source archive, log, or unrelated file. For an update,
an empty diff means the version is already published; do not create an empty
commit.

```bash
[[ -n "$(git -C "$AUR_DIR" diff --cached --name-only)" ]]
git -C "$AUR_DIR" commit -m "$PACKAGE_NAME $EXPECTED_AUR_VERSION"
export PUSHED_COMMIT="$(git -C "$AUR_DIR" rev-parse HEAD)"
git -C "$AUR_DIR" push origin master
```

Never use `--force`, amend a published AUR commit, or push a branch other than
`master`.

## Verify the public package

The publication is incomplete until both the AUR RPC and an anonymous public
clone expose the pushed version. This poll allows a short RPC propagation
delay, but it fails if the exact `0.7.0-1` postcondition is not reached.

```bash
rpc_verified=false
for attempt in {1..12}; do
  rpc_payload="$(
    curl -fsS --get \
      --data-urlencode "arg[]=$PACKAGE_NAME" \
      https://aur.archlinux.org/rpc/v5/info
  )"
  if jq -e \
    --arg name "$PACKAGE_NAME" \
    --arg version "$EXPECTED_AUR_VERSION" '
      .resultcount == 1 and
      .results[0].Name == $name and
      .results[0].PackageBase == $name and
      .results[0].Version == $version
    ' <<<"$rpc_payload" >/dev/null; then
    rpc_verified=true
    break
  fi
  sleep 10
done
[[ "$rpc_verified" == true ]]
[[ "$EXPECTED_AUR_VERSION" == 0.7.0-1 || "$VERSION" != 0.7.0 ]]
```

Finally, clone over public HTTPS into a new directory, require the exact pushed
commit and tagged files, and repeat the complete clean Arch build and alias
inspection against what anonymous users receive:

```bash
export PUBLIC_DIR="$WORK_DIR/public"
git clone "https://aur.archlinux.org/$PACKAGE_NAME.git" "$PUBLIC_DIR"
[[ "$(git -C "$PUBLIC_DIR" branch --show-current)" == master ]]
[[ "$(git -C "$PUBLIC_DIR" rev-parse HEAD)" == "$PUSHED_COMMIT" ]]
cmp "$RELEASE_DIR/PKGBUILD" "$PUBLIC_DIR/PKGBUILD"
cmp "$RELEASE_DIR/.SRCINFO" "$PUBLIC_DIR/.SRCINFO"
cmp "$RELEASE_DIR/LICENSE" "$PUBLIC_DIR/LICENSE"
validate_aur_tree "$PUBLIC_DIR"
```

Only after the RPC reports the expected version and the anonymous clone builds
with both working commands and the relative
`codex-profiles -> codex-profile` symlink is the AUR handoff complete.
