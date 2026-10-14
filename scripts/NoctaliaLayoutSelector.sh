#!/usr/bin/env bash
# ==============================================================================
# NoctaliaLayoutSelector - Interactive Bar Layouts & Geometries for Noctalia Shell
# Port of JaKooLit WaybarLayout system to native Noctalia Wayland architecture.
# Bound to: Super + Ctrl + B
# ==============================================================================
set -euo pipefail

DOTFILES="${HOME}/dotfiles"
LAYOUTS_DIR="${DOTFILES}/config/noctalia/layouts"
COMPOSER="${DOTFILES}/scripts/noctalia_composer.py"

if [ ! -d "$LAYOUTS_DIR" ]; then
    echo "Erro: Diretório de layouts não encontrado em $LAYOUTS_DIR" >&2
    exit 1
fi

current_layout=$("$COMPOSER" get-layout 2>/dev/null || echo "")

declare -A layout_map
options=()

for p in "$LAYOUTS_DIR"/*.toml; do
    fname=$(basename "$p" .toml)
    clean_name="$fname"
    if [[ "$clean_name" =~ ^[0-9]+\.\  ]]; then
        clean_name="${clean_name:3}"
    fi
    layout_map["$clean_name"]="$fname"

    if [ "$fname" = "$current_layout" ]; then
        options+=("👉 $clean_name (Ativo)")
    else
        options+=("   $clean_name")
    fi
done

# Launch Noctalia dmenu
chosen=$(printf '%s\n' "${options[@]}" | noctalia dmenu -p "󰕰 Escolher Layout de Barra (Super+Ctrl+B)" || true)

# Exit if cancelled
if [ -z "$chosen" ]; then
    exit 0
fi

# Clean selection name
clean_name=$(echo "$chosen" | sed 's/^[[:space:]]*//; s/^👉[[:space:]]*//; s/[[:space:]]*(Ativo)//')
selected_file="${layout_map[$clean_name]:-}"

if [ -z "$selected_file" ]; then
    echo "Layout não encontrado: $chosen" >&2
    exit 1
fi

# Apply layout through the unified composer (preserves active style and palette!)
"$COMPOSER" set-layout "$selected_file"
