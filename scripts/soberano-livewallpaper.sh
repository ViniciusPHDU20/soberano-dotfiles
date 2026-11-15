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

# Launch Wallpaper Animator Studio with seamless auto-restore lifecycle
launch_wallpaper_animator_studio() {
    local wa_run="$HOME/.local/share/Steam/steamapps/common/Wallpaper Animator/AppRun"
    if [ ! -x "$wa_run" ]; then
        notify-send -u normal -a "Soberano Wallpapers" "Wallpaper Animator Ausente" "O aplicativo não foi encontrado na biblioteca Steam." 2>/dev/null || true
        return 1
    fi

    # 1. Stop any currently active live wallpaper to free GPU
    systemctl --user stop soberano-wallpaper-watcher 2>/dev/null || true
    systemctl --user stop soberano-livewallpaper 2>/dev/null || true
    killall -9 linux-wallpaperengine 2>/dev/null || true
    rm -f "$STATE_FILE"

    # 2. Notify user
    notify-send -u normal -a "Soberano Wallpapers" "✨ Wallpaper Animator Studio" "Iniciando estúdio de IA... Ao fechar, o wallpaper estático será restaurado." 2>/dev/null || true

    # 3. Launch Wallpaper Animator in a dedicated supervisor subshell
    (
        "$wa_run" >/dev/null 2>&1
        # When user closes the GUI, automatically restore awww static wallpaper!
        pkill -f "/usr/bin/mpvpaper" 2>/dev/null || true
        systemctl --user start awww-daemon.service 2>/dev/null || true
        if [ -f "$STATIC_RESTORE" ]; then
            "$STATIC_RESTORE" --restore >/dev/null 2>&1
        fi
        notify-send -u low -a "Soberano Wallpapers" "󰸉 Wallpaper Restaurado" "Wallpaper Animator encerrado • awww restaurado com sucesso." 2>/dev/null || true
    ) &
}

# Stop live wallpaper and restore static engine
stop_live() {
    systemctl --user stop soberano-wallpaper-watcher 2>/dev/null || true
    systemctl --user reset-failed soberano-wallpaper-watcher 2>/dev/null || true
    pkill -f soberano-wallpaper-watcher.py 2>/dev/null || true
    systemctl --user stop soberano-livewallpaper 2>/dev/null || true
    systemctl --user reset-failed soberano-livewallpaper 2>/dev/null || true
    killall -9 linux-wallpaperengine 2>/dev/null || true
    pkill -f mpvpaper 2>/dev/null || true
    rm -f "$STATE_FILE"

    # Ensure awww service is restored
    systemctl --user start awww-daemon.service 2>/dev/null || true

    # Restore awww + last static wallpaper
    if [ -f "$STATIC_RESTORE" ]; then
        "$STATIC_RESTORE" --restore >/dev/null 2>&1 &
    fi

    notify-send -u low -a "Soberano Wallpapers" "󰸉 Wallpaper Estático Restaurado" "Engine animado encerrado • awww 144Hz ativo" 2>/dev/null || true
}

