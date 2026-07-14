#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/aur/lib.sh
source "$SCRIPT_DIR/lib.sh"

usage() {
  cat >&2 <<'EOF'
Usage: scripts/aur/verify.sh --version X.Y.Z --checkout DIRECTORY
  [--expected DIRECTORY]
  [--rpc-json FILE] [--rpc-state unclaimed|owned|exact]
  [--container auto|always|never]
EOF
}

version=""
checkout_input=""
expected_input=""
rpc_json=""
rpc_state="exact"
container_mode="auto"
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --version | --checkout | --expected | --rpc-json | --rpc-state | --container)
      [[ "$#" -ge 2 ]] || { usage; exit 2; }
      case "$1" in
        --version) version="$2" ;;
        --checkout) checkout_input="$2" ;;
        --expected) expected_input="$2" ;;
        --rpc-json) rpc_json="$2" ;;
        --rpc-state) rpc_state="$2" ;;
        --container) container_mode="$2" ;;
      esac
      shift 2
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      usage
      exit 2
      ;;
  esac
done

[[ -n "$version" && -n "$checkout_input" ]] || { usage; exit 2; }
aur_validate_version "$version"
case "$container_mode" in auto | always | never) ;; *) aur_die "container mode must be auto, always, or never" ;; esac
case "$rpc_state" in unclaimed | owned | exact) ;; *) aur_die "RPC state must be unclaimed, owned, or exact" ;; esac
[[ -d "$checkout_input" && ! -L "$checkout_input" ]] \
  || aur_die "checkout must be a real directory: $checkout_input"
checkout="$(cd "$checkout_input" && pwd -P)"
[[ -n "$checkout" && "$checkout" != "/" && "$checkout" != *$'\n'* && "$checkout" != *","* ]] \
  || aur_die "unsafe checkout path: $checkout"
if [[ -n "$expected_input" ]]; then
  [[ -d "$expected_input" && ! -L "$expected_input" ]] \
    || aur_die "expected files must be in a real directory: $expected_input"
  expected="$(cd "$expected_input" && pwd -P)"
  [[ -n "$expected" && "$expected" != "/" && "$expected" != *$'\n'* ]] \
    || aur_die "unsafe expected directory: $expected"
  for file in PKGBUILD .SRCINFO LICENSE; do
    aur_require_regular_file "$expected/$file" "expected immutable $file"
    aur_require_regular_file "$checkout/$file" "checkout $file"
    cmp -s "$expected/$file" "$checkout/$file" \
      || aur_die "checkout $file does not match expected immutable $file"
  done
fi

aur_require_command curl
aur_require_command jq
temp_root_input="${TMPDIR:-/tmp}"
[[ -d "$temp_root_input" ]] || aur_die "temporary root does not exist: $temp_root_input"
temp_root="$(cd "$temp_root_input" && pwd -P)"
[[ -n "$temp_root" && "$temp_root" != "/" ]] || aur_die "unsafe temporary root: $temp_root"
work_dir="$(mktemp -d "$temp_root/codex-profile-aur-verify.XXXXXX")"
cleanup() {
  case "$work_dir" in
    "$temp_root"/codex-profile-aur-verify.*) rm -rf -- "$work_dir" ;;
    *) printf 'Refusing unsafe cleanup path: %s\n' "$work_dir" >&2 ;;
  esac
}
trap cleanup EXIT

sources="$work_dir/sources"
mkdir "$sources"
curl --retry 3 --retry-all-errors --connect-timeout 10 --max-time 60 -fsSL \
  "https://raw.githubusercontent.com/Ducksss/codex-profiles/v$version/bin/codex-profile" \
  -o "$sources/codex-profile-$version"
curl --retry 3 --retry-all-errors --connect-timeout 10 --max-time 60 -fsSL \
  "https://raw.githubusercontent.com/Ducksss/codex-profiles/v$version/LICENSE" \
  -o "$sources/LICENSE-$version"
chmod 0600 "$sources/codex-profile-$version" "$sources/LICENSE-$version"
aur_validate_metadata "$version" "$checkout" "$sources"

if [[ -z "$rpc_json" ]]; then
  rpc_json="$work_dir/aur-rpc.json"
  curl --retry 3 --retry-all-errors --connect-timeout 10 --max-time 60 -fsSL --get \
    --data-urlencode 'arg[]=codex-profile' \
    https://aur.archlinux.org/rpc/v5/info \
    -o "$rpc_json"
fi
aur_validate_rpc "$rpc_json" "$rpc_state" "$version"
printf 'Metadata, sources, checksums, aliases, and RPC state verified for codex-profile %s-%s.\n' \
  "$version" "$AUR_PKGREL"

run_container_validation() {
  docker run --rm -i \
    --mount "type=bind,src=$checkout,dst=/release,readonly" \
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
namcap PKGBUILD | tee namcap-pkgbuild.log
namcap "$package_file" | tee namcap-package.log
! grep -Eq '(^|[[:space:]])E:' namcap-pkgbuild.log namcap-package.log

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
CODEX_PROFILE_NO_UPDATE_CHECK=1 "$canonical" version | grep -Fx "codex-profile $version"
CODEX_PROFILE_NO_UPDATE_CHECK=1 "$alias" version | grep -Fx "codex-profile $version"
BUILDER
CONTAINER
}

if [[ "$container_mode" == "never" ]]; then
  printf 'Container validation: skipped by request.\n'
elif command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
  run_container_validation
  printf 'Container validation: passed.\n'
elif [[ "$container_mode" == "always" ]]; then
  aur_die "Docker is required and its daemon must be available for --container always"
else
  printf 'Container validation: Docker unavailable; metadata verification only.\n'
fi
