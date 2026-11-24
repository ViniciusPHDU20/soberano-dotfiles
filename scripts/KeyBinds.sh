#!/usr/bin/env bash
# ==============================================================================
# Soberano Keybindings HUD
# Bound to: Super + K | Super + H | Super + Shift + K
# ==============================================================================
set -euo pipefail

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
exec python3 "${SCRIPT_DIR}/HyprKeybindsHUD.py"
