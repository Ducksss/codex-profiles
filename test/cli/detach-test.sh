#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT_DIR/test/lib/assertions.sh"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT HUP INT TERM
source "$ROOT_DIR/test/lib/cli-fixtures.sh"
export HOME="$TMP_ROOT/home" CODEX_PROFILE_CONFIG_HOME="$TMP_ROOT/control" CODEX_PROFILE_NO_UPDATE_CHECK=1
mkdir -p "$HOME"

new_pair() {
  local name="$1" entry
  mkdir -p "$HOME/.codex-$name/rules" "$HOME/.codex-$name/plugins/example"
  printf 'model = "example"\n' > "$HOME/.codex-$name/config.toml"
  for entry in AGENTS.md AGENTS.override.md instructions.md custom-instructions.md; do
    printf 'instructions\n' > "$HOME/.codex-$name/$entry"
  done
  printf 'allow\n' > "$HOME/.codex-$name/rules/example.rules"
  printf 'plugin\n' > "$HOME/.codex-$name/plugins/example/plugin.json"
  "$SCRIPT" init "$name-copy" --share-with "$name" > /dev/null
}

assert_pair_linked() {
  local name="$1" entry
  for entry in config.toml AGENTS.md AGENTS.override.md instructions.md custom-instructions.md rules plugins; do
    [[ -L "$HOME/.codex-$name-copy/$entry" ]] || fail "$name lost shared $entry"
    assert_equals 'shared target' "$HOME/.codex-$name/$entry" "$(readlink "$HOME/.codex-$name-copy/$entry")"
  done
}

new_pair source
printf 'source-token\n' > "$HOME/.codex-source/auth.json"
printf 'copy-token\n' > "$HOME/.codex-source-copy/auth.json"
rm "$HOME/.codex-source-copy/instructions.md"
printf 'local instructions\n' > "$HOME/.codex-source-copy/instructions.md"
mkdir "$HOME/.codex-source-copy/sessions"
printf 'session\n' > "$HOME/.codex-source-copy/sessions/example"
run_cmd "$SCRIPT" detach source-copy
assert_status 0
assert_contains 'Detached shared configuration'
for entry in config.toml AGENTS.md AGENTS.override.md instructions.md custom-instructions.md rules plugins; do
  [[ ! -L "$HOME/.codex-source-copy/$entry" ]] || fail "detach kept link: $entry"
  [[ "$entry" != instructions.md ]] || continue
  diff -r "$HOME/.codex-source/$entry" "$HOME/.codex-source-copy/$entry" || fail "detach changed $entry"
done
assert_equals 'private auth' copy-token "$(cat "$HOME/.codex-source-copy/auth.json")"
assert_equals 'source auth' source-token "$(cat "$HOME/.codex-source/auth.json")"
assert_equals 'private session' session "$(cat "$HOME/.codex-source-copy/sessions/example")"
assert_equals 'ordinary config' 'local instructions' "$(cat "$HOME/.codex-source-copy/instructions.md")"
printf 'changed\n' > "$HOME/.codex-source-copy/rules/example.rules"
assert_equals 'source independence' allow "$(cat "$HOME/.codex-source/rules/example.rules")"
run_cmd "$SCRIPT" detach source-copy
assert_status 0
assert_contains 'No shared configuration'
run_cmd "$SCRIPT" remove source --yes
assert_status 0
[[ -f "$HOME/.codex-source-copy/config.toml" ]] || fail 'removing source broke detached config'

# Chains created by init --share-with remain safe and become independent.
new_pair chain
"$SCRIPT" init chain-third --share-with chain-copy > /dev/null
run_cmd "$SCRIPT" detach chain-third
assert_status 0
[[ ! -L "$HOME/.codex-chain-third/config.toml" ]] || fail 'chain not detached'
assert_pair_linked chain

