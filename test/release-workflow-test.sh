#!/usr/bin/env bash

# Fixed strings below intentionally assert unevaluated workflow expressions.
# shellcheck disable=SC2016

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKFLOW="$ROOT_DIR/.github/workflows/release.yml"
PAGES_WORKFLOW="$ROOT_DIR/.github/workflows/pages.yml"
MAKEFILE="$ROOT_DIR/Makefile"
WORKFLOW_DIR="$ROOT_DIR/.github/workflows"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT HUP INT TERM

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

uses_count=0
for workflow_file in "$WORKFLOW_DIR"/*.yml "$WORKFLOW_DIR"/*.yaml; do
  [[ -f "$workflow_file" ]] || continue
  while IFS= read -r uses_line; do
    uses_ref="${uses_line#*uses: }"
    if ! [[ "$uses_ref" =~ ^[^[:space:]@]+/[^[:space:]@]+@[0-9a-f]{40}[[:space:]]+#[[:space:]]v[0-9]+$ ]]; then
      fail "workflow action must use a full immutable SHA with a version comment: ${workflow_file#"$ROOT_DIR/"}: $uses_ref"
    fi
    uses_count=$((uses_count + 1))
  done < <(grep -E '^[[:space:]]*uses: ' "$workflow_file" || true)
done
[[ "$uses_count" -gt 0 ]] || fail "no workflow action references were checked"

require_literal() {
  local literal="$1"

  grep -F -- "$literal" "$WORKFLOW" >/dev/null \
    || fail "release workflow is missing: $literal"
}

step_block() {
  local step_name="$1"

  awk -v header="      - name: $step_name" '
    $0 == header {
      found = 1
    }
    found && printed && /^      - name: / {
      exit
    }
    found {
      print
      printed = 1
    }
  ' "$WORKFLOW"
}

step_script() {
  local step_name="$1"

  step_block "$step_name" | awk '
    script {
      sub(/^          /, "")
      print
    }
    /^        run: \|$/ {
      script = 1
    }
  '
}

job_block() {
  local job_name="$1"

  awk -v header="  $job_name:" '
    $0 == header {
      found = 1
    }
    found && printed && /^  [A-Za-z0-9_-]+:$/ {
      exit
    }
    found {
      print
      printed = 1
    }
  ' "$WORKFLOW"
}

require_step_literal() {
  local step_name="$1"
  local literal="$2"
  local block

  block="$(step_block "$step_name")"
  [[ -n "$block" ]] || fail "release workflow is missing step: $step_name"
  grep -F -- "$literal" <<< "$block" >/dev/null \
    || fail "$step_name is missing: $literal"
}

require_live_only_step() {
  local step_name="$1"

  require_step_literal "$step_name" 'if: ${{ ! inputs.dry_run }}'
}

source_validation_step="Validate release source and tracked versions"
source_validation_block="$(step_block "$source_validation_step")"
[[ -n "$source_validation_block" ]] \
  || fail "release workflow is missing step: $source_validation_step"

for literal in \
  '# shellcheck disable=SC2016' \
  "grep -F 'ln -s codex-profile \"\$staged_alias\"' install.sh >/dev/null" \
  "grep -F 'mv \"\$staged_alias\" \"\$alias\"' install.sh >/dev/null" \
  "grep -F 'if [ ! -L \"\$alias\" ] || [ \"\$(readlink \"\$alias\")\" != codex-profile ]; then' install.sh >/dev/null"
do
  grep -F -- "$literal" <<< "$source_validation_block" >/dev/null \
    || fail "$source_validation_step is missing transactional installer precondition: $literal"
done

installer_shellcheck_disable_count="$(
  grep -Fxc '          # shellcheck disable=SC2016' <<< "$source_validation_block" || true
)"
[[ "$installer_shellcheck_disable_count" -eq 3 ]] \
  || fail "$source_validation_step must mark all three literal installer checks as intentional"

if grep -F 'ln -sf codex-profile \"\$BINDIR/codex-profiles\"' \
  <<< "$source_validation_block" >/dev/null; then
  fail "$source_validation_step still requires the removed non-transactional installer alias"
fi

line_number() {
  local literal="$1"
  local line

  line="$(grep -Fn -- "$literal" "$WORKFLOW" | head -n 1 | cut -d: -f1 || true)"
  [[ -n "$line" ]] || fail "release workflow is missing: $literal"
  printf '%s\n' "$line"
}

verify_job="$(job_block verify)"
publish_job="$(job_block publish)"
[[ -n "$verify_job" ]] || fail "release workflow is missing the read-only verify job"
[[ -n "$publish_job" ]] || fail "release workflow is missing the live-only publish job"

workflow_header="$(sed '/^jobs:/q' "$WORKFLOW")"
grep -F 'contents: read' <<< "$workflow_header" >/dev/null \
  || fail "release workflow must default to read-only contents permission"
if grep -Eq '^[[:space:]]+(contents: write|id-token: write|actions: write)' \
  <<< "$workflow_header"; then
  fail "release workflow must not grant top-level write permissions"
fi

for literal in \
  'permissions:' \
  'contents: read' \
  'persist-credentials: false' \
  'outputs:'
do
  grep -F -- "$literal" <<< "$verify_job" >/dev/null \
    || fail "verify job is missing read-only contract: $literal"
done
if grep -Eq '^[[:space:]]+(contents: write|id-token: write|actions: write)' <<< "$verify_job"; then
  fail "verify job must never receive a write-capable token"
fi

for literal in \
  'needs: verify' \
  'if: ${{ ! inputs.dry_run }}' \
  'contents: write' \
  'id-token: write' \
  'actions: write'
do
  grep -F -- "$literal" <<< "$publish_job" >/dev/null \
    || fail "publish job is missing live-only permission contract: $literal"
done

release_timeout="$(
  sed -n 's/^    timeout-minutes: \([0-9][0-9]*\)$/\1/p' <<< "$publish_job" | head -n 1
)"
[[ "$release_timeout" =~ ^[0-9]+$ && "$release_timeout" -ge 30 ]] \
  || fail "release job timeout must accommodate publication and watched Pages deployment"

for literal in \
  desktop_smoke_attestation \
  'ChatGPT version' \
  'bundle ID' \
  'Signed-app smoke attestation is required for a live release' \
  'npm install -g --prefix' \
  'gh release view' \
  'scripts/update-homebrew-formula' \
  'Verify tagged AUR release files'
do
  require_literal "$literal"
done

require_literal 'description: "Live release only: tested ChatGPT version and bundle ID; no account data."'
require_literal 'DESKTOP_SMOKE_ATTESTATION: ${{ inputs.desktop_smoke_attestation }}'
require_literal '[[ "$DRY_RUN" != "true" ]]'
require_literal '[[ "$DESKTOP_SMOKE_ATTESTATION" == *ChatGPT* ]]'
require_literal '[[ "$DESKTOP_SMOKE_ATTESTATION" == *com.openai.* ]]'
require_literal '[[ "$DESKTOP_SMOKE_ATTESTATION" =~ $attestation_pattern ]]'
require_literal 'Signed-app smoke attestation:'
require_literal "| tr '\\r\\n' '  '"
require_literal "sed 's/[[:cntrl:]]//g; s/&/\\&amp;/g; s/</\\&lt;/g; s/>/\\&gt;/g'"

attestation_pattern="$(
  sed -n "s/^[[:space:]]*attestation_pattern='\\(.*\\)'$/\\1/p" "$WORKFLOW"
)"
[[ -n "$attestation_pattern" ]] \
  || fail "release workflow is missing an anchored attestation pattern"

valid_attestation='ChatGPT version 1.2026.168; bundle ID com.openai.codex'
[[ "$valid_attestation" =~ $attestation_pattern ]] \
  || fail "attestation pattern rejected the documented schema"
short_valid_attestation='ChatGPT version 1.2026; bundle ID com.openai.codex'
[[ "$short_valid_attestation" =~ $attestation_pattern ]] \
  || fail "attestation pattern rejected a two-component app version"

invalid_attestations=(
  'ChatGPT version 1; bundle ID com.openai.codex'
  'ChatGPT version 1.2026.168.1; bundle ID com.openai.codex'
  'ChatGPT version 1.2026.168; bundle ID org.example.codex'
  'ChatGPT version 1.2026.168; bundle ID com.openai.codex; account alice@example.com'
  $'ChatGPT version 1.2026.168; bundle ID com.openai.codex\naccount alice@example.com'
  $'ChatGPT version 1.2026.168; bundle ID com.openai.codex\n'
  'prefix ChatGPT version 1.2026.168; bundle ID com.openai.codex'
  'ChatGPT version 1.2026.168; bundle ID com.openai.codex '
)
for invalid_attestation in "${invalid_attestations[@]}"; do
  if [[ "$invalid_attestation" =~ $attestation_pattern ]]; then
    fail "attestation pattern accepted prohibited extra or malformed content"
  fi
done

verification_step="Run full verification"
verification_block="$(step_block "$verification_step")"
[[ -n "$verification_block" ]] || fail "release workflow is missing step: $verification_step"
if grep -F 'if:' <<< "$verification_block" >/dev/null; then
  fail "$verification_step must run for both dry and live releases"
fi

verification_commands=(
  'make test'
  'make lint'
  'bash test/install-script-test.sh'
  'bash test/release-helper-test.sh'
  'bash test/package-metadata-test.sh'
  'make npm-package-test'
  'git diff --exit-code'
  'git diff --cached --exit-code'
  'git status --porcelain=v1 --untracked-files=all'
)
for command in "${verification_commands[@]}"; do
  grep -F -- "$command" <<< "$verification_block" >/dev/null \
    || fail "$verification_step is missing: $command"
done

first_live_line="$(line_number 'if: ${{ ! inputs.dry_run }}')"
verification_line="$(line_number '      - name: Run full verification')"
[[ "$verification_line" -lt "$first_live_line" ]] \
  || fail "dry-run verification must finish before the first live-only step"

live_validation_block="$(step_block "Validate live release source")"
for literal in \
  'VERIFIED_SHA: ${{ needs.verify.outputs.commit }}' \
  'git fetch --no-tags origin main' \
  'git ls-remote --exit-code --tags origin "refs/tags/$TAG"' \
  'git rev-list -n 1 "$TAG"' \
  'tag_exists=' \
  'tag_exists=$tag_exists'
do
  grep -F -- "$literal" <<< "$live_validation_block" >/dev/null \
    || fail "live release source revalidation is missing: $literal"
done

live_validation_line="$(line_number '      - name: Validate live release source')"
credential_validation_line="$(line_number '      - name: Validate release credentials')"
tag_creation_line="$(line_number '      - name: Create and push tag')"
[[ "$live_validation_line" -lt "$credential_validation_line" \
  && "$credential_validation_line" -lt "$tag_creation_line" ]] \
  || fail "live source/tag state must be revalidated immediately before mutation"

credential_validation_block="$(step_block "Validate release credentials")"
for literal in \
  'NPM_TOKEN: ${{ secrets.NPM_TOKEN }}' \
  'TAP_TOKEN: ${{ secrets.TAP_TOKEN }}' \
  '[[ -n "${NPM_TOKEN:-}" ]]' \
  '[[ -n "${TAP_TOKEN:-}" ]]' \
  'NODE_AUTH_TOKEN="$NPM_TOKEN" npm whoami' \
  'NODE_AUTH_TOKEN="$NPM_TOKEN" npm owner ls codex-profile' \
  'GH_TOKEN="$TAP_TOKEN" gh api repos/Ducksss/homebrew-tap' \
  "--jq '.permissions.push'"
do
  grep -F -- "$literal" <<< "$credential_validation_block" >/dev/null \
    || fail "release credential validation is missing: $literal"
done

credential_fake_bin="$tmp_dir/credential-fake-bin"
mkdir -p "$credential_fake_bin"
cat > "$credential_fake_bin/npm" <<'FAKE_NPM'
#!/bin/sh

set -eu

[ "${NODE_AUTH_TOKEN:-}" = "npm-token" ] || exit 65
printf 'npm:%s\n' "$*" >> "$RELEASE_WORKFLOW_TEST_LOG"
case "${1:-}" in
  whoami)
    [ "$FAKE_CREDENTIAL_SCENARIO" != "npm_auth" ] || exit 1
    printf '%s\n' 'release-owner'
    ;;
  owner)
    [ "${2:-}" = "ls" ] || exit 64
    [ "$FAKE_CREDENTIAL_SCENARIO" != "npm_owner" ] \
      && printf '%s\n' 'release-owner <owner@example.invalid>' \
      || printf '%s\n' 'different-owner <other@example.invalid>'
    ;;
  *)
    printf 'unexpected npm invocation: %s\n' "$*" >&2
    exit 64
    ;;
esac
FAKE_NPM

cat > "$credential_fake_bin/gh" <<'FAKE_GH'
#!/bin/sh

set -eu

[ "${GH_TOKEN:-}" = "tap-token" ] || exit 65
printf 'gh:%s\n' "$*" >> "$RELEASE_WORKFLOW_TEST_LOG"
[ "$FAKE_CREDENTIAL_SCENARIO" != "tap_auth" ] || exit 1
if [ "$FAKE_CREDENTIAL_SCENARIO" = "tap_readonly" ]; then
  printf '%s\n' false
else
  printf '%s\n' true
fi
FAKE_GH
chmod 755 "$credential_fake_bin/npm" "$credential_fake_bin/gh"

credential_validation_script="$(step_script "Validate release credentials")"
require_credential_scenario() {
  local scenario="$1"
  local npm_token="$2"
  local tap_token="$3"
  local expected_status="$4"
  local expected_npm_calls="$5"
  local expected_gh_calls="$6"
  local log="$tmp_dir/credential-$scenario.log"
  local status
  local actual

  : > "$log"
  set +e
  PATH="$credential_fake_bin:$PATH" \
    RELEASE_WORKFLOW_TEST_LOG="$log" \
    FAKE_CREDENTIAL_SCENARIO="$scenario" \
    NPM_TOKEN="$npm_token" \
    TAP_TOKEN="$tap_token" \
    bash -c "$credential_validation_script" \
      >"$tmp_dir/credential-$scenario.out" 2>&1
  status=$?
  set -e

  if [[ "$expected_status" == "success" ]]; then
    [[ "$status" -eq 0 ]] || fail "credential $scenario path unexpectedly failed"
  else
    [[ "$status" -ne 0 ]] || fail "credential $scenario path unexpectedly succeeded"
  fi
  actual="$(grep -c '^npm:' "$log" || true)"
  [[ "$actual" -eq "$expected_npm_calls" ]] \
    || fail "credential $scenario made $actual npm call(s); expected $expected_npm_calls"
  actual="$(grep -c '^gh:' "$log" || true)"
  [[ "$actual" -eq "$expected_gh_calls" ]] \
    || fail "credential $scenario made $actual gh call(s); expected $expected_gh_calls"
  for secret_value in "$npm_token" "$tap_token"; do
    [[ -z "$secret_value" ]] && continue
    if grep -F -- "$secret_value" "$tmp_dir/credential-$scenario.out" >/dev/null; then
      fail "credential $scenario leaked a secret value into workflow output"
    fi
  done
}

require_credential_scenario missing_npm '' tap-token failure 0 0
require_credential_scenario missing_tap npm-token '' failure 0 0
require_credential_scenario npm_auth npm-token tap-token failure 1 0
require_credential_scenario npm_owner npm-token tap-token failure 2 0
require_credential_scenario tap_auth npm-token tap-token failure 2 1
require_credential_scenario tap_readonly npm-token tap-token failure 2 1
require_credential_scenario success npm-token tap-token success 2 1

tag_publish_block="$(step_block "Create and push tag")"
for literal in \
  'VERIFIED_SHA: ${{ needs.verify.outputs.commit }}' \
  'tag_published_after_failure=true' \
  'git ls-remote --exit-code --tags origin "refs/tags/$TAG"' \
  'git rev-list -n 1 "$remote_tag_ref"'
do
  grep -F -- "$literal" <<< "$tag_publish_block" >/dev/null \
    || fail "Create and push tag is missing race recovery contract: $literal"
done

tag_fake_bin="$tmp_dir/tag-fake-bin"
mkdir -p "$tag_fake_bin"
cat > "$tag_fake_bin/git" <<'FAKE_GIT'
#!/bin/sh

set -eu

printf '%s:%s\n' "${1:-}" "$*" >> "$RELEASE_WORKFLOW_TEST_LOG"
case "${1:-}" in
  config|tag|update-ref)
    ;;
  push)
    [ "$FAKE_TAG_SCENARIO" = "success" ] && exit 0
    printf '%s\n' 'simulated push failure' >&2
    exit 1
    ;;
  ls-remote)
    [ "$FAKE_TAG_SCENARIO" != "transient" ] || exit 128
    printf '%s\n' 'remote tag exists'
    ;;
  fetch)
    ;;
  rev-list)
    if [ "$FAKE_TAG_SCENARIO" = "race_same" ]; then
      printf '%s\n' "$VERIFIED_SHA"
    else
      printf '%s\n' 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'
    fi
    ;;
  *)
    printf 'unexpected git invocation: %s\n' "$*" >&2
    exit 64
    ;;
esac
FAKE_GIT
chmod 755 "$tag_fake_bin/git"

tag_publish_script="$(step_script "Create and push tag")"
require_tag_publish_scenario() {
  local scenario="$1"
  local tag_exists="$2"
  local expected_status="$3"
  local expected_pushes="$4"
  local expected_lookups="$5"
  local log="$tmp_dir/tag-$scenario.log"
  local status
  local actual

  : > "$log"
  set +e
  PATH="$tag_fake_bin:$PATH" \
    RELEASE_WORKFLOW_TEST_LOG="$log" \
    FAKE_TAG_SCENARIO="$scenario" \
    TAG="v0.7.0" \
    TAG_EXISTS="$tag_exists" \
    VERIFIED_SHA="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" \
    bash -c "$tag_publish_script" >"$tmp_dir/tag-$scenario.out" 2>&1
  status=$?
  set -e

  if [[ "$expected_status" == "success" ]]; then
    [[ "$status" -eq 0 ]] || fail "tag $scenario path unexpectedly failed"
  else
    [[ "$status" -ne 0 ]] || fail "tag $scenario path unexpectedly succeeded"
  fi
  actual="$(grep -c '^push:' "$log" || true)"
  [[ "$actual" -eq "$expected_pushes" ]] \
    || fail "tag $scenario pushed $actual time(s); expected $expected_pushes"
  actual="$(grep -c '^ls-remote:' "$log" || true)"
  [[ "$actual" -eq "$expected_lookups" ]] \
    || fail "tag $scenario rechecked remote $actual time(s); expected $expected_lookups"
}

require_tag_publish_scenario existing true success 0 0
require_tag_publish_scenario success false success 1 0
require_tag_publish_scenario race_same false success 1 1
require_tag_publish_scenario race_different false failure 1 1
require_tag_publish_scenario transient false failure 1 1

publish_line="$(line_number 'npm publish "$tarball" --provenance --access public')"
npm_verify_line="$(line_number '      - name: Verify published npm package')"
[[ "$publish_line" -lt "$npm_verify_line" ]] \
  || fail "npm verification must run after npm publication"

release_create_line="$(line_number 'gh release create "$TAG"')"
release_verify_line="$(line_number '      - name: Verify GitHub Release')"
[[ "$release_create_line" -lt "$release_verify_line" ]] \
  || fail "GitHub Release verification must run after release creation"
require_step_literal "Verify GitHub Release" 'gh release view "$TAG"'

npm_verification_block="$(step_block "Verify published npm package")"
for literal in \
  'for attempt in {1..10}; do' \
  'if npm install -g --prefix' \
  'npm_installed=true' \
  'sleep "$((attempt * 2))"' \
  '[[ "$npm_installed" == "true" ]]'
do
  grep -F -- "$literal" <<< "$npm_verification_block" >/dev/null \
    || fail "Verify published npm package is missing retry contract: $literal"
done

npm_publish_block="$(step_block "Publish to npm")"
for literal in \
  'npm pack --json --pack-destination "$tmp"' \
  'local_integrity' \
  'for attempt in {1..5}; do' \
  'npm view codex-profile versions --json' \
  'npm view "codex-profile@$V" dist.integrity --json' \
  'versions.includes(version)' \
  'registryIntegrity !== expectedIntegrity' \
  'npm_lookup_succeeded=true' \
  '[[ "$npm_lookup_succeeded" == "true" ]]' \
  'npm_artifact_verified_after_publish=true' \
  'npm publish "$tarball" --provenance --access public'
do
  grep -F -- "$literal" <<< "$npm_publish_block" >/dev/null \
    || fail "Publish to npm is missing fail-closed lookup contract: $literal"
done

npm_fake_bin="$tmp_dir/npm-fake-bin"
mkdir -p "$npm_fake_bin"
cat > "$npm_fake_bin/npm" <<'FAKE_NPM'
#!/bin/sh

set -eu

local_integrity='sha512-dGVzdC1jb2RleC1wcm9maWxl'

case "${1:-}" in
  pack)
    printf '%s\n' 'pack' >> "$RELEASE_WORKFLOW_TEST_LOG"
    shift
    destination=''
    while [ "$#" -gt 0 ]; do
      if [ "$1" = '--pack-destination' ]; then
        destination="$2"
        shift 2
      else
        shift
      fi
    done
    [ -n "$destination" ]
    tarball="$destination/codex-profile-0.7.0.tgz"
    printf '%s\n' 'fixture tarball' > "$tarball"
    printf '[{"name":"codex-profile","version":"0.7.0","filename":"codex-profile-0.7.0.tgz","integrity":"%s"}]\n' \
      "$local_integrity"
    ;;
  view)
    if [ "${2:-}" = 'codex-profile' ] && [ "${3:-}" = 'versions' ]; then
      printf '%s\n' 'view:versions' >> "$RELEASE_WORKFLOW_TEST_LOG"
      case "$FAKE_NPM_SCENARIO" in
        present|mismatch|malformed_integrity)
          printf '%s\n' '["0.6.0", "0.7.0"]'
          ;;
        absent|race)
          if grep -Fqx 'publish' "$RELEASE_WORKFLOW_TEST_LOG"; then
            printf '%s\n' '["0.6.0", "0.7.0"]'
          else
            printf '%s\n' '["0.6.0"]'
          fi
          ;;
        malformed_versions)
          printf '%s\n' '{"unexpected":true}'
          ;;
        transient)
          printf '%s\n' 'npm error code E503' >&2
          exit 1
          ;;
        *) exit 64 ;;
      esac
    elif [ "${2:-}" = 'codex-profile@0.7.0' ] && [ "${3:-}" = 'dist.integrity' ]; then
      printf '%s\n' 'view:integrity' >> "$RELEASE_WORKFLOW_TEST_LOG"
      case "$FAKE_NPM_SCENARIO" in
        present|absent|race)
          printf '"%s"\n' "$local_integrity"
          ;;
        mismatch)
          printf '%s\n' '"sha512-ZGlmZmVyZW50LWFydGlmYWN0"'
          ;;
        malformed_integrity)
          printf '%s\n' '{"unexpected":true}'
          ;;
        *) exit 64 ;;
      esac
    else
      printf 'unexpected npm view invocation: %s\n' "$*" >&2
      exit 64
    fi
    ;;
  publish)
    printf '%s\n' 'publish' >> "$RELEASE_WORKFLOW_TEST_LOG"
    [ -f "${2:-}" ] || {
      printf 'publish did not receive the packed tarball: %s\n' "${2:-}" >&2
      exit 65
    }
    case "$FAKE_NPM_SCENARIO" in
      race) exit 1 ;;
      absent) ;;
      *) exit 64 ;;
    esac
    ;;
  *)
    printf 'unexpected npm invocation: %s\n' "$*" >&2
    exit 64
    ;;
esac
FAKE_NPM

cat > "$npm_fake_bin/sleep" <<'FAKE_SLEEP'
#!/bin/sh

printf '%s\n' 'sleep' >> "$RELEASE_WORKFLOW_TEST_LOG"
FAKE_SLEEP
chmod 755 "$npm_fake_bin/npm" "$npm_fake_bin/sleep"

npm_publish_script="$(step_script "Publish to npm")"
require_npm_publish_scenario() {
  local scenario="$1"
  local expected_status="$2"
  local expected_packs="$3"
  local expected_version_views="$4"
  local expected_integrity_views="$5"
  local expected_publishes="$6"
  local expected_sleeps="$7"
  local log="$tmp_dir/npm-$scenario.log"
  local status
  local actual

  : > "$log"
  set +e
  PATH="$npm_fake_bin:$PATH" \
    RELEASE_WORKFLOW_TEST_LOG="$log" \
    FAKE_NPM_SCENARIO="$scenario" \
    V="0.7.0" \
    bash -c "$npm_publish_script" >"$tmp_dir/npm-$scenario.out" 2>&1
  status=$?
  set -e

  if [[ "$expected_status" == "success" ]]; then
    [[ "$status" -eq 0 ]] || fail "npm $scenario lookup unexpectedly failed"
  else
    [[ "$status" -ne 0 ]] || fail "npm $scenario lookup unexpectedly succeeded"
  fi

  actual="$(grep -Fxc 'pack' "$log" || true)"
  [[ "$actual" -eq "$expected_packs" ]] \
    || fail "npm $scenario packed $actual time(s); expected $expected_packs"
  actual="$(grep -Fxc 'view:versions' "$log" || true)"
  [[ "$actual" -eq "$expected_version_views" ]] \
    || fail "npm $scenario version lookup ran $actual time(s); expected $expected_version_views"
  actual="$(grep -Fxc 'view:integrity' "$log" || true)"
  [[ "$actual" -eq "$expected_integrity_views" ]] \
    || fail "npm $scenario integrity lookup ran $actual time(s); expected $expected_integrity_views"
  actual="$(grep -Fxc 'publish' "$log" || true)"
  [[ "$actual" -eq "$expected_publishes" ]] \
    || fail "npm $scenario published $actual time(s); expected $expected_publishes"
  actual="$(grep -Fxc 'sleep' "$log" || true)"
  [[ "$actual" -eq "$expected_sleeps" ]] \
    || fail "npm $scenario backoff ran $actual time(s); expected $expected_sleeps"
}

require_npm_publish_scenario present success 1 1 1 0 0
require_npm_publish_scenario absent success 1 2 1 1 0
require_npm_publish_scenario race success 1 2 1 1 0
require_npm_publish_scenario transient failure 1 5 0 0 4
require_npm_publish_scenario malformed_versions failure 1 5 0 0 4
require_npm_publish_scenario malformed_integrity failure 1 5 5 0 4
require_npm_publish_scenario mismatch failure 1 5 5 0 4

github_release_block="$(step_block "Create GitHub Release")"
for literal in \
  'for attempt in {1..5}; do' \
  'gh api --paginate' \
  'releases?per_page=100' \
  "--jq '.[] | @json'" \
  'release.draft !== false' \
  'release.prerelease !== false' \
  "typeof release.published_at !== 'string'" \
  'release_lookup_succeeded=true' \
  '[[ "$release_lookup_succeeded" == "true" ]]' \
  'gh release create "$TAG"' \
  'release_verified_after_create=true'
do
  grep -F -- "$literal" <<< "$github_release_block" >/dev/null \
    || fail "Create GitHub Release is missing fail-closed lookup contract: $literal"
done

release_fake_bin="$tmp_dir/release-fake-bin"
mkdir -p "$release_fake_bin"
cat > "$release_fake_bin/gh" <<'FAKE_GH_RELEASE'
#!/bin/sh

set -eu

command="${1:-}:${2:-}"
case "$command" in
  api:--paginate)
    printf '%s\n' 'lookup' >> "$RELEASE_WORKFLOW_TEST_LOG"
    lookup_count="$(grep -Fxc 'lookup' "$RELEASE_WORKFLOW_TEST_LOG")"
    case "$FAKE_GH_RELEASE_SCENARIO" in
      present)
        printf '%s\n' \
          '{"tag_name":"v0.7.0","draft":false,"prerelease":false,"published_at":"2026-07-12T00:00:00Z"}'
        ;;
      absent)
        if grep -Fqx 'create' "$RELEASE_WORKFLOW_TEST_LOG"; then
          printf '%s\n' \
            '{"tag_name":"v0.7.0","draft":false,"prerelease":false,"published_at":"2026-07-12T00:00:00Z"}'
        else
          printf '%s\n' \
            '{"tag_name":"v0.6.0","draft":false,"prerelease":false,"published_at":"2026-07-01T00:00:00Z"}'
        fi
        ;;
      race)
        if grep -Fqx 'create' "$RELEASE_WORKFLOW_TEST_LOG" \
          && [ "$lookup_count" -ge 4 ]; then
          printf '%s\n' \
            '{"tag_name":"v0.7.0","draft":false,"prerelease":false,"published_at":"2026-07-12T00:00:00Z"}'
        else
          printf '%s\n' \
            '{"tag_name":"v0.6.0","draft":false,"prerelease":false,"published_at":"2026-07-01T00:00:00Z"}'
        fi
        ;;
      draft)
        printf '%s\n' \
          '{"tag_name":"v0.7.0","draft":true,"prerelease":false,"published_at":null}'
        ;;
      prerelease)
        printf '%s\n' \
          '{"tag_name":"v0.7.0","draft":false,"prerelease":true,"published_at":"2026-07-12T00:00:00Z"}'
        ;;
      unpublished)
        printf '%s\n' \
          '{"tag_name":"v0.7.0","draft":false,"prerelease":false,"published_at":null}'
        ;;
      transient)
        printf '%s\n' 'HTTP 503: service unavailable' >&2
        exit 1
        ;;
      *) exit 64 ;;
    esac
    ;;
  release:create)
    printf '%s\n' 'create' >> "$RELEASE_WORKFLOW_TEST_LOG"
    case "$FAKE_GH_RELEASE_SCENARIO" in
      absent) ;;
      race) exit 1 ;;
      *) exit 64 ;;
    esac
    ;;
  release:view)
    printf '%s\n' 'view' >> "$RELEASE_WORKFLOW_TEST_LOG"
    case "$FAKE_GH_RELEASE_SCENARIO" in
      present)
        printf '%s\n' \
          '{"tagName":"v0.7.0","isDraft":false,"isPrerelease":false,"publishedAt":"2026-07-12T00:00:00Z"}'
        ;;
      draft)
        printf '%s\n' \
          '{"tagName":"v0.7.0","isDraft":true,"isPrerelease":false,"publishedAt":null}'
        ;;
      prerelease)
        printf '%s\n' \
          '{"tagName":"v0.7.0","isDraft":false,"isPrerelease":true,"publishedAt":"2026-07-12T00:00:00Z"}'
        ;;
      unpublished)
        printf '%s\n' \
          '{"tagName":"v0.7.0","isDraft":false,"isPrerelease":false,"publishedAt":null}'
        ;;
      wrong_tag)
        printf '%s\n' \
          '{"tagName":"v0.6.0","isDraft":false,"isPrerelease":false,"publishedAt":"2026-07-01T00:00:00Z"}'
        ;;
      *) exit 64 ;;
    esac
    ;;
  *)
    printf 'unexpected gh invocation: %s\n' "$*" >&2
    exit 64
    ;;
esac
FAKE_GH_RELEASE

cat > "$release_fake_bin/sleep" <<'FAKE_SLEEP'
#!/bin/sh

printf '%s\n' 'sleep' >> "$RELEASE_WORKFLOW_TEST_LOG"
FAKE_SLEEP
chmod 755 "$release_fake_bin/gh" "$release_fake_bin/sleep"

github_release_script="$(step_script "Create GitHub Release")"
require_github_release_scenario() {
  local scenario="$1"
  local expected_status="$2"
  local expected_lookups="$3"
  local expected_creates="$4"
  local expected_sleeps="$5"
  local log="$tmp_dir/release-$scenario.log"
  local status
  local actual

  : > "$log"
  set +e
  PATH="$release_fake_bin:$PATH" \
    RELEASE_WORKFLOW_TEST_LOG="$log" \
    FAKE_GH_RELEASE_SCENARIO="$scenario" \
    GITHUB_REPOSITORY="Ducksss/codex-profiles" \
    TAG="v0.7.0" \
    bash -c "$github_release_script" >"$tmp_dir/release-$scenario.out" 2>&1
  status=$?
  set -e

  if [[ "$expected_status" == "success" ]]; then
    [[ "$status" -eq 0 ]] || fail "GitHub Release $scenario lookup unexpectedly failed"
  else
    [[ "$status" -ne 0 ]] || fail "GitHub Release $scenario lookup unexpectedly succeeded"
  fi

  actual="$(grep -Fxc 'lookup' "$log" || true)"
  [[ "$actual" -eq "$expected_lookups" ]] \
    || fail "GitHub Release $scenario lookup ran $actual time(s); expected $expected_lookups"
  actual="$(grep -Fxc 'create' "$log" || true)"
  [[ "$actual" -eq "$expected_creates" ]] \
    || fail "GitHub Release $scenario create ran $actual time(s); expected $expected_creates"
  actual="$(grep -Fxc 'sleep' "$log" || true)"
  [[ "$actual" -eq "$expected_sleeps" ]] \
    || fail "GitHub Release $scenario backoff ran $actual time(s); expected $expected_sleeps"
}

require_github_release_scenario present success 1 0 0
require_github_release_scenario absent success 2 1 0
require_github_release_scenario race success 4 1 2
require_github_release_scenario transient failure 5 0 4
require_github_release_scenario draft failure 5 0 4
require_github_release_scenario prerelease failure 5 0 4
require_github_release_scenario unpublished failure 5 0 4

github_release_verify_block="$(step_block "Verify GitHub Release")"
for literal in \
  '--json tagName,isDraft,isPrerelease,publishedAt' \
  'release.tagName !== expectedTag' \
  'release.isDraft !== false' \
  'release.isPrerelease !== false' \
  "typeof release.publishedAt !== 'string'"
do
  grep -F -- "$literal" <<< "$github_release_verify_block" >/dev/null \
    || fail "Verify GitHub Release is missing public-final contract: $literal"
done

github_release_verify_script="$(step_script "Verify GitHub Release")"
require_github_release_final_scenario() {
  local scenario="$1"
  local expected_status="$2"
  local log="$tmp_dir/release-final-$scenario.log"
  local status

  : > "$log"
  set +e
  PATH="$release_fake_bin:$PATH" \
    RELEASE_WORKFLOW_TEST_LOG="$log" \
    FAKE_GH_RELEASE_SCENARIO="$scenario" \
    TAG="v0.7.0" \
    bash -c "$github_release_verify_script" \
      >"$tmp_dir/release-final-$scenario.out" 2>&1
  status=$?
  set -e

  if [[ "$expected_status" == "success" ]]; then
    [[ "$status" -eq 0 ]] || fail "GitHub Release final $scenario verification unexpectedly failed"
  else
    [[ "$status" -ne 0 ]] || fail "GitHub Release final $scenario verification unexpectedly succeeded"
  fi
}

require_github_release_final_scenario present success
require_github_release_final_scenario draft failure
require_github_release_final_scenario prerelease failure
require_github_release_final_scenario unpublished failure
require_github_release_final_scenario wrong_tag failure

for step_name in \
  'Validate release credentials' \
  'Create and push tag' \
  'Verify tagged AUR release files' \
  'Publish to npm' \
  'Verify published npm package' \
  'Create GitHub Release' \
  'Verify GitHub Release' \
  'Update Homebrew tap' \
  'Deploy and verify release documentation'
do
  require_live_only_step "$step_name"
done

require_literal 'gh workflow run pages.yml --repo "$GITHUB_REPOSITORY" --ref "$TAG"'
require_literal 'for _attempt in {1..30}; do'
require_literal 'gh run list --repo "$GITHUB_REPOSITORY" --workflow pages.yml'
require_literal '--commit "$GITHUB_SHA" --event workflow_dispatch --limit 20'
require_literal 'gh run watch "$run_id" --repo "$GITHUB_REPOSITORY" --exit-status'
require_literal 'https://ducksss.github.io/codex-profiles/'
require_literal '<span>v$V</span>'

pages_block="$(step_block "Deploy and verify release documentation")"
for literal in \
  'pages_correlation="release-$GITHUB_RUN_ID-$GITHUB_RUN_ATTEMPT"' \
  'pages_run_title="Deploy Pages from $TAG ($pages_correlation)"' \
  '-f release_correlation="$pages_correlation"' \
  '--json databaseId,displayTitle' \
  'select(.displayTitle == \"$pages_run_title\")'
do
  grep -F -- "$literal" <<< "$pages_block" >/dev/null \
    || fail "Pages verification is missing exact correlation contract: $literal"
done

correlation_line="$(grep -Fn 'pages_correlation=' <<< "$pages_block" | cut -d: -f1)"
dispatch_line="$(grep -Fn 'gh workflow run pages.yml' <<< "$pages_block" | cut -d: -f1)"
[[ "$correlation_line" -lt "$dispatch_line" ]] \
  || fail "Pages verification must define its unique correlation before dispatch"

for literal in \
  'release_correlation:' \
  '${{ inputs.release_correlation' \
  'type: string'
do
  grep -F -- "$literal" "$PAGES_WORKFLOW" >/dev/null \
    || fail "Pages workflow is missing release correlation contract: $literal"
done

fake_bin="$tmp_dir/fake-bin"
tool_log="$tmp_dir/tool.log"
mkdir -p "$fake_bin"

cat > "$fake_bin/gh" <<'FAKE_GH'
#!/bin/sh

set -eu

command="${1:-}:${2:-}"
case "$command" in
  workflow:run)
    printf 'workflow:%s\n' "$*" >> "$RELEASE_WORKFLOW_TEST_LOG"
    ;;
  run:list)
    printf 'list:%s\n' "$*" >> "$RELEASE_WORKFLOW_TEST_LOG"
    case "$*" in
      *release-42-3*) printf '%s\n' '333' ;;
      *) printf '%s\n' '222' ;;
    esac
    ;;
  run:watch)
    printf 'watch:%s\n' "${3:-}" >> "$RELEASE_WORKFLOW_TEST_LOG"
    ;;
  *)
    printf 'unexpected gh invocation: %s\n' "$*" >&2
    exit 64
    ;;
esac
FAKE_GH

cat > "$fake_bin/curl" <<'FAKE_CURL'
#!/bin/sh

printf '%s\n' '<span>v0.7.0</span>'
FAKE_CURL

cat > "$fake_bin/sleep" <<'FAKE_SLEEP'
#!/bin/sh

exit 0
FAKE_SLEEP
chmod 755 "$fake_bin/gh" "$fake_bin/curl" "$fake_bin/sleep"

PATH="$fake_bin:$PATH" \
  RELEASE_WORKFLOW_TEST_LOG="$tool_log" \
  GITHUB_REPOSITORY="Ducksss/codex-profiles" \
  GITHUB_SHA="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" \
  GITHUB_RUN_ID="42" \
  GITHUB_RUN_ATTEMPT="3" \
  TAG="v0.7.0" \
  V="0.7.0" \
  bash -c "$(step_script "Deploy and verify release documentation")" >/dev/null

grep -Fx \
  'workflow:workflow run pages.yml --repo Ducksss/codex-profiles --ref v0.7.0 -f release_correlation=release-42-3' \
  "$tool_log" >/dev/null \
  || fail "Pages dispatch did not pass its unique release correlation"
grep -Fx 'watch:333' "$tool_log" >/dev/null \
  || fail "Pages verification did not select the exactly correlated run"
if grep -Eq '^watch:(111|222)$' "$tool_log"; then
  fail "Pages verification selected a pre-existing or racing same-commit run"
fi

poll_count="$(grep -Fxc '          for _attempt in {1..30}; do' "$WORKFLOW" || true)"
[[ "$poll_count" -eq 2 ]] \
  || fail "release workflow must bound both Pages run and deployed-version polling"

shell_steps=(
  'Validate release source and tracked versions'
  'Run full verification'
  'Verification summary'
  'Validate live release source'
  'Validate release credentials'
  'Create and push tag'
  'Verify tagged AUR release files'
  'Publish to npm'
  'Verify published npm package'
  'Create GitHub Release'
  'Verify GitHub Release'
  'Update Homebrew tap'
  'Deploy and verify release documentation'
  'Release summary'
)
for step_name in "${shell_steps[@]}"; do
  script="$(step_script "$step_name")"
  [[ -n "$script" ]] || fail "release workflow step has no block script: $step_name"
  bash -n <<< "$script" \
    || fail "release workflow step has invalid Bash syntax: $step_name"
done

for test_file in test/install-script-test.sh test/release-workflow-test.sh; do
  awk -v test_file="$test_file" '
    index($0, "\tshellcheck ") == 1 && index($0, test_file) > 0 { found = 1 }
    END { exit(found ? 0 : 1) }
  ' "$MAKEFILE" \
    || fail "Makefile lint does not cover $test_file"
  grep -Fx $'\t'bash' -n '"$test_file" "$MAKEFILE" >/dev/null \
    || fail "Makefile test does not syntax-check $test_file"
  grep -Fx $'\t'bash' '"$test_file" "$MAKEFILE" >/dev/null \
    || fail "Makefile test does not execute $test_file"
done

printf '%s\n' 'Release workflow contract tests passed.'
