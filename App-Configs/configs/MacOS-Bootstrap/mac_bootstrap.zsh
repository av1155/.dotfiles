#!/usr/bin/env zsh
#
# mac_bootstrap.zsh — Bootstrap a fresh Apple Silicon MacBook.
#
# Idempotent. Re-running on a configured machine should be a no-op (or update
# pieces that have drifted). Designed to be readable end-to-end: each phase is
# a function called from main(), in order.
#
# Requirements:
#   - macOS on Apple Silicon (arm64).
#   - Internet access. Homebrew's installer pulls Xcode Command Line Tools.
#
# Usage:
#   ./mac_bootstrap.zsh [--yes] [--dry-run] [--no-llm] [--verbose] [-h|-V]
#
#   -y, --yes         Auto-accept all prompts (default timeouts also choose "yes")
#       --dry-run     Print actions without executing them
#       --no-llm      Skip the local LLM verification phase (LM Studio + llama.cpp)
#   -v, --verbose     Trace each command (set -x equivalent)
#   -h, --help        Show this help
#   -V, --version     Show script version

set -euo pipefail

# Resolve our own path before any function shadows $0 (zsh default).
readonly SCRIPT_PATH="${0:A}"

# =============================================================================
# Constants
# =============================================================================

readonly SCRIPT_VERSION="2.0.0"
readonly SCRIPT_NAME="mac_bootstrap.zsh"
readonly LOG_FILE="${TMPDIR:-/tmp}/mac_bootstrap-$(date +%Y%m%d-%H%M%S).log"

readonly HOMEBREW_PREFIX="/opt/homebrew"
readonly HOMEBREW_BIN="${HOMEBREW_PREFIX}/bin/brew"

readonly DOTFILES_DIR="${HOME}/.dotfiles"
readonly DOTFILES_REPO_SSH="git@github.com:av1155/.dotfiles.git"
readonly DOTFILES_REPO_HTTPS="https://github.com/av1155/.dotfiles.git"

readonly SCRIPTS_DIR="${HOME}/scripts"
readonly SCRIPTS_REPO_SSH="git@github.com:av1155/scripts.git"
readonly SCRIPTS_REPO_HTTPS="https://github.com/av1155/scripts.git"

readonly BREWFILE="${DOTFILES_DIR}/App-Configs/configs/MacOS-Bootstrap/Brewfile"

readonly NVIM_VENV="${HOME}/.local/share/nvim/venv"
readonly OPENJDK_SOURCE="${HOMEBREW_PREFIX}/opt/openjdk/libexec/openjdk.jdk"
readonly OPENJDK_LINK="/Library/Java/JavaVirtualMachines/openjdk.jdk"

readonly FONT_NAME="JetBrainsMono"
readonly FONT_VERSION="v3.2.1"
readonly FONT_DIR="${HOME}/Library/Fonts"
readonly FONT_PROBE="${FONT_DIR}/${FONT_NAME}NerdFont-Regular.ttf"

# Pnpm-managed global Node packages: TypeScript dev, LSP servers, dev CLIs.
readonly PNPM_GLOBALS=(
    typescript
    tsx
    prettier
    typescript-language-server
    "@vtsls/language-server"
    vscode-langservers-extracted
    bash-language-server
    yaml-language-server
    "@tailwindcss/language-server"
    "@playwright/cli"
    firecrawl-cli
    wrangler
)

readonly LM_STUDIO_APP="/Applications/LM Studio.app"
readonly LM_STUDIO_BIN="${HOME}/.cache/lm-studio/bin"
readonly LLAMA_LAUNCHER="${DOTFILES_DIR}/scripts/llama-qwen.sh"

# =============================================================================
# Runtime flags (overridden by CLI parsing)
# =============================================================================

ASSUME_YES=0
DRY_RUN=0
SKIP_LLM=0
VERBOSE=0

# =============================================================================
# Color / logging
# =============================================================================

if [[ -t 1 ]] && [[ -z "${NO_COLOR:-}" ]]; then
    readonly C_RED=$'\033[0;31m'
    readonly C_GREEN=$'\033[0;32m'
    readonly C_YELLOW=$'\033[0;33m'
    readonly C_BLUE=$'\033[0;34m'
    readonly C_PURPLE=$'\033[0;35m'
    readonly C_CYAN=$'\033[0;36m'
    readonly C_BOLD=$'\033[1m'
    readonly C_RESET=$'\033[0m'
