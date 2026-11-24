#!/usr/bin/env bash
# ==============================================================================
# Soberano GameMode Extreme (Modo Escovar Bit)
# Universal Low-Latency Engine for AMD / Intel CPU • NVIDIA / AMD Radeon GPU
# Zero-overhead: Barra OFF, Wallpaper OFF, Hyprland 0 animações/bordas,
# Clocks de GPU cravados no teto, CPU Governor Performance, Sysctl Gaming
# Bound to: Super + G | Super + Shift + G | Super + F1
# ==============================================================================
set -euo pipefail

SCRIPTS_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"

# shellcheck source=soberano-hw-lib.sh
. "${SCRIPTS_DIR}/soberano-hw-lib.sh"

STATE_FILE="${SOB_RUNTIME}/hypr_gamemode.state"

CPU_NAME=$(sob_cpu_name)

if [ -f "$STATE_FILE" ]; then
    rm -f "$STATE_FILE"

    # 1. Return to whichever profile was live underneath GameMode.
    #    eco -> per-core floor + eco governor. Anything else -> snapshot ceiling.
    UNDER_PROFILE=$(cat "$SOB_PROFILE_STATE" 2>/dev/null || echo balanced)
    if [ "$UNDER_PROFILE" = "eco" ]; then
        GOV=$(sob_pick_governor eco)
        CEIL=$(sob_floor_snippet)
        EPP_VAL=power
        PP_TARGET=power-saver
    else
        GOV=$(sob_pick_governor balanced)
        CEIL=$(sob_restore_snippet)
        EPP_VAL=balance_performance
        PP_TARGET=balanced
    fi
    sob_root "$(sob_set_boost on)
${CEIL}
$(sob_gov_snippet "$GOV")
$(sob_epp_snippet "$EPP_VAL")"
    sob_set_platform_profile "$PP_TARGET"

    # 2. Reset GPU Clocks & PowerMizer
    if sob_nv_ok; then
        PL=$(sob_nv_pl max); [ -z "$PL" ] && PL=200
        sob_root "nvidia-smi -rgc >/dev/null 2>&1 || true
nvidia-smi -pl ${PL} >/dev/null 2>&1 || true"
        if command -v nvidia-settings >/dev/null 2>&1; then
            nvidia-settings -a '[gpu:0]/GPUPowerMizerMode=0' >/dev/null 2>&1 || true
        fi
    fi

    sob_amd_gpu_ok && sob_root "$(sob_amd_gpu_snippet auto)"

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
    GOV=$(sob_pick_governor compute)
    sob_root "$(sob_set_boost on)
$(sob_ceiling_snippet)
$(sob_gov_snippet "$GOV")
$(sob_epp_snippet performance)"
    sob_set_platform_profile performance

    # 5. Lock GPU Clocks to Boost Clocks
    if sob_nv_ok; then
        if command -v nvidia-settings >/dev/null 2>&1; then
            nvidia-settings -a '[gpu:0]/GPUPowerMizerMode=1' >/dev/null 2>&1 || true
        fi
        NV_MAX_CLK=$(sob_nv_clk max)
        NV_MIN_CLK=$(sob_nv_clk min)
        [ -z "$NV_MIN_CLK" ] && NV_MIN_CLK=300
        if [ -n "$NV_MAX_CLK" ] && [ "$NV_MAX_CLK" -gt 500 ] 2>/dev/null; then
            NV_LOCK_LO=$((NV_MAX_CLK - 300))
            [ "$NV_LOCK_LO" -lt "$NV_MIN_CLK" ] && NV_LOCK_LO=$NV_MIN_CLK
            sob_root "nvidia-smi -lgc ${NV_LOCK_LO},${NV_MAX_CLK} >/dev/null 2>&1 || true"
        fi
    fi

    sob_amd_gpu_ok && sob_root "$(sob_amd_gpu_snippet high)"

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
