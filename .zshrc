# ------------------- PATH CONFIGURATIONS -------------------

# Path to your oh-my-zsh installation.
ZSH=/usr/share/oh-my-zsh/

# Path to powerlevel10k theme
source /usr/share/zsh-theme-powerlevel10k/powerlevel10k.zsh-theme


# <------------------ Auto Start Tmux Session ------------------>
if command -v tmux &> /dev/null && [ -n "$PS1" ] && [[ ! "$TERM" =~ screen ]] && [[ ! "$TERM" =~ tmux ]] && [ -z "$TMUX" ]; then
  # Check if any tmux sessions are running
  if ! tmux /bin/ls &>/dev/null; then
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

# colorls tab completion
source $(dirname $(gem which colorls))/tab_complete.sh


# <-------------------- CONDA INITIALIZATION ------------------>

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$('/home/archbtw/miniforge3/bin/conda' 'shell.zsh' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "/home/archbtw/miniforge3/etc/profile.d/conda.sh" ]; then
        . "/home/archbtw/miniforge3/etc/profile.d/conda.sh"
    else
        export PATH="/home/archbtw/miniforge3/bin:$PATH"
    fi
fi
unset __conda_setup

if [ -f "/home/archbtw/miniforge3/etc/profile.d/mamba.sh" ]; then
    . "/home/archbtw/miniforge3/etc/profile.d/mamba.sh"
fi
# <<< conda initialize <<<


# <------------------ NVIM PYTHON PATH CONFIGURATION ------------------>

# Check if Conda is installed
if command -v conda >/dev/null 2>&1; then
    # Conda-specific configuration

    # Function to set NVIM_PYTHON_PATH
    set_python_path_for_neovim() {
        if [[ -n "$CONDA_PREFIX" ]]; then
            export NVIM_PYTHON_PATH="$CONDA_PREFIX/bin/python"
        else
            # Fallback to system Python (Python 3) if Conda is not active
            local system_python_path=$(which python3)
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

# Add the following line in `~/.config/nvim/lua/user/options.lua` to set the dynamic Python executable for pynvim
# python3_host_prog = "$NVIM_PYTHON_PATH",


# <------------------- OH-MY-ZSH AND PLUGINS ------------------->

plugins=(git sudo zsh-256color zsh-autosuggestions zsh-syntax-highlighting)
source $ZSH/oh-my-zsh.sh

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh


# <-------------------- ALIASES -------------------->
# General
alias mkdir='mkdir -p' # Always mkdir a path
alias c='clear'
alias vim='nvim'
alias vc='code'
alias lg='lazygit'
alias zen-browser='io.github.zen_browser.zen'
# alias fd='fdfind'

# ----- Bat (better cat) -----
export BAT_THEME="Catppuccin Macchiato"

# ----thefuck alias ----
eval "$(thefuck --alias)"
eval "$(thefuck --alias fk)"

# ---- Zoxide (better cd) ----
eval "$(zoxide init zsh)"
alias cd="z"

# ---- GitHuB CLI Copilot ----
eval "$(gh copilot alias -- zsh)"

# Listing
alias  l='eza -lh  --icons=auto' # long list
alias ls='eza -1   --icons=auto' # short list
alias ll='eza -lha --icons=auto --sort=name --group-directories-first' # long list all
alias ld='eza -lhD --icons=auto' # long list dirs
alias lt='eza --icons=auto --tree' # list folder as tree

# Pacman and AUR helpers
alias un='$aurhelper -Rns' # uninstall package
alias up='$aurhelper -Syu' # update system/package/aur
alias pl='$aurhelper -Qs' # list installed package
alias pa='$aurhelper -Ss' # list available package
alias pc='$aurhelper -Sc' # remove unused cache
alias po='$aurhelper -Qtdq | $aurhelper -Rns -' # remove unused packages, also try > $aurhelper -Qqd | $aurhelper -Rsu --print -

# Quick directory navigation
alias ..='cd ..'
alias ...='cd ../..'
alias .3='cd ../../..'
alias .4='cd ../../../..'
alias .5='cd ../../../../..'

# Fuzzy Finder + Nvim
# Searches files with 'fd', previews with 'bat', and opens in 'nvim' via 'fzf'.
command -v fd &>/dev/null && command -v fzf &>/dev/null &&
    command -v bat &>/dev/null && command -v vim &>/dev/null &&
    alias f="fd --type f --hidden --exclude .git --follow | fzf --preview 'bat --color=always {1}' | xargs nvim"

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

# Other Aliases
alias pear="git pair "                                                # Set up git pair for pair programming (requires git-pair gem)
alias rspec_units="rspec --exclude-pattern \"**/features/*_spec.rb\"" # Run RSpec tests excluding feature specs
alias awsume=". awsume sso;. awsume"                                  # Alias for AWS role assumption

# Tmux Aliases
alias ta="tmux attach -t"                   # Attaches tmux to a session (example: ta portal)
alias tn="tmux new-session -s "             # Creates a new session
alias tk="tmux kill-session -t "            # Kill session
alias tl="tmux list-sessions"               # Lists all ongoing sessions
alias td="tmux detach"                      # Detach from session
alias tc="clear; tmux clear-history; clear" # Tmux Clear pane

# Colorls
alias ls="colorls -A --gs --sd"                   # Lists most files, directories first, with git status.
alias la="colorls -oA --sd --gs"                  # Full listing of all files, directories first, with git status.
alias lf="colorls -foa --sd --gs"                 # File-only listing, directories first, with git status.
alias lt="colorls --tree=3 --sd --gs --hyperlink" # Tree view of directories with git status and hyperlinks.


# <------------------- CUSTOM FUNCTIONS ------------------->

#Display Pokemon
#pokemon-colorscripts --no-title -r 1,3,6

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

# FCD: Navigate directories using fd, fzf, and colorls
if command -v fd &>/dev/null && command -v fzf &>/dev/null && command -v colorls &>/dev/null; then
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

# Sourced + Aliased Scripts ------------------------------------------------------->
[ -f ~/scripts/scripts/JavaProjectManager/JavaProjectManager.zsh ] && alias jcr="~/scripts/scripts/JavaProjectManager/JavaProjectManager.zsh"
[ -f ~/scripts/scripts/sqlurl.sh ] && alias sqlurl="~/scripts/scripts/sqlurl.sh"
[ -f ~/scripts/scripts/nvim_surround_usage.sh ] && alias nvims="~/scripts/scripts/nvim_surround_usage.sh"
[ -f ~/scripts/scripts/html-to-text.zsh ] && alias h2t="~/scripts/scripts/html-to-text.zsh"


# <------------------- ENVIROMENT VARIABLES ------------------->

# Define the base directory where the jars are stored
JAVA_CLASSPATH_PREFIX="/home/archbtw/javaClasspath"

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


# <-------------------- API KEY CONFIGURATIONS -------------------->
# Anthropic API Key
ANTHROPIC_API_KEY=$(cat ~/.config/anthropic/api_key)
export ANTHROPIC_API_KEY

# OpenAI API Key
OPENAI_API_KEY=$(cat ~/.config/openai/api_key)
export OPENAI_API_KEY
