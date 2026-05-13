# <------------------- SYSTEM DETECTION ------------------->

OS=$(uname -s)
ARCHITECTURE=$(uname -m)
KERNEL_INFO=$(uname -r)
HOSTNAME=$(uname -n)

_check_network() {
    curl -s --connect-timeout 2 -o /dev/null https://www.google.com || \
    curl -s --connect-timeout 2 -o /dev/null https://www.github.com
}

# Cross-platform clipboard write helper.
# Picks the right tool per OS and falls back to stdout if none present.
_clip() {
    if [[ "$OS" == "Darwin" ]] && command -v pbcopy &>/dev/null; then
        pbcopy
    elif grep -qi microsoft /proc/version 2>/dev/null && command -v clip.exe &>/dev/null; then
        clip.exe
    elif [ -n "$WAYLAND_DISPLAY" ] && command -v wl-copy &>/dev/null; then
        wl-copy
    elif command -v xclip &>/dev/null; then
        xclip -selection clipboard
    else
        cat
        echo "(no clipboard tool found; printed to stdout)" >&2
    fi
}

case "$OS" in
Darwin)
    if ! command -v brew &>/dev/null; then
        if [ ! -f "$HOME/.homebrew_install_attempted" ] && _check_network; then
            if /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" 2>/dev/null; then
                if [ -x "/opt/homebrew/bin/brew" ]; then
                    eval "$(/opt/homebrew/bin/brew shellenv)"
                    touch "$HOME/.homebrew_install_attempted"
                fi
            else
                touch "$HOME/.homebrew_install_attempted"
                echo "Warning: Homebrew installation failed. Install manually: https://brew.sh" >&2
            fi
        fi
    fi
    if command -v brew &>/dev/null; then
        HOMEBREW_PATH=$(brew --prefix)
    fi

    if [ ! -d "$HOME/.oh-my-zsh" ] && [ ! -f "$HOME/.ohmyzsh_install_attempted" ] && _check_network; then
        if sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended 2>/dev/null; then
            touch "$HOME/.ohmyzsh_install_attempted"
        else
            touch "$HOME/.ohmyzsh_install_attempted"
            echo "Warning: Oh-My-Zsh installation failed" >&2
        fi
    fi
    [ -d "$HOME/.oh-my-zsh" ] && export ZSH="$HOME/.oh-my-zsh"

    ;;

Linux)
    if grep -qi "microsoft" /proc/version && [ ! -f "/etc/arch-release" ]; then
        if [ ! -d "$HOME/.oh-my-zsh" ] && [ ! -f "$HOME/.ohmyzsh_install_attempted" ] && _check_network; then
            if sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended 2>/dev/null; then
                touch "$HOME/.ohmyzsh_install_attempted"
            else
                touch "$HOME/.ohmyzsh_install_attempted"
                echo "Warning: Oh-My-Zsh installation failed" >&2
            fi
        fi
        [ -d "$HOME/.oh-my-zsh" ] && export ZSH="$HOME/.oh-my-zsh"

    elif [[ "$ARCHITECTURE" == "aarch64" ]]; then
        if [ ! -d "$HOME/.oh-my-zsh" ] && [ ! -f "$HOME/.ohmyzsh_install_attempted" ] && _check_network; then
            if sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended 2>/dev/null; then
                touch "$HOME/.ohmyzsh_install_attempted"
            else
                touch "$HOME/.ohmyzsh_install_attempted"
                echo "Warning: Oh-My-Zsh installation failed" >&2
            fi
        fi
        [ -d "$HOME/.oh-my-zsh" ] && export ZSH="$HOME/.oh-my-zsh"

    elif [[ -f "/etc/arch-release" || "$KERNEL_INFO" =~ "arch" || "$HOSTNAME" == "archlinux" ]]; then
        if ! command -v paru &>/dev/null && [ ! -f "$HOME/.paru_install_attempted" ] && _check_network; then
            if sudo pacman -S --needed --noconfirm base-devel 2>/dev/null; then
                temp_dir=$(mktemp -d)
                if git clone https://aur.archlinux.org/paru.git "$temp_dir/paru" 2>/dev/null; then
                    (cd "$temp_dir/paru" && makepkg -si --noconfirm 2>/dev/null)
                    touch "$HOME/.paru_install_attempted"
                else
                    touch "$HOME/.paru_install_attempted"
                    echo "Warning: Paru installation failed" >&2
                fi
                rm -rf "$temp_dir"
            else
                touch "$HOME/.paru_install_attempted"
                echo "Warning: base-devel installation failed" >&2
            fi
        fi

        if [ ! -d "/usr/share/oh-my-zsh" ] && command -v paru &>/dev/null; then
            paru -S --noconfirm oh-my-zsh-git 2>/dev/null || echo "Warning: Oh-My-Zsh installation failed" >&2
        fi
        [ -d "/usr/share/oh-my-zsh" ] && export ZSH="/usr/share/oh-my-zsh"

    fi
    ;;
