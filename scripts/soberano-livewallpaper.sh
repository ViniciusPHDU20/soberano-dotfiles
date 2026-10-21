#!/usr/bin/env bash
# ==============================================================================
# Soberano Live Wallpaper Engine (Almamu linux-wallpaperengine + Matugen MD3)
# Seamlessly integrates Steam Wallpaper Engine (431960) with Hyprland and Wayle
# ==============================================================================
set -euo pipefail

STATE_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/soberano_livewallpaper.state"
STATIC_RESTORE="${HOME}/dotfiles/scripts/WallpaperSelect.sh"
SCHEME_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/soberano_matugen_scheme.txt"

# Detect primary monitor via hyprctl
get_monitor() {
    local mon
    mon=$(hyprctl monitors -j 2>/dev/null | jq -r '.[] | select(.focused == true) | .name' 2>/dev/null || true)
    if [ -z "$mon" ] || [ "$mon" = "null" ]; then
        mon=$(hyprctl monitors -j 2>/dev/null | jq -r '.[0].name' 2>/dev/null || echo "DP-1")
    fi
    echo "$mon"
}

# Discover all Wallpaper Engine workshop directories
find_workshop_dirs() {
    local dirs=()

    # 1. Default Steam library
    local default_ws="$HOME/.local/share/Steam/steamapps/workshop/content/431960"
    [ -d "$default_ws" ] && dirs+=("$default_ws")

    # 2. Secondary Steam libraries from libraryfolders.vdf
    local vdf="$HOME/.local/share/Steam/steamapps/libraryfolders.vdf"
    if [ -f "$vdf" ]; then
        while IFS= read -r path; do
            local extra_ws="${path}/steamapps/workshop/content/431960"
            if [ -d "$extra_ws" ] && [[ ! " ${dirs[*]} " =~ " ${extra_ws} " ]]; then
                dirs+=("$extra_ws")
            fi
        done < <(grep -oP '"path"\s*"\K[^"]+' "$vdf" 2>/dev/null || true)
    fi

    # 3. User custom live wallpaper directory
    local user_live="$HOME/wallpapers/live"
    mkdir -p "$user_live"
    dirs+=("$user_live")

    printf "%s\n" "${dirs[@]}"
}

# Stop live wallpaper and restore static engine
stop_live() {
    pkill -x linux-wallpaperengine 2>/dev/null || true
    rm -f "$STATE_FILE"

    # Restore awww + last static wallpaper
    if [ -f "$STATIC_RESTORE" ]; then
        "$STATIC_RESTORE" --restore >/dev/null 2>&1 &
    fi

    notify-send -u low -a "Soberano Wallpapers" "󰸉 Wallpaper Estático Restaurado" "Engine animado encerrado • awww 144Hz ativo" 2>/dev/null || true
}

# Apply a specific live wallpaper
apply_live() {
    local target="$1"

    if [ ! -d "$target" ] && [ ! -f "$target" ]; then
        notify-send -u critical -a "Soberano Wallpapers" "Erro ao Carregar Wallpaper" "Caminho ou ID inválido: $target" 2>/dev/null || true
        exit 1
    fi

    local mon
    mon=$(get_monitor)

    # 1. Kill any running live wallpaper or awww-daemon to prevent duplicate rendering
    pkill -x linux-wallpaperengine 2>/dev/null || true
    pkill -x awww-daemon 2>/dev/null || true

    # 2. Extract Matugen color scheme from preview image if present
    local preview=""
    if [ -d "$target" ]; then
        for p in "$target/preview.jpg" "$target/preview.png" "$target/preview.gif" "$target/preview.webp"; do
            if [ -f "$p" ]; then
                preview="$p"
                break
            fi
        done
    fi

    local title
    title=$(basename "$target")
    if [ -d "$target" ] && [ -f "$target/project.json" ]; then
        local parsed_title
        parsed_title=$(jq -r '.title // empty' "$target/project.json" 2>/dev/null || true)
        [ -n "$parsed_title" ] && title="$parsed_title"
    fi

    if [ -n "$preview" ] && [ -f "$preview" ]; then
        local scheme
        scheme=$(cat "$SCHEME_FILE" 2>/dev/null || echo "vibrant")
        matugen image "$preview" -t "scheme-${scheme}" -m dark --prefer saturation --contrast -0.45 >/dev/null 2>&1 || true
    fi

    # 3. Launch linux-wallpaperengine
    linux-wallpaperengine \
        --screen-root "$mon" \
        --silent \
        --fps 144 \
        --scaling fill \
        --layer background \
        --fullscreen-pause-only-active \
        "$target" >/dev/null 2>&1 &

    echo "$target" > "$STATE_FILE"
    notify-send -u normal -a "Soberano Wallpapers" "󰸉 Live Wallpaper Ativo" "${title} (${mon} • 144 FPS)" 2>/dev/null || true
}

