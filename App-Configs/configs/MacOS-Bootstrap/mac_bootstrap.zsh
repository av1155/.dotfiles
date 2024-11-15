#!/bin/zsh

# Script for bootstrapping a new MacBook for development.
# This script installs necessary tools and sets up symlinks for dotfiles.
# Assumptions: macOS with internet access and standard file system structure.
# Usage: Execute this script in a zsh shell.

# Define ANSI color escape codes
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
PURPLE='\033[0;35m'
ORANGE='\033[0;33m'
NC='\033[0m' # No color (reset)

# Ensure Xcode Command Line Tools are installed
if ! xcode-select -p &>/dev/null; then
    color_echo $YELLOW "Xcode Command Line Tools not found. Installing..."
    xcode-select --install
    # Wait for the user to complete installation
    read -p "Press Enter after the Xcode Command Line Tools installation is complete."
fi

# Ensure the script is run in Zsh
if [ -z "$ZSH_VERSION" ]; then
    color_echo $RED "This script requires Zsh. Please run it in a Zsh shell."
    exit 1
fi

# BEGINNING OF FUNCTIONS ------------------------------------------------------

# Function to display colored messages
color_echo() {
	local color="$1"
	local message="$2"
	echo -e "${color}${message}${NC}"
}

# Function to calculate padding for centering text
calculate_padding() {
	local text="$1"
	local terminal_width=$(tput cols)
	local text_width=${#text}
	local padding_length=$(((terminal_width - text_width) / 2))
	printf "%*s" $padding_length ""
}

# Function to display centered colored messages
centered_color_echo() {
	local color="$1"
	local message="$2"
	local padding=$(calculate_padding "$message")
	echo -e "${color}${padding}${message}${padding}${NC}"
}

# Function to check if SSH is set up
is_ssh_configured() {
	if ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
		return 0
	else
		return 1
	fi
}

# Function to prompt for PAT if HTTPS cloning fails
prompt_for_pat() {
	local https_url="$1"
	local clone_directory="$2"

	color_echo $YELLOW "Please provide a GitHub Personal Access Token (PAT) for HTTPS cloning."
	echo -n "Enter your GitHub PAT Token (hidden input): "
	read -r -s pat
	echo ""

	local pat_clone_url=${https_url/https:\/\//https:\/\/$pat@}
	git clone "$pat_clone_url" "$clone_directory"
}

git_clone_fallback() {
	local ssh_url="$1"
	local https_url="$2"
	local clone_directory="$3"
	local retries=3
	local count=0

	# Attempt HTTPS cloning without PAT first (for public repositories)
	color_echo $BLUE "\nAttempting to clone repository using HTTPS (no PAT)..."
	while [ $count -lt $retries ]; do
		git clone "$https_url" "$clone_directory" && return 0
		count=$((count + 1))
		if [ $count -lt $retries ]; then
			color_echo $YELLOW "Attempt $count/$retries failed using HTTPS (no PAT). Retrying in 3 seconds..."
			sleep 2
		fi
	done

	# Reset count and attempt SSH cloning next
	color_echo $BLUE "\nAttempting to clone repository using SSH..."
	count=0
	if is_ssh_configured; then
		while [ $count -lt $retries ]; do
			git clone "$ssh_url" "$clone_directory" && return 0
			count=$((count + 1))
			if [ $count -lt $retries ]; then
				color_echo $YELLOW "Attempt $count/$retries failed using SSH. Retrying in 3 seconds..."
				sleep 2
			fi
		done
	fi

	# If both SSH and HTTPS (no PAT) fail, fall back to HTTPS with PAT
	color_echo $YELLOW "\nSSH is not configured or failed. Falling back to HTTPS with PAT."
	count=0
	while [ $count -lt $retries ]; do
		prompt_for_pat "$https_url" "$clone_directory" && return 0
		count=$((count + 1))
		if [ $count -lt $retries ]; then
			color_echo $YELLOW "\nAttempt $count/$retries failed using HTTPS with PAT. Retrying in 3 seconds..."
			sleep 2
		fi
	done

	color_echo $RED "\nFailed to clone repository after $retries attempts. Please check your network connection or credentials and try again."
	exit 1
}

backup_existing_files() {
    color_echo $YELLOW "|------- Backing Up Conflicting Files -------|\n"

    # Use stow --simulate to find conflicts
    stow --restow --simulate */ 2>&1 | grep "cannot stow" | while read -r line; do
        
        # Extract the conflicting file path using pattern matching
        target=$(echo "$line" | sed -n 's/.*over existing target \(.*\) since.*/\1/p')

        # Check if the target file exists and is a regular file (not a symlink or directory)
        if [ -f "$HOME/$target" ] && [ ! -L "$HOME/$target" ]; then
            # Create the directory for the .bak file if it doesn't exist
            target_dir=$(dirname "$target")
            mkdir -p "$HOME/$target_dir"
            
            # Move the conflicting file to a .bak version
            mv "$HOME/$target" "$HOME/${target}.bak" || {
                color_echo $RED "✗ Failed to back up $target"
                exit 1
            }
            color_echo $GREEN "✓ Backed up $target to ${target}.bak"
        else
            color_echo $CYAN "! Skipping $target (not a regular file or doesn't exist)"
        fi
    done

    color_echo $GREEN "\n|--------- Backup Process Completed ---------|\n"
}

# Function to create a symlink
create_symlink() {
	local source_file="$1"
	local target_file="$2"

	# Function to extract file and its immediate parent directory
	get_file_and_parent() {
		local full_path=$1
		echo "$(basename "$(dirname "$full_path")")/$(basename "$full_path")"
	}

	local source_display="$(get_file_and_parent "$source_file")"
	local target_display="$(get_file_and_parent "$target_file")"

	if [ -L "$target_file" ] && [ "$(readlink "$target_file")" = "$source_file" ]; then
		color_echo $GREEN "Symlink for ${PURPLE}$source_display${GREEN} already exists and is correct."
		return
	fi

	if [ -f "$target_file" ]; then
		color_echo $YELLOW "Existing file found for ${PURPLE}$target_display${YELLOW}. Do you want to overwrite it?"
		echo -n "-> [y/N]: "
		read -r choice
		case "$choice" in
		y | Y)
			color_echo $BLUE "Backing up existing ${PURPLE}$target_display${BLUE} as ${PURPLE}${target_display}.bak${BLUE}"
			mv "$target_file" "${target_file}.bak" || {
				color_echo $RED "Failed to backup $target_file"
				exit 1
			}
			;;
		n | N | "")
			color_echo $GREEN "Skipping ${PURPLE}$target_display${GREEN}."
			return
			;;
		*)
			color_echo $RED "Invalid choice. Exiting."
			exit 1
			;;
		esac
	fi

	mkdir -p "$(dirname "$target_file")"

	ln -sf "$source_file" "$target_file" || {
		color_echo $RED "Failed to create symlink for ${PURPLE}$source_display${RED}"
		exit 1
	}

	# Display this message only when a symlink is created.
	color_echo $GREEN "Created symlink for ${PURPLE}$source_display${GREEN} to ${PURPLE}$target_display${GREEN}."
}

