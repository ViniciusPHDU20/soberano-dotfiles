#!/usr/bin/env python3
"""
hud_theme_sync.py - Generates theme.css for HyprKeybindsHUD matching Noctalia & System Colors.
Respects active Bar Style (Catppuccin, Cyberpunk, Glass, Dracula, etc.) and Wallpaper Palettes.
"""
import os
import re

STYLE_PRESETS = {
    "Catppuccin-Mocha": {
        "bg_app": "rgba(24, 24, 37, 0.94)",
        "bg_card": "rgba(30, 30, 46, 0.90)",
        "bg_input": "rgba(49, 50, 68, 0.85)",
        "bg_kbd": "#45475a",
        "border_app": "rgba(203, 166, 247, 0.45)",
        "border_card": "rgba(255, 255, 255, 0.08)",
        "border_kbd": "#585b70",
        "text_fg": "#cdd6f4",
        "text_muted": "#a6adc8",
        "accent": "#cba6f7",
        "accent_contrast": "#11111b",
        "cat_rice": "#f5c2e7",
        "cat_win": "#89b4fa",
        "cat_ws": "#a6e3a1",
        "cat_utils": "#fab387",
        "danger": "#f38ba8",
        "danger_bg": "rgba(243, 139, 168, 0.15)",
        "danger_border": "rgba(243, 139, 168, 0.45)",
    },
    "Neon-Circuit-Cyberpunk": {
        "bg_app": "rgba(10, 14, 23, 0.96)",
        "bg_card": "rgba(16, 22, 36, 0.92)",
        "bg_input": "rgba(22, 30, 48, 0.90)",
        "bg_kbd": "#1c253b",
        "border_app": "rgba(0, 240, 255, 0.50)",
        "border_card": "rgba(0, 240, 255, 0.12)",
        "border_kbd": "#36476b",
        "text_fg": "#f8fafc",
        "text_muted": "#94a3b8",
        "accent": "#00f0ff",
        "accent_contrast": "#080b12",
        "cat_rice": "#ff007f",
        "cat_win": "#00f0ff",
        "cat_ws": "#00ff66",
        "cat_utils": "#ffe600",
        "danger": "#ff0055",
        "danger_bg": "rgba(255, 0, 85, 0.18)",
        "danger_border": "rgba(255, 0, 85, 0.50)",
    },
    "Crystal-Clear-Glass": {
        "bg_app": "rgba(17, 21, 30, 0.78)",
        "bg_card": "rgba(255, 255, 255, 0.05)",
        "bg_input": "rgba(255, 255, 255, 0.08)",
        "bg_kbd": "rgba(255, 255, 255, 0.12)",
        "border_app": "rgba(173, 198, 255, 0.40)",
        "border_card": "rgba(255, 255, 255, 0.08)",
        "border_kbd": "rgba(255, 255, 255, 0.20)",
        "text_fg": "#f8fafc",
        "text_muted": "#cbd5e1",
        "accent": "#adc6ff",
        "accent_contrast": "#0a1329",
        "cat_rice": "#debcdf",
        "cat_win": "#adc6ff",
        "cat_ws": "#a6e3a1",
        "cat_utils": "#bfc6dc",
        "danger": "#ffb4ab",
        "danger_bg": "rgba(255, 180, 171, 0.18)",
        "danger_border": "rgba(255, 180, 171, 0.45)",
    },
    "Dracula": {
        "bg_app": "rgba(40, 42, 54, 0.95)",
        "bg_card": "rgba(33, 34, 44, 0.90)",
        "bg_input": "rgba(68, 71, 90, 0.85)",
        "bg_kbd": "#44475a",
        "border_app": "rgba(189, 147, 249, 0.45)",
        "border_card": "rgba(255, 255, 255, 0.08)",
        "border_kbd": "#6272a4",
        "text_fg": "#f8f8f2",
        "text_muted": "#6272a4",
        "accent": "#bd93f9",
        "accent_contrast": "#21222c",
        "cat_rice": "#ff79c6",
        "cat_win": "#8be9fd",
        "cat_ws": "#50fa7b",
        "cat_utils": "#ffb86c",
        "danger": "#ff5555",
        "danger_bg": "rgba(255, 85, 85, 0.15)",
        "danger_border": "rgba(255, 85, 85, 0.45)",
    },
    "Gruvbox-Retro": {
        "bg_app": "rgba(40, 40, 40, 0.95)",
        "bg_card": "rgba(50, 48, 47, 0.90)",
        "bg_input": "rgba(60, 56, 54, 0.85)",
        "bg_kbd": "#504945",
        "border_app": "rgba(215, 153, 33, 0.45)",
        "border_card": "rgba(235, 219, 178, 0.08)",
        "border_kbd": "#665c54",
        "text_fg": "#ebdbb2",
        "text_muted": "#a89984",
        "accent": "#fe8019",
        "accent_contrast": "#282828",
        "cat_rice": "#d3869b",
        "cat_win": "#83a598",
        "cat_ws": "#b8bb26",
        "cat_utils": "#fabd2f",
        "danger": "#fb4934",
        "danger_bg": "rgba(251, 73, 52, 0.15)",
        "danger_border": "rgba(251, 73, 52, 0.45)",
    },
    "Nord-Frost": {
        "bg_app": "rgba(46, 52, 64, 0.95)",
        "bg_card": "rgba(59, 66, 82, 0.90)",
        "bg_input": "rgba(67, 76, 94, 0.85)",
        "bg_kbd": "#4c566a",
        "border_app": "rgba(136, 192, 208, 0.45)",
        "border_card": "rgba(236, 239, 244, 0.08)",
        "border_kbd": "#5e81ac",
        "text_fg": "#eceff4",
        "text_muted": "#d8dee9",
        "accent": "#88c0d0",
        "accent_contrast": "#2e3440",
        "cat_rice": "#b48ead",
        "cat_win": "#81a1c1",
        "cat_ws": "#a3be8c",
        "cat_utils": "#ebcb8b",
        "danger": "#bf616a",
        "danger_bg": "rgba(191, 97, 106, 0.15)",
        "danger_border": "rgba(191, 97, 106, 0.45)",
    },
    "Tokyo-Night": {
        "bg_app": "rgba(26, 27, 38, 0.95)",
        "bg_card": "rgba(36, 40, 59, 0.90)",
        "bg_input": "rgba(41, 46, 66, 0.85)",
        "bg_kbd": "#343b58",
        "border_app": "rgba(122, 162, 247, 0.45)",
        "border_card": "rgba(192, 202, 245, 0.08)",
        "border_kbd": "#414868",
        "text_fg": "#c0caf5",
        "text_muted": "#7982a9",
        "accent": "#7aa2f7",
        "accent_contrast": "#1a1b26",
        "cat_rice": "#bb9af7",
        "cat_win": "#7dcfff",
        "cat_ws": "#9ece6a",
        "cat_utils": "#ff9e64",
        "danger": "#f7768e",
        "danger_bg": "rgba(247, 118, 142, 0.15)",
        "danger_border": "rgba(247, 118, 142, 0.45)",
    },
    "Rose-Pine": {
        "bg_app": "rgba(25, 23, 36, 0.95)",
        "bg_card": "rgba(31, 29, 46, 0.90)",
        "bg_input": "rgba(38, 35, 58, 0.85)",
        "bg_kbd": "#403d52",
        "border_app": "rgba(234, 154, 151, 0.45)",
        "border_card": "rgba(224, 222, 244, 0.08)",
        "border_kbd": "#524f67",
        "text_fg": "#e0def4",
        "text_muted": "#908caa",
        "accent": "#eb6f92",
        "accent_contrast": "#191724",
        "cat_rice": "#c4a7e7",
        "cat_win": "#9ccfd8",
        "cat_ws": "#31748f",
        "cat_utils": "#f6c177",
        "danger": "#eb6f92",
        "danger_bg": "rgba(235, 111, 146, 0.15)",
        "danger_border": "rgba(235, 111, 146, 0.45)",
    },
    "Kanagawa-Wave": {
        "bg_app": "rgba(31, 31, 40, 0.95)",
        "bg_card": "rgba(42, 42, 55, 0.90)",
        "bg_input": "rgba(54, 54, 70, 0.85)",
        "bg_kbd": "#49473e",
        "border_app": "rgba(126, 156, 216, 0.45)",
        "border_card": "rgba(220, 215, 186, 0.08)",
        "border_kbd": "#54546d",
        "text_fg": "#dcd7ba",
        "text_muted": "#727169",
        "accent": "#7e9cd8",
        "accent_contrast": "#1f1f28",
        "cat_rice": "#957fb8",
        "cat_win": "#7aa89f",
        "cat_ws": "#98bb6c",
        "cat_utils": "#ffa066",
        "danger": "#e82424",
        "danger_bg": "rgba(232, 36, 36, 0.15)",
        "danger_border": "rgba(232, 36, 36, 0.45)",
    },
    "Everforest-Natural": {
        "bg_app": "rgba(43, 51, 57, 0.95)",
        "bg_card": "rgba(50, 60, 67, 0.90)",
        "bg_input": "rgba(58, 69, 77, 0.85)",
        "bg_kbd": "#4a555b",
        "border_app": "rgba(167, 192, 128, 0.45)",
        "border_card": "rgba(211, 198, 170, 0.08)",
        "border_kbd": "#56635f",
        "text_fg": "#d3c6aa",
        "text_muted": "#859289",
        "accent": "#a7c080",
        "accent_contrast": "#2b3339",
        "cat_rice": "#d699b6",
        "cat_win": "#7fbbb3",
        "cat_ws": "#83c092",
        "cat_utils": "#dbbc7f",
        "danger": "#e67e80",
        "danger_bg": "rgba(230, 126, 128, 0.15)",
        "danger_border": "rgba(230, 126, 128, 0.45)",
    },
    "Black-&-White-Monochrome": {
        "bg_app": "rgba(18, 18, 18, 0.96)",
        "bg_card": "rgba(28, 28, 28, 0.90)",
        "bg_input": "rgba(38, 38, 38, 0.85)",
        "bg_kbd": "#363636",
        "border_app": "rgba(255, 255, 255, 0.45)",
        "border_card": "rgba(255, 255, 255, 0.12)",
        "border_kbd": "#505050",
        "text_fg": "#ffffff",
        "text_muted": "#8c8c8c",
        "accent": "#ffffff",
        "accent_contrast": "#000000",
        "cat_rice": "#e0e0e0",
        "cat_win": "#cccccc",
        "cat_ws": "#b0b0b0",
        "cat_utils": "#999999",
        "danger": "#ff6666",
        "danger_bg": "rgba(255, 102, 102, 0.15)",
        "danger_border": "rgba(255, 102, 102, 0.45)",
    },
    "Nordic-Slate": {
        "bg_app": "rgba(24, 28, 36, 0.95)",
        "bg_card": "rgba(34, 40, 52, 0.90)",
        "bg_input": "rgba(44, 52, 68, 0.85)",
        "bg_kbd": "#3a4459",
        "border_app": "rgba(148, 163, 184, 0.45)",
        "border_card": "rgba(230, 235, 240, 0.08)",
        "border_kbd": "#4a5773",
        "text_fg": "#e6ebf0",
        "text_muted": "#8a99a8",
        "accent": "#8899aa",
        "accent_contrast": "#181c24",
        "cat_rice": "#a0b0c0",
        "cat_win": "#88a0b8",
        "cat_ws": "#80a898",
        "cat_utils": "#c0b090",
        "danger": "#d06060",
        "danger_bg": "rgba(208, 96, 96, 0.15)",
        "danger_border": "rgba(208, 96, 96, 0.45)",
    },
    "Colorful-Chroma-Spectrum": {
        "bg_app": "rgba(18, 14, 28, 0.95)",
        "bg_card": "rgba(28, 22, 44, 0.90)",
        "bg_input": "rgba(38, 30, 60, 0.85)",
        "bg_kbd": "#44356e",
        "border_app": "rgba(255, 0, 127, 0.45)",
        "border_card": "rgba(255, 255, 255, 0.10)",
        "border_kbd": "#634d9f",
        "text_fg": "#ffffff",
        "text_muted": "#b3a8cf",
        "accent": "#00f0ff",
        "accent_contrast": "#0d0a14",
        "cat_rice": "#ff00aa",
        "cat_win": "#00d4ff",
        "cat_ws": "#00ff88",
        "cat_utils": "#ffb300",
        "danger": "#ff0055",
        "danger_bg": "rgba(255, 0, 85, 0.18)",
        "danger_border": "rgba(255, 0, 85, 0.45)",
    },
}