else
    readonly C_RED="" C_GREEN="" C_YELLOW="" C_BLUE=""
    readonly C_PURPLE="" C_CYAN="" C_BOLD="" C_RESET=""
fi

_log() {
    local level="$1"; shift
    local color="$1"; shift
    local timestamp
    timestamp="$(date +%H:%M:%S)"
    printf '%s%s [%s]%s %s\n' "${color}" "${timestamp}" "${level}" "${C_RESET}" "$*" | tee -a "${LOG_FILE}" >&2
}

log_info()    { _log "INFO " "${C_BLUE}"   "$*"; }
log_warn()    { _log "WARN " "${C_YELLOW}" "$*"; }
log_error()   { _log "ERROR" "${C_RED}"    "$*"; }
log_success() { _log "OK   " "${C_GREEN}"  "$*"; }
log_debug()   { (( VERBOSE )) && _log "DEBUG" "${C_PURPLE}" "$*" || true; }

log_step() {
    local title="$*"
    local bar
    bar="$(printf '%*s' 78 '' | tr ' ' '─')"
    printf '\n%s%s%s\n%s%s  %s%s\n%s%s%s\n\n' \
        "${C_CYAN}" "${bar}" "${C_RESET}" \
        "${C_CYAN}${C_BOLD}" "▶" "${title}" "${C_RESET}" \
        "${C_CYAN}" "${bar}" "${C_RESET}" | tee -a "${LOG_FILE}"
}

# =============================================================================
# Run / dry-run wrapper
# =============================================================================

# Run a command, respecting --dry-run. Logs the command at debug level.
run() {
    log_debug "$ $*"
    if (( DRY_RUN )); then
        printf '%s[dry-run]%s %s\n' "${C_PURPLE}" "${C_RESET}" "$*"
        return 0
    fi
    "$@"
}

# Same as run() but for shell strings that need eval (use sparingly).
run_shell() {
    log_debug "$ $1"
    if (( DRY_RUN )); then
        printf '%s[dry-run]%s %s\n' "${C_PURPLE}" "${C_RESET}" "$1"
        return 0
    fi
    eval "$1"
}

# =============================================================================
# Trap handlers
# =============================================================================

on_error() {
    local exit_code=$?
    local line_no=$1
    log_error "Script failed at line ${line_no} (exit ${exit_code}). See log: ${LOG_FILE}"
}

trap 'on_error ${LINENO}' ERR

# =============================================================================
# CLI parsing
# =============================================================================

print_help() {
    sed -n '2,/^$/p' "${SCRIPT_PATH}" | sed 's/^# \{0,1\}//'
}

parse_args() {
    while (( $# )); do
        case "$1" in
            -y|--yes)        ASSUME_YES=1 ;;
            --dry-run)       DRY_RUN=1 ;;
            --no-llm)        SKIP_LLM=1 ;;
            -v|--verbose)    VERBOSE=1; set -x ;;
            -h|--help)       print_help; exit 0 ;;
            -V|--version)    echo "${SCRIPT_NAME} ${SCRIPT_VERSION}"; exit 0 ;;
            *)               log_error "Unknown argument: $1"; print_help; exit 2 ;;
        esac
        shift
    done
}

# =============================================================================
# Preflight checks
# =============================================================================

require_zsh() {
    if [[ -z "${ZSH_VERSION:-}" ]]; then
        log_error "This script requires Zsh."
        exit 1
    fi
}

require_apple_silicon() {
    local arch
    arch="$(uname -m)"
    if [[ "${arch}" != "arm64" ]]; then
        log_error "Apple Silicon (arm64) only. Detected: ${arch}"
        exit 1
    fi
}

require_network() {
    if ! curl -fsS --max-time 5 -o /dev/null https://github.com; then
        log_error "Cannot reach github.com. Check your internet connection."
        exit 1
    fi
}

prime_sudo() {
    log_info "Some steps may need sudo. Caching credentials now..."
    sudo -v
    # Keep-alive: refresh sudo timestamp until script exits.
    while true; do
        sudo -n true
        sleep 60
        kill -0 $$ 2>/dev/null || exit
    done 2>/dev/null &
}

# =============================================================================
# Prompts
# =============================================================================