# Function to prompt and install an app
# Arguments: app_name, install_command, check_command
install_app() {
	local app_name="$1"
	local install_command="$2"
	local check_command="$3"

	if ! eval "$check_command"; then
		color_echo $GREEN "$app_name already installed."
	else
		if auto_prompt "Do you want to install $app_name?" 10 "y" $YELLOW; then
			color_echo $BLUE "Installing $app_name..."
			eval "$install_command" || {
				color_echo $RED "Failed to install $app_name."
				exit 1
			}
		else
			color_echo $BLUE "Skipping $app_name installation."
		fi
	fi
}

# Function to install Neovim on macOS
install_neovim() {
	# URL for Neovim pre-built binary for macOS
	local nvim_url="https://github.com/neovim/neovim/releases/download/v0.9.4/nvim-macos.tar.gz"
	local nvim_tarball="nvim-macos.tar.gz"

	# Check if Neovim is installed or the directory exists
	if command -v nvim &>/dev/null || [ -d "$HOME/nvim-macos" ]; then
		color_echo $GREEN "Neovim already installed."
	else
		color_echo $YELLOW "Do you want to install Neovim?"
		echo -n "-> [y/N]: "
		read -r choice
		if [ "$choice" = "y" ] || [ "$choice" = "Y" ]; then
			# Install dependencies
			color_echo $BLUE "Installing dependencies for Neovim..."
			brew install gettext || {
				color_echo $RED "Failed to install dependencies for Neovim."
				exit 1
			}

			# Download Neovim
			color_echo $BLUE "Downloading Neovim..."
			curl -LO $nvim_url || {
				color_echo $RED "Failed to download Neovim."
				exit 1
			}

			# Remove "unknown developer" warning
			color_echo $BLUE "Removing 'unknown developer' warning from Neovim tarball..."
			xattr -c $nvim_tarball

			# Extract Neovim
			color_echo $BLUE "Extracting Neovim..."
			tar xzf $nvim_tarball || {
				color_echo $RED "Failed to extract Neovim."
				exit 1
			}

			# Remove the tarball and extracted directory
			rm -f $nvim_tarball

			color_echo $GREEN "Neovim installed successfully."
		else
			color_echo $BLUE "Skipping Neovim installation."
		fi
	fi

}

# Function for an automatic yes/no prompt with a timeout
auto_prompt() {
    local prompt_message="$1"
    local timeout_duration="${2:-10}"  # Default to 10 seconds if not specified
    local default_choice="${3:-n}"     # Default choice if not specified
    local color="${4:-$YELLOW}"        # Default color for prompt message
    local response

    # Set prompt based on default choice
    if [[ "$default_choice" =~ ^[Yy]$ ]]; then
        color_echo "$color" "$prompt_message -> [Y/n] (default in $timeout_duration seconds): "
    else
        color_echo "$color" "$prompt_message -> [y/N] (default in $timeout_duration seconds): "
    fi

    # Prompt user and handle timeout or empty input with default choice
    read -t "$timeout_duration" -r response

    # If response is empty (Enter pressed or timeout), use default choice
    response="${response:-$default_choice}"

    # Return based on the interpreted response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        return 0  # Yes
    else
        return 1  # No
    fi
}

# END OF FUNCTIONS ------------------------------------------------------------

# Confirmation prompt for starting the script
if auto_prompt "Do you want to proceed with the BootStrap Setup Script?" 10 "y" $YELLOW; then
	color_echo $GREEN "Starting BootStrap Setup Script..."
else 
	color_echo $RED "BootStrap Setup Script aborted."
	exit 1
fi

# Step 1: Install Homebrew ----------------------------------------------------

echo ""

centered_color_echo $ORANGE "<-------------- Homebrew Configuration -------------->"

echo ""

# Check if Homebrew is installed
if ! command -v brew &>/dev/null; then
	if auto_prompt "Do you want to install Homebrew?" 10 "y" $YELLOW; then
		color_echo $BLUE "Installing Homebrew..."
		/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || {
			color_echo $RED "Failed to install Homebrew."
			exit 1
		}

		# Determine the architecture (Intel or Apple Silicon)
		arch_name="$(uname -m)"
		if [ "$arch_name" = "x86_64" ]; then
			# Intel Macs
			HOMEBREW_BIN="/usr/local/bin/brew"
		elif [ "$arch_name" = "arm64" ]; then
			# Apple Silicon Macs
			HOMEBREW_BIN="/opt/homebrew/bin/brew"
		else
			color_echo $RED "Unknown architecture: $arch_name"
			exit 1
		fi

		# Set up Homebrew in the shell only after installation
		echo "eval \"$($HOMEBREW_BIN shellenv)\"" >>$HOME/.zprofile
		eval "$($HOMEBREW_BIN shellenv)"

	else
		color_echo $RED "Homebrew installation skipped."
		exit 1
	fi

else
	color_echo $GREEN "Homebrew already installed, updating..."
	brew update && brew upgrade || {
		color_echo $RED "Failed to update Homebrew."
		exit 1
	}
fi

