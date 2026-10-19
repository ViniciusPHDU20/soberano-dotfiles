#!/usr/bin/env bash
# ==============================================================================
# Soberano GameMode Extreme — Ryzen 9 9950X + NVIDIA RTX 3060 Ti
# Bound to: Super + G | Super + Shift + G | Super + F1
# ==============================================================================
set -euo pipefail

SCRIPTS_DIR="${HOME}/dotfiles/scripts"
STATE_FILE="/tmp/hypr_gamemode.state"

if [ -f "$STATE_FILE" ]; then
    rm -f "$STATE_FILE"

    if command -v powerprofilesctl >/dev/null 2>&1; then
        powerprofilesctl set balanced >/dev/null 2>&1 || true
    fi
    if command -v nvidia-settings >/dev/null 2>&1; then
        nvidia-settings -a '[gpu:0]/GPUPowerMizerMode=0' >/dev/null 2>&1 || true
    fi

    hyprctl reload >/dev/null 2>&1 || true
    "${SCRIPTS_DIR}/WallpaperSelect.sh" --restore >/dev/null 2>&1 &

    notify-send -u normal -a "GameMode" "🚀 GameMode: DESATIVADO" "CPU Balanced • GPU Auto • Efeitos e Wallpaper Restaurados" 2>/dev/null || true
    exit 0
else
    touch "$STATE_FILE"

    if command -v powerprofilesctl >/dev/null 2>&1; then
        powerprofilesctl set performance >/dev/null 2>&1 || true
    fi
    if command -v nvidia-settings >/dev/null 2>&1; then
        nvidia-settings -a '[gpu:0]/GPUPowerMizerMode=1' >/dev/null 2>&1 || true
    fi

    pkill -x awww-daemon 2>/dev/null || true

    hyprctl eval "hl.config({
        animations = { enabled = false },
        decoration = {
            shadow = { enabled = false },
            blur = { enabled = false },
            rounding = 0
        },
        general = {
            gaps_in = 0,
            gaps_out = 0,
            border_size = 1,
            allow_tearing = true
        },
        misc = {
            vfr = false
        }
    })" >/dev/null 2>&1 || true

    hyprctl eval "hl.window_rule({ name = 'gamemode-opacity', match = { class = '.*' }, opacity = 1.0 })" >/dev/null 2>&1 || true

    notify-send -u low -a "GameMode" "⚡ GameMode: ATIVADO" "CPU Performance • GPU Max Clock • Tearing ON • Efeitos OFF" 2>/dev/null || true
    exit 0
fi
