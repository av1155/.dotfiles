#!/bin/bash
input=$(cat)

PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
DURATION_MS=$(echo "$input" | jq -r '.cost.total_duration_ms // 0')
SESSION_ID=$(echo "$input" | jq -r '.session_id')
FIVE_H=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
SEVEN_D=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')

# Colors
GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
DIM='\033[2m'
RESET='\033[0m'

# Terminal width for truncation
COLS=$(tput cols 2>/dev/null || echo 120)

# Context bar (10 chars) with threshold colors
if [ "$PCT" -ge 90 ]; then
    BAR_COLOR="$RED"
elif [ "$PCT" -ge 70 ]; then
    BAR_COLOR="$YELLOW"
else BAR_COLOR="$GREEN"; fi

FILLED=$((PCT / 10))
EMPTY=$((10 - FILLED))
printf -v FILL "%${FILLED}s"
printf -v PAD "%${EMPTY}s"
BAR="${FILL// /█}${PAD// /░}"

# Duration: two most significant units
TOTAL_SEC=$((DURATION_MS / 1000))
D=$((TOTAL_SEC / 86400))
H=$(((TOTAL_SEC % 86400) / 3600))
M=$(((TOTAL_SEC % 3600) / 60))
S=$((TOTAL_SEC % 60))
if [ "$D" -gt 0 ]; then
    DURATION_FMT="${D}d${H}h"
elif [ "$H" -gt 0 ]; then
    DURATION_FMT="${H}h${M}m"
elif [ "$M" -gt 0 ]; then
    DURATION_FMT="${M}m${S}s"
else
    DURATION_FMT="${S}s"
fi

# Rate limits with color coding
rate_color() {
    local val
    val=$(printf '%.0f' "$1")
    if [ "$val" -ge 80 ]; then
        echo "$RED"
    elif [ "$val" -ge 50 ]; then
        echo "$YELLOW"
    else echo "$GREEN"; fi
}

LIMITS=""
if [ -n "$FIVE_H" ]; then
    FC=$(rate_color "$FIVE_H")
    LIMITS="${DIM}│${RESET} ${FC}$(printf '%.0f' "$FIVE_H")%${RESET} 5h"
fi
if [ -n "$SEVEN_D" ]; then
    SC=$(rate_color "$SEVEN_D")
    LIMITS="${LIMITS} ${DIM}│${RESET} ${SC}$(printf '%.0f' "$SEVEN_D")%${RESET} 7d"
fi

# Git (cached 5s)
CACHE_FILE="/tmp/cc-statusline-git-$SESSION_ID"
if [ ! -f "$CACHE_FILE" ] || [ $(($(date +%s) - $(stat -f %m "$CACHE_FILE" 2>/dev/null || stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0))) -gt 5 ]; then
    if git rev-parse --git-dir >/dev/null 2>&1; then
        BRANCH=$(git branch --show-current 2>/dev/null)
        STAGED=$(git diff --cached --numstat 2>/dev/null | wc -l | tr -d ' ')
        MODIFIED=$(git diff --numstat 2>/dev/null | wc -l | tr -d ' ')
        echo "$BRANCH|$STAGED|$MODIFIED" >"$CACHE_FILE"
    else
        echo "||" >"$CACHE_FILE"
    fi
fi
IFS='|' read -r BRANCH STAGED MODIFIED <"$CACHE_FILE"

GIT_SEG=""
if [ -n "$BRANCH" ]; then
    GIT_SEG=" ${DIM}│${RESET} 🌿 ${BRANCH}"
    [ "$STAGED" -gt 0 ] && GIT_SEG="${GIT_SEG} ${GREEN}+${STAGED}${RESET}"
    [ "$MODIFIED" -gt 0 ] && GIT_SEG="${GIT_SEG} ${YELLOW}~${MODIFIED}${RESET}"
fi

# Build single line
LINE="${BAR_COLOR}${BAR}${RESET} ${PCT}% ${LIMITS} ${DIM}│${RESET} ${DURATION_FMT}${GIT_SEG}"

# Truncate to terminal width (ANSI-aware)
printf '%b' "$LINE" | perl -CS -e '
    $max = shift; $_ = <STDIN>; chomp;
    $vis = 0; $pos = 0;
    while ($pos < length && $vis < $max) {
        if (substr($_, $pos) =~ /^(\e\[[0-9;]*m)/) { $pos += length($1); }
        else { $pos++; $vis++; }
    }
    print substr($_, 0, $pos), "\e[0m\n";
' "$COLS"
