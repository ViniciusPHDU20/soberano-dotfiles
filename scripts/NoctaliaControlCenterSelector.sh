#!/usr/bin/env bash
# ==============================================================================
# NoctaliaControlCenterSelector - Interactive Control Center Profile Chooser
# Modifies Noctalia's Control Center geometry, width, sidebar layout, and transparency.
# Bound to: Super + Alt + C
# ==============================================================================
set -euo pipefail

DOTFILES="${HOME}/dotfiles"
PRESETS_DIR="${DOTFILES}/config/noctalia/presets/control_center"
COMPOSER="${DOTFILES}/scripts/noctalia_composer.py"

if [ ! -d "$PRESETS_DIR" ]; then
    echo "Erro: Diretório de presets não encontrado em $PRESETS_DIR" >&2
    exit 1
fi

current_cc=$("$COMPOSER" get-cc-style 2>/dev/null || echo "6. Auto-Sync-Theme")

# Descriptions mapping
declare -A desc_map=(
    ["1. Cyber-Cockpit-HUD"]="Wide 820px • Cantos Retos 90° • Full Sidebar • Glass"
    ["2. Nordic-Pure-Minimal"]="Slim 560px • Curva 0.4 • Sem Sidebar • Vidro Fosco"
    ["3. Floating-Island-Center"]="Janela Flutuante Central • Pill 1.4 • Soft Acrílico"
    ["4. Velvet-Cozy-Cards"]="Compact 660px • Pill 1.4 • Compact Sidebar • Soft"
    ["5. Brutalist-Monochrome"]="Stark 780px • Cantos 0° • Full Sidebar • OLED Solid"
    ["6. Auto-Sync-Theme"]="Sincronizar dinamicamente com o Tema de Barra Ativo"
)

declare -A icon_map=(
    ["1. Cyber-Cockpit-HUD"]="󰧑"
    ["2. Nordic-Pure-Minimal"]="󰒋"
    ["3. Floating-Island-Center"]="󰖲"
    ["4. Velvet-Cozy-Cards"]="󰄛"
    ["5. Brutalist-Monochrome"]="󰚌"
    ["6. Auto-Sync-Theme"]="󰑐"
)

# Build menu list
options=()
for p in "$PRESETS_DIR"/*.toml; do
    name=$(basename "$p" .toml)
    icon="${icon_map[$name]:-󰍹}"
    desc="${desc_map[$name]:-}"
    
    label="$icon $name"
    if [ -n "$desc" ]; then
        label="$label ($desc)"
    fi

    if [ "$name" = "$current_cc" ]; then
        options+=("👉 $label [Ativo]")
    else
        options+=("   $label")
    fi
done

# Launch Noctalia dmenu
chosen=$(printf '%s\n' "${options[@]}" | noctalia dmenu -p "󰏘 Escolher Perfil do Control Center (Super+Alt+C)" || true)

# Exit if cancelled
if [ -z "$chosen" ]; then
    exit 0
fi

# Extract preset name
clean_name=$(echo "$chosen" | sed -E 's/^[[:space:]]*//; s/^👉[[:space:]]*//; s/^[󰧑󰒋󰖲󰄛󰚌󰑐󰍹][[:space:]]*//; s/[[:space:]]*\(.*//; s/[[:space:]]*\[Ativo\]//')

# Apply Control Center profile through the unified composer
"$COMPOSER" set-cc-style "$clean_name"
