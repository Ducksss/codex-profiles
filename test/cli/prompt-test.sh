#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT_DIR/test/lib/assertions.sh"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT HUP INT TERM
source "$ROOT_DIR/test/lib/cli-fixtures.sh"
mkdir -p "$TMP_ROOT/home/.codex-work" "$TMP_ROOT/home/.codex-other" "$TMP_ROOT/home/.codex" "$TMP_ROOT/bin"
ln -s "$SCRIPT" "$TMP_ROOT/bin/codex-profile"

# Exercise the shell's registered hooks, as the shell does before displaying PS1.
# NO_COLOR keeps these exact transcripts to the marker itself; the coloured
# dot that precedes it has its own checks below.
cat > "$TMP_ROOT/check.sh" <<'CHECK'
set -eu
PS1='original> '
if [ "$TEST_SHELL" = bash ]; then
  PROMPT_COMMAND=': existing-hook'
  render() { eval "$PROMPT_COMMAND"; printf '%s\n' "$PS1"; }
else
  precmd_functions=(existing_hook)
  existing_hook() { :; }
  render() { local hook; for hook in "${precmd_functions[@]}"; do "$hook"; done; printf '%s\n' "$PS1"; }
fi
eval "$(codex-profile shell-init "$TEST_SHELL")"
[[ "$PS1" == 'original> ' ]]
if [[ "$TEST_SHELL" == bash ]]; then
  [[ "$PROMPT_COMMAND" == ': existing-hook' ]]
else
  [[ "${precmd_functions[*]}" == existing_hook ]]
fi
eval "$(codex-profile shell-init "$TEST_SHELL" --prompt)"
render
codex-profile use work
render
eval "$(codex-profile shell-init "$TEST_SHELL" --prompt)"
render
codex-profile use other
render
codex-profile use default
render
CODEX_HOME="$HOME/wrong"
render
CODEX_PROFILE_NAME='$(touch "$HOME/injected")'
CODEX_HOME="$HOME/.codex-$CODEX_PROFILE_NAME"
render
unset CODEX_PROFILE_NAME CODEX_HOME
render
CHECK

for shell in bash zsh; do
  if ! command -v "$shell" > /dev/null 2>&1; then
    printf 'SKIP: %s prompt runtime unavailable\n' "$shell"
    continue
  fi
  run_cmd env HOME="$TMP_ROOT/home" PATH="$TMP_ROOT/bin:$PATH" NO_COLOR=1 TEST_SHELL="$shell" "$shell" -f "$TMP_ROOT/check.sh"
  assert_status 0
  assert_equals $'original> \n[codex:work] original> \n[codex:work] original> \n[codex:other] original> \n[codex:default] original> \noriginal> \noriginal> \noriginal> '
  [[ ! -e "$TMP_ROOT/home/injected" ]] || fail 'prompt executed invalid profile text'
done

# Python venv and similar tools save PS1 with the indicator inside, prefix it,
# and later restore the saved copy; no stale indicator may survive.
cat > "$TMP_ROOT/restore.sh" <<'CHECK'
set -eu
PS1='base> '
if [ "$TEST_SHELL" = bash ]; then
  render() { eval "$PROMPT_COMMAND"; printf '%s\n' "$PS1"; }
else
  render() { local hook; for hook in "${precmd_functions[@]}"; do "$hook"; done; printf '%s\n' "$PS1"; }
fi
eval "$(codex-profile shell-init "$TEST_SHELL" --prompt)"
codex-profile use work
render
saved="$PS1"
PS1="(venv) $PS1"
render
codex-profile use other
render
PS1="$saved"
render
unset CODEX_PROFILE_NAME CODEX_HOME
render
PS1='[codex:not a profile] base> '
render
CHECK