# Step 2: Install Git (if not already installed by Xcode Command Line Tools) ---
if ! command -v git &>/dev/null; then
	color_echo $BLUE "Installing Git..."
	brew install git || {
		color_echo $RED "Failed to install Git."
		exit 1
	}
fi

# Step 3: Installation of software --------------------------------------------

echo ""

centered_color_echo $ORANGE "<-------------- Installation of Software -------------->"

echo ""

# app_name: The name of the app.
# install_command: The command to install the app.
# check_command: The command to check if the app is already installed.

# Example:
# install_app "Visual Studio Code" "brew install --cask visual-studio-code" "! brew list --cask | grep -q visual-studio-code && [ ! -d '/Applications/Visual Studio Code.app' ]"

# # Install Zplug # Handled by .zshrc now
# install_app "Zplug" "brew install zplug" "! brew list zplug &>/dev/null"

# After Oh My Zsh installation, insert a reminder to run the script again
color_echo $YELLOW "Once Oh My Zsh has been installed, rerun the script to finish the setup process."

# Install Oh My Zsh
install_app "Oh My Zsh" "sh -c \"\$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)\"" "[ ! -d '$HOME/.oh-my-zsh' ]"

# Install Java
ARCH="$(uname -m)"
JDK_PAGE_URL="https://www.oracle.com/java/technologies/downloads/#jdk"

# Fetch the page and extract the correct link based on architecture
if [ "$ARCH" = "arm64" ]; then
    JDK_URL=$(curl -sL $JDK_PAGE_URL | grep -oE 'https://download.oracle.com/java/[0-9]+/latest/jdk-[0-9]+_macos-aarch64_bin.tar.gz' | head -n 1)
elif [ "$ARCH" = "x86_64" ]; then
    JDK_URL=$(curl -sL $JDK_PAGE_URL | grep -oE 'https://download.oracle.com/java/[0-9]+/latest/jdk-[0-9]+_macos-x64_bin.tar.gz' | head -n 1)
else
    color_echo $RED "Unsupported architecture: $ARCH"
    exit 1
fi

if [ -z "$JDK_URL" ]; then
    color_echo $RED "Failed to find the latest JDK download link."
    exit 1
fi

DOWNLOAD_LOCATION="$HOME/Downloads"
EXTRACT_LOCATION="$DOWNLOAD_LOCATION/jdk_extract"
JAVA_VM_DIR="$HOME/Library/Java/JavaVirtualMachines"

# Create necessary directories
mkdir -p "$EXTRACT_LOCATION" "$JAVA_VM_DIR"

# Download and extract JDK
color_echo $YELLOW "Downloading and extracting JDK from $JDK_URL..."
curl -L "$JDK_URL" | tar -xz -C "$EXTRACT_LOCATION"

# Get extracted directory name
JDK_DIR_NAME=$(ls "$EXTRACT_LOCATION" | grep 'jdk')

if [ -n "$JDK_DIR_NAME" ]; then
    if [ ! -d "$JAVA_VM_DIR/$JDK_DIR_NAME" ]; then
        mv "$EXTRACT_LOCATION/$JDK_DIR_NAME" "$JAVA_VM_DIR/" || {
            color_echo $RED "Failed to move JDK to $JAVA_VM_DIR."
            rm -rf "$EXTRACT_LOCATION"
            exit 1
        }
        color_echo $GREEN "Java installed successfully."
    else
        color_echo $BLUE "Java is already installed. Cleaning up extracted files."
    fi
else
    color_echo $RED "JDK extraction failed. Cleaning up."
    rm -rf "$EXTRACT_LOCATION"
    exit 1
fi

# Cleanup
rm -rf "$EXTRACT_LOCATION"

# Step 4: Clone scripts repository -------------------------------------------

echo ""

centered_color_echo $ORANGE "<-------------- Scripts Repository Configuration -------------->"

echo ""

# Check if the "scripts" repository already exists in the specified directory
SCRIPTS_REPO_DIRECTORY="$HOME/scripts"
if [ -d "$SCRIPTS_REPO_DIRECTORY" ]; then
	color_echo $GREEN "The 'scripts' directory already exists in '$SCRIPTS_REPO_DIRECTORY'. Skipping clone of repository."
else
	# Ask the user if they want to clone the "scripts" repository
	color_echo $YELLOW "The 'scripts' directory does not exist in '$SCRIPTS_REPO_DIRECTORY'."
	if auto_prompt "Do you want to clone the scripts repository?" 10 "y" $YELLOW; then
		git_clone_fallback "git@github.com:av1155/scripts.git" "https://github.com/av1155/scripts.git" "$SCRIPTS_REPO_DIRECTORY"
	else
		color_echo $GREEN "Skipping scripts repository cloning."
	fi
fi

# Step 5: Clone .dotfiles repository -------------------------------------------

echo ""

centered_color_echo $ORANGE "<-------------- Dotfiles + BootStrap Repository Configuration -------------->"

echo ""

DOTFILES_DIR="$HOME/.dotfiles"
if [ ! -d "$DOTFILES_DIR" ]; then
	if auto_prompt "Do you want to clone the .dotfiles repository?" 10 "y" $YELLOW; then
		color_echo $BLUE "Cloning .dotfiles repository..."
		git_clone_fallback "git@github.com:av1155/.dotfiles.git" "https://github.com/av1155/.dotfiles.git" "$DOTFILES_DIR"
	else
		color_echo $GREEN "Skipping clone of repository."
		echo ""
	fi
else
	color_echo $GREEN "The '.dotfiles' directory already exists in '$DOTFILES_DIR'. Skipping clone of repository."
	echo ""
fi

# Install software from Brewfile -----------------------------------------------

if auto_prompt "Do you want to proceed with installing software from Brewfile?" 10 "y" $YELLOW; then
    color_echo $BLUE "Installing software from Brewfile..."
    brew bundle --file "$DOTFILES_DIR/App-Configs/configs/MacOS-Bootstrap/Brewfile" || {
        color_echo $RED "Failed to install software from Brewfile."
        if auto_prompt "The Brewfile installation failed. Do you want to continue with the rest of the script?" 10 "n" $YELLOW; then
            color_echo $YELLOW "Continuing with the rest of the script..."
        else
            color_echo $RED "Aborting the script as requested."
            exit 1
        fi
    }
    color_echo $GREEN "Brewfile installation complete."
