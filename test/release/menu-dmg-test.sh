#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT_DIR/test/lib/assertions.sh"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT HUP INT TERM

# Exercise the real release script; the keychain, the random source and the
# inner DMG builder are faked so no certificate or Apple service is needed.
fixture_root="$tmp_dir/repository with spaces"
fake_bin="$tmp_dir/fake-bin"
mkdir -p "$fixture_root/scripts/release" "$fixture_root/scripts/macos" "$fake_bin"
cp "$ROOT_DIR/scripts/release/build-menu-dmg.sh" "$ROOT_DIR/scripts/release/lib.sh" \
  "$fixture_root/scripts/release/"

cat > "$fixture_root/scripts/macos/build-menu-dmg.sh" <<'BUILDER'
#!/usr/bin/env bash
set -euo pipefail
{
  printf 'builder|%s|%s|%s|%s\n' "$MENU_APP_SIGNING_IDENTITY" "$MENU_APP_NOTARY_KEY_ID" \
    "$MENU_APP_NOTARY_ISSUER" "$(cat "$MENU_APP_NOTARY_KEY")"
  printf 'key-mode|%s\n' "$(ls -l "$MENU_APP_NOTARY_KEY" | cut -c1-10)"
} >> "$MENU_DMG_TEST_LOG"
[[ -z "${MENU_DMG_TEST_BUILD_FAILS:-}" ]] || exit 93
mkdir -p "$MENU_APP_BUILD_DIR"
dmg="Codex-Profiles-${MENU_DMG_TEST_APP_VERSION:-1.4.0}-universal.dmg"
printf 'notarised image\n' > "$MENU_APP_BUILD_DIR/$dmg"
(cd "$MENU_APP_BUILD_DIR" && shasum -a 256 "$dmg" > "$dmg.sha256")
BUILDER
chmod 755 "$fixture_root/scripts/macos/build-menu-dmg.sh"

cat > "$fake_bin/security" <<'SECURITY'
#!/usr/bin/env bash
set -euo pipefail
printf 'security|%s\n' "$*" >> "$MENU_DMG_TEST_LOG"
case "$1" in
  list-keychains)
    if [[ "${2:-}:${3:-}" == "-d:user" && $# -eq 3 ]]; then
      printf '    "%s"\n' "/Users/runner/Library/Keychains/login.keychain-db" \
        "/Users/runner/Library/Keychains/with space.keychain-db"
    fi
    ;;
  import)
    [[ -z "${MENU_DMG_TEST_IMPORT_FAILS:-}" ]] || exit 94
    [[ "$(cat "$2")" == 'p12 bytes' ]] || exit 95
    ;;
  find-identity)
    count="${MENU_DMG_TEST_IDENTITIES:-1}"
    for ((i = 1; i <= count; i++)); do
      printf '  %d) %040d "Developer ID Application: Fixture %d (TEAM%d)"\n' "$i" "$i" "$i" "$i"
    done
    printf '  %d) %040d "Apple Development: Someone (DEVTEAM)"\n' "$((count + 1))" 0
    printf '     %d valid identities found\n' "$((count + 1))"
    ;;
esac
SECURITY
cat > "$fake_bin/openssl" <<'OPENSSL'
#!/usr/bin/env bash
printf 'keychain-secret\n'
OPENSSL
chmod 755 "$fake_bin/security" "$fake_bin/openssl"

run_build() {
  local label="$1"
  shift
  log="$tmp_dir/$label.log"
  output_dir="$tmp_dir/$label output"
  : > "$log"
  set +e
  env PATH="$fake_bin:$PATH" RUNNER_TEMP="$tmp_dir" MENU_DMG_TEST_LOG="$log" \
    V=1.4.0 MENU_DMG_DIR="$output_dir" \
    MENU_APP_CERTIFICATE_P12="$(printf 'p12 bytes' | base64)" \
    MENU_APP_CERTIFICATE_PASSWORD='p12 password' \
    MENU_APP_NOTARY_API_KEY='-----BEGIN PRIVATE KEY-----' \
    MENU_APP_NOTARY_KEY_ID=KEYID12345 MENU_APP_NOTARY_ISSUER=issuer-uuid \
    "$@" "$fixture_root/scripts/release/build-menu-dmg.sh" > "$tmp_dir/$label.out" 2>&1
  status=$?
  set -e
}

