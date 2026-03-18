#!/usr/bin/env bash

set -e

DOTFILES_DIR="$HOME/.dotfiles"
BACKUP_SUFFIX=".bak"
DRY_RUN=0
NON_INTERACTIVE=0

print_usage() {
    cat <<EOF
Usage: $0 [OPTION]

Options:
  -n, --dry-run   Show what would happen without making changes
  -y, --yes       Run non-interactively and apply changes
  -h, --help      Show this help message

If no option is provided, the script will ask whether to run a dry run
or apply changes.
EOF
}

run_cmd() {
    if [ "$DRY_RUN" -eq 1 ]; then
        printf '  WOULD run:'
        printf ' %q' "$@"
        printf '\n'
    else
        "$@"
    fi
}

for arg in "$@"; do
    case "$arg" in
    -n | --dry-run)
        DRY_RUN=1
        ;;
    -y | --yes)
        NON_INTERACTIVE=1
        ;;
    -h | --help)
        print_usage
        exit 0
        ;;
    *)
        echo "Error: unknown argument: $arg" >&2
        print_usage >&2
        exit 1
        ;;
    esac
done

echo "================================================"
echo "  Dotfiles Installation Script"
echo "================================================"
echo ""

if [ ! -d "$DOTFILES_DIR" ]; then
    echo "Error: $DOTFILES_DIR not found" >&2
    exit 1
fi

if ! command -v stow &>/dev/null; then
    echo "Error: GNU Stow is not installed" >&2
    echo "Install it with:"
    echo "  macOS:  brew install stow"
    echo "  Arch:   sudo pacman -S stow"
    echo "  Debian: sudo apt install stow"
    exit 1
fi

if [ "$NON_INTERACTIVE" -eq 0 ] && [ "$DRY_RUN" -eq 0 ]; then
    echo "Choose mode:"
    echo "  1) Dry run (show what would happen)"
    echo "  2) Apply changes"
    echo ""
    echo -n "Select an option (1-2, default 1): "
    read -r mode_choice

    case "${mode_choice:-1}" in
    1)
        DRY_RUN=1
        ;;
    2)
        DRY_RUN=0
        ;;
    *)
        echo "Invalid option. Defaulting to dry run."
        DRY_RUN=1
        ;;
    esac
    echo ""
fi

if [ "$DRY_RUN" -eq 1 ]; then
    echo "DRY RUN MODE: no filesystem changes will be made"
    echo ""
fi

cd "$DOTFILES_DIR" || exit 1

echo "Step 1: Analyzing .dotfiles structure..."

# Build explicit packages array.
# Include .opencode if present, but exclude .git.
packages=()
while IFS= read -r dir; do
    dir_name=$(basename "$dir")
    if [ "$dir_name" != ".git" ] && [ -d "$dir_name" ]; then
        packages+=("$dir_name")
    fi
done < <(find . -maxdepth 1 -mindepth 1 -type d ! -name '.git' | sort)

