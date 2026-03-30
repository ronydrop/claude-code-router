#!/usr/bin/env bash
set -e

INSTALL_DIR="$HOME/.config/claude-code-router"
BASHRC="$HOME/.bashrc"

echo "Uninstalling claude-code-router..."

rm -rf "$INSTALL_DIR"
echo "✓ Removed $INSTALL_DIR"

if grep -qF 'claude-code-router' "$BASHRC" 2>/dev/null; then
    sed -i '/# claude-code-router/d;/claude-code-router/d' "$BASHRC"
    echo "✓ Removed from $BASHRC"
fi

echo ""
echo "Done. Restart your terminal."
