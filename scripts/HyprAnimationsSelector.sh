#!/usr/bin/env bash
# ==============================================================================
# Soberano Hyprland Animations Selector (Fuzzel)
# Bound to: Super + Alt + A
# ==============================================================================
set -euo pipefail

DOTFILES="${HOME}/dotfiles"
ANIMS_DIR="${DOTFILES}/config/hypr/animations"
TARGET_LUA="${DOTFILES}/config/hypr/config/animations.lua"
STATE_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/soberano_animation.txt"

current_anim=$(cat "$STATE_FILE" 2>/dev/null || echo "2. Smooth-Fluid")

declare -A anim_map
options=()

for p in "$ANIMS_DIR"/*.lua; do
    fname=$(basename "$p" .lua)
    clean_name="${fname#*. }"
    anim_map["$clean_name"]="$fname"

    if [[ "$fname" == "$current_anim" ]] || [[ "$clean_name" == "$current_anim" ]]; then
        options+=("👉 $clean_name")
    else
        options+=("   $clean_name")
    fi
done

chosen=$(printf '%s\n' "${options[@]}" | fuzzel --dmenu -p "󰑮 Animações ❯ " -w 42 -l 5 || true)
[ -z "$chosen" ] && exit 0

clean_name=$(echo "$chosen" | sed 's/^👉 //; s/^   //')
selected_file="${anim_map[$clean_name]:-}"

if [ -n "$selected_file" ] && [ -f "$ANIMS_DIR/${selected_file}.lua" ]; then
    cp -f "$ANIMS_DIR/${selected_file}.lua" "$TARGET_LUA"
    mkdir -p "$(dirname "$STATE_FILE")"
    echo "$selected_file" > "$STATE_FILE"
    hyprctl reload >/dev/null 2>&1 || true
    notify-send -u low -a "Soberano" "󰑮 Animações Hyprland" "Perfil: ${clean_name}" 2>/dev/null || true
fi