# Preflight all entries before modifying any link, including links to private files.
for kind in broken cycle private nested hardlink fifo cookies; do
  new_pair "$kind"
  case "$kind" in
    broken) rm "$HOME/.codex-$kind/plugins/example/plugin.json"; rmdir "$HOME/.codex-$kind/plugins/example" "$HOME/.codex-$kind/plugins" ;;
    cycle) rm -rf "$HOME/.codex-$kind/plugins"; ln -s "$HOME/.codex-$kind-copy/plugins" "$HOME/.codex-$kind/plugins" ;;
    private)
      printf 'do-not-copy-secret\n' > "$HOME/.codex-$kind/auth.json"
      rm "$HOME/.codex-$kind/config.toml"
      ln -s "$HOME/.codex-$kind/auth.json" "$HOME/.codex-$kind/config.toml"
      ;;
    nested) ln -s "$HOME/.codex-source-copy/auth.json" "$HOME/.codex-$kind/plugins/secret" ;;
    hardlink) ln "$HOME/.codex-source-copy/auth.json" "$HOME/.codex-$kind/plugins/secret" ;;
    fifo) mkfifo "$HOME/.codex-$kind/plugins/pipe" ;;
    cookies) printf 'do-not-copy-cookie\n' > "$HOME/.codex-$kind/plugins/Cookies" ;;
  esac
  run_cmd "$SCRIPT" detach "$kind-copy"
  assert_status 1
  assert_not_contains 'do-not-copy-secret'
  assert_not_contains 'do-not-copy-cookie'
  assert_pair_linked "$kind"
  [[ -z "$(find "$HOME/.codex-$kind-copy" -name '.detach.*' -print)" ]] || fail 'failed preflight left staging data'
done

new_pair failed
mkdir "$TMP_ROOT/bin"
export DETACH_REAL_CP
DETACH_REAL_CP="$(command -v cp)"
cat > "$TMP_ROOT/bin/cp" <<'SHIM'
#!/usr/bin/env bash
case "$2" in
  */AGENTS.md) exit 73 ;;
esac
exec "$DETACH_REAL_CP" "$@"
SHIM
chmod +x "$TMP_ROOT/bin/cp"
run_cmd env PATH="$TMP_ROOT/bin:$PATH" "$SCRIPT" detach failed-copy
assert_status 1
assert_contains 'Cannot copy shared configuration'
assert_pair_linked failed
rm "$TMP_ROOT/bin/cp"

# Failure after one replacement restores every original link, not only the last.
export DETACH_REAL_MV
DETACH_REAL_MV="$(command -v mv)"
cat > "$TMP_ROOT/bin/mv" <<'SHIM'
#!/usr/bin/env bash
case "$1" in
  */copies/AGENTS.md) exit 74 ;;
esac
exec "$DETACH_REAL_MV" "$@"
SHIM
chmod +x "$TMP_ROOT/bin/mv"
run_cmd env PATH="$TMP_ROOT/bin:$PATH" "$SCRIPT" detach failed-copy
assert_status 1
assert_contains 'Cannot replace shared link: AGENTS.md'
assert_pair_linked failed
[[ -z "$(find "$HOME/.codex-failed-copy" -name '.detach.*' -print)" ]] || fail 'rollback left staging data'
[[ ! -d "$CODEX_PROFILE_CONFIG_HOME/mutation.lock" ]] || fail 'detach left mutation lock'

# If restoration itself fails, keep the original link for manual recovery.
cat > "$TMP_ROOT/bin/mv" <<'SHIM'
#!/usr/bin/env bash
case "$1" in
  */copies/AGENTS.md|*/links/AGENTS.md) exit 74 ;;
esac
exec "$DETACH_REAL_MV" "$@"
SHIM
run_cmd env PATH="$TMP_ROOT/bin:$PATH" "$SCRIPT" detach failed-copy
assert_status 1
assert_contains 'original link retained in '
recovery="$(find "$HOME/.codex-failed-copy" -path '*/links/AGENTS.md' -print)"
[[ -L "$recovery" ]] || fail 'failed rollback discarded original link'
assert_equals 'recovery target' "$HOME/.codex-failed/AGENTS.md" "$(readlink "$recovery")"
[[ -L "$HOME/.codex-failed-copy/config.toml" ]] || fail 'failed rollback did not restore other entries'
[[ ! -d "$CODEX_PROFILE_CONFIG_HOME/mutation.lock" ]] || fail 'failed rollback left mutation lock'

run_cmd "$SCRIPT" detach missing
assert_status 1
assert_contains 'not initialized'
run_cmd "$SCRIPT" detach source-copy extra
assert_status 1
assert_contains 'Usage:'
run_cmd "$SCRIPT" detach
assert_status 1
assert_contains 'Usage:'
ln -s "$HOME/.codex-source-copy" "$HOME/.codex-linked"
run_cmd "$SCRIPT" detach linked
assert_status 1
assert_contains 'not initialized'

printf 'detach tests passed\n'
