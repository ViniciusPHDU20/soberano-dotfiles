#!/usr/bin/env bash
# ==============================================================================
# Soberano Dotfiles - Update Check Daemon
# Lightweight script executed by Wayle's custom module to check for git updates
# ==============================================================================
set -euo pipefail

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

if [ ! -d "$DOTFILES_DIR/.git" ]; then
    exit 0
fi

# Skip network check while an update is actively running
LOCK_FILE="${XDG_RUNTIME_DIR:-/tmp}/soberano-update.lock"
if [ -f "$DOTFILES_DIR/.git/index.lock" ] || ! flock -n 9 9>>"$LOCK_FILE" 2>/dev/null; then
    SHORT=$(git -C "$DOTFILES_DIR" rev-parse --short HEAD 2>/dev/null || echo "main")
    printf '{"text": "", "tooltip": "󰚰 Soberano Dotfiles (%s)\\n• Sincronização em andamento"}\n' "$SHORT"
    exit 0
fi
exec 9>&-

# Quick connectivity test (timeout 1s)
if ! curl -fsS --head --request GET https://github.com --max-time 1 >/dev/null 2>&1; then
    exit 0
fi

cd "$DOTFILES_DIR"
BRANCH=$(git symbolic-ref --short HEAD 2>/dev/null || echo "main")
GIT_TERMINAL_PROMPT=0 git -c gc.auto=0 fetch origin "$BRANCH" --quiet 2>/dev/null || exit 0

BEHIND=$(git rev-list --count "HEAD..origin/$BRANCH" 2>/dev/null || echo "0")

if [ "$BEHIND" -gt 0 ]; then
    printf '{"text": "%s", "tooltip": "󰚰 Atualização Disponível\\n• %s alteração(ões) no GitHub\\n• Clique para aplicar agora"}\n' "$BEHIND" "$BEHIND"
else
    SHORT=$(git rev-parse --short HEAD 2>/dev/null || echo "main")
    printf '{"text": "", "tooltip": "󰚰 Soberano Dotfiles (%s)\\n• Sistema sincronizado\\n• Clique para verificar o GitHub"}\n' "$SHORT"
fi
