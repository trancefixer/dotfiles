#!/usr/bin/env sh
set -eu

DOTFILES_REPO="https://github.com/trancefixer/dotfiles.git"
BRANCH="${1:-main}"

echo "==> Bootstrapping dotfiles (branch: $BRANCH)..."

# 2. Install chezmoi via mise and apply dotfiles
if command -v chezmoi >/dev/null 2>&1; then
    chezmoi init --apply --branch "$BRANCH" "$DOTFILES_REPO"
else
    # 1. Install mise if missing (mise.run installs to ~/.local/bin/mise)
    export PATH="$HOME/.local/bin:$PATH"
    if ! command -v mise >/dev/null 2>&1; then
        echo "==> Installing mise..."
        if command -v curl >/dev/null 2>&1; then
           curl -fsSL https://mise.run | sh
        elif command -v wget >/dev/null 2>&1; then
           wget -qO- https://mise.run | sh
        else
           echo "Error: neither curl nor wget is installed." >&2
           exit 1
        fi
    fi

    mise use --global chezmoi@latest
    mise exec chezmoi@latest -- chezmoi init --apply --branch "$BRANCH" "$DOTFILES_REPO"
fi

echo "==> Setup complete!"
