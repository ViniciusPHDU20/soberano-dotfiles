#!/usr/bin/env python3
"""
hud_theme_sync.py - Generates & embeds dynamic system theme into HyprKeybindsHUD.
Guarantees 100% theme fidelity with Noctalia active style and Wallpaper M3 palette.
"""
import os
import re

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

def hex_to_rgba(hex_color, alpha=1.0):
    hex_color = hex_color.lstrip("#")
    if len(hex_color) == 6:
        r = int(hex_color[0:2], 16)
        g = int(hex_color[2:4], 16)
        b = int(hex_color[4:6], 16)
        return f"rgba({r}, {g}, {b}, {alpha})"
    return hex_color

STYLE_PRESETS = {
    "Catppuccin-Mocha": {
        "bg_app": "rgba(24, 24, 37, 0.95)",
        "bg_card": "rgba(30, 30, 46, 0.90)",
        "bg_input": "rgba(49, 50, 68, 0.85)",
        "bg_kbd": "#45475a",
        "border_app": "rgba(203, 166, 247, 0.55)",
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
        "danger_bg": "rgba(243, 139, 168, 0.18)",
        "danger_border": "rgba(243, 139, 168, 0.50)",
    },
    "Neon-Circuit-Cyberpunk": {
        "bg_app": "rgba(10, 14, 23, 0.96)",
        "bg_card": "rgba(16, 22, 36, 0.92)",
        "bg_input": "rgba(22, 30, 48, 0.90)",
        "bg_kbd": "#1c253b",
        "border_app": "rgba(0, 240, 255, 0.60)",
        "border_card": "rgba(0, 240, 255, 0.15)",
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
        "danger_bg": "rgba(255, 0, 85, 0.20)",
        "danger_border": "rgba(255, 0, 85, 0.55)",
    },
    "Dracula": {
        "bg_app": "rgba(40, 42, 54, 0.95)",
        "bg_card": "rgba(33, 34, 44, 0.90)",
        "bg_input": "rgba(68, 71, 90, 0.85)",
        "bg_kbd": "#44475a",
        "border_app": "rgba(189, 147, 249, 0.55)",
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
        "danger_bg": "rgba(255, 85, 85, 0.18)",
        "danger_border": "rgba(255, 85, 85, 0.50)",
    },
    "Gruvbox-Retro": {
        "bg_app": "rgba(40, 40, 40, 0.96)",
        "bg_card": "rgba(50, 48, 47, 0.92)",
        "bg_input": "rgba(60, 56, 54, 0.88)",
        "bg_kbd": "#504945",
        "border_app": "rgba(215, 153, 33, 0.60)",
        "border_card": "rgba(235, 219, 178, 0.10)",
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
        "danger_bg": "rgba(251, 73, 52, 0.18)",
        "danger_border": "rgba(251, 73, 52, 0.50)",
    },
    "Nord-Frost": {
        "bg_app": "rgba(46, 52, 64, 0.95)",
        "bg_card": "rgba(59, 66, 82, 0.90)",
        "bg_input": "rgba(67, 76, 94, 0.85)",
        "bg_kbd": "#4c566a",
        "border_app": "rgba(136, 192, 208, 0.55)",
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
        "danger_bg": "rgba(191, 97, 106, 0.18)",
        "danger_border": "rgba(191, 97, 106, 0.50)",
    },
    "Tokyo-Night": {
        "bg_app": "rgba(26, 27, 38, 0.95)",
        "bg_card": "rgba(36, 40, 59, 0.90)",
        "bg_input": "rgba(41, 46, 66, 0.85)",
        "bg_kbd": "#343b58",
        "border_app": "rgba(122, 162, 247, 0.55)",
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
        "danger_bg": "rgba(247, 118, 142, 0.18)",
        "danger_border": "rgba(247, 118, 142, 0.50)",
    },
    "Rose-Pine": {
        "bg_app": "rgba(25, 23, 36, 0.95)",
        "bg_card": "rgba(31, 29, 46, 0.90)",
        "bg_input": "rgba(38, 35, 58, 0.85)",
        "bg_kbd": "#403d52",
        "border_app": "rgba(234, 154, 151, 0.55)",
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
        "danger_bg": "rgba(235, 111, 146, 0.18)",
        "danger_border": "rgba(235, 111, 146, 0.50)",
    },
    "Everforest-Natural": {
        "bg_app": "rgba(43, 51, 57, 0.95)",
        "bg_card": "rgba(50, 60, 67, 0.90)",
        "bg_input": "rgba(58, 69, 77, 0.85)",
        "bg_kbd": "#4a555b",
        "border_app": "rgba(167, 192, 128, 0.55)",
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
        "danger_bg": "rgba(230, 126, 128, 0.18)",
        "danger_border": "rgba(230, 126, 128, 0.50)",
    },
}

