#!/usr/bin/env bash
# ==============================================================================
# Soberano GameMode Extreme (Modo Escovar Bit)
# Ryzen 9 9950X (16C/32T) + NVIDIA GeForce RTX 3060 Ti
# Zero-overhead: Barra OFF, Wallpaper OFF, Hyprland 0 animações/bordas,
# Clocks de GPU cravados no teto, CPU Governor Performance, Sysctl Gaming
# Bound to: Super + G | Super + Shift + G | Super + F1
# ==============================================================================
set -euo pipefail

SCRIPTS_DIR="${HOME}/dotfiles/scripts"
STATE_FILE="/tmp/hypr_gamemode.state"

if [ -f "$STATE_FILE" ]; then
    rm -f "$STATE_FILE"

    # 1. Reset CPU Governor & EPP (Ryzen 9 9950X)
    sudo sh -c 'for g in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do echo powersave > "$g"; done' 2>/dev/null || true
    sudo sh -c 'for e in /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference; do echo balance_performance > "$e"; done' 2>/dev/null || true
    if command -v powerprofilesctl >/dev/null 2>&1; then
        powerprofilesctl set balanced >/dev/null 2>&1 || true
    fi

    # 2. Reset GPU Clocks & PowerMizer (RTX 3060 Ti)
    sudo nvidia-smi -rgc >/dev/null 2>&1 || true
    if command -v nvidia-settings >/dev/null 2>&1; then
        nvidia-settings -a '[gpu:0]/GPUPowerMizerMode=0' >/dev/null 2>&1 || true
    fi

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

    notify-send -u normal -a "GameMode" "🚀 GameMode: DESATIVADO" "CPU/GPU Automático • Wayle & Wallpaper Restaurados • Efeitos ON" 2>/dev/null || true
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

    # 4. Maximize CPU Performance on all 32 threads (Ryzen 9 9950X)
    sudo sh -c 'for g in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do echo performance > "$g"; done' 2>/dev/null || true
    sudo sh -c 'for e in /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference; do echo performance > "$e"; done' 2>/dev/null || true
    if command -v powerprofilesctl >/dev/null 2>&1; then
        powerprofilesctl set performance >/dev/null 2>&1 || true
    fi

    # 5. Lock GPU Clocks to Boost Clocks (Prevents clock drops in menus/transitions)
    if command -v nvidia-settings >/dev/null 2>&1; then
        nvidia-settings -a '[gpu:0]/GPUPowerMizerMode=1' >/dev/null 2>&1 || true
    fi
    sudo nvidia-smi -lgc 1665,1950 >/dev/null 2>&1 || true

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

    notify-send -u low -a "GameMode" "⚡ GameMode: ESCOVAR BIT ATIVADO" "Ryzen 9 Performance • RTX Clocks Travados • Wayle OFF • Tearing ON" 2>/dev/null || true
    exit 0
fi
