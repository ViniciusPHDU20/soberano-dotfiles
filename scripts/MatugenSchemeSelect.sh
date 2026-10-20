#!/usr/bin/env bash
# ==============================================================================
# Soberano Matugen Scheme Selector (Material Design 3)
# Bound to: Super + Alt + B
# ==============================================================================
set -euo pipefail

WAYLE_CFG="${HOME}/dotfiles/config/wayle/config.toml"
WALL_STATE="${XDG_CACHE_HOME:-$HOME/.cache}/soberano_wallpaper.txt"
SCHEME_STATE="${XDG_CACHE_HOME:-$HOME/.cache}/soberano_matugen_scheme.txt"

current_scheme=$(cat "$SCHEME_STATE" 2>/dev/null || echo "vibrant")

declare -a schemes=(
    "tonal-spot   — Equilibrado (Material You Default)"
    "vibrant      — Alta saturação e destaque"
    "expressive   — Contraste ousado e dramático"
    "fidelity     — Fiel às cores exatas do wallpaper"
    "content      — Adaptativo à cor dominante"
    "fruit-salad  — Multi-colorido dinâmico"
    "rainbow      — Espectro cromático amplo"
    "neutral      — Sóbrio e minimalista"
    "monochrome   — Monocromático puro"
)

options=()
for entry in "${schemes[@]}"; do
    key="${entry%% *}"
    if [[ "$key" == "$current_scheme" ]]; then
        options+=("👉 $entry")
    else
        options+=("   $entry")
    fi
done

chosen=$(printf '%s\n' "${options[@]}" | fuzzel --dmenu -p "󰏘 Matugen Scheme ❯ " -w 54 -l 9 || true)
[ -z "$chosen" ] && exit 0

clean=$(echo "$chosen" | sed 's/^👉 //; s/^   //')
scheme="${clean%% *}"

mkdir -p "$(dirname "$SCHEME_STATE")"
echo "$scheme" > "$SCHEME_STATE"

# Update Wayle config.toml live (Wayle watches config.toml and recompiles SCSS automatically)
sed -i "s/^matugen-scheme = .*/matugen-scheme = \"${scheme}\"/" "$WAYLE_CFG"

# Re-extract Matugen colors for both Wayle and system apps
img=$(cat "$WALL_STATE" 2>/dev/null || echo "${HOME}/dotfiles/wallpapers/Anime-City-Night.png")
if [ -f "$img" ]; then
    wayle wallpaper set "$img" --monitor DP-1 >/dev/null 2>&1 || true
    matugen image "$img" -t "scheme-${scheme}" -m dark --prefer saturation --contrast -0.45 >/dev/null 2>&1 || true
fi

notify-send -u low -a "Soberano" "󰏘 Esquema Matugen" "Ativado: ${scheme}" 2>/dev/null || true
