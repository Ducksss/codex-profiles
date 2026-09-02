#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
INSTALLER="$ROOT_DIR/install.sh"
VERSION="0.10.0"
ORIGINAL_PATH="$PATH"
REAL_LN="$(command -v ln)"
REAL_MV="$(command -v mv)"
REAL_RM="$(command -v rm)"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_success() {
  local label="$1"

  [[ "$status" -eq 0 ]] || fail "$label failed with exit $status: $output"
}

assert_failure() {
  local label="$1"

  [[ "$status" -ne 0 ]] || fail "$label unexpectedly succeeded"
}

path_exists() {
  [[ -e "$1" || -L "$1" ]]
}

assert_path_absent() {
  local path="$1"

  ! path_exists "$path" || fail "unexpected installer path remains: $path"
}

assert_no_transaction_residue() {
  local bindir="$1"
  local residue

  [[ -d "$bindir" ]] || return 0
  residue="$({
    find "$bindir" -mindepth 1 -maxdepth 1 \
      ! -name codex-profile ! -name codex-profiles -print
  } 2>/dev/null)"
  [[ -z "$residue" ]] || fail "installer left transaction residue: $residue"
}

assert_installed() {
  local prefix="$1"
  local fixture="$2"
  local expected_version="$3"
  local canonical="$prefix/bin/codex-profile"
  local alias="$prefix/bin/codex-profiles"

  [[ -f "$canonical" && -x "$canonical" ]] || fail "canonical command is not an executable file"
  [[ -L "$alias" ]] || fail "plural command is not a symlink"
  [[ "$(readlink "$alias")" == "codex-profile" ]] || fail "plural symlink is not relative to codex-profile"
  cmp -s "$fixture" "$canonical" || fail "installed command bytes differ from downloaded fixture"
  "$canonical" version | grep -Fx "codex-profile $expected_version" >/dev/null \
    || fail "canonical command reports the wrong version"
  "$alias" version | grep -Fx "codex-profile $expected_version" >/dev/null \
    || fail "plural command reports the wrong version"
  "$alias" help >/dev/null || fail "plural command could not run help"
  assert_no_transaction_residue "$prefix/bin"
}

write_cli_fixture() {
  local path="$1"
  local declared_version="$2"
  local runtime_version="${3:-$declared_version}"

  cat > "$path" <<EOF
#!/usr/bin/env bash
set -euo pipefail
VERSION="$declared_version"
case "\${1:-help}" in
  version|--version) printf 'codex-profile %s\\n' "$runtime_version" ;;
  help|-h|--help) printf 'fixture help\\n' ;;
  *) exit 64 ;;
esac
EOF
  chmod 755 "$path"
}

prepare_existing_install() {
  local prefix="$1"
  local canonical_content="$2"
  local alias_target="$3"

  mkdir -p "$prefix/bin"
  cp "$canonical_content" "$prefix/bin/codex-profile"
  chmod 755 "$prefix/bin/codex-profile"
  ln -s "$alias_target" "$prefix/bin/codex-profiles"
}

assert_existing_install_unchanged() {
  local prefix="$1"
  local canonical_before="$2"
  local alias_target="$3"

  cmp -s "$canonical_before" "$prefix/bin/codex-profile" \
    || fail "canonical command was not restored byte-for-byte"
  [[ -L "$prefix/bin/codex-profiles" ]] || fail "original plural symlink was not restored"
  [[ "$(readlink "$prefix/bin/codex-profiles")" == "$alias_target" ]] \
    || fail "original plural symlink target was not restored"
  assert_no_transaction_residue "$prefix/bin"
}

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT HUP INT TERM

fixture_dir="$tmp_dir/fixtures"
fake_bin="$tmp_dir/fake-bin"
mkdir -p "$fixture_dir" "$fake_bin" "$tmp_dir/home"

current_fixture="$fixture_dir/codex-profile-$VERSION"
write_cli_fixture "$current_fixture" "$VERSION"
write_cli_fixture "$fixture_dir/codex-profile-0.6.0" "0.6.0"
write_cli_fixture "$fixture_dir/runtime-mismatch" "$VERSION" "9.9.9"

cat > "$fixture_dir/no-version" <<'NO_VERSION'
#!/usr/bin/env bash
case "${1:-help}" in
  version|--version) printf 'codex-profile 0.10.0\n' ;;
  *) printf 'fixture help\n' ;;
esac
NO_VERSION
chmod 755 "$fixture_dir/no-version"

