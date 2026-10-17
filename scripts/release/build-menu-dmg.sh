#!/usr/bin/env bash

set -euo pipefail

# Builds the notarised menu-bar DMG on a macOS release runner. The Developer ID
# certificate lives only in a temporary keychain, and the App Store Connect key
# only in a private temporary file; both are removed when the script exits.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=scripts/release/lib.sh
source "$SCRIPT_DIR/lib.sh"
cd "$ROOT_DIR"

for name in V MENU_DMG_DIR MENU_APP_CERTIFICATE_P12 MENU_APP_CERTIFICATE_PASSWORD \
  MENU_APP_NOTARY_API_KEY MENU_APP_NOTARY_KEY_ID MENU_APP_NOTARY_ISSUER; do
  release_require_env "$name"
done
[[ "$V" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || release_die "Invalid release version: $V"

umask 077
work_dir="$(mktemp -d "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/menu-dmg.XXXXXX")"
keychain="$work_dir/signing.keychain-db"
original_keychains=()
while IFS= read -r line; do
  line="${line#"${line%%[![:space:]]*}"}"
  line="${line#\"}"
  line="${line%\"}"
  [[ -z "$line" ]] || original_keychains+=("$line")
done < <(security list-keychains -d user)
keychain_created=false

cleanup() {
  if [[ "$keychain_created" == true ]]; then
    if ((${#original_keychains[@]})); then
      security list-keychains -d user -s "${original_keychains[@]}" || true
    fi
    security delete-keychain "$keychain" || true
  fi
  rm -rf "$work_dir"
}
trap cleanup EXIT
trap 'exit 130' HUP INT TERM

printf '%s' "$MENU_APP_CERTIFICATE_P12" | base64 --decode > "$work_dir/certificate.p12" \
  || release_die "MENU_APP_CERTIFICATE_P12 is not valid base64."
[[ -s "$work_dir/certificate.p12" ]] || release_die "MENU_APP_CERTIFICATE_P12 decoded to an empty file."
printf '%s\n' "$MENU_APP_NOTARY_API_KEY" > "$work_dir/notary-key.p8"

keychain_password="$(openssl rand -hex 32)"
security create-keychain -p "$keychain_password" "$keychain"
keychain_created=true
security set-keychain-settings -lut 21600 "$keychain"
security unlock-keychain -p "$keychain_password" "$keychain"
security import "$work_dir/certificate.p12" -k "$keychain" \
  -P "$MENU_APP_CERTIFICATE_PASSWORD" -T /usr/bin/codesign \
  || release_die "Could not import MENU_APP_CERTIFICATE_P12; check MENU_APP_CERTIFICATE_PASSWORD."
rm -f "$work_dir/certificate.p12"
security set-key-partition-list -S apple-tool:,apple:,codesign: -s \
  -k "$keychain_password" "$keychain" > /dev/null
security list-keychains -d user -s "$keychain" ${original_keychains[@]+"${original_keychains[@]}"}

identities=()
while IFS= read -r identity; do
  identities+=("$identity")
done < <(
  security find-identity -v -p codesigning "$keychain" \
    | sed -n 's/^ *[0-9][0-9]*) [0-9A-F]\{40\} "\(Developer ID Application: .*\)"$/\1/p' \
    | sort -u
)
[[ "${#identities[@]}" -eq 1 ]] || release_die \
  "MENU_APP_CERTIFICATE_P12 must hold exactly one valid Developer ID Application identity; found ${#identities[@]}."

build_dir="$work_dir/build"
MENU_APP_BUILD_DIR="$build_dir" \
  MENU_APP_SIGNING_IDENTITY="${identities[0]}" \
  MENU_APP_NOTARY_KEY="$work_dir/notary-key.p8" \
  MENU_APP_NOTARY_KEY_ID="$MENU_APP_NOTARY_KEY_ID" \
  MENU_APP_NOTARY_ISSUER="$MENU_APP_NOTARY_ISSUER" \
  scripts/macos/build-menu-dmg.sh

dmg="Codex-Profiles-$V-universal.dmg"
[[ -s "$build_dir/$dmg" && -s "$build_dir/$dmg.sha256" ]] \
  || release_die "The menu-bar build did not produce $dmg; the app version must match $V."
(cd "$build_dir" && shasum -a 256 -c "$dmg.sha256")
mkdir -p "$MENU_DMG_DIR"
cp "$build_dir/$dmg" "$build_dir/$dmg.sha256" "$MENU_DMG_DIR/"
echo "Built and notarised $dmg."
