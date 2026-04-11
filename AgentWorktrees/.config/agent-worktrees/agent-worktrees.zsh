# =============================================================================
# agent: Unified CLI for parallel AI coding sessions
# =============================================================================
# Source from .zshrc:
#   [ -f "$HOME/.config/agent-worktrees/agent-worktrees.zsh" ] && \
#       source "$HOME/.config/agent-worktrees/agent-worktrees.zsh"
#
# Or add to dotfiles via GNU Stow (AgentWorktrees package).
#
# Usage:
#   agent                          Interactive launcher (requires fzf)
#   agent spin <n> [--codex]    Create worktree + tmux + coding agent
#   agent list                     Show all active agent worktrees
#   agent attach <n>            Attach to an agent's tmux session
#   agent diff <n>              Show what the agent changed
#   agent review <n>            Launch adversarial reviewer (fresh context)
#   agent merge <n>             Merge agent branch into current branch
#   agent clean <n>             Remove worktree + branch + tmux
#   agent clean-all                Remove all agent worktrees for this repo
#   agent help                     Show help
#   agent version                  Show version
#
# Environment:
#   AGENT_WORKTREE_DIR   Base directory for worktrees (default: ~/.agent-worktrees)
# =============================================================================

AGENT_WORKTREE_DIR="${AGENT_WORKTREE_DIR:-$HOME/.agent-worktrees}"

__AGENT_VERSION="1.0.0"

# =============================================================================
# Output helpers (color + path)
# =============================================================================

# Populates the caller's color vars via dynamic scoping. Callers MUST declare:
#   local c_reset c_bold c_dim c_red c_green c_yellow c_blue c_magenta c_cyan c_gray
# otherwise these leak as globals. Honors NO_COLOR (no-color.org) and
# AGENT_NO_COLOR, and auto-disables when stdout is not a TTY so pipes and
# parsers see plain text.
__agent_init_colors() {
  if [[ -t 1 && -z "$NO_COLOR" && -z "$AGENT_NO_COLOR" ]]; then
    c_reset=$'\e[0m';   c_bold=$'\e[1m';    c_dim=$'\e[2m'
    c_red=$'\e[31m';    c_green=$'\e[32m';  c_yellow=$'\e[33m'
    c_blue=$'\e[34m';   c_magenta=$'\e[35m';c_cyan=$'\e[36m'
    c_gray=$'\e[90m'
  else
    c_reset=""; c_bold=""; c_dim=""; c_red=""; c_green=""; c_yellow=""
    c_blue=""; c_magenta=""; c_cyan=""; c_gray=""
  fi
}

__agent_short_path() {
  print -r -- "${1/#$HOME/~}"
}

# =============================================================================
# Main entry point
# =============================================================================

agent() {
  local cmd="${1:-}"

  case "$cmd" in
    spin)       shift; __agent_spin "$@" ;;
    list|ls)    shift; __agent_list "$@" ;;
    attach|a)   shift; __agent_attach "$@" ;;
    diff|d)     shift; __agent_diff "$@" ;;
    review|r)   shift; __agent_review "$@" ;;
    merge|m)    shift; __agent_merge "$@" ;;
    clean)      shift; __agent_clean "$@" ;;
    clean-all)  shift; __agent_clean_all "$@" ;;
    help|-h|--help)       __agent_help ;;
    version|-v|--version) __agent_version ;;
    "")         __agent_interactive ;;
    *)
      local c_reset c_bold c_dim c_red c_green c_yellow c_blue c_magenta c_cyan c_gray
      __agent_init_colors
      print -r -- "${c_red}✗${c_reset} agent: unknown command '${cmd}'"
      print -r -- "  ${c_dim}run: agent help${c_reset}"
      return 1
      ;;
  esac
}

# =============================================================================
# Help and version
# =============================================================================

