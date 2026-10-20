#!/usr/bin/env bash
# ==============================================================================
# Soberano Native Wayle Bar Preset Selector
# Uses 100% native Wayle GTK4 parameters (rem spacing units)
# Bound to: Super + Ctrl + B
# ==============================================================================
set -euo pipefail

WAYLE_CFG="${HOME}/dotfiles/config/wayle/config.toml"
WAYLE_RUNTIME="${HOME}/dotfiles/config/wayle/runtime.toml"
PRESET_STATE="${XDG_CACHE_HOME:-$HOME/.cache}/soberano_wayle_preset.txt"

current_preset=$(cat "$PRESET_STATE" 2>/dev/null || echo "2")

declare -a presets=(
    "1   — Floating Pill Top (Pílula Flutuante Suave)"
    "2   — Block-Prefix Chips (Padrão Nativo Wayle)"
    "3   — Full-Width Top Blade (Lâmina Reta de Ponta a Ponta)"
    "4   — Floating macOS Dock (Dock Flutuante Inferior Centralizado)"
    "5   — Split Dual-Wings HUD (Asas nos Cantos • Centro 100% Livre)"
    "6   — Dynamic Island Capsule (Cápsula Flutuante Central)"
    "7   — Island Floating Clusters (Ilhas 100% Transparentes)"
    "8   — Audiophile Soundstage (Foco CAVA & Player Musical)"
    "9   — Glassmorphism Frost (Vidro Fosco Translúcido 50%)"
    "10  — Stealth Zen Minimalist (Apenas Relógio e Workspaces)"
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

chosen=$(printf '%s\n' "${options[@]}" | fuzzel --dmenu -p "󰕮 Wayle Layout ❯ " -w 66 -l 10 || true)
[ -z "$chosen" ] && exit 0

clean=$(echo "$chosen" | sed 's/^👉 //; s/^   //')
id="${clean%% *}"

mkdir -p "$(dirname "$PRESET_STATE")"
echo "$id" > "$PRESET_STATE"

# Clear any stale runtime overrides so config.toml changes are applied directly
echo "" > "$WAYLE_RUNTIME"

python3 - "$WAYLE_CFG" "$id" <<'PY'
import sys, re

cfg_path, preset_id = sys.argv[1], sys.argv[2]
with open(cfg_path, "r") as f:
    cfg_text = f.read()

# Layout definitions
L_STANDARD = """[[bar.layout]]
monitor = "*"
show = true
left = ["dashboard", "hyprland-workspaces", "window-title"]
center = ["clock", "media", "cava"]
right = [
    { name = "hardware", modules = ["cpu", "ram", "storage"] },
    "weather",
    "volume",
    "microphone",
    "network",
    "systray",
    "notifications"
]"""

L_DOCK = """[[bar.layout]]
monitor = "*"
show = true
left = []
center = ["dashboard", "hyprland-workspaces", "window-title", "media", "cava", "volume", "clock", "notifications"]
right = []"""

L_WINGS = """[[bar.layout]]
monitor = "*"
show = true
left = ["dashboard", "hyprland-workspaces", "window-title"]
center = []
right = [
    { name = "hardware", modules = ["cpu", "ram", "storage"] },
    "weather",
    "volume",
    "clock",
    "notifications"
]"""

L_ISLAND = """[[bar.layout]]
monitor = "*"
show = true
left = []
center = ["dashboard", "hyprland-workspaces", "clock", "media", "volume"]
right = []"""

L_AUDIOPHILE = """[[bar.layout]]
monitor = "*"
show = true
left = ["dashboard", "hyprland-workspaces"]
center = ["media", "cava"]
right = ["volume", "clock", "notifications"]"""

L_ZEN = """[[bar.layout]]
monitor = "*"
show = true
left = []
center = ["hyprland-workspaces", "clock"]
right = []"""

presets = {
    # 1. Floating Pill Top (Pílula Flutuante)
    "1": {
        "bar": {
            "location": '"top"',
            "scale": "0.95",
            "inset-edge": "0.35",
            "inset-ends": "0.5",
            "padding": "0.3",
            "padding-ends": "0.5",
            "module-gap": "0.4",
            "bg": '"bg-surface"',
            "background-opacity": "85",
            "rounding": '"full"',
            "border-location": '"all"',
            "border-width": "1",
            "border-color": '"border-subtle"',
            "shadow": '"none"',
            "button-variant": '"basic"',
            "button-rounding": '"full"',
            "button-border-location": '"all"',
            "button-border-width": "1",
            "button-group-border-location": '"none"',
            "button-group-rounding": '"sm"',
        },
        "layout": L_STANDARD,
    },
    # 2. Block-Prefix Chips (Padrão Wayle)
    "2": {
        "bar": {
            "location": '"top"',
            "scale": "0.95",
            "inset-edge": "0.35",
            "inset-ends": "0.5",
            "padding": "0.3",
            "padding-ends": "0.5",
            "module-gap": "0.4",
            "bg": '"bg-surface"',
            "background-opacity": "88",
            "rounding": '"lg"',
            "border-location": '"all"',
            "border-width": "1",
            "border-color": '"border-subtle"',
            "shadow": '"none"',
            "button-variant": '"block-prefix"',
            "button-rounding": '"sm"',
            "button-border-location": '"all"',
            "button-border-width": "1",
            "button-group-border-location": '"none"',
            "button-group-rounding": '"sm"',
        },
        "layout": L_STANDARD,
    },
    # 3. Full-Width Top Blade
    "3": {
        "bar": {
            "location": '"top"',
            "scale": "0.95",
            "inset-edge": "0.0",
            "inset-ends": "0.0",
            "padding": "0.28",
            "padding-ends": "0.45",
            "module-gap": "0.4",
            "bg": '"bg-surface"',
            "background-opacity": "95",
            "rounding": '"none"',
            "border-location": '"bottom"',
            "border-width": "2",
            "border-color": '"border-accent"',
            "shadow": '"none"',
            "button-variant": '"icon-square"',
            "button-rounding": '"none"',
            "button-border-location": '"all"',
            "button-border-width": "1",
            "button-group-border-location": '"none"',
            "button-group-rounding": '"none"',
        },
        "layout": L_STANDARD,
    },
    # 4. Floating macOS Dock (Dock Inferior)
    "4": {
        "bar": {
            "location": '"bottom"',
            "scale": "0.98",
            "inset-edge": "0.55",
            "inset-ends": "1.8",
            "padding": "0.35",
            "padding-ends": "0.7",
            "module-gap": "0.45",
            "bg": '"bg-surface"',
            "background-opacity": "88",
            "rounding": '"full"',
            "border-location": '"all"',
            "border-width": "1",
            "border-color": '"border-accent"',
            "shadow": '"drop"',
            "button-variant": '"basic"',
            "button-rounding": '"full"',
            "button-border-location": '"all"',
            "button-border-width": "1",
            "button-group-border-location": '"none"',
            "button-group-rounding": '"full"',
        },
        "layout": L_DOCK,
    },
    # 5. Split Dual-Wings HUD (Asas nos Cantos • Centro 100% Livre)
    "5": {
        "bar": {
            "location": '"top"',
            "scale": "0.95",
            "inset-edge": "0.35",
            "inset-ends": "0.5",
            "padding": "0.25",
            "padding-ends": "0.4",
            "module-gap": "0.4",
            "bg": '"transparent"',
            "background-opacity": "0",
            "rounding": '"none"',
            "border-location": '"none"',
            "border-width": "0",
            "shadow": '"none"',
            "button-variant": '"block-prefix"',
            "button-rounding": '"lg"',
            "button-border-location": '"none"',
            "button-border-width": "0",
            "button-group-background": '"bg-elevated"',
            "button-group-opacity": "92",
            "button-group-border-location": '"all"',
            "button-group-border-color": '"border-accent"',
            "button-group-rounding": '"lg"',
        },
        "layout": L_WINGS,
    },
    # 6. Dynamic Island Capsule (Cápsula Flutuante Central)
    "6": {
        "bar": {
            "location": '"top"',
            "scale": "1.0",
            "inset-edge": "0.5",
            "inset-ends": "2.2",
            "padding": "0.32",
            "padding-ends": "0.6",
            "module-gap": "0.35",
            "bg": '"bg-surface"',
            "background-opacity": "94",
            "rounding": '"full"',
            "border-location": '"all"',
            "border-width": "1",
            "border-color": '"border-accent"',
            "shadow": '"floating"',
            "button-variant": '"basic"',
            "button-rounding": '"full"',
            "button-border-location": '"none"',
            "button-border-width": "0",
            "button-group-border-location": '"none"',
            "button-group-rounding": '"full"',
        },
        "layout": L_ISLAND,
    },
    # 7. Island Floating Clusters (Ilhas 100% Transparentes)
    "7": {
        "bar": {
            "location": '"top"',
            "scale": "0.95",
            "inset-edge": "0.35",
            "inset-ends": "0.45",
            "padding": "0.2",
            "padding-ends": "0.3",
            "module-gap": "0.6",
            "bg": '"transparent"',
            "background-opacity": "0",
            "rounding": '"none"',
            "border-location": '"none"',
            "border-width": "0",
            "shadow": '"none"',
            "button-variant": '"block-prefix"',
            "button-rounding": '"full"',
            "button-border-location": '"none"',
            "button-border-width": "0",
            "button-group-background": '"bg-elevated"',
            "button-group-opacity": "92",
            "button-group-border-location": '"all"',
            "button-group-border-color": '"border-accent"',
            "button-group-rounding": '"full"',
        },
        "layout": L_STANDARD,
    },
    # 8. Audiophile Soundstage (Foco CAVA & Player Musical)
    "8": {
        "bar": {
            "location": '"top"',
            "scale": "0.96",
            "inset-edge": "0.35",
            "inset-ends": "0.6",
            "padding": "0.3",
            "padding-ends": "0.5",
            "module-gap": "0.4",
            "bg": '"bg-surface"',
            "background-opacity": "90",
            "rounding": '"xl"',
            "border-location": '"all"',
            "border-width": "1",
            "border-color": '"border-accent"',
            "shadow": '"drop"',
            "button-variant": '"basic"',
            "button-rounding": '"lg"',
            "button-border-location": '"all"',
            "button-border-width": "1",
            "button-group-border-location": '"none"',
            "button-group-rounding": '"lg"',
        },
        "layout": L_AUDIOPHILE,
    },
    # 9. Glassmorphism Frost (Vidro Fosco Translúcido 50%)
    "9": {
        "bar": {
            "location": '"top"',
            "scale": "0.95",
            "inset-edge": "0.35",
            "inset-ends": "0.4",
            "padding": "0.3",
            "padding-ends": "0.5",
            "module-gap": "0.4",
            "bg": '"bg-surface"',
            "background-opacity": "50",
            "rounding": '"lg"',
            "border-location": '"all"',
            "border-width": "1",
            "border-color": '"border-accent"',
            "shadow": '"drop"',
            "button-variant": '"block-prefix"',
            "button-rounding": '"md"',
            "button-border-location": '"all"',
            "button-border-width": "1",
            "button-group-border-location": '"none"',
            "button-group-rounding": '"md"',
        },
        "layout": L_STANDARD,
    },
    # 10. Stealth Zen Minimalist (Apenas Relógio e Workspaces)
    "10": {
        "bar": {
            "location": '"top"',
            "scale": "0.85",
            "inset-edge": "0.4",
            "inset-ends": "3.5",
            "padding": "0.18",
            "padding-ends": "0.4",
            "module-gap": "0.3",
            "bg": '"bg-surface"',
            "background-opacity": "92",
            "rounding": '"full"',
            "border-location": '"all"',
            "border-width": "1",
            "border-color": '"border-subtle"',
            "shadow": '"none"',
            "button-variant": '"basic"',
            "button-rounding": '"full"',
            "button-border-location": '"none"',
            "button-border-width": "0",
            "button-group-border-location": '"none"',
            "button-group-rounding": '"full"',
        },
        "layout": L_ZEN,
    },
}

p = presets.get(preset_id, presets["2"])
p_bar = p["bar"]
p_layout = p["layout"]

lines = cfg_text.splitlines()
in_bar = False
found_keys = set()
new_lines = []

for line in lines:
    if line.strip() == "[bar]":
        in_bar = True
        new_lines.append(line)
        continue
    if in_bar and (line.strip().startswith("[") or line.strip().startswith("[[")):
        for k, v in p_bar.items():
            if k not in found_keys:
                new_lines.append(f"{k} = {v}")
        in_bar = False
    if in_bar:
        matched = False
        for k, v in p_bar.items():
            if line.strip().startswith(f"{k} ") or line.strip().startswith(f"{k}="):
                new_lines.append(f"{k} = {v}")
                found_keys.add(k)
                matched = True
                break
        if not matched:
            new_lines.append(line)
    else:
        new_lines.append(line)

new_cfg = "\n".join(new_lines)

# Replace the [[bar.layout]] block
pattern = r"(?s)\[\[bar\.layout\]\].*?(?=\n\[styling\])"
new_cfg = re.sub(pattern, p_layout.strip(), new_cfg)

with open(cfg_path, "w") as f:
    f.write(new_cfg + "\n")
PY

# Instant reload of Wayle service (takes ~150ms)
systemctl --user restart wayle.service >/dev/null 2>&1 || true

notify-send -u low -a "Soberano" "󰕮 Wayle Layout" "Preset ${clean} aplicado" 2>/dev/null || true
