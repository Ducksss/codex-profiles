#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/aur/lib.sh
source "$SCRIPT_DIR/lib.sh"

usage() {
  cat >&2 <<'EOF'
Usage: scripts/aur/prepare.sh --version X.Y.Z --release-json FILE \
  --archive FILE --output DIRECTORY
EOF
}

version=""
release_json=""
archive=""
output_input=""
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --version | --release-json | --archive | --output)
      [[ "$#" -ge 2 ]] || { usage; exit 2; }
      case "$1" in
        --version) version="$2" ;;
        --release-json) release_json="$2" ;;
        --archive) archive="$2" ;;
        --output) output_input="$2" ;;
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

[[ -n "$version" && -n "$release_json" && -n "$archive" && -n "$output_input" ]] \
  || { usage; exit 2; }
aur_validate_version "$version"
aur_require_regular_file "$release_json" "GitHub Release JSON"
aur_require_regular_file "$archive" "release archive"
aur_require_command jq
aur_require_command tar

tag="v$version"
jq -e --arg tag "$tag" '
  .tag_name == $tag and
  .draft == false and
  .prerelease == false and
  (.published_at | type == "string" and length > 0) and
  .immutable == true
' "$release_json" >/dev/null \
  || aur_die "$tag is not an immutable final GitHub Release"

[[ "$output_input" != *$'\n'* && "$output_input" != "/" ]] \
  || aur_die "unsafe output directory: $output_input"
[[ ! -e "$output_input" && ! -L "$output_input" ]] \
  || aur_die "output directory must not already exist: $output_input"
output_parent="$(dirname "$output_input")"
output_name="$(basename "$output_input")"
[[ -d "$output_parent" && "$output_name" != "." && "$output_name" != ".." ]] \
  || aur_die "output parent must exist and have a safe basename"
output_parent="$(cd "$output_parent" && pwd -P)"
[[ -n "$output_parent" && "$output_parent" != "/" ]] \
  || aur_die "unsafe output parent: $output_parent"
output="$output_parent/$output_name"

mkdir -m 0700 "$output"
prepared=false
cleanup_output() {
  if [[ "$prepared" != true && -d "$output" && ! -L "$output" ]]; then
    rm -rf -- "$output"
  fi
}
trap cleanup_output EXIT

archive_members="$output/.archive-members"
tar -tf "$archive" > "$archive_members"
while IFS= read -r member; do
  case "/$member/" in
    //* | */../* | */./*) aur_die "release archive contains an unsafe path: $member" ;;
  esac
done < "$archive_members"

find_member() {
  local suffix="$1"
  local matches

  matches="$(awk -v suffix="$suffix" '
    $0 == suffix || (length($0) > length(suffix) && substr($0, length($0) - length(suffix), 1) == "/" && substr($0, length($0) - length(suffix) + 1) == suffix) { print }
  ' "$archive_members")"
  [[ -n "$matches" && "$matches" != *$'\n'* ]] \
    || aur_die "release archive must contain exactly one $suffix"
  printf '%s\n' "$matches"
}

pkgbuild_member="$(find_member packaging/aur/PKGBUILD)"
srcinfo_member="$(find_member packaging/aur/.SRCINFO)"
cli_member="$(find_member bin/codex-profile)"
license_member="$(find_member LICENSE)"
archive_prefix="${pkgbuild_member%packaging/aur/PKGBUILD}"
[[ "$srcinfo_member" == "${archive_prefix}packaging/aur/.SRCINFO" \
  && "$cli_member" == "${archive_prefix}bin/codex-profile" \
  && "$license_member" == "${archive_prefix}LICENSE" ]] \
  || aur_die "release archive files do not share one root"

sources="$output/.sources"
mkdir -m 0700 "$sources"
tar -xOf "$archive" "$pkgbuild_member" > "$output/PKGBUILD"
tar -xOf "$archive" "$srcinfo_member" > "$output/.SRCINFO"
tar -xOf "$archive" "$license_member" > "$output/LICENSE"
tar -xOf "$archive" "$cli_member" > "$sources/codex-profile-$version"
tar -xOf "$archive" "$license_member" > "$sources/LICENSE-$version"
chmod 0644 "$output/PKGBUILD" "$output/.SRCINFO" "$output/LICENSE"
chmod 0600 "$sources/codex-profile-$version" "$sources/LICENSE-$version"

aur_validate_metadata "$version" "$output" "$sources"
rm -rf -- "$sources" "$archive_members"
prepared=true

printf 'Prepared codex-profile %s-%s from immutable %s.\n' "$version" "$AUR_PKGREL" "$tag"
printf 'Review directory: %s\n' "$output"
printf 'Files: PKGBUILD .SRCINFO LICENSE\n'
printf 'Checksums: %s %s\n' "$AUR_CLI_CHECKSUM" "$AUR_LICENSE_CHECKSUM"
printf 'No AUR credentials were used and no push was performed.\n'