# Interactive Fuzzel selector
select_interactive() {
    local items=()
    local paths=()

    # First option: Stop / return to static
    items+=("⏹ [Parar Wallpaper Animado / Voltar ao Estático]")
    paths+=("__STOP__")

    while IFS= read -r ws_dir; do
        [ -d "$ws_dir" ] || continue
        for item in "$ws_dir"/*; do
            [ -d "$item" ] || continue

            local title
            title=$(basename "$item")
            local type="Unknown"

            if [ -f "$item/project.json" ]; then
                local p_title
                p_title=$(jq -r '.title // empty' "$item/project.json" 2>/dev/null || true)
                local p_type
                p_type=$(jq -r '.type // empty' "$item/project.json" 2>/dev/null || true)
                [ -n "$p_title" ] && title="$p_title"
                [ -n "$p_type" ] && type="$p_type"
            elif ls "$item"/*.mp4 >/dev/null 2>&1; then
                type="Video"
            fi

            items+=("󰑋 ${title} [${type} • $(basename "$item")]")
            paths+=("$item")
        done
    done < <(find_workshop_dirs)

    if [ ${#items[@]} -le 1 ]; then
        notify-send -u normal -a "Soberano Wallpapers" "Oficina Steam Vazia" "Nenhum wallpaper animado encontrado no Wallpaper Engine (AppID 431960).\nBaixe na Oficina da Steam ou coloque pastas em ~/wallpapers/live/" 2>/dev/null || true
        exit 0
    fi

    local selected_idx
    selected_idx=$(printf '%s\n' "${items[@]}" | fuzzel --dmenu --index --prompt "󰑋 Live Wallpaper Engine > " --width 50) || exit 0

    local chosen_path="${paths[$selected_idx]}"
    if [ "$chosen_path" = "__STOP__" ]; then
        stop_live
    else
        apply_live "$chosen_path"
    fi
}

# CLI Argument Router
case "${1:-}" in
    --stop)
        stop_live
        ;;
    --status)
        if pgrep -x linux-wallpaperengine >/dev/null 2>&1; then
            echo "active: $(cat "$STATE_FILE" 2>/dev/null || echo "unknown")"
        else
            echo "inactive"
        fi
        ;;
    --toggle)
        if pgrep -x linux-wallpaperengine >/dev/null 2>&1; then
            stop_live
        else
            select_interactive
        fi
        ;;
    "")
        select_interactive
        ;;
    *)
        # Check if ID was passed directly
        if [[ "$1" =~ ^[0-9]+$ ]]; then
            found_target=""
            while IFS= read -r ws_dir; do
                if [ -d "$ws_dir/$1" ]; then
                    found_target="$ws_dir/$1"
                    break
                fi
            done < <(find_workshop_dirs)

            if [ -n "$found_target" ]; then
                apply_live "$found_target"
            else
                apply_live "$1"
            fi
        else
            apply_live "$1"
        fi
        ;;
esac
