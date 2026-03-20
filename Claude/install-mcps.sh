#!/usr/bin/env bash
set -euo pipefail

if [[ -t 1 ]]; then
    C_RESET=$'\033[0m'
    C_BOLD=$'\033[1m'
    C_DIM=$'\033[2m'
    C_RED=$'\033[31m'
    C_GREEN=$'\033[32m'
    C_YELLOW=$'\033[33m'
    C_BLUE=$'\033[34m'
    C_CYAN=$'\033[36m'
else
    C_RESET=''
    C_BOLD=''
    C_DIM=''
    C_RED=''
    C_GREEN=''
    C_YELLOW=''
    C_BLUE=''
    C_CYAN=''
fi

MCP_NAMES=(
    git
    time
    fetch
    firecrawl
    brave-search
    duckduckgo
    context7
    playwright
    github
)

need_cmd() {
    command -v "$1" >/dev/null 2>&1 || {
        printf '%b\n' "${C_RED}${C_BOLD}Error:${C_RESET} missing required command: ${C_YELLOW}$1${C_RESET}" >&2
        exit 1
    }
}

have_env() {
    local name="$1"
    [[ -n "${!name:-}" ]]
}

remove_mcp_if_present() {
    local name="$1"
    claude mcp remove "$name" -s user >/dev/null 2>&1 || true
}

print_header() {
    echo
    printf '%b\n' "${C_CYAN}${C_BOLD}Claude Code MCP Manager${C_RESET}"
    printf '%b\n' "${C_DIM}Manage Claude Code MCP servers from one place.${C_RESET}"
    printf '%b\n' "${C_BLUE}===============================================${C_RESET}"
    echo
}

print_menu() {
    printf '%b\n' "${C_BOLD}Available actions${C_RESET}"
    printf '%b\n' "  ${C_GREEN}1)${C_RESET} Install all MCPs"
    printf '%b\n' "  ${C_YELLOW}2)${C_RESET} Uninstall all MCPs"
    printf '%b\n' "  ${C_CYAN}3)${C_RESET} Reinstall all MCPs"
    printf '%b\n' "  ${C_BLUE}4)${C_RESET} List configured MCPs"
    printf '%b\n' "  ${C_BLUE}5)${C_RESET} Show details for one MCP"
    printf '%b\n' "  ${C_DIM}6)${C_RESET} Exit"
    echo
}

confirm() {
    local prompt="${1:-Are you sure? [y/N]: }"
    read -r -p "$prompt" reply
    [[ "$reply" =~ ^[Yy]([Ee][Ss])?$ ]]
}

check_base_requirements() {
    need_cmd claude
    need_cmd npx
    need_cmd uvx
}

install_git() {
    printf '%b\n' "${C_GREEN}==>${C_RESET} Installing MCP: ${C_BOLD}git${C_RESET}"
    remove_mcp_if_present git
    claude mcp add --scope user --transport stdio git -- uvx mcp-server-git
}

install_time() {
    printf '%b\n' "${C_GREEN}==>${C_RESET} Installing MCP: ${C_BOLD}time${C_RESET}"
    remove_mcp_if_present time
    claude mcp add --scope user --transport stdio time -- uvx mcp-server-time
}

install_fetch() {
    printf '%b\n' "${C_GREEN}==>${C_RESET} Installing MCP: ${C_BOLD}fetch${C_RESET}"
    remove_mcp_if_present fetch
    claude mcp add --scope user --transport stdio fetch -- uvx mcp-server-fetch
}

install_firecrawl() {
    if ! have_env FIRECRAWL_API_KEY; then
        printf '%b\n' "${C_YELLOW}==>${C_RESET} Skipping ${C_BOLD}firecrawl${C_RESET}: ${C_DIM}FIRECRAWL_API_KEY is not set${C_RESET}"
        return
    fi
    printf '%b\n' "${C_GREEN}==>${C_RESET} Installing MCP: ${C_BOLD}firecrawl${C_RESET}"
    remove_mcp_if_present firecrawl
    claude mcp add-json --scope user firecrawl \
        "{\"type\":\"stdio\",\"command\":\"npx\",\"args\":[\"-y\",\"firecrawl-mcp\"],\"env\":{\"FIRECRAWL_API_KEY\":\"${FIRECRAWL_API_KEY}\"}}"
}

