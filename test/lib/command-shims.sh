#!/usr/bin/env bash

write_command_shim() {
  local path="$1"

  mkdir -p "$(dirname "$path")"
  {
    printf '%s\n\n' '#!/bin/sh'
    cat
  } > "$path"
  chmod 755 "$path"
}
