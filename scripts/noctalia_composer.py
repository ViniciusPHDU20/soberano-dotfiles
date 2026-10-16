#!/usr/bin/env python3
"""
noctalia_composer.py - Orthogonal Style & Layout Composer for Noctalia Shell.
Merges Bar Styles (Skins, Palettes, Opacity, Colors) with Bar Layouts (Geometry, Position, Margins)
and Control Center Profiles (Cyber-Cockpit, Nordic-Minimal, Velvet-Cozy, Floating-Island, Auto-Sync).
Port of the JaKooLit WaybarStyles + WaybarLayout architecture.
"""
import sys
import os
import re
import subprocess

DOTFILES = os.path.expanduser("~/dotfiles")
CONFIG_DIR = os.path.join(DOTFILES, "config/noctalia")
STYLES_DIR = os.path.join(CONFIG_DIR, "styles")
LAYOUTS_DIR = os.path.join(CONFIG_DIR, "layouts")
CC_PRESETS_DIR = os.path.join(CONFIG_DIR, "presets/control_center")
TARGET_CONFIG = os.path.join(CONFIG_DIR, "config.toml")
USER_CONFIG = os.path.expanduser("~/.config/noctalia/config.toml")
WALLPAPERS_DIR = os.path.join(DOTFILES, "wallpapers")
SYNC_SCRIPT = os.path.join(DOTFILES, "scripts/DynamicThemeSync.sh")

STATE_DIR = os.path.expanduser("~/.config/noctalia")
STYLE_STATE_FILE = os.path.join(STATE_DIR, "active_style.txt")
LAYOUT_STATE_FILE = os.path.join(STATE_DIR, "active_layout.txt")
CC_STATE_FILE = os.path.join(STATE_DIR, "active_cc_style.txt")

WALLPAPER_MAP = {
    "Catppuccin-Mocha": "Pastel-Window.png",
    "Neon-Circuit-Cyberpunk": "Night_City.png",
    "Crystal-Clear-Glass": "Space-Nebula.png",
    "Dracula": "Purple-Nightmare.jpg",
    "Gruvbox-Retro": "Retro - Programmer.jpeg",
    "Nord-Frost": "Northern Lights3.png",
    "Tokyo-Night": "Tokyo_Pink.png",
    "Rose-Pine": "Dreamy-Aesthetic-Home-Under-Moonlight.png",
    "Kanagawa-Wave": "Fantasy-Japanese-Street.png",
    "Everforest-Natural": "Fog-Forest-Everforest.png",
    "Colorful-Chroma-Spectrum": "Under_Starlit_Sky.png",
    "Black-&-White-Monochrome": "Night monochrome.jpg",
    "Nordic-Slate": "Dark_Nature.png",
}

def get_active_style():
    if os.path.isfile(STYLE_STATE_FILE):
        with open(STYLE_STATE_FILE, "r") as f:
            val = f.read().strip()
            if val and os.path.isfile(os.path.join(STYLES_DIR, f"{val}.toml")):
                return val
    return "Neon-Circuit-Cyberpunk"

def get_active_layout():
    if os.path.isfile(LAYOUT_STATE_FILE):
        with open(LAYOUT_STATE_FILE, "r") as f:
            val = f.read().strip()
            if val and os.path.isfile(os.path.join(LAYOUTS_DIR, f"{val}.toml")):
                return val
    return "1. Top-Floating-Pill"

def get_active_cc_style():
    if os.path.isfile(CC_STATE_FILE):
        with open(CC_STATE_FILE, "r") as f:
            val = f.read().strip()
            if val:
                return val
    return "6. Auto-Sync-Theme"

def set_state(style=None, layout=None, cc_style=None):
    os.makedirs(STATE_DIR, exist_ok=True)
    if style:
        with open(STYLE_STATE_FILE, "w") as f:
            f.write(style + "\n")
    if layout:
        with open(LAYOUT_STATE_FILE, "w") as f:
            f.write(layout + "\n")
    if cc_style:
        with open(CC_STATE_FILE, "w") as f:
            f.write(cc_style + "\n")