else
    color_echo $RED "Brewfile installation aborted."
fi

echo ""

# Install Neovim if Brewfile installation was unsuccessful
install_neovim

# Step 5.1: Check and Prompt for Cloning CondaBackup repository ---------------------------------------

echo ""

centered_color_echo $ORANGE "<-------------- CondaBackup Repository Configuration -------------->"

echo ""

CONDA_BACKUP_DIR="$HOME/CondaBackup"
if [ ! -d "$CONDA_BACKUP_DIR" ]; then
	if auto_prompt "The 'CondaBackup' directory does not exist. Do you want to clone the CondaBackup repository?" 10 "y" $YELLOW; then
    	color_echo $BLUE "Cloning CondaBackup repository..."
    	git_clone_fallback "git@github.com:av1155/CondaBackup.git" "https://github.com/av1155/CondaBackup.git" "$CONDA_BACKUP_DIR" ||
        	{
            	color_echo $RED "Failed to clone CondaBackup repository."
            	exit 1
        	}
	else
		color_echo $BLUE "Skipping cloning of CondaBackup repository."
	fi
else
	color_echo $GREEN "The 'CondaBackup' directory already exists in '$CONDA_BACKUP_DIR'. Skipping clone of repository."
fi

# Step 5.2: Prompt for Restoring Conda environments ---------------------------------------

echo ""

centered_color_echo $ORANGE "<-------------- Restoring Conda Environments -------------->"

echo ""

if auto_prompt "Do you want to restore Conda environments from the backup?" 10 "y" $YELLOW; then
    BACKUP_DIR="${HOME}/CondaBackup"

    if [ -d "$BACKUP_DIR" ]; then
        color_echo $BLUE "Restoring Conda environments from $BACKUP_DIR..."

        # Check and restore the base environment if a backup exists
        BASE_ENV_YML="$BACKUP_DIR/base.yml"
        if [ -f "$BASE_ENV_YML" ]; then
            color_echo $GREEN "\nRestoring the base environment..."
            if ! conda env update --file "$BASE_ENV_YML" --prune 2>/dev/null; then
                color_echo $RED "Failed to restore the base environment: prefix already exists."
                if auto_prompt "The base environment already exists. Do you want to force the restoration?" 10 "n" $YELLOW; then
                    color_echo $YELLOW "Forcing restoration of the base environment..."
                    conda env update --file "$BASE_ENV_YML" --prune --force || {
                        color_echo $RED "Failed to force restore the base environment. Exiting."
                        exit 1
                    }
                else
                    color_echo $BLUE "Skipping forced restoration of the base environment."
                fi
            fi
        else
            color_echo $YELLOW "No base.yml file found. Skipping base environment restoration."
        fi

        # Restore other environments
        for yml_file in "$BACKUP_DIR"/*.yml; do
            env_name=$(basename "$yml_file" .yml)
            if [ "$env_name" != "base" ]; then
                color_echo $GREEN "\nRestoring environment $env_name..."
                conda env create --name "$env_name" --file "$yml_file" || {
                    color_echo $RED "Failed to restore environment $env_name."
                }
            fi
        done

        color_echo $GREEN "All Conda environments have been restored."
        color_echo $ORANGE "====================================================================================\n"
    else
        color_echo $RED "Backup directory $BACKUP_DIR not found. Skipping..."
    fi

else
    color_echo $BLUE "Skipping Conda environment restoration."
fi


# Step 6: Backup existing files and then run stow ------------------------------
echo ""

centered_color_echo $ORANGE "<-------------- Backup Existing Files and Stow -------------->"

echo ""

# Navigate to the .dotfiles directory
cd "$HOME/.dotfiles" || {
    color_echo $RED "Failed to change directory to $HOME/.dotfiles."
    exit 1
}

# Backup any existing conflicting files
backup_existing_files

# Run stow after backing up files
color_echo $BLUE "Running stow --restow */ to create symlinks..."
stow --restow */ || {
    color_echo $RED "Failed to stow dotfiles."
    exit 1
}

color_echo $GREEN "Successfully stowed dotfiles."

cd - || {
	color_echo $RED "Failed to change back to the previous directory."
	exit 1
}


# Step 7: Create symlinks (Idempotent) ----------------------------------------

echo ""

centered_color_echo $ORANGE "<-------------- Symlinks Configuration -------------->"

echo ""

color_echo $BLUE "Creating symlinks..."

# Symlinks go here:
# create_symlink "$DOTFILES_DIR/configs/.original_file" "$HOME/.linked_file"
create_symlink "/opt/homebrew/bin/gdu-go" "/opt/homebrew/bin/gdu"

# Set up bat themes by building the cache
color_echo $BLUE "\nBuilding bat cache for themes..."
bat cache --build
bat --list-themes | grep Catppuccin

# Inform the user about setting up GitHub Copilot CLI
color_echo $YELLOW "\nSetting up GitHub Copilot CLI..."

# Check if already logged in to GitHub CLI
if ! gh auth status >/dev/null 2>&1; then
	color_echo $RED "Not logged in to GitHub. Please log in."
	gh auth login
else
	color_echo $GREEN "Already logged in to GitHub."
fi

# Set up gh for GitHub CLI
# Check if gh-copilot is already installed
if ! gh extension list | grep -q "gh-copilot"; then
	color_echo $BLUE "Installing gh-copilot extension..."
	gh extension install github/gh-copilot
	gh copilot config
else
	color_echo $GREEN "gh-copilot extension is already installed."
fi

# Step 8: Install NVM, Node.js, & npm -----------------------------------------

echo ""

centered_color_echo $ORANGE "<-------------- Configuration of NVM, NODE, & NPM -------------->"

echo ""

