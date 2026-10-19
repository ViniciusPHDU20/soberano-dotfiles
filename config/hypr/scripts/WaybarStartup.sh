#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026) — Wayle Lifecycle Manager
#  Replaces legacy WaybarStartup.sh with native Wayle service orchestration
# ==================================================
set -u

SCRIPTSDIR="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/scripts"

# Ensure no legacy waybar or swaync instances conflict with Wayle
pkill -x waybar 2>/dev/null || true
pkill -x '.waybar-wrapped' 2>/dev/null || true
pkill -x swaync 2>/dev/null || true

# Sync active layout + style into Wayle config.toml & index.scss
if [[ -x "${SCRIPTSDIR}/WayleSyncConfig.py" ]]; then
    python3 "${SCRIPTSDIR}/WayleSyncConfig.py" >/dev/null 2>&1 || true
fi

case "${1:-}" in
    --restart)
        systemctl --user restart wayle.service >/dev/null 2>&1 || {
            pkill -x wayle 2>/dev/null || true
            nohup wayle shell >/dev/null 2>&1 &
        }
        ;;
    --stop)
        systemctl --user stop wayle.service >/dev/null 2>&1 || pkill -x wayle 2>/dev/null || true
        ;;
    *)
        if ! systemctl --user is-active --quiet wayle.service 2>/dev/null; then
            systemctl --user start wayle.service >/dev/null 2>&1 || {
                pgrep -x wayle >/dev/null 2>&1 || nohup wayle shell >/dev/null 2>&1 &
            }
        fi
        ;;
esac
