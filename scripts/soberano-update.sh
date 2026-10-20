#!/usr/bin/env bash
# ==============================================================================
# Soberano Dotfiles - Auto-Updater & Git Sync Engine
# Synchronizes local dotfiles with remote master repository
# Can be run manually or triggered via systemd user timer
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Check if running in terminal
IS_TTY=false
if [ -t 1 ]; then
    IS_TTY=true
fi

notify() {
    local title="$1"
    local msg="$2"
    local urgency="${3:-normal}"
    if command -v notify-send >/dev/null 2>&1; then
        notify-send -u "$urgency" -a "Soberano Dotfiles" "$title" "$msg" 2>/dev/null || true
    fi
    if [ "$IS_TTY" = true ]; then
        printf ":: [%s] %s\n" "$title" "$msg"
    fi
}

# 1. Verify Internet Connectivity
if ! curl -s --head --request GET https://github.com --max-time 5 >/dev/null 2>&1; then
    if [ "$IS_TTY" = true ]; then
        echo ":: Sem conexão com a internet ou GitHub inacessível. Pulando sincronização."
    fi
    exit 0
fi

# 2. Check Git Repository
if [ ! -d "$DOTFILES_DIR/.git" ]; then
    if [ "$IS_TTY" = true ]; then
        echo ":: Diretório $DOTFILES_DIR não é um repositório git."
    fi
    exit 1
fi

cd "$DOTFILES_DIR"

# 3. Fetch Remote Changes
git fetch origin main --quiet 2>/dev/null || git fetch origin master --quiet 2>/dev/null || exit 0

BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")
LOCAL=$(git rev-parse HEAD 2>/dev/null)
REMOTE=$(git rev-parse "origin/$BRANCH" 2>/dev/null || true)

if [ -z "$REMOTE" ]; then
    exit 0
fi

if [ "$LOCAL" = "$REMOTE" ]; then
    if [ "$IS_TTY" = true ]; then
        echo "✓ Seus dotfiles já estão na versão mais recente ($LOCAL)."
    fi
    exit 0
fi

# 4. Pull Updates
notify "Atualização Detectada" "Baixando novas configurações do Soberano Dotfiles..." "normal"

# Stash local uncommitted changes to avoid conflict
HAS_CHANGES=false
if ! git diff-index --quiet HEAD -- 2>/dev/null; then
    HAS_CHANGES=true
    git stash --quiet 2>/dev/null || true
fi

# Fast-forward pull
if git pull --ff-only origin "$BRANCH" --quiet 2>/dev/null; then
    # Re-apply stash if any
    if [ "$HAS_CHANGES" = true ]; then
        git stash pop --quiet 2>/dev/null || true
    fi

    # Fix permissions
    chmod +x "$DOTFILES_DIR"/scripts/*.sh "$DOTFILES_DIR"/scripts/*.py 2>/dev/null || true

    # Reload Hyprland if active
    if command -v hyprctl >/dev/null 2>&1 && [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
        hyprctl reload >/dev/null 2>&1 || true
    fi

    # Reload user systemd daemons
    if command -v systemctl >/dev/null 2>&1; then
        systemctl --user daemon-reload 2>/dev/null || true
    fi

    NEW_REV=$(git rev-parse --short HEAD 2>/dev/null || echo "revisão recente")
    notify "Soberano Dotfiles Atualizado" "Seu desktop foi sincronizado com sucesso para ($NEW_REV)!" "normal"
else
    # Pull failed (non-fast-forward)
    if [ "$HAS_CHANGES" = true ]; then
        git stash pop --quiet 2>/dev/null || true
    fi
    notify "Falha na Sincronização" "Houve conflito local de versões. Verifique git status em $DOTFILES_DIR." "critical"
fi