esac


# <------------------- UV INSTALL ------------------->

case "$OS" in
Darwin)
    if ! command -v uv &>/dev/null && command -v brew &>/dev/null; then
        brew install uv 2>/dev/null || \
            echo "Warning: uv installation failed" >&2
    fi
    ;;
Linux)
    if ! command -v uv &>/dev/null \
        && [ ! -f "$HOME/.uv_install_attempted" ] \
        && _check_network; then
        if curl -fsSL https://astral.sh/uv/install.sh | sh 2>/dev/null; then
            touch "$HOME/.uv_install_attempted"
        else
            touch "$HOME/.uv_install_attempted"
            echo "Warning: uv installation failed" >&2
        fi
    fi
    ;;
esac


# <------------------ Auto Start Tmux Session ------------------>

if [ -z "$INTELLIJ_ENVIRONMENT_READER" ]; then
    if command -v tmux &> /dev/null && [ -n "$PS1" ] && [ -t 1 ] && [[ ! "$TERM" =~ screen ]] && [[ ! "$TERM" =~ tmux ]] && [ -z "$TMUX" ]; then
      if ! tmux list-sessions &>/dev/null; then
        exec tmux new-session -s main
      else
        if tmux has-session -t main &>/dev/null; then
          attached_clients=$(tmux list-clients -t main 2>/dev/null | wc -l | tr -d ' ')

          if [ "$attached_clients" -eq 0 ]; then
            exec tmux attach-session -t main
          else
            detached_session=$(tmux list-sessions -F '#{session_name}:#{session_attached}' 2>/dev/null | grep ':0$' | grep -E '^(main|session[0-9]+):0$' | head -1 | cut -d: -f1)

            if [ -n "$detached_session" ]; then
              exec tmux attach-session -t "$detached_session"
            else
              new_session_name=$(tmux list-sessions -F "#S" | grep -E 'session[0-9]+$' | awk -F 'session' '{print $2}' | sort -n | tail -n1)

              if [ -z "$new_session_name" ]; then
                new_session_name=1
              else
                new_session_name=$((new_session_name + 1))
              fi

              exec tmux new-session -s "session$new_session_name"
            fi
          fi
        else
          exec tmux new-session -s main
        fi
      fi
    fi
fi


# <------------------ TMUX SESSION VARIABLE ------------------>

if [ -n "$TMUX" ]; then
    export TMUX_SESSION=$(tmux display-message -p '#S')
fi


# <------------------- OH-MY-ZSH AND PLUGINS ------------------->

zstyle ':omz:update' mode auto

export ZPLUG_HOME="$HOME/.zplug"

if [ ! -d "$ZPLUG_HOME" ] && _check_network; then
    if ! git clone https://github.com/zplug/zplug "$ZPLUG_HOME" 2>/dev/null; then
        echo "Warning: Zplug installation failed" >&2
        rm -rf "$ZPLUG_HOME"
    fi
fi

