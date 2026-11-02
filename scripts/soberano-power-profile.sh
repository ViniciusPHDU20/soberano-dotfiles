#!/usr/bin/env bash
# ==============================================================================
# Soberano Hardware Power & Performance Profile Engine
# AMD Ryzen 9 9950X (16C/32T) + NVIDIA GeForce RTX 3060 Ti
# ==============================================================================
set -euo pipefail

SCRIPTS_DIR="${HOME}/dotfiles/scripts"
STATE_FILE="/tmp/soberano_power_profile.state"
GAME_STATE="/tmp/hypr_gamemode.state"

get_current_profile() {
    if [ -f "$GAME_STATE" ]; then
        echo "game"
    elif [ -f "$STATE_FILE" ]; then
        cat "$STATE_FILE" 2>/dev/null || echo "balanced"
    else
        echo "balanced"
    fi
}

exit_game_mode_if_active() {
    if [ -f "$GAME_STATE" ]; then
        bash "${SCRIPTS_DIR}/GameMode.sh" >/dev/null 2>&1 || true
    fi
}

apply_eco() {
    exit_game_mode_if_active

    # 1. CPU Ryzen 9 9950X: Disable Boost, clamp to 0.61 GHz, power EPP
    sudo sh -c 'echo 0 > /sys/devices/system/cpu/cpufreq/boost' 2>/dev/null || true
    sudo sh -c 'for g in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do echo powersave > "$g"; done' 2>/dev/null || true
    sudo sh -c 'for e in /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference; do echo power > "$e"; done' 2>/dev/null || true
    sudo sh -c 'for f in /sys/devices/system/cpu/cpu*/cpufreq/scaling_max_freq; do echo 614286 > "$f"; done' 2>/dev/null || true
    if command -v powerprofilesctl >/dev/null 2>&1; then
        powerprofilesctl set power-saver >/dev/null 2>&1 || true
    fi

    # 2. GPU RTX 3060 Ti: Clamp to 210MHz idle clock, drop TDP to 100W min
    sudo nvidia-smi -lgc 210,450 >/dev/null 2>&1 || true
    sudo nvidia-smi -pl 100 >/dev/null 2>&1 || true
    if command -v nvidia-settings >/dev/null 2>&1; then
        nvidia-settings -a '[gpu:0]/GPUPowerMizerMode=0' >/dev/null 2>&1 || true
    fi

    echo "eco" > "$STATE_FILE"
    notify-send -u low -a "Soberano Power" "🌿 Perfil: ECO SILENCIOSO (0.61 GHz)" "Ryzen 9 travado a 614 MHz • GPU 210 MHz / 100W • Zero Ruído / Frio" 2>/dev/null || true
}

apply_balanced() {
    exit_game_mode_if_active

    # 1. CPU Ryzen 9 9950X: Enable Boost, full dynamic range (0.61 - 5.7 GHz)
    sudo sh -c 'echo 1 > /sys/devices/system/cpu/cpufreq/boost' 2>/dev/null || true
    sudo sh -c 'for f in /sys/devices/system/cpu/cpu*/cpufreq/scaling_max_freq; do echo 5998320 > "$f"; done' 2>/dev/null || true
    sudo sh -c 'for g in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do echo powersave > "$g"; done' 2>/dev/null || true
    sudo sh -c 'for e in /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference; do echo balance_performance > "$e"; done' 2>/dev/null || true
    if command -v powerprofilesctl >/dev/null 2>&1; then
        powerprofilesctl set balanced >/dev/null 2>&1 || true
    fi

    # 2. GPU RTX 3060 Ti: Dynamic auto clocks, default 200W TDP
    sudo nvidia-smi -rgc >/dev/null 2>&1 || true
    sudo nvidia-smi -pl 200 >/dev/null 2>&1 || true
    if command -v nvidia-settings >/dev/null 2>&1; then
        nvidia-settings -a '[gpu:0]/GPUPowerMizerMode=0' >/dev/null 2>&1 || true
    fi

    # 3. Kernel Virtual Memory Default
    sudo sysctl -w vm.swappiness=60 >/dev/null 2>&1 || true
    sudo sysctl -w vm.compaction_proactiveness=20 >/dev/null 2>&1 || true
    sudo sysctl -w vm.stat_interval=1 >/dev/null 2>&1 || true

    echo "balanced" > "$STATE_FILE"
    notify-send -u normal -a "Soberano Power" "⚖️ Perfil: BALANCEADO" "Ryzen 9 Dinâmico (0.61–5.7 GHz) • GPU Auto • Desktop Suave" 2>/dev/null || true
}

