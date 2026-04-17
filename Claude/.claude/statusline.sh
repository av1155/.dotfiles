#!/bin/bash
input=$(cat)

PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
CONTEXT_SIZE=$(echo "$input" | jq -r '.context_window.context_window_size // 200000')
SESSION_ID=$(echo "$input" | jq -r '.session_id')
DURATION_MS=$(echo "$input" | jq -r '.cost.total_duration_ms // 0')
FIVE_H=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
SEVEN_D=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
FIVE_H_RESET=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
SEVEN_D_RESET=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')
WORKTREE=$(echo "$input" | jq -r '.workspace.git_worktree // empty')
OUTPUT_STYLE_NAME=$(echo "$input" | jq -r '.output_style.name // "default"')

# Colors
GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
CYAN='\033[36m'
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

# Feature tiers based on available width. The branch cap is computed
# dynamically later based on measured widths of every other segment, so
# tiers only drive which segments render and the context-bar width.
if [ "$BUDGET" -lt 50 ]; then
    SHOW_LIMITS=0
    SHOW_COUNTDOWNS=0
    SHOW_GIT_EXTRAS=0
    BAR_WIDTH=8
elif [ "$BUDGET" -lt 75 ]; then
    SHOW_LIMITS=1
    SHOW_COUNTDOWNS=0
    SHOW_GIT_EXTRAS=1
    BAR_WIDTH=8
else
    SHOW_LIMITS=1
    SHOW_COUNTDOWNS=1
    SHOW_GIT_EXTRAS=1
    # Scale the bar into extra terminal space: +1 cell per 10 cols past 75,
    # capped at 14 to avoid a bar that dominates the line.
    BAR_WIDTH=$((8 + (BUDGET - 75) / 10))
    [ "$BAR_WIDTH" -gt 14 ] && BAR_WIDTH=14
fi
# Output-style badge and session duration only when there's plenty of room.
SHOW_OUTPUT_STYLE=0
SHOW_DURATION=0
[ "$BUDGET" -ge 90 ] && SHOW_OUTPUT_STYLE=1
[ "$BUDGET" -ge 90 ] && SHOW_DURATION=1
# Mini rate-limit gauges when the terminal is genuinely wide.
SHOW_RATE_BARS=0
[ "$BUDGET" -ge 110 ] && SHOW_RATE_BARS=1

# Context bar with threshold colors (BAR_WIDTH set by the tier block above).
# Thresholds anchored to two real events so the colors are actionable:
#   yellow = degraded model quality (context rot is meaningful here)
#   red    = pre-auto-compact warning AND severely degraded quality;
#            fires early enough to let the user /compact manually
# Default auto-compact trigger is ~83.5% (CLAUDE_AUTOCOMPACT_PCT_OVERRIDE).
#   200k: auto-compact at ~167k → red at 75% (150k, ~17k tokens of buffer)
#   1M:   auto-compact at ~967k → red at 85% (850k, ~117k tokens of buffer)
if [ "$CONTEXT_SIZE" -ge 500000 ]; then
    CTX_YELLOW=50
    CTX_RED=85
else
    CTX_YELLOW=60
    CTX_RED=75
fi
if [ "$PCT" -ge "$CTX_RED" ]; then
    BAR_COLOR="$RED"
elif [ "$PCT" -ge "$CTX_YELLOW" ]; then
    BAR_COLOR="$YELLOW"
else BAR_COLOR="$GREEN"; fi

FILLED=$((PCT * BAR_WIDTH / 100))
[ "$FILLED" -gt "$BAR_WIDTH" ] && FILLED=$BAR_WIDTH
EMPTY=$((BAR_WIDTH - FILLED))
printf -v FILL "%${FILLED}s" ""
printf -v PAD "%${EMPTY}s" ""
BAR="${FILL// /█}${PAD// /░}"

# Compact duration formatter. Shows the most significant unit, and the next
# unit only when it's non-zero (so "6d0h" → "6d", "3h44m" stays).
format_secs() {
    local diff=$1 d h m s out
    [ "$diff" -le 0 ] && { echo "0s"; return; }
    d=$((diff / 86400))
    h=$(((diff % 86400) / 3600))
    m=$(((diff % 3600) / 60))
    s=$((diff % 60))
    if [ "$d" -gt 0 ]; then
        out="${d}d"
        [ "$h" -gt 0 ] && out="${out}${h}h"
    elif [ "$h" -gt 0 ]; then
        out="${h}h"
        [ "$m" -gt 0 ] && out="${out}${m}m"
    elif [ "$m" -gt 0 ]; then
        out="${m}m"
    else
        out="${s}s"
    fi
    echo "$out"
}