if [ -d "$ZPLUG_HOME" ] && [ -f "$ZPLUG_HOME/init.zsh" ]; then
    source "$ZPLUG_HOME"/init.zsh

    zplug "mafredri/zsh-async", from:github
    zplug "sindresorhus/pure", use:pure.zsh, from:github, as:theme
    zplug "chrissicool/zsh-256color", defer:2
    zplug "zsh-users/zsh-autosuggestions", defer:2
    zplug "zsh-users/zsh-syntax-highlighting", defer:2
    zplug load

    if ! zplug check --verbose; then
        printf "Install? [y/N]: "
        if read -q; then
            echo
            zplug install
        fi
    fi

    zstyle :prompt:pure:git:stash show yes
fi

[ -n "$ZSH" ] && [ -f "$ZSH/oh-my-zsh.sh" ] && source "$ZSH/oh-my-zsh.sh"


# <---------------------- INITIALIZATION ----------------------->

if command -v fastfetch &>/dev/null && [ -z "$FASTFETCH_SHOWN" ] && [[ "$PWD" != *"__worktrees"* ]]; then
    export FASTFETCH_SHOWN=1
    fastfetch --logo small --logo-padding-top 1 &
fi

# <-------------------- DIRENV ------------------>

if command -v direnv &>/dev/null; then
    eval "$(direnv hook zsh)"
fi


# <-------------------- AUTO-ACTIVATE PYTHON .venv ------------------>

# Manual activation (we don't `source .venv/bin/activate`) so the venv's
# activate script never modifies PS1. Pure reads $VIRTUAL_ENV_PROMPT for its
# venv indicator; we set it to ".venv" for a consistent display in every
# tmux window, regardless of whether the shell started inside or outside
# a project directory.
_venv_auto_activate() {
    local d=$PWD
    while [ "$d" != "/" ]; do
        if [ -x "$d/.venv/bin/python" ]; then
            if [ "$VIRTUAL_ENV" != "$d/.venv" ]; then
                # entering a venv (or switching between venvs)
                if [ -z "${_VENV_PATH_BACKUP:-}" ]; then
                    export _VENV_PATH_BACKUP="$PATH"
                fi
                export VIRTUAL_ENV="$d/.venv"
                export VIRTUAL_ENV_PROMPT=".venv"
                export PATH="$VIRTUAL_ENV/bin:$_VENV_PATH_BACKUP"
            fi
            return
        fi
        d=${d:h}
    done
    # leaving every venv: restore PATH and clear the markers
    if [ -n "${VIRTUAL_ENV:-}" ]; then
        if [ -n "${_VENV_PATH_BACKUP:-}" ]; then
            export PATH="$_VENV_PATH_BACKUP"
            unset _VENV_PATH_BACKUP
        fi
        unset VIRTUAL_ENV VIRTUAL_ENV_PROMPT
    fi
}

autoload -U add-zsh-hook
add-zsh-hook chpwd _venv_auto_activate

# Ensure Pure's venv indicator stays as ".venv" every prompt. Runs after
# direnv's precmd, so even if direnv resets state across .envrc transitions
# the indicator stays consistent.
_venv_sync_prompt() {
    if [ -n "${VIRTUAL_ENV:-}" ] && [ "${VIRTUAL_ENV_PROMPT:-}" != ".venv" ]; then
        export VIRTUAL_ENV_PROMPT=".venv"
    fi
}
add-zsh-hook precmd _venv_sync_prompt


# <-------------------- ALIASES -------------------->

alias mkdir='mkdir -p'
alias c='clear'
alias v='nvim'
alias vc='code'
alias lg='lazygit'
alias lzd='lazydocker'
alias zen-browser='io.github.zen_browser.zen'
alias h="history"
alias pn="pnpm"
alias wm='workmux'
alias gcopylog='git log --pretty=format:"%ad | %an%n%s%n%b%n" --date=short | _clip'
alias gt='git --no-pager log --graph --abbrev-commit --decorate --all --format="%C(bold blue)%h%C(reset) - %C(bold green)(%ar)%C(reset) %C(white)%s%C(reset) %C(dim white) - %an%C(reset)%C(auto) %d%C(reset)"'

