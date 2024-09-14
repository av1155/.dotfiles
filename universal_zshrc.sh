# <------------------- SYSTEM DETECTION ------------------->
# Identify the operating system and architecture
case "$(uname -s)" in
    Darwin) # macOS
        export ZSH="$HOME/.oh-my-zsh"
        POWERLEVEL10K_DIR="$HOME/.oh-my-zsh/themes/powerlevel10k"
        AUR_HELPER_NOT_AVAILABLE=true
        ;;
    Linux)
        if [[ "$(uname -m)" == "aarch64" ]]; then
            # Raspberry Pi 5
            export ZSH="/usr/share/oh-my-zsh"
            POWERLEVEL10K_DIR="/usr/share/zsh-theme-powerlevel10k"
            AUR_HELPER_NOT_AVAILABLE=true
        else
            # Arch Linux (WSL or Hyprland)
            export ZSH="/usr/share/oh-my-zsh"
            POWERLEVEL10K_DIR="/usr/share/zsh-theme-powerlevel10k"
        fi
        ;;
    CYGWIN*|MINGW32*|MSYS*|MINGW*) # Windows (WSL or native)
        export ZSH="$HOME/.oh-my-zsh"
        POWERLEVEL10K_DIR="$HOME/.oh-my-zsh/themes/powerlevel10k"
        AUR_HELPER_NOT_AVAILABLE=true
        ;;
esac

# <------------------- OH-MY-ZSH AND PLUGINS ------------------->
source $ZSH/oh-my-zsh.sh
source $POWERLEVEL10K_DIR/powerlevel10k.zsh-theme
plugins=(git sudo zsh-256color zsh-autosuggestions zsh-syntax-highlighting)
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh


# <------------------ AUTO START TMUX SESSION ------------------>
if command -v tmux &> /dev/null && [ -n "$PS1" ] && [[ ! "$TERM" =~ screen ]] && [[ ! "$TERM" =~ tmux ]] && [ -z "$TMUX" ]; then
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

# <------------------- FASTFETCH ------------------->
if command -v fastfetch &>/dev/null; then
    fastfetch --logo small --logo-padding-top 1
fi

# <------------------- NVM INITIALIZATION ------------------->
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# Add gem folder's bin path to PATH
path+=(
    $(ruby -e 'puts File.join(Gem.user_dir, "bin")')
)

# Enable colorls tab completion if installed
if command -v colorls &>/dev/null; then
    source $(dirname $(gem which colorls))/tab_complete.sh
fi


# <------------------- CONDA INITIALIZATION ------------------->
if command -v conda >/dev/null 2>&1; then
    __conda_setup="$('conda' 'shell.zsh' 'hook' 2> /dev/null)"
    if [ $? -eq 0 ]; then
        eval "$__conda_setup"
    else
        if [ -f "$HOME/miniforge3/etc/profile.d/conda.sh" ]; then
            source "$HOME/miniforge3/etc/profile.d/conda.sh"
        fi
    fi
    unset __conda_setup
fi

# Optional: Mamba initialization if installed
if [ -f "$HOME/miniforge3/etc/profile.d/mamba.sh" ]; then
    source "$HOME/miniforge3/etc/profile.d/mamba.sh"
fi

# <------------------- NVIM PYTHON CONFIGURATION ------------------->
set_python_path_for_neovim() {
    if [[ -n "$CONDA_PREFIX" ]]; then
        export NVIM_PYTHON_PATH="$CONDA_PREFIX/bin/python"
    else
        local system_python_path=$(which python3)
        export NVIM_PYTHON_PATH="$system_python_path"
    fi
}

if command -v conda >/dev/null 2>&1; then
    set_python_path_for_neovim
    function precmd_set_python_path() {
        if [[ "$PREV_CONDA_PREFIX" != "$CONDA_PREFIX" ]]; then
            set_python_path_for_neovim
            PREV_CONDA_PREFIX="$CONDA_PREFIX"
        fi
    }
    autoload -U add-zsh-hook
    add-zsh-hook precmd precmd_set_python_path
else
    python_path=$(which python3)
    export NVIM_PYTHON_PATH="$python_path"
fi


# <------------------- ALIASES ------------------->
alias mkdir='mkdir -p'
alias c='clear'
alias v='nvim'
alias vc='code'
alias lg='lazygit'
alias lzd='lazydocker'
alias zen-browser='io.github.zen_browser.zen'

# Bat (better cat)
export BAT_THEME="Catppuccin Macchiato"

# Thefuck alias
eval "$(thefuck --alias)"
eval "$(thefuck --alias fk)"

# Zoxide
eval "$(zoxide init zsh)"
alias cd="z"

# GitHub CLI Copilot
eval "$(gh copilot alias -- zsh)"

# Listings
alias ls='eza -1 -A --git --icons=auto --sort=name --group-directories-first'
alias l='eza -A -lh --git --icons=auto --sort=name --group-directories-first'
alias la='eza -lha --git --icons=auto --sort=name --group-directories-first'
alias ld='eza -A -lhD --git --icons=auto --sort=name'
alias lt='eza -A --git --icons=auto --tree --level=2'

# Pacman and AUR helpers (for Arch Linux only)
if [[ "$AUR_HELPER_NOT_AVAILABLE" != "true" ]]; then
    alias un='$aurhelper -Rns'
    alias up='$aurhelper -Syu'
    alias pl='$aurhelper -Qs'
    alias pa='$aurhelper -Ss'
    alias pc='$aurhelper -Sc'
    alias po='$aurhelper -Qtdq | $aurhelper -Rns -'