# Time remaining until an epoch timestamp, "now" if the epoch has passed.
format_until() {
    local diff=$(($1 - $(date +%s)))
    [ "$diff" -le 0 ] && { echo "now"; return; }
    format_secs "$diff"
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

# Visible column width of a string (strips ANSI and adjusts for 2-col
# emojis — bash counts 🌿 as one char but terminals render it as two cols).
# Note: our color vars hold literal "\033[32m" text rather than real ESC
# chars, so we must expand via printf '%b' before sed can strip them.
visible_width() {
    local s
    s=$(printf '%b' "$1" | sed $'s/\x1b\\[[0-9;]*m//g')
    local w=${#s} e rest
    for e in "🌿" "🔀"; do
        rest="${s//$e/}"
        w=$((w + ${#s} - ${#rest}))
    done
    echo "$w"
}

# Mini 4-cell gauge for a rate limit. Uses ▰▱ (parallelograms) to stay
# visually distinct from the main context bar's █░ blocks.
rate_bar() {
    local pct=$1 color=$2 width=4
    local filled=$((pct * width / 100)) empty fp ep
    [ "$filled" -gt "$width" ] && filled=$width
    [ "$filled" -lt 0 ] && filled=0
    # With only 4 cells (25% per step) anything 1-24% would round to 0 and
    # look identical to 0%. Guarantee at least one cell lit when the value
    # is non-zero so the gauge always reflects "some usage".
    [ "$filled" -eq 0 ] && [ "$pct" -gt 0 ] && filled=1
    empty=$((width - filled))
    printf -v fp "%${filled}s" ""
    printf -v ep "%${empty}s" ""
    printf '%b%s%b%b%s%b' "$color" "${fp// /▰}" "$RESET" "$DIM" "${ep// /▱}" "$RESET"
}

LIMITS=""
if [ "$SHOW_LIMITS" = 1 ]; then
    # Use a dim middle-dot separator between (bar+%), (window label), and
    # (countdown) only when the line is genuinely wide (same gate as the
    # rate bars). Below that, plain spaces keep the line compact.
    if [ "$SHOW_RATE_BARS" = 1 ]; then
        SEP=" ${DIM}·${RESET} "
    else
        SEP=" "
    fi
    if [ -n "$FIVE_H" ]; then
        five_pct=$(printf '%.0f' "$FIVE_H")
        FC=$(rate_color "$FIVE_H")
        five_bar=""
        [ "$SHOW_RATE_BARS" = 1 ] && five_bar="$(rate_bar "$five_pct" "$FC")  "
        LIMITS=" ${DIM}│${RESET} 5h${SEP}${five_bar}${FC}${five_pct}%${RESET}"
        if [ "$SHOW_COUNTDOWNS" = 1 ] && [ -n "$FIVE_H_RESET" ]; then
            LIMITS="${LIMITS}${SEP}${DIM}↻ $(format_until "$FIVE_H_RESET")${RESET}"
        fi
    fi
    if [ -n "$SEVEN_D" ]; then
        seven_pct=$(printf '%.0f' "$SEVEN_D")
        SC=$(rate_color "$SEVEN_D")
        seven_bar=""
        [ "$SHOW_RATE_BARS" = 1 ] && seven_bar="$(rate_bar "$seven_pct" "$SC")  "
        LIMITS="${LIMITS} ${DIM}│${RESET} 7d${SEP}${seven_bar}${SC}${seven_pct}%${RESET}"
        if [ "$SHOW_COUNTDOWNS" = 1 ] && [ -n "$SEVEN_D_RESET" ]; then
            LIMITS="${LIMITS}${SEP}${DIM}↻ $(format_until "$SEVEN_D_RESET")${RESET}"
        fi
    fi
fi

# Git (cached 5s). Cache format is 6 fields separated by "|":
#   BRANCH|STAGED|MODIFIED|UNTRACKED|AHEAD|BEHIND
# The v2 prefix forces a fresh cache when the format changes.
CACHE_FILE="/tmp/cc-statusline-git-v2-$SESSION_ID"
if [ ! -f "$CACHE_FILE" ] || [ $(($(date +%s) - $(stat -f %m "$CACHE_FILE" 2>/dev/null || stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0))) -gt 5 ]; then
    if git rev-parse --git-dir >/dev/null 2>&1; then
        BRANCH=$(git branch --show-current 2>/dev/null)
        STAGED=$(git diff --cached --numstat 2>/dev/null | wc -l | tr -d ' ')
        MODIFIED=$(git diff --numstat 2>/dev/null | wc -l | tr -d ' ')
        UNTRACKED=$(git ls-files --others --exclude-standard 2>/dev/null | wc -l | tr -d ' ')
        AHEAD=0
        BEHIND=0
        if git rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then
            ab=$(git rev-list --count --left-right '@{u}...HEAD' 2>/dev/null)
            BEHIND=$(echo "$ab" | awk '{print $1}')
            AHEAD=$(echo "$ab" | awk '{print $2}')
        fi
        echo "$BRANCH|$STAGED|$MODIFIED|$UNTRACKED|$AHEAD|$BEHIND" >"$CACHE_FILE"
    else
        echo "|||||" >"$CACHE_FILE"
    fi
fi
IFS='|' read -r BRANCH STAGED MODIFIED UNTRACKED AHEAD BEHIND <"$CACHE_FILE"

# Session-duration segment (dim) when room allows.
DURATION_SEG=""
if [ "$SHOW_DURATION" = 1 ] && [ "${DURATION_MS:-0}" -gt 0 ]; then
    DURATION_SEG=" ${DIM}│ ⏱ $(format_secs $((DURATION_MS / 1000)))${RESET}"
fi

# Output-style badge (dim) when non-default and room allows.
# Case-insensitive match: settings.json uses "Default" but CC may emit any
# casing, so normalize via case globs (works on bash 3.2, unlike ${v,,}).
STYLE_SEG=""
if [ "$SHOW_OUTPUT_STYLE" = 1 ] && [ -n "$OUTPUT_STYLE_NAME" ]; then
    case "$OUTPUT_STYLE_NAME" in
        default|Default|DEFAULT) ;;
        *) STYLE_SEG=" ${DIM}│ ✎ ${OUTPUT_STYLE_NAME}${RESET}" ;;
    esac
fi

# Build the git segment with a truly dynamic branch cap. We pre-build the
# prefix (pipe + leaf emoji) and the counters (+N ~M ?U ↑A ↓B) as separate
# pieces, measure every other segment's visible width, and give the branch
# exactly what's left. This guarantees counters never get clipped off the
# right edge when a long branch would have pushed the line past the width.
GIT_SEG=""
if [ -n "$BRANCH" ]; then
    # Counters string (may be empty).
    git_counters=""
    [ "${STAGED:-0}" -gt 0 ] && git_counters="${git_counters} ${GREEN}+${STAGED}${RESET}"
    [ "${MODIFIED:-0}" -gt 0 ] && git_counters="${git_counters} ${YELLOW}~${MODIFIED}${RESET}"
    if [ "$SHOW_GIT_EXTRAS" = 1 ]; then
        [ "${UNTRACKED:-0}" -gt 0 ] && git_counters="${git_counters} ${CYAN}?${UNTRACKED}${RESET}"
        [ "${AHEAD:-0}" -gt 0 ] && git_counters="${git_counters} ${GREEN}↑${AHEAD}${RESET}"
        [ "${BEHIND:-0}" -gt 0 ] && git_counters="${git_counters} ${RED}↓${BEHIND}${RESET}"
    fi
    # Branch prefix: swap emoji when inside a linked worktree.
    if [ -n "$WORKTREE" ]; then
        git_prefix=" ${DIM}│${RESET} 🔀 "
    else
        git_prefix=" ${DIM}│${RESET} 🌿 "
    fi
    # Reserve room for every non-branch visible element, then give branch
    # whatever's left (clamped to [5, 60] for sanity).
    bar_pct_width=$((BAR_WIDTH + 2 + ${#PCT}))
    reserved=$((bar_pct_width \
        + $(visible_width "$LIMITS") \
        + $(visible_width "$DURATION_SEG") \
        + $(visible_width "$STYLE_SEG") \
        + $(visible_width "$git_prefix") \
        + $(visible_width "$git_counters") \
        + 2))
    avail=$((BUDGET - reserved))
    [ "$avail" -lt 5 ] && avail=5
    [ "$avail" -gt 60 ] && avail=60
    if [ "${#BRANCH}" -gt "$avail" ]; then
        BRANCH="${BRANCH:0:$((avail - 1))}…"
    fi
    GIT_SEG="${git_prefix}${BRANCH}${git_counters}"
fi

# Build single line. LIMITS, GIT_SEG, and STYLE_SEG carry their own leading
# separators when populated, so there's no literal space between them.
LINE="${BAR_COLOR}${BAR}${RESET} ${PCT}%${LIMITS}${DURATION_SEG}${GIT_SEG}${STYLE_SEG}"

printf '%b\n' "$LINE"
