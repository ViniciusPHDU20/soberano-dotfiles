#!/usr/bin/env bash
# ==============================================================================
# Soberano // Force Kill Active Window & Process
# Bound to: Super + Shift + Q
# ==============================================================================
set -euo pipefail

# 1. Obter PID da janela ativa via Hyprland IPC
active_pid=$(hyprctl activewindow -j 2>/dev/null | jq -r '.pid // empty' 2>/dev/null || true)

# 2. Fallback caso jq falhe ou janela não reporte pid em json
if [[ -z "$active_pid" || "$active_pid" == "null" || "$active_pid" -le 0 ]]; then
    active_pid=$(hyprctl activewindow 2>/dev/null | grep -o 'pid: [0-9]*' | cut -d' ' -f2 || true)
fi

# 3. Finalização forçada
if [[ -n "$active_pid" && "$active_pid" =~ ^[0-9]+$ && "$active_pid" -gt 0 ]]; then
    # Tenta SIGTERM primeiro e escala imediatamente para SIGKILL se travar
    kill "$active_pid" 2>/dev/null || true
    sleep 0.1
    if kill -0 "$active_pid" 2>/dev/null; then
        kill -9 "$active_pid" 2>/dev/null || true
    fi
else
    # Fallback se não houver PID mapeado: fecha via dispatcher do Hyprland
    hyprctl dispatch killactive >/dev/null 2>&1 || true
fi