__agent_help() {
  local c_reset c_bold c_dim c_red c_green c_yellow c_blue c_magenta c_cyan c_gray
  __agent_init_colors

  print -r -- "agent: Unified CLI for parallel AI coding sessions"
  print -r -- ""
  print -r -- "${c_bold}${c_cyan}USAGE${c_reset}"
  print -r -- "  ${c_bold}agent${c_reset}                             Interactive launcher (requires fzf)"
  print -r -- "  ${c_bold}agent${c_reset} <command> [args]            Run a command directly"
  print -r -- ""
  print -r -- "${c_bold}${c_cyan}COMMANDS${c_reset}"
  print -r -- "  ${c_bold}spin${c_reset} <name> [--bare|--codex]   Create isolated worktree + tmux session"
  print -r -- "                                      (default) Claude Code"
  print -r -- "                                      --bare    worktree only, no session"
  print -r -- "                                      --codex   OpenAI Codex CLI instead"
  print -r -- ""
  print -r -- "  ${c_bold}list${c_reset}, ${c_bold}ls${c_reset}                          Show all active agent worktrees"
  print -r -- ""
  print -r -- "  ${c_bold}attach${c_reset}, ${c_bold}a${c_reset} <name>                  Attach to an agent's tmux session"
  print -r -- ""
  print -r -- "  ${c_bold}diff${c_reset}, ${c_bold}d${c_reset} <name>                    Show what the agent changed vs base"
  print -r -- ""
  print -r -- "  ${c_bold}review${c_reset}, ${c_bold}r${c_reset} <name>                  Launch adversarial review (fresh Claude Code)"
  print -r -- "                                    Then type /review inside the session"
  print -r -- ""
  print -r -- "  ${c_bold}merge${c_reset}, ${c_bold}m${c_reset} <name>                   Merge agent branch into current branch"
  print -r -- ""
  print -r -- "  ${c_bold}clean${c_reset} <name>                     Kill session + remove worktree + delete branch"
  print -r -- ""
  print -r -- "  ${c_bold}clean-all${c_reset}                         Clean all agent worktrees for this repo"
  print -r -- ""
  print -r -- "  ${c_bold}help${c_reset}, ${c_bold}-h${c_reset}, ${c_bold}--help${c_reset}                  Show this help"
  print -r -- ""
  print -r -- "  ${c_bold}version${c_reset}, ${c_bold}-v${c_reset}, ${c_bold}--version${c_reset}            Show version"
  print -r -- ""
  print -r -- "${c_bold}${c_cyan}WORKFLOW${c_reset}"
  print -r -- "  1. cd into any git repo"
  print -r -- "  2. agent spin feature-a                  # Claude Code session"
  print -r -- "  3. agent spin fix-tests --codex          # Codex session (parallel)"
  print -r -- "  4. agent attach feature-a                # Brief the agent, detach"
  print -r -- "  5. ... do other work while agents run ..."
  print -r -- "  6. agent review feature-a                # Adversarial review"
  print -r -- "  7. agent merge feature-a                 # Merge if review passes"
  print -r -- "  8. agent clean feature-a                 # Clean up"
  print -r -- ""
  print -r -- "${c_bold}${c_cyan}QUALITY GATES${c_reset} (before every merge)"
  print -r -- "  ${c_dim}·${c_reset} Linter passes"
  print -r -- "  ${c_dim}·${c_reset} Type checker passes"
  print -r -- "  ${c_dim}·${c_reset} Tests pass"
  print -r -- "  ${c_dim}·${c_reset} /review has zero CRITICAL findings"
  print -r -- "  ${c_dim}·${c_reset} You read the diff and approve"
  print -r -- ""
  print -r -- "${c_bold}${c_cyan}ENVIRONMENT${c_reset}"
  print -r -- "  AGENT_WORKTREE_DIR    Base directory for worktrees"
  print -r -- "                        Default: ~/.agent-worktrees"
}

__agent_version() {
  echo "agent ${__AGENT_VERSION}"
}

# =============================================================================
# Interactive launcher (fzf)
# =============================================================================

