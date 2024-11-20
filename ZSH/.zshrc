# <------------------- SYSTEM DETECTION ------------------->
# Identify the operating system and architecture

OS=$(uname -s)
ARCHITECTURE=$(uname -m)
KERNEL_INFO=$(uname -r)
HOSTNAME=$(uname -n)

case "$OS" in
Darwin) # macOS

    # homebrew
    if ! command -v brew &>/dev/null; then
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
    HOMEBREW_PATH=$(brew --prefix)

    # Oh-my-zsh
    [ ! -d "$HOME/.oh-my-zsh" ] && sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    export ZSH="$HOME/.oh-my-zsh"

    # powerlevel10k
    [ ! -d "$HOMEBREW_PATH/share/powerlevel10k" ] && brew install powerlevel10k
    POWERLEVEL10K_DIR="$HOME/powerlevel10k"

    # miniforge3
    ! command -v conda &>/dev/null && brew install miniforge
    CONDA_PATH="$HOMEBREW_PATH/Caskroom/miniforge/base"
    ;;

Linux)
    if grep -qi "microsoft" /proc/version && [ ! -f "/etc/arch-release" ]; then
        # WSL detected and it's not Arch Linux

        # Oh-my-zsh
        [ ! -d "$HOME/.oh-my-zsh" ] && sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
        export ZSH="$HOME/.oh-my-zsh"

        # powerlevel10k
        POWERLEVEL10K_DIR="$HOME/powerlevel10k"
        [ ! -d "$POWERLEVEL10K_DIR" ] && git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ~/powerlevel10k

        # miniforge3
        if [ ! -d "$HOME/miniforge3" ]; then
            curl -L -O "https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-$(uname)-$(uname -m).sh"
            bash "Miniforge3-$(uname)-$(uname -m).sh"
        fi
        CONDA_PATH="$HOME/miniforge3"

    elif [[ "$ARCHITECTURE" == "aarch64" ]]; then 
        # Raspberry Pi 5 or other ARM-based Linux systems

        # Oh-my-zsh
        [ ! -d "$HOME/.oh-my-zsh" ] && sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
        export ZSH="$HOME/.oh-my-zsh"

        # powerlevel10k
        POWERLEVEL10K_DIR="$HOME/powerlevel10k"
        [ ! -d "$POWERLEVEL10K_DIR" ] && git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ~/powerlevel10k

        # miniforge3
        if [ ! -d "$HOME/miniforge3" ]; then
            curl -L -O "https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-$(uname)-$(uname -m).sh"
            bash "Miniforge3-$(uname)-$(uname -m).sh"
        fi
        CONDA_PATH="$HOME/miniforge3"

    elif [[ -f "/etc/arch-release" || "$KERNEL_INFO" =~ "arch" || "$HOSTNAME" == "archlinux" ]]; then
        # Arch Linux

        # Install paru if not installed
        if ! command -v paru &>/dev/null; then
            sudo pacman -S --needed base-devel
            git clone https://aur.archlinux.org/paru.git
            cd paru || return
            makepkg -si
            cd ~ || return
        fi

        # Oh-my-zsh
        [ ! -d "/usr/share/oh-my-zsh" ] && paru -S --noconfirm oh-my-zsh-git
        export ZSH="/usr/share/oh-my-zsh"

        # powerlevel10k
        POWERLEVEL10K_DIR="/usr/share/zsh-theme-powerlevel10k"
        [ ! -d "$POWERLEVEL10K_DIR" ] && paru -S --noconfirm zsh-theme-powerlevel10k-git

        # miniforge3
        if [ ! -d "$HOME/miniforge3" ]; then
            curl -L -O "https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-$(uname)-$(uname -m).sh"
            bash "Miniforge3-$(uname)-$(uname -m).sh"
        fi
        CONDA_PATH="$HOME/miniforge3"
    fi
    ;;
esac


# <------------------ Auto Start Tmux Session ------------------>

# Skip terminal-specific commands if run by IntelliJ
if [ -z "$INTELLIJ_ENVIRONMENT_READER" ]; then
    # Only run this code if it's an interactive shell (not when loaded by IntelliJ)
    
    if command -v tmux &> /dev/null && [ -n "$PS1" ] && [ -t 1 ] && [[ ! "$TERM" =~ screen ]] && [[ ! "$TERM" =~ tmux ]] && [ -z "$TMUX" ]; then
      # Check if any tmux sessions are running
      if ! tmux list-sessions &>/dev/null; then
        # No sessions exist, create or attach to "main"
        exec tmux new-session -s main
      else
        # Check if "main" exists
        if tmux has-session -t main &>/dev/null; then
          # If "main" exists, attach to it unless it's already attached
          if ! tmux list-clients -t main | grep -q .; then
            exec tmux attach-session -t main
          fi
        else
          # "main" session has been killed, recreate it
          exec tmux new-session -s main
        fi

        # If "main" is already attached or unavailable, create a new session with incrementing name
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

