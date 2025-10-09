# <------------------- SYSTEM DETECTION ------------------->

OS=$(uname -s)
ARCHITECTURE=$(uname -m)
KERNEL_INFO=$(uname -r)
HOSTNAME=$(uname -n)

case "$OS" in
Darwin)
    if ! command -v brew &>/dev/null; then
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
    HOMEBREW_PATH=$(brew --prefix)

    [ ! -d "$HOME/.oh-my-zsh" ] && sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    export ZSH="$HOME/.oh-my-zsh"

    ! command -v conda &>/dev/null && brew install miniforge
    CONDA_PATH="$HOMEBREW_PATH/Caskroom/miniforge/base"
    ;;

Linux)
    if grep -qi "microsoft" /proc/version && [ ! -f "/etc/arch-release" ]; then
        [ ! -d "$HOME/.oh-my-zsh" ] && sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
        export ZSH="$HOME/.oh-my-zsh"

        if [ ! -d "$HOME/miniforge3" ]; then
            curl -L -O "https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-$(uname)-$(uname -m).sh"
            bash "Miniforge3-$(uname)-$(uname -m).sh"
        fi
        CONDA_PATH="$HOME/miniforge3"

    elif [[ "$ARCHITECTURE" == "aarch64" ]]; then 
        [ ! -d "$HOME/.oh-my-zsh" ] && sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
        export ZSH="$HOME/.oh-my-zsh"

        if [ ! -d "$HOME/miniforge3" ]; then
            curl -L -O "https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-$(uname)-$(uname -m).sh"
            bash "Miniforge3-$(uname)-$(uname -m).sh"
        fi
        CONDA_PATH="$HOME/miniforge3"

    elif [[ -f "/etc/arch-release" || "$KERNEL_INFO" =~ "arch" || "$HOSTNAME" == "archlinux" ]]; then
        if ! command -v paru &>/dev/null; then
            sudo pacman -S --needed base-devel
            git clone https://aur.archlinux.org/paru.git
            cd paru || return
            makepkg -si
            cd ~ || return
        fi

        [ ! -d "/usr/share/oh-my-zsh" ] && paru -S --noconfirm oh-my-zsh-git
        export ZSH="/usr/share/oh-my-zsh"

        if [ ! -d "$HOME/miniforge3" ]; then
            curl -L -O "https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-$(uname)-$(uname -m).sh"
            bash "Miniforge3-$(uname)-$(uname -m).sh"
        fi
        CONDA_PATH="$HOME/miniforge3"
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
          if ! tmux list-clients -t main | grep -q .; then
            exec tmux attach-session -t main
          fi
        else
          exec tmux new-session -s main
        fi

        new_session_name=$(tmux list-sessions -F "#S" | grep -E 'session[0-9]*' | awk -F 'session' '{print $2}' | sort -n | tail -n1)

        if [ -z "$new_session_name" ]; then
          new_session_name=1
        else
          new_session_name=$((new_session_name + 1))
        fi

        exec tmux new-session -s "session$new_session_name"
      fi
    fi
fi


# <------------------- OH-MY-ZSH AND PLUGINS ------------------->

zstyle ':omz:update' mode auto

export ZPLUG_HOME="$HOME/.zplug"

if [ ! -d "$ZPLUG_HOME" ]; then
    git clone https://github.com/zplug/zplug "$ZPLUG_HOME"
fi

if [ -d "$ZPLUG_HOME" ]; then
    source "$ZPLUG_HOME"/init.zsh

    zplug "mafredri/zsh-async", from:github
    zplug "sindresorhus/pure", use:pure.zsh, from:github, as:theme
    zplug "plugins/conda", from:oh-my-zsh, defer:2
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

source "$ZSH"/oh-my-zsh.sh


# <---------------------- INITIALIZATION ----------------------->

if command -v fastfetch &>/dev/null; then
    fastfetch --logo small --logo-padding-top 1
fi

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"


# <-------------------- CONDA INITIALIZATION ------------------>

export AUTO_ACTIVATE_CONDA=true
CONDA_EXEC_PATH="$CONDA_PATH/bin/conda"

if [ -f "$CONDA_EXEC_PATH" ]; then
    __conda_setup="$("$CONDA_EXEC_PATH" 'shell.zsh' 'hook' 2>/dev/null)"
    if [ $? -eq 0 ]; then
        eval "$__conda_setup"
    else
        CONDA_SH_PATH="$CONDA_PATH/etc/profile.d/conda.sh"
        if [ -f "$CONDA_SH_PATH" ]; then
            . "$CONDA_SH_PATH"
        else
            export PATH="$CONDA_PATH/bin:$PATH"
        fi
    fi

    if "$CONDA_EXEC_PATH" config --show | grep -q "auto_activate_base"; then
        config_key="auto_activate_base"
    else
        config_key="auto_activate"
    fi

    if [ "$AUTO_ACTIVATE_CONDA" = "true" ]; then
        "$CONDA_EXEC_PATH" config --set "$config_key" true
    else
        "$CONDA_EXEC_PATH" config --set "$config_key" false
    fi
else
    echo "Conda executable not found at $CONDA_EXEC_PATH"
fi

unset __conda_setup


# <------------------ NVIM PYTHON PATH CONFIGURATION ------------------>

