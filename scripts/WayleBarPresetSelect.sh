#!/usr/bin/env bash
# ==============================================================================
# Soberano Native Wayle Bar Preset Selector
# Uses 100% native Wayle GTK4 parameters (rem spacing units)
# Bound to: Super + Ctrl + B
# ==============================================================================
set -euo pipefail

WAYLE_CFG="${HOME}/dotfiles/config/wayle/config.toml"
PRESET_STATE="${XDG_CACHE_HOME:-$HOME/.cache}/soberano_wayle_preset.txt"

current_preset=$(cat "$PRESET_STATE" 2>/dev/null || echo "2")

declare -a presets=(
    "1  — Floating Pill Top (Pílula Flutuante)"
    "2  — Block-Prefix Chips (Padrão Nativo Wayle)"
    "3  — Full-Width Top Bar (Barra Reta Colada no Topo)"
    "4  — Floating Bottom Dock (Barra Flutuante Inferior)"
    "5  — Icon-Square Compact (Compacto Quadrado)"
)

options=()
for entry in "${presets[@]}"; do
    key="${entry%% *}"
    if [[ "$key" == "$current_preset" ]]; then
        options+=("👉 $entry")
    else
        options+=("   $entry")
    fi
done

chosen=$(printf '%s\n' "${options[@]}" | fuzzel --dmenu -p "󰕮 Wayle Layout ❯ " -w 52 -l 5 || true)
[ -z "$chosen" ] && exit 0

clean=$(echo "$chosen" | sed 's/^👉 //; s/^   //')
id="${clean%% *}"

mkdir -p "$(dirname "$PRESET_STATE")"
echo "$id" > "$PRESET_STATE"

python3 - "$WAYLE_CFG" "$id" <<'PY'
import sys, re

cfg_path, preset_id = sys.argv[1], sys.argv[2]
with open(cfg_path, "r") as f:
    text = f.read()

presets = {
    "1": {
        "location": '"top"',
        "inset-edge": "0.35",
        "inset-ends": "0.5",
        "padding": "0.3",
        "padding-ends": "0.5",
        "rounding": '"full"',
        "button-variant": '"basic"',
        "button-rounding": '"full"',
        "background-opacity": "85",
        "border-location": '"all"',
    },
    "2": {
        "location": '"top"',
        "inset-edge": "0.35",
        "inset-ends": "0.5",
        "padding": "0.3",
        "padding-ends": "0.5",
        "rounding": '"lg"',
        "button-variant": '"block-prefix"',
        "button-rounding": '"sm"',
        "background-opacity": "88",
        "border-location": '"all"',
    },
    "3": {
        "location": '"top"',
        "inset-edge": "0.0",
        "inset-ends": "0.0",
        "padding": "0.28",
        "padding-ends": "0.45",
        "rounding": '"none"',
        "button-variant": '"block-prefix"',
        "button-rounding": '"sm"',
        "background-opacity": "94",
        "border-location": '"bottom"',
    },
    "4": {
        "location": '"bottom"',
        "inset-edge": "0.35",
        "inset-ends": "0.6",
        "padding": "0.3",
        "padding-ends": "0.5",
        "rounding": '"full"',
        "button-variant": '"basic"',
        "button-rounding": '"full"',
        "background-opacity": "88",
        "border-location": '"all"',
    },
    "5": {
        "location": '"top"',
        "inset-edge": "0.25",
        "inset-ends": "0.4",
        "padding": "0.25",
        "padding-ends": "0.4",
        "rounding": '"md"',
        "button-variant": '"icon-square"',
        "button-rounding": '"sm"',
        "background-opacity": "85",
        "border-location": '"all"',
    },
}

p = presets.get(preset_id, presets["2"])
for k, v in p.items():
    text = re.sub(rf"(?m)^{re.escape(k)}\s*=\s*.*$", f"{k} = {v}", text, count=1)

with open(cfg_path, "w") as f:
    f.write(text)
PY

notify-send -u low -a "Soberano" "󰕮 Wayle Layout" "Preset ${clean} aplicado" 2>/dev/null || true
