#!/usr/bin/env bash
# ==============================================================================
# Soberano Hardware Power & Performance Profile Engine
# Universal Dynamic Hardware Adaptation (AMD / Intel CPU • NVIDIA / AMD Radeon GPU)
# ==============================================================================
set -euo pipefail

SCRIPTS_DIR="${HOME}/dotfiles/scripts"
STATE_FILE="/tmp/soberano_power_profile.state"
GAME_STATE="/tmp/hypr_gamemode.state"

# -----------------------------------------------------------------------------
# Dynamic Hardware Probing
# -----------------------------------------------------------------------------
CPU_NAME=$(grep -m1 "model name" /proc/cpuinfo 2>/dev/null | cut -d: -f2 | xargs | sed -E 's/\(R\)|\(TM\)//g' | awk '{print $1,$2,$3}')
[ -z "$CPU_NAME" ] && CPU_NAME="CPU"
CPU_THREADS=$(nproc 2>/dev/null || echo 1)

# Sysfs hardware frequency boundaries (in kHz)
CPU_MIN_FREQ=$(cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_min_freq 2>/dev/null || echo "600000")
CPU_MAX_FREQ=$(cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq 2>/dev/null || echo "5000000")

CPU_MIN_GHZ=$(awk "BEGIN {printf \"%.2f\", $CPU_MIN_FREQ / 1000000}")
CPU_MAX_GHZ=$(awk "BEGIN {printf \"%.2f\", $CPU_MAX_FREQ / 1000000}")

# GPU Detection
HAS_NVIDIA=false
HAS_AMD_GPU=false
NV_MIN_PL=""
NV_MAX_PL=""

if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi >/dev/null 2>&1; then
    HAS_NVIDIA=true
    NV_INFO=$(nvidia-smi -q -d POWER 2>/dev/null || true)
    NV_MIN_PL=$(echo "$NV_INFO" | grep "Min Power Limit" | head -1 | awk '{print $5}' | cut -d. -f1 || echo "100")
    NV_MAX_PL=$(echo "$NV_INFO" | grep "Max Power Limit" | head -1 | awk '{print $5}' | cut -d. -f1 || echo "200")
    [ -z "$NV_MIN_PL" ] && NV_MIN_PL=100
    [ -z "$NV_MAX_PL" ] && NV_MAX_PL=200
fi

for card_dpm in /sys/class/drm/card*/device/power_dpm_force_performance_level; do
    if [ -f "$card_dpm" ]; then
        HAS_AMD_GPU=true
        break
    fi
done

# -----------------------------------------------------------------------------
# Profile Functions
# -----------------------------------------------------------------------------
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

    # 1. CPU: Disable Boost, clamp to hardware min freq, power EPP
    sudo sh -c 'echo 0 > /sys/devices/system/cpu/cpufreq/boost' 2>/dev/null || true
    sudo sh -c 'for g in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do echo powersave > "$g"; done' 2>/dev/null || true
    sudo sh -c 'for e in /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference; do echo power > "$e"; done' 2>/dev/null || true
    sudo sh -c "for f in /sys/devices/system/cpu/cpu*/cpufreq/scaling_max_freq; do echo $CPU_MIN_FREQ > \"\$f\"; done" 2>/dev/null || true
    if command -v powerprofilesctl >/dev/null 2>&1; then
        powerprofilesctl set power-saver >/dev/null 2>&1 || true
    fi

    # 2. GPU Power Clamping
    if [ "$HAS_NVIDIA" = true ]; then
        sudo nvidia-smi -lgc 210,450 >/dev/null 2>&1 || true
        sudo nvidia-smi -pl "$NV_MIN_PL" >/dev/null 2>&1 || true
        if command -v nvidia-settings >/dev/null 2>&1; then
            nvidia-settings -a '[gpu:0]/GPUPowerMizerMode=0' >/dev/null 2>&1 || true
        fi
    fi

    if [ "$HAS_AMD_GPU" = true ]; then
        sudo sh -c 'for d in /sys/class/drm/card*/device/power_dpm_force_performance_level; do echo low > "$d"; done' 2>/dev/null || true
    fi

    echo "eco" > "$STATE_FILE"
    notify-send -u low -a "Soberano Power" "🌿 Perfil: ECO SILENCIOSO (${CPU_MIN_GHZ} GHz)" "${CPU_NAME} travado a ${CPU_MIN_GHZ} GHz • GPU Fria / Min TDP • Zero Ruído" 2>/dev/null || true
}

