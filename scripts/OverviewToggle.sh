#!/usr/bin/env bash
# ==============================================================================
# Soberano Workspace Overview Toggle (Quickshell)
# Bound to: Super + A
# ==============================================================================
set -euo pipefail

QS_OVERVIEW_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/overview"
QS_LOG_RULE="qt.qpa.wayland.textinput.warning=false"

if command -v qs >/dev/null 2>&1 && [ -d "$QS_OVERVIEW_DIR" ]; then
    if pgrep -x qs >/dev/null 2>&1; then
        qs ipc -c overview call overview toggle >/dev/null 2>&1 && exit 0
    fi
    qs --log-rules "$QS_LOG_RULE" -c overview >/dev/null 2>&1 &
    sleep 0.5
    qs ipc -c overview call overview toggle >/dev/null 2>&1 && exit 0
fi

notify-send -u low -a "Soberano" "Overview" "Quickshell overview indisponível" 2>/dev/null || true
