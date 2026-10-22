#!/usr/bin/env bash
# ==============================================================================
# Soberano Native Wayle Bar Preset Selector & Dynamic Hyprland Gaps Engine
# Synchronizes bar geometry with Hyprland window gaps, borders, and rounding
# Bound to: Super + Ctrl + B
# ==============================================================================
set -euo pipefail

WAYLE_CFG="${HOME}/dotfiles/config/wayle/config.toml"
WAYLE_RUNTIME="${HOME}/dotfiles/config/wayle/runtime.toml"
PRESET_STATE="${XDG_CACHE_HOME:-$HOME/.cache}/soberano_wayle_preset.txt"

current_preset=$(cat "$PRESET_STATE" 2>/dev/null || echo "2")

declare -a presets=(
    "1   — Floating Pill Top (Pílula Flutuante Suave • Gaps 10/8 • Rounding 12px)"
    "2   — Block-Prefix Chips (Padrão Nativo Wayle • Gaps 8/8 • Rounding 10px)"
    "3   — Full-Width Top Blade (Lâmina Cyberpunk • Gaps 2px • Rounding 0px)"
    "4   — Floating macOS Dock (Dock Inferior Flutuante • Gaps Bottom 14px • Rounding 14px)"
    "5   — Split Dual-Wings HUD (Asas nos Cantos • Centro 100% Livre • Gaps 12px)"
    "6   — Dynamic Island Capsule (Cápsula Central • Gaps Top 14px • Rounding 14px)"
    "7   — Island Floating Clusters (Ilhas Transparentes • Gaps 10px • Rounding 16px)"
    "8   — Audiophile Soundstage (Foco CAVA & Player Musical • Gaps 10px • Rounding 12px)"
    "9   — Glassmorphism Frost (Vidro Fosco 50% • Gaps 8px • Rounding 10px)"
    "10  — Stealth Zen Minimalist (Workspaces • App Ativo • Bandeja • Relógio • Gaps 2px)"
    "11  — Lateral Vertical Blade (Barra Vertical Esquerda • Espaço 100% Livre • Gaps 8px)"
    "12  — ROG Telemetry Cyber-HUD (Aero Cyber-Militar • Telemetria Viva • Gaps 4px • 0px Sharp)"
    "13  — Dynamic Top Notch (Cápsula Flutuante no Topo • Rounding 14px • Gaps 10px)"
    "14  — Swiss Editorial Typographic (Design Editorial Suíço Inferior • Gaps 6px • Rounding 6px)"
    "15  — Retro-Terminal Synth (Mainframe Monospace • Blocos Retro • Gaps 6px • Rounding 2px)"
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

if [[ $# -ge 1 && -n "$1" ]]; then
    chosen="$1"
else
    chosen=$(printf '%s\n' "${options[@]}" | fuzzel --dmenu -p "󰕮 Wayle & Hyprland Layout ❯ " -w 84 -l 15 || true)
fi
[ -z "$chosen" ] && exit 0

clean=$(echo "$chosen" | sed 's/^👉 //; s/^   //')
id="${clean%% *}"

mkdir -p "$(dirname "$PRESET_STATE")"
echo "$id" > "$PRESET_STATE"

# Clear any stale runtime overrides so config.toml changes are applied directly
echo "" > "$WAYLE_RUNTIME"

python3 - "$WAYLE_CFG" "$id" <<'PY'
import sys, re, os, subprocess

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
    { name = "hardware", modules = ["custom-cpu", "custom-ram", "custom-storage"] },
    "weather",
    "volume",
    "microphone",
    "network",
    "custom-updates",
    "systray",
    "notifications"
]"""

L_DOCK = """[[bar.layout]]
monitor = "*"
show = true
left = []
center = ["dashboard", "hyprland-workspaces", "window-title", "media", "cava", "volume", "custom-updates", "clock", "notifications"]
right = []"""

L_WINGS = """[[bar.layout]]
monitor = "*"
show = true
left = ["dashboard", "hyprland-workspaces", "window-title"]
center = []
right = [
    { name = "hardware", modules = ["custom-cpu", "custom-ram", "custom-storage"] },
    "weather",
    "volume",
    "custom-updates",
    "clock",
    "notifications"
]"""

L_ISLAND = """[[bar.layout]]
monitor = "*"
show = true
left = []
center = ["dashboard", "hyprland-workspaces", "clock", "media", "custom-updates", "volume"]
right = []"""

L_AUDIOPHILE = """[[bar.layout]]
monitor = "*"
show = true
left = ["dashboard", "hyprland-workspaces"]
center = ["media", "cava"]
right = ["volume", "custom-updates", "clock", "notifications"]"""

L_ZEN = """[[bar.layout]]
monitor = "*"
show = true
left = []
center = ["hyprland-workspaces", "window-title", "custom-updates", "systray", "clock"]
right = []"""

L_VERTICAL_LEFT = """[[bar.layout]]
monitor = "*"
show = true
left = ["dashboard", "hyprland-workspaces"]
center = ["clock", "media"]
right = ["volume", "custom-updates", "systray", "notifications"]"""

L_TELEMETRY = """[[bar.layout]]
monitor = "*"
show = true
left = ["dashboard", "hyprland-workspaces", { name = "telemetry", modules = ["custom-cpu", "custom-ram", "custom-storage"] }]
center = ["window-title"]
right = ["cava", "volume", "microphone", "network", "clock", "notifications"]"""

L_NOTCH = """[[bar.layout]]
monitor = "*"
show = true
left = []
center = ["dashboard", "hyprland-workspaces", "clock", "media", "volume", "notifications"]
right = []"""

L_SWISS = """[[bar.layout]]
monitor = "*"
show = true
left = ["dashboard", "window-title"]
center = ["hyprland-workspaces"]
right = ["weather", "volume", "custom-updates", "clock", "notifications"]"""

L_RETRO = """[[bar.layout]]
monitor = "*"
show = true
left = ["dashboard", "hyprland-workspaces", "window-title"]
center = ["clock", "cava"]
right = [{ name = "sys", modules = ["custom-cpu", "custom-ram"] }, "volume", "network", "custom-updates", "notifications"]"""

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
        "hypr": {
            "gaps_in": 4,
            "gaps_out": "{ top = 10, right = 8, bottom = 8, left = 8 }",
            "rounding": 12,
            "border_size": 2,
        },
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
        "hypr": {
            "gaps_in": 3,
            "gaps_out": "{ top = 8, right = 8, bottom = 8, left = 8 }",
            "rounding": 10,
            "border_size": 2,
        },
    },
    # 3. Full-Width Top Blade (Cyberpunk)
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
        "hypr": {
            "gaps_in": 2,
            "gaps_out": "{ top = 2, right = 4, bottom = 4, left = 4 }",
            "rounding": 0,
            "border_size": 1,
        },
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
        "hypr": {
            "gaps_in": 4,
            "gaps_out": "{ top = 4, right = 8, bottom = 14, left = 8 }",
            "rounding": 14,
            "border_size": 2,
        },
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
        "hypr": {
            "gaps_in": 5,
            "gaps_out": "{ top = 12, right = 10, bottom = 10, left = 10 }",
            "rounding": 12,
            "border_size": 2,
        },
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
        "hypr": {
            "gaps_in": 4,
            "gaps_out": "{ top = 14, right = 8, bottom = 8, left = 8 }",
            "rounding": 14,
            "border_size": 2,
        },
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
        "hypr": {
            "gaps_in": 4,
            "gaps_out": "{ top = 10, right = 10, bottom = 10, left = 10 }",
            "rounding": 16,
            "border_size": 2,
        },
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
        "hypr": {
            "gaps_in": 4,
            "gaps_out": "{ top = 10, right = 8, bottom = 8, left = 8 }",
            "rounding": 12,
            "border_size": 2,
        },
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
        "hypr": {
            "gaps_in": 4,
            "gaps_out": "{ top = 8, right = 8, bottom = 8, left = 8 }",
            "rounding": 10,
            "border_size": 2,
        },
    },
    # 10. Stealth Zen Minimalist (Workspaces + App em Uso + Relógio)
    "10": {
        "bar": {
            "location": '"top"',
            "scale": "0.88",
            "inset-edge": "0.2",
            "inset-ends": "0.8",
            "padding": "0.22",
            "padding-ends": "0.45",
            "module-gap": "0.35",
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
        "hypr": {
            "gaps_in": 1,
            "gaps_out": "{ top = 2, right = 2, bottom = 2, left = 2 }",
            "rounding": 4,
            "border_size": 1,
        },
    },
    # 11. Lateral Vertical Blade (Barra Vertical Esquerda • Espaço 100% Livre)
    "11": {
        "bar": {
            "location": '"left"',
            "scale": "0.94",
            "inset-edge": "0.35",
            "inset-ends": "0.5",
            "padding": "0.3",
            "padding-ends": "0.4",
            "module-gap": "0.4",
            "bg": '"bg-surface"',
            "background-opacity": "92",
            "rounding": '"lg"',
            "border-location": '"all"',
            "border-width": "1",
            "border-color": '"border-subtle"',
            "shadow": '"none"',
            "button-variant": '"icon-square"',
            "button-rounding": '"md"',
            "button-border-location": '"all"',
            "button-border-width": "1",
            "button-group-border-location": '"none"',
            "button-group-rounding": '"md"',
        },
        "layout": L_VERTICAL_LEFT,
        "hypr": {
            "gaps_in": 4,
            "gaps_out": "{ top = 8, right = 8, bottom = 8, left = 8 }",
            "rounding": 10,
            "border_size": 2,
        },
    },
    # 12. ROG Telemetry Cyber-HUD (Aero Cyber-Militar • Telemetria Viva • 0px Sharp)
    "12": {
        "bar": {
            "location": '"top"',
            "scale": "0.98",
            "inset-edge": "0.0",
            "inset-ends": "0.0",
            "padding": "0.22",
            "padding-ends": "0.5",
            "module-gap": "0.3",
            "bg": '"bg-surface"',
            "background-opacity": "98",
            "rounding": '"none"',
            "border-location": '"bottom"',
            "border-width": "2",
            "border-color": '"border-accent"',
            "shadow": '"none"',
            "button-variant": '"icon-square"',
            "button-rounding": '"none"',
            "button-border-location": '"all"',
            "button-border-width": "1",
            "button-group-border-location": '"all"',
            "button-group-border-width": "1",
            "button-group-rounding": '"none"',
        },
        "layout": L_TELEMETRY,
        "hypr": {
            "gaps_in": 2,
            "gaps_out": "{ top = 4, right = 4, bottom = 4, left = 4 }",
            "rounding": 0,
            "border_size": 2,
        },
    },
    # 13. Dynamic Top Notch (Cápsula Flutuante no Topo • Rounding 14px)
    "13": {
        "bar": {
            "location": '"top"',
            "scale": "0.96",
            "inset-edge": "0.0",
            "inset-ends": "1.8",
            "padding": "0.32",
            "padding-ends": "0.6",
            "module-gap": "0.4",
            "bg": '"bg-surface"',
            "background-opacity": "95",
            "rounding": '"lg"',
            "border-location": '"all"',
            "border-width": "1",
            "border-color": '"border-accent"',
            "shadow": '"drop"',
            "button-variant": '"basic"',
            "button-rounding": '"full"',
            "button-border-location": '"none"',
            "button-border-width": "0",
            "button-group-border-location": '"none"',
            "button-group-rounding": '"full"',
        },
        "layout": L_NOTCH,
        "hypr": {
            "gaps_in": 4,
            "gaps_out": "{ top = 10, right = 8, bottom = 8, left = 8 }",
            "rounding": 14,
            "border_size": 2,
        },
    },
    # 14. Swiss Editorial Typographic (Design Editorial Suíço Inferior • Gaps 6px)
    "14": {
        "bar": {
            "location": '"bottom"',
            "scale": "0.90",
            "inset-edge": "0.0",
            "inset-ends": "0.0",
            "padding": "0.18",
            "padding-ends": "0.8",
            "module-gap": "0.6",
            "bg": '"bg-surface"',
            "background-opacity": "95",
            "rounding": '"none"',
            "border-location": '"top"',
            "border-width": "1",
            "border-color": '"border-subtle"',
            "shadow": '"none"',
            "button-variant": '"basic"',
            "button-rounding": '"none"',
            "button-border-location": '"none"',
            "button-border-width": "0",
            "button-group-border-location": '"none"',
            "button-group-rounding": '"none"',
        },
        "layout": L_SWISS,
        "hypr": {
            "gaps_in": 3,
            "gaps_out": "{ top = 6, right = 6, bottom = 8, left = 6 }",
            "rounding": 6,
            "border_size": 1,
        },
    },
    # 15. Retro-Terminal Synth (Mainframe Monospace • Blocos Retro)
    "15": {
        "bar": {
            "location": '"top"',
            "scale": "0.94",
            "inset-edge": "0.25",
            "inset-ends": "0.35",
            "padding": "0.25",
            "padding-ends": "0.5",
            "module-gap": "0.5",
            "bg": '"bg-surface"',
            "background-opacity": "96",
            "rounding": '"sm"',
            "border-location": '"all"',
            "border-width": "2",
            "border-color": '"border-accent"',
            "shadow": '"drop"',
            "button-variant": '"block-prefix"',
            "button-rounding": '"sm"',
            "button-border-location": '"all"',
            "button-border-width": "1",
            "button-group-border-location": '"all"',
            "button-group-border-width": "1",
            "button-group-rounding": '"sm"',
        },
        "layout": L_RETRO,
        "hypr": {
            "gaps_in": 3,
            "gaps_out": "{ top = 8, right = 6, bottom = 6, left = 6 }",
            "rounding": 2,
            "border_size": 2,
        },
    },
}

p = presets.get(preset_id, presets["2"])
p_bar = p["bar"]
p_layout = p["layout"]
p_hypr = p["hypr"]

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

# Dynamic Hyprland Gaps & Rounding sync
gaps_lua_path = os.path.expanduser("~/dotfiles/config/hypr/config/gaps_dynamic.lua")
gaps_content = f"""-- Dynamic Hyprland Gaps (Auto-adapted to Wayle Preset {preset_id})
DYNAMIC_GAPS_IN = {p_hypr['gaps_in']}
DYNAMIC_GAPS_OUT = {p_hypr['gaps_out']}
DYNAMIC_ROUNDING = {p_hypr['rounding']}
DYNAMIC_BORDER_SIZE = {p_hypr['border_size']}
"""
with open(gaps_lua_path, "w") as f:
    f.write(gaps_content)

# Live apply to Hyprland compositor
gin = p_hypr['gaps_in']
gout = p_hypr['gaps_out']
bsz = p_hypr['border_size']
rnd = p_hypr['rounding']
eval_str = f"hl.config({{ general = {{ gaps_in = {gin}, gaps_out = {gout}, border_size = {bsz} }}, decoration = {{ rounding = {rnd} }} }})"
subprocess.run(["hyprctl", "eval", eval_str], capture_output=True)
PY

# Instant reload of Wayle service (takes ~150ms)
systemctl --user restart wayle.service >/dev/null 2>&1 || true

notify-send -u low -a "Soberano" "󰕮 Wayle & Hyprland" "Layout ${clean} sincronizado" 2>/dev/null || true