fi

# Directory navigation
alias ..='cd ..'
alias ...='cd ../..'
alias .3='cd ../../..'
alias .4='cd ../../../..'
alias .5='cd ../../../../..'

# Git Aliases
alias ga="git add"
alias gap="git add -p"
alias gcm="git commit -m"
alias gra="git commit --amend --reset-author --no-edit"
alias unwip="git reset HEAD~"
alias uncommit="git reset HEAD~ --hard"

# Branch and Merge
alias gco="git checkout"
alias gpfwl="git push --force-with-lease"
alias gprune="git branch --merged main | grep -v '^[ *]*main\$' | xargs git branch -d"

# Git Status and Inspection
alias gs="git status"
alias gl="git lg"
alias glo="git log --oneline"
alias glt="git describe --tags --abbrev=0"

# Remote Operations
alias gpr="git pull -r"
alias gup="gco main && gpr && gco -"

# Stashing
alias hangon="git stash save -u"
alias gsp="git stash pop"

# Git Cleanup
alias gclean="git clean -df"
alias cleanstate="unwip && git checkout . && git clean -df"

# Tmux Aliases
alias ta="tmux attach -t"
alias tn="tmux new-session -s"
alias tk="tmux kill-session -t"
alias tl="tmux list-sessions"
alias td="tmux detach"
alias tc="clear; tmux clear-history; clear"

# <------------------- CUSTOM FUNCTIONS ------------------->
# Command Not Found Handler (for Arch Linux)
if [[ "$AUR_HELPER_NOT_AVAILABLE" != "true" ]]; then
    function command_not_found_handler {
        local purple='\e[1;35m' bright='\e[0;1m' green='\e[1;32m' reset='\e[0m'
        printf 'zsh: command not found: %s\n' "$1"
        local entries=( ${(f)"$(/usr/bin/pacman -F --machinereadable -- "/usr/bin/$1")"} )
        if (( ${#entries[@]} )) ; then
            printf "${bright}$1${reset} may be found in the following packages:\n"
            local pkg
            for entry in "${entries[@]}" ; do
                local fields=( ${(0)entry} )
                if [[ "$pkg" != "${fields[2]}" ]]; then
                    printf "${purple}%s/${bright}%s ${green}%s${reset}\n" "${fields[1]}" "${fields[2]}" "${fields[3]}"
                fi
                printf '    /%s\n' "${fields[4]}"
                pkg="${fields[2]}"
            done
        fi
        return 127
    }
fi

# Install Packages Function (for Arch Linux only)
if [[ "$AUR_HELPER_NOT_AVAILABLE" != "true" ]]; then
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

# FCD: Navigate directories using fd, fzf, and colorls
if command -v fd &>/dev/null && command -v fzf &>/dev/null && command -v colorls &>/dev/null; then
    fcd() {
        local depth="${1:-9}"
        local dir
        dir=$(fd --type d --hidden --max-depth "$depth" \
            --exclude '.git' \
            --exclude 'node_modules' \
            --exclude 'venv' \
            --exclude 'env' \
            . 2>/dev/null | fzf --preview 'eza --tree --level 2 --color=always {}' +m) && z "$dir" || return
    }
fi

# Fuzzy Finder + Nvim
if command -v fd &>/dev/null && command -v fzf &>/dev/null && command -v bat &>/dev/null && command -v nvim &>/dev/null; then
    function fzf_find_edit() {
        local file
        file=$(fd --type f --hidden --exclude .git --follow | fzf --preview 'bat --color=always {1}')
        [ -n "$file" ] && nvim "$file"
    }
    alias f='fzf_find_edit'
fi

# Yazi: A directory navigator with fzf
function y() {
	local tmp="$(mktemp -t "yazi-cwd.XXXXXX")"
	yazi "$@" --cwd-file="$tmp"
	if cwd="$(cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
		builtin cd -- "$cwd"
	fi
	rm -f -- "$tmp"
}

# <------------------- FZF INITIALIZATION ------------------->
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
eval "$(fzf --zsh)"

# FZF Theme and options
fg="#CBE0F0"
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

# <------------------- SCRIPTS ------------------->
[ -f ~/scripts/scripts/JavaProjectManager/JavaProjectManager.zsh ] && alias jcr="~/scripts/scripts/JavaProjectManager/JavaProjectManager.zsh"
[ -f ~/scripts/scripts/sqlurl.sh ] && alias sqlurl="~/scripts/scripts/sqlurl.sh"
[ -f ~/scripts/scripts/nvim_surround_usage.sh ] && alias nvims="~/scripts/scripts/nvim_surround_usage.sh"
[ -f ~/scripts/scripts/html-to-text.zsh ] && alias h2t="~/scripts/scripts/html-to-text.zsh"


# <------------------- ENVIRONMENT VARIABLES ------------------->
JAVA_CLASSPATH_PREFIX="/home/archbtw/javaClasspath"
export CLASSPATH=""

for jar in "$JAVA_CLASSPATH_PREFIX"/*.jar; do
    [ -e "$jar" ] && export CLASSPATH="$CLASSPATH:$jar"
done


# <------------------- API KEYS ------------------->
ANTHROPIC_API_KEY=$(cat ~/.config/anthropic/api_key)
export ANTHROPIC_API_KEY

OPENAI_API_KEY=$(cat ~/.config/openai/api_key)
export OPENAI_API_KEY