require_cleanup() {
  local label="$1"
  local keychain_path
  keychain_path="$(sed -n 's/^security|create-keychain -p keychain-secret //p' "$log")"
  [[ -n "$keychain_path" ]] || fail "$label created no keychain"
  assert_contains "$(tail -n 2 "$log")" \
    'security|list-keychains -d user -s /Users/runner/Library/Keychains/login.keychain-db /Users/runner/Library/Keychains/with space.keychain-db' \
    "$label restores the keychain search list"
  assert_equals "$label deletes the keychain" "security|delete-keychain $keychain_path" "$(tail -n 1 "$log")"
  [[ -z "$(find "$tmp_dir" -maxdepth 1 -name 'menu-dmg.*' -print -quit)" ]] \
    || fail "$label left its temporary signing files behind"
}

run_build success
[[ "$status" -eq 0 ]] || { cat "$tmp_dir/success.out" >&2; fail 'a valid signing setup did not build'; }
dmg="Codex-Profiles-1.4.0-universal.dmg"
assert_equals 'published image' 'notarised image' "$(cat "$output_dir/$dmg")"
(cd "$output_dir" && shasum -a 256 -c "$dmg.sha256" > /dev/null)
assert_contains "$(cat "$log")" \
  'builder|Developer ID Application: Fixture 1 (TEAM1)|KEYID12345|issuer-uuid|-----BEGIN PRIVATE KEY-----' \
  'builder receives the identity and API key'
assert_contains "$(cat "$log")" 'key-mode|-rw-------' 'the API key file is private'
assert_contains "$(cat "$log")" "security|import $tmp_dir/menu-dmg." 'the certificate is imported'
assert_contains "$(cat "$log")" '-P p12 password -T /usr/bin/codesign' 'the import is limited to codesign'
assert_contains "$(cat "$log")" 'security|set-key-partition-list -S apple-tool:,apple:,codesign: -s' \
  'codesign may use the key without a prompt'
assert_contains "$(grep '^security|list-keychains -d user -s' "$log" | head -n 1)" \
  'signing.keychain-db /Users/runner/Library/Keychains/login.keychain-db /Users/runner/Library/Keychains/with space.keychain-db' \
  'the signing keychain is searched first'
assert_not_contains "$(cat "$tmp_dir/success.out")" 'p12 password' 'the certificate password is never printed'
assert_not_contains "$(cat "$tmp_dir/success.out")" 'BEGIN PRIVATE KEY' 'the API key is never printed'
require_cleanup success

run_build mismatch MENU_DMG_TEST_APP_VERSION=1.3.0
[[ "$status" -ne 0 ]] || fail 'a DMG for another version was accepted'
assert_contains "$(cat "$tmp_dir/mismatch.out")" 'app version must match 1.4.0' 'version mismatch diagnostics'
[[ ! -e "$output_dir" ]] || fail 'a mismatched build published files'
require_cleanup mismatch

run_build build-failure MENU_DMG_TEST_BUILD_FAILS=1
[[ "$status" -ne 0 ]] || fail 'a failed notarisation build succeeded'
[[ ! -e "$output_dir" ]] || fail 'a failed build published files'
require_cleanup build-failure

run_build bad-password MENU_DMG_TEST_IMPORT_FAILS=1
[[ "$status" -ne 0 ]] || fail 'a certificate that could not be imported succeeded'
assert_contains "$(cat "$tmp_dir/bad-password.out")" 'check MENU_APP_CERTIFICATE_PASSWORD' 'import diagnostics'
require_cleanup bad-password

for count in 0 2; do
  run_build "identities-$count" MENU_DMG_TEST_IDENTITIES="$count"
  [[ "$status" -ne 0 ]] || fail "$count Developer ID identities were accepted"
  assert_contains "$(cat "$tmp_dir/identities-$count.out")" \
    "exactly one valid Developer ID Application identity; found $count" 'identity diagnostics'
  if grep -q '^builder|' "$log"; then fail "$count identities reached the builder"; fi
  require_cleanup "identities-$count"
done

for missing in V MENU_DMG_DIR MENU_APP_CERTIFICATE_P12 MENU_APP_CERTIFICATE_PASSWORD \
  MENU_APP_NOTARY_API_KEY MENU_APP_NOTARY_KEY_ID MENU_APP_NOTARY_ISSUER; do
  run_build "missing-$missing" "$missing="
  [[ "$status" -ne 0 ]] || fail "missing $missing was accepted"
  assert_contains "$(cat "$tmp_dir/missing-$missing.out")" "$missing is required" "missing $missing diagnostics"
  [[ ! -s "$log" ]] || fail "missing $missing touched the keychain"
done

run_build bad-version V=1.4
[[ "$status" -ne 0 ]] || fail 'an invalid version was accepted'
[[ ! -s "$log" ]] || fail 'an invalid version touched the keychain'

printf '%s\n' 'Menu-bar DMG release tests passed without certificates or Apple services.'