apply_compute() {
    exit_game_mode_if_active

    # 1. CPU Ryzen 9 9950X: Maximum boost on all 32 threads, performance governor
    sudo sh -c 'echo 1 > /sys/devices/system/cpu/cpufreq/boost' 2>/dev/null || true
    sudo sh -c 'for f in /sys/devices/system/cpu/cpu*/cpufreq/scaling_max_freq; do echo 5998320 > "$f"; done' 2>/dev/null || true
    sudo sh -c 'for g in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do echo performance > "$g"; done' 2>/dev/null || true
    sudo sh -c 'for e in /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference; do echo performance > "$e"; done' 2>/dev/null || true
    if command -v powerprofilesctl >/dev/null 2>&1; then
        powerprofilesctl set performance >/dev/null 2>&1 || true
    fi

    # 2. GPU RTX 3060 Ti: Unlocked clocks, 200W TDP, PowerMizer Max Performance
    sudo nvidia-smi -rgc >/dev/null 2>&1 || true
    sudo nvidia-smi -pl 200 >/dev/null 2>&1 || true
    if command -v nvidia-settings >/dev/null 2>&1; then
        nvidia-settings -a '[gpu:0]/GPUPowerMizerMode=1' >/dev/null 2>&1 || true
    fi

    # 3. Kernel low swappiness for heavy compile / renders
    sudo sysctl -w vm.swappiness=10 >/dev/null 2>&1 || true

    echo "compute" > "$STATE_FILE"
    notify-send -u normal -a "Soberano Power" "⚡ Perfil: COMPUTAÇÃO BRUTA" "32 Cores em 100% Performance • GPU 200W • Desktop Ativo" 2>/dev/null || true
}

apply_game() {
    # If not in game mode, trigger GameMode.sh
    if [ ! -f "$GAME_STATE" ]; then
        bash "${SCRIPTS_DIR}/GameMode.sh"
    fi
    echo "game" > "$STATE_FILE"
}

show_menu() {
    current=$(get_current_profile)

    options=(
        "🌿  Eco Silencioso (0.61 GHz • GPU 210 MHz / 100W • Frio)"
        "⚖️  Balanceado (Padrão Diário • Clocks Dinâmicos • Efeitos ON)"
        "⚡  Computação / Render (32 Cores no Máximo • Desktop ON)"
        "🎮  Modo Escovar Bit (Jogos Competitivos • Zero Overhead • Tearing ON)"
    )

    menu_lines=()
    for opt in "${options[@]}"; do
        if [[ "$opt" == *"Eco"* ]] && [ "$current" = "eco" ]; then
            menu_lines+=("👉 $opt")
        elif [[ "$opt" == *"Balanceado"* ]] && [ "$current" = "balanced" ]; then
            menu_lines+=("👉 $opt")
        elif [[ "$opt" == *"Computação"* ]] && [ "$current" = "compute" ]; then
            menu_lines+=("👉 $opt")
        elif [[ "$opt" == *"Escovar Bit"* ]] && [ "$current" = "game" ]; then
            menu_lines+=("👉 $opt")
        else
            menu_lines+=("   $opt")
        fi
    done

    chosen=$(printf '%s\n' "${menu_lines[@]}" | fuzzel --dmenu -p "⚡ Perfil de Energia ❯ " -w 56 -l 6 || true)
    [ -z "$chosen" ] && exit 0

    if [[ "$chosen" == *"Eco"* ]]; then
        apply_eco
    elif [[ "$chosen" == *"Balanceado"* ]]; then
        apply_balanced
    elif [[ "$chosen" == *"Computação"* ]]; then
        apply_compute
    elif [[ "$chosen" == *"Escovar Bit"* ]]; then
        apply_game
    fi
}

case "${1:-menu}" in
    --eco|eco)
        apply_eco
        ;;
    --balanced|balanced)
        apply_balanced
        ;;
    --compute|compute)
        apply_compute
        ;;
    --game|game)
        apply_game
        ;;
    --toggle-eco)
        if [ "$(get_current_profile)" = "eco" ]; then
            apply_balanced
        else
            apply_eco
        fi
        ;;
    --menu|menu)
        show_menu
        ;;
    --status|status)
        echo "$(get_current_profile)"
        ;;
    *)
        show_menu
        ;;
esac
