#!/usr/bin/env bash
# ==============================================================================
# NoctaliaThemeSelector - Interactive Bar Styles & Themes for Noctalia Shell
# Port of JaKooLit WaybarStyles system to native Noctalia Wayland architecture.
# Bound to: Super + Alt + B
# ==============================================================================
set -euo pipefail

DOTFILES="${HOME}/dotfiles"
STYLES_DIR="${DOTFILES}/config/noctalia/styles"
COMPOSER="${DOTFILES}/scripts/noctalia_composer.py"

if [ ! -d "$STYLES_DIR" ]; then
    echo "Erro: Diretório de estilos não encontrado em $STYLES_DIR" >&2
    exit 1
fi

current_style=$("$COMPOSER" get-style 2>/dev/null || echo "")

# Build menu list
options=()
for p in "$STYLES_DIR"/*.toml; do
    name=$(basename "$p" .toml)
    if [ "$name" = "$current_style" ]; then
        options+=("👉 $name (Ativo)")
    else
        options+=("   $name")
    fi
done

# Launch Noctalia dmenu
chosen=$(printf '%s\n' "${options[@]}" | noctalia dmenu -p "󰏘 Escolher Estilo de Barra (Super+Alt+B)" || true)

# Exit if cancelled
if [ -z "$chosen" ]; then
    exit 0
fi

# Clean selection name
clean_name=$(echo "$chosen" | sed 's/^[[:space:]]*//; s/^👉[[:space:]]*//; s/[[:space:]]*(Ativo)//')

# Apply style through the unified composer (preserves active layout geometry!)
"$COMPOSER" set-style "$clean_name"