def parse_style(style_path):
    with open(style_path, "r", encoding="utf-8") as f:
        content = f.read()

    m_border = re.search(r'^\s*border\s*=\s*"([^"]+)"', content, re.MULTILINE)
    border = m_border.group(1) if m_border else ""

    m_bw = re.search(r'^\s*border_width\s*=\s*([0-9.]+)', content, re.MULTILINE)
    border_width = float(m_bw.group(1)) if m_bw else 0.0

    m_bo = re.search(r'^\s*background_opacity\s*=\s*([0-9.]+)', content, re.MULTILINE)
    background_opacity = float(m_bo.group(1)) if m_bo else 0.92

    def extract_capsule_border(id_name, text):
        blocks = text.split("[[bar.")
        for b in blocks:
            if f'id = "{id_name}"' in b:
                m = re.search(r'border\s*=\s*"([^"]*)"', b)
                if m:
                    return m.group(1)
        return ""

    hw_border = extract_capsule_border("hw", content)
    netvol_border = extract_capsule_border("netvol", content)

    # All non-bar content starts at [shell]
    shell_idx = content.find("[shell]")
    non_bar_content = content[shell_idx:] if shell_idx != -1 else ""

    return {
        "border": border,
        "border_width": border_width,
        "background_opacity": background_opacity,
        "hw_border": hw_border,
        "netvol_border": netvol_border,
        "non_bar_content": non_bar_content,
        "is_glass": "Crystal-Clear-Glass" in style_path or border_width == 0.0
    }

def inject_capsule_border(id_name, new_border, text):
    pattern = r'(\[\[bar\.[^\]]+\.capsule_group\]\][^\[]*?border\s*=\s*")[^"]*("(?=[^\[]*?id\s*=\s*"' + id_name + '"))'
    return re.sub(pattern, r'\g<1>' + new_border + r'\g<2>', text, flags=re.DOTALL)

def overlay_control_center(non_bar_content, cc_preset_name):
    """Overlays an independent Control Center preset on non_bar_content while preserving theme colors and widgets."""
    if not cc_preset_name or "Auto-Sync" in cc_preset_name:
        return non_bar_content

    # Find preset file
    preset_path = os.path.join(CC_PRESETS_DIR, f"{cc_preset_name}.toml")
    if not os.path.isfile(preset_path):
        matches = glob_matches = [f for f in os.listdir(CC_PRESETS_DIR) if f.startswith(cc_preset_name)]
        if matches:
            preset_path = os.path.join(CC_PRESETS_DIR, matches[0])
        else:
            return non_bar_content

    with open(preset_path, "r", encoding="utf-8") as f:
        preset_content = f.read().strip()

    # In non_bar_content, find where [system.monitor] starts (marks the boundary where theme & widgets begin)
    sysmon_idx = non_bar_content.find("[system.monitor]")
    if sysmon_idx != -1:
        theme_and_widgets = non_bar_content[sysmon_idx:]
        return preset_content + "\n\n" + theme_and_widgets.strip()
    return non_bar_content

