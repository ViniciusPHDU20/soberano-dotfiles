#!/usr/bin/env bash
# ==============================================================================
# Hyprland Post-Processing GLSL Shader Manager
# ==============================================================================

SHADER_DIR="$HOME/.config/hypr/shaders"
STATE_FILE="$HOME/.config/hypr/.current_shader"

apply_shader() {
    local shader_name="$1"
    local shader_path="$SHADER_DIR/$shader_name.frag"

    if [ "$shader_name" = "off" ] || [ -z "$shader_name" ]; then
        hyprctl eval 'hl.config({ decoration = { screen_shader = "" } })' >/dev/null 2>&1
        echo "off" > "$STATE_FILE"
        notify-send -a "Hyprland Shaders" -i video-display "Shaders Desativados" "Pós-processamento desativado." -t 2000
        return 0
    fi

    if [ ! -f "$shader_path" ]; then
        notify-send -a "Hyprland Shaders" -u critical "Erro de Shader" "Arquivo não encontrado: $shader_name.frag"
        return 1
    fi

    hyprctl eval "hl.config({ decoration = { screen_shader = \"$shader_path\" } })" >/dev/null 2>&1
    echo "$shader_name" > "$STATE_FILE"
    
    local title=""
    case "$shader_name" in
        vibrance) title="Vibrance & Contrast Pop" ;;
        night-warm) title="Modo Noturno (Filtro Azul)" ;;
        crt-retro) title="Retro CRT Scanlines" ;;
        cyberpunk) title="Cyberpunk Neon Chroma" ;;
        monochrome) title="Cinema Monocromático" ;;
        soft-bloom) title="Soft Dream Bloom" ;;
        *) title="$shader_name" ;;
    esac

    notify-send -a "Hyprland Shaders" -i video-display "Shader Ativado" "$title" -t 2000
}

toggle_vibrance() {
    local current=$(cat "$STATE_FILE" 2>/dev/null || echo "off")
    if [ "$current" = "vibrance" ]; then
        apply_shader "off"
    else
        apply_shader "vibrance"
    fi
}

toggle_night() {
    local current=$(cat "$STATE_FILE" 2>/dev/null || echo "off")
    if [ "$current" = "night-warm" ]; then
        apply_shader "off"
    else
        apply_shader "night-warm"
    fi
}

show_menu() {
    local current=$(cat "$STATE_FILE" 2>/dev/null || echo "off")
    
    local options="󰌪 Desativar (Off)\n󰏘 Vibrance Pop (Cores Vivas & Contraste)\n󰖔 Modo Noturno (Filtro Luz Azul 3600K)\n󰢩 Cyberpunk Neon (Chroma Aberration)\n󰑋 Retro CRT (Scanlines & Distorção)\n󰄄 Cinema Monocromático (Black & White)\n󰔎 Soft Dream Glow (Bloom Suave)"

    local choice=$(echo -e "$options" | fuzzel --dmenu -p "󰌪 Shaders GLSL [$current] ❯ " -w 55 -l 8)

    case "$choice" in
        *"Desativar"*) apply_shader "off" ;;
        *"Vibrance"*) apply_shader "vibrance" ;;
        *"Modo Noturno"*) apply_shader "night-warm" ;;
        *"Cyberpunk"*) apply_shader "cyberpunk" ;;
        *"Retro CRT"*) apply_shader "crt-retro" ;;
        *"Monocromático"*) apply_shader "monochrome" ;;
        *"Soft Dream"*) apply_shader "soft-bloom" ;;
    esac
}

case "$1" in
    vibrance|night-warm|crt-retro|cyberpunk|monochrome|soft-bloom|off)
        apply_shader "$1"
        ;;
    toggle-vibrance)
        toggle_vibrance
        ;;
    toggle-night)
        toggle_night
        ;;
    menu|"")
        show_menu
        ;;
    *)
        echo "Uso: $0 [vibrance|night-warm|crt-retro|cyberpunk|monochrome|soft-bloom|off|toggle-vibrance|toggle-night|menu]"
        ;;
esac
