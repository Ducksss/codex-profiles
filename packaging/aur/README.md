# AUR publication and update runbook

The GitHub release workflow validates the tracked Arch package, but it does not
hold AUR credentials or write to the external AUR Git repository. A maintainer
must use this runbook after the immutable upstream release tag exists. The same
fail-closed staging and validation steps apply to the first publication and to
every later update.

Except for the one-time key bootstrap, run the commands in one dedicated Bash
shell from a clean clone of `Ducksss/codex-profiles`. Start at the credential
verification block when the dedicated key already exists. Stop on any
unexpected output, metadata difference, repository history, identity, owner,
or package content. Never repair tagged files directly in the AUR clone; fix
the source repository and publish a new release instead.

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
set -euo pipefail
umask 077
mkdir -p "$HOME/.ssh"
AUR_SSH_KEY="$HOME/.ssh/aur_codex_profile_ed25519"
if [[ -e "$AUR_SSH_KEY" || -L "$AUR_SSH_KEY" ]]; then
  echo "refusing to overwrite existing AUR key: $AUR_SSH_KEY" >&2
  exit 1
fi
ssh-keygen -t ed25519 -a 100 \
  -f "$AUR_SSH_KEY" \
  -C "AUR codex-profile"
if [[ ! -f "$AUR_SSH_KEY" || -L "$AUR_SSH_KEY" ]]; then
  echo 'ssh-keygen did not create the expected regular private-key file' >&2
  exit 1
fi
if [[ ! -f "$AUR_SSH_KEY.pub" || ! -s "$AUR_SSH_KEY.pub" || -L "$AUR_SSH_KEY.pub" ]]; then
  echo 'ssh-keygen did not create the expected regular public-key file' >&2
  exit 1
fi
chmod 600 "$AUR_SSH_KEY"
chmod 0644 "$AUR_SSH_KEY.pub"
```

Register the contents of
`~/.ssh/aur_codex_profile_ed25519.pub` in the AUR account. Do not copy or
display the private file.

Create `~/.ssh/aur_codex_profile_known_hosts` as a dedicated host-key file.
Obtain the current `aur.archlinux.org` host key through a trusted channel,
compare its fingerprint with the current fingerprint published on the
[official AUR homepage](https://aur.archlinux.org/), and only then install the
verified public host-key line in that file. Do not rely on an interactive first
connection or an unverified `ssh-keyscan` result. This file must contain only
the deliberately verified AUR host key; do not point the runbook at the user's
general `known_hosts` file.

Start the dedicated publication shell by enabling strict mode and proving that
both credential paths are regular files. This explicit failure path matters in
interactive shells, where a bare false predicate would otherwise continue:

```bash
set -euo pipefail
export AUR_SSH_KEY="$HOME/.ssh/aur_codex_profile_ed25519"
export AUR_KNOWN_HOSTS="$HOME/.ssh/aur_codex_profile_known_hosts"
if [[ ! -f "$AUR_SSH_KEY" || -L "$AUR_SSH_KEY" ]]; then
  echo "missing regular AUR private key: $AUR_SSH_KEY" >&2
  exit 1
fi
if [[ ! -f "$AUR_SSH_KEY.pub" || ! -s "$AUR_SSH_KEY.pub" || -L "$AUR_SSH_KEY.pub" ]]; then
  echo "missing regular AUR public key: $AUR_SSH_KEY.pub" >&2
  exit 1
fi
if [[ ! -f "$AUR_KNOWN_HOSTS" || ! -s "$AUR_KNOWN_HOSTS" || -L "$AUR_KNOWN_HOSTS" ]]; then
  echo "missing verified AUR known_hosts file: $AUR_KNOWN_HOSTS" >&2
  exit 1
fi
if ! ssh-keygen -F aur.archlinux.org -f "$AUR_KNOWN_HOSTS" >/dev/null; then
  echo 'verified known_hosts has no aur.archlinux.org entry' >&2
  exit 1