__agent_interactive() {
  if ! command -v fzf &>/dev/null; then
    echo "Interactive mode requires fzf. Install it or use: agent <command>"
    echo ""
    __agent_help
    return 1
  fi

  setopt local_options extendedglob
  local c_reset c_bold c_dim c_red c_green c_yellow c_blue c_magenta c_cyan c_gray
  __agent_init_colors

  local repo_root
  repo_root=$(git rev-parse --show-toplevel 2>/dev/null)

  # Build the menu dynamically based on current state
  local -a menu_items=()
  local worktree_count=0

  if [[ -n "$repo_root" ]]; then
    local base_dir="${AGENT_WORKTREE_DIR}/$(basename "$repo_root")"
    if [[ -d "$base_dir" ]]; then
      worktree_count=$(find "$base_dir" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
    fi
  fi

  menu_items+=("${c_bold}${c_cyan}spin${c_reset}        Create a new agent worktree + session")

  if [[ "$worktree_count" -gt 0 ]]; then
    menu_items+=("${c_bold}${c_cyan}list${c_reset}        Show all active agent worktrees ${c_dim}(${worktree_count} active)${c_reset}")
    menu_items+=("${c_bold}${c_cyan}attach${c_reset}      Attach to an agent's tmux session")
    menu_items+=("${c_bold}${c_cyan}diff${c_reset}        Show what an agent changed")
    menu_items+=("${c_bold}${c_cyan}review${c_reset}      Launch adversarial review on an agent's work")
    menu_items+=("${c_bold}${c_cyan}merge${c_reset}       Merge an agent's branch into current branch")
    menu_items+=("${c_bold}${c_cyan}clean${c_reset}       Remove a specific agent worktree")
    menu_items+=("${c_bold}${c_cyan}clean-all${c_reset}   Remove all agent worktrees for this repo")
  else
    menu_items+=("${c_bold}${c_cyan}list${c_reset}        Show all active agent worktrees ${c_dim}(none)${c_reset}")
  fi

  menu_items+=("${c_bold}${c_cyan}help${c_reset}        Show full help")
  menu_items+=("${c_bold}${c_cyan}version${c_reset}     Show version")

  local selection
  selection=$(printf '%s\n' "${menu_items[@]}" | fzf \
    --height=~40% \
    --border \
    --prompt="agent> " \
    --header="Select a command (ESC to cancel)" \
    --no-multi \
    --ansi)

  [[ -z "$selection" ]] && return 0

  # Strip ANSI SGR escapes so `case` matches plain command names
  local selected_cmd agent_name
  local selection_plain="${selection//$'\e'\[[0-9;]#m/}"
  selected_cmd=$(echo "$selection_plain" | awk '{print $1}')

  case "$selected_cmd" in
    spin)
      echo -n "Agent name: "
      read -r agent_name
      [[ -z "$agent_name" ]] && return 0

      local mode_selection
      mode_selection=$(printf '%s\n' \
        "${c_bold}${c_green}claude${c_reset}     Claude Code (default)" \
        "${c_bold}${c_blue}codex${c_reset}      OpenAI Codex CLI" \
        "${c_bold}${c_gray}bare${c_reset}       Worktree only, no session" \
        | fzf \
          --height=~30% \
          --border \
          --prompt="mode> " \
          --header="Select agent type" \
          --no-multi \
          --ansi)

      [[ -z "$mode_selection" ]] && return 0

      local mode_flag=""
      local mode_cmd
      local mode_plain="${mode_selection//$'\e'\[[0-9;]#m/}"
      mode_cmd=$(echo "$mode_plain" | awk '{print $1}')
      case "$mode_cmd" in
        codex) mode_flag="--codex" ;;
        bare)  mode_flag="--bare" ;;
      esac

      __agent_spin "$agent_name" $mode_flag
      ;;

    attach|diff|review|merge|clean)
      agent_name=$(__agent_pick_worktree "Select agent for ${selected_cmd}")
      [[ -z "$agent_name" ]] && return 0

      case "$selected_cmd" in
        attach)  __agent_attach "$agent_name" ;;
        diff)    __agent_diff "$agent_name" ;;
        review)  __agent_review "$agent_name" ;;
        merge)   __agent_merge "$agent_name" ;;
        clean)   __agent_clean "$agent_name" ;;
      esac
      ;;

    clean-all) __agent_clean_all ;;
    list)      __agent_list ;;
    help)      __agent_help ;;
    version)   __agent_version ;;
  esac
}