# Oh My Zsh configuration
zstyle ':omz:update' mode auto # Enable automatic updates without prompt

# ZPLUG
export ZPLUG_HOME="$HOME/.zplug"

# If Zplug is not already installed, clone it manually
if [ ! -d "$ZPLUG_HOME" ]; then
    git clone https://github.com/zplug/zplug "$ZPLUG_HOME"
fi

# Source Zplug and configure plugins
if [ -d "$ZPLUG_HOME" ]; then
    source $ZPLUG_HOME/init.zsh

    # Configuration (PLUGINS):
    zplug "mafredri/zsh-async", from:github
    zplug "sindresorhus/pure", use:pure.zsh, from:github, as:theme
    # zplug "plugins/git", from:oh-my-zsh, defer:2
    zplug "plugins/conda", from:oh-my-zsh, defer:2
    zplug "chrissicool/zsh-256color", defer:2
    zplug "zsh-users/zsh-autosuggestions", defer:2
    zplug "zsh-users/zsh-syntax-highlighting", defer:2
    zplug load

    # Clean up orphaned plugins (run manually if needed):
    # zplug clean

    # Install missing plugins
    if ! zplug check --verbose; then
        printf "Install? [y/N]: "
        if read -q; then
            echo
            zplug install
        fi
    fi

    # Pure Prompt Configuration
    zstyle :prompt:pure:git:stash show yes
fi

# Path to powerlevel10k theme
# source "$POWERLEVEL10K_DIR/powerlevel10k.zsh-theme"

# plugins=( git sudo zsh-256color zsh-autosuggestions zsh-syntax-highlighting )
source $ZSH/oh-my-zsh.sh

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh


# <---------------------- INITIALIZATION ----------------------->

# fastfetch if installed
if command -v fastfetch &>/dev/null; then
    fastfetch --logo small --logo-padding-top 1
fi

# NVM
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# Add gem folder's bin path to PATH
path+=(
    $(ruby -e 'puts File.join(Gem.user_dir, "bin")')
)

if ! gem which colorls &>/dev/null; then
    gem install colorls
fi

# colorls tab completion
source "$(dirname "$(gem which colorls)")/tab_complete.sh"


# <-------------------- CONDA INITIALIZATION ------------------>
export AUTO_ACTIVATE_CONDA=true # Set to true to auto-activate the base environment

# Set the Conda executable path
CONDA_EXEC_PATH="$CONDA_PATH/bin/conda"

# Initialize Conda
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

    if [ "$AUTO_ACTIVATE_CONDA" = "true" ]; then
        "$CONDA_EXEC_PATH" config --set auto_activate_base true
    else
        "$CONDA_EXEC_PATH" config --set auto_activate_base false
    fi
else
    echo "Conda executable not found at $CONDA_EXEC_PATH"
fi

unset __conda_setup
# <<< END CONDA INITIALIZATION


# <------------------ NVIM PYTHON PATH CONFIGURATION ------------------>

# Function to set NVIM_PYTHON_PATH
if command -v conda &>/dev/null; then
    set_python_path_for_neovim() {
        if [[ -n "$CONDA_PREFIX" ]]; then
            export NVIM_PYTHON_PATH="$CONDA_PREFIX/bin/python"
        else
            # Fallback to system Python (Python 3) if Conda is not active
            local system_python_path
            system_python_path=$(which python3)
            if [[ -z "$system_python_path" ]]; then
                echo "Python is not installed. Please install Python to use with Neovim."
            else
                export NVIM_PYTHON_PATH="$system_python_path"
            fi
        fi
    }

    # Initialize NVIM_PYTHON_PATH
    set_python_path_for_neovim

    # Hook into the precmd function
    function precmd_set_python_path() {
        if [[ "$PREV_CONDA_PREFIX" != "$CONDA_PREFIX" ]]; then
            set_python_path_for_neovim
            PREV_CONDA_PREFIX="$CONDA_PREFIX"
        fi
    }

    # Save the initial Conda prefix
    PREV_CONDA_PREFIX="$CONDA_PREFIX"

    # Add the hook to precmd
    autoload -U add-zsh-hook
    add-zsh-hook precmd precmd_set_python_path