cp "$current_fixture" "$fixture_dir/duplicate-version"
printf 'VERSION="%s"\n' "$VERSION" >> "$fixture_dir/duplicate-version"

cat > "$fake_bin/curl" <<'FAKE_CURL'
#!/bin/sh
set -eu
for argument do
  url="$argument"
done
printf 'curl %s\n' "$url" >> "$INSTALL_TEST_TRANSPORT_LOG"
case "$url" in
  https://api.github.com/repos/Ducksss/codex-profiles/releases/latest)
    printf '{"tag_name":"%s"}\n' "$INSTALL_TEST_LATEST_TAG"
    ;;
  https://raw.githubusercontent.com/Ducksss/codex-profiles/*/bin/codex-profile)
    cat "$INSTALL_TEST_CLI_FIXTURE"
    ;;
  *)
    printf 'unexpected installer URL: %s\n' "$url" >&2
    exit 22
    ;;
esac
FAKE_CURL

cat > "$fake_bin/wget" <<'FAKE_WGET'
#!/bin/sh
set -eu
for argument do
  url="$argument"
done
printf 'wget %s\n' "$url" >> "$INSTALL_TEST_TRANSPORT_LOG"
case "$url" in
  https://api.github.com/repos/Ducksss/codex-profiles/releases/latest)
    printf '{"tag_name":"%s"}\n' "$INSTALL_TEST_LATEST_TAG"
    ;;
  https://raw.githubusercontent.com/Ducksss/codex-profiles/*/bin/codex-profile)
    cat "$INSTALL_TEST_CLI_FIXTURE"
    ;;
  *)
    printf 'unexpected installer URL: %s\n' "$url" >&2
    exit 22
    ;;
esac
FAKE_WGET

cat > "$fake_bin/mv" <<'FAKE_MV'
#!/bin/sh
set -eu
destination=""
for argument do
  destination="$argument"
done
if [ -n "${INSTALL_TEST_FAIL_MV_DEST:-}" ] \
  && [ "${destination##*/}" = "$INSTALL_TEST_FAIL_MV_DEST" ] \
  && [ ! -e "$INSTALL_TEST_FAILURE_MARKER" ]; then
  : > "$INSTALL_TEST_FAILURE_MARKER"
  printf 'forced mv failure for %s\n' "$destination" >&2
  exit 73
fi
"$INSTALL_TEST_REAL_MV" "$@"
if [ -n "${INSTALL_TEST_SIGNAL_AFTER_MV_DEST:-}" ] \
  && [ "${destination##*/}" = "$INSTALL_TEST_SIGNAL_AFTER_MV_DEST" ] \
  && [ ! -e "$INSTALL_TEST_SIGNAL_MARKER" ]; then
  : > "$INSTALL_TEST_SIGNAL_MARKER"
  kill -TERM "$PPID"
  sleep 1
fi
FAKE_MV

cat > "$fake_bin/ln" <<'FAKE_LN'
#!/bin/sh
set -eu
if [ "${INSTALL_TEST_FAIL_LN:-}" = "yes" ] \
  && [ ! -e "$INSTALL_TEST_FAILURE_MARKER" ]; then
  : > "$INSTALL_TEST_FAILURE_MARKER"
  printf 'forced ln failure\n' >&2
  exit 74
fi
exec "$INSTALL_TEST_REAL_LN" "$@"
FAKE_LN

cat > "$fake_bin/rm" <<'FAKE_RM'
#!/bin/sh
set -eu
destination=""
for argument do
  destination="$argument"
done
"$INSTALL_TEST_REAL_RM" "$@"
if [ "${INSTALL_TEST_SIGNAL_AFTER_COMMIT:-}" = "yes" ] \
  && [ ! -e "$INSTALL_TEST_SIGNAL_MARKER" ]; then
  case "$destination" in
    */.codex-profile-install.*)
      : > "$INSTALL_TEST_SIGNAL_MARKER"
      kill -TERM "$PPID"
      sleep 1
      ;;
  esac
fi
FAKE_RM

chmod 755 \
  "$fake_bin/curl" "$fake_bin/wget" "$fake_bin/mv" "$fake_bin/ln" "$fake_bin/rm"

wget_bin="$tmp_dir/forced-wget-bin"
mkdir -p "$wget_bin"
for tool in bash cat chmod grep head mkdir mktemp readlink sed sh; do
  tool_path="$(command -v "$tool")"
  "$REAL_LN" -s "$tool_path" "$wget_bin/$tool"
