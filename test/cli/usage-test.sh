#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT_DIR/test/lib/assertions.sh"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT HUP INT TERM
source "$ROOT_DIR/test/lib/cli-fixtures.sh"

FAKE_CODEX="$TMP_ROOT/codex"
FAKE_LOG="$TMP_ROOT/app-server.log"

# Speaks just enough of the app-server stdio protocol. Each profile home
# selects a reply with its fake-mode file so overviews can mix outcomes.
cat > "$FAKE_CODEX" <<'FAKE_CODEX'
#!/usr/bin/env bash
if [[ "${1:-}" == "--version" ]]; then
  printf 'fake-codex 1.0\n'
  exit 0
fi
[[ "${1:-}" == app-server && "$#" -eq 1 ]] || {
  printf 'unexpected arguments: %s\n' "$*" >&2
  exit 64
}
mode=ok
[[ ! -f "$CODEX_HOME/fake-mode" ]] || mode="$(cat "$CODEX_HOME/fake-mode")"
printf '%s|%s|%s|%s|%s|%s\n' "$CODEX_HOME" "$PWD" "$$" "${OPENAI_API_KEY-unset}" \
  "${CODEX_API_KEY-unset}" "${CODEX_ACCESS_TOKEN-unset}" >> "$FAKE_LOG"
now="$(date +%s)"
while IFS= read -r line; do
  case "$line" in
    *'"method":"initialize"'*)
      case "$mode" in
        hang) ;;
        exit-early) exit 0 ;;
        *) printf '{"id":1,"result":{"userAgent":"fake","codexHome":"%s"}}\n' "$CODEX_HOME" ;;
      esac
      ;;
    *'"method":"account/rateLimits/read"'*)
      case "$mode" in
        ok)
          printf '{"method":"remoteControl/status/changed","params":{"id":"x"}}\n'
          printf '{"id":2,"result":{"rateLimits":{"limitId":"codex","primary":{"usedPercent":92,"windowDurationMins":300,"resetsAt":%s},"secondary":{"usedPercent":47.5,"windowDurationMins":10080,"resetsAt":null},"credits":{"balance":"0"}},"accountId":"secret-account","planType":"pro"}}\n' \
            "$((now + 4320))"
          ;;
        by-limit-id)
          printf '{"id":2,"result":{"rateLimits":{"limitId":"other","primary":{"usedPercent":5,"windowDurationMins":60,"resetsAt":null},"secondary":null},"rateLimitsByLimitId":{"other":{"limitId":"other","primary":{"usedPercent":5,"windowDurationMins":60,"resetsAt":null}},"codex":{"limitId":"codex","primary":{"usedPercent":0,"windowDurationMins":43200,"resetsAt":%s},"secondary":null}}}}\n' \
            "$((now + 90000))"
          ;;
        other-only)
          printf '{"id":2,"result":{"rateLimits":{"limitId":"other","primary":{"usedPercent":5,"windowDurationMins":60,"resetsAt":null},"secondary":null}}}\n'
          ;;
        reached)
          printf '{"id":2,"result":{"rateLimits":{"limitId":null,"primary":{"usedPercent":100,"windowDurationMins":300,"resetsAt":%s},"secondary":{"usedPercent":20,"windowDurationMins":10080,"resetsAt":%s}}}}\n' \
            "$((now + 120))" "$((now - 60))"
          ;;
        null-duration)
          printf '{"id":2,"result":{"rateLimits":{"limitId":"codex","primary":{"usedPercent":40,"windowDurationMins":null,"resetsAt":%s},"secondary":null}}}\n' \
            "$((now + 7200))"
          ;;
        signed-out)
          printf '{"error":{"code":-32600,"message":"Codex account authentication required to read rate limits \\"\\u00e9\\""},"id":2}\n'
          ;;
        api-key)
          printf '{"id":2,"error":{"code":-32600,"message":"chatgpt authentication required to read rate limits"}}\n'
          ;;
        expired)
          printf '{"id":2,"error":{"code":-32603,"message":"failed to fetch codex rate limits: GET https://chatgpt.com/backend-api/wham/usage failed: 401 Unauthorized; body={\\n  \\"error\\": {\\"message\\": \\"Could not parse your authentication token. Please try signing in again.\\"}}"}}\n'
          ;;
        refresh-failed)
          printf '{"id":2,"error":{"code":-32603,"message":"Your access token could not be refreshed because your refresh token has expired. Please log out and sign in again."}}\n'
          ;;
        stream)
          # Unrelated replies arrive faster than they can be examined.
          while :; do
            for _ in 1 2 3 4 5 6 7 8 9 10; do printf '{"id":7,"result":{}}\n'; done
            sleep 0.01
          done
          ;;
        server-error)
          printf '{"id":2,"error":{"code":-32603,"message":"internal"}}\n'
          ;;
        garbage)
          printf '{"id":2,"result":{"rateLimits":\n'
          ;;
        split)
          printf '{"id":2,"result":{"rateLimits":{"limitId":"codex","primary":{"usedP'
          sleep 0.3
          printf 'ercent":10,"windowDurationMins":300,"resetsAt":null},"secondary":null}}}\n'
          ;;
      esac
      ;;
  esac
