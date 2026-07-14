#!/usr/bin/env bash

# Shared, read-only validation for AUR preparation and verification.
# Dollar expressions below intentionally match literal PKGBUILD or jq input.
# shellcheck disable=SC2016

aur_die() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

aur_require_command() {
  command -v "$1" >/dev/null 2>&1 || aur_die "$1 is required"
}

aur_require_regular_file() {
  local path="$1"
  local label="$2"

  [[ -f "$path" && ! -L "$path" ]] \
    || aur_die "$label must be a regular file: $path"
}

aur_validate_version() {
  local version="$1"

  [[ "$version" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]] \
    || aur_die "expected an exact X.Y.Z version, got: $version"
}

aur_sha256() {
  local path="$1"

  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$path" | awk '{ print $1 }'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$path" | awk '{ print $1 }'
  else
    aur_die "sha256sum or shasum is required"
  fi
}

aur_expect_once() {
  local file="$1"
  local literal="$2"
  local label="$3"
  local count

  count="$(grep -Fxc "$literal" "$file" || true)"
  [[ "$count" == 1 ]] || aur_die "$label is missing or duplicated in $file"
}

aur_validate_metadata() {
  local version="$1"
  local tree="$2"
  local sources="$3"
  local pkgbuild="$tree/PKGBUILD"
  local srcinfo="$tree/.SRCINFO"
  local license="$tree/LICENSE"
  local pkgrel_values
  local pkgrel
  local checksum
  local actual_cli_checksum
  local actual_license_checksum
  local source_count
  local srcinfo_source_count
  local srcinfo_checksum_count
  local -a checksums=()

  aur_validate_version "$version"
  aur_require_regular_file "$pkgbuild" "PKGBUILD"
  aur_require_regular_file "$srcinfo" ".SRCINFO"
  aur_require_regular_file "$license" "LICENSE"
  aur_require_regular_file "$sources/codex-profile-$version" "codex-profile source"
  aur_require_regular_file "$sources/LICENSE-$version" "LICENSE source"

  aur_expect_once "$pkgbuild" "pkgname=codex-profile" "PKGBUILD package name"
  aur_expect_once "$pkgbuild" "pkgver=$version" "PKGBUILD version"
  pkgrel_values="$(sed -n 's/^pkgrel=\([1-9][0-9]*\)$/\1/p' "$pkgbuild")"
  [[ -n "$pkgrel_values" && "$pkgrel_values" != *$'\n'* ]] \
    || aur_die "PKGBUILD pkgrel must be one positive integer"
  pkgrel="$pkgrel_values"

  aur_expect_once "$pkgbuild" \
    'url="https://github.com/Ducksss/codex-profiles"' \
    "PKGBUILD canonical project URL"
  aur_expect_once "$pkgbuild" \
    '  "codex-profile-$pkgver::https://raw.githubusercontent.com/Ducksss/codex-profiles/v$pkgver/bin/codex-profile"' \
    "PKGBUILD immutable command source"
  aur_expect_once "$pkgbuild" \
    '  "LICENSE-$pkgver::https://raw.githubusercontent.com/Ducksss/codex-profiles/v$pkgver/LICENSE"' \
    "PKGBUILD immutable license source"

  source_count="$(grep -Fc 'https://raw.githubusercontent.com/Ducksss/codex-profiles/' "$pkgbuild" || true)"
  [[ "$source_count" == 2 ]] || aur_die "PKGBUILD must declare exactly two canonical sources"

  while IFS= read -r checksum; do
    checksums[${#checksums[@]}]="$checksum"
  done < <(sed -n "s/^  '\([0-9a-f][0-9a-f]*\)'$/\1/p" "$pkgbuild")
  [[ "${#checksums[@]}" == 2 ]] || aur_die "PKGBUILD must declare exactly two SHA-256 checksums"
  for checksum in "${checksums[@]}"; do
    [[ "$checksum" =~ ^[0-9a-f]{64}$ ]] || aur_die "PKGBUILD contains an invalid SHA-256 checksum"
  done

  actual_cli_checksum="$(aur_sha256 "$sources/codex-profile-$version")"
  actual_license_checksum="$(aur_sha256 "$sources/LICENSE-$version")"
  [[ "${checksums[0]}" == "$actual_cli_checksum" ]] \
    || aur_die "codex-profile source checksum does not match PKGBUILD"
  [[ "${checksums[1]}" == "$actual_license_checksum" ]] \
    || aur_die "LICENSE source checksum does not match PKGBUILD"
  cmp -s "$sources/LICENSE-$version" "$license" \
    || aur_die "staged LICENSE does not match the immutable release source"

  aur_expect_once "$srcinfo" "pkgbase = codex-profile" ".SRCINFO package base"
  aur_expect_once "$srcinfo" $'\tpkgver = '"$version" ".SRCINFO version"
  aur_expect_once "$srcinfo" $'\tpkgrel = '"$pkgrel" ".SRCINFO pkgrel"
  aur_expect_once "$srcinfo" \
    $'\turl = https://github.com/Ducksss/codex-profiles' \
    ".SRCINFO canonical project URL"
  aur_expect_once "$srcinfo" \
    $'\tsource = '"codex-profile-$version::https://raw.githubusercontent.com/Ducksss/codex-profiles/v$version/bin/codex-profile" \
    ".SRCINFO immutable command source"
  aur_expect_once "$srcinfo" \
    $'\tsource = '"LICENSE-$version::https://raw.githubusercontent.com/Ducksss/codex-profiles/v$version/LICENSE" \
    ".SRCINFO immutable license source"
  aur_expect_once "$srcinfo" $'\tsha256sums = '"${checksums[0]}" ".SRCINFO command checksum"
  aur_expect_once "$srcinfo" $'\tsha256sums = '"${checksums[1]}" ".SRCINFO license checksum"
  aur_expect_once "$srcinfo" "pkgname = codex-profile" ".SRCINFO package name"

  srcinfo_source_count="$(grep -c $'^\tsource = ' "$srcinfo" || true)"
  srcinfo_checksum_count="$(grep -c $'^\tsha256sums = ' "$srcinfo" || true)"
  [[ "$srcinfo_source_count" == 2 ]] || aur_die ".SRCINFO must declare exactly two sources"
  [[ "$srcinfo_checksum_count" == 2 ]] || aur_die ".SRCINFO must declare exactly two checksums"

  aur_expect_once "$pkgbuild" \
    '  install -Dm755 "codex-profile-$pkgver" "$pkgdir/usr/bin/codex-profile"' \
    "canonical executable install"
  aur_expect_once "$pkgbuild" \
    '  ln -s codex-profile "$pkgdir/usr/bin/codex-profiles"' \
    "relative codex-profiles alias"
  aur_expect_once "$pkgbuild" \
    '  install -Dm644 "LICENSE-$pkgver" "$pkgdir/usr/share/licenses/$pkgname/LICENSE"' \
    "license install"

  AUR_PKGREL="$pkgrel"
  # These validation outputs are consumed by prepare.sh after sourcing this library.
  # shellcheck disable=SC2034
  AUR_CLI_CHECKSUM="${checksums[0]}"
  # shellcheck disable=SC2034
  AUR_LICENSE_CHECKSUM="${checksums[1]}"
}

aur_validate_rpc() {
  local file="$1"
  local state="$2"
  local version="$3"
  local filter

  aur_require_regular_file "$file" "AUR RPC JSON"
  aur_require_command jq

  case "$state" in
    unclaimed)
      filter='.resultcount == 0 and (.results | type == "array" and length == 0)'
      ;;
    owned)
      filter='
        .resultcount == 1 and
        (.results | type == "array" and length == 1) and
        .results[0].Name == $name and
        .results[0].PackageBase == $name and
        .results[0].Maintainer == $maintainer
      '
      ;;
    exact)
      filter='
        .resultcount == 1 and
        (.results | type == "array" and length == 1) and
        .results[0].Name == $name and
        .results[0].PackageBase == $name and
        .results[0].Maintainer == $maintainer and
        .results[0].Version == ($version + "-" + $pkgrel)
      '
      ;;
    *)
      aur_die "RPC state must be one of: unclaimed, owned, exact"
      ;;
  esac

  jq -e \
    --arg name codex-profile \
    --arg maintainer Ducksss \
    --arg version "$version" \
    --arg pkgrel "$AUR_PKGREL" \
    "$filter" "$file" >/dev/null \
    || aur_die "AUR RPC state does not match required '$state' contract"
}