# Apply a specific live wallpaper
apply_live() {
    local target="$1"

    # Detect if target is a video file or a Wallpaper Animator folder containing video
    local is_wa_video=false
    local video_file=""

    if [ -d "$target" ] && [ -f "$target/video.mp4" ]; then
        is_wa_video=true
        video_file="$target/video.mp4"
    elif [ -d "$target" ] && [ -f "$target/video.webm" ]; then
        is_wa_video=true
        video_file="$target/video.webm"
    elif [ -f "$target" ] && [[ "$target" =~ \.(mp4|webm|mkv)$ ]] && [ ! -f "$(dirname "$target")/project.json" ]; then
        is_wa_video=true
        video_file="$target"
    fi

    if [ "$is_wa_video" = "false" ] && ! command -v linux-wallpaperengine >/dev/null 2>&1; then
        notify-send -u normal -a "Soberano Wallpapers" "Wallpaper Engine Ausente" "O linux-wallpaperengine não está instalado. Ative pelo instalador ou instale 'linux-wallpaperengine-v3-bin'." 2>/dev/null || true
        echo "Aviso: linux-wallpaperengine não está instalado no sistema." >&2
        return 1
    fi

    if [ ! -d "$target" ] && [ ! -f "$target" ]; then
        notify-send -u critical -a "Soberano Wallpapers" "Erro ao Carregar Wallpaper" "Caminho ou ID inválido: $target" 2>/dev/null || true
        exit 1
    fi

    load_config
    local mon
    mon=$(get_monitor)

    # 1. Cleanly terminate any running live wallpaper and suspend awww-daemon to allow video layer
    systemctl --user stop soberano-wallpaper-watcher 2>/dev/null || true
    systemctl --user reset-failed soberano-wallpaper-watcher 2>/dev/null || true
    pkill -f soberano-wallpaper-watcher.py 2>/dev/null || true
    systemctl --user stop soberano-livewallpaper 2>/dev/null || true
    systemctl --user reset-failed soberano-livewallpaper 2>/dev/null || true
    killall -9 linux-wallpaperengine 2>/dev/null || true
    pkill -f mpvpaper 2>/dev/null || true
    systemctl --user stop awww-daemon.service 2>/dev/null || true
    killall -9 awww-daemon 2>/dev/null || true

    # 2. Extract Matugen color scheme from high-resolution preview frame or target
    local preview=""
    local item_id
    item_id=$(basename "$target")
    local hires_preview="${XDG_CACHE_HOME:-$HOME/.cache}/soberano_thumbnails/hires_${item_id}.jpg"

    if [ -f "$hires_preview" ]; then
        preview="$hires_preview"
    elif [ -d "$target" ]; then
        for p in "$target/thumb.jpg" "$target/image.png" "$target/preview.jpg" "$target/preview.png" "$target/preview.webp" "$target/preview.gif"; do
            if [ -f "$p" ]; then
                preview="$p"
                break
            fi
        done
    elif [ -f "$target" ]; then
        if [ -f "$(dirname "$target")/thumb.jpg" ]; then
            preview="$(dirname "$target")/thumb.jpg"
        elif [ -f "$(dirname "$target")/image.png" ]; then
            preview="$(dirname "$target")/image.png"
        else
            preview="$target"
        fi
    fi

    local title
    title=$(basename "$target")
    if [ -d "$target" ] && [ -f "$target/project.json" ]; then
        local parsed_title
        parsed_title=$(jq -r '.title // empty' "$target/project.json" 2>/dev/null || true)
        [ -n "$parsed_title" ] && title="$parsed_title"
    elif [ -d "$target" ] && [ -f "$target/meta.json" ]; then
        local parsed_title
        parsed_title=$(jq -r '.title // empty' "$target/meta.json" 2>/dev/null || true)
        [ -n "$parsed_title" ] && title="$parsed_title"
    elif [ -f "$target" ] && [ -f "$(dirname "$target")/meta.json" ]; then
        local parsed_title
        parsed_title=$(jq -r '.title // empty' "$(dirname "$target")/meta.json" 2>/dev/null || true)
        [ -n "$parsed_title" ] && title="$parsed_title"
    fi

    if [ -n "$preview" ] && [ -f "$preview" ]; then
        local scheme
        scheme=$(cat "$SCHEME_FILE" 2>/dev/null || echo "vibrant")
        pkill -x matugen 2>/dev/null || true
        matugen image "$preview" -t "scheme-${scheme}" -m dark --prefer saturation --contrast -0.45 >/dev/null 2>&1 || true
        sed -i "s|^wallpaper = .*|wallpaper = \"$preview\"|" "${HOME}/dotfiles/config/wayle/config.toml" 2>/dev/null || true
        wayle wallpaper set "$preview" >/dev/null 2>&1 || true
    fi

    # 3. If target is a standalone video or Wallpaper Animator animation, launch via mpvpaper
    if [ "$is_wa_video" = "true" ]; then
        local mpvpaper_cmd="mpvpaper"
        if ! command -v mpvpaper >/dev/null 2>&1; then
            local bundled_mpvpaper="$HOME/.local/share/Steam/steamapps/common/Wallpaper Animator/usr/bin/mpvpaper"
            if [ -x "$bundled_mpvpaper" ]; then
                mpvpaper_cmd="$bundled_mpvpaper"
            fi
        fi

        local audio_opts="loop"
        if [ "$SILENT" = "true" ]; then
            audio_opts="loop no-audio"
        else
            local eff_vol="$VOLUME"
            if [ "$eff_vol" -gt 0 ]; then
                eff_vol=$(python3 -c "import sys; v=int(sys.argv[1]); print(min(100, int(round((v/100.0)**0.6 * 100))))" "$VOLUME" 2>/dev/null || echo "$VOLUME")
            fi
            audio_opts="loop volume=${eff_vol}"
        fi

        systemd-run --user --unit=soberano-livewallpaper "$mpvpaper_cmd" -p -o "$audio_opts" "$mon" "$video_file" >/dev/null 2>&1
        echo "$target" > "$STATE_FILE"
        notify-send -u normal -a "Soberano Wallpapers" "🎬 Live Wallpaper IA Ativo" "${title} (${mon} • mpvpaper • Vol: ${VOLUME}%)" 2>/dev/null || true
        return 0
    fi

    # 4. Assemble command flags based on user configuration for linux-wallpaperengine
    local cmd_args=(
        --screen-root "$mon"
        --fps "$FPS"
        --scaling "$SCALING"
        --clamp border
        --layer background
    )

    if [ "$SILENT" = "true" ]; then
        cmd_args+=(--silent)
    else
        local eff_vol="$VOLUME"
        if [ "$eff_vol" -gt 0 ]; then
            eff_vol=$(python3 -c "import sys; v=int(sys.argv[1]); print(min(100, int(round((v/100.0)**0.6 * 100))))" "$VOLUME" 2>/dev/null || echo "$VOLUME")
        fi
        cmd_args+=(--volume "$eff_vol")
    fi

    # Crucial: pass --noautomute so Discord / browser / CAVA doesn't silently mute wallpaper audio.
    # Dynamic workspace & focus auto-mute is handled natively by soberano-wallpaper-watcher.py
    cmd_args+=(--noautomute)

    if [ "$AUDIO_PROCESSING" = "false" ]; then
        cmd_args+=(
            --no-audio-processing
            --set-property audioresponsive=0
            --set-property glitchaudioresponsive=0
            --set-property visualizer=0
            --set-property audiobars1=0
            --set-property audiovisualiser=0
            --set-property rain=0
        )
    else
        cmd_args+=(
            --set-property audioresponsive=1
            --set-property glitchaudioresponsive=1
            --set-property visualizer=1
            --set-property audiobars1=1
            --set-property audiovisualiser=1
            --set-property rain=1
        )
    fi

    if [ "$FULLSCREEN_PAUSE" = "true" ]; then
        cmd_args+=(--fullscreen-pause-only-active)
    else
        cmd_args+=(--no-fullscreen-pause)
    fi

    if [ "$MOUSE_INTERACTION" = "false" ]; then
        cmd_args+=(--disable-mouse --set-property mouseinfluence=0)
    else
        cmd_args+=(--set-property mouseinfluence=1)
    fi

    if [ "$PARALLAX" = "false" ]; then
        cmd_args+=(--disable-parallax)
    fi

    if [ "$PARTICLES" = "false" ]; then
        cmd_args+=(--disable-particles --set-property particles=0)
    else
        cmd_args+=(--set-property particles=1)
    fi

    cmd_args+=("$target")

    # Launch linux-wallpaperengine isolated as a systemd user unit
    systemd-run --user --unit=soberano-livewallpaper linux-wallpaperengine "${cmd_args[@]}" >/dev/null 2>&1

    # Spawn dynamic focus & workspace audio watcher as a systemd user unit
    systemd-run --user --unit=soberano-wallpaper-watcher python3 "$HOME/dotfiles/scripts/soberano-wallpaper-watcher.py" >/dev/null 2>&1

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
    if ! command -v linux-wallpaperengine >/dev/null 2>&1; then
        notify-send -u normal -a "Soberano Wallpapers" "Wallpaper Engine Ausente" "O linux-wallpaperengine não está instalado. Ative pelo instalador ou instale 'linux-wallpaperengine-v3-bin'." 2>/dev/null || true
        return 1
    fi

    local items=()
    local paths=()

    # First option: Stop / return to static
    items+=("⏹ [Parar Wallpaper Animado / Voltar ao Estático]")
    paths+=("__STOP__")

    # Conditional Steam Wallpaper Animator option (only if installed)
    local wa_run="$HOME/.local/share/Steam/steamapps/common/Wallpaper Animator/AppRun"
    if [ -x "$wa_run" ]; then
        items+=("✨ [Abrir Wallpaper Animator Studio (Steam AI)]")
        paths+=("__WALLPAPER_ANIMATOR_STUDIO__")
    fi

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
    elif [ "$chosen_path" = "__WALLPAPER_ANIMATOR_STUDIO__" ]; then
        launch_wallpaper_animator_studio
    else
        apply_live "$chosen_path"
    fi
}

