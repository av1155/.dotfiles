#!/bin/bash
input=$(cat)

PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
SESSION_ID=$(echo "$input" | jq -r '.session_id')
FIVE_H=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
SEVEN_D=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
FIVE_H_RESET=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
SEVEN_D_RESET=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')

# Colors
GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
DIM='\033[2m'
RESET='\033[0m'

# Terminal width: tput cols reads stderr's TTY, but CC pipes stderr so it
# returns the 80-col fallback. Walk up PPIDs to find the real controlling
# TTY and query its width via stty.
get_cols() {
    local pid=$PPID tty cols
    for _ in 1 2 3 4 5 6 7 8; do
        tty=$(ps -o tty= -p "$pid" 2>/dev/null | tr -d ' ')
        [ -n "$tty" ] && [ "$tty" != "??" ] && break
        pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
        { [ -z "$pid" ] || [ "$pid" = "1" ]; } && break
    done
    if [ -n "$tty" ] && [ "$tty" != "??" ]; then
        cols=$(stty size <"/dev/$tty" 2>/dev/null | awk '{print $2}')
    fi
    echo "${cols:-120}"
}
COLS=$(get_cols)
# Reserve a few columns for CC's right-side notifications.
BUDGET=$((COLS - 5))

# Feature tiers based on available width.
if [ "$BUDGET" -lt 50 ]; then
    SHOW_LIMITS=0
    SHOW_COUNTDOWNS=0
    MAX_BRANCH=14
elif [ "$BUDGET" -lt 75 ]; then
    SHOW_LIMITS=1
    SHOW_COUNTDOWNS=0
    MAX_BRANCH=18
else
    SHOW_LIMITS=1
    SHOW_COUNTDOWNS=1
    MAX_BRANCH=22
fi

# Context bar with threshold colors (tight width for narrow panes)
BAR_WIDTH=8
if [ "$PCT" -ge 70 ]; then
    BAR_COLOR="$RED"
elif [ "$PCT" -ge 40 ]; then
    BAR_COLOR="$YELLOW"
else BAR_COLOR="$GREEN"; fi

FILLED=$((PCT * BAR_WIDTH / 100))
[ "$FILLED" -gt "$BAR_WIDTH" ] && FILLED=$BAR_WIDTH
EMPTY=$((BAR_WIDTH - FILLED))
printf -v FILL "%${FILLED}s" ""
printf -v PAD "%${EMPTY}s" ""
BAR="${FILL// /█}${PAD// /░}"

# Compact "time until epoch" formatter (two most significant units)
format_until() {
    local epoch diff d h m s
    epoch=$1
    diff=$((epoch - $(date +%s)))
    [ "$diff" -le 0 ] && { echo "now"; return; }
    d=$((diff / 86400))
    h=$(((diff % 86400) / 3600))
    m=$(((diff % 3600) / 60))
    s=$((diff % 60))
    if [ "$d" -gt 0 ]; then
        echo "${d}d${h}h"
    elif [ "$h" -gt 0 ]; then
        echo "${h}h${m}m"
    elif [ "$m" -gt 0 ]; then
        echo "${m}m${s}s"
    else
        echo "${s}s"
    fi
}

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
if [ "$SHOW_LIMITS" = 1 ]; then
    if [ -n "$FIVE_H" ]; then
        FC=$(rate_color "$FIVE_H")
        LIMITS=" ${DIM}│${RESET} ${FC}$(printf '%.0f' "$FIVE_H")%${RESET} 5h"
        if [ "$SHOW_COUNTDOWNS" = 1 ] && [ -n "$FIVE_H_RESET" ]; then
            LIMITS="${LIMITS} ${DIM}↻ $(format_until "$FIVE_H_RESET")${RESET}"
        fi
    fi
    if [ -n "$SEVEN_D" ]; then
        SC=$(rate_color "$SEVEN_D")
        LIMITS="${LIMITS} ${DIM}│${RESET} ${SC}$(printf '%.0f' "$SEVEN_D")%${RESET} 7d"
        if [ "$SHOW_COUNTDOWNS" = 1 ] && [ -n "$SEVEN_D_RESET" ]; then
            LIMITS="${LIMITS} ${DIM}↻ $(format_until "$SEVEN_D_RESET")${RESET}"
        fi
    fi
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
    if [ "${#BRANCH}" -gt "$MAX_BRANCH" ]; then
        BRANCH="${BRANCH:0:$((MAX_BRANCH - 1))}…"
    fi
    GIT_SEG=" ${DIM}│${RESET} 🌿 ${BRANCH}"
    [ "$STAGED" -gt 0 ] && GIT_SEG="${GIT_SEG} ${GREEN}+${STAGED}${RESET}"
    [ "$MODIFIED" -gt 0 ] && GIT_SEG="${GIT_SEG} ${YELLOW}~${MODIFIED}${RESET}"
fi

# Build single line. LIMITS and GIT_SEG carry their own leading separators
# when populated, so there's no literal space between "%" and them.
LINE="${BAR_COLOR}${BAR}${RESET} ${PCT}%${LIMITS}${GIT_SEG}"

printf '%b\n' "$LINE"
