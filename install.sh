#!/usr/bin/env bash
set -eu

DOTFILES_REPO="https://github.com/trancefixer/dotfiles.git"

echo "==> Bootstrapping dotfiles..."

# 1. Install mise if missing
if ! command -v mise >/dev/null 2>&1; then
  echo "==> Installing mise..."
  curl https://mise.run | sh
  export PATH="$HOME/.local/share/mise/bin:$PATH"
fi

# 2. Run chezmoi or stow via mise
if command -v chezmoi >/dev/null 2>&1; then
  chezmoi init --apply trancefixer
else
  # Fallback to cloning directly if using custom install script
  mise trust
  mise install
  mise run setup
fi

echo "==> Setup complete!"
