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

The `mac_bootstrap.zsh` script automates various setup tasks:

1. **Xcode Command Line Tools Installation**: Essential for development on
   macOS, this step ensures that compilers and Git are available on your
   machine (installed by Homebrew).

2. **Smart Repository Cloning**: It utilizes a robust cloning mechanism that initially tries SSH, and then switches to HTTPS with a Personal Access Token (PAT) if needed. If SSH fails, the user will be prompted for a PAT token.

3. **Symlink Creation**: Sets up symbolic links for essential configuration
   files, linking them from the repository to your home directory for easy
   access and management.

4. **Homebrew Management**: Installs Homebrew if not already present and uses a
   Brewfile to manage software installations, keeping your environment
   consistent and up-to-date.

5. **AstroNvim Setup with Dependency Management**: Integrates AstroNvim, a highly configurable Neovim distribution, with your user profile for an enhanced coding experience. The script also manages dependencies including Python, Ruby, and Perl.

6. **CondaBackup Repository Restoration**: Checks for the existence of a
   CondaBackup repository, clones it if necessary, and restores Conda
   environments from saved backups.

7. **Nerd Font Installation**: Automatically installs the JetBrainsMono Nerd
   Font to enhance terminal aesthetics and compatibility with powerline
   symbols.

8. **User Interface Enhancements**: The script includes functions for displaying
   colorful and centered messages, adding a touch of personality to your
   terminal.

9. **To-Do List for App Downloads**: Generates a list of recommended
   applications to download, saved as a text file on your desktop for easy
   reference.

## Installation

To set up your macOS development environment using this repository, ensure you have a stable internet connection and administrative access on your device. The installation can be done using a single command that downloads, executes, and removes the setup script.

### Quick Installation

Open your terminal and run the following command:

```bash
curl -sSL https://github.com/av1155/.dotfiles/raw/main/App-Configs/configs/MacOS-Bootstrap/mac_bootstrap.zsh -o mac_bootstrap_tmp.zsh && chmod +x mac_bootstrap_tmp.zsh && ./mac_bootstrap_tmp.zsh && rm ./mac_bootstrap_tmp.zsh
```

This command will perform the following actions:

1.  Download the `mac_bootstrap.zsh` script and save it as `mac_bootstrap_tmp.zsh`.
2.  Make the script executable.
3.  Execute the script.
4.  Remove the script after execution.

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
