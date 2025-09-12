#!/usr/bin/env bash
set -euo pipefail

# Default value (if no args given)
name="${1:-BOSS}"

read -rp "Enter name (or press Enter to keep ${name}): " input
if [[ -n "$input" ]]; then
    name="$input"
fi

today="$(date +%Y-%m-%d)"
printf "hello, %s - today is %s\n" "$name" "$today"