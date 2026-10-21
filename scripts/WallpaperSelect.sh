#!/usr/bin/env bash
# ==============================================================================
# Soberano Wallpaper & Matugen Engine (Wayle + awww + Matugen v4)
# Bound to: Super + W (interactive) | Super + Alt + W (--random)
# ==============================================================================
set -euo pipefail

WALL_DIR="${HOME}/dotfiles/wallpapers"
STATE_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/soberano_wallpaper.txt"
SCHEME_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/soberano_matugen_scheme.txt"
PICKER_BIN="${HOME}/dotfiles/scripts/wallpaper-picker-rs"

get_monitor() {
    local mon
    mon=$(hyprctl monitors -j 2>/dev/null | jq -r '.[] | select(.focused == true) | .name' 2>/dev/null || true)
    if [ -z "$mon" ] || [ "$mon" = "null" ]; then
        mon=$(hyprctl monitors -j 2>/dev/null | jq -r '.[0].name' 2>/dev/null || echo "DP-1")
    fi
    echo "$mon"
}

# If interactive launch without arguments, exec native Rust studio directly
if [ $# -eq 0 ]; then
    if [ -x "$PICKER_BIN" ]; then
        exec "$PICKER_BIN"
    fi
fi

mkdir -p "$(dirname "$STATE_FILE")"

apply_wallpaper() {
    local img="$1"
    if [ ! -f "$img" ]; then
        exit 1
    fi

    echo "$img" > "$STATE_FILE"

    # Terminate any previous live wallpaper engines and matugen
    systemctl --user stop soberano-livewallpaper 2>/dev/null || true
    systemctl --user reset-failed soberano-livewallpaper 2>/dev/null || true
    killall -9 linux-wallpaperengine 2>/dev/null || true
    rm -f "${XDG_CACHE_HOME:-$HOME/.cache}/soberano_livewallpaper.state"
    pkill -x matugen 2>/dev/null || true

    # Ensure awww-daemon service is active for static rendering
    systemctl --user start awww-daemon.service 2>/dev/null || true
    if ! pgrep -x awww-daemon >/dev/null 2>&1; then
        awww-daemon >/dev/null 2>&1 &
        sleep 0.2
    fi

    # Update persistent wallpaper path in Wayle config.toml
    sed -i "s|^wallpaper = .*|wallpaper = \"$img\"|" "${HOME}/dotfiles/config/wayle/config.toml" 2>/dev/null || true

    # Update Wayle shell state and apply smooth 144 FPS transition to awww
    wayle wallpaper set "$img" >/dev/null 2>&1 || true
    awww img "$img" --transition-type grow --transition-fps 144 >/dev/null 2>&1 || true

    # Synchronous Matugen color extraction
    local scheme
    scheme=$(cat "$SCHEME_FILE" 2>/dev/null || echo "vibrant")
    matugen image "$img" -t "scheme-${scheme}" -m dark --prefer saturation --contrast -0.45 >/dev/null 2>&1 || true

    notify-send -u low -a "Soberano" "󰸉 Wallpaper & Matugen" "$(basename "$img") (${scheme})" 2>/dev/null || true
}

if [[ "${1:-}" == "--apply" ]] && [ -n "${2:-}" ]; then
    apply_wallpaper "$2"
    exit 0
fi

if [[ "${1:-}" == "--random" ]]; then
    random_img=$(find "$WALL_DIR" -maxdepth 2 -type f \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.webp" \) | shuf -n 1)
    [ -n "$random_img" ] && apply_wallpaper "$random_img"
    exit 0
fi

if [[ "${1:-}" == "--restore" ]]; then
    saved_img=$(cat "$STATE_FILE" 2>/dev/null || echo "${WALL_DIR}/Anime-City-Night.png")
    [ -f "$saved_img" ] || saved_img="${WALL_DIR}/Anime-City-Night.png"
    apply_wallpaper "$saved_img"
    exit 0
fi

if [[ "${1:-}" == "--fuzzel" ]]; then
    current_img=$(cat "$STATE_FILE" 2>/dev/null || echo "")
    current_base=$(basename "$current_img" 2>/dev/null || echo "")

    mapfile -t files < <(find "$WALL_DIR" -maxdepth 2 -type f \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.webp" \) | sort)

    options=("󰒝  [Aleatório / Random Wallpaper]")
    declare -A file_map

    for f in "${files[@]}"; do
        rel="${f#$WALL_DIR/}"
        file_map["$rel"]="$f"
        if [[ "$(basename "$f")" == "$current_base" ]]; then
            options+=("👉 $rel")
        else
            options+=("   $rel")
        fi
    done

    chosen=$(printf '%s\n' "${options[@]}" | fuzzel --dmenu -p "󰸉 Wallpaper ❯ " -w 52 -l 14 || true)
    [ -z "$chosen" ] && exit 0

    if [[ "$chosen" == *"Aleatório"* ]]; then
        exec "$0" --random
    fi

    clean_rel=$(echo "$chosen" | sed 's/^👉 //; s/^   //')
    target="${file_map[$clean_rel]:-}"

    if [ -n "$target" ] && [ -f "$target" ]; then
        apply_wallpaper "$target"
    fi
    exit 0
fi

if [ -x "$PICKER_BIN" ]; then
    exec "$PICKER_BIN"
fi