fi
```

The SSH wrapper created below also uses `-F /dev/null`, `IdentitiesOnly=yes`,
`StrictHostKeyChecking=yes`, and the dedicated host-key file. Thus neither an
SSH agent, another key, the user's SSH configuration, nor an interactive trust
prompt can silently select a different account or host.

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
export EXPECTED_AUR_MAINTAINER=Ducksss
export CANONICAL_REPO_URL=https://github.com/Ducksss/codex-profiles.git
export AUR_GIT_NAME=Ducksss
export AUR_GIT_EMAIL=58126222+Ducksss@users.noreply.github.com

unset GIT_CONFIG GIT_CONFIG_PARAMETERS GIT_CONFIG_COUNT GIT_CONFIG_SYSTEM
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR
unset GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_TEMPLATE_DIR
unset GIT_NAMESPACE GIT_SHALLOW_FILE GIT_QUARANTINE_PATH
unset GIT_CEILING_DIRECTORIES GIT_DISCOVERY_ACROSS_FILESYSTEM
export GIT_CONFIG_NOSYSTEM=1
export GIT_CONFIG_GLOBAL=/dev/null
export GIT_NO_REPLACE_OBJECTS=1

REPO_ROOT=
if ! REPO_ROOT="$(git rev-parse --show-toplevel)"; then
  echo 'run this from a clean codex-profiles Git clone' >&2
  exit 1
fi
if [[ -z "$REPO_ROOT" || "$REPO_ROOT" == *$'\n'* ]]; then
  echo 'Git returned an unsafe repository root' >&2
  exit 1
fi
[[ -n "$REPO_ROOT" && -d "$REPO_ROOT" ]]
export REPO_ROOT

origin_url=
if ! origin_url="$(git -C "$REPO_ROOT" remote get-url origin)"; then
  echo 'the source clone has no origin remote' >&2
  exit 1
fi
case "$origin_url" in
  https://github.com/Ducksss/codex-profiles.git | \
    git@github.com:Ducksss/codex-profiles.git | \
    ssh://git@github.com/Ducksss/codex-profiles.git) ;;
  *)
    echo "origin is not the canonical codex-profiles repository: $origin_url" >&2
    exit 1
    ;;
esac

repo_status=
if ! repo_status="$(git -C "$REPO_ROOT" status --porcelain)"; then
  echo 'could not inspect the source clone' >&2
  exit 1
fi
[[ -z "$repo_status" ]]

TEMP_ROOT_INPUT="${TMPDIR:-/tmp}"
if [[ -z "$TEMP_ROOT_INPUT" || ! -d "$TEMP_ROOT_INPUT" ]]; then
  echo 'temporary root is empty or does not exist' >&2
  exit 1
fi
TEMP_ROOT=
if ! TEMP_ROOT="$(cd -- "$TEMP_ROOT_INPUT" && pwd -P)"; then
  echo 'could not resolve the temporary root' >&2
  exit 1
fi
if [[ -z "$TEMP_ROOT" || ! -d "$TEMP_ROOT" || \
  "$TEMP_ROOT" == / || "$TEMP_ROOT" == *$'\n'* ]]; then
  echo 'resolved temporary root is unsafe' >&2
  exit 1
fi

WORK_DIR=
if ! WORK_DIR="$(mktemp -d "$TEMP_ROOT/codex-profile-aur.XXXXXX")"; then
  echo 'could not create the AUR staging directory' >&2
  exit 1
fi
[[ -n "$WORK_DIR" && -d "$WORK_DIR" ]]
case "$WORK_DIR" in
  "$TEMP_ROOT"/codex-profile-aur.*) ;;
  *)
    echo "refusing unsafe staging directory: $WORK_DIR" >&2
    exit 1
    ;;
esac

cleanup_work_dir() {
  case "$WORK_DIR" in
    "$TEMP_ROOT"/codex-profile-aur.*) rm -rf -- "$WORK_DIR" ;;
    *) echo "refusing unsafe cleanup path: $WORK_DIR" >&2 ;;
  esac
}
trap cleanup_work_dir EXIT

work_dir_physical=
if ! work_dir_physical="$(cd -- "$WORK_DIR" && pwd -P)"; then
  echo 'could not resolve the AUR staging directory' >&2
  exit 1
fi
[[ "$work_dir_physical" == "$WORK_DIR" ]]
export WORK_DIR
export EXTRACT_DIR="$WORK_DIR/tag"
export RELEASE_DIR="$WORK_DIR/release"
export AUR_DIR="$WORK_DIR/aur"
export TAG_REPO="$WORK_DIR/upstream.git"
export AUR_SSH_WRAPPER="$WORK_DIR/aur-ssh"

umask 077
cat >"$AUR_SSH_WRAPPER" <<'AUR_SSH'
#!/usr/bin/env bash
set -euo pipefail
: "${AUR_SSH_KEY:?AUR_SSH_KEY is required}"
: "${AUR_KNOWN_HOSTS:?AUR_KNOWN_HOSTS is required}"
exec ssh -F /dev/null \
  -i "$AUR_SSH_KEY" \
  -o IdentitiesOnly=yes \
  -o StrictHostKeyChecking=yes \
  -o UserKnownHostsFile="$AUR_KNOWN_HOSTS" \
  "$@"
AUR_SSH
chmod 0700 "$AUR_SSH_WRAPPER"
unset GIT_SSH_COMMAND
export GIT_SSH="$AUR_SSH_WRAPPER"
export GIT_SSH_VARIANT=ssh
"$AUR_SSH_WRAPPER" aur@aur.archlinux.org help >/dev/null

mkdir -p "$EXTRACT_DIR" "$RELEASE_DIR"
git init --bare "$TAG_REPO"
git -C "$TAG_REPO" fetch --no-tags "$CANONICAL_REPO_URL" \
  "refs/tags/$TAG:refs/tags/$TAG"

tag_type=
if ! tag_type="$(git -C "$TAG_REPO" cat-file -t "$TAG")"; then
  echo "canonical release tag does not exist: $TAG" >&2
  exit 1
fi
[[ "$tag_type" == tag ]]
git -C "$TAG_REPO" cat-file -e "$TAG^{commit}"

release_payload=
if ! release_payload="$(
  curl -fsS \
    -H 'Accept: application/vnd.github+json' \
    -H 'X-GitHub-Api-Version: 2022-11-28' \
    "https://api.github.com/repos/Ducksss/codex-profiles/releases/tags/$TAG"
)"; then
  echo "could not fetch the public GitHub Release for $TAG" >&2
  exit 1
fi
[[ -n "$release_payload" ]]
jq -e --arg tag "$TAG" '
  .tag_name == $tag and
  .draft == false and
  .prerelease == false and
  .published_at != null and
  (.published_at | type == "string" and length > 0) and
  .immutable == true
' <<<"$release_payload" >/dev/null

git -C "$TAG_REPO" archive --format=tar "$TAG" -- \
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
rpc_payload=
if ! rpc_payload="$(
  curl -fsS --get \
    --data-urlencode "arg[]=$PACKAGE_NAME" \
    https://aur.archlinux.org/rpc/v5/info
)"; then
  echo 'AUR RPC lookup failed' >&2
  exit 1
fi
[[ -n "$rpc_payload" ]]
jq -e '.resultcount == 0 and (.results | length == 0)' \
  <<<"$rpc_payload" >/dev/null
```

