# .dotfiles

This repository contains my personal configuration files (dotfiles) for setting up my Arch Linux with Hyprland window manager and other utilities. It also includes configurations for macOS and other environments.

## Installation

To install and symlink the configuration files to your system:

1. Clone this repository into your home directory:

    ```bash
    git clone git@github.com:av1155/.dotfiles.git ~/.dotfiles
    ```

2. Install GNU Stow (if not installed) to manage the symlinks:

    ```bash
    sudo pacman -S stow     # For Arch Linux
    brew install stow       # For macOS (using Homebrew)
    sudo apt install stow   # For Debian Linux
    ```

3. Navigate to the `.dotfiles` directory:

    ```bash
    cd ~/.dotfiles
    ```

4. Run `stow .` to symlink all configurations.
   If issues arise because symlinks already exist, or original files, you need to manually remove those files (or turn them into .bak's) and then run `stow .` from the `~/.dotfiles` directory again.

    - For specific files and directories then:

        ```bash
        stow directory  # To symlink specific directories
        stow file       # To symlink specific files
        ```

        Run `man stow` to understand how it works before using it.

## Structure

Below is an overview of the files and directories in this repository:

## Key Features

### Universal Zsh Configuration (`.zshrc`)

The `.zshrc` file is designed to work across different systems like macOS, Linux (Arch, Raspberry Pi, etc.), and Windows (WSL). It detects the current OS and adjusts paths and tool installations accordingly, ensuring consistent behavior regardless of the platform.

-   **Oh My Zsh**: Configuration for managing Zsh and its plugins.
-   **Powerlevel10k Theme**: Installs and configures Powerlevel10k for a beautiful terminal prompt.
-   **ZPlug**: Manages Zsh plugins.
-   **Fastfetch**: Quickly fetches system information and displays it in the terminal.

### Terminal Multiplexing (`tmux`)

Auto-starts a `tmux` session on terminal login, with custom session naming and attachment logic. This is ideal for maintaining persistent work environments.

#### Issues if tmux configuration does not load:

1. Remove all Tmux plugins or previous symlinks

```bash
cd ~/.config/tmux/plugins
rm -rf *
```

2. Reinstall Tmux Plugin Manager (tpm)

```bash
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
```

3. Reload Tmux Configuration

```bash
tmux source-file ~/.config/tmux/tmux.conf
```

4. Install Plugins Using tpm

```bash
Ctrl + A (your current prefix), then I
```

### Neovim Configuration

-   The `.zshrc` includes automatic setup for Neovim's Python provider, ensuring that Neovim is always ready to work with Python and other environments.
-   Supports a dynamic Python executable path for `pynvim`.

### FZF and Bat Integration

-   Enhanced file navigation with FZF (Fuzzy Finder) and `bat` (a better `cat`).
-   Custom aliases for efficient directory and file navigation.

### Package Manager Support

The setup automatically configures the appropriate package manager for your system:

-   **Paru/Yay** on Arch Linux (for AUR support)
-   **Homebrew** on macOS (via `brew`)

### Scripts

-   **fzf-git.sh**: Adds git integration to FZF for quickly browsing and managing git repositories.
-   **Custom Shell Scripts**: Includes scripts for managing Java projects, SQL URLs, updating packages, etc.

### Color Schemes

-   **Bat themes**: Automatically installs the Catppuccin theme for the `bat` command.
-   **Kitty**: Dynamic configuration for font size and opacity depending on the OS.

### Java Classpath

Automatically configures the Java classpath based on the JAR files found in the `javaClasspath` directory.

## License

This project is licensed under the MIT License.
