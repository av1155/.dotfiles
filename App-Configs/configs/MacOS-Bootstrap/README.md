# Dotfiles + BootStrap Repository

<!--toc:start-->

-   [Dotfiles + BootStrap Repository](#dotfiles-bootstrap-repository)
    -   [Introduction](#introduction)
    -   [Features](#features)
    -   [Installation](#installation)
        -   [Quick Installation](#quick-installation)
        -   [Usage](#usage)
            -   [Option 1: Clone and Run](#option-1-clone-and-run)
            -   [Option 2: Download and Run](#option-2-download-and-run)
    -   [Customization](#customization)
    -   [Troubleshooting](#troubleshooting)
    -   [Contributing](#contributing)
    -   [License](#license)
    <!--toc:end-->

Welcome to my dotfiles repository! Here, you'll find configuration files
(dotfiles) for customizing my development environment and a robust script,
`mac_bootstrap.zsh`, designed to automate the entire setup of a new macOS
device. This script covers everything from installing Xcode Command Line Tools
to setting up your favorite apps, ensuring a streamlined and personalized
development experience.

## Introduction

This repository serves as a one-stop solution for setting up and customizing
your macOS development environment. It includes my personal dotfiles and the
`mac_bootstrap.zsh` script, which simplifies the setup process.

## Features

The `mac_bootstrap.zsh` script automates various setup tasks. The script targets
**Apple Silicon (arm64) only**.

1. **Homebrew + Xcode Command Line Tools**: Installs Homebrew, which now also
   installs the Xcode Command Line Tools automatically — no separate
   `xcode-select` step is needed.

2. **Smart Repository Cloning**: Robust cloning that tries HTTPS first, falls
   back to SSH, and finally to HTTPS with a Personal Access Token (PAT) if
   neither works.

3. **Brewfile-driven installs**: All formulae and casks are declared in
   `Brewfile` and applied with `brew bundle`. The Brewfile is regenerated
   automatically by `update_homebrew()` in `~/scripts/scripts/package_updater.zsh`,
   so it always reflects the current state of the laptop.

4. **GNU Stow for dotfiles**: Existing conflicting files are backed up to
   `*.bak`, then `stow --restow */` symlinks each managed package into `$HOME`.

5. **Language Toolchains (modern stack)**:
   - **Node.js**: pnpm-managed (`pnpm env use --global lts`). No nvm.
   - **Python**: uv (system) + a dedicated uv venv for the Neovim Python
     provider at `~/.local/share/nvim/venv`. No conda/miniforge.
   - **Java**: a single Homebrew `openjdk`, optionally symlinked into
     `/Library/Java/JavaVirtualMachines/` so `/usr/libexec/java_home` and
     other tools find it. No Oracle JDK auto-downloader, no JDK bloat.
   - **pnpm globals**: `typescript`, `tsx`, `prettier`, several LSP servers
     (typescript-language-server, vtsls, vscode-langservers-extracted,
     bash-language-server, yaml-language-server, tailwindcss-language-server),
     plus `@playwright/cli`, `firecrawl-cli`, `wrangler`.

6. **Per-project Python envs via direnv + chpwd hook**: The dotfiles ship
   a zsh `chpwd` hook (`_venv_auto_activate`) that auto-activates a project's
   `.venv/` on `cd`, plus a `direnv hook zsh` for projects with extra env
   vars (`.envrc`).

7. **Neovim**: installed via Brewfile. Configuration arrives via stow from
   `~/.dotfiles/Config/.config/nvim/` (LazyVim-based). Bootstrap triggers
   `Lazy! sync` headlessly to install plugins.

8. **Nerd Font Installation**: Installs JetBrainsMono Nerd Font for terminal
   icons and ligatures.

9. **GitHub CLI + Copilot**: Logs into `gh` and installs `gh-copilot`.

10. **Optional: Docker + Ollama + Open WebUI**: Sets up the local LLM stack
    if requested.

11. **TODO list**: Generates `~/Desktop/apps_to_download.txt` with the
    handful of apps not installable via Homebrew (Mac App Store + a few
    direct downloads).

## Installation

To set up your macOS development environment using this repository, ensure you have a stable internet connection and administrative access on your device. The installation can be done using a single command that downloads, executes, and removes the setup script.

### Quick Installation

Open your terminal and run the following command:

```bash
curl -sSL https://github.com/av1155/.dotfiles/raw/main/App-Configs/configs/MacOS-Bootstrap/mac_bootstrap.zsh -o mac_bootstrap.zsh && zsh mac_bootstrap.zsh && rm mac_bootstrap.zsh
```

This command will perform the following actions:

1.  Download the `mac_bootstrap.zsh` script.
2.  Execute the script.
3.  Remove the script after execution.

-   After Oh My Zsh is installed, you need to re-run the script because OMZ refreshes the shell.

Follow any on-screen instructions to complete the setup.

### Usage

#### Option 1: Clone and Run

1. Clone this repository to your desired location by opening the terminal and
   running the following command:

    ```shell
    git clone https://github.com/av1155/.dotfiles.git
    ```

2. Navigate to the cloned directory:

    `cd .dotfiles`

3. Make the script executable:

    `chmod u+x ~/.dotfiles/App-Configs/configs/MacOS-Bootstrap/mac_bootstrap.zsh`

4. Execute the script:

    `~/.dotfiles/App-Configs/configs/MacOS-Bootstrap/mac_bootstrap.zsh`

5. Follow any on-screen instructions to complete setup.

#### Option 2: Download and Run

1. Download the `mac_bootstrap.zsh` script from this repository.

2. Make the script executable:

    `chmod +x ~/Downloads/mac_bootstrap.zsh`

3. Execute the script and follow any on-screen instructions to complete setup.:

    `~/Downloads/mac_bootstrap.zsh`

## Customization

Feel free to fork this repository and customize the dotfiles and script to match
your personal preferences and workflow. You can also modify the script to:

-   **Adjust Repository Cloning Logic**: Customize the order in which SSH,
    HTTPS, and PAT are used for cloning repositories.
-   **Install Additional Fonts**: Add or replace the Nerd Font installation
    with your preferred fonts.
-   **Manage Additional Software**: Extend the Brewfile or script to install
    additional software packages or manage more complex configurations.

## Troubleshooting

Encounter an issue? Here are some common problems and their solutions:

-   **Script Fails to Clone Repositories**: The script tries SSH first, then
    HTTPS with a GitHub Personal Access Token (PAT). If all
    methods fail, ensure your SSH keys are set up correctly or generate a PAT
    from your GitHub account and provide it when prompted.

-   **Xcode Command Line Tools Installation Issues**: Check your internet
    connection and retry, or install manually from the Apple Developer website.

-   **AstroNvim Dependency Issues**: If the script fails to install dependencies
    like Python (pynvim), Ruby (neovim gem), or Perl (local::lib and
    Neovim::Ext), ensure you have a stable internet connection and sufficient
    permissions to install software. You may need to manually install these
    dependencies.

## Contributing

Contributions are welcome! If you have improvements, suggestions, or bug fixes,
please submit a Pull Request.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for
details.
