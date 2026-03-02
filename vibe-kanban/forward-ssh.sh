#!/usr/bin/env bash
set -euo pipefail

if [ $# -ne 1 ]; then
  echo "Usage: $0 <workspace-name>"
  exit 1
fi

name="$1"
file="$HOME/.ssh/workspaces/${name}.config"

if [ ! -f "$file" ]; then
  echo "Error: file not found: $file"
  exit 1
fi

if ! command -v lsof >/dev/null 2>&1; then
  echo "Error: lsof is required but not installed"
  exit 1
fi

check_port() {
  local port="$1"

  if lsof -nP -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1; then
    echo "Error: port $port is already in use:"
    lsof -nP -iTCP:"$port" -sTCP:LISTEN
    echo
  fi
}

# Check ports before modifying anything
check_port 42091

add_if_missing() {
  local line="$1"
  if ! grep -Fxq "$line" "$file"; then
    printf '%s\n' "$line" >> "$file"
    echo "Added: $line"
  else
    echo "Already present in $file: $line"
  fi
}

add_if_missing "    LocalForward 42091 localhost:42091"
add_if_missing "    LocalForward 3000 localhost:3000"


echo "Done."