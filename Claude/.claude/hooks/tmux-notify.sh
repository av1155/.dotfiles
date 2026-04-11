#!/bin/bash
[ -z "$TMUX" ] && exit 0
input=$(cat)
title=$(echo "$input" | jq -r '.title // "Claude Code"')
message=$(echo "$input" | jq -r '.message // ""')
printf $'\033Ptmux;\033\033]9;%s: %s\007\033\\' "$title" "$message" >/dev/tty
