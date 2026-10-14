#!/usr/bin/env bash
# ==============================================================================
# HyprAnimationsSelector - Interactive Animation Profiles for Hyprland
# Port of JaKooLit Animations system.
# Bound to: Super + Alt + A
# ==============================================================================
set -euo pipefail

DOTFILES="${HOME}/dotfiles"
ANIMS_DIR="${DOTFILES}/config/hypr/animations"
TARGET_LUA="${DOTFILES}/config/hypr/config/animations.lua"
STATE_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/active_animation.txt"

if [ ! -d "$ANIMS_DIR" ]; then
    echo "Erro: Diretório de animações não encontrado em $ANIMS_DIR" >&2
    exit 1
fi

current_anim=$(cat "$STATE_FILE" 2>/dev/null || echo "2. Smooth-Fluid")

declare -A anim_map
options=()

for p in "$ANIMS_DIR"/*.lua; do
    fname=$(basename "$p" .lua)
    clean_name="$fname"
    if [[ "$clean_name" =~ ^[0-9]+\.\  ]]; then
        clean_name="${clean_name:3}"
    fi
    anim_map["$clean_name"]="$fname"

    if [ "$fname" = "$current_anim" ] || [ "$clean_name" = "$current_anim" ]; then
        options+=("👉 $clean_name (Ativo)")
    else
        options+=("   $clean_name")
    fi
done

# Launch Noctalia dmenu
chosen=$(printf '%s\n' "${options[@]}" | noctalia dmenu -p "󰑮 Escolher Perfil de Animações (Super+Alt+A)" || true)

# Exit if cancelled
if [ -z "$chosen" ]; then
    exit 0
fi

# Clean selection name
clean_name=$(echo "$chosen" | sed 's/^[[:space:]]*//; s/^👉[[:space:]]*//; s/[[:space:]]*(Ativo)//')
selected_file="${anim_map[$clean_name]:-}"

if [ -z "$selected_file" ] || [ ! -f "$ANIMS_DIR/${selected_file}.lua" ]; then
    echo "Perfil não encontrado: $chosen" >&2
    exit 1
fi

# Apply profile to animations.lua
cp -f "$ANIMS_DIR/${selected_file}.lua" "$TARGET_LUA"

# Save state
mkdir -p "$(dirname "$STATE_FILE")"
echo "$selected_file" > "$STATE_FILE"

# Reload Hyprland live animations
if command -v hyprctl >/dev/null 2>&1; then
    hyprctl reload >/dev/null 2>&1 || true
fi

# Show OSD notification
if command -v noctalia >/dev/null 2>&1; then
    noctalia msg notification-show "Animações do Hyprland" "Perfil: ${clean_name}" >/dev/null 2>&1 || true
fi

echo "Perfil de animações ${clean_name} aplicado com sucesso."
