#!/usr/bin/env bash

# shellcheck disable=SC2034 # globals are consumed by suites that source this file.

[[ -n "${ROOT_DIR:-}" ]] || {
  printf '%s\n' 'FAIL: ROOT_DIR must be set before sourcing cli-fixtures.sh' >&2
  exit 1
}
[[ -n "${TMP_ROOT:-}" ]] || {
  printf '%s\n' 'FAIL: TMP_ROOT must be set before sourcing cli-fixtures.sh' >&2
  exit 1
}

SCRIPT="$ROOT_DIR/bin/codex-profile"
output=""
status=0

run_cmd() {
  set +e
  output="$("$@" 2>&1)"
  status=$?
  set -e
}

run_cmd_with_input() {
  local input="$1"
  shift

  set +e
  output="$(printf '%b' "$input" | "$@" 2>&1)"
  status=$?
  set -e
}

mode_of() {
  if stat -f '%Lp' "$1" > /dev/null 2>&1; then
    stat -f '%Lp' "$1"
  else
    stat -c '%a' "$1"
  fi
}

write_fake_codex() {
  local path="$1"

  cat > "$path" <<'FAKE_CODEX'
#!/usr/bin/env bash

if [[ "${1:-}" == "--version" ]]; then
  printf 'fake-codex 1.0\n'
  exit 0
fi

if [[ ! -d "${CODEX_HOME:-}" ]]; then
  printf 'CODEX_HOME missing: %s\n' "${CODEX_HOME:-}" >&2
  exit 42
fi

printf '%s\n' "$*"
FAKE_CODEX
  chmod 755 "$path"
}

write_fake_upgrade_repo() {
  local repo="$1"
  local version="$2"

  mkdir -p "$repo/bin"

  cat > "$repo/bin/codex-profile" <<FAKE_PROFILE
#!/usr/bin/env bash
VERSION="$version"
if [[ "\${1:-}" == "version" || "\${1:-}" == "--version" ]]; then
  printf 'codex-profile %s\n' "\$VERSION"
  exit 0
fi
printf 'fake codex-profile %s\n' "\$VERSION"
FAKE_PROFILE
  chmod 755 "$repo/bin/codex-profile"

  cat > "$repo/Makefile" <<'FAKE_MAKEFILE'
PREFIX ?= $(HOME)/.local
BINDIR ?= $(PREFIX)/bin

.PHONY: install

install:
	install -d "$(BINDIR)"
	install -m 755 bin/codex-profile "$(BINDIR)/codex-profile"
FAKE_MAKEFILE
}

init_git_main_branch() {
  local repo="$1"

  if git -C "$repo" init -b main >/dev/null 2>&1; then
    return 0
  fi

  git -C "$repo" init >/dev/null
  git -C "$repo" checkout -b main >/dev/null 2>&1
}

write_fake_chatgpt_app_bundle() {
  local app="$1"
  local message="$2"

  mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
  cat > "$app/Contents/Info.plist" <<'FAKE_PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDisplayName</key>
  <string>ChatGPT</string>
  <key>CFBundleExecutable</key>
  <string>ChatGPT</string>
  <key>CFBundleIdentifier</key>
  <string>com.openai.codex</string>
  <key>CFBundleName</key>
  <string>ChatGPT</string>
</dict>
</plist>
FAKE_PLIST

  cat > "$app/Contents/MacOS/ChatGPT" <<FAKE_CHATGPT_APP
#!/usr/bin/env bash
if [[ "\${OPEN_LAUNCHED:-}" != "yes" ]]; then
  printf 'not launched through open\n' >&2
  exit 64
fi
printf 'MESSAGE=%s\n' "$message"
printf 'CODEX_HOME=%s\n' "\$CODEX_HOME"
printf 'ARGS=%s\n' "\$*"
FAKE_CHATGPT_APP
  chmod 755 "$app/Contents/MacOS/ChatGPT"

  cat > "$app/Contents/Resources/codex" <<'FAKE_BUNDLED_CODEX'
#!/usr/bin/env bash
if [[ "${1:-}" == "--version" ]]; then
  printf 'bundled-codex 1.0\n'
  exit 0
fi
if [[ -n "${FAKE_TOOL_LOG:-}" ]]; then
  printf 'bundled codex called: %s\n' "$*" >> "$FAKE_TOOL_LOG"
fi
printf 'BUNDLED_CODEX_HOME=%s\n' "${CODEX_HOME:-}"
printf 'BUNDLED_ARGS=%s\n' "$*"
FAKE_BUNDLED_CODEX
  chmod 755 "$app/Contents/Resources/codex"
  printf 'fake ChatGPT icon\n' > "$app/Contents/Resources/icon-chatgpt.png"
}

