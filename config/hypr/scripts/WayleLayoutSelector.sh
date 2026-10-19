#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026) — Wayle Port
#  Project URL: https://github.com/LinuxBeginnings
# ==================================================
# Interactive Layout Selector for Wayle (47 JaKooLit Layouts)
set -euo pipefail
IFS=$'\n\t'

WAYLE_LAYOUTS="${XDG_CONFIG_HOME:-$HOME/.config}/wayle/layouts"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/wayle"
ACTIVE_LAYOUT_FILE="${STATE_DIR}/active_layout"
SCRIPTSDIR="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/scripts"
ROFI_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/rofi/config-waybar-layout.rasi"
MSG=' 🎌 WAYLE LAYOUTS: Escolha qualquer um dos 47 layouts do JaKooLit'

mkdir -p "$STATE_DIR"

apply_config() {
    local chosen_layout="$1"
    python3 "${SCRIPTSDIR}/WayleSyncConfig.py" "$chosen_layout" "-"
    notify-send -u low -i preferences-desktop-display "Wayle Layout" "Layout aplicado: <b>${chosen_layout}</b>" 2>/dev/null || true
}

if [[ "${1:-}" != "" ]]; then
    apply_config "$1"
    exit 0
fi

main() {
    local current_name="TOP-Default"
    if [[ -f "$ACTIVE_LAYOUT_FILE" ]]; then
        current_name=$(head -n 1 "$ACTIVE_LAYOUT_FILE" | tr -d '\r\n')
    fi

    mapfile -t options < <(
        find -L "$WAYLE_LAYOUTS" -maxdepth 1 -type f -name '*.toml' \
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
            | rofi -i -dmenu -p "󰕰 Wayle Layout" -selected-row "$default_row" || true
        )
    fi

    [[ -z "$choice" ]] && exit 0

    choice="${choice#"$MARKER "}"
    apply_config "$choice"
}

if pgrep -x "rofi" >/dev/null 2>&1; then
    pkill rofi
    exit 0
fi

main
