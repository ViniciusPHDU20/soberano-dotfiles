#!/usr/bin/env bash
# ==============================================================================
# Soberano Live Wallpaper Engine (Almamu linux-wallpaperengine + Matugen MD3)
# Seamlessly integrates Steam Wallpaper Engine (431960) with Hyprland and Wayle
# Managed via transient systemd user service for zero process drops and rock-solid audio
# ==============================================================================
set -euo pipefail

CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/soberano/livewallpaper.json"
STATE_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/soberano_livewallpaper.state"
STATIC_RESTORE="${HOME}/dotfiles/scripts/WallpaperSelect.sh"
SCHEME_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/soberano_matugen_scheme.txt"

# Default fallback settings
FPS=144
VOLUME=50
SILENT=false
AUTOMUTE=false
AUDIO_PROCESSING=true
FULLSCREEN_PAUSE=true
SCALING="fill"
MOUSE_INTERACTION=true
PARALLAX=true
PARTICLES=true

# Load persistent user configuration from JSON
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        FPS=$(jq -r '.fps // 144' "$CONFIG_FILE" 2>/dev/null || echo 144)
        VOLUME=$(jq -r '.volume // 50' "$CONFIG_FILE" 2>/dev/null || echo 50)
        SILENT=$(jq -r '.silent // false' "$CONFIG_FILE" 2>/dev/null || echo false)
        AUTOMUTE=$(jq -r '.automute // false' "$CONFIG_FILE" 2>/dev/null || echo false)
        AUDIO_PROCESSING=$(jq -r '.audio_processing // true' "$CONFIG_FILE" 2>/dev/null || echo true)
        FULLSCREEN_PAUSE=$(jq -r '.fullscreen_pause // true' "$CONFIG_FILE" 2>/dev/null || echo true)
        SCALING=$(jq -r '.scaling // "fill"' "$CONFIG_FILE" 2>/dev/null || echo "fill")
        MOUSE_INTERACTION=$(jq -r '.mouse_interaction // true' "$CONFIG_FILE" 2>/dev/null || echo true)
        PARALLAX=$(jq -r '.parallax // true' "$CONFIG_FILE" 2>/dev/null || echo true)
        PARTICLES=$(jq -r '.particles // true' "$CONFIG_FILE" 2>/dev/null || echo true)
    fi
}

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
    local vdf_candidates=(
        "$HOME/.local/share/Steam/steamapps/libraryfolders.vdf"
        "$HOME/.steam/steam/steamapps/libraryfolders.vdf"
    )
    for vdf in "${vdf_candidates[@]}"; do
        if [ -f "$vdf" ]; then
            while IFS= read -r path; do
                local extra_ws="${path}/steamapps/workshop/content/431960"
                if [ -d "$extra_ws" ] && [[ ! " ${dirs[*]} " =~ " ${extra_ws} " ]]; then
                    dirs+=("$extra_ws")
                fi
            done < <(grep -oP '"path"\s*"\K[^"]+' "$vdf" 2>/dev/null || true)
        fi
    done

    # 3. User custom live wallpaper directory
    local user_live="$HOME/wallpapers/live"
    mkdir -p "$user_live"
    dirs+=("$user_live")

    printf "%s\n" "${dirs[@]}"
}

# Stop live wallpaper and restore static engine
stop_live() {
    systemctl --user stop soberano-livewallpaper 2>/dev/null || true
    killall -9 linux-wallpaperengine 2>/dev/null || true
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

    load_config
    local mon
    mon=$(get_monitor)

    # 1. Cleanly terminate any running live wallpaper or awww-daemon to prevent conflicts
    systemctl --user stop soberano-livewallpaper 2>/dev/null || true
    killall -9 linux-wallpaperengine 2>/dev/null || true
    killall -9 awww-daemon 2>/dev/null || true

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

    # 3. Assemble command flags based on user configuration
    local cmd_args=(
        --screen-root "$mon"
        --fps "$FPS"
        --scaling "$SCALING"
        --layer background
    )

    if [ "$SILENT" = "true" ]; then
        cmd_args+=(--silent)
    else
        cmd_args+=(--volume "$VOLUME")
    fi

    # Crucial: pass --noautomute so Discord / browser / CAVA doesn't silently mute wallpaper audio
    if [ "$AUTOMUTE" = "false" ]; then
        cmd_args+=(--noautomute)
    fi

    if [ "$AUDIO_PROCESSING" = "false" ]; then
        cmd_args+=(--no-audio-processing)
    fi

    if [ "$FULLSCREEN_PAUSE" = "true" ]; then
        cmd_args+=(--fullscreen-pause-only-active)
    else
        cmd_args+=(--no-fullscreen-pause)
    fi

    if [ "$MOUSE_INTERACTION" = "false" ]; then
        cmd_args+=(--disable-mouse)
    fi

    if [ "$PARALLAX" = "false" ]; then
        cmd_args+=(--disable-parallax)
    fi

    if [ "$PARTICLES" = "false" ]; then
        cmd_args+=(--disable-particles)
    fi

    cmd_args+=("$target")

    # 4. Launch linux-wallpaperengine isolated as a systemd user unit
    systemd-run --user --unit=soberano-livewallpaper linux-wallpaperengine "${cmd_args[@]}" >/dev/null 2>&1

    echo "$target" > "$STATE_FILE"
    notify-send -u normal -a "Soberano Wallpapers" "󰸉 Live Wallpaper Ativo" "${title} (${mon} • ${FPS} FPS • Vol: ${VOLUME}%)" 2>/dev/null || true
}

# Reload currently active live wallpaper with updated settings
reload_live() {
    if [ -f "$STATE_FILE" ]; then
        local current
        current=$(cat "$STATE_FILE" 2>/dev/null || true)
        if [ -n "$current" ] && { [ -d "$current" ] || [ -f "$current" ]; }; then
            apply_live "$current"
            return 0
        fi
    fi
    notify-send -u low -a "Soberano Wallpapers" "Nenhum Live Wallpaper Ativo" "Inicie um wallpaper animado pela galeria antes de recarregar." 2>/dev/null || true
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
    --reload)
        reload_live
        ;;
    --status)
        if systemctl --user is-active --quiet soberano-livewallpaper || pgrep -x linux-wallpaperengine >/dev/null 2>&1; then
            echo "active: $(cat "$STATE_FILE" 2>/dev/null || echo "unknown")"
        else
            echo "inactive"
        fi
        ;;
    --toggle)
        if systemctl --user is-active --quiet soberano-livewallpaper || pgrep -x linux-wallpaperengine >/dev/null 2>&1; then
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