# Check if NVM (Node Version Manager) is installed ----------------------------
if [ ! -d "$HOME/.nvm" ]; then
    if auto_prompt "Do you want to install NVM?" 10 "y" $YELLOW; then
        # Fetch the latest NVM version from the README on GitHub
        LATEST_NVM_VERSION=$(curl -sL 'https://raw.githubusercontent.com/nvm-sh/nvm/refs/heads/master/README.md' \
                            | grep -oE 'curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v[0-9]+\.[0-9]+\.[0-9]+/install.sh' \
                            | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' \
                            | head -n 1)
        
        # Default to v0.40.1 if no version is found
        if [ -z "$LATEST_NVM_VERSION" ]; then
            color_echo $RED "Failed to fetch the latest NVM version, defaulting to v0.40.1."
            LATEST_NVM_VERSION="v0.40.1"
        fi
        
        # Install NVM
        color_echo $BLUE "Installing Node Version Manager (nvm) version $LATEST_NVM_VERSION..."
        curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/${LATEST_NVM_VERSION}/install.sh" | bash || {
            color_echo $RED "Failed to install nvm."
            exit 1
        }
    else
        color_echo $GREEN "Skipping NVM installation."
        exit 0
    fi
fi

# Load NVM for the current session if it's installed
export NVM_DIR="$HOME/.nvm"
if [ -s "$NVM_DIR/nvm.sh" ]; then
    . "$NVM_DIR/nvm.sh" # This loads nvm
else
    color_echo $RED "NVM installation was unsuccessful or not found in $NVM_DIR."
    exit 1
fi

echo ""

# Check if Node is installed --------------------------------------------------
if ! command -v node &>/dev/null; then
	# Install Node.js using NVM if it's not installed
	color_echo $BLUE "Installing Node.js..."
	nvm install node || {
		color_echo $RED "Failed to install Node.js."
		exit 1
	}
else
	color_echo $GREEN "Node.js already installed, checking for updates..."

	# Get the current version of Node.js
	CURRENT_NODE_VERSION=$(nvm current | sed 's/\x1b\[[0-9;]*m//g')

	# Get the latest LTS Node.js version and strip ANSI escape codes
	LATEST_LTS_VERSION=$(nvm ls-remote --lts | tail -1 | awk '{ print $2 }' | sed 's/\x1b\[[0-9;]*m//g')

	# Debug: Print versions for checking
	echo "Current Node version:${PURPLE} ${CURRENT_NODE_VERSION} ${NC}"
	echo "Latest LTS version:${PURPLE} ${LATEST_LTS_VERSION} ${NC}"

	if [ "$CURRENT_NODE_VERSION" != "$LATEST_LTS_VERSION" ]; then
		# Install the latest LTS Node.js version and reinstall packages from the current version
		nvm install --lts --reinstall-packages-from="$CURRENT_NODE_VERSION" || {
			color_echo $RED "Failed to update Node.js."
			exit 1
		}

		# Switch to the latest Node.js version
		nvm use --lts || {
			color_echo $RED "Failed to switch to the latest Node.js version."
			exit 1
		}

		# Check the new current version after update
		NEW_NODE_VERSION=$(nvm current | sed 's/\x1b\[[0-9;]*m//g')

		# Uninstall the old version if it's different from the new version
		if [ "$NEW_NODE_VERSION" != "$CURRENT_NODE_VERSION" ]; then
			color_echo $BLUE "Uninstalling the old version of Node.js ${PURPLE}${CURRENT_NODE_VERSION}${NC}..."
			nvm uninstall "$CURRENT_NODE_VERSION" || {
				color_echo $RED "Failed to uninstall the old version of Node.js."
				exit 1
			}
		fi

	else
		color_echo $YELLOW "Already on the latest LTS version of Node.js."
	fi

	# Prompt for updating global npm packages
	if auto_prompt "Do you want to update global npm packages?" 10 "y" $YELLOW; then
		color_echo $GREEN "Updating global npm packages..."
		npm update -g || {
			color_echo $RED "Failed to update global npm packages."
			exit 1
		}
	else
		color_echo $BLUE "Skipping global npm package updates."
	fi

	color_echo $GREEN "Node.js is up to date."
fi

echo ""

# Install Global npm Packages: ------------------------------------------------
color_echo $BLUE "Installing global npm packages..."

# Check and install tree-sitter-cli
if ! npm list -g tree-sitter-cli &>/dev/null; then
	color_echo $BLUE " * Installing tree-sitter-cli..."
	npm install -g tree-sitter-cli || {
		color_echo $YELLOW "Regular installation failed. Attempting with --force..."
		npm install -g tree-sitter-cli --force || {
			color_echo $RED "Failed to install tree-sitter-cli."
			exit 1
		}
	}
else
	color_echo $GREEN " * tree-sitter-cli already installed."
fi

# Check and install live-server
if ! npm list -g live-server &>/dev/null; then
	color_echo $BLUE " * Installing live-server..."
	npm install -g live-server || {
		color_echo $YELLOW "Regular installation failed. Attempting with --force..."
		npm install -g live-server --force || {
			color_echo $RED "Failed to install live-server."
			exit 1
		}
	}
else
	color_echo $GREEN " * live-server already installed."
fi

# Check and install neovim
if ! npm list -g neovim &>/dev/null; then
	color_echo $BLUE " * Installing neovim..."
	npm install -g neovim || {
		color_echo $YELLOW "Regular installation failed. Attempting with --force..."
		npm install -g neovim --force || {
			color_echo $RED "Failed to install neovim."
			exit 1
		}
	}
else
	color_echo $GREEN " * neovim already installed."
fi

# Check and install TypeScript
if ! npm list -g typescript &>/dev/null; then
	color_echo $BLUE " * Installing TypeScript..."
	npm install -g typescript || {
		color_echo $YELLOW "Regular installation failed. Attempting with --force..."
		npm install -g typescript --force || {
			color_echo $RED "Failed to install TypeScript."
			exit 1
		}
	}
else
	color_echo $GREEN " * TypeScript already installed."
fi

# Prompt to Install CocoaPods and Run Flutter Doctor -----------------------------------

if auto_prompt "Do you want to install CocoaPods and verify Flutter setup?" 10 "y" $YELLOW; then
    color_echo $BLUE "Installing CocoaPods..."
    gem install cocoapods || {
        color_echo $RED "Failed to install CocoaPods."
        exit 1
    }
    color_echo $GREEN "CocoaPods installation complete."

    # Run Flutter Doctor
    color_echo $BLUE "Running Flutter Doctor to verify setup..."
    flutter doctor -v
    color_echo $GREEN "Flutter setup verification complete."