# confirm "Question?" [default-yes=1|default-no=0] [timeout-seconds=10]
# Returns 0 (yes) / 1 (no). Honors --yes and CI-friendly defaults.
confirm() {
    local question="$1"
    local default_yes="${2:-1}"
    local timeout="${3:-10}"
    local hint response

    (( ASSUME_YES )) && return 0

    if (( default_yes )); then
        hint="[Y/n]"
    else
        hint="[y/N]"
    fi

    printf '%s%s %s (default in %ds): %s' "${C_YELLOW}" "${question}" "${hint}" "${timeout}" "${C_RESET}"

    if ! read -t "${timeout}" -r response; then
        echo
        response=""
    fi

    response="${response:-$( (( default_yes )) && echo y || echo n )}"

    [[ "${response:0:1}" == [Yy] ]]
}

# Read a secret without echoing.
prompt_secret() {
    local label="$1"
    local var
    printf '%s%s:%s ' "${C_YELLOW}" "${label}" "${C_RESET}"
    read -r -s var
    echo
    printf '%s' "${var}"
}

# =============================================================================
# Retry / network helpers
# =============================================================================

# retry max_attempts cmd...
retry() {
    local max="$1"; shift
    local attempt=1
    local delay=2
    while (( attempt <= max )); do
        if "$@"; then
            return 0
        fi
        log_warn "Attempt ${attempt}/${max} failed. Retrying in ${delay}s..."
        sleep "${delay}"
        attempt=$(( attempt + 1 ))
        delay=$(( delay * 2 ))
    done
    return 1
}

is_ssh_to_github_ok() {
    ssh -T -o StrictHostKeyChecking=accept-new -o ConnectTimeout=5 \
        git@github.com 2>&1 | grep -q "successfully authenticated"
}

# Clone a repo trying HTTPS (no auth) → SSH → HTTPS-with-PAT.
git_clone_resilient() {
    local ssh_url="$1"
    local https_url="$2"
    local target="$3"

    log_info "Cloning ${https_url} → ${target}"

    if retry 3 git clone "${https_url}" "${target}" 2>/dev/null; then
        return 0
    fi

    if is_ssh_to_github_ok; then
        log_info "Falling back to SSH..."
        if retry 3 git clone "${ssh_url}" "${target}"; then
            return 0
        fi
    fi

    log_warn "Public HTTPS and SSH both failed. Falling back to HTTPS + PAT."
    local pat
    pat="$(prompt_secret "GitHub Personal Access Token")"
    local pat_url="${https_url/https:\/\//https:\/\/${pat}@}"
    if retry 3 git clone "${pat_url}" "${target}"; then
        return 0
    fi

    log_error "Failed to clone after all fallbacks: ${https_url}"
    return 1
}

# =============================================================================
# Filesystem helpers
# =============================================================================

# Create a symlink only if it isn't already correct. Backs up real files.
ensure_symlink() {
    local source="$1"
    local target="$2"

    if [[ -L "${target}" && "$(readlink "${target}")" == "${source}" ]]; then
        log_debug "Symlink already correct: ${target}"
        return 0
    fi

    if [[ -e "${target}" && ! -L "${target}" ]]; then
        log_warn "Backing up ${target} → ${target}.bak"
        run mv "${target}" "${target}.bak"
    fi

    run mkdir -p "$(dirname "${target}")"
    run ln -sfn "${source}" "${target}"
    log_success "Symlinked ${target}"
}

# =============================================================================
# Phase 1 — Homebrew
# =============================================================================

phase_homebrew() {
    log_step "Homebrew"

    if command -v brew &>/dev/null; then
        log_info "Homebrew already installed. Updating..."
        run brew update
        run brew upgrade
        return 0
    fi

    if ! confirm "Install Homebrew?"; then
        log_error "Homebrew is required. Aborting."
        exit 1
    fi

    log_info "Installing Homebrew (this also installs Xcode Command Line Tools)..."
    run_shell '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'

    # Wire Homebrew into the shell for the remainder of this session.
    if [[ -x "${HOMEBREW_BIN}" ]]; then
        eval "$(${HOMEBREW_BIN} shellenv)"
        # And persist it in .zprofile if not already there.
        if ! grep -q "brew shellenv" "${HOME}/.zprofile" 2>/dev/null; then
            echo "eval \"\$(${HOMEBREW_BIN} shellenv)\"" >> "${HOME}/.zprofile"
        fi
    else
        log_error "Homebrew install completed but ${HOMEBREW_BIN} is missing."
        exit 1
    fi
}

# =============================================================================
# Phase 2 — Clone scripts + dotfiles
# =============================================================================

