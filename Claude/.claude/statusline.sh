#!/bin/bash
input=$(cat)

MODEL=$(echo "$input" | jq -r '.model.display_name')
DIR=$(echo "$input" | jq -r '.workspace.current_dir')
PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
DURATION_MS=$(echo "$input" | jq -r '.cost.total_duration_ms // 0')
SESSION_ID=$(echo "$input" | jq -r '.session_id')
FIVE_H=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
SEVEN_D=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')

# Colors
CYAN='\033[36m'
GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
DIM='\033[2m'
RESET='\033[0m'

# Context bar with threshold colors
if [ "$PCT" -ge 90 ]; then
    BAR_COLOR="$RED"
elif [ "$PCT" -ge 70 ]; then
    BAR_COLOR="$YELLOW"
else BAR_COLOR="$GREEN"; fi

FILLED=$((PCT / 5))
EMPTY=$((20 - FILLED))
printf -v FILL "%${FILLED}s"
printf -v PAD "%${EMPTY}s"
BAR="${FILL// /█}${PAD// /░}"

# Duration
MINS=$((DURATION_MS / 60000))
SECS=$(((DURATION_MS % 60000) / 1000))

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
    LIMITS="${FC}$(printf '%.0f' "$FIVE_H")%%${RESET} 5h"
fi
if [ -n "$SEVEN_D" ]; then
    SC=$(rate_color "$SEVEN_D")
    [ -n "$LIMITS" ] && LIMITS="${LIMITS} ${DIM}│${RESET} "
    LIMITS="${LIMITS}${SC}$(printf '%.0f' "$SEVEN_D")%%${RESET} 7d"
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

GIT_INFO=""
if [ -n "$BRANCH" ]; then
    GIT_INFO=" ${DIM}│${RESET} 🌿 ${BRANCH}"
    [ "$STAGED" -gt 0 ] && GIT_INFO="${GIT_INFO} ${GREEN}+${STAGED}${RESET}"
    [ "$MODIFIED" -gt 0 ] && GIT_INFO="${GIT_INFO} ${YELLOW}~${MODIFIED}${RESET}"
fi

# Line 1: model, dir, git
echo -e "${CYAN}${MODEL}${RESET} ${DIM}·${RESET} ${DIR##*/}${GIT_INFO}"
# Line 2: context bar, rate limits, time
RATE_SEG=""
[ -n "$LIMITS" ] && RATE_SEG=" ${DIM}│${RESET} ${LIMITS}"
echo -e "${BAR_COLOR}${BAR}${RESET} ${PCT}%${RATE_SEG} ${DIM}│${RESET} ${MINS}m${SECS}s"