def resolve_palette():
    active_style = get_active_style_name()
    kitty = parse_kitty_theme(os.path.expanduser("~/.config/kitty/themes/noctalia.conf"))

    # If active style is Crystal-Clear-Glass or has rich kitty extraction, derive from system colors
    if active_style == "Crystal-Clear-Glass" or active_style not in STYLE_PRESETS:
        sys_bg = kitty.get("background", "#1a110f")
        sys_fg = kitty.get("foreground", "#f1dfdb")
        sys_border = kitty.get("active_border_color", "#ffb4a3")
        sys_sel = kitty.get("selection_background", "#534340")
        sys_gold = kitty.get("color4", "#dbc58c")
        sys_acc2 = kitty.get("color2", "#ffb4a3")
        sys_rose = kitty.get("color3", "#e7bdb4")
        sys_danger = kitty.get("color1", "#ffb4ab")
        sys_muted = kitty.get("color8", "#a08c88")

        return {
            "name": active_style,
            "bg_app": hex_to_rgba(sys_bg, 0.94),
            "bg_card": hex_to_rgba(sys_sel, 0.55),
            "bg_input": hex_to_rgba(sys_sel, 0.75),
            "bg_kbd": sys_sel,
            "border_app": hex_to_rgba(sys_border, 0.65),
            "border_card": hex_to_rgba(sys_fg, 0.10),
            "border_kbd": hex_to_rgba(sys_border, 0.50),
            "text_fg": sys_fg,
            "text_muted": sys_muted,
            "accent": sys_border,
            "accent_contrast": sys_bg,
            "cat_rice": sys_gold,
            "cat_win": sys_border,
            "cat_ws": sys_acc2,
            "cat_utils": sys_rose,
            "danger": sys_danger,
            "danger_bg": hex_to_rgba(sys_danger, 0.20),
            "danger_border": hex_to_rgba(sys_danger, 0.50),
        }

    # Named handcrafted preset
    p = STYLE_PRESETS[active_style].copy()
    p["name"] = active_style
    return p

def sync_all():
    p = resolve_palette()
    css_vars = f"""/* Dynamic System Theme for style: {p['name']} */
:root {{
  --bg-app: {p['bg_app']} !important;
  --bg-card: {p['bg_card']} !important;
  --bg-input: {p['bg_input']} !important;
  --bg-kbd: {p['bg_kbd']} !important;
  --border-app: {p['border_app']} !important;
  --border-card: {p['border_card']} !important;
  --border-kbd: {p['border_kbd']} !important;
  --text-fg: {p['text_fg']} !important;
  --text-muted: {p['text_muted']} !important;
  --accent: {p['accent']} !important;
  --accent-contrast: {p['accent_contrast']} !important;
  --cat-rice: {p['cat_rice']} !important;
  --cat-win: {p['cat_win']} !important;
  --cat-ws: {p['cat_ws']} !important;
  --cat-utils: {p['cat_utils']} !important;
  --danger: {p['danger']} !important;
  --danger-bg: {p['danger_bg']} !important;
  --danger-border: {p['danger_border']} !important;
}}
"""
    # 1. Write theme.css
    theme_css_path = os.path.expanduser("~/dotfiles/config/hypr/hud/theme.css")
    with open(theme_css_path, "w", encoding="utf-8") as f:
        f.write(css_vars)

    # 2. Directly embed into index.html to guarantee 0 cache issues
    index_html_path = os.path.expanduser("~/dotfiles/config/hypr/hud/index.html")
    if os.path.exists(index_html_path):
        with open(index_html_path, "r", encoding="utf-8") as f:
            content = f.read()

        pattern = re.compile(r'<style id="dynamic-theme">.*?</style>', re.DOTALL)
        replacement = f'<style id="dynamic-theme">\n{css_vars}</style>'
        if pattern.search(content):
            new_content = pattern.sub(replacement, content)
        else:
            # Insert before </head>
            new_content = content.replace("</head>", f"{replacement}\n</head>")

        with open(index_html_path, "w", encoding="utf-8") as f:
            f.write(new_content)

    return p['name']

if __name__ == "__main__":
    st = sync_all()
    print(f"Synced HUD with system theme: {st}")