if command -v conda &>/dev/null; then
    set_python_path_for_neovim() {
        if [[ -n "$CONDA_PREFIX" ]]; then
            export NVIM_PYTHON_PATH="$CONDA_PREFIX/bin/python"
        else
            local system_python_path
            system_python_path=$(which python3)
            if [[ -z "$system_python_path" ]]; then
                echo "Python is not installed. Please install Python to use with Neovim."
            else
                export NVIM_PYTHON_PATH="$system_python_path"
            fi
        fi
    }

    set_python_path_for_neovim

    function precmd_set_python_path() {
        if [[ "$PREV_CONDA_PREFIX" != "$CONDA_PREFIX" ]]; then
            set_python_path_for_neovim
            PREV_CONDA_PREFIX="$CONDA_PREFIX"
        fi
    }

    PREV_CONDA_PREFIX="$CONDA_PREFIX"

    autoload -U add-zsh-hook
    add-zsh-hook precmd precmd_set_python_path

else
    python_path=$(which python3)
    if [[ -z "$python_path" ]]; then
        echo "Python is not installed. Please install Python to use with Neovim."
    else
        export NVIM_PYTHON_PATH="$python_path"
    fi
fi

aider () {
  command conda run -n aider --no-capture-output aider "$@"
}


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
alias gcopylog='git log --pretty=format:"%ad | %an%n%s%n%b%n" --date=short | pbcopy'
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

  local branch files ins dels
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
      git diff --no-index --numstat /dev/null "$f"
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
      if (( print_only )); then cat; else pbcopy; fi
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
        git diff --no-color --no-index /dev/null "$f"
    done < <(git ls-files --others --exclude-standard -z)
  } | {
    if (( print_only )); then cat; else pbcopy; fi
  }

  (( print_only )) || echo "Commit prompt (all changes) copied to clipboard." >&2
}

if command -v nvim &>/dev/null; then
    export EDITOR='nvim'
fi

if [ ! -d "$(bat --config-dir)/themes" ]; then
    mkdir -p "$(bat --config-dir)/themes"

    wget -P "$(bat --config-dir)/themes" https://github.com/catppuccin/bat/raw/main/themes/Catppuccin%20Latte.tmTheme
    wget -P "$(bat --config-dir)/themes" https://github.com/catppuccin/bat/raw/main/themes/Catppuccin%20Frappe.tmTheme
    wget -P "$(bat --config-dir)/themes" https://github.com/catppuccin/bat/raw/main/themes/Catppuccin%20Macchiato.tmTheme
    wget -P "$(bat --config-dir)/themes" https://github.com/catppuccin/bat/raw/main/themes/Catppuccin%20Mocha.tmTheme

    bat cache --build
    bat --list-themes
fi
export BAT_THEME="Catppuccin Macchiato"

eval "$(thefuck --alias)"
eval "$(thefuck --alias fk)"

eval "$(zoxide init zsh)"
alias cd="z"

eval "$(gh copilot alias -- zsh)"

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
            . 2>/dev/null | fzf --preview 'eza --tree --level 2 --color=always {}' +m) && z "$dir" || return
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
    git clone https://github.com/junegunn/fzf-git.sh.git ~/fzf-git.sh
fi
source ~/fzf-git.sh/fzf-git.sh

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

[ -f "$HOME/.dotfiles/App-Configs/configs/MacOS-Bootstrap/mac_bootstrap.zsh" ] && alias macOS-bootstrap="$HOME/.dotfiles/App-Configs/configs/MacOS-Bootstrap/mac_bootstrap.zsh"


# <------------------- ENVIROMENT VARIABLES ------------------->

export PRETTIERD_DEFAULT_CONFIG="$HOME/.dotfiles/Formatting-Files/.prettierrc.json"

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

kitty_config_dir="$HOME/.dotfiles/Config/.config/kitty"
if [ ! -d "$kitty_config_dir" ]; then
    mkdir -p "$kitty_config_dir"
fi

printf "font_size %s\nbackground_opacity %s\nmacos_option_as_alt %s" "$FONT_SIZE" "$BACKGROUND_OPACITY" "$MACOS_OPTION_AS_ALT" > "$kitty_config_dir/dynamic.conf"

JAVA_CLASSPATH_PREFIX="$HOME/.dotfiles/Java-Jars/javaClasspath"

export CLASSPATH=""

for jar in "$JAVA_CLASSPATH_PREFIX"/*.jar; do
    if [ -e "$jar" ]; then
        if [ -z "$CLASSPATH" ]; then
            export CLASSPATH="$jar"
        else
            export CLASSPATH="$CLASSPATH:$jar"
        fi
    fi
done

export CLASSPATH="$CLASSPATH:."


# <-------------------- API KEY CONFIGURATIONS -------------------->

export_from_file() {
  local var="$1" file="$2"
  if [ -f "$file" ]; then
    export "$var"="$(tr -d '\r\n' < "$file")"
  else
    echo "$var not found at $file"
  fi
}

export_from_file "ANTHROPIC_API_KEY" "$HOME/.config/anthropic/api_key"
export_from_file "OPENAI_API_KEY" "$HOME/.config/openai/api_key"
export_from_file "FIRECRAWL_API_KEY" "$HOME/.config/firecrawl/api_key"
export_from_file "CONTEXT7_API_KEY" "$HOME/.config/context7/api_key"
export_from_file "BRAVE_API_KEY" "$HOME/.config/brave_search/api_key"
export_from_file "MAGIC_MCP_API_KEY" "$HOME/.config/magic_mcp/api_key"

export OLLAMA_API_BASE="http://127.0.0.1:11434"


# <-------------------- GENERAL CONFIGURATIONS -------------------->

export PATH="$PATH:$HOME/.cache/lm-studio/bin"
export PATH="$PATH:$HOME/.pub-cache/bin"

export PNPM_HOME="$HOME/.local/share/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac

export PATH="/opt/homebrew/opt/libpq/bin:$PATH"

if grep -qi microsoft /proc/version 2>/dev/null; then
  export GALLIUM_DRIVER=d3d12
  export LIBVA_DRIVER_NAME=d3d12
fi
