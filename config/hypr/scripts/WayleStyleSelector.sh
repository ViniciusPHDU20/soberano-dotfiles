#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026) — Wayle Port
#  Project URL: https://github.com/LinuxBeginnings
# ==================================================
# Interactive Style Selector for Wayle (50 JaKooLit Styles + Wallust)
set -euo pipefail
IFS=$'\n\t'

WAYLE_THEMES="${XDG_CONFIG_HOME:-$HOME/.config}/wayle/themes"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/wayle"
ACTIVE_STYLE_FILE="${STATE_DIR}/active_style"
SCRIPTSDIR="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/scripts"
ROFI_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/rofi/config-waybar-style.rasi"
MSG=' 🎌 WAYLE STYLES: Escolha qualquer um dos 50 estilos visuais do JaKooLit'

mkdir -p "$STATE_DIR"

apply_style() {
    local chosen_style="$1"
    python3 "${SCRIPTSDIR}/WayleSyncConfig.py" "-" "$chosen_style"
    notify-send -u low -i preferences-desktop-theme "Wayle Style" "Estilo aplicado: <b>${chosen_style}</b>" 2>/dev/null || true
}

if [[ "${1:-}" != "" ]]; then
    apply_style "$1"
    exit 0
fi

main() {
    local current_name="Catppuccin-Mocha"
    if [[ -f "$ACTIVE_STYLE_FILE" ]]; then
        current_name=$(head -n 1 "$ACTIVE_STYLE_FILE" | tr -d '\r\n')
    fi

    mapfile -t options < <(
        find -L "$WAYLE_THEMES" -maxdepth 1 -type f -name '*.toml' \
            ! -name 'Wallust-Dynamic.toml' \
            -exec basename {} .toml \; \
            | sort
    )

    local default_row=0
    local MARKER="👉"
    for i in "${!options[@]}"; do
        if [[ "${options[i]}" == "$current_name" ]]; then
            options[i]="$MARKER ${options[i]}"
            default_row=$i
            break
        fi
    done

    "${SCRIPTSDIR}/RofiFocusedWallpaperLink.sh" >/dev/null 2>&1 || true

    local choice=""
    if [[ -f "$ROFI_CONFIG" ]]; then
        choice=$(printf '%s\n' "${options[@]}" \
            | rofi -i -dmenu \
                   -config "$ROFI_CONFIG" \
                   -mesg "$MSG" \
                   -selected-row "$default_row" || true
        )
    else
        choice=$(printf '%s\n' "${options[@]}" \
            | rofi -i -dmenu -p "󰏘 Wayle Style" -selected-row "$default_row" || true
        )
    fi

    [[ -z "$choice" ]] && exit 0

    choice="${choice#"$MARKER "}"
    apply_style "$choice"
}

if pgrep -x "rofi" >/dev/null 2>&1; then
    pkill rofi
    exit 0
fi

main