# Pick an existing worktree via fzf
__agent_pick_worktree() {
  setopt local_options nullglob extendedglob
  local header="${1:-Select an agent}"
  local c_reset c_bold c_dim c_red c_green c_yellow c_blue c_magenta c_cyan c_gray
  __agent_init_colors

  local repo_root
  repo_root=$(git rev-parse --show-toplevel 2>/dev/null)
  if [[ -z "$repo_root" ]]; then
    echo ""
    return 1
  fi

  local base_dir="${AGENT_WORKTREE_DIR}/$(basename "$repo_root")"
  if [[ ! -d "$base_dir" ]]; then
    print -u2 -r -- "No agent worktrees found."
    echo ""
    return 1
  fi

  local -a entries=()
  local name branch wt_status glyph_char glyph_color status_color install_pid
  local name_col branch_col status_col
  for dir in "$base_dir"/*/; do
    [[ -d "$dir" ]] || continue
    name=$(basename "$dir")
    branch="agent/${name}"

    wt_status="idle"
    if tmux has-session -t "agent-${name}" 2>/dev/null; then
      wt_status="claude"
    elif tmux has-session -t "codex-${name}" 2>/dev/null; then
      wt_status="codex"
    elif tmux has-session -t "review-${name}" 2>/dev/null; then
      wt_status="reviewing"
    elif [[ -f "${dir}.agent-install.pid" ]]; then
      install_pid=$(cat "${dir}.agent-install.pid" 2>/dev/null)
      if [[ -n "$install_pid" ]] && kill -0 "$install_pid" 2>/dev/null; then
        wt_status="installing"
      fi
    fi

    case "$wt_status" in
      claude|codex) glyph_char="●"; glyph_color="$c_green";   status_color="$c_green"   ;;
      reviewing)    glyph_char="⟳"; glyph_color="$c_magenta"; status_color="$c_magenta" ;;
      installing)   glyph_char="⠿"; glyph_color="$c_yellow";  status_color="$c_yellow"  ;;
      *)            glyph_char="○"; glyph_color="$c_gray";    status_color="$c_gray"    ;;
    esac

    name_col=$(printf '%-24s' "$name")
    branch_col=$(printf '%-28s' "$branch")
    status_col=$(printf '%-10s' "$wt_status")
    entries+=("${glyph_color}${glyph_char}${c_reset} ${c_bold}${name_col}${c_reset} ${c_dim}${branch_col}${c_reset} ${status_color}${status_col}${c_reset}")
  done

  if [[ ${#entries[@]} -eq 0 ]]; then
    print -u2 -r -- "No agent worktrees found."
    echo ""
    return 1
  fi

  local selection
  selection=$(printf '%s\n' "${entries[@]}" | fzf \
    --height=~40% \
    --border \
    --prompt="agent> " \
    --header="$header" \
    --ansi \
    --no-multi)

  [[ -z "$selection" ]] && echo "" && return 0

  # Strip ANSI SGR so callers get the plain worktree name (field 2 after glyph)
  local plain="${selection//$'\e'\[[0-9;]#m/}"
  print -r -- "${plain}" | awk '{print $2}'
}

# =============================================================================
# Core commands
# =============================================================================

__agent_spin() {
  local c_reset c_bold c_dim c_red c_green c_yellow c_blue c_magenta c_cyan c_gray
  __agent_init_colors

  local name="$1"
  local mode="${2:-}"

  if [[ -z "$name" ]]; then
    print -r -- "${c_dim}Usage:${c_reset} agent spin <name> [--bare|--codex]"
    print -r -- ""
    print -r -- "Examples:"
    print -r -- "  agent spin auth-refactor          # Claude Code in tmux"
    print -r -- "  agent spin readme-rewrite --bare  # Worktree only, no session"
    print -r -- "  agent spin fix-tests --codex      # OpenAI Codex CLI in tmux"
    return 1
  fi

  local repo_root
  repo_root=$(git rev-parse --show-toplevel 2>/dev/null)
  if [[ -z "$repo_root" ]]; then
    print -r -- "${c_red}✗${c_reset} not inside a git repository"
    return 1
  fi

  local branch="agent/${name}"
  local worktree_path="${AGENT_WORKTREE_DIR}/$(basename "$repo_root")/${name}"
  local worktree_display
  worktree_display=$(__agent_short_path "$worktree_path")
  local base_branch
  base_branch=$(git symbolic-ref --short HEAD 2>/dev/null || echo "main")

  print -r -- "${c_cyan}→${c_reset} Spinning up agent ${c_bold}\"${name}\"${c_reset}"

  if [[ -d "$worktree_path" ]]; then
    print -r -- "  ${c_red}✗${c_reset} worktree  already exists at ${c_dim}${worktree_display}${c_reset}"
    print -r -- "    ${c_dim}attach: agent attach ${name}${c_reset}"
    return 1
  fi

  mkdir -p "$(dirname "$worktree_path")"

  git worktree add -b "$branch" "$worktree_path" "$base_branch" &>/dev/null
  if [[ $? -ne 0 ]]; then
    git worktree add "$worktree_path" "$branch" &>/dev/null
    if [[ $? -ne 0 ]]; then
      print -r -- "  ${c_red}✗${c_reset} worktree  failed to create (branch '${branch}' conflict?)"
      return 1
    fi
  fi
  print -r -- "  ${c_green}✓${c_reset} worktree  ${c_dim}${worktree_display}${c_reset}"
  print -r -- "  ${c_green}✓${c_reset} branch    ${c_dim}${branch} (from ${base_branch})${c_reset}"

  # Carry over env files the project might need to build/run
  local -a envs_copied=()
  for envfile in .env .env.local .env.development.local; do
    if [[ -f "${repo_root}/${envfile}" ]]; then
      cp "${repo_root}/${envfile}" "${worktree_path}/${envfile}"
      envs_copied+=("$envfile")
    fi
  done
  if (( ${#envs_copied[@]} > 0 )); then
    print -r -- "  ${c_green}✓${c_reset} env       ${c_dim}${(j:, :)envs_copied}${c_reset}"
  fi

  # Install deps in background if lockfile exists. Using `builtin cd` bypasses
  # zoxide's `cd` alias. The grouping subshell writes the install PID (for
  # `agent clean` to kill stragglers) AND the exit code (for `agent list` to
  # distinguish installing/ready/failed).
  local install_pid="" install_mgr=""
  if [[ -f "${worktree_path}/pnpm-lock.yaml" ]]; then
    install_mgr="pnpm"
    (
      builtin cd "$worktree_path" && pnpm install --frozen-lockfile --silent 2>/dev/null
      print -r -- $? > "${worktree_path}/.agent-install.status"
    ) &
    install_pid=$!
  elif [[ -f "${worktree_path}/package-lock.json" ]]; then
    install_mgr="npm"
    (
      builtin cd "$worktree_path" && npm ci --silent 2>/dev/null
      print -r -- $? > "${worktree_path}/.agent-install.status"
    ) &
    install_pid=$!
  elif [[ -f "${worktree_path}/yarn.lock" ]]; then
    install_mgr="yarn"
    (
      builtin cd "$worktree_path" && yarn install --frozen-lockfile --silent 2>/dev/null
      print -r -- $? > "${worktree_path}/.agent-install.status"
    ) &
    install_pid=$!
  fi
  if [[ -n "$install_pid" ]]; then
    print -r -- "$install_pid" > "${worktree_path}/.agent-install.pid"
    print -r -- "  ${c_yellow}⠿${c_reset} install   ${c_dim}${install_mgr} (pid ${install_pid}) running in background${c_reset}"
  fi

  if [[ "$mode" == "--bare" ]]; then
    print -r -- ""
    print -r -- "  ${c_dim}Launch: cd ${worktree_display} && claude${c_reset}"
    return 0
  fi

  local session_name="agent-${name}"
  local launch_cmd="claude"

  if [[ "$mode" == "--codex" ]]; then
    launch_cmd="codex"
    session_name="codex-${name}"
  fi

  if tmux has-session -t "$session_name" 2>/dev/null; then
    print -r -- "  ${c_yellow}·${c_reset} session   ${c_dim}${session_name} already exists, attaching${c_reset}"
    tmux attach-session -t "$session_name"
  else
    tmux new-session -d -s "$session_name" -c "$worktree_path" "$launch_cmd"
    print -r -- "  ${c_green}✓${c_reset} session   ${c_dim}${session_name} (${launch_cmd})${c_reset}"
    print -r -- ""
    print -r -- "  ${c_dim}Attach: agent attach ${name}${c_reset}"
  fi
}

__agent_list() {
  setopt local_options nullglob
  local c_reset c_bold c_dim c_red c_green c_yellow c_blue c_magenta c_cyan c_gray
  __agent_init_colors

  local base_dir="${AGENT_WORKTREE_DIR}"
  local repo_root
  repo_root=$(git rev-parse --show-toplevel 2>/dev/null)
  if [[ -z "$repo_root" ]]; then
    print -r -- "  ${c_dim}(not in a git repo)${c_reset}"
    return
  fi

  local repo_name
  repo_name=$(basename "$repo_root")
  local repo_dir="${base_dir}/${repo_name}"
  if [[ ! -d "$repo_dir" ]]; then
    print -r -- "  ${c_dim}No agent worktrees in ${repo_name}.${c_reset}"
    return
  fi

  # Resolve base ref from the parent repo once (for F2 commits-ahead)
  local base_ref=""
  if git -C "$repo_root" rev-parse --verify --quiet main &>/dev/null; then
    base_ref="main"
  elif git -C "$repo_root" rev-parse --verify --quiet master &>/dev/null; then
    base_ref="master"
  fi

  # Pass 1: gather rows and compute column widths
  local -a rows_name rows_branch rows_status rows_ahead rows_dirty
  local max_name=4 max_branch=6 max_status=6
  local wt_name wt_branch wt_status install_pid install_state status_code
  local merge_base ahead dirty

  for dir in "$repo_dir"/*/; do
    [[ -d "$dir" ]] || continue
    wt_name=$(basename "$dir")
    wt_branch="agent/${wt_name}"

    wt_status="idle"
    install_state=""
    if tmux has-session -t "agent-${wt_name}" 2>/dev/null; then
      wt_status="claude"
    elif tmux has-session -t "codex-${wt_name}" 2>/dev/null; then
      wt_status="codex"
    elif tmux has-session -t "review-${wt_name}" 2>/dev/null; then
      wt_status="reviewing"
    else
      if [[ -f "${dir}.agent-install.pid" ]]; then
        install_pid=$(cat "${dir}.agent-install.pid" 2>/dev/null)
        if [[ -n "$install_pid" ]] && kill -0 "$install_pid" 2>/dev/null; then
          install_state="installing"
        fi
      fi
      if [[ -z "$install_state" && -f "${dir}.agent-install.status" ]]; then
        status_code=$(cat "${dir}.agent-install.status" 2>/dev/null)
        if [[ -n "$status_code" && "$status_code" != "0" ]]; then
          install_state="failed"
        fi
      fi
      if [[ "$install_state" == "installing" ]]; then
        wt_status="installing"
      elif [[ "$install_state" == "failed" ]]; then
        wt_status="failed"
      fi
    fi

    ahead=""
    if [[ -n "$base_ref" ]]; then
      merge_base=$(git -C "$dir" merge-base HEAD "$base_ref" 2>/dev/null)
      if [[ -n "$merge_base" ]]; then
        ahead=$(git -C "$dir" rev-list --count "${merge_base}..HEAD" 2>/dev/null)
      fi
    fi

    # Dirty = any tracked or untracked change EXCEPT our own metadata files
    # (.agent-install.pid and .agent-install.status live inside the worktree).
    dirty=""
    if git -C "$dir" status --porcelain 2>/dev/null \
         | grep -qv '\.agent-install\.\(pid\|status\)$'; then
      dirty="*"
    fi

    rows_name+=("$wt_name")
    rows_branch+=("$wt_branch")
    rows_status+=("$wt_status")
    rows_ahead+=("$ahead")
    rows_dirty+=("$dirty")

    (( ${#wt_name}   > max_name   )) && max_name=${#wt_name}
    (( ${#wt_branch} > max_branch )) && max_branch=${#wt_branch}
    (( ${#wt_status} > max_status )) && max_status=${#wt_status}
  done

  local n=${#rows_name[@]}
  if (( n == 0 )); then
    print -r -- "  ${c_dim}No agent worktrees in ${repo_name}.${c_reset}"
    return
  fi

  # Header + horizontal rule sized to longest row
  print -r -- "  ${c_bold}${c_cyan}agent worktrees${c_reset} ${c_dim}${repo_name} (${n})${c_reset}"
  local rule_width=$(( 2 + max_name + 1 + max_branch + 1 + max_status + 6 ))
  local rule="" i
  for (( i = 0; i < rule_width; i++ )); do
    rule="${rule}─"
  done
  print -r -- "  ${c_dim}${rule}${c_reset}"

  # Pass 2: print rows
  local glyph glyph_c status_c name_col branch_col status_col extras
  for (( i = 1; i <= n; i++ )); do
    wt_name="${rows_name[i]}"
    wt_branch="${rows_branch[i]}"
    wt_status="${rows_status[i]}"
    ahead="${rows_ahead[i]}"
    dirty="${rows_dirty[i]}"

    case "$wt_status" in
      claude|codex) glyph="●"; glyph_c="$c_green";   status_c="$c_green"   ;;
      reviewing)    glyph="⟳"; glyph_c="$c_magenta"; status_c="$c_magenta" ;;
      installing)   glyph="⠿"; glyph_c="$c_yellow";  status_c="$c_yellow"  ;;
      failed)       glyph="✗"; glyph_c="$c_red";     status_c="$c_red"     ;;
      *)            glyph="○"; glyph_c="$c_gray";    status_c="$c_gray"    ;;
    esac

    name_col=$(printf "%-${max_name}s" "$wt_name")
    branch_col=$(printf "%-${max_branch}s" "$wt_branch")
    status_col=$(printf "%-${max_status}s" "$wt_status")

    extras=""
    if [[ -n "$ahead" ]]; then
      extras="${c_dim}+${ahead}${c_reset}"
    fi
    if [[ -n "$dirty" ]]; then
      if [[ -n "$extras" ]]; then
        extras="${extras} ${c_yellow}${dirty}${c_reset}"
      else
        extras="${c_yellow}${dirty}${c_reset}"
      fi
    fi

    print -r -- "  ${glyph_c}${glyph}${c_reset} ${c_bold}${name_col}${c_reset} ${c_dim}${branch_col}${c_reset} ${status_c}${status_col}${c_reset} ${extras}"
  done
}

__agent_attach() {
  local c_reset c_bold c_dim c_red c_green c_yellow c_blue c_magenta c_cyan c_gray
  __agent_init_colors

  local name="$1"
  if [[ -z "$name" ]]; then
    print -r -- "${c_dim}Usage:${c_reset} agent attach <name>"
    return 1
  fi

  for prefix in "agent" "codex" "review"; do
    if tmux has-session -t "${prefix}-${name}" 2>/dev/null; then
      tmux attach-session -t "${prefix}-${name}"
      return 0
    fi
  done

  print -r -- "${c_red}✗${c_reset} no active session for ${c_bold}\"${name}\"${c_reset}"
  print -r -- "  ${c_dim}start one: agent spin ${name}${c_reset}"
  return 1
}

__agent_diff() {
  local c_reset c_bold c_dim c_red c_green c_yellow c_blue c_magenta c_cyan c_gray
  __agent_init_colors

  local name="$1"
  if [[ -z "$name" ]]; then
    print -r -- "${c_dim}Usage:${c_reset} agent diff <name>"
    return 1
  fi

  local repo_root
  repo_root=$(git rev-parse --show-toplevel 2>/dev/null)
  local worktree_path="${AGENT_WORKTREE_DIR}/$(basename "$repo_root")/${name}"

  if [[ ! -d "$worktree_path" ]]; then
    print -r -- "${c_red}✗${c_reset} no worktree ${c_bold}\"${name}\"${c_reset} found"
    return 1
  fi

  local base
  base=$(git -C "$worktree_path" merge-base HEAD main 2>/dev/null || \
         git -C "$worktree_path" merge-base HEAD master 2>/dev/null)

  print -r -- "${c_cyan}→${c_reset} Changes in ${c_bold}agent/${name}${c_reset}"
  if [[ -z "$base" ]]; then
    print -r -- "  ${c_dim}(no base branch found; neither main nor master exists)${c_reset}"
    return 1
  fi

  local commit_count file_count
  commit_count=$(git -C "$worktree_path" rev-list --count "${base}..HEAD" 2>/dev/null)
  file_count=$(git -C "$worktree_path" diff --name-only "$base" HEAD 2>/dev/null | wc -l | tr -d ' ')
  print -r -- "  ${c_dim}${commit_count} commit(s), ${file_count} file(s) changed${c_reset}"
  print -r -- ""

  local color_flag=""
  [[ -t 1 && -z "$NO_COLOR" && -z "$AGENT_NO_COLOR" ]] && color_flag="--color=always"
  git -C "$worktree_path" diff --stat $color_flag "$base" HEAD 2>/dev/null
  print -r -- ""
  print -r -- "  ${c_dim}Full diff: cd $(__agent_short_path "$worktree_path") && git diff ${base} HEAD${c_reset}"
}

__agent_review() {
  local c_reset c_bold c_dim c_red c_green c_yellow c_blue c_magenta c_cyan c_gray
  __agent_init_colors

  local name="$1"
  if [[ -z "$name" ]]; then
    print -r -- "${c_dim}Usage:${c_reset} agent review <name>"
    print -r -- "  Launches a fresh Claude Code session to adversarially review the agent's work."
    print -r -- "  Type /review inside the session to run the review skill."
    return 1
  fi

  local repo_root
  repo_root=$(git rev-parse --show-toplevel 2>/dev/null)
  local worktree_path="${AGENT_WORKTREE_DIR}/$(basename "$repo_root")/${name}"

  if [[ ! -d "$worktree_path" ]]; then
    print -r -- "${c_red}✗${c_reset} no worktree ${c_bold}\"${name}\"${c_reset} found"
    return 1
  fi

  local session_name="review-${name}"

  print -r -- "${c_cyan}→${c_reset} Launching adversarial review for ${c_bold}agent/${name}${c_reset}"

  if tmux has-session -t "$session_name" 2>/dev/null; then
    print -r -- "  ${c_yellow}·${c_reset} session ${c_dim}${session_name}${c_reset} already exists, attaching"
    tmux attach-session -t "$session_name"
    return 0
  fi

  tmux new-session -d -s "$session_name" -c "$worktree_path" "claude"
  print -r -- "  ${c_green}✓${c_reset} session ${c_dim}${session_name}${c_reset}"
  print -r -- "  ${c_dim}·${c_reset} attach: ${c_dim}tmux attach -t ${session_name}${c_reset}"
  print -r -- "  ${c_dim}·${c_reset} then run ${c_bold}/review${c_reset} inside the session"
}

__agent_merge() {
  local c_reset c_bold c_dim c_red c_green c_yellow c_blue c_magenta c_cyan c_gray
  __agent_init_colors

  local name="$1"
  if [[ -z "$name" ]]; then
    print -r -- "${c_dim}Usage:${c_reset} agent merge <name>"
    return 1
  fi

  local repo_root
  repo_root=$(git rev-parse --show-toplevel 2>/dev/null)
  local worktree_path="${AGENT_WORKTREE_DIR}/$(basename "$repo_root")/${name}"
  local branch="agent/${name}"

  if [[ ! -d "$worktree_path" ]]; then
    print -r -- "${c_red}✗${c_reset} no worktree ${c_bold}\"${name}\"${c_reset} found"
    return 1
  fi

  # Refuse on any dirty state EXCEPT our own .agent-install.* metadata files.
  # Matches the filter used in __agent_list's dirty check so the `*` marker
  # in `agent list` and the merge safety check stay consistent: if list shows
  # dirty, merge refuses.
  if git -C "$worktree_path" status --porcelain 2>/dev/null \
       | grep -qv '\.agent-install\.\(pid\|status\)$'; then
    print -r -- "${c_yellow}!${c_reset} worktree has uncommitted changes or untracked files"
    print -r -- "  ${c_dim}commit or remove them first: agent attach ${name}${c_reset}"
    return 1
  fi

  local current
  current=$(git symbolic-ref --short HEAD 2>/dev/null)
  print -r -- "${c_cyan}→${c_reset} Merging ${c_bold}${branch}${c_reset} into ${c_bold}${current}${c_reset}"
  git merge "$branch" --no-ff -m "merge: agent/${name} into ${current}"
  local rc=$?

  if [[ $rc -eq 0 ]]; then
    print -r -- "${c_green}✓${c_reset} Done. ${c_dim}Clean up: agent clean ${name}${c_reset}"
  else
    print -r -- "${c_red}✗${c_reset} Merge conflicts. Resolve manually."
    return 1
  fi
}

__agent_clean() {
  local c_reset c_bold c_dim c_red c_green c_yellow c_blue c_magenta c_cyan c_gray
  __agent_init_colors

  local name="$1"
  if [[ -z "$name" ]]; then
    print -r -- "${c_dim}Usage:${c_reset} agent clean <name>"
    return 1
  fi

  local repo_root
  repo_root=$(git rev-parse --show-toplevel 2>/dev/null)
  local worktree_path="${AGENT_WORKTREE_DIR}/$(basename "$repo_root")/${name}"
  local branch="agent/${name}"
  local cleaned=0

  print -r -- "${c_cyan}→${c_reset} Cleaning ${c_bold}\"${name}\"${c_reset}"

  for prefix in "agent" "codex" "review"; do
    if tmux has-session -t "${prefix}-${name}" 2>/dev/null; then
      tmux kill-session -t "${prefix}-${name}"
      print -r -- "  ${c_green}✓${c_reset} killed session ${c_dim}${prefix}-${name}${c_reset}"
      cleaned=1
    fi
  done

  # If `agent spin` recorded a background install PID, kill it (and children)
  # before touching the worktree. Prevents pnpm/npm/yarn racing with
  # `git worktree remove` and repopulating the directory after removal.
  if [[ -f "${worktree_path}/.agent-install.pid" ]]; then
    local install_pid
    install_pid=$(cat "${worktree_path}/.agent-install.pid" 2>/dev/null)
    if [[ -n "$install_pid" ]] && kill -0 "$install_pid" 2>/dev/null; then
      pkill -TERM -P "$install_pid" 2>/dev/null
      kill -TERM "$install_pid" 2>/dev/null
      local waited=0
      while kill -0 "$install_pid" 2>/dev/null && [[ $waited -lt 20 ]]; do
        sleep 0.1
        ((waited++))
      done
      kill -KILL "$install_pid" 2>/dev/null
      pkill -KILL -P "$install_pid" 2>/dev/null
      print -r -- "  ${c_green}✓${c_reset} stopped install ${c_dim}(pid ${install_pid})${c_reset}"
      cleaned=1
    fi
  fi

  if [[ -d "$worktree_path" ]]; then
    local removed=0
    if git worktree remove "$worktree_path" --force 2>/dev/null; then
      removed=1
    fi
    # Bounded rm -rf fallback for install stragglers, scoped to AGENT_WORKTREE_DIR.
    if [[ -d "$worktree_path" && "$worktree_path" == "${AGENT_WORKTREE_DIR}/"* ]]; then
      rm -rf "$worktree_path"
      removed=1
    fi
    if [[ "$removed" -eq 1 ]]; then
      print -r -- "  ${c_green}✓${c_reset} removed worktree"
      cleaned=1
    fi
  fi

  if git show-ref --verify --quiet "refs/heads/${branch}" 2>/dev/null; then
    if git branch -D "$branch" &>/dev/null; then
      print -r -- "  ${c_green}✓${c_reset} deleted branch ${c_dim}${branch}${c_reset}"
      cleaned=1
    fi
  fi

  if [[ "$cleaned" -eq 0 ]]; then
    print -r -- "  ${c_dim}· no session${c_reset}"
    print -r -- "  ${c_dim}· no worktree${c_reset}"
    print -r -- "  ${c_dim}· no branch${c_reset}"
    print -r -- "  ${c_red}✗${c_reset} nothing to clean"
    return 1
  fi
}

__agent_clean_all() {
  setopt local_options nullglob
  local c_reset c_bold c_dim c_red c_green c_yellow c_blue c_magenta c_cyan c_gray
  __agent_init_colors

  local repo_root
  repo_root=$(git rev-parse --show-toplevel 2>/dev/null)
  if [[ -z "$repo_root" ]]; then
    print -r -- "${c_red}✗${c_reset} not inside a git repository"
    return 1
  fi
  local repo_name
  repo_name=$(basename "$repo_root")
  local base_dir="${AGENT_WORKTREE_DIR}/${repo_name}"

  print -r -- "${c_cyan}→${c_reset} Cleaning all agent worktrees in ${c_bold}${repo_name}${c_reset}"

  local count=0
  if [[ -d "$base_dir" ]]; then
    for dir in "$base_dir"/*/; do
      [[ -d "$dir" ]] || continue
      __agent_clean "$(basename "$dir")"
      count=$((count + 1))
    done
  fi

  if (( count == 0 )); then
    print -r -- "  ${c_dim}· (none)${c_reset}"
  else
    print -r -- "${c_green}✓${c_reset} ${count} cleaned"
  fi
}