phase_clone_repos() {
    log_step "Clone scripts + dotfiles repositories"

    if [[ -d "${SCRIPTS_DIR}" ]]; then
        log_info "${SCRIPTS_DIR} exists, skipping."
    elif confirm "Clone scripts repository to ${SCRIPTS_DIR}?"; then
        git_clone_resilient "${SCRIPTS_REPO_SSH}" "${SCRIPTS_REPO_HTTPS}" "${SCRIPTS_DIR}"
    fi

    if [[ -d "${DOTFILES_DIR}" ]]; then
        log_info "${DOTFILES_DIR} exists, skipping."
    elif confirm "Clone .dotfiles repository to ${DOTFILES_DIR}?"; then
        git_clone_resilient "${DOTFILES_REPO_SSH}" "${DOTFILES_REPO_HTTPS}" "${DOTFILES_DIR}"
    fi
}

# =============================================================================
# Phase 3 — brew bundle
# =============================================================================

phase_brewfile() {
    log_step "Install software from Brewfile"

    if [[ ! -f "${BREWFILE}" ]]; then
        log_warn "No Brewfile at ${BREWFILE}. Skipping."
        return 0
    fi

    if ! confirm "Run 'brew bundle' against ${BREWFILE}?"; then
        log_warn "Brewfile install skipped."
        return 0
    fi

    if ! run brew bundle --file "${BREWFILE}"; then
        log_warn "Brewfile install had errors."
        confirm "Continue anyway?" 0 10 || exit 1
    fi
}

# =============================================================================
# Phase 4 — Oh My Zsh
# =============================================================================

phase_oh_my_zsh() {
    log_step "Oh My Zsh"

    if [[ -d "${HOME}/.oh-my-zsh" ]]; then
        log_info "Oh My Zsh already installed."
        return 0
    fi

    if ! confirm "Install Oh My Zsh?"; then
        log_warn "Oh My Zsh install skipped."
        return 0
    fi

    log_warn "After Oh My Zsh installs, re-run this script to finish setup (OMZ replaces the shell)."
    run_shell 'sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended'
}

# =============================================================================
# Phase 5 — Stow dotfiles
# =============================================================================

# Use stow to detect conflicts and back them up to *.bak so a re-stow succeeds.
backup_stow_conflicts() {
    log_info "Detecting stow conflicts..."
    local conflicts
    conflicts="$(cd "${DOTFILES_DIR}" && stow --restow --simulate */ 2>&1 | grep "cannot stow" || true)"
    if [[ -z "${conflicts}" ]]; then
        log_info "No conflicts."
        return 0
    fi

    while IFS= read -r line; do
        local target
        target="$(echo "${line}" | sed -n 's/.*over existing target \(.*\) since.*/\1/p')"
        [[ -z "${target}" ]] && continue
        local full="${HOME}/${target}"
        if [[ -f "${full}" && ! -L "${full}" ]]; then
            run mv "${full}" "${full}.bak"
            log_success "Backed up ${target} → ${target}.bak"
        fi
    done <<< "${conflicts}"
}

phase_stow() {
    log_step "Stow dotfiles into \$HOME"

    if [[ ! -d "${DOTFILES_DIR}" ]]; then
        log_warn "${DOTFILES_DIR} not present, skipping stow."
        return 0
    fi

    if ! command -v stow &>/dev/null; then
        log_error "GNU stow not found (should have been installed via Brewfile). Skipping."
        return 0
    fi

    backup_stow_conflicts

    log_info "Running stow --restow */ in ${DOTFILES_DIR}"
    ( cd "${DOTFILES_DIR}" && run stow --restow */ )
    log_success "Dotfiles stowed."
}

# =============================================================================
# Phase 6 — Auxiliary symlinks (gdu wrapper, bat themes)
# =============================================================================

phase_aux_symlinks() {
    log_step "Auxiliary symlinks + bat cache"

    # `gdu` from Homebrew installs as `gdu-go` to avoid clashing with coreutils.
    if [[ -x "${HOMEBREW_PREFIX}/bin/gdu-go" ]]; then
        ensure_symlink "${HOMEBREW_PREFIX}/bin/gdu-go" "${HOMEBREW_PREFIX}/bin/gdu"
    fi

    if command -v bat &>/dev/null; then
        log_info "Building bat theme cache..."
        run bat cache --build
    fi
}

# =============================================================================
# Phase 7 — Language toolchain (Homebrew node + pnpm globals, uv-managed nvim Python, Java)
# =============================================================================