for shell in bash zsh; do
  command -v "$shell" > /dev/null 2>&1 || continue
  run_cmd env HOME="$TMP_ROOT/home" PATH="$TMP_ROOT/bin:$PATH" NO_COLOR=1 TEST_SHELL="$shell" "$shell" -f "$TMP_ROOT/restore.sh"
  assert_status 0
  assert_equals $'[codex:work] base> \n[codex:work] (venv) base> \n[codex:other] (venv) base> \n[codex:other] base> \nbase> \n[codex:not a profile] base> '
done

# Bash users may already have multiple prompt hooks; preserve their array.
# shellcheck disable=SC2016 # expanded by the child shell
run_cmd env HOME="$TMP_ROOT/home" PATH="$TMP_ROOT/bin:$PATH" NO_COLOR=1 bash -eu -c '
  PS1="original> "
  PROMPT_COMMAND=("printf first" "PS1=\"original> \"; printf second")
  export PROMPT_COMMAND
  eval "$(codex-profile shell-init bash --prompt)"
  eval "$(codex-profile shell-init bash --prompt)"
  codex-profile use work
  for hook in "${PROMPT_COMMAND[@]}"; do eval "$hook"; done
  printf "%s" "$PS1"
'
assert_status 0
assert_equals 'firstsecond[codex:work] original> '

# A dot in the profile's colour precedes the marker. It follows the profile,
# never stacks, and leaves with the marker.
cat > "$TMP_ROOT/color.sh" <<'CHECK'
set -eu
PS1='base> '
if [ "$TEST_SHELL" = bash ]; then
  render() { eval "$PROMPT_COMMAND"; printf '%s\n' "$PS1"; }
else
  render() { local hook; for hook in "${precmd_functions[@]}"; do "$hook"; done; printf '%s\n' "$PS1"; }
fi
eval "$(codex-profile shell-init "$TEST_SHELL" --prompt)"
codex-profile appearance work --color teal > /dev/null
codex-profile use work
render
render
codex-profile use other
render
unset CODEX_PROFILE_NAME CODEX_HOME
render
CHECK
for shell in bash zsh; do
  command -v "$shell" > /dev/null 2>&1 || continue
  run_cmd env HOME="$TMP_ROOT/home" PATH="$TMP_ROOT/bin:$PATH" TEST_SHELL="$shell" "$shell" -f "$TMP_ROOT/color.sh"
  assert_status 0
  if [[ "$shell" == bash ]]; then
    assert_equals $'\\[\\e[38;5;30m\\]●\\[\\e[39m\\] [codex:work] base> \n\\[\\e[38;5;30m\\]●\\[\\e[39m\\] [codex:work] base> \n\\[\\e[38;5;95m\\]●\\[\\e[39m\\] [codex:other] base> \nbase> '
  else
    assert_equals $'%F{30}●%f [codex:work] base> \n%F{30}●%f [codex:work] base> \n%F{95}●%f [codex:other] base> \nbase> '
  fi
done

if command -v fish > /dev/null 2>&1; then
  cat > "$TMP_ROOT/check.fish" <<'CHECK'
function fish_prompt
    printf 'original:%s> \n' $status
end
set -l original_prompt (functions fish_prompt | string collect)
codex-profile shell-init fish | source
test "$original_prompt" = (functions fish_prompt | string collect); or exit 90
codex-profile shell-init fish --prompt | source
fish_prompt
codex-profile use work
fish_prompt
codex-profile shell-init fish --prompt | source
fish_prompt
codex-profile use other
fish_prompt
codex-profile use default
fish_prompt
set -gx CODEX_HOME "$HOME/wrong"
fish_prompt
set -gx CODEX_PROFILE_NAME '$(touch "$HOME/injected")'
set -gx CODEX_HOME "$HOME/.codex-$CODEX_PROFILE_NAME"
fish_prompt
set -e CODEX_PROFILE_NAME CODEX_HOME
fish_prompt
false
fish_prompt
CHECK
  run_cmd env HOME="$TMP_ROOT/home" PATH="$TMP_ROOT/bin:$PATH" NO_COLOR=1 fish --no-config "$TMP_ROOT/check.fish"
  assert_status 0
  assert_equals $'original:0> \n[codex:work] original:0> \n[codex:work] original:0> \n[codex:other] original:0> \n[codex:default] original:0> \noriginal:0> \noriginal:0> \noriginal:0> \noriginal:1> '
  [[ ! -e "$TMP_ROOT/home/injected" ]] || fail 'fish prompt executed invalid profile text'
  cat > "$TMP_ROOT/pipeline.fish" <<'CHECK'