else
    color_echo $BLUE "Skipping CocoaPods installation and Flutter setup verification."
fi

# Enable Corepack and Use Latest Version of pnpm --------------------------------------

if auto_prompt "Do you want to enable Corepack and set up pnpm?" 10 "y" $YELLOW; then
    color_echo $BLUE "Enabling Corepack and setting up pnpm..."
    corepack enable
    corepack prepare pnpm@latest --activate
    color_echo $GREEN "pnpm setup complete."
else
    color_echo $BLUE "Skipping pnpm setup."
fi

# Step 9: Install Nerd Font --------------------------------------------------

echo ""

centered_color_echo $ORANGE "<-------------- Configuration of Nerd Fonts -------------->"

echo ""

# JetBrainsMonoNerdFont-Regular.ttf
# FiraCodeNerdFont-Regular.ttf

FONT_NAME="JetBrainsMono"
FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1/$FONT_NAME.zip"
FONT_DIR="$HOME/Library/Fonts"
FONT_FILE="$FONT_DIR/${FONT_NAME}NerdFont-Regular.ttf"

# Check if the font is already installed
if [ -f "$FONT_FILE" ]; then
	color_echo $GREEN "$FONT_NAME Nerd Font is already installed."
else
	# Confirmation prompt for font installation
	if auto_prompt "Do you want to proceed installing $FONT_NAME Nerd Font?" 10 "n" $YELLOW; then
		color_echo $RED "Font installation aborted."
	else
		color_echo $BLUE "Installing $FONT_NAME Nerd Font..."
		if [ ! -d "$FONT_DIR" ]; then
			color_echo $BLUE "Creating font directory..."
			mkdir -p "$FONT_DIR"
		fi
		curl -L $FONT_URL -o "$FONT_DIR/$FONT_NAME.zip" || {
			color_echo $RED "Failed to download $FONT_NAME Nerd Font."
			exit 1
		}
		unzip "$FONT_DIR/$FONT_NAME.zip" -d "$FONT_DIR" || {
			color_echo $RED "Failed to unzip $FONT_NAME Nerd Font."
			exit 1
		}
		rm "$FONT_DIR/$FONT_NAME.zip"
		color_echo $GREEN "$FONT_NAME Nerd Font installation complete."
	fi
fi

# Step 10: Install AstroNvim Dependencies ------------------------------------

echo ""

centered_color_echo $ORANGE "<-------------- AstroNvim Dependencies Configuration -------------->"

echo ""

# PYNVIM SETUP -------------------------------->

# Determine the architecture (Intel or Apple Silicon)
arch_name="$(uname -m)"
if [ "$arch_name" = "x86_64" ]; then
	# Intel Macs
	PYTHON_PATH="/usr/local/miniforge3/bin/python3"
elif [ "$arch_name" = "arm64" ]; then
	# Apple Silicon Macs
	PYTHON_PATH="/opt/homebrew/Caskroom/miniforge/base/bin/python3"
else
	color_echo $RED "Unknown architecture: $arch_name"
	exit 1
fi

# Python AstroNvim dependencies
if ! $PYTHON_PATH -c "import pynvim" &>/dev/null; then
	color_echo $YELLOW " * pynvim not installed, installing..."
	$PYTHON_PATH -m pip install pynvim || {
		color_echo $RED "Failed to install pynvim."
		exit 1
	}
else
	color_echo $GREEN " * pynvim already installed."
fi

# END OF PYNVIM SETUP <<<

# PERL NEONVIM EXTENSION SETUP -------------------------------->

# Check if Perl is installed via Homebrew and install if necessary
if brew list perl &>/dev/null; then
	color_echo $GREEN " * Perl is already installed."
else
	color_echo $YELLOW " * Installing Perl..."
	brew install perl || {
		color_echo $RED "Failed to install Perl."
		exit 1
	}
fi

# Check and Configure local::lib
if [ -d "$HOME/perl5/lib/perl5" ] && grep -q 'perl5' <<<"$PERL5LIB"; then
	color_echo $GREEN " * local::lib is already configured."
else
	color_echo $YELLOW " * Configuring local::lib..."
	PERL_MM_OPT="INSTALL_BASE=$HOME/perl5" cpan local::lib || {
		color_echo $RED "Failed to configure local::lib."
		exit 1
	}
fi

# Check if cpanm is installed via Homebrew and install if necessary
if brew list cpanminus &>/dev/null; then
	color_echo $GREEN " * cpanm is already installed."
else
	color_echo $YELLOW " * Installing cpanm..."
	brew install cpanminus || {
		color_echo $RED "Failed to install cpanminus."
		exit 1
	}
fi

# Check if Neovim::Ext is installed and install if necessary
if perl -MNeovim::Ext -e 1 &>/dev/null; then
	color_echo $GREEN " * Neovim::Ext is already installed."
else
	color_echo $YELLOW " * Installing Neovim::Ext..."
	cpanm Neovim::Ext || {
		color_echo $RED "Failed to install Neovim::Ext."
		exit 1
	}
fi

# END OF PERL NEONVIM EXTENSION SETUP <<<

# RUBY ASTRONVIM SETUP -------------------------------->

color_echo $YELLOW " * Checking Ruby installation..."

# Determine the architecture (Intel or Apple Silicon)
arch_name="$(uname -m)"

# Determine the path of the current Ruby executable
current_ruby_path=$(which ruby)

# Determine the path of the gem executable
gem_executable=$(which gem)

if [ "$arch_name" = "arm64" ]; then
	# Apple Silicon Macs
	expected_ruby_path="/opt/homebrew/opt/ruby/bin/ruby"
elif [ "$arch_name" = "x86_64" ]; then
	# Intel Macs
	expected_ruby_path="/usr/local/opt/ruby/bin/ruby"
else
	color_echo $RED "Unknown architecture: $arch_name"
	exit 1
fi