phase_node_via_brew() {
    if ! command -v brew &>/dev/null; then
        log_warn "Homebrew not found. Skipping Node/pnpm setup."
        return 0
    fi

    if ! confirm "Install Node.js + pnpm via Homebrew (skipped silently if already installed)?"; then
        log_info "Skipping Homebrew Node/pnpm install."
        return 0
    fi

    run brew install node pnpm
}

phase_pnpm_globals() {
    if ! command -v pnpm &>/dev/null; then
        return 0
    fi

    if ! confirm "Install pnpm globals (TypeScript, LSP servers, dev CLIs)?"; then
        log_info "Skipping pnpm globals."
        return 0
    fi

    run pnpm add -g "${PNPM_GLOBALS[@]}"
}

phase_nvim_python_provider() {
    if ! command -v uv &>/dev/null; then
        log_warn "uv not found. Skipping Neovim Python provider setup."
        return 0
    fi

    if [[ -x "${NVIM_VENV}/bin/python" ]]; then
        log_info "Neovim Python provider venv already exists at ${NVIM_VENV}."
        return 0
    fi

    if ! confirm "Create dedicated Python venv for Neovim provider?"; then
        return 0
    fi

    run uv venv --python 3.12 "${NVIM_VENV}"
    run uv pip install --python "${NVIM_VENV}/bin/python" pynvim
}

phase_openjdk_link() {
    if [[ ! -d "${OPENJDK_SOURCE}" ]]; then
        log_warn "Brew openjdk not installed; skipping system symlink."
        return 0
    fi

    if [[ -L "${OPENJDK_LINK}" ]]; then
        log_info "openjdk system symlink already in place."
        return 0
    fi

    if ! confirm "Symlink Homebrew openjdk into /Library/Java/JavaVirtualMachines (sudo)?"; then
        return 0
    fi

    run sudo ln -sfn "${OPENJDK_SOURCE}" "${OPENJDK_LINK}"
    log_success "openjdk linked at ${OPENJDK_LINK}"
}

phase_flutter_doctor() {
    if ! command -v flutter &>/dev/null; then
        return 0
    fi

    if confirm "Run 'flutter doctor -v'?"; then
        run flutter doctor -v
    fi
}

phase_language_toolchain() {
    log_step "Language toolchain (Homebrew node+pnpm, uv-nvim-Python, openjdk symlink, Flutter)"

    phase_node_via_brew
    phase_pnpm_globals
    phase_nvim_python_provider
    phase_openjdk_link
    phase_flutter_doctor
}

# =============================================================================
# Phase 8 — GitHub CLI + Copilot
# =============================================================================

phase_github_cli() {
    log_step "GitHub CLI + Copilot extension"

    if ! command -v gh &>/dev/null; then
        log_warn "gh not installed; skipping."
        return 0
    fi

    if ! gh auth status &>/dev/null; then
        log_info "Not logged in to GitHub. Launching gh auth login..."
        run gh auth login
    else
        log_success "Already logged in to GitHub."
    fi

    if gh extension list 2>/dev/null | grep -q "gh-copilot"; then
        log_info "gh-copilot already installed."
    else
        if confirm "Install gh-copilot extension?"; then
            run gh extension install github/gh-copilot
        fi
    fi
}

# =============================================================================
# Phase 9 — Nerd Font
# =============================================================================

phase_nerd_font() {
    log_step "Nerd Font (${FONT_NAME})"

    if [[ -f "${FONT_PROBE}" ]]; then
        log_info "${FONT_NAME} Nerd Font already installed."
        return 0
    fi

    if ! confirm "Install ${FONT_NAME} Nerd Font?" 0; then
        return 0
    fi

    local url="https://github.com/ryanoasis/nerd-fonts/releases/download/${FONT_VERSION}/${FONT_NAME}.zip"
    local zip="${FONT_DIR}/${FONT_NAME}.zip"

    run mkdir -p "${FONT_DIR}"
    run curl -fL -o "${zip}" "${url}"
    run unzip -o "${zip}" -d "${FONT_DIR}"
    run rm -f "${zip}"
    log_success "${FONT_NAME} Nerd Font installed."
}

# =============================================================================
# Phase 10 — Neovim plugin sync (LazyVim)
# =============================================================================