done
FAKE_CODEX
chmod 755 "$FAKE_CODEX"

new_home() {
  local home="$1"
  shift
  rm -rf "$home"
  mkdir -p "$home"
  : > "$FAKE_LOG"
  while [[ "$#" -gt 0 ]]; do
    mkdir -p "$home/$1"
    [[ "$2" == ok ]] || printf '%s' "$2" > "$home/$1/fake-mode"
    shift 2
  done
}

run_usage() {
  local home="$1"
  shift
  run_cmd env HOME="$home" CODEX_CLI="$FAKE_CODEX" FAKE_LOG="$FAKE_LOG" \
    OPENAI_API_KEY=leak CODEX_API_KEY=leak CODEX_ACCESS_TOKEN=leak \
    "$SCRIPT" usage "$@"
}

assert_json() {
  # shellcheck disable=SC2016 # node evaluates the check expression itself
  JSON_PAYLOAD="$output" JSON_CHECK="$1" node -e '
    const value = JSON.parse(process.env.JSON_PAYLOAD);
    if (!new Function("value", `return (${process.env.JSON_CHECK});`)(value)) {
      console.error(JSON.stringify(value));
      process.exit(1);
    }
  ' || fail "usage JSON did not satisfy: $1"
}

test_usage_json_reports_windows_without_account_details() {
  local home="$TMP_ROOT/json"
  new_home "$home" .codex ok

  run_usage "$home" --json default

  assert_status 0
  assert_not_contains 'secret-account'
  assert_not_contains 'planType'
  assert_json 'value.profiles.length === 1'
  assert_json 'value.profiles[0].name === "default" && value.profiles[0].state === "ok"'
  assert_json '!("detail" in value.profiles[0])'
  assert_json 'value.profiles[0].home.endsWith("/.codex")'
  assert_json 'JSON.stringify(value.profiles[0].windows.map(w => [w.duration_mins, w.used_percent, w.remaining_percent])) === "[[300,92,8],[10080,47.5,52]]"'
  assert_json 'typeof value.profiles[0].windows[0].resets_at === "number" && value.profiles[0].windows[1].resets_at === null'
}

test_usage_isolates_the_app_server_environment() {
  local home="$TMP_ROOT/isolation" record

  new_home "$home" .codex-work ok
  run_usage "$home" --json work

  assert_status 0
  record="$(cat "$FAKE_LOG")"
  [[ "$record" == "$home/.codex-work|"* ]] || fail "app-server did not receive the profile CODEX_HOME: $record"
  [[ "$record" == *'|unset|unset|unset' ]] || fail "credential environment leaked into app-server: $record"
  [[ "$record" != *"|$PWD|"* ]] || fail "app-server ran in the caller's directory: $record"
  [[ ! -e "$(cut -d '|' -f 2 <<< "$record")" ]] || fail "private usage directory was not removed"
}

test_usage_human_output_names_windows_levels_and_resets() {
  local home="$TMP_ROOT/human"
  new_home "$home" .codex ok .codex-work reached

  run_usage "$home"

  assert_status 0
  assert_contains 'default:'
  assert_contains '5h limit'
  assert_contains '8% left (critical), resets in 1h 12m at'
  assert_contains '7d limit'
  assert_contains '52% left, reset time unavailable'
  assert_contains 'work:'
  assert_contains '0% left (limit reached), resets in 2m'
  assert_contains 'Awaiting a fresh reading (reset at'
  assert_contains 'ChatGPT may use a different account.'
}

