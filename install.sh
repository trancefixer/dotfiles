#!/usr/bin/env sh
set -eu

DOTFILES_REPO="https://github.com/trancefixer/dotfiles.git"
BRANCH="${1:-main}"

echo "==> Bootstrapping dotfiles (branch: $BRANCH)..."

# 1. Install mise if missing (mise.run installs to ~/.local/bin/mise)
export PATH="$HOME/.local/bin:$PATH"
if ! command -v mise >/dev/null 2>&1; then
  echo "==> Installing mise..."
  curl -fsSL https://mise.run | sh
fi

# 2. Install chezmoi via mise and apply dotfiles
if command -v chezmoi >/dev/null 2>&1; then
  chezmoi init --apply --branch "$BRANCH" "$DOTFILES_REPO"
else
  mise use --global chezmoi@latest
  mise exec chezmoi@latest -- chezmoi init --apply --branch "$BRANCH" "$DOTFILES_REPO"
fi

echo "==> Setup complete!"