# Check if the current Ruby is the expected Ruby based on architecture
if [[ "$current_ruby_path" == "$expected_ruby_path" ]]; then
	color_echo $YELLOW " * Ruby installed via Homebrew, installing neovim gem..."
	# Check if the neovim gem is already installed
	if gem list -i neovim >/dev/null 2>&1; then
		color_echo $GREEN " * Neovim gem already installed."
	else
		color_echo $YELLOW " * Installing neovim gem..."
		$gem_executable install neovim || {
			color_echo $RED "Failed to install neovim gem."
			exit 1
		}
	fi
else
	color_echo $GREEN " * Non-Homebrew Ruby detected. Please ensure Ruby from Homebrew is correctly set up."
fi

# Verify Lua 5.1 and LuaRocks are installed
if command -v lua5.1 &>/dev/null && command -v luarocks &>/dev/null; then
	color_echo $GREEN " * Lua 5.1 and LuaRocks are installed."

	# Install Magick LuaRock
	color_echo $YELLOW " * Installing Magick LuaRock..."
	luarocks --local --lua-version=5.1 install magick || {
		color_echo $RED "Failed to install Magick LuaRock."
		exit 1
	}

	color_echo $GREEN " * Magick LuaRock installed successfully."
else
	color_echo $RED " * Lua 5.1 or LuaRocks is not installed. Please install Lua 5.1 and LuaRocks first."
fi

# END OF RUBY ASTRONVIM SETUP <<<

# Install Composer for PHP development ---------------------------------------

echo ""

centered_color_echo $ORANGE "<-------------- Composer Installation for PHP Development -------------->"

echo ""

# Verify if Composer is already installed
if command -v composer >/dev/null 2>&1; then
	color_echo $GREEN " * Composer is already installed."
else
	# Download and verify Composer
	color_echo $YELLOW " * Downloading and verifying Composer..."
	php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
	php -r "if (hash_file('sha384', 'composer-setup.php') === 'e21205b207c3ff031906575712edab6f13eb0b361f2085f1f1237b7126d785e826a450292b6cfd1d64d92e6563bbde02') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;"
	php composer-setup.php
	php -r "unlink('composer-setup.php');"

	# Move Composer to a global directory
	color_echo $YELLOW " * Moving Composer to global directory..."
	sudo mv composer.phar /usr/local/bin/composer || {
		color_echo $RED "Failed to move Composer."
		exit 1
	}

	# Verify Composer installation
	color_echo $YELLOW " * Verifying Composer installation..."
	composer --version || {
		color_echo $RED "Composer installation failed."
		exit 1
	}

	color_echo $GREEN " * Composer installed successfully."
fi

# NeoVim-Configuration ---------------------------------------------------------

echo ""

centered_color_echo $ORANGE "<-------------- Setting Up AstroNvim v4+ -------------->"

echo ""

# Check if the Neovim configuration directory exists
if [ -d "$HOME/.config/nvim" ]; then
	color_echo $YELLOW "An existing Neovim configuration has been detected."
	if auto_prompt "Do you want to KEEP the current Neovim configuration?" 10 "y" $YELLOW; then
		color_echo $GREEN "Keeping the existing configuration. No changes made."

	else
		# Backing up existing Neovim configurations
		color_echo $BLUE "Backing up existing Neovim configurations..."
		mv ~/.config/nvim ~/.config/nvim.bak
		mv ~/.local/share/nvim ~/.local/share/nvim.bak
		mv ~/.local/state/nvim ~/.local/state/nvim.bak
		mv ~/.cache/nvim ~/.cache/nvim.bak
		color_echo $GREEN "Backup completed."

		# Ask the user if they want to delete the backed-up .local/share/nvim and .local/state/nvim directories
		color_echo $YELLOW "The backup of .local/share/nvim and .local/state/nvim may take up significant space."
		if auto_prompt "Would you like to delete the backed-up .local/share/nvim.bak and .local/state/nvim.bak directories to save space?" 10 "y" $YELLOW; then
			rm -rf ~/.local/share/nvim.bak ~/.local/state/nvim.bak
			color_echo $GREEN "The backed-up .local/share/nvim.bak and .local/state/nvim.bak directories have been deleted."
		else
			color_echo $BLUE "The backed-up directories have been retained."
		fi

		# Cloning the new configuration repository
		color_echo $BLUE "Cloning the new AstroNvim configuration..."
		git_clone_fallback "git@github.com:av1155/Neovim-Config.git" "https://github.com/av1155/Neovim-Config.git" "$HOME/.config/nvim"
		color_echo $GREEN "Clone completed."
	fi
else
	color_echo $GREEN "No existing Neovim configuration found. Proceeding with setup..."

	# Cloning the new configuration repository
	color_echo $BLUE "Cloning the new AstroNvim configuration..."
	git_clone_fallback "git@github.com:av1155/Neovim-Config.git" "https://github.com/av1155/Neovim-Config.git" "$HOME/.config/nvim"
	color_echo $GREEN "Clone completed."
fi

# Check if Neovim is installed
if command -v nvim &>/dev/null; then
	color_echo $GREEN "Neovim is installed. Running Neovim in headless mode to initialize..."

	# Start Neovim in headless mode and then exit
	nvim --headless -c 'quitall'
	color_echo $GREEN "Neovim has been initialized in headless mode."
else
	color_echo $YELLOW "Neovim is not installed. Please install Neovim to proceed."
fi


# Step 12: Docker, Ollama, and Open WebUI -------------------------------

echo ""
centered_color_echo $ORANGE "<-------------- Docker, Ollama, and Open WebUI -------------->"
echo ""