else
    # Non-Conda environment: Check if Python is installed
    python_path=$(which python3)
    if [[ -z "$python_path" ]]; then
        echo "Python is not installed. Please install Python to use with Neovim."
    else
        export NVIM_PYTHON_PATH="$python_path"
    fi
fi

# Add the following line in `~/.config/nvim/lua/plugins/astrocore.lua` (vim.g.python3_host_prog = os.getenv "NVIM_PYTHON_PATH",) to set the dynamic Python executable for pynvim
# python3_host_prog = os.getenv "NVIM_PYTHON_PATH",


# <-------------------- ALIASES -------------------->
# General
alias mkdir='mkdir -p' # Always mkdir a path
alias c='clear'
alias v='nvim'
alias vc='code'
alias lg='lazygit'
alias lzd='lazydocker'
alias zen-browser='io.github.zen_browser.zen'
alias h="history"
alias pn="pnpm"
alias gscopy='(echo -e "Provide a commit message and a title for the following, enclosed within a code block:\n" && gs && gd) | pbcopy'
# alias fd='fdfind'

if command -v nvim &>/dev/null; then
    export EDITOR='nvim'
fi

# ----- Bat (better cat) -----
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

# ----thefuck alias ----
eval "$(thefuck --alias)"
eval "$(thefuck --alias fk)"

# ---- Zoxide (better cd) ----
eval "$(zoxide init zsh)"
alias cd="z"

# ---- GitHub CLI Copilot ----
eval "$(gh copilot alias -- zsh)"

# Listing
alias ls='eza -1 -A --git --icons=auto --sort=name --group-directories-first' # short list
alias  l='eza -A -lh --git --icons=auto --sort=name --group-directories-first' # long list
alias la='eza -lha --git --icons=auto --sort=name --group-directories-first' # long list all
alias ld='eza -A -lhD --git --icons=auto --sort=name' # long list dirs
# alias lt='eza -A --git --icons=auto --tree --level=3 --ignore-glob ".git|node_modules|*.log|*.tmp|dist|build|.DS_Store|*.swp|*.swo|.idea|__pycache__|coverage|env|venv|*.ttf|Icon?"'

function lt() {
    local depth="${1:-3}" # Use $1 if depth is passed, otherwise default to 3
    eza -A --git --icons=auto --tree --level="$depth" --ignore-glob ".git|node_modules|*.log|*.tmp|dist|build|.DS_Store|*.swp|*.swo|.idea|__pycache__|coverage|env|venv|*.ttf|Icon?"
}

# # Colorls
# alias ls="colorls -A --gs --sd"                   # Lists most files, directories first, with git status.
# alias la="colorls -oA --sd --gs"                  # Full listing of all files, directories first, with git status.
# alias lf="colorls -foa --sd --gs"                 # File-only listing, directories first, with git status.
# alias lt="colorls --tree=3 --sd --gs --hyperlink" # Tree view of directories with git status and hyperlinks.

# Pacman and AUR helpers (Linux-specific)
if [[ -f "/etc/arch-release" || "$KERNEL_INFO" =~ "arch" || "$HOSTNAME" == "archlinux" ]]; then
    alias un='$aurhelper -Rns' # uninstall package
    alias up='$aurhelper -Syu' # update system/package/aur
    alias pl='$aurhelper -Qs' # list installed package
    alias pa='$aurhelper -Ss' # list available package
    alias pc='$aurhelper -Sc' # remove unused cache
    alias po='$aurhelper -Qtdq | $aurhelper -Rns -' # remove unused packages, also try > $aurhelper -Qqd | $aurhelper -Rsu --print -
fi

# Quick directory navigation
alias ..='cd ..'
alias ...='cd ../..'
alias .3='cd ../../..'
alias .4='cd ../../../..'
alias .5='cd ../../../../..'

# Git Aliases
# Staging and Committing
alias ga="git add"                                      # Stage all changes
alias gap="git add -p"                                  # Stage changes interactively
alias gcm="git commit -m"                               # Commit with a message
alias gra="git commit --amend --reset-author --no-edit" # Amend the last commit without changing its message
alias unwip="git reset HEAD~"                           # Undo the last commit but keep changes
alias uncommit="git reset HEAD~ --hard"                 # Undo the last commit and discard changes

# Branch and Merge
alias gco="git checkout"                                                               # Switch branches or restore working tree files
alias gpfwl="git push --force-with-lease"                                              # Force push with lease for safety
alias gprune="git branch --merged main | grep -v '^[ *]*main\$' | xargs git branch -d" # Delete branches merged into main

