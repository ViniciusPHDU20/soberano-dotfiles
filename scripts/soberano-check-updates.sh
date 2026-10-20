#!/usr/bin/env bash
# ==============================================================================
# Soberano Dotfiles - Update Check Daemon
# Lightweight script executed by Wayle's custom module to check for git updates
# ==============================================================================
set -euo pipefail

DOTFILES_DIR="${HOME}/dotfiles"

if [ ! -d "$DOTFILES_DIR/.git" ]; then
    exit 0
fi

# Quick connectivity test (timeout 1s)
if ! curl -s --head --request GET https://github.com --max-time 1 >/dev/null 2>&1; then
    exit 0
fi

cd "$DOTFILES_DIR"
git fetch origin main --quiet 2>/dev/null || exit 0

LOCAL=$(git rev-parse HEAD 2>/dev/null)
REMOTE=$(git rev-parse origin/main 2>/dev/null || true)

if [ -n "$REMOTE" ] && [ "$LOCAL" != "$REMOTE" ]; then
    # New commit available
    BEHIND=$(git rev-list --count HEAD..origin/main 2>/dev/null || echo "1")
    printf '{"text": "%s", "tooltip": "󰚰 Atualização Disponível\\n• %s alteração(ões) no GitHub\\n• Clique para aplicar agora"}\n' "$BEHIND" "$BEHIND"
else
    # Up to date
    SHORT=$(git rev-parse --short HEAD 2>/dev/null || echo "main")
    printf '{"text": "", "tooltip": "󰚰 Soberano Dotfiles (%s)\\n• Sistema sincronizado\\n• Clique para verificar o GitHub"}\n' "$SHORT"
fi
