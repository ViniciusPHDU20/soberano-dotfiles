#!/usr/bin/env python3
"""
noctalia_layout_manager.py - Manages and applies Noctalia bar layouts dynamically.
Port of JaKooLit WaybarLayout system to native Noctalia architecture.
"""
import sys
import os
import re
import subprocess

DOTFILES = os.path.expanduser("~/dotfiles")
CONFIG_PATH = os.path.join(DOTFILES, "config/noctalia/config.toml")
USER_CONFIG_PATH = os.path.expanduser("~/.config/noctalia/config.toml")
LAYOUTS_DIR = os.path.join(DOTFILES, "config/noctalia/layouts")

def list_layouts():
    files = sorted(os.listdir(LAYOUTS_DIR))
    layouts = []
    for f in files:
        if f.endswith(".toml"):
            clean = f[:-5]
            if clean[0].isdigit() and clean[1:3] == ". ":
                clean = clean[3:]
            layouts.append((f, clean))
    return layouts

def apply_layout(layout_filename):
    layout_file = os.path.join(LAYOUTS_DIR, layout_filename)
    if not os.path.isfile(layout_file):
        print(f"Error: layout file {layout_file} not found", file=sys.stderr)
        return False

    with open(CONFIG_PATH, "r", encoding="utf-8") as f:
        current_content = f.read()

    # Extract theme border color
    border_match = re.search(r'border\s*=\s*"([^"]+)"', current_content)
    current_border = border_match.group(1) if border_match else ""

    # Extract capsule group borders
    hw_border_match = re.search(r'\[\[bar\.[^\]]+\.capsule_group\]\]\s*\nborder\s*=\s*"([^"]+)"\s*\nfill\s*=\s*"[^"]+"\s*\nid\s*=\s*"hw"', current_content)
    hw_border = hw_border_match.group(1) if hw_border_match else ""

    netvol_border_match = re.search(r'\[\[bar\.[^\]]+\.capsule_group\]\]\s*\nborder\s*=\s*"([^"]+)"\s*\nfill\s*=\s*"[^"]+"\s*\nid\s*=\s*"netvol"', current_content)
    netvol_border = netvol_border_match.group(1) if netvol_border_match else ""

    # Extract non-bar sections: [shell] onwards
    shell_idx = current_content.find("[shell]")
    if shell_idx != -1:
        non_bar_content = current_content[shell_idx:]
    else:
        non_bar_content = ""

    # Extract accessibility section
    accessibility_idx = current_content.find("[accessibility]")
    bar_start = current_content.find("[bar.")
    if accessibility_idx != -1 and accessibility_idx < bar_start:
        accessibility_content = current_content[accessibility_idx:bar_start].strip() + "\n\n"
    else:
        accessibility_content = "[accessibility]\nui_scale = 1.20\n\n"

    with open(layout_file, "r", encoding="utf-8") as f:
        layout_content = f.read()

    # Replace border placeholders with current active theme colors
    if current_border:
        layout_content = re.sub(r'border\s*=\s*""', f'border = "{current_border}"', layout_content)
    if hw_border:
        layout_content = layout_content.replace('border = ""\n    fill = "on_secondary"\n    id = "hw"', f'border = "{hw_border}"\n    fill = "on_secondary"\n    id = "hw"')
    if netvol_border:
        layout_content = layout_content.replace('border = ""\n    fill = "on_secondary"\n    id = "netvol"', f'border = "{netvol_border}"\n    fill = "on_secondary"\n    id = "netvol"')

    full_merged = accessibility_content + layout_content.strip() + "\n\n" + non_bar_content.strip() + "\n"

    # Temporary validation
    tmp_path = "/tmp/noctalia_layout_validate.toml"
    with open(tmp_path, "w", encoding="utf-8") as f:
        f.write(full_merged)

    val = subprocess.run(["noctalia", "config", "validate", tmp_path], capture_output=True, text=True)
    if val.returncode != 0:
        print(f"Validation failed:\n{val.stderr}", file=sys.stderr)
        return False

    # Write to target and user config
    with open(CONFIG_PATH, "w", encoding="utf-8") as f:
        f.write(full_merged)
    if os.path.exists(USER_CONFIG_PATH) and not os.path.samefile(CONFIG_PATH, USER_CONFIG_PATH):
        with open(USER_CONFIG_PATH, "w", encoding="utf-8") as f:
            f.write(full_merged)

    return True

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: noctalia_layout_manager.py [list|apply <filename>]")
        sys.exit(1)

    cmd = sys.argv[1]
    if cmd == "list":
        for fname, clean in list_layouts():
            print(f"{fname}\t{clean}")
    elif cmd == "apply" and len(sys.argv) >= 3:
        target = sys.argv[2]
        if apply_layout(target):
            sys.exit(0)
        else:
            sys.exit(1)
