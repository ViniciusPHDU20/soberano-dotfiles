#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026) — Wayle Port
#  Refresh script for Wayle, Rofi, Quickshell & Wallust
# ==================================================

SCRIPTSDIR="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/scripts"
QS_TEXTINPUT_LOG_RULE="qt.qpa.wayland.textinput.warning=false"

# Kill open menus
for _prs in rofi ags waybar swaync; do
  if pidof "${_prs}" >/dev/null 2>&1; then
    pkill "${_prs}" 2>/dev/null || true
  fi
done

# Relaunch Quickshell overview if installed
if command -v qs >/dev/null 2>&1; then
  pkill qs 2>/dev/null || true
  qs --log-rules "$QS_TEXTINPUT_LOG_RULE" -c overview >/dev/null 2>&1 &
fi

# Sync and restart Wayle
if [ -x "${SCRIPTSDIR}/WaybarStartup.sh" ]; then
  "${SCRIPTSDIR}/WaybarStartup.sh" --restart &
else
  systemctl --user restart wayle.service >/dev/null 2>&1 &
fi

# Reload nwg-dock-hyprland if running
if pgrep -f "nwg-dock-hyprland" >/dev/null 2>&1; then
  "${SCRIPTSDIR}/Dock.sh" --restart >/dev/null 2>&1 &
fi

# Re-apply Rainbow Borders
sleep 0.5
if [ -x "${SCRIPTSDIR}/RainbowBordersStartup.sh" ]; then
  "${SCRIPTSDIR}/RainbowBordersStartup.sh" >/dev/null 2>&1 || true
fi

exit 0
