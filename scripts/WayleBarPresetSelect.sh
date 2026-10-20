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
    "1   — Floating Pill Top (Pílula Flutuante Suave)"
    "2   — Block-Prefix Chips (Padrão Nativo Wayle)"
    "3   — Full-Width Top Bar (Barra Reta Colada no Topo)"
    "4   — Floating Bottom Dock (Barra Flutuante Inferior)"
    "5   — Icon-Square Compact (Compacto Quadrado)"
    "6   — Island Floating Clusters (Ilhas Flutuantes Transparentes)"
    "7   — Cyberpunk Neon Blade (Lâmina Angular com Laser Accent)"
    "8   — Dynamic Island Capsule (Cápsula Flutuante com Sombra 3D)"
    "9   — Glassmorphism HUD Dock (Dock Inferior de Vidro Fosco)"
    "10  — Stealth Minimalist Strip (Micro-Faixa Stealth Invisível)"
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

chosen=$(printf '%s\n' "${options[@]}" | fuzzel --dmenu -p "󰕮 Wayle Layout ❯ " -w 62 -l 10 || true)
[ -z "$chosen" ] && exit 0

clean=$(echo "$chosen" | sed 's/^👉 //; s/^   //')
id="${clean%% *}"

mkdir -p "$(dirname "$PRESET_STATE")"
echo "$id" > "$PRESET_STATE"

python3 - "$WAYLE_CFG" "$id" <<'PY'
import sys

cfg_path, preset_id = sys.argv[1], sys.argv[2]
with open(cfg_path, "r") as f:
    cfg_text = f.read()

presets = {
    # 1. Floating Pill Top (Pílula Flutuante)
    "1": {
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
    # 2. Block-Prefix Chips (Padrão Wayle)
    "2": {
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
    # 3. Full-Width Top Bar (Barra Reta Colada no Topo)
    "3": {
        "location": '"top"',
        "scale": "0.95",
        "inset-edge": "0.0",
        "inset-ends": "0.0",
        "padding": "0.28",
        "padding-ends": "0.45",
        "module-gap": "0.4",
        "bg": '"bg-surface"',
        "background-opacity": "94",
        "rounding": '"none"',
        "border-location": '"bottom"',
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
    # 4. Floating Bottom Dock (Barra Flutuante Inferior)
    "4": {
        "location": '"bottom"',
        "scale": "0.95",
        "inset-edge": "0.35",
        "inset-ends": "0.6",
        "padding": "0.3",
        "padding-ends": "0.5",
        "module-gap": "0.4",
        "bg": '"bg-surface"',
        "background-opacity": "88",
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
    # 5. Icon-Square Compact (Compacto Quadrado)
    "5": {
        "location": '"top"',
        "scale": "0.95",
        "inset-edge": "0.25",
        "inset-ends": "0.4",
        "padding": "0.25",
        "padding-ends": "0.4",
        "module-gap": "0.4",
        "bg": '"bg-surface"',
        "background-opacity": "85",
        "rounding": '"md"',
        "border-location": '"all"',
        "border-width": "1",
        "border-color": '"border-subtle"',
        "shadow": '"none"',
        "button-variant": '"icon-square"',
        "button-rounding": '"sm"',
        "button-border-location": '"all"',
        "button-border-width": "1",
        "button-group-border-location": '"none"',
        "button-group-rounding": '"sm"',
    },
    # 6. Island Floating Clusters (Ilhas Flutuantes Transparentes)
    "6": {
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
    # 7. Cyberpunk Neon Blade (Lâmina Angular com Laser Accent)
    "7": {
        "location": '"top"',
        "scale": "0.95",
        "inset-edge": "0.0",
        "inset-ends": "0.0",
        "padding": "0.25",
        "padding-ends": "0.4",
        "module-gap": "0.35",
        "bg": '"bg-base"',
        "background-opacity": "96",
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
        "button-group-border-color": '"border-subtle"',
        "button-group-rounding": '"none"',
    },
    # 8. Dynamic Island Capsule (Cápsula Flutuante com Sombra 3D)
    "8": {
        "location": '"top"',
        "scale": "0.98",
        "inset-edge": "0.5",
        "inset-ends": "1.1",
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
        "button-border-location": '"all"',
        "button-border-width": "1",
        "button-group-border-location": '"none"',
        "button-group-rounding": '"full"',
    },
    # 9. Glassmorphism HUD Dock (Dock Inferior de Vidro Fosco)
    "9": {
        "location": '"bottom"',
        "scale": "0.96",
        "inset-edge": "0.45",
        "inset-ends": "0.65",
        "padding": "0.3",
        "padding-ends": "0.5",
        "module-gap": "0.4",
        "bg": '"bg-surface"',
        "background-opacity": "68",
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
    # 10. Stealth Minimalist Strip (Micro-Faixa Stealth Invisível)
    "10": {
        "location": '"top"',
        "scale": "0.88",
        "inset-edge": "0.15",
        "inset-ends": "0.2",
        "padding": "0.18",
        "padding-ends": "0.3",
        "module-gap": "0.25",
        "bg": '"bg-surface"',
        "background-opacity": "90",
        "rounding": '"sm"',
        "border-location": '"none"',
        "border-width": "0",
        "shadow": '"none"',
        "button-variant": '"basic"',
        "button-rounding": '"sm"',
        "button-border-location": '"none"',
        "button-border-width": "0",
        "button-group-border-location": '"none"',
        "button-group-rounding": '"sm"',
    },
}

p = presets.get(preset_id, presets["2"])

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
        for k, v in p.items():
            if k not in found_keys:
                new_lines.append(f"{k} = {v}")
        in_bar = False
    if in_bar:
        matched = False
        for k, v in p.items():
            if line.strip().startswith(f"{k} ") or line.strip().startswith(f"{k}="):
                new_lines.append(f"{k} = {v}")
                found_keys.add(k)
                matched = True
                break
        if not matched:
            new_lines.append(line)
    else:
        new_lines.append(line)

with open(cfg_path, "w") as f:
    f.write("\n".join(new_lines) + "\n")
PY

notify-send -u low -a "Soberano" "󰕮 Wayle Layout" "Preset ${clean} aplicado" 2>/dev/null || true