if [ ${#packages[@]} -eq 0 ]; then
    echo "Error: no stow packages found in $DOTFILES_DIR" >&2
    exit 1
fi

echo "  Detected ${#packages[@]} package(s): ${packages[*]}"

# Detect base directories
base_dirs=()
for package in "${packages[@]}"; do
    while IFS= read -r -d '' subdir; do
        dirname=$(basename "$subdir")

        if [[ "$dirname" =~ ^\. ]] || [ "$dirname" = "Library" ]; then
            if [[ ! " ${base_dirs[*]} " =~ $dirname ]]; then
                base_dirs+=("$dirname")
            fi
        fi
    done < <(find "$package" -mindepth 1 -maxdepth 1 -type d -print0)
done

if [ ${#base_dirs[@]} -eq 0 ]; then
    echo "  No base directories detected"
else
    echo "  Detected base directories: ${base_dirs[*]}"
fi
echo ""

echo "Step 2: Creating base directories..."
for dir in "${base_dirs[@]}"; do
    target="$HOME/$dir"
    if [ ! -d "$target" ]; then
        if [ "$DRY_RUN" -eq 1 ]; then
            echo "  WOULD create $target"
        else
            mkdir -p "$target"
            echo "  ✓ Created $target"
        fi
    else
        echo "  - Skipping $target (already exists)"
    fi
done
echo ""

echo "Step 3: Checking for conflicts..."
conflicts=()

stow_output=$(stow --simulate --restow "${packages[@]}" 2>&1 || true)

if echo "$stow_output" | grep -q "existing target is"; then
    while IFS= read -r line; do
        if [[ "$line" =~ existing\ target\ is ]]; then
            conflict_file=$(echo "$line" | sed -E 's/.*existing target is (neither a link nor a directory|not owned by stow): (.*)/\2/')
            if [ -n "$conflict_file" ]; then
                conflicts+=("$conflict_file")
            fi
        fi
    done <<<"$stow_output"
fi

# Separate conflicts into files and directories
file_conflicts=()
dir_conflicts=()
for conflict in "${conflicts[@]}"; do
    if [ -f "$HOME/$conflict" ] && [ ! -L "$HOME/$conflict" ]; then
        file_conflicts+=("$conflict")
    elif [ -d "$HOME/$conflict" ] && [ ! -L "$HOME/$conflict" ]; then
        dir_conflicts+=("$conflict")
    fi
done

if [ ${#file_conflicts[@]} -eq 0 ] && [ ${#dir_conflicts[@]} -eq 0 ]; then
    echo "  No conflicts detected"
else
    echo "  Found ${#conflicts[@]} conflict(s)"
fi
echo ""

if [ ${#file_conflicts[@]} -gt 0 ] || [ ${#dir_conflicts[@]} -gt 0 ]; then
    echo "Step 4: Handling conflicts..."

    if [ ${#file_conflicts[@]} -gt 0 ]; then
        if [ "$DRY_RUN" -eq 1 ]; then
            echo "  WOULD back up ${#file_conflicts[@]} conflicting file(s):"
        else
            echo "  Backing up ${#file_conflicts[@]} conflicting file(s)..."
        fi

        for conflict in "${file_conflicts[@]}"; do
            backup="$HOME/${conflict}${BACKUP_SUFFIX}"
            if [ "$DRY_RUN" -eq 1 ]; then
                echo "  WOULD move $HOME/$conflict -> $backup"
            else
                mv "$HOME/$conflict" "$backup"
                echo "  ✓ Moved $conflict → ${conflict}${BACKUP_SUFFIX}"
            fi
        done
    fi

    if [ ${#dir_conflicts[@]} -gt 0 ]; then
        if [ "$DRY_RUN" -eq 1 ]; then
            echo "  WOULD skip ${#dir_conflicts[@]} conflicting directory(s):"
        else
            echo "  ⚠️  Skipping ${#dir_conflicts[@]} conflicting directory(s):"
        fi
        for conflict in "${dir_conflicts[@]}"; do
            echo "  - $conflict (directory conflicts require manual review)"
        done
        echo "  Note: Directories are not automatically backed up for safety."
    fi

    echo ""
fi

echo "Step 5: Running stow..."
if [ "$DRY_RUN" -eq 1 ]; then
    printf '  WOULD run:'
    printf ' %q' stow --restow "${packages[@]}"
    printf '\n'
    echo "  ✓ Dry run completed successfully"
else
    if stow --restow "${packages[@]}" 2>&1; then
        echo "  ✓ Stow completed successfully"
    else
        echo "  ✗ Stow encountered errors" >&2
        exit 1
    fi
fi
echo ""

echo "================================================"
if [ "$DRY_RUN" -eq 1 ]; then
    echo "  Dry Run Complete!"
else
    echo "  Installation Complete!"
fi
echo "================================================"
echo ""
echo "Summary:"
echo "  - Base directories detected: ${#base_dirs[@]}"
echo "  - Packages processed: ${#packages[@]}"
if [ ${#file_conflicts[@]} -gt 0 ]; then
    if [ "$DRY_RUN" -eq 1 ]; then
        echo "  - Conflicting files that would be backed up: ${#file_conflicts[@]}"
    else
        echo "  - Conflicting files backed up: ${#file_conflicts[@]}"
    fi
fi
if [ ${#dir_conflicts[@]} -gt 0 ]; then
    echo "  - Conflicting directories skipped: ${#dir_conflicts[@]}"
fi
echo ""
if [ "$DRY_RUN" -eq 1 ]; then
    echo "No changes were made."
else
    echo "Backup files (if any) are saved with '$BACKUP_SUFFIX' extension"
    echo "You can now start a new shell or run: exec zsh"
fi
echo ""

echo "Would you like to run the troubleshooting menu? (y/N)"
read -r response
if [[ "$response" =~ ^[Yy]$ ]]; then
    while true; do
        echo ""
        echo "================================================"
        echo "  Troubleshooting Menu"
        echo "================================================"
        echo ""
        echo "  1) Fix Tmux Plugin Manager (TPM)"
        echo "  2) Reinstall all Tmux plugins"
        echo "  3) Reset Tmux configuration completely"
        echo "  4) Exit"
        echo ""
        echo -n "Select an option (1-4): "
        read -r choice

        case $choice in
        1)
            echo ""
            echo "Fixing Tmux Plugin Manager..."

            if [ -d "$HOME/.tmux/plugins/tpm" ]; then
                echo "  - TPM directory already exists"
            else
                echo "  - Installing TPM..."
                run_cmd git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
                [ "$DRY_RUN" -eq 1 ] || echo "  ✓ TPM installed"
            fi

            if [ -f "$HOME/.config/tmux/tmux.conf" ]; then
                echo "  - Reloading tmux configuration..."
                if [ "$DRY_RUN" -eq 1 ]; then
                    echo "  WOULD run: tmux source-file $HOME/.config/tmux/tmux.conf"
                else
                    tmux source-file "$HOME/.config/tmux/tmux.conf" 2>/dev/null && echo "  ✓ Configuration reloaded" || echo "  ! No active tmux session"
                fi
            fi

            if [ "$DRY_RUN" -eq 1 ]; then
                echo "  WOULD create $HOME/.tmux_tpm_setup_complete"
            else
                touch "$HOME/.tmux_tpm_setup_complete"
                echo "  ✓ TPM setup marker created"
            fi

            echo ""
            echo "To install plugins, either:"
            echo "  - Press Ctrl+A then I (inside tmux)"
            echo "  - Run: ~/.tmux/plugins/tpm/bin/install_plugins"
            ;;

        2)
            echo ""
            echo "Reinstalling all Tmux plugins..."

            if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
                echo "  ! TPM not found. Please run option 1 first."
            else
                echo "  - Cleaning old plugins..."
                if [ "$DRY_RUN" -eq 1 ]; then
                    echo "  WOULD remove directories under $HOME/.tmux/plugins except tpm"
                else
                    find "$HOME/.tmux/plugins" -mindepth 1 -maxdepth 1 -type d ! -name 'tpm' -exec rm -rf {} +
                fi

                echo "  - Installing plugins..."
                if [ "$DRY_RUN" -eq 1 ]; then
                    echo "  WOULD run: $HOME/.tmux/plugins/tpm/bin/install_plugins"
                else
                    "$HOME/.tmux/plugins/tpm/bin/install_plugins"
                    echo "  ✓ Plugins reinstalled"
                fi

                if [ -f "$HOME/.config/tmux/tmux.conf" ]; then
                    echo "  - Reloading configuration..."
                    if [ "$DRY_RUN" -eq 1 ]; then
                        echo "  WOULD run: tmux source-file $HOME/.config/tmux/tmux.conf"
                    else
                        tmux source-file "$HOME/.config/tmux/tmux.conf" 2>/dev/null && echo "  ✓ Configuration reloaded" || echo "  ! No active tmux session"
                    fi
                fi
            fi
            ;;

        3)
            echo ""
            echo "⚠️  WARNING: This will remove ALL tmux plugins and reinstall from scratch"
            echo -n "Are you sure? (y/N): "
            read -r confirm

            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                echo "  - Removing all plugin directories..."
                if [ "$DRY_RUN" -eq 1 ]; then
                    echo "  WOULD remove $HOME/.config/tmux/plugins and $HOME/.tmux/plugins"
                else
                    rm -rf "$HOME/.config/tmux/plugins" "$HOME/.tmux/plugins" 2>/dev/null
                fi

                echo "  - Creating fresh plugin directory..."
                if [ "$DRY_RUN" -eq 1 ]; then
                    echo "  WOULD create $HOME/.tmux/plugins"
                else
                    mkdir -p "$HOME/.tmux/plugins"
                fi

                echo "  - Cloning TPM..."
                run_cmd git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"

                echo "  - Installing plugins..."
                if [ "$DRY_RUN" -eq 1 ]; then
                    echo "  WOULD run: $HOME/.tmux/plugins/tpm/bin/install_plugins"
                else
                    "$HOME/.tmux/plugins/tpm/bin/install_plugins"
                fi

                if [ "$DRY_RUN" -eq 1 ]; then
                    echo "  WOULD create $HOME/.tmux_tpm_setup_complete"
                else
                    touch "$HOME/.tmux_tpm_setup_complete"
                    echo "  ✓ Complete reset finished"
                fi

                if [ -f "$HOME/.config/tmux/tmux.conf" ]; then
                    echo "  - Reloading configuration..."
                    if [ "$DRY_RUN" -eq 1 ]; then
                        echo "  WOULD run: tmux source-file $HOME/.config/tmux/tmux.conf"
                    else
                        tmux source-file "$HOME/.config/tmux/tmux.conf" 2>/dev/null && echo "  ✓ Configuration reloaded" || echo "  ! Start a new tmux session to apply changes"
                    fi
                fi
            else
                echo "  Cancelled."
            fi
            ;;

        4)
            echo ""
            echo "Exiting troubleshooting menu."
            break
            ;;

        *)
            echo ""
            echo "Invalid option. Please select 1-4."
            ;;
        esac
    done
fi

echo ""
