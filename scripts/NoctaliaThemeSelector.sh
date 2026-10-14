#!/usr/bin/env bash
# ==============================================================================
# NoctaliaThemeSelector - Interactive Bar Styles & Themes for Noctalia Shell
# Port of JaKooLit WaybarStyles system to native Noctalia Wayland architecture.
# Bound to: Super + Alt + B
# ==============================================================================
set -euo pipefail

STYLES_DIR="${HOME}/dotfiles/config/noctalia/styles"
TARGET_CONFIG="${HOME}/dotfiles/config/noctalia/config.toml"
USER_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/noctalia/config.toml"
WALLPAPERS_DIR="${HOME}/dotfiles/wallpapers"
SYNC_SCRIPT="${HOME}/dotfiles/scripts/DynamicThemeSync.sh"

if [ ! -d "$STYLES_DIR" ]; then
    echo "Erro: Diretório de estilos não encontrado em $STYLES_DIR" >&2
    exit 1
fi

# Detect current style by md5 / content comparison
current_style=""
if [ -f "$TARGET_CONFIG" ]; then
    current_hash=$(md5sum "$TARGET_CONFIG" | awk '{print $1}')
    for p in "$STYLES_DIR"/*.toml; do
        if [ "$(md5sum "$p" | awk '{print $1}')" = "$current_hash" ]; then
            current_style=$(basename "$p" .toml)
            break
        fi
    done
fi

# Build menu list
options=()
for p in "$STYLES_DIR"/*.toml; do
    name=$(basename "$p" .toml)
    if [ "$name" = "$current_style" ]; then
        options+=("👉 $name (Ativo)")
    else
        options+=("   $name")
    fi
done

# Launch Noctalia dmenu
chosen=$(printf '%s\n' "${options[@]}" | noctalia dmenu -p "󰏘 Escolher Estilo de Barra (Super+Alt+B)" || true)

# Exit if cancelled
if [ -z "$chosen" ]; then
    exit 0
fi

# Clean selection name
clean_name=$(echo "$chosen" | sed 's/^[[:space:]]*//; s/^👉[[:space:]]*//; s/[[:space:]]*(Ativo)//')
selected_file="$STYLES_DIR/${clean_name}.toml"

if [ ! -f "$selected_file" ]; then
    echo "Estilo não encontrado: $selected_file" >&2
    exit 1
fi

# Apply style to both dotfiles and active user config
cp -f "$selected_file" "$TARGET_CONFIG"
cp -f "$selected_file" "$USER_CONFIG"

# Map signature wallpaper for each style
sig_wall=""
case "$clean_name" in
    "Colorful-Chroma-Spectrum")
        sig_wall="$WALLPAPERS_DIR/Under_Starlit_Sky.png"
        [ ! -f "$sig_wall" ] && sig_wall="$WALLPAPERS_DIR/Purple-sea-moon-stars.png"
        ;;
    "Catppuccin-Mocha")
        sig_wall="$WALLPAPERS_DIR/Pastel-Window.png"
        [ ! -f "$sig_wall" ] && sig_wall="$WALLPAPERS_DIR/Purple-sea-moon-stars.png"
        ;;
    "Neon-Circuit-Cyberpunk")
        sig_wall="$WALLPAPERS_DIR/Night_City.png"
        [ ! -f "$sig_wall" ] && sig_wall="$WALLPAPERS_DIR/Night-City.jpg"
        ;;
    "Everforest-Natural")
        sig_wall="$WALLPAPERS_DIR/Fog-Forest-Everforest.png"
        ;;
    "Nord-Frost")
        sig_wall="$WALLPAPERS_DIR/Northern Lights3.png"
        ;;
    "Tokyo-Night")
        sig_wall="$WALLPAPERS_DIR/Tokyo_Pink.png"
        ;;
    "Crystal-Clear-Glass")
        sig_wall="$WALLPAPERS_DIR/Space-Nebula.png"
        ;;
    "Dracula")
        sig_wall="$WALLPAPERS_DIR/Purple-Nightmare.jpg"
        ;;
    "Rose-Pine")
        sig_wall="$WALLPAPERS_DIR/Dreamy-Aesthetic-Home-Under-Moonlight.png"
        ;;
    "Kanagawa-Wave")
        sig_wall="$WALLPAPERS_DIR/Fantasy-Japanese-Street.png"
        ;;
    "Black-&-White-Monochrome")
        sig_wall="$WALLPAPERS_DIR/Night monochrome.jpg"
        ;;
    "Gruvbox-Retro")
        sig_wall="$WALLPAPERS_DIR/Retro - Programmer.jpeg"
        ;;
    "Nordic-Slate")
        sig_wall="$WALLPAPERS_DIR/Dark_Nature.png"
        ;;
esac

# Switch wallpaper if signature wallpaper exists
if [ -n "$sig_wall" ] && [ -f "$sig_wall" ] && command -v noctalia >/dev/null 2>&1; then
    noctalia msg wallpaper-set "$sig_wall" >/dev/null 2>&1 || true
fi

# Small delay to let wallpaper and config hot-reload settle
sleep 0.3

# Re-apply theme templates and Hyprland dynamic border sync
if command -v noctalia >/dev/null 2>&1; then
    noctalia msg templates-apply >/dev/null 2>&1 || true
    noctalia msg notification-show "Estilo de Barra Aplicado" "Estilo: ${clean_name}" >/dev/null 2>&1 || true
fi

if [ -f "$SYNC_SCRIPT" ]; then
    bash "$SYNC_SCRIPT" >/dev/null 2>&1 || true
fi

echo "Estilo ${clean_name} aplicado com sucesso."
