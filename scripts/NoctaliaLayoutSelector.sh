#!/usr/bin/env bash
# ==============================================================================
# NoctaliaLayoutSelector - Interactive Bar Layouts & Geometries for Noctalia Shell
# Port of JaKooLit WaybarLayout system to native Noctalia Wayland architecture.
# Bound to: Super + Ctrl + B
# ==============================================================================
set -euo pipefail

SCRIPTS_DIR="${HOME}/dotfiles/scripts"
MANAGER="${SCRIPTS_DIR}/noctalia_layout_manager.py"
SYNC_SCRIPT="${SCRIPTS_DIR}/DynamicThemeSync.sh"

if [ ! -f "$MANAGER" ]; then
    echo "Erro: Layout manager não encontrado em $MANAGER" >&2
    exit 1
fi

# Get list of layouts: filename <tab> clean_name
mapfile -t raw_list < <("$MANAGER" list)

if [ ${#raw_list[@]} -eq 0 ]; then
    echo "Nenhum layout disponível encontrado." >&2
    exit 1
fi

declare -A layout_map
options=()

for line in "${raw_list[@]}"; do
    fname=$(echo "$line" | cut -f1)
    cname=$(echo "$line" | cut -f2)
    layout_map["$cname"]="$fname"
    options+=("󰕰 $cname")
done

# Launch Noctalia dmenu
chosen=$(printf '%s\n' "${options[@]}" | noctalia dmenu -p "󰕰 Escolher Layout de Barra (Super+Ctrl+B)" || true)

# Exit if cancelled
if [ -z "$chosen" ]; then
    exit 0
fi

# Clean selection name
clean_name=$(echo "$chosen" | sed 's/^[[:space:]]*//; s/^󰕰[[:space:]]*//')
selected_file="${layout_map[$clean_name]:-}"

if [ -z "$selected_file" ]; then
    echo "Layout não encontrado: $chosen" >&2
    exit 1
fi

# Apply layout via manager
if "$MANAGER" apply "$selected_file"; then
    # Small delay for hot-reload
    sleep 0.2
    
    # Notify and sync
    if command -v noctalia >/dev/null 2>&1; then
        noctalia msg notification-show "Layout de Barra Aplicado" "Layout: ${clean_name}" >/dev/null 2>&1 || true
    fi
    
    if [ -f "$SYNC_SCRIPT" ]; then
        bash "$SYNC_SCRIPT" >/dev/null 2>&1 || true
    fi
    
    echo "Layout ${clean_name} aplicado com sucesso."
else
    if command -v noctalia >/dev/null 2>&1; then
        noctalia msg notification-show "Erro" "Falha ao aplicar o layout ${clean_name}" >/dev/null 2>&1 || true
    fi
    exit 1
fi
