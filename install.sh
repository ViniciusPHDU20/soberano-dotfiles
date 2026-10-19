#!/usr/bin/env bash
# ==============================================================================
# Soberano Dotfiles Installer (CachyOS / Arch Linux)
# Stack: Hyprland (Native Lua) + Wayle (Rust/GTK4) + Matugen (MD3) + Fuzzel + awww
# ==============================================================================
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"

echo ":: [Soberano] Instalando dependências base..."
sudo pacman -S --needed --noconfirm \
    awww fuzzel cliphist wl-clipboard grim slurp hyprpicker \
    kitty btop fastfetch fish playerctl brightnessctl

if ! command -v matugen >/dev/null 2>&1 || ! command -v wayle >/dev/null 2>&1; then
    if command -v yay >/dev/null 2>&1; then
        yay -S --needed --noconfirm wayle-bin matugen-bin
    elif command -v paru >/dev/null 2>&1; then
        paru -S --needed --noconfirm wayle-bin matugen-bin
    fi
fi

mkdir -p "$CONFIG_DIR" "$CONFIG_DIR/gtk-3.0" "$CONFIG_DIR/gtk-4.0"
chmod +x "$DOTFILES_DIR"/scripts/*.sh "$DOTFILES_DIR"/scripts/*.py 2>/dev/null || true

CONFIGS=(
    hypr
    wayle
    matugen
    fuzzel
    kitty
    btop
    fastfetch
    fish
    quickshell
)

echo ":: [Soberano] Vinculando diretórios em ${CONFIG_DIR}..."
for dir in "${CONFIGS[@]}"; do
    target="${CONFIG_DIR}/${dir}"
    if [ -e "$target" ] && [ ! -L "$target" ]; then
        mv "$target" "${target}.bak.$(date +%s)"
    fi
    rm -f "$target"
    ln -sfnT "${DOTFILES_DIR}/config/${dir}" "$target"
    echo "   -> ${target} -> ${DOTFILES_DIR}/config/${dir}"
done

echo ":: [Soberano] Inicializando awww-daemon, Wayle e Matugen..."
pgrep -x awww-daemon >/dev/null 2>&1 || (awww-daemon >/dev/null 2>&1 & sleep 0.4)
systemctl --user enable --now wayle.service >/dev/null 2>&1 || true
"${DOTFILES_DIR}/scripts/WallpaperSelect.sh" --restore || true
hyprctl reload >/dev/null 2>&1 || true

echo ":: [Soberano] Instalação concluída com sucesso!"
