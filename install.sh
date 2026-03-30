#!/usr/bin/env bash
set -e

INSTALL_DIR="$HOME/.config/claude-code-router"
BASHRC="$HOME/.bashrc"
SOURCE_LINE='for _f in ~/.config/claude-code-router/*.sh; do [ -f "$_f" ] && source "$_f"; done; unset _f'

echo "Installing claude-code-router..."

mkdir -p "$INSTALL_DIR"
cp cc.sh ai.sh "$INSTALL_DIR/"
chmod 644 "$INSTALL_DIR/"*.sh

[ -f "$INSTALL_DIR/run-aliases" ] || touch "$INSTALL_DIR/run-aliases"

if grep -qF 'claude-code-router' "$BASHRC" 2>/dev/null; then
    echo "✓ Already in $BASHRC — skipping"
else
    printf '\n# claude-code-router\n%s\n' "$SOURCE_LINE" >> "$BASHRC"
    echo "✓ Added to $BASHRC"
fi

echo ""
echo "Done. Run: source ~/.bashrc"
echo "Then: cc help  |  ai help"
