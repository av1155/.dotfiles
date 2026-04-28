#!/bin/sh
# Path display for the tmux status bar.
#
# Display tiers, in order of preference:
#   1. Inside a linked git worktree:    <repo> SEP <worktree-leaf>
#   2. Inside a main git worktree:
#        a. at repo root:        <repo>
#        b. fits within NICE:    <repo>/<sub>
#        c. otherwise:           <repo>/ELL/<leaf>
#   3. Outside any git repo:
#        a. $HOME prefix becomes ~
#        b. more than 4 segments: <root>/<seg2>/ELL/<n-1>/<n>
#
# A final HARD cap middle-truncates anything still too long.

set -eu

NICE=30
HARD=55
ELL='…'
SEP='⎇'

input="$(cat)"
[ -n "$input" ] || exit 0

home_rel() {
  case "$1" in
    "$HOME") printf '~' ;;
    "$HOME"/*) printf '~%s' "${1#"$HOME"}" ;;
    *) printf '%s' "$1" ;;
  esac
}

# Normalize possibly-relative common-dir into an absolute repo root.
# git-common-dir is reported relative to the directory git was invoked in,
# so the base must be the input path, not the toplevel.
# Args: $1 = git invocation dir, $2 = git-common-dir (relative or absolute)
main_root_of() {
  case "$2" in
    /*) c="$2" ;;
    *)  c="$1/$2" ;;
  esac
  cd "$(dirname "$c")" 2>/dev/null && pwd
}

git_display() {
  toplevel="$(git -C "$1" rev-parse --show-toplevel 2>/dev/null)" || return 1
  common="$(git -C "$1" rev-parse --git-common-dir 2>/dev/null)"   || return 1
  main_root="$(main_root_of "$1" "$common")" || return 1
  repo="$(basename "$main_root")"

  if [ "$toplevel" != "$main_root" ]; then
    printf '%s %s %s' "$repo" "$SEP" "$(basename "$toplevel")"
    return 0
  fi

  rel="${1#"$toplevel"}"
  rel="${rel#/}"
  if [ -z "$rel" ]; then
    printf '%s' "$repo"
    return 0
  fi

  cand="$repo/$rel"
  if [ ${#cand} -le "$NICE" ]; then
    printf '%s' "$cand"
  else
    printf '%s/%s/%s' "$repo" "$ELL" "${rel##*/}"
  fi
}

generic_display() {
  home_rel "$1" | awk -v ell="$ELL" '
  {
    n = split($0, p, "/")
    if (n > 4) printf "%s/%s/%s/%s/%s", p[1], p[2], ell, p[n-1], p[n]
    else printf "%s", $0
  }'
}

cap_width() {
  s="$1"
  if [ ${#s} -le "$HARD" ]; then
    printf '%s\n' "$s"
    return
  fi
  half=$(( (HARD - 1) / 2 ))
  left=$(printf '%s' "$s" | cut -c1-"$half")
  right=$(printf '%s' "$s" | cut -c"$(( ${#s} - half + 1 ))"-)
  printf '%s%s%s\n' "$left" "$ELL" "$right"
}

if out="$(git_display "$input")"; then
  :
else
  out="$(generic_display "$input")"
fi

cap_width "$out"
