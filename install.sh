#!/usr/bin/env bash

set -e

DOTFILES_DIR="$HOME/.dotfiles"
BACKUP_SUFFIX=".bak"

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

cd "$DOTFILES_DIR" || exit 1

echo "Step 1: Analyzing .dotfiles structure..."
base_dirs=()

for package in */; do
    package_name="${package%/}"
    
    if [ "$package_name" = ".git" ] || [ ! -d "$package" ]; then
        continue
    fi
    
    while IFS= read -r -d '' subdir; do
        dirname=$(basename "$subdir")
        
        if [[ "$dirname" =~ ^\. ]] || [ "$dirname" = "Library" ]; then
            if [[ ! " ${base_dirs[@]} " =~ " ${dirname} " ]]; then
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
        mkdir -p "$target"
        echo "  ✓ Created $target"
    else
        echo "  - Skipping $target (already exists)"
    fi
done
echo ""

echo "Step 3: Checking for conflicts..."
conflicts=()

stow_output=$(stow --simulate --restow */ 2>&1 || true)

if echo "$stow_output" | grep -q "existing target is"; then
    while IFS= read -r line; do
        if [[ "$line" =~ "existing target is" ]]; then
            conflict_file=$(echo "$line" | sed -E 's/.*existing target is (neither a link nor a directory|not owned by stow): (.*)/\2/')
            if [ -n "$conflict_file" ]; then
                conflicts+=("$conflict_file")
            fi
        fi
    done <<< "$stow_output"
fi

if [ ${#conflicts[@]} -eq 0 ]; then
    echo "  No conflicts detected"
else
    echo "  Found ${#conflicts[@]} conflict(s)"
fi
echo ""

if [ ${#conflicts[@]} -gt 0 ]; then
    echo "Step 4: Backing up conflicting files..."
    for conflict in "${conflicts[@]}"; do
        if [ -e "$HOME/$conflict" ] && [ ! -L "$HOME/$conflict" ]; then
            backup="$HOME/${conflict}${BACKUP_SUFFIX}"
            mv "$HOME/$conflict" "$backup"
            echo "  ✓ Moved $conflict → ${conflict}${BACKUP_SUFFIX}"
        fi
    done
    echo ""
fi

echo "Step 5: Running stow..."
if stow --restow */ 2>&1; then
    echo "  ✓ Stow completed successfully"
else
    echo "  ✗ Stow encountered errors" >&2
    exit 1
fi
echo ""

echo "================================================"
echo "  Installation Complete!"
echo "================================================"
echo ""
echo "Summary:"
echo "  - Base directories created: ${#base_dirs[@]}"
echo "  - Files backed up: ${#conflicts[@]}"
echo "  - Symlinks created: $(find "$DOTFILES_DIR" -mindepth 1 -maxdepth 1 -type d ! -name '.git' | wc -l | tr -d ' ') packages"
echo ""
echo "Backup files (if any) are saved with '$BACKUP_SUFFIX' extension"
echo "You can now start a new shell or run: exec zsh"
echo ""