# Repository Status and Inspection
alias gs="git status"                      # Show the working tree status
alias gl="git lg"                          # Show commit logs in a graph format
alias glo="git log --oneline"              # Show commit logs in a single line each
alias glt="git describe --tags --abbrev=0" # Describe the latest tag

# Remote Operations
alias gpr="git pull -r"              # Pull with rebase
alias gup="gco main && gpr && gco -" # Update the current branch with changes from main

# Stashing
alias hangon="git stash save -u" # Stash changes including untracked files
alias gsp="git stash pop"        # Apply stashed changes and remove them from the stash

# Cleanup
alias gclean="git clean -df"                                # Remove untracked files and directories
alias cleanstate="unwip && git checkout . && git clean -df" # Undo last commit, revert changes, and clean untracked files

# Tmux Aliases
alias ta="tmux attach -t"                   # Attaches tmux to a session (example: ta portal)
alias tn="tmux new-session -s "             # Creates a new session
alias tk="tmux kill-session -t "            # Kill session
alias tl="tmux list-sessions"               # Lists all ongoing sessions
alias td="tmux detach"                      # Detach from session
alias tc="clear; tmux clear-history; clear" # Tmux Clear pane


# <------------------- CUSTOM FUNCTIONS ------------------->

#Display Pokemon
#pokemon-colorscripts --no-title -r 1,3,6

if [[ -f "/etc/arch-release" || "$KERNEL_INFO" =~ "arch" || "$HOSTNAME" == "archlinux" ]]; then

    # Command Not Found Handler
    # In case a command is not found, try to find the package that has it
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

    # Detect the AUR wrapper
    if pacman -Qi yay &>/dev/null ; then
    aurhelper="yay"
    elif pacman -Qi paru &>/dev/null ; then
    aurhelper="paru"
    fi

    # Function to install packages
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

