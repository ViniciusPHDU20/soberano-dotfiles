#!/usr/bin/env python3
# ==============================================================================
# Soberano Hardware Popover Menu (Native Wayle Popover Replica)
# Sits seamlessly right below the top bar (y=54), auto-dismisses on click outside
# or when clicking the bar icon again (toggle). Fixed position.
# ==============================================================================

import os
import sys
import socket
import subprocess
import glob
import re

import gi
gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")
gi.require_version("GtkLayerShell", "0.1")
from gi.repository import Gtk, Gdk, GtkLayerShell, GLib

SOCKET_PATH = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "soberano_hw_menu.sock")

def send_to_server(msg: str) -> bool:
    if not os.path.exists(SOCKET_PATH):
        return False
    try:
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s.connect(SOCKET_PATH)
        s.sendall(msg.encode("utf-8"))
        s.close()
        return True
    except Exception:
        try:
            os.remove(SOCKET_PATH)
        except OSError:
            pass
        return False

class HardwareDropdown(Gtk.Window):
    def __init__(self):
        super().__init__(type=Gtk.WindowType.TOPLEVEL)
        self.set_title("Hardware Popover")

        # Layer Shell Configuration - Fullscreen overlay for reliable click-outside dismiss
        GtkLayerShell.init_for_window(self)
        GtkLayerShell.set_layer(self, GtkLayerShell.Layer.TOP)
        GtkLayerShell.set_anchor(self, GtkLayerShell.Edge.TOP, True)
        GtkLayerShell.set_anchor(self, GtkLayerShell.Edge.BOTTOM, True)
        GtkLayerShell.set_anchor(self, GtkLayerShell.Edge.LEFT, True)
        GtkLayerShell.set_anchor(self, GtkLayerShell.Edge.RIGHT, True)
        GtkLayerShell.set_keyboard_mode(self, GtkLayerShell.KeyboardMode.ON_DEMAND)

        # Keyboard shortcuts and cleanup
        self.connect("key-press-event", self.on_key_press)
        self.connect("destroy", self.on_destroy)

        # Load Matugen Theme
        self.load_theme()
        self.build_ui()

        # Initial metrics & live periodic update
        self.update_metrics()
        self.timer_id = GLib.timeout_add(1200, self.update_metrics)

        # Start Unix Socket listener for single-instance toggle
        self.setup_socket()

    def load_theme(self):
        bg = "#1d2026"
        surface = "#282a31"
        accent = "#aac7ff"
        fg = "#e2e2e9"
        fg_muted = "#c4c6d0"

        hypr_colors = os.path.expanduser("~/dotfiles/config/hypr/config/colors_dynamic.lua")
        if os.path.exists(hypr_colors):
            try:
                with open(hypr_colors) as f:
                    content = f.read()
                    m = re.search(r'DYNAMIC_ACTIVE_1\s*=\s*"rgba\(([0-9a-fA-F]{6})', content)
                    if m:
                        accent = f"#{m.group(1)}"
                    m_bg = re.search(r'DYNAMIC_SURFACE\s*=\s*"rgba\(([0-9a-fA-F]{6})', content)
                    if m_bg:
                        bg = f"#{m_bg.group(1)}"
            except Exception:
                pass

        css = f"""
        window {{
            background-color: transparent;
        }}
        .popover-card {{
            background-color: alpha({bg}, 0.98);
            border: 1px solid alpha({accent}, 0.35);
            border-radius: 16px;
            padding: 14px 16px;
            box-shadow: 0 10px 30px rgba(0, 0, 0, 0.7);
        }}
        .header-title {{
            font-size: 13px;
            font-weight: 700;
            color: {fg};
        }}
        .metric-title {{
            font-size: 12px;
            font-weight: 700;
            color: {fg};
        }}
        .metric-sub {{
            font-size: 11px;
            font-weight: 600;
            color: {fg_muted};
        }}
        .metric-pct {{
            font-size: 12px;
            font-weight: 800;
            color: {accent};
        }}
        progressbar trough {{
            background: alpha({surface}, 0.9);
            border-radius: 6px;
            min-height: 8px;
        }}
        progressbar progress {{
            background: {accent};
            border-radius: 6px;
            min-height: 8px;
        }}
        .section-label {{
            font-size: 11px;
            font-weight: 800;
            color: {accent};
            margin-top: 6px;
        }}
        .proc-row {{
            background: alpha({surface}, 0.5);
            border-radius: 8px;
            padding: 5px 8px;
            margin-top: 3px;
        }}
        .proc-name {{
            font-size: 11px;
            font-weight: 600;
            color: {fg};
        }}
        .proc-pct {{
            font-size: 11px;
            font-weight: 800;
            color: {accent};
        }}
        .pill-btn {{
            background: alpha({surface}, 0.7);
            color: {fg};
            border: 1px solid alpha({accent}, 0.25);
            border-radius: 8px;
            padding: 5px 10px;
            font-size: 11px;
            font-weight: 600;
        }}
        .pill-btn:hover {{
            background: alpha({accent}, 0.25);
            color: #ffffff;
        }}
        """
        try:
            provider = Gtk.CssProvider()
            provider.load_from_data(css.encode("utf-8"))
            Gtk.StyleContext.add_provider_for_screen(
                Gdk.Screen.get_default(),
                provider,
                Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
            )
        except Exception as e:
            print("CSS loading notice:", e)

    def build_ui(self):
        # Transparent backdrop covering screen (click outside to dismiss)
        backdrop = Gtk.EventBox()
        backdrop.set_visible_window(False)
        backdrop.connect("button-press-event", lambda w, e: Gtk.main_quit())
        self.add(backdrop)

        container = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        backdrop.add(container)

        # Card Container placed seamlessly right against the top bar
        card_wrapper = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        card_wrapper.set_halign(Gtk.Align.END)
        card_wrapper.set_valign(Gtk.Align.START)
        # In layer coordinates (layer starts at y=50 below the exclusive bar):
        # 0px margin places it directly attached to the bar bottom edge (y=50)
        card_wrapper.set_margin_top(0)
        card_wrapper.set_margin_end(220)
        container.pack_start(card_wrapper, False, False, 0)

        # Actual Popover Card (catches its own clicks so clicks inside do not close)
        card_ev = Gtk.EventBox()
        card_ev.set_visible_window(False)
        card_ev.connect("button-press-event", lambda w, e: True)
        card_wrapper.pack_start(card_ev, False, False, 0)

        outer = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        outer.set_size_request(320, 360)
        outer.get_style_context().add_class("popover-card")
        card_ev.add(outer)

        # Header Bar (Fixed / Native Dropdown Style)
        header = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
        outer.pack_start(header, False, False, 0)

        title = Gtk.Label(label="󰍛  Hardware")
        title.get_style_context().add_class("header-title")
        header.pack_start(title, False, False, 0)

        # 1. CPU Row & Slider
        cpu_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=3)
        outer.pack_start(cpu_box, False, False, 0)

        cpu_top = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        cpu_lbl = Gtk.Label(label="CPU")
        cpu_lbl.get_style_context().add_class("metric-title")
        cpu_top.pack_start(cpu_lbl, False, False, 0)

        self.cpu_sub = Gtk.Label(label="-- GHz • -- °C")
        self.cpu_sub.get_style_context().add_class("metric-sub")
        self.cpu_sub.set_margin_start(8)
        cpu_top.pack_start(self.cpu_sub, False, False, 0)

        self.cpu_pct = Gtk.Label(label="0%")
        self.cpu_pct.get_style_context().add_class("metric-pct")
        cpu_top.pack_end(self.cpu_pct, False, False, 0)
        cpu_box.pack_start(cpu_top, False, False, 0)

        self.cpu_bar = Gtk.ProgressBar()
        cpu_box.pack_start(self.cpu_bar, False, False, 0)

        # 2. RAM Row & Slider
        ram_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=3)
        outer.pack_start(ram_box, False, False, 0)

        ram_top = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        ram_lbl = Gtk.Label(label="Memória")
        ram_lbl.get_style_context().add_class("metric-title")
        ram_top.pack_start(ram_lbl, False, False, 0)

        self.ram_sub = Gtk.Label(label="-- / -- GiB")
        self.ram_sub.get_style_context().add_class("metric-sub")
        self.ram_sub.set_margin_start(8)
        ram_top.pack_start(self.ram_sub, False, False, 0)

        self.ram_pct = Gtk.Label(label="0%")
        self.ram_pct.get_style_context().add_class("metric-pct")
        ram_top.pack_end(self.ram_pct, False, False, 0)
        ram_box.pack_start(ram_top, False, False, 0)

        self.ram_bar = Gtk.ProgressBar()
        ram_box.pack_start(self.ram_bar, False, False, 0)

        # 3. Disk Row & Slider
        disk_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=3)
        outer.pack_start(disk_box, False, False, 0)

        disk_top = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        disk_lbl = Gtk.Label(label="Disco (/)")
        disk_lbl.get_style_context().add_class("metric-title")
        disk_top.pack_start(disk_lbl, False, False, 0)

        self.disk_sub = Gtk.Label(label="-- livre")
        self.disk_sub.get_style_context().add_class("metric-sub")
        self.disk_sub.set_margin_start(8)
        disk_top.pack_start(self.disk_sub, False, False, 0)

        self.disk_pct = Gtk.Label(label="0%")
        self.disk_pct.get_style_context().add_class("metric-pct")
        disk_top.pack_end(self.disk_pct, False, False, 0)
        disk_box.pack_start(disk_top, False, False, 0)

        self.disk_bar = Gtk.ProgressBar()
        disk_box.pack_start(self.disk_bar, False, False, 0)

        # 4. Top Processes
        lbl_proc = Gtk.Label(label="Top Processos")
        lbl_proc.get_style_context().add_class("section-label")
        lbl_proc.set_halign(Gtk.Align.START)
        outer.pack_start(lbl_proc, False, False, 0)

        self.proc_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=3)
        outer.pack_start(self.proc_box, False, False, 0)

        # 5. Bottom Quick Actions
        footer = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
        footer.set_margin_top(6)
        outer.pack_start(footer, False, False, 0)

        btn_res = Gtk.Button(label="󰍹 Telas & Hz")
        btn_res.get_style_context().add_class("pill-btn")
        btn_res.connect("clicked", self.on_res_clicked)
        footer.pack_start(btn_res, True, True, 0)

        btn_up = Gtk.Button(label="󰚰 Atualizar")
        btn_up.get_style_context().add_class("pill-btn")
        btn_up.connect("clicked", self.on_update_clicked)
        footer.pack_start(btn_up, True, True, 0)

    def update_metrics(self):
        # 1. CPU
        try:
            with open("/proc/stat") as f:
                line = f.readline()
            fields = [float(x) for x in line.strip().split()[1:]]
            idle = fields[3] + fields[4]
            total = sum(fields)
            if hasattr(self, "_last_idle"):
                diff_idle = idle - self._last_idle
                diff_total = total - self._last_total
                usage = int(100.0 * (1.0 - diff_idle / max(1.0, diff_total)))
            else:
                usage = 5
            self._last_idle = idle
            self._last_total = total

            self.cpu_pct.set_text(f"{usage}%")
            self.cpu_bar.set_fraction(max(0.0, min(1.0, usage / 100.0)))
        except Exception:
            pass

        # CPU Freq & Temp
        freq_ghz = "4.0"
        try:
            with open("/proc/cpuinfo") as f:
                for line in f:
                    if "cpu MHz" in line:
                        mhz = float(line.split(":")[1])
                        freq_ghz = f"{mhz/1000.0:.2f}"
                        break
        except Exception:
            pass

        temp_c = "N/A"
        for p in glob.glob("/sys/class/hwmon/hwmon*/temp1_input"):
            try:
                with open(p) as f:
                    raw = int(f.read().strip())
                    if raw > 0:
                        temp_c = f"{raw // 1000}°C"
                        break
            except Exception:
                pass
        self.cpu_sub.set_text(f"{freq_ghz} GHz • {temp_c}")

        # 2. RAM
        try:
            mem = {}
            with open("/proc/meminfo") as f:
                for line in f:
                    parts = line.split(":")
                    if len(parts) == 2:
                        k = parts[0].strip()
                        v = int(parts[1].strip().split()[0])
                        mem[k] = v
            total_kb = mem.get("MemTotal", 1)
            avail_kb = mem.get("MemAvailable", 0)
            used_kb = total_kb - avail_kb
            ram_pct = int(used_kb * 100 / total_kb)
            used_gib = used_kb / 1024 / 1024
            total_gib = total_kb / 1024 / 1024

            self.ram_pct.set_text(f"{ram_pct}%")
            self.ram_sub.set_text(f"{used_gib:.1f} / {total_gib:.1f} GiB")
            self.ram_bar.set_fraction(max(0.0, min(1.0, ram_pct / 100.0)))
        except Exception:
            pass

        # 3. Disk
        try:
            out_df = subprocess.run(["df", "-h", "/"], capture_output=True, text=True)
            last = out_df.stdout.strip().splitlines()[-1].split()
            pct = int(last[4].replace("%", ""))
            self.disk_pct.set_text(f"{pct}%")
            self.disk_sub.set_text(f"{last[3]} livre")
            self.disk_bar.set_fraction(max(0.0, min(1.0, pct / 100.0)))
        except Exception:
            pass

        # 4. Top 2 processes
        try:
            out_ps = subprocess.run(
                ["ps", "-eo", "comm,%cpu", "--sort=-%cpu"],
                capture_output=True, text=True, timeout=1
            )
            lines = out_ps.stdout.splitlines()[1:3]
            for c in self.proc_box.get_children():
                self.proc_box.remove(c)
            for line in lines:
                parts = line.strip().split()
                if len(parts) >= 2:
                    name, cpu_p = parts[0], parts[1]
                    r = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
                    r.get_style_context().add_class("proc-row")
                    l_n = Gtk.Label(label=f"▸ {name[:18]}")
                    l_n.get_style_context().add_class("proc-name")
                    l_p = Gtk.Label(label=f"{cpu_p}%")
                    l_p.get_style_context().add_class("proc-pct")
                    r.pack_start(l_n, False, False, 0)
                    r.pack_end(l_p, False, False, 0)
                    self.proc_box.pack_start(r, False, False, 0)
            self.proc_box.show_all()
        except Exception:
            pass

        return True

    def on_res_clicked(self, widget):
        picker = os.path.expanduser("~/dotfiles/scripts/display-picker-rs")
        if os.path.exists(picker):
            subprocess.Popen([picker], start_new_session=True)
        else:
            subprocess.Popen(["bash", os.path.expanduser("~/dotfiles/scripts/MonitorSelect.sh")], start_new_session=True)
        Gtk.main_quit()

    def on_update_clicked(self, widget):
        subprocess.Popen(["bash", os.path.expanduser("~/dotfiles/scripts/soberano-update.sh")])

    def on_key_press(self, widget, event):
        if event.keyval == Gdk.KEY_Escape:
            Gtk.main_quit()
            return True
        return False

    def on_destroy(self, widget):
        if hasattr(self, "server_sock"):
            try:
                self.server_sock.close()
            except Exception:
                pass
        if os.path.exists(SOCKET_PATH):
            try:
                os.remove(SOCKET_PATH)
            except OSError:
                pass

    def setup_socket(self):
        if os.path.exists(SOCKET_PATH):
            try:
                os.remove(SOCKET_PATH)
            except OSError:
                pass
        self.server_sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.server_sock.bind(SOCKET_PATH)
        self.server_sock.listen(5)
        self.server_sock.setblocking(False)
        GLib.io_add_watch(self.server_sock.fileno(), GLib.IO_IN, self.handle_socket_client)

    def handle_socket_client(self, source, condition):
        try:
            conn, _ = self.server_sock.accept()
            data = conn.recv(1024).decode("utf-8").strip()
            conn.close()
            if data:
                # Toggle: clicking icon closes the open popover
                Gtk.main_quit()
        except Exception:
            pass
        return True

def main():
    if send_to_server("toggle"):
        sys.exit(0)

    win = HardwareDropdown()
    win.show_all()
    Gtk.main()

if __name__ == "__main__":
    main()