done
"$REAL_LN" -s "$fake_bin/wget" "$wget_bin/wget"
"$REAL_LN" -s "$fake_bin/mv" "$wget_bin/mv"
"$REAL_LN" -s "$fake_bin/ln" "$wget_bin/ln"
"$REAL_LN" -s "$fake_bin/rm" "$wget_bin/rm"

run_installer() {
  local prefix="$1"
  local fixture="$2"
  local requested_tag="$3"
  local latest_tag="$4"
  local command_path="$5"
  local fail_mv_dest="${6:-}"
  local fail_ln="${7:-no}"
  local case_state="$8"
  local signal_after_mv_dest="${9:-}"
  local signal_after_commit="${10:-no}"

  mkdir -p "$case_state"
  : > "$case_state/transport.log"
  rm -f "$case_state/failure.marker"

  set +e
  output="$(
    PATH="$command_path" \
      HOME="$tmp_dir/home" \
      CODEX_PROFILE_PREFIX="$prefix" \
      CODEX_PROFILE_VERSION="$requested_tag" \
      INSTALL_TEST_CLI_FIXTURE="$fixture" \
      INSTALL_TEST_LATEST_TAG="$latest_tag" \
      INSTALL_TEST_TRANSPORT_LOG="$case_state/transport.log" \
      INSTALL_TEST_FAIL_MV_DEST="$fail_mv_dest" \
      INSTALL_TEST_FAIL_LN="$fail_ln" \
      INSTALL_TEST_FAILURE_MARKER="$case_state/failure.marker" \
      INSTALL_TEST_SIGNAL_AFTER_MV_DEST="$signal_after_mv_dest" \
      INSTALL_TEST_SIGNAL_AFTER_COMMIT="$signal_after_commit" \
      INSTALL_TEST_SIGNAL_MARKER="$case_state/signal.marker" \
      INSTALL_TEST_REAL_MV="$REAL_MV" \
      INSTALL_TEST_REAL_LN="$REAL_LN" \
      INSTALL_TEST_REAL_RM="$REAL_RM" \
      sh "$INSTALLER" 2>&1
  )"
  status=$?
  set -e
}

# Fresh latest-release install through curl.
case_dir="$tmp_dir/case-fresh-curl"
prefix="$case_dir/prefix"
run_installer "$prefix" "$ROOT_DIR/bin/codex-profile" "" "v$VERSION" \
  "$fake_bin:$ORIGINAL_PATH" "" no "$case_dir/state"
assert_success "fresh curl install"
assert_installed "$prefix" "$ROOT_DIR/bin/codex-profile" "$VERSION"
grep -Fx 'curl https://api.github.com/repos/Ducksss/codex-profiles/releases/latest' \
  "$case_dir/state/transport.log" >/dev/null || fail "curl did not query the latest release"
grep -Fx "curl https://raw.githubusercontent.com/Ducksss/codex-profiles/v$VERSION/bin/codex-profile" \
  "$case_dir/state/transport.log" >/dev/null || fail "curl did not download the validated tag"

# Supplied exact tag bypasses latest lookup.
case_dir="$tmp_dir/case-supplied-tag"
prefix="$case_dir/prefix"
run_installer "$prefix" "$current_fixture" "v$VERSION" "invalid-if-read" \
  "$fake_bin:$ORIGINAL_PATH" "" no "$case_dir/state"
assert_success "supplied exact tag install"
assert_installed "$prefix" "$current_fixture" "$VERSION"
[[ "$(wc -l < "$case_dir/state/transport.log" | tr -d ' ')" == "1" ]] \
  || fail "supplied tag unexpectedly queried the latest release"

# An environment without curl must use wget for both lookup and download.
case_dir="$tmp_dir/case-wget"
prefix="$case_dir/prefix"
run_installer "$prefix" "$current_fixture" "" "v$VERSION" \
  "$wget_bin" "" no "$case_dir/state"
assert_success "forced wget install"
assert_installed "$prefix" "$current_fixture" "$VERSION"
[[ "$(grep -c '^wget ' "$case_dir/state/transport.log")" == "2" ]] \
  || fail "forced wget path did not perform both downloads with wget"
! grep -q '^curl ' "$case_dir/state/transport.log" || fail "forced wget path used curl"