gscopy() {
  local print_only=0 OPTIND opt
  while getopts ":ph" opt; do
    case "$opt" in
      p) print_only=1 ;;
      h)
        echo "Usage: gscopy [-p]" >&2
        echo "  -p  print prompt to stdout (no clipboard/status message)" >&2
        return 0
        ;;
      \?)
        echo "gscopy: invalid option -- -$OPTARG" >&2
        return 2
        ;;
    esac
  done
  shift $((OPTIND - 1))

  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "Not a git repo." >&2; return 1; }

  local branch files ins dels f target
  branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")

  files=$(
    {
      git status --porcelain=v1
      git ls-files --others --exclude-standard
    } | awk 'NF' | wc -l | tr -d ' '
  )

  read -r ins dels <<EOF_STATS
$(
  {
    git diff --cached --numstat
    git diff --numstat
    while IFS= read -r -d '' f; do
      if [[ -L "$f" ]]; then
        printf '1\t0\t%s\n' "$f"
      else
        git diff --no-index --numstat -- /dev/null "$f"
      fi
    done < <(git ls-files --others --exclude-standard -z)
  } | awk '{a+=$1; d+=$2} END {if (a=="") a=0; if (d=="") d=0; print a, d}'
)
EOF_STATS

  if (( files == 0 )); then
    {
      cat <<'EOF'
No changes in working tree.

Tip:
- Edit files or stage changes (e.g., `git add -p`) and re-run `gscopy`.
- Use `git status` to see what changed.
EOF
    } | {
      if (( print_only )); then cat; else _clip; fi
    }
    (( print_only )) || echo "No changes: copied a reminder to your clipboard." >&2
    return
  fi

  local worth_branch="no"
  if (( files >= 4 || (ins + dels) >= 80 )); then worth_branch="yes"; fi

  local scope_guess
  scope_guess=$(
    {
      git diff --name-only --cached
      git diff --name-only
    } | awk -F/ 'NF{print $1}' | sort | uniq -c | sort -nr | awk 'NR==1{print $2}'
  )
  [[ -z "$scope_guess" ]] && scope_guess="core"

  scope_guess=$(printf '%s' "$scope_guess" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9]+/-/g; s/^-+|-+$//g')

  local branch_suggestions=""
  if [[ "$worth_branch" == "yes" ]]; then
    branch_suggestions=$(
      printf '%s\n' \
        "feature/${scope_guess}-implementation" \
        "feature/${scope_guess}-refactor" \
        "bugfix/${scope_guess}-edge-cases"
    )
  fi

  {
    cat <<EOF
Please provide a concise commit message that adheres to the Conventional Commits standard.
Return ONLY:

1. The commit message enclosed in triple backticks.
2. A branch name on a separate line prefixed with \`branch:\`.

Branch naming rules:
- Use the suggested branch names in the context only as hints.
- Based on the context (scope, type of change, diff stats, current branch, etc.), choose or adapt the best possible branch name.
- Ensure the branch name follows professional standards: lowercase, hyphen-separated, scoped appropriately, and concise.

Formatting rules:
- **Title**: "<type>(<scope>): <subject>" — imperative mood, ≤ 50 chars.
- **Blank line** after the title.
- **Body**: wrap at ~72 columns; explain the *what* and *why*.
- Use bullets only when listing multiple distinct points.
- Common types: feat, fix, refactor, chore, docs, test, style, perf, ci, build, revert.

Template:
\`\`\`
<type>(${scope_guess}): <subject>

<Motivation/What & Why in 1–3 short lines.>

- Optional concise bullet
- Optional concise bullet
\`\`\`

Context:
- Current branch: ${branch}
- Working-tree diff stats: ${files} files, +${ins} / -${dels}
- Worth new branch for PR: ${worth_branch}
EOF

    if [[ "$worth_branch" == "yes" ]]; then
      printf -- "- Suggested branch names:\n%s\n" "$branch_suggestions"
    fi

    echo
    echo "Now, here are the changes:"
    git status --porcelain=v1
    echo

    git diff --cached --no-color
    git diff --no-color

    while IFS= read -r -d '' f; do
        echo
        if [[ -L "$f" ]]; then
            target=$(readlink "$f")
            printf 'diff --git a/%s b/%s\n' "$f" "$f"
            printf '%s\n' 'new file mode 120000'
            printf '%s\n' '--- /dev/null'
            printf '+++ b/%s\n' "$f"
            printf '%s\n' '@@ -0,0 +1 @@'
            printf '+%s\n' "$target"
        else
            git diff --no-color --no-index -- /dev/null "$f"
        fi
    done < <(git ls-files --others --exclude-standard -z)
  } | {
    if (( print_only )); then cat; else _clip; fi
  }

  (( print_only )) || echo "Commit prompt (all changes) copied to clipboard." >&2
}

if command -v nvim &>/dev/null; then
    export EDITOR='nvim'
fi

if command -v bat &>/dev/null; then
    bat_themes_dir="$(bat --config-dir)/themes"
    
    themes=(
        "Catppuccin Latte.tmTheme"
        "Catppuccin Frappe.tmTheme"
        "Catppuccin Macchiato.tmTheme"
        "Catppuccin Mocha.tmTheme"
    )
    
    all_themes_exist=true
    for theme in "${themes[@]}"; do
        if [ ! -f "$bat_themes_dir/$theme" ]; then
            all_themes_exist=false
            break
        fi
    done
    
    if [ "$all_themes_exist" = false ] && [ ! -f "$bat_themes_dir/.themes_installed" ] && _check_network; then
        mkdir -p "$bat_themes_dir"
        
        all_downloaded=true
        for theme in "${themes[@]}"; do
            theme_file="$bat_themes_dir/$theme"
            if [ ! -f "$theme_file" ]; then
                theme_url=$(echo "$theme" | sed 's/ /%20/g')
                if ! wget -q -O "$theme_file" "https://github.com/catppuccin/bat/raw/main/themes/$theme_url" 2>/dev/null; then
                    all_downloaded=false
                    rm -f "$theme_file"
                    break
                fi
            fi
        done
        
        if [ "$all_downloaded" = true ]; then
            bat cache --build >/dev/null 2>&1
            touch "$bat_themes_dir/.themes_installed"
        else
            echo "Warning: bat themes download incomplete" >&2
        fi
    fi
    export BAT_THEME="Catppuccin Macchiato"
fi

alias ls='eza -1 -A --git --icons=auto --sort=name --group-directories-first'
alias  l='eza -A -lh --git --icons=auto --sort=name --group-directories-first'
alias la='eza -lha --git --icons=auto --sort=name --group-directories-first'
alias ld='eza -A -lhD --git --icons=auto --sort=name'

function lt() {
    local depth="${1:-3}"
    eza -A --git --icons=auto --tree --level="$depth" --ignore-glob ".git|node_modules|*.log|*.tmp|dist|build|.DS_Store|*.swp|*.swo|.idea|__pycache__|coverage|env|venv|*.ttf|Icon?"
}

if [[ -f "/etc/arch-release" || "$KERNEL_INFO" =~ "arch" || "$HOSTNAME" == "archlinux" ]]; then
    alias un='$aurhelper -Rns'
    alias up='$aurhelper -Syu'
    alias pl='$aurhelper -Qs'
    alias pa='$aurhelper -Ss'
    alias pc='$aurhelper -Sc'
    alias po='$aurhelper -Qtdq | $aurhelper -Rns -'
fi

alias ..='cd ..'
alias ...='cd ../..'
alias .3='cd ../../..'
alias .4='cd ../../../..'
alias .5='cd ../../../../..'

alias ga="git add"
alias gap="git add -p"
alias gcm="git commit -m"
alias gra="git commit --amend --reset-author --no-edit"
alias unwip="git reset HEAD~"
alias uncommit="git reset HEAD~ --hard"

alias gco="git checkout"
alias gpfwl="git push --force-with-lease"
alias gprune="git branch --merged main | grep -v '^[ *]*main\$' | xargs git branch -d"

alias gs="git status"
alias gd="git diff"
alias gl="git lg"
alias glo="git log --oneline"
alias glt="git describe --tags --abbrev=0"

alias gpr="git pull -r"
alias gup="gco main && gpr && gco -"

alias hangon="git stash save -u"
alias gsp="git stash pop"

alias gclean="git clean -df"
alias cleanstate="unwip && git checkout . && git clean -df"

alias ta="tmux attach -t"
alias tn="tmux new-session -s "
alias tk="tmux kill-session -t "
alias tl="tmux list-sessions"
alias td="tmux detach"
alias tc="clear; tmux clear-history; clear"


# <------------------- CUSTOM FUNCTIONS ------------------->

if [[ -f "/etc/arch-release" || "$KERNEL_INFO" =~ "arch" || "$HOSTNAME" == "archlinux" ]]; then

    function command_not_found_handler {
        local purple='\e[1;35m' bright='\e[0;1m' green='\e[1;32m' reset='\e[0m'
        printf 'zsh: command not found: %s\n' "$1"
        local entries=( ${(f)"$(/usr/bin/pacman -F --machinereadable -- "/usr/bin/$1")"} )
        if (( ${#entries[@]} )) ; then
            printf "${bright}$1${reset} may be found in the following packages:\n"
            local pkg
            for entry in "${entries[@]}" ; do
                local fields=( ${(0)entry} )
                if [[ "$pkg" != "${fields[2]}" ]] ; then
                    printf "${purple}%s/${bright}%s ${green}%s${reset}\n" "${fields[1]}" "${fields[2]}" "${fields[3]}"
                fi
                printf '    /%s\n' "${fields[4]}"
                pkg="${fields[2]}"
            done
        fi
        return 127
    }

    if pacman -Qi yay &>/dev/null ; then
    aurhelper="yay"
    elif pacman -Qi paru &>/dev/null ; then
    aurhelper="paru"
    fi

    function in {
        local -a inPkg=("$@")
        local -a arch=()
        local -a aur=()

        for pkg in "${inPkg[@]}"; do
            if pacman -Si "${pkg}" &>/dev/null ; then
                arch+=("${pkg}")
            else 
                aur+=("${pkg}")
            fi
        done

        if [[ ${#arch[@]} -gt 0 ]]; then
            sudo pacman -S "${arch[@]}"
        fi

        if [[ ${#aur[@]} -gt 0 ]]; then
            ${aurhelper} -S "${aur[@]}"
        fi
    }
fi

if command -v fd &>/dev/null && command -v fzf &>/dev/null && command -v eza &>/dev/null; then
    fcd() {
        local depth="${1:-9}"
        local dir
        dir=$(fd --type d --hidden --max-depth "$depth" \
            --exclude '.git' \
            --exclude 'Photos' \
            --exclude '.local' \
            --exclude 'node_modules' \
            --exclude 'venv' \
            --exclude 'env' \
            --exclude '.venv' \
            --exclude 'build' \
            --exclude 'dist' \
            --exclude 'cache' \
            --exclude '.cache' \
            --exclude 'tmp' \
            --exclude '.tmp' \
            --exclude 'temp' \
            --exclude '.temp' \
            --exclude 'Trash' \
            --exclude '.Trash' \
            --follow \
            . 2>/dev/null | fzf --preview 'eza --tree --level 2 --color=always {}' +m) && cd "$dir" || return
    }
fi

command -v fd &>/dev/null && command -v fzf &>/dev/null &&
    command -v bat &>/dev/null && command -v nvim &>/dev/null &&
    function fzf_find_edit() {
        local file
        file=$(fd --type f --hidden --exclude .git --follow | fzf --preview 'bat --color=always {1}')
        [ -n "$file" ] && nvim "$file"
    }
alias f='fzf_find_edit'

function y() {
	local tmp="$(mktemp -t "yazi-cwd.XXXXXX")"
	yazi "$@" --cwd-file="$tmp"
	if cwd="$(cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
		builtin cd -- "$cwd" || exit
	fi
	rm -f -- "$tmp"
}


# <-------------------- FZF INITIALIZATION -------------------->

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
eval "$(fzf --zsh)"

fg="#CBE0F0"
bg="#011628"
bg_highlight="#143652"
purple="#B388FF"
blue="#06BCE4"
cyan="#2CF9ED"

export FZF_DEFAULT_OPTS="-m --height 70% --border --extended --layout=reverse --color=fg:${fg},hl:${purple},fg+:${fg},hl+:${purple},info:${blue},prompt:${cyan},pointer:${cyan},marker:${cyan},spinner:${cyan},header:${cyan}"

export FZF_DEFAULT_COMMAND="fd --hidden --strip-cwd-prefix --exclude .git"
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND="fd --type=d --hidden --strip-cwd-prefix --exclude .git"

_fzf_compgen_path() {
    fd --hidden --exclude .git . "$1"
}

_fzf_compgen_dir() {
    fd --type=d --hidden --exclude .git . "$1"
}

if [ ! -f ~/fzf-git.sh/fzf-git.sh ]; then
    git clone https://github.com/junegunn/fzf-git.sh.git ~/fzf-git.sh 2>/dev/null
fi
[ -f ~/fzf-git.sh/fzf-git.sh ] && source ~/fzf-git.sh/fzf-git.sh

export FZF_CTRL_T_OPTS="--preview 'bat -n --color=always --line-range :500 {}'"
export FZF_ALT_C_OPTS="--preview 'eza --tree --color=always {} | head -200'"

_fzf_comprun() {
    local command=$1
    shift

    case "$command" in
    cd) fzf --preview 'eza --tree --color=always {} | head -200' "$@" ;;
    export | unset) fzf --preview "eval 'echo \$'{}" "$@" ;;
    ssh) fzf --preview 'dig {}' "$@" ;;
    *) fzf --preview "bat -n --color=always --line-range :500 {}" "$@" ;;
    esac
}


# <-------------------- SCRIPTS -------------------->

if [ -d ~/scripts/scripts ]; then
    alias jcr="~/scripts/scripts/JavaProjectManager/JavaProjectManager.zsh"
    alias ccz="~/scripts/scripts/c_compiler.zsh"
    alias sqlurl="~/scripts/scripts/sqlurl.sh"
    alias getc="~/scripts/scripts/get_code_context.sh"
    alias nvims="~/scripts/scripts/nvim_surround_usage.sh"
    alias h2t="~/scripts/scripts/html-to-text/html-to-text.zsh"
    alias upall-mac="~/scripts/scripts/package_updater.zsh"
    alias upall-rpi="~/scripts/scripts/package_updater_rpi.zsh"
fi

if [ -d ~/.dotfiles/scripts ]; then
    alias qwen='~/.dotfiles/scripts/llama-qwen.sh'
    alias qwen-agent='~/.dotfiles/scripts/llama-qwen-agent.sh'
fi

[ -f "$HOME/.dotfiles/App-Configs/configs/MacOS-Bootstrap/mac_bootstrap.zsh" ] && alias macOS-bootstrap="$HOME/.dotfiles/App-Configs/configs/MacOS-Bootstrap/mac_bootstrap.zsh"

# [ -f "$HOME/.config/agent-worktrees/agent-worktrees.zsh" ] && \
#     source "$HOME/.config/agent-worktrees/agent-worktrees.zsh"

command -v workmux &>/dev/null && eval "$(workmux completions zsh)"


# <------------------- ENVIROMENT VARIABLES ------------------->

export PRETTIERD_DEFAULT_CONFIG="$HOME/.dotfiles/Formatting-Files/.prettierrc.json"

if [[ "$OS" == "Darwin" && -S "$HOME/.colima/default/docker.sock" ]]; then
    # Use /var/run/docker.sock so socket bind mounts work inside the Colima VM.
    if [[ ! -e /var/run/docker.sock ]]; then
        sudo ln -sf "$HOME/.colima/default/docker.sock" /var/run/docker.sock 2>/dev/null
    fi
    if [[ -e /var/run/docker.sock ]]; then
        export DOCKER_HOST="unix:///var/run/docker.sock"
    else
        export DOCKER_HOST="unix://$HOME/.colima/default/docker.sock"
    fi
fi

if [[ "$OS" == "Darwin" && "$ARCHITECTURE" == "arm64" ]]; then
    FONT_SIZE="17"
    BACKGROUND_OPACITY="0.7"
    MACOS_OPTION_AS_ALT="left"
elif [[ "$OS" == "Linux" && "$ARCHITECTURE" == "x86_64" ]]; then
    FONT_SIZE="9.5"
    BACKGROUND_OPACITY="0.8"
else
    FONT_SIZE="12"
    BACKGROUND_OPACITY="0.7"
fi

# ---

kitty_config_dir="$HOME/.dotfiles/Config/.config/kitty"
kitty_dynamic_conf="$kitty_config_dir/dynamic.conf"
new_kitty_config="font_size $FONT_SIZE
background_opacity $BACKGROUND_OPACITY
macos_option_as_alt $MACOS_OPTION_AS_ALT"

if [ ! -d "$kitty_config_dir" ]; then
    mkdir -p "$kitty_config_dir"
fi

if [ ! -f "$kitty_dynamic_conf" ] || [ "$(cat "$kitty_dynamic_conf" 2>/dev/null)" != "$new_kitty_config" ]; then
    printf "%s\n" "$new_kitty_config" > "$kitty_dynamic_conf"
fi

ghostty_config_dir="$HOME/.dotfiles/Config/.config/ghostty"
ghostty_dynamic_conf="$ghostty_config_dir/dynamic.conf"
new_ghostty_config="font-size = $FONT_SIZE
background-opacity = $BACKGROUND_OPACITY
macos-option-as-alt = $MACOS_OPTION_AS_ALT"

if [ ! -d "$ghostty_config_dir" ]; then
    mkdir -p "$ghostty_config_dir"
fi

if [ ! -f "$ghostty_dynamic_conf" ] || [ "$(cat "$ghostty_dynamic_conf" 2>/dev/null)" != "$new_ghostty_config" ]; then
    printf "%s\n" "$new_ghostty_config" > "$ghostty_dynamic_conf"
fi

# <-------------------- API KEY CONFIGURATIONS -------------------->

export_from_file() {
  local var="$1" file="$2"
  if [ -f "$file" ]; then
    export "$var"="$(tr -d '\r\n' < "$file")"
  else
    echo "$var not found at $file"
  fi
}

# export_from_file "ANTHROPIC_API_KEY" "$HOME/.config/anthropic/api_key"
# export_from_file "OPENAI_API_KEY" "$HOME/.config/openai/api_key"
export_from_file "FIRECRAWL_API_KEY" "$HOME/.config/firecrawl/api_key"
export_from_file "CONTEXT7_API_KEY" "$HOME/.config/context7/api_key"
export_from_file "BRAVE_API_KEY" "$HOME/.config/brave_search/api_key"
export_from_file "MAGIC_API_KEY" "$HOME/.config/magic/api_key"
export_from_file "GOOGLE_STITCH_API_KEY" "$HOME/.config/google_stitch/api_key"
export_from_file "GITHUB_PERSONAL_ACCESS_TOKEN" "$HOME/.config/github/token"
export_from_file "LINEAR_API_KEY" "$HOME/.config/linear/api_key"

export OLLAMA_API_BASE="http://127.0.0.1:11434"

# Keep pi-lens startup non-blocking. Use PI_LENS_STARTUP_MODE=full pi for
# one-off sessions where proactive startup scans and warmups are preferred.
export PI_LENS_STARTUP_MODE="quick"

# <-------------------- GENERAL CONFIGURATIONS -------------------->

export LESS="-R --mouse"

export PATH="$PATH:$HOME/.cache/lm-studio/bin"
export PATH="$PATH:$HOME/.pub-cache/bin"

# pnpm
export PNPM_HOME="$HOME/.local/share/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME/bin:"*) ;;
  *) export PATH="$PNPM_HOME/bin:$PATH" ;;
esac
# pnpm end

if [[ "$OS" == "Darwin" ]]; then
    export PATH="/opt/homebrew/opt/libpq/bin:$PATH"
fi

if grep -qi microsoft /proc/version 2>/dev/null; then
  export GALLIUM_DRIVER=d3d12
  export LIBVA_DRIVER_NAME=d3d12
fi


# Must run after every PATH mutation above so _VENV_PATH_BACKUP captures the full PATH.
_venv_auto_activate

# <-------------------- ZOXIDE -------------------->

if command -v zoxide &>/dev/null; then
    export _ZO_DOCTOR=0
    eval "$(zoxide init zsh --cmd cd)"
fi

