#!/usr/bin/env bash
# ==============================================================================
# WayleLayoutSelector - Interactive Bar Layout & Geometry Selector for Wayle
# Port of JaKooLit WaybarLayout system to native Wayle architecture
# Bound to: Super + Ctrl + B
# ==============================================================================
set -euo pipefail

LAYOUTS_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/wayle/layouts"
CONFIG_TOML="${XDG_CONFIG_HOME:-$HOME/.config}/wayle/config.toml"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/wayle"
ACTIVE_LAYOUT_FILE="${STATE_DIR}/active_layout"

mkdir -p "$STATE_DIR"

if [ ! -d "$LAYOUTS_DIR" ]; then
    notify-send -u critical "Wayle Error" "Diretório de layouts não encontrado: $LAYOUTS_DIR"
    exit 1
fi

apply_layout() {
    local layout_name="$1"
    local layout_file=""

    # Find matching layout file
    for f in "$LAYOUTS_DIR"/*.toml; do
        bname=$(basename "$f" .toml)
        clean_bname=$(echo "$bname" | sed 's/^[0-9]*\.[[:space:]]*//')
        if [ "$clean_bname" = "$layout_name" ] || [ "$bname" = "$layout_name" ]; then
            layout_file="$f"
            break
        fi
    done

    if [ -z "$layout_file" ] || [ ! -f "$layout_file" ]; then
        notify-send -u critical "Wayle Error" "Arquivo de layout não encontrado: $layout_name"
        return 1
    fi

    # Merge layout into config.toml
    python3 -c '
import sys, re

layout_path = sys.argv[1]
config_path = sys.argv[2]

with open(layout_path, "r") as f:
    layout_content = f.read().strip()

with open(config_path, "r") as f:
    config_content = f.read()

# Replace the [bar] and [[bar.layout]] blocks in config_content
# Match from [bar] up to [styling]
pattern = r"\[bar\].*?(?=\n\[styling\])"
replacement = layout_content + "\n"

new_config, count = re.subn(pattern, replacement, config_content, flags=re.DOTALL)
if count > 0:
    with open(config_path, "w") as f:
        f.write(new_config)
else:
    print("Warning: regex pattern did not match, fallback needed", file=sys.stderr)
' "$layout_file" "$CONFIG_TOML"

    # Fast restart of Wayle service (<120ms on Zen 5)
    systemctl --user restart wayle.service

    echo "$layout_name" > "$ACTIVE_LAYOUT_FILE"
    notify-send -u low -a "Wayle" "󰕰 Layout da Barra Aplicado" "Geometria: <b>${layout_name}</b>" 2>/dev/null || true
}

# Direct CLI execution
if [ "${1:-}" != "" ]; then
    apply_layout "$1"
    exit 0
fi

# Determine current layout
current_layout=""
if [ -f "$ACTIVE_LAYOUT_FILE" ]; then
    current_layout=$(cat "$ACTIVE_LAYOUT_FILE")
fi

# Build options list
options=()
for f in "$LAYOUTS_DIR"/*.toml; do
    bname=$(basename "$f" .toml)
    clean_name=$(echo "$bname" | sed 's/^[0-9]*\.[[:space:]]*//')
    if [ "$clean_name" = "$current_layout" ]; then
        options+=("👉  $clean_name (Ativo)")
    else
        options+=("    $clean_name")
    fi
done

# Launch Rofi
chosen=$(printf '%s\n' "${options[@]}" | rofi -dmenu -i -p "󰕰 Layout da Barra (Super+Ctrl+B)" || true)

if [ -z "$chosen" ]; then
    exit 0
fi

clean_choice=$(echo "$chosen" | sed 's/^[[:space:]]*//; s/^👉[[:space:]]*//; s/[[:space:]]*(Ativo)//; s/[[:space:]]*$//')
apply_layout "$clean_choice"