# Supplied tags must be exact immutable-looking release tags and fail before I/O.
for malformed_tag in "$VERSION" main "v${VERSION%.*}" "v$VERSION/extra" "v$VERSION-rc1"; do
  safe_name="$(printf '%s' "$malformed_tag" | tr '/.' '__')"
  case_dir="$tmp_dir/case-malformed-$safe_name"
  prefix="$case_dir/prefix"
  run_installer "$prefix" "$current_fixture" "$malformed_tag" "v$VERSION" \
    "$fake_bin:$ORIGINAL_PATH" "" no "$case_dir/state"
  assert_failure "malformed supplied tag $malformed_tag"
  [[ ! -s "$case_dir/state/transport.log" ]] || fail "malformed supplied tag performed network I/O"
  [[ ! -e "$prefix" ]] || fail "malformed supplied tag created the install prefix"
done

# API-derived tags receive the same exact validation before fetching a payload.
case_dir="$tmp_dir/case-malformed-latest"
prefix="$case_dir/prefix"
run_installer "$prefix" "$current_fixture" "" main \
  "$fake_bin:$ORIGINAL_PATH" "" no "$case_dir/state"
assert_failure "malformed latest-release tag"
[[ "$(wc -l < "$case_dir/state/transport.log" | tr -d ' ')" == "1" ]] \
  || fail "malformed latest tag fetched a release payload"
[[ ! -e "$prefix" ]] || fail "malformed latest tag created the install prefix"

# A valid shebang is insufficient: the one static VERSION must match the
# API-derived tag, so latest-release drift fails closed.
case_dir="$tmp_dir/case-wrong-version"
prefix="$case_dir/prefix"
run_installer "$prefix" "$fixture_dir/codex-profile-0.6.0" "" "v$VERSION" \
  "$fake_bin:$ORIGINAL_PATH" "" no "$case_dir/state"
assert_failure "wrong-version shebang-valid payload"
assert_path_absent "$prefix/bin/codex-profile"
assert_path_absent "$prefix/bin/codex-profiles"
assert_no_transaction_residue "$prefix/bin"

for fixture_name in no-version duplicate-version; do
  case_dir="$tmp_dir/case-$fixture_name"
  prefix="$case_dir/prefix"
  run_installer "$prefix" "$fixture_dir/$fixture_name" "v$VERSION" "v$VERSION" \
    "$fake_bin:$ORIGINAL_PATH" "" no "$case_dir/state"
  assert_failure "$fixture_name payload"
  assert_path_absent "$prefix/bin/codex-profile"
  assert_path_absent "$prefix/bin/codex-profiles"
  assert_no_transaction_residue "$prefix/bin"
done

# Runtime postconditions must agree with the statically declared version.
case_dir="$tmp_dir/case-runtime-mismatch"
prefix="$case_dir/prefix"
run_installer "$prefix" "$fixture_dir/runtime-mismatch" "v$VERSION" "v$VERSION" \
  "$fake_bin:$ORIGINAL_PATH" "" no "$case_dir/state"
assert_failure "runtime version mismatch"
assert_path_absent "$prefix/bin/codex-profile"
assert_path_absent "$prefix/bin/codex-profiles"
assert_no_transaction_residue "$prefix/bin"

# A normal update replaces the regular executable and relative symlink cleanly.
case_dir="$tmp_dir/case-update"
prefix="$case_dir/prefix"
prepare_existing_install "$prefix" "$fixture_dir/codex-profile-0.6.0" codex-profile
run_installer "$prefix" "$current_fixture" "v$VERSION" "v$VERSION" \
  "$fake_bin:$ORIGINAL_PATH" "" no "$case_dir/state"
assert_success "existing install update"
assert_installed "$prefix" "$current_fixture" "$VERSION"

# Directory destinations must be rejected, never followed or populated.
case_dir="$tmp_dir/case-canonical-directory"
prefix="$case_dir/prefix"
mkdir -p "$prefix/bin/codex-profile"
run_installer "$prefix" "$current_fixture" "v$VERSION" "v$VERSION" \
  "$fake_bin:$ORIGINAL_PATH" "" no "$case_dir/state"
assert_failure "canonical directory destination"
[[ -d "$prefix/bin/codex-profile" ]] || fail "canonical directory was removed"
[[ -z "$(find "$prefix/bin/codex-profile" -mindepth 1 -print -quit)" ]] \
  || fail "installer wrote inside the canonical directory"
assert_path_absent "$prefix/bin/codex-profiles"
assert_no_transaction_residue "$prefix/bin"

case_dir="$tmp_dir/case-alias-directory"
prefix="$case_dir/prefix"
mkdir -p "$prefix/bin/codex-profiles"
cp "$fixture_dir/codex-profile-0.6.0" "$prefix/bin/codex-profile"
cp "$prefix/bin/codex-profile" "$case_dir/canonical.before"
run_installer "$prefix" "$current_fixture" "v$VERSION" "v$VERSION" \
  "$fake_bin:$ORIGINAL_PATH" "" no "$case_dir/state"
