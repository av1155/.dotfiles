#!/bin/sh
# Shorten a path for the tmux status bar:
#   1. Replace leading $HOME with ~
#   2. If >4 segments, keep the root segment + last 2 with an ellipsis
#      so both identity (project root) and position (leaf) stay visible.
awk -v home="$HOME" '
{
  p = $0
  hlen = length(home)
  if (hlen > 0 && substr(p, 1, hlen) == home && \
      (length(p) == hlen || substr(p, hlen + 1, 1) == "/")) {
    p = "~" substr(p, hlen + 1)
  }
  n = split(p, parts, "/")
  if (n > 4) {
    printf "%s/%s/…/%s/%s\n", parts[1], parts[2], parts[n-1], parts[n]
  } else {
    print p
  }
}
' </dev/stdin

# Module to be used in tmux configuration.