install_brave() {
    if ! have_env BRAVE_API_KEY; then
        printf '%b\n' "${C_YELLOW}==>${C_RESET} Skipping ${C_BOLD}brave-search${C_RESET}: ${C_DIM}BRAVE_API_KEY is not set${C_RESET}"
        return
    fi
    printf '%b\n' "${C_GREEN}==>${C_RESET} Installing MCP: ${C_BOLD}brave-search${C_RESET}"
    remove_mcp_if_present brave-search
    claude mcp add-json --scope user brave-search \
        "{\"type\":\"stdio\",\"command\":\"npx\",\"args\":[\"-y\",\"@brave/brave-search-mcp-server\"],\"env\":{\"BRAVE_API_KEY\":\"${BRAVE_API_KEY}\"}}"
}

install_duckduckgo() {
    printf '%b\n' "${C_GREEN}==>${C_RESET} Installing MCP: ${C_BOLD}duckduckgo${C_RESET}"
    remove_mcp_if_present duckduckgo
    claude mcp add --scope user --transport stdio duckduckgo -- uvx duckduckgo-mcp-server
}

install_context7() {
    if ! have_env CONTEXT7_API_KEY; then
        printf '%b\n' "${C_YELLOW}==>${C_RESET} Skipping ${C_BOLD}context7${C_RESET}: ${C_DIM}CONTEXT7_API_KEY is not set${C_RESET}"
        return
    fi
    printf '%b\n' "${C_GREEN}==>${C_RESET} Installing MCP: ${C_BOLD}context7${C_RESET}"
    remove_mcp_if_present context7
    claude mcp add-json --scope user context7 \
        "{\"type\":\"stdio\",\"command\":\"npx\",\"args\":[\"-y\",\"@upstash/context7-mcp\"],\"env\":{\"CONTEXT7_API_KEY\":\"${CONTEXT7_API_KEY}\"}}"
}

install_playwright() {
    printf '%b\n' "${C_GREEN}==>${C_RESET} Installing MCP: ${C_BOLD}playwright${C_RESET}"
    remove_mcp_if_present playwright
    claude mcp add --scope user --transport stdio playwright -- \
        npx @playwright/mcp@latest --output-dir .
}

install_github() {
    if ! have_env GITHUB_PERSONAL_ACCESS_TOKEN; then
        printf '%b\n' "${C_YELLOW}==>${C_RESET} Skipping ${C_BOLD}github${C_RESET}: ${C_DIM}GITHUB_PERSONAL_ACCESS_TOKEN is not set${C_RESET}"
        return
    fi
    printf '%b\n' "${C_GREEN}==>${C_RESET} Installing MCP: ${C_BOLD}github${C_RESET}"
    remove_mcp_if_present github
    claude mcp add --scope user --transport http github \
        https://api.githubcopilot.com/mcp \
        --header "Authorization: Bearer $GITHUB_PERSONAL_ACCESS_TOKEN"
}

install_all() {
    check_base_requirements
    printf '%b\n' "${C_BOLD}Starting MCP installation...${C_RESET}"
    install_git
    install_time
    install_fetch
    install_firecrawl
    install_brave
    install_duckduckgo
    install_context7
    install_playwright
    install_github
    echo
    printf '%b\n' "${C_GREEN}${C_BOLD}Done.${C_RESET}"
    claude mcp list
}

uninstall_all() {
    need_cmd claude
    printf '%b\n' "${C_BOLD}Removing managed MCPs...${C_RESET}"
    for name in "${MCP_NAMES[@]}"; do
        printf '%b\n' "${C_YELLOW}==>${C_RESET} Removing MCP: ${C_BOLD}$name${C_RESET}"
        claude mcp remove "$name" -s user >/dev/null 2>&1 || true
    done
    echo
    printf '%b\n' "${C_GREEN}${C_BOLD}Done.${C_RESET}"
    claude mcp list || true
}

show_one() {
    need_cmd claude
    read -r -p "Enter MCP name: " name
    [[ -n "${name:-}" ]] || {
        printf '%b\n' "${C_RED}No MCP name entered.${C_RESET}"
        return
    }
    claude mcp get "$name"
}

main() {
    print_header
    while true; do
        print_menu
        read -r -p "Choose an option [1-6]: " choice
        echo
        case "$choice" in
        1) confirm "Install all MCPs globally for Claude Code? [y/N]: " && install_all ;;
        2) confirm "Uninstall all managed MCPs? [y/N]: " && uninstall_all ;;
        3) confirm "Reinstall all managed MCPs? [y/N]: " && {
            uninstall_all
            install_all
        } ;;
        4)
            need_cmd claude
            claude mcp list
            ;;
        5) show_one ;;
        6) exit 0 ;;
        *) printf '%b\n' "${C_RED}Invalid option.${C_RESET}" ;;
        esac
        echo
    done
}

main "$@"