assert_failure "alias directory destination"
cmp -s "$case_dir/canonical.before" "$prefix/bin/codex-profile" \
  || fail "alias directory failure changed the canonical command"
[[ -d "$prefix/bin/codex-profiles" ]] || fail "alias directory was removed"
[[ -z "$(find "$prefix/bin/codex-profiles" -mindepth 1 -print -quit)" ]] \
  || fail "installer wrote inside the alias directory"
assert_no_transaction_residue "$prefix/bin"

# A staging ln failure must leave an existing install byte-identical.
case_dir="$tmp_dir/case-ln-failure"
prefix="$case_dir/prefix"
prepare_existing_install "$prefix" "$fixture_dir/codex-profile-0.6.0" previous-codex
cp "$prefix/bin/codex-profile" "$case_dir/canonical.before"
run_installer "$prefix" "$current_fixture" "v$VERSION" "v$VERSION" \
  "$fake_bin:$ORIGINAL_PATH" "" yes "$case_dir/state"
assert_failure "forced ln failure"
assert_existing_install_unchanged "$prefix" "$case_dir/canonical.before" previous-codex

# A late alias mv failure occurs after canonical replacement and must roll back both paths.
case_dir="$tmp_dir/case-late-mv-failure"
prefix="$case_dir/prefix"
prepare_existing_install "$prefix" "$fixture_dir/codex-profile-0.6.0" previous-codex
cp "$prefix/bin/codex-profile" "$case_dir/canonical.before"
run_installer "$prefix" "$current_fixture" "v$VERSION" "v$VERSION" \
  "$fake_bin:$ORIGINAL_PATH" codex-profiles no "$case_dir/state"
assert_failure "forced late alias mv failure"
assert_existing_install_unchanged "$prefix" "$case_dir/canonical.before" previous-codex

# Signals delivered immediately after each successful rename must observe the
# move that already happened and restore an existing install byte-for-byte.
for signal_destination in \
  original-codex-profile original-codex-profiles codex-profile codex-profiles
do
  case_dir="$tmp_dir/case-signal-existing-$signal_destination"
  prefix="$case_dir/prefix"
  prepare_existing_install "$prefix" "$fixture_dir/codex-profile-0.6.0" previous-codex
  cp "$prefix/bin/codex-profile" "$case_dir/canonical.before"
  run_installer "$prefix" "$current_fixture" "v$VERSION" "v$VERSION" \
    "$fake_bin:$ORIGINAL_PATH" "" no "$case_dir/state" "$signal_destination"
  assert_failure "TERM after $signal_destination move with existing install"
  [[ -e "$case_dir/state/signal.marker" ]] \
    || fail "TERM injection after $signal_destination did not run"
  assert_existing_install_unchanged "$prefix" "$case_dir/canonical.before" previous-codex
done

# Fresh installs have no backup moves, but either install move can still be
# interrupted before the next shell assignment records it.
for signal_destination in codex-profile codex-profiles; do
  case_dir="$tmp_dir/case-signal-fresh-$signal_destination"
  prefix="$case_dir/prefix"
  run_installer "$prefix" "$current_fixture" "v$VERSION" "v$VERSION" \
    "$fake_bin:$ORIGINAL_PATH" "" no "$case_dir/state" "$signal_destination"
  assert_failure "TERM after $signal_destination move with fresh install"
  [[ -e "$case_dir/state/signal.marker" ]] \
    || fail "fresh TERM injection after $signal_destination did not run"
  assert_path_absent "$prefix/bin/codex-profile"
  assert_path_absent "$prefix/bin/codex-profiles"
  assert_no_transaction_residue "$prefix/bin"
done

# Once both installed paths have passed their postconditions and the commit
# marker is set, a signal during transaction cleanup must leave that valid
# committed install in place even though the interrupted process exits nonzero.
case_dir="$tmp_dir/case-signal-after-commit"
prefix="$case_dir/prefix"
prepare_existing_install "$prefix" "$fixture_dir/codex-profile-0.6.0" previous-codex
run_installer "$prefix" "$current_fixture" "v$VERSION" "v$VERSION" \
  "$fake_bin:$ORIGINAL_PATH" "" no "$case_dir/state" "" yes
assert_failure "TERM after commit"
[[ -e "$case_dir/state/signal.marker" ]] || fail "post-commit TERM injection did not run"
assert_installed "$prefix" "$current_fixture" "$VERSION"

printf '%s\n' 'Standalone installer tests passed.'