def parse_kitty_theme(path):
    colors = {}
    if not os.path.exists(path):
        return colors
    try:
        with open(path, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                parts = line.split()
                if len(parts) >= 2:
                    colors[parts[0]] = parts[1]
    except Exception:
        pass
    return colors

def get_active_style_name():
    style_file = os.path.expanduser("~/.config/noctalia/active_style.txt")
    if os.path.exists(style_file):
        try:
            with open(style_file, "r") as f:
                val = f.read().strip()
                if val:
                    return val
        except Exception:
            pass
    return "Neon-Circuit-Cyberpunk"

def generate_css():
    active_style = get_active_style_name()
    kitty_colors = parse_kitty_theme(os.path.expanduser("~/.config/kitty/themes/noctalia.conf"))

    # Base on preset or fallback
    preset = STYLE_PRESETS.get(active_style, STYLE_PRESETS["Neon-Circuit-Cyberpunk"]).copy()

    # Dynamic wallpaper integration (e.g. for Glass or when user customizes theme)
    if active_style == "Crystal-Clear-Glass" and kitty_colors:
        if "active_border_color" in kitty_colors:
            acc = kitty_colors["active_border_color"]
            preset["accent"] = acc
            preset["border_app"] = f"{acc}88"
            preset["cat_win"] = acc
        if "color4" in kitty_colors:
            preset["cat_rice"] = kitty_colors["color4"]
        if "color2" in kitty_colors:
            preset["cat_ws"] = kitty_colors["color2"]
        if "color3" in kitty_colors:
            preset["cat_utils"] = kitty_colors["color3"]
        if "color1" in kitty_colors:
            preset["danger"] = kitty_colors["color1"]
        if "foreground" in kitty_colors:
            preset["text_fg"] = kitty_colors["foreground"]
        if "color8" in kitty_colors:
            preset["text_muted"] = kitty_colors["color8"]

    css_content = f"""/* Auto-generated by hud_theme_sync.py for style: {active_style} */
:root {{
  --bg-app: {preset['bg_app']};
  --bg-card: {preset['bg_card']};
  --bg-input: {preset['bg_input']};
  --bg-kbd: {preset['bg_kbd']};
  --border-app: {preset['border_app']};
  --border-card: {preset['border_card']};
  --border-kbd: {preset['border_kbd']};
  --text-fg: {preset['text_fg']};
  --text-muted: {preset['text_muted']};
  --accent: {preset['accent']};
  --accent-contrast: {preset['accent_contrast']};
  --cat-rice: {preset['cat_rice']};
  --cat-win: {preset['cat_win']};
  --cat-ws: {preset['cat_ws']};
  --cat-utils: {preset['cat_utils']};
  --danger: {preset['danger']};
  --danger-bg: {preset['danger_bg']};
  --danger-border: {preset['danger_border']};
}}
"""
    output_path = os.path.expanduser("~/dotfiles/config/hypr/hud/theme.css")
    with open(output_path, "w", encoding="utf-8") as f:
        f.write(css_content)

    return active_style

if __name__ == "__main__":
    st = generate_css()
    print(f"HUD theme synced successfully for style: {st}")
