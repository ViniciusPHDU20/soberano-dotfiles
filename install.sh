#!/usr/bin/env bash
# ==============================================================================
# Soberano Dotfiles Installer (JaKooLit Hyprland-Dots v2.3.27.7 + Wayle Port)
# Environment: Arch / CachyOS (Zen 5 x86-64-v4) - Hyprland Lua & Wayle (Rust)
# ==============================================================================
set -e

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.config.bak-$(date +%Y%m%d_%H%M%S)"

echo "==> Iniciando sincronização do Soberano Dotfiles (Hyprland-Dots + Wayle)..."

mkdir -p "$BACKUP_DIR"

link_config() {
    local src="$1"
    local dest="$2"

    if [ -e "$dest" ] && [ ! -L "$dest" ]; then
        echo "  [Backup] Movendo $dest existente para $BACKUP_DIR/"
        mv "$dest" "$BACKUP_DIR/"
    fi

    echo "  [Symlink] $src -> $dest"
    ln -sfn "$src" "$dest"
}

mkdir -p "$HOME/.config" "$HOME/.local/bin" "$HOME/.local/share/wallpapers" "$HOME/Pictures"

# Linkar todo o ecossistema Hyprland-Dots + Wayle
for dir in hypr wayle kitty fish fastfetch quickshell btop cava ghostty Kvantum nwg-dock-hyprland qt5ct qt6ct swappy waybar-weather wezterm wlogout yazi; do
    if [ -d "$DOTFILES_DIR/config/$dir" ]; then
        link_config "$DOTFILES_DIR/config/$dir" "$HOME/.config/$dir"
    fi
done

# Linkar Rofi e Wallust apontando para a estrutura interna do Hyprland-Dots
link_config "$DOTFILES_DIR/config/hypr/rofi" "$HOME/.config/rofi"
link_config "$DOTFILES_DIR/config/hypr/wallust" "$HOME/.config/wallust"

# Linkar starship.toml se existir
if [ -f "$DOTFILES_DIR/config/starship/starship.toml" ]; then
    link_config "$DOTFILES_DIR/config/starship/starship.toml" "$HOME/.config/starship.toml"
fi

# Linkar wallpapers
ln -sfn "$DOTFILES_DIR/wallpapers" "$HOME/Pictures/wallpapers" 2>/dev/null || true

# Remover backup vazio caso nada tenha precisado de backup
rmdir "$BACKUP_DIR" 2>/dev/null || true

echo "==> Concluído com sucesso! Ecossistema Hyprland-Dots + Wayle 100% sincronizado."