write_fake_chatgpt_open_tools() {
  local fake_bin="$1"
  local tool

  mkdir -p "$fake_bin"

  cat > "$fake_bin/plutil" <<'FAKE_PLUTIL'
#!/usr/bin/env bash
if [[ "${1:-}" != "-extract" ]]; then
  printf 'unexpected plutil mutation: %s\n' "$*" >&2
  exit 99
fi
key="${2:-}"
plist="${!#}"
awk -v target="$key" '
  /<key>.*<\/key>/ {
    current = $0
    sub(/^.*<key>/, "", current)
    sub(/<\/key>.*$/, "", current)
    waiting = current == target
    next
  }
  waiting && /<string>/ {
    value = $0
    gsub(/^[[:space:]]*<string>/, "", value)
    gsub(/<\/string>[[:space:]]*$/, "", value)
    print value
    found = 1
    exit
  }
  END { if (!found) exit 1 }
' "$plist"
FAKE_PLUTIL
  chmod 755 "$fake_bin/plutil"

  for tool in codesign osascript pgrep pkill cp; do
    cat > "$fake_bin/$tool" <<'FAKE_FORBIDDEN_TOOL'
#!/usr/bin/env bash
printf 'forbidden tool %s was called: %s\n' "${0##*/}" "$*" >> "${FAKE_TOOL_LOG:?}"
exit 99
FAKE_FORBIDDEN_TOOL
    chmod 755 "$fake_bin/$tool"
  done

  cat > "$fake_bin/open" <<'FAKE_OPEN'
#!/usr/bin/env bash
if [[ -n "${FAKE_OPEN_EXIT:-}" ]]; then
  printf 'open failed intentionally\n' >&2
  exit "$FAKE_OPEN_EXIT"
fi
stdout="/dev/null"
stderr="/dev/null"
app=""
env_args=()
file_args=()
app_args=()

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    -n|--new)
      shift
      ;;
    --env)
      env_args+=("$2")
      shift 2
      ;;
    --stdout)
      stdout="$2"
      shift 2
      ;;
    --stderr)
      stderr="$2"
      shift 2
      ;;
    -a)
      app="$2"
      shift 2
      ;;
    --args)
      shift
      app_args=("$@")
      break
      ;;
    *)
      file_args+=("$1")
      shift
      ;;
  esac
done

printf 'open -a %s files=%s args=%s\n' "$app" "${file_args[*]}" "${app_args[*]}" >> "${FAKE_TOOL_LOG:?}"
executable="$(plutil -extract CFBundleExecutable raw -o - "$app/Contents/Info.plist")"

if [[ "$stdout" == "$stderr" ]]; then
  env OPEN_LAUNCHED=yes "${env_args[@]}" bash "$app/Contents/MacOS/$executable" "${app_args[@]}" > "$stdout" 2>&1
else
  env OPEN_LAUNCHED=yes "${env_args[@]}" bash "$app/Contents/MacOS/$executable" "${app_args[@]}" > "$stdout" 2> "$stderr"
fi
FAKE_OPEN
  chmod 755 "$fake_bin/open"
}