Clone the package's SSH URL. A legitimate first-publication clone is an unborn
`master` branch with no commit and no tracked or untracked content. This check
also closes the race between the RPC lookup and clone. **Stop immediately** if
any history or content appears.

```bash
git -c init.defaultBranch=master clone "ssh://aur@aur.archlinux.org/$PACKAGE_NAME.git" "$AUR_DIR"
aur_branch=
if ! aur_branch="$(git -C "$AUR_DIR" symbolic-ref --short HEAD)"; then
  echo 'AUR clone has no unborn branch' >&2
  exit 1
fi
[[ "$aur_branch" == master ]]
if git -C "$AUR_DIR" rev-parse --verify HEAD >/dev/null 2>&1; then
  echo 'AUR repository unexpectedly has history; stopping' >&2
  exit 1
fi
aur_status=
if ! aur_status="$(git -C "$AUR_DIR" status --short --untracked-files=all)"; then
  echo 'could not inspect the empty AUR clone' >&2
  exit 1
fi
[[ -z "$aur_status" ]]
```

Continue at [Commit and push `master`](#commit-and-push-master).

## Updating an existing package

For an update, require an existing exact package result before cloning. Then
inspect the AUR history before changing anything. Stop if the history, package
base, remote, or current maintainer state is not the expected continuation of
the previously published package.

```bash
rpc_payload=
if ! rpc_payload="$(
  curl -fsS --get \
    --data-urlencode "arg[]=$PACKAGE_NAME" \
    https://aur.archlinux.org/rpc/v5/info
)"; then
  echo 'AUR RPC lookup failed' >&2
  exit 1
fi
[[ -n "$rpc_payload" ]]
jq -e \
  --arg name "$PACKAGE_NAME" \
  --arg maintainer "$EXPECTED_AUR_MAINTAINER" '
  .resultcount == 1 and
  .results[0].Name == $name and
  .results[0].PackageBase == $name and
  .results[0].Maintainer == $maintainer
' <<<"$rpc_payload" >/dev/null

git clone "ssh://aur@aur.archlinux.org/$PACKAGE_NAME.git" "$AUR_DIR"
aur_branch=
if ! aur_branch="$(git -C "$AUR_DIR" branch --show-current)"; then
  echo 'could not inspect the AUR branch' >&2
  exit 1
fi
[[ "$aur_branch" == master ]]
git -C "$AUR_DIR" rev-parse --verify HEAD >/dev/null
aur_status=
if ! aur_status="$(git -C "$AUR_DIR" status --porcelain)"; then
  echo 'could not inspect the AUR worktree' >&2
  exit 1
fi
[[ -z "$aur_status" ]]
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

aur_origin=
if ! aur_origin="$(git -C "$AUR_DIR" remote get-url origin)"; then
  echo 'AUR clone has no origin remote' >&2
  exit 1
fi
[[ "$aur_origin" == "ssh://aur@aur.archlinux.org/$PACKAGE_NAME.git" ]]

unset GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_AUTHOR_DATE
unset GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL GIT_COMMITTER_DATE
git -C "$AUR_DIR" config user.name "$AUR_GIT_NAME"
git -C "$AUR_DIR" config user.email "$AUR_GIT_EMAIL"
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
staged_names=
if ! staged_names="$(git -C "$AUR_DIR" diff --cached --name-only)"; then
  echo 'could not inspect the staged AUR files' >&2
  exit 1
fi
[[ -n "$staged_names" ]]

GIT_AUTHOR_NAME="$AUR_GIT_NAME" \
GIT_AUTHOR_EMAIL="$AUR_GIT_EMAIL" \
GIT_COMMITTER_NAME="$AUR_GIT_NAME" \
GIT_COMMITTER_EMAIL="$AUR_GIT_EMAIL" \
  git -C "$AUR_DIR" commit -m "$PACKAGE_NAME $EXPECTED_AUR_VERSION"

commit_author_name=
if ! commit_author_name="$(git -C "$AUR_DIR" show -s --format=%an HEAD)"; then
  echo 'could not read committed author name' >&2
  exit 1
fi
commit_author_email=
if ! commit_author_email="$(git -C "$AUR_DIR" show -s --format=%ae HEAD)"; then
  echo 'could not read committed author email' >&2
  exit 1
fi
commit_committer_name=
if ! commit_committer_name="$(git -C "$AUR_DIR" show -s --format=%cn HEAD)"; then
  echo 'could not read committed committer name' >&2
  exit 1
fi
commit_committer_email=
if ! commit_committer_email="$(git -C "$AUR_DIR" show -s --format=%ce HEAD)"; then
  echo 'could not read committed committer email' >&2
  exit 1
fi
[[ "$commit_author_name" == "$AUR_GIT_NAME" ]]
[[ "$commit_author_email" == "$AUR_GIT_EMAIL" ]]
[[ "$commit_committer_name" == "$AUR_GIT_NAME" ]]
[[ "$commit_committer_email" == "$AUR_GIT_EMAIL" ]]

PUSHED_COMMIT=
if ! PUSHED_COMMIT="$(git -C "$AUR_DIR" rev-parse --verify "HEAD^{commit}")"; then
  echo 'could not resolve the AUR commit' >&2
  exit 1
fi
[[ "$PUSHED_COMMIT" =~ ^[0-9a-f]{40,64}$ ]]
export PUSHED_COMMIT
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
  rpc_payload=
  if ! rpc_payload="$(
    curl -fsS --get \
      --data-urlencode "arg[]=$PACKAGE_NAME" \
      https://aur.archlinux.org/rpc/v5/info
  )"; then
    echo "AUR RPC attempt $attempt failed" >&2
  elif jq -e \
    --arg name "$PACKAGE_NAME" \
    --arg maintainer "$EXPECTED_AUR_MAINTAINER" \
    --arg version "$EXPECTED_AUR_VERSION" '
      .resultcount == 1 and
      .results[0].Name == $name and
      .results[0].PackageBase == $name and
      .results[0].Maintainer == $maintainer and
      .results[0].Version == $version
    ' <<<"$rpc_payload" >/dev/null; then
    rpc_verified=true
    break
  fi
  if (( attempt < 12 )); then
    sleep 10
  fi
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
public_branch=
if ! public_branch="$(git -C "$PUBLIC_DIR" branch --show-current)"; then
  echo 'could not inspect the public AUR branch' >&2
  exit 1
fi
[[ "$public_branch" == master ]]
public_commit=
if ! public_commit="$(git -C "$PUBLIC_DIR" rev-parse --verify "HEAD^{commit}")"; then
  echo 'could not resolve the public AUR commit' >&2
  exit 1
fi
[[ "$public_commit" == "$PUSHED_COMMIT" ]]
cmp "$RELEASE_DIR/PKGBUILD" "$PUBLIC_DIR/PKGBUILD"
cmp "$RELEASE_DIR/.SRCINFO" "$PUBLIC_DIR/.SRCINFO"
cmp "$RELEASE_DIR/LICENSE" "$PUBLIC_DIR/LICENSE"
validate_aur_tree "$PUBLIC_DIR"
```

Only after the RPC reports the expected version and the anonymous clone builds
with both working commands and the relative
`codex-profiles -> codex-profile` symlink is the AUR handoff complete.