def compose_config(style_name, layout_name, cc_style_name=None):
    style_path = os.path.join(STYLES_DIR, f"{style_name}.toml")
    layout_path = os.path.join(LAYOUTS_DIR, f"{layout_name}.toml")

    if not os.path.isfile(style_path):
        raise FileNotFoundError(f"Estilo não encontrado: {style_path}")
    if not os.path.isfile(layout_path):
        raise FileNotFoundError(f"Layout não encontrado: {layout_path}")

    if cc_style_name is None:
        cc_style_name = get_active_cc_style()

    s = parse_style(style_path)
    with open(layout_path, "r", encoding="utf-8") as f:
        l_content = f.read()

    is_dual = "Dual-Bar-Split" in layout_name
    is_islands = "Floating-Islands" in layout_name

    eff_opacity = 0.0 if (is_islands or s["is_glass"]) else s["background_opacity"]

    # Overlay CC preset if not Auto-Sync
    final_non_bar = overlay_control_center(s["non_bar_content"], cc_style_name)

    if is_dual:
        lines = ["[accessibility]\nui_scale = 1.20\n\n"]
        cg_pos = l_content.find("[[bar.bottom.capsule_group]]")
        if cg_pos != -1:
            bar_part = l_content[:cg_pos]
            cg_part = l_content[cg_pos:]
        else:
            bar_part = l_content
            cg_part = ""

        bar_part = re.sub(r'border\s*=\s*"[^"]*"\n', '', bar_part)
        bar_part = re.sub(r'border_width\s*=\s*[0-9.]+\n', '', bar_part)
        bar_part = re.sub(r'background_opacity\s*=\s*[0-9.]+\n', '', bar_part)

        top_insert = f"background_opacity = {eff_opacity}\n"
        if s["border"] and s["border_width"] > 0 and not s["is_glass"]:
            top_insert += f'border = "{s["border"]}"\nborder_width = {s["border_width"]}\n'
        else:
            top_insert += 'border_width = 0.0\n'

        bot_insert = top_insert
        bar_part = bar_part.replace("[bar.top]", f"[bar.top]\n{top_insert.strip()}")
        bar_part = bar_part.replace("[bar.bottom]", f"[bar.bottom]\n{bot_insert.strip()}")

        if s["is_glass"]:
            cg_part = ""
        else:
            if s["hw_border"]:
                cg_part = inject_capsule_border("hw", s["hw_border"], cg_part)
            if s["netvol_border"]:
                cg_part = inject_capsule_border("netvol", s["netvol_border"], cg_part)

        cleaned_layout = bar_part.strip() + ("\n\n" + cg_part.strip() if cg_part.strip() else "")
        lines.append(cleaned_layout.strip() + "\n\n")
        lines.append(final_non_bar.strip() + "\n\n")

        discord_block = """[plugins]
enabled = [ "raycursive/discord-voice" ]

[plugin_settings."raycursive/discord-voice"]
discord_binary = "/usr/bin/vesktop"

[widget."raycursive/discord-voice:bar"]
show_channel_name = true
hide_when_disconnected = false
"""
        lines.append(discord_block.strip() + "\n")
        return "".join(lines)
    else:
        lines = ["[accessibility]\nui_scale = 1.20\n\n"]
        cg_pos = l_content.find("[[bar.default.capsule_group]]")
        if cg_pos != -1:
            bar_part = l_content[:cg_pos]
            cg_part = l_content[cg_pos:]
        else:
            bar_part = l_content
            cg_part = ""

        bar_part = re.sub(r'border\s*=\s*"[^"]*"\n', '', bar_part)
        bar_part = re.sub(r'border_width\s*=\s*[0-9.]+\n', '', bar_part)
        bar_part = re.sub(r'background_opacity\s*=\s*[0-9.]+\n', '', bar_part)

        bar_insert = f"background_opacity = {eff_opacity}\n"
        if s["border"] and s["border_width"] > 0 and not s["is_glass"]:
            bar_insert += f'border = "{s["border"]}"\nborder_width = {s["border_width"]}\n'
        else:
            bar_insert += 'border_width = 0.0\n'

        bar_part = bar_part.replace("[bar.default]", f"[bar.default]\n{bar_insert.strip()}")

        if s["is_glass"]:
            cg_part = ""
            bar_part = bar_part.replace('"group:hw", "group:netvol"', '"temp", "sysmon_2", "sysmon_3", "network", "volume", "raycursive/discord-voice:bar"')
        else:
            if s["hw_border"]:
                cg_part = inject_capsule_border("hw", s["hw_border"], cg_part)
            if s["netvol_border"]:
                cg_part = inject_capsule_border("netvol", s["netvol_border"], cg_part)

        cleaned_layout = bar_part.strip() + ("\n\n" + cg_part.strip() if cg_part.strip() else "")
        lines.append(cleaned_layout.strip() + "\n\n")
        lines.append(final_non_bar.strip() + "\n\n")
        
        discord_block = """[plugins]
enabled = [ "raycursive/discord-voice" ]

[plugin_settings."raycursive/discord-voice"]
discord_binary = "/usr/bin/vesktop"

[widget."raycursive/discord-voice:bar"]
show_channel_name = true
hide_when_disconnected = false
"""
        lines.append(discord_block.strip() + "\n")
        return "".join(lines)