test_usage_prefers_the_codex_limit() {
  local home="$TMP_ROOT/limit-id"
  new_home "$home" .codex-team by-limit-id .codex-other other-only

  run_usage "$home" --json team other

  assert_status 1
  assert_json 'value.profiles[0].state === "ok" && value.profiles[0].windows.length === 1'
  assert_json 'value.profiles[0].windows[0].duration_mins === 43200 && value.profiles[0].windows[0].remaining_percent === 100'
  assert_json 'value.profiles[1].state === "unavailable" && /no usage limits/.test(value.profiles[1].detail)'
}

test_usage_reports_signed_out_profiles() {
  local home="$TMP_ROOT/signed-out"
  new_home "$home" .codex-personal signed-out

  run_usage "$home" --json personal

  assert_status 1
  assert_json 'value.profiles[0].state === "not_logged_in"'
  assert_json 'value.profiles[0].detail === "Not signed in. Run '"'"'codex-profile login personal'"'"'."'
  assert_json 'value.profiles[0].windows.length === 0'

  run_usage "$home" personal
  assert_status 1
  assert_contains "Not signed in. Run 'codex-profile login personal'."
}

test_usage_classifies_sign_in_errors() {
  local home="$TMP_ROOT/sign-in"
  new_home "$home" .codex-expired expired .codex-refresh refresh-failed .codex-key api-key

  run_usage "$home" --json expired refresh key

  assert_status 1
  assert_json 'value.profiles.map(p => p.state).join(",") === "not_logged_in,not_logged_in,unavailable"'
  assert_json 'value.profiles[0].detail === "Sign-in expired or invalid. Run '"'"'codex-profile login expired'"'"'."'
  assert_json 'value.profiles[1].detail === "Sign-in expired or invalid. Run '"'"'codex-profile login refresh'"'"'."'
  assert_json 'value.profiles[2].detail === "Codex quota needs a ChatGPT sign-in; this profile uses an API key."'
  assert_json 'value.profiles.every(p => JSON.stringify(Object.keys(p)) === "[\"name\",\"home\",\"state\",\"detail\",\"windows\"]" && p.windows.length === 0)'

  run_usage "$home" key
  assert_status 1
  assert_contains 'Codex quota needs a ChatGPT sign-in; this profile uses an API key.'
  assert_not_contains 'Not signed in'
}

test_usage_keeps_empty_duration_fields() {
  local home="$TMP_ROOT/null-duration"
  new_home "$home" .codex-work null-duration

  run_usage "$home" --json work

  assert_status 0
  assert_json 'value.profiles[0].windows.length === 1 && value.profiles[0].windows[0].duration_mins === null'
  assert_json 'typeof value.profiles[0].windows[0].resets_at === "number" && value.profiles[0].windows[0].resets_at > 1e9'
  assert_json 'value.profiles[0].windows[0].used_percent === 40 && value.profiles[0].windows[0].remaining_percent === 60'

  run_usage "$home" work
  assert_status 0
  assert_contains 'Limit 1'
  assert_contains '60% left, resets in 2h at'
  assert_not_contains 'reset time unavailable'
}

test_usage_reads_each_named_profile_once() {
  local home="$TMP_ROOT/duplicates"
  new_home "$home" .codex ok

  run_usage "$home" --json default default -- default

  assert_status 0
  assert_json 'value.profiles.length === 1 && value.profiles[0].state === "ok"'
  [[ "$(wc -l < "$FAKE_LOG")" -eq 1 ]] || fail "a repeated profile was read more than once"
}

test_usage_overview_lists_initialized_profiles_and_succeeds() {
  local home="$TMP_ROOT/overview"
  new_home "$home" .codex ok .codex-personal signed-out .codex-team server-error .codex-.bad ok

  run_usage "$home" --json

  assert_status 0
  assert_json 'value.profiles.map(p => p.name).join(",") === "default,personal,team"'
  assert_json 'value.profiles.map(p => p.state).join(",") === "ok,not_logged_in,unavailable"'
  [[ "$(wc -l < "$FAKE_LOG")" -eq 3 ]] || fail "overview did not read each initialized profile once"
}