apply_balanced() {
    exit_game_mode_if_active

    # 1. CPU: Enable Boost, restore full dynamic frequency range
    sudo sh -c 'echo 1 > /sys/devices/system/cpu/cpufreq/boost' 2>/dev/null || true
    sudo sh -c "for f in /sys/devices/system/cpu/cpu*/cpufreq/scaling_max_freq; do echo $CPU_MAX_FREQ > \"\$f\"; done" 2>/dev/null || true
    sudo sh -c 'for g in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do echo powersave > "$g"; done' 2>/dev/null || true
    sudo sh -c 'for e in /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference; do echo balance_performance > "$e"; done' 2>/dev/null || true
    if command -v powerprofilesctl >/dev/null 2>&1; then
        powerprofilesctl set balanced >/dev/null 2>&1 || true
    fi

    # 2. GPU: Dynamic auto clocks & maximum stock TDP
    if [ "$HAS_NVIDIA" = true ]; then
        sudo nvidia-smi -rgc >/dev/null 2>&1 || true
        sudo nvidia-smi -pl "$NV_MAX_PL" >/dev/null 2>&1 || true
        if command -v nvidia-settings >/dev/null 2>&1; then
            nvidia-settings -a '[gpu:0]/GPUPowerMizerMode=0' >/dev/null 2>&1 || true
        fi
    fi

    if [ "$HAS_AMD_GPU" = true ]; then
        sudo sh -c 'for d in /sys/class/drm/card*/device/power_dpm_force_performance_level; do echo auto > "$d"; done' 2>/dev/null || true
    fi

    # 3. Kernel Virtual Memory Default
    sudo sysctl -w vm.swappiness=60 >/dev/null 2>&1 || true
    sudo sysctl -w vm.compaction_proactiveness=20 >/dev/null 2>&1 || true
    sudo sysctl -w vm.stat_interval=1 >/dev/null 2>&1 || true

    echo "balanced" > "$STATE_FILE"
    notify-send -u normal -a "Soberano Power" "⚖️ Perfil: BALANCEADO" "${CPU_NAME} Dinâmico (${CPU_MIN_GHZ}–${CPU_MAX_GHZ} GHz) • GPU Auto • Desktop Suave" 2>/dev/null || true
}

apply_compute() {
    exit_game_mode_if_active

    # 1. CPU: Maximum boost on all threads, performance governor & EPP
    sudo sh -c 'echo 1 > /sys/devices/system/cpu/cpufreq/boost' 2>/dev/null || true
    sudo sh -c "for f in /sys/devices/system/cpu/cpu*/cpufreq/scaling_max_freq; do echo $CPU_MAX_FREQ > \"\$f\"; done" 2>/dev/null || true
    sudo sh -c 'for g in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do echo performance > "$g"; done' 2>/dev/null || true
    sudo sh -c 'for e in /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference; do echo performance > "$e"; done' 2>/dev/null || true
    if command -v powerprofilesctl >/dev/null 2>&1; then
        powerprofilesctl set performance >/dev/null 2>&1 || true
    fi

    # 2. GPU: Unlocked clocks, max TDP, PowerMizer Max Performance
    if [ "$HAS_NVIDIA" = true ]; then
        sudo nvidia-smi -rgc >/dev/null 2>&1 || true
        sudo nvidia-smi -pl "$NV_MAX_PL" >/dev/null 2>&1 || true
        if command -v nvidia-settings >/dev/null 2>&1; then
            nvidia-settings -a '[gpu:0]/GPUPowerMizerMode=1' >/dev/null 2>&1 || true
        fi
    fi

    if [ "$HAS_AMD_GPU" = true ]; then
        sudo sh -c 'for d in /sys/class/drm/card*/device/power_dpm_force_performance_level; do echo high > "$d"; done' 2>/dev/null || true
    fi

    # 3. Kernel low swappiness for heavy compile / renders
    sudo sysctl -w vm.swappiness=10 >/dev/null 2>&1 || true

    echo "compute" > "$STATE_FILE"
    notify-send -u normal -a "Soberano Power" "⚡ Perfil: COMPUTAÇÃO BRUTA" "${CPU_THREADS} Threads em 100% Performance • GPU Desbloqueada • Desktop Ativo" 2>/dev/null || true
}

apply_game() {
    if [ ! -f "$GAME_STATE" ]; then
        bash "${SCRIPTS_DIR}/GameMode.sh"
    fi
    echo "game" > "$STATE_FILE"
}

show_menu() {
    current=$(get_current_profile)

    options=(
        "🌿  Eco Silencioso (${CPU_MIN_GHZ} GHz • GPU Fria / Min TDP • Zero Ruído)"
        "⚖️  Balanceado (Padrão Diário • Clocks Dinâmicos • Efeitos ON)"
        "⚡  Computação / Render (${CPU_THREADS} Threads no Máximo • Desktop ON)"
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

    chosen=$(printf '%s\n' "${menu_lines[@]}" | fuzzel --dmenu -p "⚡ Perfil de Energia ❯ " -w 58 -l 6 || true)
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