def apply_composition(style_name, layout_name, cc_style_name=None, change_wallpaper=True):
    if cc_style_name is None:
        cc_style_name = get_active_cc_style()

    content = compose_config(style_name, layout_name, cc_style_name=cc_style_name)
    tmp_path = "/tmp/noctalia_composed_validate.toml"
    with open(tmp_path, "w", encoding="utf-8") as f:
        f.write(content)

    val = subprocess.run(["noctalia", "config", "validate", tmp_path], capture_output=True, text=True)
    if val.returncode != 0:
        print(f"Erro de validação:\n{val.stderr}", file=sys.stderr)
        return False

    with open(TARGET_CONFIG, "w", encoding="utf-8") as f:
        f.write(content)
    if os.path.exists(USER_CONFIG) and not os.path.samefile(TARGET_CONFIG, USER_CONFIG):
        with open(USER_CONFIG, "w", encoding="utf-8") as f:
            f.write(content)

    set_state(style=style_name, layout=layout_name, cc_style=cc_style_name)

    # Force instant Noctalia reload
    subprocess.run(["noctalia", "msg", "config-reload"], capture_output=True)

    if change_wallpaper and style_name in WALLPAPER_MAP:
        wall_file = os.path.join(WALLPAPERS_DIR, WALLPAPER_MAP[style_name])
        if os.path.isfile(wall_file):
            subprocess.run(["noctalia", "msg", "wallpaper-set", wall_file], capture_output=True)

    subprocess.run(["sleep", "0.2"])
    subprocess.run(["noctalia", "msg", "templates-apply"], capture_output=True)
    if os.path.isfile(SYNC_SCRIPT):
        subprocess.run(["bash", SYNC_SCRIPT], capture_output=True)

    return True

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Uso: noctalia_composer.py [get-style|get-layout|get-cc-style|set-style <nome>|set-layout <nome>|set-cc-style <nome>|recompose]")
        sys.exit(1)

    cmd = sys.argv[1]
    if cmd == "get-style":
        print(get_active_style())
    elif cmd == "get-layout":
        print(get_active_layout())
    elif cmd == "get-cc-style":
        print(get_active_cc_style())
    elif cmd == "set-style" and len(sys.argv) >= 3:
        target_style = sys.argv[2]
        curr_layout = get_active_layout()
        curr_cc = get_active_cc_style()
        if apply_composition(target_style, curr_layout, cc_style_name=curr_cc, change_wallpaper=True):
            clean_lay = curr_layout[3:] if curr_layout[0].isdigit() and curr_layout[1:3] == ". " else curr_layout
            subprocess.run(["noctalia", "msg", "notification-show", "Estilo Aplicado", f"Estilo: {target_style} | Layout: {clean_lay}"])
            print(f"Estilo {target_style} aplicado com layout {clean_lay}.")
        else:
            sys.exit(1)
    elif cmd == "set-layout" and len(sys.argv) >= 3:
        target_layout = sys.argv[2]
        curr_style = get_active_style()
        curr_cc = get_active_cc_style()
        if apply_composition(curr_style, target_layout, cc_style_name=curr_cc, change_wallpaper=False):
            clean_lay = target_layout[3:] if target_layout[0].isdigit() and target_layout[1:3] == ". " else target_layout
            subprocess.run(["noctalia", "msg", "notification-show", "Layout Aplicado", f"Layout: {clean_lay} | Estilo: {curr_style}"])
            print(f"Layout {clean_lay} aplicado com estilo {curr_style}.")
        else:
            sys.exit(1)
    elif cmd == "set-cc-style" and len(sys.argv) >= 3:
        target_cc = sys.argv[2]
        curr_style = get_active_style()
        curr_layout = get_active_layout()
        if apply_composition(curr_style, curr_layout, cc_style_name=target_cc, change_wallpaper=False):
            clean_cc = target_cc[3:] if target_cc[0].isdigit() and target_cc[1:3] == ". " else target_cc
            subprocess.run(["noctalia", "msg", "notification-show", "Control Center Atualizado", f"Perfil: {clean_cc}"])
            print(f"Control Center {clean_cc} aplicado com sucesso.")
        else:
            sys.exit(1)
    elif cmd == "recompose":
        apply_composition(get_active_style(), get_active_layout(), cc_style_name=get_active_cc_style(), change_wallpaper=False)