function fish_prompt
    printf 'status=%s pipeline=%s>\n\n' $status (string join , $pipestatus)
    set -g prompt_called yes
end
codex-profile shell-init fish --prompt | source
codex-profile use work
false | true
fish_prompt
true | false
fish_prompt
printf 'called:%s' $prompt_called
CHECK
  run_cmd env HOME="$TMP_ROOT/home" PATH="$TMP_ROOT/bin:$PATH" NO_COLOR=1 fish --no-config "$TMP_ROOT/pipeline.fish"
  assert_status 0
  assert_equals $'[codex:work] status=0 pipeline=1,0>\n\n[codex:work] status=1 pipeline=0,1>\n\ncalled:yes'
  # shellcheck disable=SC2016 # Evaluated by fish.
  run_cmd env HOME="$TMP_ROOT/home" PATH="$TMP_ROOT/bin:$PATH" fish --no-config -c '
    function fish_prompt; printf "base> \n"; end
    codex-profile shell-init fish --prompt | source
    codex-profile use work
    fish_prompt
    set -gx NO_COLOR 1
    fish_prompt
  '
  assert_status 0
  assert_contains '●'
  assert_contains $'\n[codex:work] base> '
else
  printf 'SKIP: fish prompt runtime unavailable\n'
fi
run_cmd "$SCRIPT" shell-init bash --prompt --prompt
assert_status 1
assert_contains 'Usage:'
run_cmd "$SCRIPT" shell-init bash --unexpected
assert_status 1
assert_contains 'Usage:'
run_cmd "$SCRIPT" shell-init bash --completions --completions
assert_status 1
assert_contains 'Usage:'

for shell in bash zsh fish; do
  if ! command -v "$shell" >/dev/null 2>&1; then
    printf 'SKIP: %s shell integration runtime unavailable\n' "$shell"
    continue
  fi
  if [[ "$shell" == fish ]]; then
    # shellcheck disable=SC2016 # Evaluated by the shell under test.
    run_cmd env HOME="$TMP_ROOT/home" PATH="$TMP_ROOT/bin:$PATH" fish --no-config -c '
      codex-profile shell-init fish --completions --prompt | source
      codex-profile shell-init fish --prompt --completions | source
      codex-profile use work; or exit 1
      test "$CODEX_HOME" = "$HOME/.codex-work"; or exit 1
      complete -C "codex-profile cli wo"
    '
  else
    # shellcheck disable=SC2016 # Evaluated by the shell under test.
    run_cmd env HOME="$TMP_ROOT/home" PATH="$TMP_ROOT/bin:$PATH" TEST_SHELL="$shell" "$shell" -f -c '
      set -eu
      eval "$(codex-profile shell-init "$TEST_SHELL" --completions --prompt)"
      eval "$(codex-profile shell-init "$TEST_SHELL" --prompt --completions)"
      codex-profile use work
      [[ "$CODEX_HOME" == "$HOME/.codex-work" ]]
      if [[ "$TEST_SHELL" == bash ]]; then
        complete -p codex-profile
        COMP_WORDS=(codex-profile cli wo); COMP_CWORD=2
        _codex_profile
        printf "%s\n" "${COMPREPLY[@]}"
      else
        [[ "${_comps[codex-profile]}" == _codex_profile ]]
        print work
      fi
    '
  fi
  assert_status 0
  assert_contains work
done
run_cmd "$SCRIPT" shell-init tcsh --prompt
assert_status 1
assert_contains "Unsupported shell 'tcsh'"
printf 'prompt tests passed\n'