set_live_volume() {
    local vol="${1:-50}"
    if [ -f "$CONFIG_FILE" ]; then
        jq ".volume = $vol" "$CONFIG_FILE" > "$CONFIG_FILE.tmp" 2>/dev/null && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
    fi
    pactl list sink-inputs 2>/dev/null | awk -v v="${vol}%" '
        /^Sink Input #/ { id = substr($3, 2) }
        /application.name = "(linux-wallpaperengine|mpv)"/ || /application.process.binary = "linux-wallpaperengine"/ {
            if (id != "") system("pactl set-sink-input-volume " id " " v " 2>/dev/null")
        }
    '
}

set_live_mute() {
    local mute_val="${1:-1}"
    local bool_val="false"
    [ "$mute_val" = "1" ] && bool_val="true"
    if [ -f "$CONFIG_FILE" ]; then
        jq ".silent = $bool_val" "$CONFIG_FILE" > "$CONFIG_FILE.tmp" 2>/dev/null && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
    fi
    set_runtime_mute "$mute_val"
}

set_runtime_mute() {
    local mute_val="${1:-1}"
    pactl list sink-inputs 2>/dev/null | awk -v m="$mute_val" '
        /^Sink Input #/ { id = substr($3, 2) }
        /application.name = "(linux-wallpaperengine|mpv)"/ || /application.process.binary = "linux-wallpaperengine"/ {
            if (id != "") system("pactl set-sink-input-mute " id " " m " 2>/dev/null")
        }
    '
}

# CLI Argument Router
case "${1:-}" in
    --launch-wa-studio)
        launch_wallpaper_animator_studio
        ;;
    --stop)
        stop_live
        ;;
    --reload)
        reload_live
        ;;
    --volume)
        set_live_volume "${2:-50}"
        ;;
    --mute)
        set_live_mute "${2:-1}"
        ;;
    --runtime-mute)
        set_runtime_mute "${2:-1}"
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