test_usage_survives_split_replies_and_rejects_malformed_ones() {
  local home="$TMP_ROOT/framing"
  new_home "$home" .codex-split split .codex-garbage garbage

  run_usage "$home" --json split garbage

  assert_status 1
  assert_json 'value.profiles[0].state === "ok" && value.profiles[0].windows[0].remaining_percent === 90'
  assert_json 'value.profiles[1].state === "unavailable"'
}

test_usage_times_out_and_stops_the_server() {
  local home="$TMP_ROOT/timeout" started elapsed pid
  new_home "$home" .codex-slow hang .codex-gone exit-early
  started="$SECONDS"

  run_cmd env HOME="$home" CODEX_CLI="$FAKE_CODEX" FAKE_LOG="$FAKE_LOG" \
    CODEX_PROFILE_USAGE_TIMEOUT=2 "$SCRIPT" usage --json slow gone

  elapsed=$((SECONDS - started))
  assert_status 1
  assert_json 'value.profiles[0].state === "unavailable" && value.profiles[0].detail.startsWith("Timed out after 2s")'
  assert_json 'value.profiles[1].state === "unavailable" && !value.profiles[1].detail.startsWith("Timed out")'
  [[ "$elapsed" -le 6 ]] || fail "usage read outlived its timeout by too much (${elapsed}s)"
  while IFS='|' read -r _ _ pid _; do
    ! kill -0 "$pid" 2> /dev/null || fail "app-server process $pid was left running"
  done < "$FAKE_LOG"
}

test_usage_timeout_holds_during_a_message_stream() {
  local home="$TMP_ROOT/stream" started elapsed
  new_home "$home" .codex-busy stream
  started="$SECONDS"

  run_cmd env HOME="$home" CODEX_CLI="$FAKE_CODEX" FAKE_LOG="$FAKE_LOG" \
    CODEX_PROFILE_USAGE_TIMEOUT=2 "$SCRIPT" usage --json busy

  elapsed=$((SECONDS - started))
  assert_status 1
  assert_json 'value.profiles[0].state === "unavailable" && value.profiles[0].detail.startsWith("Timed out after 2s")'
  [[ "$elapsed" -le 6 ]] || fail "a message stream kept the read past its timeout (${elapsed}s)"
}

test_usage_term_stops_readers_and_removes_temporary_files() {
  local home="$TMP_ROOT/term" tmp="$TMP_ROOT/term-tmp" pid code=0 waited=0 pids
  new_home "$home" .codex-a hang .codex-b hang .codex-c hang .codex-d hang .codex-e hang
  rm -rf "$tmp"
  mkdir -p "$tmp"

  env HOME="$home" CODEX_CLI="$FAKE_CODEX" FAKE_LOG="$FAKE_LOG" TMPDIR="$tmp" \
    CODEX_PROFILE_USAGE_TIMEOUT=60 "$SCRIPT" usage --json a b c d e > "$TMP_ROOT/term.out" 2>&1 &
  pid=$!
  until [[ "$(wc -l < "$FAKE_LOG")" -ge 4 ]]; do
    [[ "$waited" -lt 100 ]] || { kill -KILL "$pid" 2> /dev/null; fail "usage never started its readers"; }
    waited=$((waited + 1))
    sleep 0.1
  done

  kill -TERM "$pid"
  wait "$pid" || code=$?

  [[ "$code" -eq 1 ]] || fail "usage exited $code after SIGTERM instead of 1"
  pids="$(cut -d '|' -f 3 "$FAKE_LOG" | tr '\n' ' ')"
  for pid in $pids; do
    if kill -0 "$pid" 2> /dev/null; then
      kill -KILL "$pid" 2> /dev/null || true
      fail "app-server process $pid outlived usage after SIGTERM"
    fi
  done
  [[ -z "$(ls -A "$tmp")" ]] || fail "temporary usage files remained after SIGTERM: $(ls -A "$tmp")"
}

