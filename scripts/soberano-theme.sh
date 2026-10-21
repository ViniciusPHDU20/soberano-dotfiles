#!/usr/bin/env bash
# ==============================================================================
# Soberano Theme & Master Aesthetic Preset Switcher
# Applies the full aesthetic suite: Wallpaper + Wayle Bar Layout + Matugen Scheme + Shaders
# Bound to: Super + Shift + T | Terminal command: soberano-theme
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

THEME_STATE="${XDG_CACHE_HOME:-$HOME/.cache}/soberano_active_theme.txt"
current_theme=$(cat "$THEME_STATE" 2>/dev/null || echo "1")

declare -a themes=(
    "1 — Nordic Slate (Foco & Código • Azul Ardósia • Preset 2 Chips • Neutro)"
    "2 — Cyberpunk Glow (Shaders GLSL • Neon Magenta/Ciano • Preset 3 Blade • Vibrante)"
    "3 — Catppuccin Velvet (Tons Pastel Mocha • Preset 1 Pílula Flutuante • Tonal-Spot)"
    "4 — Japanese Minimalist (Estética Zen Clean • Preset 10 Minimalista • Fidelidade)"
)

options=()
for entry in "${themes[@]}"; do
    key="${entry%% *}"
    if [[ "$key" == "$current_theme" ]]; then
        options+=("👉 $entry")
    else
        options+=("   $entry")
    fi
done

if [[ $# -ge 1 && -n "$1" ]]; then
    chosen="$1"
else
    if command -v fuzzel >/dev/null 2>&1 && [ -n "${WAYLAND_DISPLAY:-}" ]; then
        chosen=$(printf '%s\n' "${options[@]}" | fuzzel --dmenu -p "󰏘 Tema Soberano ❯ " -w 76 -l 4 || true)
    else
        printf "Selecione o Tema Soberano:\n"
        for entry in "${themes[@]}"; do
            printf " [%s] %s\n" "${entry%% *}" "${entry#*— }"
        done
        read -rp "Opção [1-4]: " chosen
    fi
fi
[ -z "$chosen" ] && exit 0

clean=$(echo "$chosen" | sed 's/^👉 //; s/^   //')
id="${clean%% *}"

# Match text names as fallback (ex: soberano-theme nordic)
case "$(echo "$chosen" | tr '[:upper:]' '[:lower:]')" in
    *nordic*)     id="1" ;;
    *cyberpunk*)  id="2" ;;
    *catppuccin*) id="3" ;;
    *japan*)      id="4" ;;
esac

mkdir -p "$(dirname "$THEME_STATE")"
echo "$id" > "$THEME_STATE"

SHADER_SCRIPT="$DOTFILES_DIR/config/hypr/scripts/shader-manager.sh"

case "$id" in
    1)
        # Nordic Slate
        THEME_NAME="Nordic Slate"
        WALLPAPER="$DOTFILES_DIR/wallpapers/Mountain_dark.dynamic.png"
        WAYLE_PRESET="2"
        MATUGEN_SCHEME="neutral"
        SHADER="off"
        ;;
    2)
        # Cyberpunk Glow
        THEME_NAME="Cyberpunk Glow"
        WALLPAPER="$DOTFILES_DIR/wallpapers/Anime-City-Night.png"
        WAYLE_PRESET="3"
        MATUGEN_SCHEME="vibrant"
        SHADER="cyberpunk"
        ;;
    3)
        # Catppuccin Velvet
        THEME_NAME="Catppuccin Velvet"
        WALLPAPER="$DOTFILES_DIR/wallpapers/Lofi - Chill Room.png"
        WAYLE_PRESET="1"
        MATUGEN_SCHEME="tonal-spot"
        SHADER="soft-bloom"
        ;;
    4)
        # Japanese Minimalist
        THEME_NAME="Japanese Minimalist"
        WALLPAPER="$DOTFILES_DIR/wallpapers/Concept-Japanese house.png"
        WAYLE_PRESET="10"
        MATUGEN_SCHEME="fidelity"
        SHADER="off"
        ;;
    *)
        echo "Opção inválida: $id"
        exit 1
        ;;
esac

echo ":: Aplicando Tema Soberano: $THEME_NAME"

# 1. Update Matugen Scheme configuration
SCHEME_STATE="${XDG_CACHE_HOME:-$HOME/.cache}/soberano_matugen_scheme.txt"
echo "$MATUGEN_SCHEME" > "$SCHEME_STATE" 2>/dev/null || true
sed -i "s/^matugen-scheme = .*/matugen-scheme = \"${MATUGEN_SCHEME}\"/" "$DOTFILES_DIR/config/wayle/config.toml" 2>/dev/null || true

# 2. Apply Wayle Bar Layout Geometry & Restart Bar
"$DOTFILES_DIR/scripts/WayleBarPresetSelect.sh" "$WAYLE_PRESET" >/dev/null 2>&1 || true

# 3. Apply Wallpaper, awww 144Hz Transition & Synchronous Matugen Extraction
if [ -f "$WALLPAPER" ]; then
    "$DOTFILES_DIR/scripts/WallpaperSelect.sh" --apply "$WALLPAPER" >/dev/null 2>&1 || true
fi

# 4. Apply GLSL Screen Shaders if Hyprland is active
if [ -f "$SHADER_SCRIPT" ] && command -v hyprctl >/dev/null 2>&1; then
    bash "$SHADER_SCRIPT" "$SHADER" >/dev/null 2>&1 || true
fi

if command -v notify-send >/dev/null 2>&1; then
    notify-send -u normal -a "Soberano Dotfiles" "󰏘 Tema Ativado" "Estilo: $THEME_NAME\nPreset Wayle: $WAYLE_PRESET | Matugen: $MATUGEN_SCHEME" 2>/dev/null || true
fi

echo "✓ Tema $THEME_NAME aplicado com sucesso!"
