#!/usr/bin/env bash
# ==============================================================================
# KeybindsHelp.sh - Toggle HUD Keybindings Cheat-Sheet
# Bound to: Super + Shift + ? / Super + H
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec python3 "${SCRIPT_DIR}/HyprKeybindsCheatSheet.py"
