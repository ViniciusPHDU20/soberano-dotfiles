#!/usr/bin/env bash
# ==============================================================================
# KeyBinds.sh - Visual Glass HUD for JaKooLit Keybindings (WebKitGTK / Tauri Engine)
# Bound to: Super + Shift + K (and Super + K / Super + H / Super + Shift + ?)
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec python3 "${SCRIPT_DIR}/HyprKeybindsHUD.py"
