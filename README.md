# .dotfiles

> Cross-platform developer environment for macOS, Arch Linux, Debian, and WSL—featuring automated setup, modular configuration management, and zero-friction onboarding.

## Quick Start

```bash
git clone git@github.com:av1155/.dotfiles.git ~/.dotfiles
cd ~/.dotfiles
./install.sh
exec zsh
```

## Why These Dotfiles?

- **Portable**: Works across macOS (Intel/Apple Silicon), Arch Linux, Debian, WSL, and Raspberry Pi
- **Safe & Idempotent**: Automatically backs up conflicts, can be run multiple times safely
- **Zero Configuration**: Automated detection and installation of tools based on your platform
- **Modular**: Managed with GNU Stow—easy to add, remove, or customize individual packages
- **Fast**: Optimized shell startup with lazy-loading and caching (1-2s faster than default configs)
- **Robust**: Error-resistant with network checks, retry protection, and graceful degradation

## Table of Contents

<!--toc:start-->

- [.dotfiles](#dotfiles)
  - [Quick Start](#quick-start)
  - [Why These Dotfiles?](#why-these-dotfiles)
  - [Table of Contents](#table-of-contents)
  - [Features](#features)
  - [Installation](#installation)
    - [Prerequisites](#prerequisites)
    - [Automated Installation](#automated-installation)
    - [Manual Installation (Advanced)](#manual-installation-advanced)
  - [Repository Structure](#repository-structure)
  - [Configuration Details](#configuration-details)
    - [Universal Zsh Configuration](#universal-zsh-configuration)
    - [Terminal Multiplexing (tmux)](#terminal-multiplexing-tmux)
    - [Package Management](#package-management)
    - [Development Tools](#development-tools)
    - [Theming & Appearance](#theming--appearance)
    - [macOS Bootstrap](#macos-bootstrap)
  - [Customization](#customization)
  - [Updating](#updating)
  - [Uninstalling](#uninstalling)
  - [Troubleshooting](#troubleshooting)
    - [tmux Configuration Not Loading](#tmux-configuration-not-loading)
    - [Stow Conflicts](#stow-conflicts)

## Features

- **Universal Shell Environment**: Zsh configuration that adapts to macOS, Arch, Debian, WSL, and Raspberry Pi
- **Automated Tool Installation**: Homebrew, Oh-My-Zsh, Conda, and platform-specific package managers installed automatically
- **Smart Plugin Management**: ZPlug with Pure theme, syntax highlighting, autosuggestions, and async rendering
- **Self-Healing tmux**: Automatic plugin manager setup with session persistence and custom keybindings
- **Enhanced Navigation**: FZF fuzzy finder integrated with bat, git, and file browsing
- **AI Development Tools**: Pre-configured OpenCode agents, Claude MCP servers, and Aider integration
- **Python Environment**: Conda/Miniforge auto-setup with Neovim provider configuration
- **Node.js Management**: NVM lazy-loading for instant shell startup
- **Java Development**: Auto-configured classpath with JUnit and common libraries
- **Modern CLI Tools**: fastfetch, yazi, lazygit, eza, zoxide, ripgrep, and more
- **Catppuccin Theming**: Consistent color schemes across bat, tmux, and terminal
- **Nerd Font Included**: JetBrains Mono with icons and ligatures

## Installation

### Prerequisites

- **Git**: For cloning the repository
- **Zsh**: Your default shell (will be configured automatically)
- **GNU Stow**: Symlink management (installation instructions provided below)
- **curl/wget**: For downloading tools (usually pre-installed)

Optional but recommended:

- **tmux**: Terminal multiplexer
- **Neovim**: Modern vim editor
- **Python 3**: For Neovim provider and development

### Automated Installation

The installation script handles everything automatically:

1. Clone this repository:

    ```bash
    git clone git@github.com:av1155/.dotfiles.git ~/.dotfiles
    ```

1. Install GNU Stow (if not already installed):

    ```bash
    # macOS
    brew install stow

    # Arch Linux
    sudo pacman -S stow

    # Debian/Ubuntu
    sudo apt install stow
    ```

1. Run the installation script:

    ```bash
    cd ~/.dotfiles
    ./install.sh
    ```

    **What the script does:**

    - ✅ Auto-detects required base directories (`.config`, `.ssh`, `.fonts`, `Library`)
    - ✅ Creates missing directories
    - ✅ Detects conflicts with existing files
    - ✅ Backs up conflicting files to `filename.bak` (with notification)
    - ✅ Runs `stow --restow */` safely
    - ✅ Idempotent—safe to run multiple times
    - ✅ Offers optional troubleshooting menu for fixing common issues

1. Restart your shell:

    ```bash
    exec zsh
    ```

### Manual Installation (Advanced)

<details>
<summary>Click to expand manual installation steps</summary>

If you prefer manual control:

1. Pre-create base directories:

    ```bash
    mkdir -p ~/.config ~/.local ~/.ssh ~/.fonts ~/Library
    ```

1. Back up any conflicting files:

    ```bash
    mv ~/.zshrc ~/.zshrc.bak
    mv ~/.gitconfig ~/.gitconfig.bak
    # ... repeat for other conflicts
    ```

1. Run GNU Stow:

    ```bash
    cd ~/.dotfiles
    stow --restow */
    ```

1. Restart your shell:

    ```bash
    exec zsh
    ```

**Note**: Run `man stow` to understand how symlink management works.

</details>

## Repository Structure

<details>
<summary>Click to expand directory structure</summary>

```bash
.
├── install.sh                  # Automated installation script
├── .stow-global-ignore         # Files to exclude from stowing
│
├── App-Configs/                # Application-specific configurations
│   └── configs/
│       ├── iTerm2_Profile/     # iTerm2 profile and icons
│       ├── KittyAppIconMac/    # Custom Kitty icons
│       └── MacOS-Bootstrap/    # macOS dev environment bootstrap script
│
├── Claude/                     # Claude AI MCP server configurations
│   └── .claude/
│
├── Config/                     # XDG config directory
│   └── .config/
│       ├── bat/                # Bat (better cat) themes
│       ├── fastfetch/          # System info display
│       ├── hypr/               # Hyprland window manager (Linux)
│       ├── kitty/              # Kitty terminal emulator
│       ├── lazygit/            # Git TUI configuration
│       ├── opencode/           # OpenCode AI agents & settings
│       ├── tmux/               # Tmux configuration & plugins
│       └── yazi/               # File manager configuration
│
├── Fonts/                      # JetBrains Mono Nerd Font (all variants)
│   └── .fonts/
│
├── Formatting-Files/           # Code formatters & linters
│   ├── .clang-format
│   ├── .markdownlint-cli2.yaml
│   └── .prettierrc.json
│
├── Git/                        # Git configuration
│   ├── .gitconfig
│   ├── .gitignore_global
│   └── README.md               # Git subtree workflow guide
│
├── Java-Jars/                  # Java development libraries
│   └── javaClasspath/          # JUnit, jsoup, etc.
│
├── macOS-Library/              # macOS Application Support
│   └── Library/
│       └── Application Support/
│           ├── Code/           # VSCode settings
│           └── lazygit/        # Lazygit config
│
├── SSH/                        # SSH configuration
│   └── .ssh/
│       └── config
│
└── ZSH/                        # Zsh shell configuration
    ├── .zshrc                  # Main shell config
    ├── .zprofile               # Login shell config
    └── fzf-git.sh/             # FZF git integration
```

</details>

## Configuration Details

### Universal Zsh Configuration

The `.zshrc` is designed to work seamlessly across different platforms:

- **Platform Detection**: Automatically detects macOS, Arch Linux, Debian, WSL, and Raspberry Pi
- **Oh-My-Zsh**: Managed with automatic installation and plugin support
- **ZPlug**: Plugin manager with Pure theme, syntax highlighting, and autosuggestions
- **Performance**: Lazy-loading (NVM), caching (conda config), and optimized PATH management
- **Fastfetch**: System information display on new shells
- **Smart Aliases**: Context-aware shortcuts for common tasks

### Terminal Multiplexing (tmux)

Auto-configured tmux with plugin management:

- **Auto-Start**: Automatically starts or attaches to tmux sessions
- **Plugin Manager**: TPM (Tmux Plugin Manager) can be set up via the troubleshooting menu
- **Plugins Included**:
  - `tmux-sensible`: Sensible defaults
  - `vim-tmux-navigator`: Seamless vim/tmux navigation
  - `catppuccin/tmux`: Beautiful theme
  - `tmux-cpu`: CPU usage display
  - `tmux-yank`: System clipboard integration
  - `tmux-sessionx`: Advanced session switcher
- **Custom Keybindings**: `Ctrl+A` prefix, intuitive pane navigation
- **Status Bar**: Custom top status with directory, session, and system info

### Package Management

Automatic setup for platform-specific package managers:

- **macOS**: Homebrew with automatic installation
- **Arch Linux**: Paru (AUR helper) with auto-compilation
- **Conda/Miniforge**: Python environment management
- **NVM**: Node.js version management (lazy-loaded)

### Development Tools

Pre-configured for modern development:

- **Neovim**: Python provider auto-configured with conda environments
- **Git**: Enhanced with FZF integration and custom aliases
- **AI Tools**:
  - OpenCode with specialized agents (code-reviewer, debugger, refactorer, etc.)
  - Claude MCP servers (git, time, fetch, brave-search, playwright, magic)
- **File Navigation**:
  - FZF: Fuzzy finder with custom keybindings
  - Bat: Syntax-highlighted file viewer
  - Eza: Modern `ls` replacement
  - Yazi: Terminal file manager
  - Zoxide: Smart directory jumping
- **Terminal Tools**:
  - Lazygit: Git TUI
  - Thefuck: Command correction
  - Ripgrep: Fast text search

### Theming & Appearance

Consistent Catppuccin theming:

- **Bat**: Catppuccin Macchiato syntax highlighting
- **Tmux**: Catppuccin Frappe theme
- **Kitty**: Dynamic font size and opacity per OS
- **Fonts**: JetBrains Mono Nerd Font (all variants included)

### macOS Bootstrap

Comprehensive macOS development environment setup script:

- **Location**: `App-Configs/configs/MacOS-Bootstrap/`
- **Features**: Automated installation of Homebrew, development tools, AstroNvim, and essential utilities
- **Documentation**: See [MacOS-Bootstrap README](App-Configs/configs/MacOS-Bootstrap/README.md)

## Customization

### Adding Your Own Configs

Create a new stow package:

```bash
cd ~/.dotfiles
mkdir -p MyCustom/.config/myapp
# Add your configs
stow MyCustom
```

### Overriding Defaults

Create local override files that won't be tracked:

```bash
# Add personal zsh customizations
echo "# My custom aliases" >> ~/.zshrc.local
source ~/.zshrc.local  # Add this to .zshrc
```

### Excluding Packages

Only stow specific packages:

```bash
# Install only Git and ZSH configs
cd ~/.dotfiles
stow Git ZSH
```

## Updating

Pull the latest changes and re-run the installer:

```bash
cd ~/.dotfiles
git pull --rebase
./install.sh
exec zsh
```

**Note**: The installer will skip existing installations and only update changed files.

## Uninstalling

### Remove Symlinks

Use GNU Stow to remove all symlinks:

```bash
cd ~/.dotfiles
stow -D */
```

### Restore Backups

Restore your original files from `.bak` backups:

```bash
mv ~/.zshrc.bak ~/.zshrc
mv ~/.gitconfig.bak ~/.gitconfig
# ... restore other backups
```

### Clean Up Marker Files

Remove installation markers to allow fresh reinstalls:

```bash
rm ~/.homebrew_install_attempted
rm ~/.ohmyzsh_install_attempted
rm ~/.miniforge_install_attempted
rm ~/.tmux_tpm_setup_complete
# ... etc.
```

## Troubleshooting

### Interactive Troubleshooting Menu

The installation script includes an interactive troubleshooting menu. Run it anytime with:

```bash
cd ~/.dotfiles
./install.sh
```

When prompted, choose `y` to access the troubleshooting menu with these options:

1. **Fix Tmux Plugin Manager (TPM)**: Installs or repairs TPM installation
2. **Reinstall all Tmux plugins**: Removes and reinstalls all tmux plugins
3. **Reset Tmux configuration completely**: Nuclear option—completely removes and reinstalls everything tmux-related
4. **Exit**: Return to normal operation

### tmux Configuration Not Loading

If tmux plugins aren't working, use the troubleshooting menu above, or manually:

1. Remove existing plugins:

    ```bash
    rm -rf ~/.config/tmux/plugins ~/.tmux/plugins
    ```

1. Reinstall TPM:

    ```bash
    git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
    ```

1. Reload tmux configuration:

    ```bash
    tmux source-file ~/.config/tmux/tmux.conf
    ```

1. Install plugins:
    - Inside tmux: `Ctrl+A` then `I` (capital i)
    - Or run: `~/.tmux/plugins/tpm/bin/install_plugins`

### Stow Conflicts

If you encounter symlink conflicts:

```bash
# See what's conflicting
cd ~/.dotfiles
stow --simulate --restow */

# Manually backup conflicting files
mv ~/.conflicting-file ~/.conflicting-file.bak

# Re-run stow
./install.sh
```

### Other Issues

- **Oh-My-Zsh not installed**: Delete `~/.ohmyzsh_install_attempted` and restart shell
- **Brew commands not found**: Restart shell or run `eval "$(/opt/homebrew/bin/brew shellenv)"`
- **Python provider errors in Neovim**: Run `:checkhealth provider` in Neovim for diagnostics