test_usage_reports_uninitialized_profiles_without_creating_them() {
  local home="$TMP_ROOT/missing"
  new_home "$home"

  run_usage "$home" --json work

  assert_status 1
  assert_json 'value.profiles[0].state === "not_initialized" && value.profiles[0].windows.length === 0'
  [[ ! -e "$home/.codex-work" ]] || fail "usage created a missing profile home"
  [[ ! -s "$FAKE_LOG" ]] || fail "usage started app-server for an uninitialized profile"

  run_usage "$home"
  assert_status 0
  assert_contains 'No initialized profiles.'
}

test_usage_reports_a_missing_codex_cli() {
  local home="$TMP_ROOT/no-cli"
  new_home "$home" .codex-work ok

  run_cmd env HOME="$home" PATH="/usr/bin:/bin" CODEX_CLI="$TMP_ROOT/missing-codex" \
    CHATGPT_APP="$TMP_ROOT/missing.app" "$SCRIPT" usage --json work

  assert_status 1
  assert_json 'value.profiles[0].state === "error" && value.profiles[0].detail.length > 0'

  run_cmd env HOME="$home" PATH="/usr/bin:/bin" CODEX_CLI="$TMP_ROOT/missing-codex" \
    CHATGPT_APP="$TMP_ROOT/missing.app" "$SCRIPT" usage work
  assert_status 1
  assert_contains 'Error:'
}

test_usage_validates_arguments() {
  local home="$TMP_ROOT/arguments"
  new_home "$home" .codex ok

  run_usage "$home" ../work
  assert_status 1
  assert_contains "Invalid profile '../work'"

  run_usage "$home" --watch
  assert_status 1
  assert_contains "Unknown usage option '--watch'."

  run_usage "$home" --json -- default
  assert_status 0
  assert_json 'value.profiles.length === 1 && value.profiles[0].name === "default" && value.profiles[0].state === "ok"'

  run_usage "$home" -- --json
  assert_status 1
  assert_contains "Invalid profile '--json'"

  # Like other commands, help is accepted only straight after the name.
  run_usage "$home" default --help
  assert_status 1
  assert_contains "Unknown usage option '--help'."

  run_cmd env HOME="$home" CODEX_CLI="$FAKE_CODEX" CODEX_PROFILE_USAGE_TIMEOUT=0 "$SCRIPT" usage
  assert_status 1
  assert_contains 'CODEX_PROFILE_USAGE_TIMEOUT must be a whole number'
}

test_usage_json_never_emits_update_notices() {
  local home="$TMP_ROOT/update" cache="$TMP_ROOT/update-check"
  new_home "$home" .codex ok
  printf '%s 9.9.9\n' "$(date +%s)" > "$cache"

  run_cmd env HOME="$home" CODEX_CLI="$FAKE_CODEX" FAKE_LOG="$FAKE_LOG" \
    CODEX_PROFILE_FORCE_UPDATE_CHECK=1 CODEX_PROFILE_UPDATE_CACHE="$cache" \
    "$SCRIPT" usage --json

  assert_status 0
  assert_not_contains 'available'
  [[ "$output" == \{*\} ]] || fail "usage --json was polluted by non-JSON output"
}

test_usage_help_documents_the_command() {
  run_cmd "$SCRIPT" usage --help
  assert_status 0
  assert_contains 'Usage: codex-profile usage [--json] [profile...]'
  assert_contains 'CODEX_PROFILE_USAGE_TIMEOUT'

  run_cmd "$SCRIPT" help
  assert_contains 'usage [--json] [profile...]'
}

test_usage_json_reports_windows_without_account_details
test_usage_isolates_the_app_server_environment
test_usage_human_output_names_windows_levels_and_resets
test_usage_prefers_the_codex_limit
test_usage_reports_signed_out_profiles
test_usage_classifies_sign_in_errors
test_usage_keeps_empty_duration_fields
test_usage_reads_each_named_profile_once
test_usage_overview_lists_initialized_profiles_and_succeeds
test_usage_survives_split_replies_and_rejects_malformed_ones
test_usage_times_out_and_stops_the_server
test_usage_timeout_holds_during_a_message_stream
test_usage_term_stops_readers_and_removes_temporary_files
test_usage_reports_uninitialized_profiles_without_creating_them
test_usage_reports_a_missing_codex_cli
test_usage_validates_arguments
test_usage_json_never_emits_update_notices
test_usage_help_documents_the_command