# FCD: Navigate directories using fd, fzf, and eza
if command -v fd &>/dev/null && command -v fzf &>/dev/null && command -v eza &>/dev/null; then
    fcd() {
        local depth="${1:-9}" # Default depth is 9, but can be overridden by first argument
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

# Fuzzy Finder + Nvim
# Searches files with 'fd', previews with 'bat', and opens in 'nvim' via 'fzf'.
command -v fd &>/dev/null && command -v fzf &>/dev/null &&
    command -v bat &>/dev/null && command -v nvim &>/dev/null &&
    function fzf_find_edit() {
        local file
        file=$(fd --type f --hidden --exclude .git --follow | fzf --preview 'bat --color=always {1}')
        [ -n "$file" ] && nvim "$file"
    }
alias f='fzf_find_edit'

# Yazi: A directory navigator with fzf
function y() {
	local tmp="$(mktemp -t "yazi-cwd.XXXXXX")"
	yazi "$@" --cwd-file="$tmp"
	if cwd="$(cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
		builtin cd -- "$cwd"
	fi
	rm -f -- "$tmp"
}


# <-------------------- FZF INITIALIZATION -------------------->
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
eval "$(fzf --zsh)"

# --- setup fzf theme ---
fg="#CBE0F0"           # Foreground color
bg="#011628"           # Background color [UNUSED]
bg_highlight="#143652" # Background highlight color [UNUSED]
purple="#B388FF"       # Purple color for highlights
blue="#06BCE4"         # Blue color for info
cyan="#2CF9ED"         # Cyan color for various elements

# Set default FZF options
export FZF_DEFAULT_OPTS="-m --height 70% --border --extended --layout=reverse --color=fg:${fg},hl:${purple},fg+:${fg},hl+:${purple},info:${blue},prompt:${cyan},pointer:${cyan},marker:${cyan},spinner:${cyan},header:${cyan}"

# -- Use fd instead of fzf --
export FZF_DEFAULT_COMMAND="fd --hidden --strip-cwd-prefix --exclude .git"
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND="fd --type=d --hidden --strip-cwd-prefix --exclude .git"

# Use fd (https://github.com/sharkdp/fd) for listing path candidates.
# - The first argument to the function ($1) is the base path to start traversal
# - See the source code (completion.{bash,zsh}) for the details.
_fzf_compgen_path() {
    fd --hidden --exclude .git . "$1"
}

# Use fd to generate the list for directory completion
_fzf_compgen_dir() {
    fd --type=d --hidden --exclude .git . "$1"
}

# https://github.com/junegunn/fzf-git.sh
if [ ! -f ~/fzf-git.sh/fzf-git.sh ]; then
    git clone https://github.com/junegunn/fzf-git.sh.git ~/fzf-git.sh
fi
source ~/fzf-git.sh/fzf-git.sh

export FZF_CTRL_T_OPTS="--preview 'bat -n --color=always --line-range :500 {}'"
export FZF_ALT_C_OPTS="--preview 'eza --tree --color=always {} | head -200'"

# Advanced customization of fzf options via _fzf_comprun function
# - The first argument to the function is the name of the command.
# - You should make sure to pass the rest of the arguments to fzf.
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
    alias h2t="~/scripts/scripts/html-to-text.zsh"
    alias upall-mac="~/scripts/scripts/package_updater.zsh"
    alias upall-rpi="~/scripts/scripts/package_updater_rpi.zsh"
fi

[ -f "$HOME/.dotfiles/App-Configs/configs/MacOS-Bootstrap/mac_bootstrap.zsh" ] && alias macOS-bootstrap="$HOME/.dotfiles/App-Configs/configs/MacOS-Bootstrap/mac_bootstrap.zsh"


# <------------------- ENVIROMENT VARIABLES ------------------->

export PRETTIERD_DEFAULT_CONFIG="$HOME/.dotfiles/Formatting-Files/.prettierrc.json"

# Detect the architecture
if [[ "$OS" == "Darwin" && "$ARCHITECTURE" == "arm64" ]]; then
    # macOS
    FONT_SIZE="17"
    BACKGROUND_OPACITY="0.7"
    MACOS_OPTION_AS_ALT="left"

elif [[ "$OS" == "Linux" && "$ARCHITECTURE" == "x86_64" ]]; then
    # Arch Linux
    FONT_SIZE="9.5"
    BACKGROUND_OPACITY="0.8"
else
    # Fallback
    FONT_SIZE="12"
    BACKGROUND_OPACITY="0.7"
fi

# Create the dynamic kitty config directory if it doesn't exist
kitty_config_dir="$HOME/.dotfiles/Config/.config/kitty"
if [ ! -d "$kitty_config_dir" ]; then
    mkdir -p "$kitty_config_dir"
fi

# Create the dynamic kitty config file
printf "font_size %s\nbackground_opacity %s\nmacos_option_as_alt %s" "$FONT_SIZE" "$BACKGROUND_OPACITY" "$MACOS_OPTION_AS_ALT" > "$kitty_config_dir/dynamic.conf"

# JAVA CLASSPATH CONFIGURATION
JAVA_CLASSPATH_PREFIX="$HOME/.dotfiles/Java-Jars/javaClasspath"

# Clear existing java classpath entries
export CLASSPATH=""

# Add each jar file found in the directory and its subdirectories to the CLASSPATH
for jar in "$JAVA_CLASSPATH_PREFIX"/*.jar; do
    if [ -e "$jar" ]; then
        if [ -z "$CLASSPATH" ]; then
            export CLASSPATH="$jar"
        else
            export CLASSPATH="$CLASSPATH:$jar"
        fi
    fi
done

# Finally, append the current directory to the CLASSPATH
export CLASSPATH="$CLASSPATH:."


# <-------------------- API KEY CONFIGURATIONS -------------------->
# Anthropic API Key
if [ -f "$HOME/.config/anthropic/api_key" ]; then
    ANTHROPIC_API_KEY=$(cat ~/.config/anthropic/api_key)
    export ANTHROPIC_API_KEY
else
    echo "Anthropic API key not found at $HOME/.config/anthropic/api_key"
fi


# OpenAI API Key
if [ -f "$HOME/.config/openai/api_key" ]; then
    OPENAI_API_KEY=$(cat ~/.config/openai/api_key)
    export OPENAI_API_KEY
else
    echo "OpenAI API key not found at $HOME/.config/openai/api_key"
fi


# <-------------------- GENERAL CONFIGURATIONS -------------------->

# fix paru: sudo ln -s /usr/lib/libalpm.so.15 /usr/lib/libalpm.so.14
# When paru is updated (fixed), then: sudo rm /usr/lib/libalpm.so.14

# Then reinstall paru:
# sudo pacman -S --needed base-devel
# git clone https://aur.archlinux.org/paru.git
# cd paru
# makepkg -si


# pnpm
export PNPM_HOME="$HOME/Library/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end


# Added by LM Studio CLI (lms)
export PATH="$PATH:/Users/andreaventi/.cache/lm-studio/bin"
