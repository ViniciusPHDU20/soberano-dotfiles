#!/usr/bin/env bash
# ==============================================================================
# Soberano GameMode Extreme (Modo Escovar Bit)
# Universal Low-Latency Engine for AMD / Intel CPU • NVIDIA / AMD Radeon GPU
# Zero-overhead: Barra OFF, Wallpaper OFF, Hyprland 0 animações/bordas,
# Clocks de GPU cravados no teto, CPU Governor Performance, Sysctl Gaming
# Bound to: Super + G | Super + Shift + G | Super + F1
# ==============================================================================
set -euo pipefail

SCRIPTS_DIR="${HOME}/dotfiles/scripts"
STATE_FILE="/tmp/hypr_gamemode.state"

CPU_NAME=$(grep -m1 "model name" /proc/cpuinfo 2>/dev/null | cut -d: -f2 | xargs | sed -E 's/\(R\)|\(TM\)//g' | awk '{print $1,$2,$3}')
[ -z "$CPU_NAME" ] && CPU_NAME="CPU"

if [ -f "$STATE_FILE" ]; then
    rm -f "$STATE_FILE"

    # 1. Reset CPU Governor & EPP
    sudo sh -c 'for g in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do echo powersave > "$g"; done' 2>/dev/null || true
    sudo sh -c 'for e in /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference; do echo balance_performance > "$e"; done' 2>/dev/null || true
    if command -v powerprofilesctl >/dev/null 2>&1; then
        powerprofilesctl set balanced >/dev/null 2>&1 || true
    fi

    # 2. Reset GPU Clocks & PowerMizer
    if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi >/dev/null 2>&1; then
        sudo nvidia-smi -rgc >/dev/null 2>&1 || true
        if command -v nvidia-settings >/dev/null 2>&1; then
            nvidia-settings -a '[gpu:0]/GPUPowerMizerMode=0' >/dev/null 2>&1 || true
        fi
    fi

    for d in /sys/class/drm/card*/device/power_dpm_force_performance_level; do
        if [ -f "$d" ]; then
            echo auto | sudo tee "$d" >/dev/null 2>&1 || true
        fi
    done

    # 3. Reset Kernel Virtual Memory Tuning
    sudo sysctl -w vm.swappiness=60 >/dev/null 2>&1 || true
    sudo sysctl -w vm.compaction_proactiveness=20 >/dev/null 2>&1 || true
    sudo sysctl -w vm.stat_interval=1 >/dev/null 2>&1 || true

    # 4. Restore Hyprland Configuration (Animations, Blurs, Gaps, Borders)
    hyprctl reload >/dev/null 2>&1 || true

    # 5. Restore Desktop Shell (Wayle) & Wallpaper (awww)
    systemctl --user start wayle.service >/dev/null 2>&1 || true
    systemctl --user start awww-daemon.service >/dev/null 2>&1 || true
    pkill -CONT -x linux-wallpaperengine 2>/dev/null || true
    if ! pgrep -x linux-wallpaperengine >/dev/null 2>&1; then
        "${SCRIPTS_DIR}/WallpaperSelect.sh" --restore >/dev/null 2>&1 &
    fi

    notify-send -u normal -a "GameMode" "🚀 GameMode: DESATIVADO" "${CPU_NAME} & GPU Dinâmicos • Wayle & Wallpaper Restaurados • Efeitos ON" 2>/dev/null || true
    exit 0
else
    touch "$STATE_FILE"

    # 1. Stop Desktop Shell & Daemons (Eliminates bar draw calls, CAVA FFT & pollers)
    systemctl --user stop wayle.service >/dev/null 2>&1 || true
    systemctl --user stop awww-daemon.service >/dev/null 2>&1 || true
    killall -9 awww-daemon 2>/dev/null || true
    systemctl --user stop soberano-livewallpaper >/dev/null 2>&1 || true
    killall -9 linux-wallpaperengine 2>/dev/null || true

    # 2. Flush OS page caches to maximize contiguous free physical RAM
    sync
    echo 3 | sudo tee /proc/sys/vm/drop_caches >/dev/null 2>&1 || true

    # 3. Kernel Low-Latency & Anti-Stutter Tuning
    sudo sysctl -w vm.swappiness=10 >/dev/null 2>&1 || true
    sudo sysctl -w vm.compaction_proactiveness=0 >/dev/null 2>&1 || true
    sudo sysctl -w vm.stat_interval=10 >/dev/null 2>&1 || true
    sudo sysctl -w kernel.split_lock_mitigate=0 >/dev/null 2>&1 || true

    # 4. Maximize CPU Performance on all threads
    sudo sh -c 'for g in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do echo performance > "$g"; done' 2>/dev/null || true
    sudo sh -c 'for e in /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference; do echo performance > "$e"; done' 2>/dev/null || true
    if command -v powerprofilesctl >/dev/null 2>&1; then
        powerprofilesctl set performance >/dev/null 2>&1 || true
    fi

    # 5. Lock GPU Clocks to Boost Clocks
    if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi >/dev/null 2>&1; then
        if command -v nvidia-settings >/dev/null 2>&1; then
            nvidia-settings -a '[gpu:0]/GPUPowerMizerMode=1' >/dev/null 2>&1 || true
        fi
        NV_CLK_RAW=$(nvidia-smi --query-gpu=clocks.max.graphics --format=csv,noheader,nounits 2>/dev/null || true)
        NV_MAX_CLK=$(echo "$NV_CLK_RAW" | head -1 | xargs || true)
        if [ -n "$NV_MAX_CLK" ] && [ "$NV_MAX_CLK" -gt 500 ] 2>/dev/null; then
            NV_MIN_LOCK=$((NV_MAX_CLK - 300))
            [ "$NV_MIN_LOCK" -lt 300 ] && NV_MIN_LOCK=300
            sudo nvidia-smi -lgc "$NV_MIN_LOCK,$NV_MAX_CLK" >/dev/null 2>&1 || true
        fi
    fi

    for d in /sys/class/drm/card*/device/power_dpm_force_performance_level; do
        if [ -f "$d" ]; then
            echo high | sudo tee "$d" >/dev/null 2>&1 || true
        fi
    done

    # 6. Strip Hyprland to Absolute Bare-Metal (0 animations, 0 borders, 0 blur, VFR)
    hyprctl eval "hl.config({
        animations = { enabled = false },
        decoration = {
            shadow = { enabled = false },
            blur = { enabled = false },
            rounding = 0,
            active_opacity = 1.0,
            inactive_opacity = 1.0,
            dim_inactive = false,
            dim_special = 0
        },
        general = {
            gaps_in = 0,
            gaps_out = 0,
            border_size = 0,
            allow_tearing = true
        },
        misc = {
            vfr = true,
            disable_hyprland_logo = true,
            disable_splash_rendering = true,
            force_default_wallpaper = 0,
            background_color = 0x000000
        }
    })" >/dev/null 2>&1 || true

    # Force solid opacity across all surfaces
    hyprctl eval "hl.window_rule({ name = 'gamemode-opacity', match = { class = '.*' }, opacity = 1.0 })" >/dev/null 2>&1 || true

    notify-send -u low -a "GameMode" "⚡ GameMode: ESCOVAR BIT ATIVADO" "${CPU_NAME} Performance • Clocks GPU Travados • Wayle OFF • Tearing ON" 2>/dev/null || true
    exit 0
fi