phase_neovim_plugins() {
    log_step "Neovim plugin sync (LazyVim)"

    if ! command -v nvim &>/dev/null; then
        log_warn "nvim not found; skipping plugin sync."
        return 0
    fi

    log_info "Running 'nvim --headless +Lazy! sync +qa'..."
    run nvim --headless "+Lazy! sync" "+qa" 2>/dev/null || true
    log_success "Neovim plugins synced."
}

# =============================================================================
# Phase 11 — Local LLM stack (LM Studio + llama.cpp)
# =============================================================================
#
# LM Studio (cask) and llama.cpp (formula) are both installed by Brewfile.
# This phase verifies they're present, primes LM Studio's CLI (`lms`) so it's
# usable from the terminal, and points at the custom llama-server launcher.

phase_local_llm() {
    log_step "Local LLM stack (LM Studio + llama.cpp)"

    if (( SKIP_LLM )); then
        log_info "Skipped via --no-llm."
        return 0
    fi

    if [[ -d "${LM_STUDIO_APP}" ]]; then
        log_success "LM Studio.app present."
    else
        log_warn "LM Studio.app not found. Add 'cask \"lm-studio\"' to your Brewfile."
    fi

    if command -v llama-server &>/dev/null; then
        log_success "llama.cpp present: $(llama-server --version 2>&1 | head -1)"
    else
        log_warn "llama-server not found. Add 'brew \"llama.cpp\"' to your Brewfile."
    fi

    # Bootstrap LM Studio's CLI (`lms`). On first launch LM Studio drops a
    # bootstrap script under ~/.cache/lm-studio/bin; we just need to make sure
    # the user has launched it once so that `lms` is on PATH.
    if [[ -d "${LM_STUDIO_APP}" && ! -x "${LM_STUDIO_BIN}/lms" ]]; then
        if confirm "Launch LM Studio once to provision the 'lms' CLI?"; then
            run open -a "LM Studio"
            log_warn "Complete the LM Studio first-run setup, then press Enter."
            read -r
        fi
    fi

    if [[ -x "${LM_STUDIO_BIN}/lms" ]]; then
        log_success "LM Studio CLI ready: ${LM_STUDIO_BIN}/lms"
    fi

    # Make sure the custom llama-server launcher is executable.
    if [[ -f "${LLAMA_LAUNCHER}" ]]; then
        if [[ ! -x "${LLAMA_LAUNCHER}" ]]; then
            run chmod +x "${LLAMA_LAUNCHER}"
        fi
        log_info "Custom launcher: ${LLAMA_LAUNCHER}"
        log_info "Aliased to 'qwen' in .zshrc — runs Qwen3.6-35B-A3B on port 1235."
    fi

    log_info "Models live under ~/.cache/lm-studio/models/ — download via LM Studio UI."
}

# =============================================================================
# Phase 12 — Apps TODO list
# =============================================================================

phase_apps_todo() {
    log_step "Generate TODO list of manually-installed apps"

    local out="${HOME}/Desktop/apps_to_download.txt"

    cat > "${out}" <<'EOF'
Apps not installed by Homebrew — install manually.

Mac App Store (sign in to App Store):
  - Xcode
  - ChatGPT
  - OneDrive
  - WireGuard (free)
  - Numbers / Pages / Keynote (if needed)

Direct download:
  - Synology Drive Client
    https://www.synology.com/en-global/support/download

Audit which apps need this list with:
  comm -23 \
    <(ls /Applications | sed 's/.app$//' | sort -u) \
    <(brew list --cask | sort -u)
EOF

    log_success "TODO list saved to ${out}"
}

# =============================================================================
# main
# =============================================================================

main() {
    parse_args "$@"

    require_zsh
    require_apple_silicon
    require_network

    log_info "${SCRIPT_NAME} ${SCRIPT_VERSION} — log: ${LOG_FILE}"

    if (( DRY_RUN )); then
        log_warn "DRY RUN — no changes will be made."
    fi

    if ! confirm "Proceed with bootstrap?"; then
        log_warn "Aborted by user."
        exit 0
    fi

    prime_sudo

    phase_homebrew
    phase_clone_repos
    phase_brewfile
    phase_oh_my_zsh
    phase_stow
    phase_aux_symlinks
    phase_language_toolchain
    phase_github_cli
    phase_nerd_font
    phase_neovim_plugins
    phase_local_llm
    phase_apps_todo

    echo
    log_success "🚀 Bootstrap complete. Restart your terminal (or 'exec zsh') to pick up the full env."
    log_info "Log saved to ${LOG_FILE}"
}

main "$@"
