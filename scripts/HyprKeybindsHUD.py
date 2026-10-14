#!/usr/bin/env python3
"""
HyprKeybindsHUD.py - Lightweight Native WebKitGTK Glass HUD for Keybindings.
Uses WebKit2GTK (Tauri runtime engine) on Wayland.
"""
import sys
import os
import signal
import gi

gi.require_version("Gtk", "3.0")
gi.require_version("WebKit2", "4.1")
from gi.repository import Gtk, WebKit2, Gdk, GLib

PID_FILE = "/tmp/hypr_keybinds_hud.pid"
HTML_PATH = os.path.expanduser("~/dotfiles/config/hypr/hud/index.html")

def check_singleton():
    if os.path.exists(PID_FILE):
        try:
            with open(PID_FILE, "r") as f:
                pid = int(f.read().strip())
            os.kill(pid, signal.SIGTERM)
            os.remove(PID_FILE)
            sys.exit(0)
        except (ProcessLookupError, ValueError):
            pass
        except Exception:
            pass

    with open(PID_FILE, "w") as f:
        f.write(str(os.getpid()))

def cleanup():
    if os.path.exists(PID_FILE):
        try:
            os.remove(PID_FILE)
        except Exception:
            pass

class KeybindsHUDWindow(Gtk.Window):
    def __init__(self):
        super().__init__(type=Gtk.WindowType.TOPLEVEL)
        self.set_wmclass("hypr-keybinds-hud", "hypr-keybinds-hud")
        self.set_title("Atalhos do Sistema")
        self.set_decorated(False)
        self.set_default_size(1080, 780)
        self.set_position(Gtk.WindowPosition.CENTER)

        # Transparent RGBA visual
        screen = self.get_screen()
        visual = screen.get_rgba_visual()
        if visual:
            self.set_visual(visual)
        self.set_app_paintable(True)

        # WebKit User Content Manager for JS -> Python bridge
        content_manager = WebKit2.UserContentManager()
        content_manager.register_script_message_handler("closeHandler")
        content_manager.connect("script-message-received::closeHandler", self.on_close_requested)

        # WebKit WebView
        self.webview = WebKit2.WebView.new_with_user_content_manager(content_manager)
        self.webview.set_background_color(Gdk.RGBA(0, 0, 0, 0))

        # Settings
        settings = self.webview.get_settings()
        settings.set_enable_javascript(True)
        settings.set_enable_developer_extras(False)

        # Load local HTML file
        if os.path.exists(HTML_PATH):
            self.webview.load_uri(f"file://{HTML_PATH}")
        else:
            self.webview.load_html("<h1>Erro: index.html não encontrado</h1>", "file:///")

        self.add(self.webview)
        self.connect("destroy", self.on_destroy)
        self.connect("key-press-event", self.on_key_press)

    def on_close_requested(self, user_content_manager, message):
        self.close_window()

    def on_key_press(self, widget, event):
        if event.keyval == Gdk.KEY_Escape:
            self.close_window()
            return True
        return False

    def close_window(self):
        cleanup()
        self.destroy()
        Gtk.main_quit()

    def on_destroy(self, widget):
        cleanup()
        Gtk.main_quit()

if __name__ == "__main__":
    check_singleton()
    Gtk.init(sys.argv)

    win = KeybindsHUDWindow()
    win.show_all()
    Gtk.main()
