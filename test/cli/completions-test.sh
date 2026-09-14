#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT_DIR/test/lib/assertions.sh"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT HUP INT TERM
source "$ROOT_DIR/test/lib/cli-fixtures.sh"
mkdir -p "$TMP_ROOT/home/.codex-client" "$TMP_ROOT/bin" "$TMP_ROOT/project with spaces"
ln -s "$SCRIPT" "$TMP_ROOT/bin/codex-profile"

cat > "$TMP_ROOT/check.sh" <<'CHECK'
set -eu
if [[ "$TEST_SHELL" == bash ]]; then
  source "$COMPLETIONS"
  COMP_WORDS=(codex-profile "$@")
  COMP_CWORD=$((${#COMP_WORDS[@]} - 1))
  _codex_profile
  [[ ${#COMPREPLY[@]} -eq 0 ]] || printf '%s\n' "${COMPREPLY[@]}"
else
  autoload -Uz compinit
  compinit -D
  source "$COMPLETIONS"
  [[ "${_comps[codex-profile]}" == _codex_profile ]]
  _describe() {
    local candidate
    for candidate in "${(@P)2}"; do
      [[ "$candidate" == "$words[CURRENT]"* ]] && print -r -- "$candidate"
    done
    return 0
  }
  _values() { local label="$1"; shift; local -a values=("$@"); _describe "$label" values; }
  _files() { print -r -- 'DIRECTORY COMPLETION'; }
  words=(codex-profile "$@")
  CURRENT=${#words[@]}
  _codex_profile
fi
CHECK

complete_words() {
  if [[ "$shell" == fish ]]; then
    local line='codex-profile' word
    # These test operands have no shell syntax; quote whitespace for fish.
    for word in "$@"; do
      if [[ -z "$word" ]]; then line="$line "; else line="$line '$word'"; fi
    done
    # shellcheck disable=SC2016 # the child fish reads its completion environment
    run_cmd env HOME="$TMP_ROOT/home" PATH="$TMP_ROOT/bin:$PATH" \
      COMPLETIONS="$TMP_ROOT/completions.$shell" COMPLETION_LINE="$line" \
      fish --no-config -c 'source "$COMPLETIONS"; or exit $status; complete -C "$COMPLETION_LINE" | string split -f 1 \t; exit $pipestatus[1]'
  else
    run_cmd env HOME="$TMP_ROOT/home" PATH="$TMP_ROOT/bin:$PATH" \
      COMPLETIONS="$TMP_ROOT/completions.$shell" TEST_SHELL="$shell" \
      "$shell" -f "$TMP_ROOT/check.sh" "$@"
  fi
  assert_status 0
}

for shell in bash zsh fish; do
  if ! command -v "$shell" > /dev/null 2>&1; then
    printf 'SKIP: %s completion runtime unavailable\n' "$shell"
    continue
  fi
  "$SCRIPT" completions "$shell" > "$TMP_ROOT/completions.$shell"
  for command in app app-instance cli login detach remove status path env use logs clone-config; do
    complete_words "$command" ''
    assert_contains client
    assert_not_contains default
    assert_not_contains personal
    assert_not_contains work
  done
  complete_words setup ''
  assert_contains work
  complete_words init ''
  assert_contains work
  complete_words list --d
  assert_contains --details
  complete_words app --h
  assert_equals --help
  complete_words workspace bind --h
  assert_equals --help
  complete_words help ''
  assert_contains app
  assert_contains list
  complete_words help workspace ''
  assert_contains bind
  assert_contains guard
  complete_words init new --share-with ''
  assert_equals client
  complete_words cli client ''
  assert_equals ''
  complete_words cli client status ''
  assert_equals ''
  complete_words login client -- ''
  assert_equals ''
  complete_words login client cli ''
  assert_equals ''
  complete_words run exec -- ''
  assert_equals ''
  complete_words status --j
  assert_contains --json
  complete_words status --json ''
  assert_contains client
  complete_words status -j ''
  assert_contains client
  complete_words status client --j
  assert_contains --json
  complete_words env client --shell ''
  assert_contains bash
  assert_contains zsh
  assert_contains fish
  complete_words env --shell fish ''
  assert_contains client
  complete_words remove client --y
  assert_contains --yes
  complete_words logs client --
  assert_contains --path
  assert_contains --tail
  assert_contains --instance
  complete_words clone-config client client --f
  assert_contains --force
  complete_words clone-config --force client ''
  assert_contains client
  complete_words workspace bind "$TMP_ROOT" ''
  assert_equals client
  complete_words workspace bind "$TMP_ROOT" client --f
  assert_contains --force
  complete_words launcher remove client --y
  assert_contains --yes
  complete_words launcher list --j
  assert_contains --json
  complete_words launcher create client --color ''
  assert_contains graphite
  assert_not_contains client
  complete_words launcher create client --name ''
  assert_equals ''
  complete_words upgrade --
  assert_contains --dry-run
  assert_contains --prefix
  assert_contains --ref
  complete_words upgrade --ref ''
  assert_not_contains --prefix
  complete_words shell-init zsh --prompt --c
  assert_contains --completions
  complete_words shell-init bash --completions --p
  assert_contains --prompt
  complete_words app --instance ''
  assert_contains client
  complete_words app client -- ''
  assert_not_contains --instance
  complete_words app client "$TMP_ROOT/project"
  if [[ "$shell" == zsh ]]; then
    assert_contains 'DIRECTORY COMPLETION'
  else
    assert_contains 'project'
    assert_contains 'spaces'
  fi
  complete_words run --app "$TMP_ROOT/project"
  if [[ "$shell" == zsh ]]; then assert_contains 'DIRECTORY COMPLETION'; else assert_contains 'spaces'; fi
  printf 'PASS: %s completion contexts\n' "$shell"
done

if command -v zsh > /dev/null 2>&1; then
  mkdir -p "$TMP_ROOT/zfunc"
  cp "$TMP_ROOT/completions.zsh" "$TMP_ROOT/zfunc/_codex_profile"
  # shellcheck disable=SC2016 # the child zsh evaluates its completion context
  run_cmd env HOME="$TMP_ROOT/home" PATH="$TMP_ROOT/bin:$PATH" ZFUNC="$TMP_ROOT/zfunc" zsh -f -c '
    fpath=("$ZFUNC" $fpath)
    autoload -Uz _codex_profile
    _describe() { printf "%s\n" "${(@P)2}"; }
    words=(codex-profile app "")
    CURRENT=3
    _codex_profile
  '
  assert_status 0
  assert_equals client
fi

# Candidate arrays cannot prove Readline quoting or directory suffix behavior.
if command -v expect > /dev/null 2>&1; then
  mkdir -p "$TMP_ROOT/workspace/client" "$TMP_ROOT/workspace/project with spaces"
  cat > "$TMP_ROOT/bashrc" <<'CHECK'
PS1='COMPLETION> '
cd "$TEST_WORKSPACE"
source "$COMPLETIONS"
CHECK
  cat > "$TMP_ROOT/readline.exp" <<'CHECK'
set timeout 5
log_user 0
proc await_literal {value} {
    expect {
        -exact $value {}
        timeout { exit 1 }
        eof { exit 1 }
    }
}
spawn bash --noprofile --rcfile $env(TEST_BASHRC) -i
await_literal "COMPLETION> "
send -- "codex-profile app cli\t"
await_literal "codex-profile app client "
send -- "\003"
await_literal "COMPLETION> "
send -- "codex-profile app client pro\t"
await_literal {project\ with\ spaces/}
send -- "\003"
await_literal "COMPLETION> "
send -- "codex-profile app cli\t"
await_literal "codex-profile app client "
send -- "\003"
await_literal "COMPLETION> "
send -- "exit\r"
expect eof
CHECK
  run_cmd env HOME="$TMP_ROOT/home" PATH="$TMP_ROOT/bin:$PATH" INPUTRC=/dev/null \
    BASH_SILENCE_DEPRECATION_WARNING=1 TEST_BASHRC="$TMP_ROOT/bashrc" \
    TEST_WORKSPACE="$TMP_ROOT/workspace" COMPLETIONS="$TMP_ROOT/completions.bash" \
    expect "$TMP_ROOT/readline.exp"
  assert_status 0
  printf 'PASS: Bash Readline quotes directories and preserves profile operands\n'
else
  printf 'SKIP: expect unavailable for Bash Readline integration\n'
fi