# Prompt to set up Open WebUI
if auto_prompt "Would you like to set up Open WebUI with the following command?\n${BLUE}docker run -d -p 8080:8080 -v open-webui:/app/backend/data -e OLLAMA_BASE_URL=http://host.docker.internal:11434 --name open-webui --restart always ghcr.io/open-webui/open-webui:main${NC}" 10 "y" $YELLOW; then
    # Step 1: Check for Docker installation
    if ! command -v docker &>/dev/null; then
        color_echo $RED "Docker is not installed."

        # Prompt to install Docker
		if auto_prompt "Would you like to download and install Docker?" 10 "y" $YELLOW; then
            docker_dmg_path="$HOME/Downloads/Docker.dmg"
            color_echo $BLUE "Downloading Docker..."
            curl -L -o "$docker_dmg_path" "https://desktop.docker.com/mac/main/arm64/Docker.dmg" || {
                color_echo $RED "Failed to download Docker."
                exit 1
            }
            color_echo $GREEN "Docker downloaded to $docker_dmg_path"

            # Mount and open the Docker DMG
            hdiutil attach "$docker_dmg_path" -quiet || {
                color_echo $RED "Failed to mount Docker DMG."
                exit 1
            }
            open /Volumes/Docker/Docker.app
            color_echo $YELLOW "Please complete the Docker installation. Press Enter when done."
            read -r

            # Unmount Docker DMG
            hdiutil detach "/Volumes/Docker" -quiet
            color_echo $GREEN "Docker DMG unmounted."

            # Confirm Docker installation
            if ! command -v docker &>/dev/null; then
                color_echo $RED "Docker installation did not complete successfully. Please install manually."
                exit 1
            fi
        else
            color_echo $BLUE "Skipping Docker installation."
            exit 1
        fi
    else
        color_echo $GREEN "Docker is already installed. Version: $(docker -v)"
    fi

	# Step 2: Check for Ollama installation
	if ! command -v ollama &>/dev/null; then
    	color_echo $RED "Ollama is not installed. Please install Ollama to proceed."
    	exit 1
	else
    	color_echo $GREEN "Ollama is installed. Version: $(ollama -v)"
	fi

	# Prompt to pull specific models using Ollama
	models=("llama3.1:8b" "qwen2.5-coder:7b")

	for model in "${models[@]}"; do
		if auto_prompt "Would you like to pull the model ${BLUE}$model${YELLOW} using Ollama?" 10 "y" $YELLOW; then
        	color_echo $BLUE "Pulling model $model..."
        	ollama pull "$model" || {
            	color_echo $RED "Failed to pull model $model. Please check your Ollama installation or try again later."
        	}
    	else
        	color_echo $BLUE "Skipping model pull for $model."
    	fi
	done

    # Step 3: Check if Open WebUI container and image already exist
    if docker ps -a --filter "name=open-webui" --format "{{.Names}}" | grep -q "open-webui"; then
        color_echo $YELLOW "An existing Open WebUI container was found."

        # Prompt to handle the existing container
        echo -n "Would you like to restart the existing container, recreate it, or skip? (r/restart, c/recreate, s/skip): "
        read -r container_action
        case "$container_action" in
            r | restart)
                color_echo $BLUE "Restarting existing Open WebUI container..."
                docker start open-webui
                ;;
            c | recreate)
                color_echo $BLUE "Recreating Open WebUI container..."
                docker rm -f open-webui
                docker run -d -p 8080:8080 -v open-webui:/app/backend/data -e OLLAMA_BASE_URL=http://host.docker.internal:11434 --name open-webui --restart always ghcr.io/open-webui/open-webui:main
                ;;
            *)
                color_echo $BLUE "Skipping Open WebUI setup."
                ;;
        esac
    else
        # No existing container; check if the image is available
        if docker images -q ghcr.io/open-webui/open-webui:main &>/dev/null; then
            color_echo $YELLOW "The Open WebUI image is already available locally."

            # Prompt to use existing image or pull a fresh one
            echo -n "Would you like to use the existing image or pull the latest? (e/existing, l/latest): "
            read -r image_choice
            if [[ "$image_choice" =~ ^[Ll]$ ]]; then
                color_echo $BLUE "Pulling the latest Open WebUI image..."
                docker pull ghcr.io/open-webui/open-webui:main
            fi
        else
            color_echo $BLUE "Pulling the Open WebUI image..."
            docker pull ghcr.io/open-webui/open-webui:main
        fi

        # Run the container
        color_echo $BLUE "Setting up Open WebUI container..."
        docker run -d -p 8080:8080 -v open-webui:/app/backend/data -e OLLAMA_BASE_URL=http://host.docker.internal:11434 --name open-webui --restart always ghcr.io/open-webui/open-webui:main || {
            color_echo $RED "Failed to set up Open WebUI."
            exit 1
        }
        color_echo $GREEN "Open WebUI setup complete."
    fi
else
    color_echo $BLUE "Skipping Open WebUI setup."
fi


# Step 13: Create TODO List of Apps to Download -------------------------------

echo ""

centered_color_echo $ORANGE "<-------------- TODO List of Apps to Download -------------->"

echo ""

# Define the list of apps
app_list=(
	"The following apps were not installed with Homebrew and need to be downloaded manually:"
	"balenaEtcher.app"
	"Bartender 5.app"
	"Bitwarden.app"
	"ChatGPT.app"
	"CleanMyMac X.app"
	"Color Picker.app"
	"CrystalFetch.app"
	"Docker.app"
	"Dropover.app"
	"Encrypto.app"
	"Final Cut Pro.app"
	"Grammarly for Safari.app"
	"jd-gui-1.6.6.jar"
	"jd-gui.cfg"
	"LockDown Browser.app"
	"Noir.app"
	"OneDrive.app"
	"OpenVPN Connect"
	"OpenVPN Connect.app"
	"Python 3.11"
	"Raspberry Pi Imager.app"
	"Ryujinx.app"
	"Synology Active Backup for Business Agent.app"
	"Synology Drive Client.app"
	"Xcode.app"
)

# Define the path of the text file
desktop_path="$HOME/Desktop/apps_to_download.txt"

# Always create or overwrite the file and write the app list
printf "%s\n" "${app_list[@]}" >"$desktop_path"

# Print a message to inform the user
color_echo $BLUE "A TODO list of apps to download has been created/updated on your desktop: $desktop_path"

# -----------------------------------------------------------------------------

echo ""

centered_color_echo $ORANGE "<-------------- Thank You! -------------->"

echo ""

color_echo $PURPLE "🚀 Installation successful! Your development environment is now supercharged and ready for lift-off. Please restart your computer to finalize the setup. Happy coding!    "

# -----------------------------------------------------------------------------
