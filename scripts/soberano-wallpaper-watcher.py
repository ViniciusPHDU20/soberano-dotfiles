#!/usr/bin/env python3
"""
Soberano Live Wallpaper Smart Focus & Workspace Audio Watcher
Listens to Hyprland IPC socket2 events and dynamically manages
wallpaper audio mute/unmute states based on user preferences.
"""

import os
import sys
import json
import time
import socket
import select
import subprocess

CONFIG_PATH = os.path.expanduser("~/.config/soberano/livewallpaper.json")

def load_config():
    try:
        with open(CONFIG_PATH, "r") as f:
            return json.load(f)
    except Exception:
        return {
            "automute": False,
            "fullscreen_pause": True,
            "silent": False,
        }

def get_hypr_socket():
    sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
    xdg = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
    if not sig:
        try:
            entries = os.listdir(f"{xdg}/hypr")
            if entries:
                sig = entries[0]
        except Exception:
            pass
    if not sig:
        return None
    sock_path = f"{xdg}/hypr/{sig}/.socket2.sock"
    if os.path.exists(sock_path):
        return sock_path
    return None

def set_wallpaper_runtime_mute(mute: bool):
    mute_arg = "1" if mute else "0"
    script = os.path.expanduser("~/dotfiles/scripts/soberano-livewallpaper.sh")
    subprocess.run([script, "--runtime-mute", mute_arg], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

def get_active_workspace_info():
    try:
        res = subprocess.run(["hyprctl", "activeworkspace", "-j"], capture_output=True, text=True, timeout=0.3)
        if res.returncode == 0 and res.stdout.strip():
            return json.loads(res.stdout)
    except Exception:
        pass
    return None

def get_active_window_class():
    try:
        res = subprocess.run(["hyprctl", "activewindow", "-j"], capture_output=True, text=True, timeout=0.3)
        if res.returncode == 0 and res.stdout.strip():
            d = json.loads(res.stdout)
            return d.get("class") or ""
    except Exception:
        pass
    return ""

def main():
    sock_path = get_hypr_socket()
    if not sock_path:
        sys.exit(1)

    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    try:
        s.connect(sock_path)
    except Exception:
        sys.exit(1)

    last_mute_state = None

    while True:
        try:
            # Wake up on any Hyprland socket event or every 1.5s
            r, _, _ = select.select([s], [], [], 1.5)
            if r:
                data = s.recv(4096)
                if not data:
                    break

            cfg = load_config()

            # If user explicitly turned on "Mudo Total" in GUI, respect it
            if cfg.get("silent", False):
                if last_mute_state is not True:
                    set_wallpaper_runtime_mute(True)
                    last_mute_state = True
                continue

            automute = cfg.get("automute", False)
            fullscreen_pause = cfg.get("fullscreen_pause", True)

            ws_info = get_active_workspace_info()
            windows_count = ws_info.get("windows", 0) if ws_info else 0
            has_fullscreen = ws_info.get("hasfullscreen", False) if ws_info else False
            active_class = get_active_window_class()

            # Determine whether user is on clean desktop
            is_desktop = (windows_count == 0) or (active_class == "")

            should_mute = False

            if automute:
                # Automute mode: mute when focused on an active app window, unmute on desktop
                if not is_desktop:
                    should_mute = True
                else:
                    should_mute = False
            elif fullscreen_pause and has_fullscreen:
                should_mute = True

            if should_mute != last_mute_state:
                set_wallpaper_runtime_mute(should_mute)
                last_mute_state = should_mute

        except Exception:
            time.sleep(1.0)

if __name__ == "__main__":
    main()
