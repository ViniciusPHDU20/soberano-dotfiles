#!/usr/bin/env python3
# ==============================================================================
# Soberano Native Hardware Dropdown Menu
# Native Wayland Layer-Shell Popover Menu (Material Design 3 / Wayle styled)
# Anchors cleanly below Wayle top bar, auto-dismisses on click-away / Escape.
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
    def __init__(self, initial_tab="cpu"):
        super().__init__(type=Gtk.WindowType.TOPLEVEL)
        self.set_title("Soberano Hardware Control")
        self.set_default_size(430, 530)
        self.set_resizable(False)

        # Layer Shell Configuration
        GtkLayerShell.init_for_window(self)
        GtkLayerShell.set_layer(self, GtkLayerShell.Layer.TOP)
        GtkLayerShell.set_anchor(self, GtkLayerShell.Edge.TOP, True)
        GtkLayerShell.set_anchor(self, GtkLayerShell.Edge.RIGHT, True)
        GtkLayerShell.set_margin(self, GtkLayerShell.Edge.TOP, 48)
        GtkLayerShell.set_margin(self, GtkLayerShell.Edge.RIGHT, 16)
        GtkLayerShell.set_keyboard_mode(self, GtkLayerShell.KeyboardMode.ON_DEMAND)

        # Dismiss on focus lost or Escape
        self.connect("focus-out-event", self.on_focus_out)
        self.connect("key-press-event", self.on_key_press)
        self.connect("destroy", self.on_destroy)

        # Read colors from Matugen
        self.load_theme()
        self.build_ui()

        # Select tab
        tab_map = {"cpu": 0, "ram": 1, "storage": 2, "disco": 2}
        target_name = initial_tab if initial_tab in tab_map else "cpu"
        self.switch_to_tab(target_name)

        # Initial metrics & periodic refresh
        self.update_metrics()
        self.timer_id = GLib.timeout_add(1500, self.update_metrics)

        # Start Unix Socket listener for single-instance toggle
        self.setup_socket()

    def load_theme(self):
        # Default Material Design 3 fallback palette
        bg = "#1a1110"
        surface = "#271d1c"
        surface_elevated = "#342624"
        accent = "#d18073"
        fg = "#f0dedc"
        fg_muted = "#a5918e"

        # Try reading from Matugen kitty or hypr colors
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
        .dropdown-card {{
            background-color: alpha({bg}, 0.95);
            border: 1px solid alpha({accent}, 0.35);
            border-radius: 20px;
            padding: 20px;
            box-shadow: 0 16px 40px rgba(0, 0, 0, 0.75);
        }}
        .header-title {{
            font-size: 16px;
            font-weight: 800;
            color: {fg};
            letter-spacing: 0.3px;
        }}
        .draggable-header {{
            cursor: grab;
        }}
        .draggable-header:active {{
            cursor: grabbing;
        }}
        .header-close {{
            background: alpha({surface}, 0.7);
            color: {fg_muted};
            border: 1px solid alpha({accent}, 0.25);
            border-radius: 50%;
            min-width: 28px;
            min-height: 28px;
            padding: 0;
            font-weight: 700;
            font-size: 13px;
        }}
        .header-close:hover {{
            background: {accent};
            color: #140c0b;
        }}
        .tab-btn {{
            background: alpha({surface}, 0.75);
            color: {fg_muted};
            border: 1px solid alpha({accent}, 0.25);
            border-radius: 12px;
            padding: 8px 16px;
            font-weight: 700;
            font-size: 13px;
            transition: all 150ms ease;
        }}
        .tab-btn:hover {{
            background: alpha({surface_elevated}, 0.9);
            color: {fg};
        }}
        .tab-btn:checked, .tab-btn:active {{
            background: {accent};
            color: #140c0b;
            border-color: {accent};
        }}
        .metric-big {{
            font-size: 34px;
            font-weight: 900;
            color: {accent};
            letter-spacing: -0.5px;
        }}
        .metric-subtitle {{
            font-size: 13px;
            font-weight: 600;
            color: {fg_muted};
        }}
        .spec-box {{
            background: alpha({surface}, 0.65);
            border: 1px solid alpha({accent}, 0.15);
            border-radius: 14px;
            padding: 12px 14px;
            margin-top: 8px;
            margin-bottom: 8px;
        }}
        .spec-label {{
            font-size: 12px;
            font-weight: 600;
            color: {fg_muted};
        }}
        .spec-val {{
            font-size: 13px;
            font-weight: 700;
            color: {fg};
        }}
        .section-header {{
            font-size: 12px;
            font-weight: 700;
            color: {accent};
            margin-top: 6px;
            margin-bottom: 4px;
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }}
        .proc-item {{
            background: alpha({surface}, 0.55);
            border: 1px solid alpha({accent}, 0.12);
            border-radius: 10px;
            padding: 8px 12px;
            margin-top: 4px;
        }}
        .proc-name {{
            font-size: 13px;
            font-weight: 700;
            color: {fg};
        }}
        .proc-badge {{
            font-size: 12px;
            font-weight: 800;
            color: {accent};
            background: alpha({accent}, 0.18);
            border-radius: 6px;
            padding: 3px 8px;
        }}
        progressbar trough {{
            background: alpha({surface}, 0.9);
            border-radius: 8px;
            min-height: 10px;
        }}
        progressbar progress {{
            background: {accent};
            border-radius: 8px;
            min-height: 10px;
        }}
        .action-btn {{
            background: alpha({accent}, 0.15);
            color: {accent};
            border: 1px solid alpha({accent}, 0.35);
            border-radius: 10px;
            padding: 8px 14px;
            font-size: 12px;
            font-weight: 700;
            transition: all 120ms ease;
        }}
        .action-btn:hover {{
            background: alpha({accent}, 0.3);
            color: {fg};
        }}
        """
        provider = Gtk.CssProvider()
        provider.load_from_data(css.encode("utf-8"))
        Gtk.StyleContext.add_provider_for_screen(
            Gdk.Screen.get_default(),
            provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )

    def build_ui(self):
        # Outer Card
        outer = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        outer.get_style_context().add_class("dropdown-card")
        self.add(outer)

        # Header Bar (Draggable)
        header_ev = Gtk.EventBox()
        header_ev.set_visible_window(False)
        header_ev.add_events(Gdk.EventMask.BUTTON_PRESS_MASK | Gdk.EventMask.BUTTON1_MOTION_MASK)
        header_ev.connect("button-press-event", self.on_header_drag_begin)
        header_ev.connect("motion-notify-event", self.on_header_drag_motion)
        header_ev.get_style_context().add_class("draggable-header")

        header = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        header_ev.add(header)
        outer.pack_start(header_ev, False, False, 0)

        title = Gtk.Label(label="󰍛  Hardware & Performance")
        title.get_style_context().add_class("header-title")
        header.pack_start(title, False, False, 0)

        header.pack_start(Gtk.Box(), True, True, 0) # Spacer

        btn_close = Gtk.Button(label="✕")
        btn_close.get_style_context().add_class("header-close")
        btn_close.connect("clicked", lambda w: Gtk.main_quit())
        header.pack_end(btn_close, False, False, 0)

        # Tab Segmented Switcher
        tab_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        tab_box.set_homogeneous(True)
        tab_box.set_margin_top(4)
        tab_box.set_margin_bottom(8)
        outer.pack_start(tab_box, False, False, 0)

        self.btn_cpu = Gtk.RadioButton.new_with_label(None, "󰍛  Processador")
        self.btn_cpu.set_mode(False)
        self.btn_cpu.get_style_context().add_class("tab-btn")
        self.btn_cpu.connect("toggled", lambda w: self.on_tab_toggled(w, "cpu"))
        tab_box.pack_start(self.btn_cpu, True, True, 0)

        self.btn_ram = Gtk.RadioButton.new_with_label_from_widget(self.btn_cpu, "󰘚  Memória")
        self.btn_ram.set_mode(False)
        self.btn_ram.get_style_context().add_class("tab-btn")
        self.btn_ram.connect("toggled", lambda w: self.on_tab_toggled(w, "ram"))
        tab_box.pack_start(self.btn_ram, True, True, 0)

        self.btn_storage = Gtk.RadioButton.new_with_label_from_widget(self.btn_cpu, "󰋊  Disco")
        self.btn_storage.set_mode(False)
        self.btn_storage.get_style_context().add_class("tab-btn")
        self.btn_storage.connect("toggled", lambda w: self.on_tab_toggled(w, "storage"))
        tab_box.pack_start(self.btn_storage, True, True, 0)

        # Stack Views
        self.stack = Gtk.Stack()
        self.stack.set_transition_type(Gtk.StackTransitionType.CROSSFADE)
        self.stack.set_transition_duration(180)
        outer.pack_start(self.stack, True, True, 0)

        # 1. CPU View
        self.cpu_view = self.create_cpu_view()
        self.stack.add_named(self.cpu_view, "cpu")

        # 2. RAM View
        self.ram_view = self.create_ram_view()
        self.stack.add_named(self.ram_view, "ram")

        # 3. Storage View
        self.storage_view = self.create_storage_view()
        self.stack.add_named(self.storage_view, "storage")

        # Footer Actions
        footer = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        footer.set_margin_top(8)
        outer.pack_start(footer, False, False, 0)

        btn_displays = Gtk.Button(label="󰍹  Telas & Hz (Super + M)")
        btn_displays.get_style_context().add_class("action-btn")
        btn_displays.connect("clicked", self.on_displays_clicked)
        footer.pack_start(btn_displays, True, True, 0)

        btn_update = Gtk.Button(label="󰚰  Atualizar Dotfiles")
        btn_update.get_style_context().add_class("action-btn")
        btn_update.connect("clicked", self.on_update_clicked)
        footer.pack_start(btn_update, True, True, 0)

    def on_displays_clicked(self, widget):
        Gtk.main_quit()
        picker = os.path.expanduser("~/dotfiles/scripts/display-picker-rs")
        if os.path.exists(picker):
            subprocess.Popen([picker])
        else:
            subprocess.Popen(["bash", os.path.expanduser("~/dotfiles/scripts/MonitorSelect.sh")])

    def on_header_drag_begin(self, widget, event):
        if event.button == 1:
            self._drag_start_x = event.x_root
            self._drag_start_y = event.y_root
            self._drag_init_top = GtkLayerShell.get_margin(self, GtkLayerShell.Edge.TOP)
            self._drag_init_right = GtkLayerShell.get_margin(self, GtkLayerShell.Edge.RIGHT)

    def on_header_drag_motion(self, widget, event):
        if hasattr(self, "_drag_start_x") and (event.state & Gdk.ModifierType.BUTTON1_MASK):
            dx = event.x_root - self._drag_start_x
            dy = event.y_root - self._drag_start_y
            new_top = int(self._drag_init_top + dy)
            new_right = int(self._drag_init_right - dx)
            GtkLayerShell.set_margin(self, GtkLayerShell.Edge.TOP, max(0, new_top))
            GtkLayerShell.set_margin(self, GtkLayerShell.Edge.RIGHT, max(0, new_right))

    def on_tab_toggled(self, button, name):
        if button.get_active():
            self.stack.set_visible_child_name(name)

    def create_cpu_view(self):
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)

        # Header with Big % and CPU Name
        top_h = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        self.cpu_big_label = Gtk.Label(label="0%")
        self.cpu_big_label.get_style_context().add_class("metric-big")
        top_h.pack_start(self.cpu_big_label, False, False, 0)

        right_col = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        right_col.set_halign(Gtk.Align.END)
        self.cpu_model_label = Gtk.Label(label="Processador")
        self.cpu_model_label.get_style_context().add_class("spec-val")
        self.cpu_threads_label = Gtk.Label(label="Threads Ativas")
        self.cpu_threads_label.get_style_context().add_class("metric-subtitle")
        right_col.pack_start(self.cpu_model_label, False, False, 0)
        right_col.pack_start(self.cpu_threads_label, False, False, 0)
        top_h.pack_end(right_col, False, False, 0)
        box.pack_start(top_h, False, False, 0)

        self.cpu_bar = Gtk.ProgressBar()
        box.pack_start(self.cpu_bar, False, False, 0)

        # Spec Card
        spec_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        spec_box.get_style_context().add_class("spec-box")
        box.pack_start(spec_box, False, False, 0)

        grid = Gtk.Grid()
        grid.set_column_spacing(24)
        grid.set_row_spacing(6)
        spec_box.pack_start(grid, True, True, 0)

        l_freq = Gtk.Label(label="Frequência Atual:")
        l_freq.get_style_context().add_class("spec-label")
        l_freq.set_halign(Gtk.Align.START)
        self.cpu_freq_val = Gtk.Label(label="-- GHz")
        self.cpu_freq_val.get_style_context().add_class("spec-val")
        self.cpu_freq_val.set_halign(Gtk.Align.START)

        l_temp = Gtk.Label(label="Temperatura:")
        l_temp.get_style_context().add_class("spec-label")
        l_temp.set_halign(Gtk.Align.START)
        self.cpu_temp_val = Gtk.Label(label="-- °C")
        self.cpu_temp_val.get_style_context().add_class("spec-val")
        self.cpu_temp_val.set_halign(Gtk.Align.START)

        l_arch = Gtk.Label(label="Arquitetura:")
        l_arch.get_style_context().add_class("spec-label")
        l_arch.set_halign(Gtk.Align.START)
        self.cpu_arch_val = Gtk.Label(label="x86_64")
        self.cpu_arch_val.get_style_context().add_class("spec-val")
        self.cpu_arch_val.set_halign(Gtk.Align.START)

        grid.attach(l_freq, 0, 0, 1, 1)
        grid.attach(self.cpu_freq_val, 1, 0, 1, 1)
        grid.attach(l_temp, 0, 1, 1, 1)
        grid.attach(self.cpu_temp_val, 1, 1, 1, 1)
        grid.attach(l_arch, 0, 2, 1, 1)
        grid.attach(self.cpu_arch_val, 1, 2, 1, 1)

        # Top processes section
        sub_title = Gtk.Label(label="Processos com Maior Carga")
        sub_title.get_style_context().add_class("section-header")
        sub_title.set_halign(Gtk.Align.START)
        box.pack_start(sub_title, False, False, 0)

        self.cpu_proc_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=5)
        box.pack_start(self.cpu_proc_box, True, True, 0)

        return box

    def create_ram_view(self):
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)

        # RAM Usage Header
        top_h = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        self.ram_big_label = Gtk.Label(label="0%")
        self.ram_big_label.get_style_context().add_class("metric-big")
        top_h.pack_start(self.ram_big_label, False, False, 0)

        self.ram_used_label = Gtk.Label(label="0 / 0 GiB")
        self.ram_used_label.get_style_context().add_class("spec-val")
        self.ram_used_label.set_halign(Gtk.Align.END)
        top_h.pack_end(self.ram_used_label, False, False, 0)
        box.pack_start(top_h, False, False, 0)

        self.ram_bar = Gtk.ProgressBar()
        box.pack_start(self.ram_bar, False, False, 0)

        # Spec Box
        spec_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        spec_box.get_style_context().add_class("spec-box")
        box.pack_start(spec_box, False, False, 0)

        swap_h = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        l_swap = Gtk.Label(label="Swap em Uso:")
        l_swap.get_style_context().add_class("spec-label")
        swap_h.pack_start(l_swap, False, False, 0)

        self.swap_val = Gtk.Label(label="-- GiB")
        self.swap_val.get_style_context().add_class("spec-val")
        swap_h.pack_end(self.swap_val, False, False, 0)
        spec_box.pack_start(swap_h, False, False, 0)

        self.swap_bar = Gtk.ProgressBar()
        spec_box.pack_start(self.swap_bar, False, False, 0)

        # Top processes section
        sub_title = Gtk.Label(label="Processos com Maior Consumo de Memória")
        sub_title.get_style_context().add_class("section-header")
        sub_title.set_halign(Gtk.Align.START)
        box.pack_start(sub_title, False, False, 0)

        self.ram_proc_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=5)
        box.pack_start(self.ram_proc_box, True, True, 0)

        return box

    def create_storage_view(self):
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)

        top_h = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        self.disk_big_label = Gtk.Label(label="0%")
        self.disk_big_label.get_style_context().add_class("metric-big")
        top_h.pack_start(self.disk_big_label, False, False, 0)

        self.disk_used_label = Gtk.Label(label="-- / --")
        self.disk_used_label.get_style_context().add_class("spec-val")
        top_h.pack_end(self.disk_used_label, False, False, 0)
        box.pack_start(top_h, False, False, 0)

        self.disk_bar = Gtk.ProgressBar()
        box.pack_start(self.disk_bar, False, False, 0)

        spec_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        spec_box.get_style_context().add_class("spec-box")
        box.pack_start(spec_box, False, False, 0)

        grid = Gtk.Grid()
        grid.set_column_spacing(24)
        grid.set_row_spacing(6)
        spec_box.pack_start(grid, True, True, 0)

        l_mount = Gtk.Label(label="Ponto de Montagem:")
        l_mount.get_style_context().add_class("spec-label")
        l_mount.set_halign(Gtk.Align.START)
        v_mount = Gtk.Label(label="/ (Raiz do Sistema)")
        v_mount.get_style_context().add_class("spec-val")
        v_mount.set_halign(Gtk.Align.START)

        l_avail = Gtk.Label(label="Espaço Livre:")
        l_avail.get_style_context().add_class("spec-label")
        l_avail.set_halign(Gtk.Align.START)
        self.disk_avail_val = Gtk.Label(label="--")
        self.disk_avail_val.get_style_context().add_class("spec-val")
        self.disk_avail_val.set_halign(Gtk.Align.START)

        grid.attach(l_mount, 0, 0, 1, 1)
        grid.attach(v_mount, 1, 0, 1, 1)
        grid.attach(l_avail, 0, 1, 1, 1)
        grid.attach(self.disk_avail_val, 1, 1, 1, 1)

        # Info Box
        info = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        info.get_style_context().add_class("spec-box")
        info.set_margin_top(8)
        lbl1 = Gtk.Label(label="󰋊  Monitoramento Ativo de Discos NVMe / SSD")
        lbl1.get_style_context().add_class("spec-val")
        lbl1.set_halign(Gtk.Align.START)
        info.pack_start(lbl1, False, False, 0)
        lbl2 = Gtk.Label(label="• Monitorando partição raiz com taxas I/O em tempo real.")
        lbl2.get_style_context().add_class("spec-label")
        lbl2.set_halign(Gtk.Align.START)
        info.pack_start(lbl2, False, False, 0)
        box.pack_start(info, False, False, 0)

        return box

    def update_metrics(self):
        # 1. Update CPU
        try:
            with open("/proc/stat") as f:
                line = f.readline()
            fields = [float(x) for x in line.strip().split()[1:]]
            idle = fields[3] + fields[4]
            total = sum(fields)
            if hasattr(self, "_last_cpu_total"):
                diff_idle = idle - self._last_cpu_idle
                diff_total = total - self._last_cpu_total
                usage = int(100.0 * (1.0 - diff_idle / max(1.0, diff_total)))
            else:
                usage = 5
            self._last_cpu_idle = idle
            self._last_cpu_total = total

            self.cpu_big_label.set_text(f"{usage}%")
            self.cpu_bar.set_fraction(max(0.0, min(1.0, usage / 100.0)))
        except Exception:
            pass

        # CPU Freq & Model
        try:
            with open("/proc/cpuinfo") as f:
                for line in f:
                    if "cpu MHz" in line:
                        mhz = float(line.split(":")[1])
                        self.cpu_freq_val.set_text(f"{mhz/1000.0:.2f} GHz")
                        break
                    elif "model name" in line and not hasattr(self, "_cpu_model_set"):
                        m_name = line.split(":")[1].strip()
                        m_name = re.sub(r' [0-9]+-Core.*', '', m_name)
                        m_name = re.sub(r' Processor| CPU|@.*', '', m_name)
                        self.cpu_model_label.set_text(m_name[:24])
                        n_cores = os.cpu_count() or 16
                        self.cpu_threads_label.set_text(f"{n_cores} Threads Ativas")
                        self._cpu_model_set = True
        except Exception:
            pass

        # CPU Temp
        temp_val = "N/A"
        for p in glob.glob("/sys/class/hwmon/hwmon*/temp1_input"):
            try:
                with open(p) as f:
                    raw = int(f.read().strip())
                    if raw > 0:
                        temp_val = f"{raw // 1000} °C"
                        break
            except Exception:
                pass
        self.cpu_temp_val.set_text(temp_val)

        # Top CPU Processes
        try:
            out = subprocess.run(
                ["ps", "-eo", "comm,%cpu", "--sort=-%cpu"],
                capture_output=True, text=True, timeout=1
            )
            lines = out.stdout.splitlines()[1:4]
            for c in self.cpu_proc_box.get_children():
                self.cpu_proc_box.remove(c)
            for line in lines:
                parts = line.strip().split()
                if len(parts) >= 2:
                    name, pct = parts[0], parts[1]
                    row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
                    row.get_style_context().add_class("proc-item")
                    l_name = Gtk.Label(label=f"▸  {name}")
                    l_name.get_style_context().add_class("proc-name")
                    l_badge = Gtk.Label(label=f"{pct}%")
                    l_badge.get_style_context().add_class("proc-badge")
                    row.pack_start(l_name, False, False, 0)
                    row.pack_end(l_badge, False, False, 0)
                    self.cpu_proc_box.pack_start(row, False, False, 0)
            self.cpu_proc_box.show_all()
        except Exception:
            pass

        # 2. Update RAM
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

            self.ram_big_label.set_text(f"{ram_pct}%")
            self.ram_used_label.set_text(f"{used_gib:.1f} / {total_gib:.1f} GiB")
            self.ram_bar.set_fraction(max(0.0, min(1.0, ram_pct / 100.0)))

            swap_total = mem.get("SwapTotal", 0)
            swap_free = mem.get("SwapFree", 0)
            swap_used = swap_total - swap_free
            if swap_total > 0:
                swap_pct = swap_used / swap_total
                self.swap_bar.set_fraction(max(0.0, min(1.0, swap_pct)))
                self.swap_val.set_text(f"{swap_used/1024/1024:.1f} / {swap_total/1024/1024:.1f} GiB")
            else:
                self.swap_bar.set_fraction(0.0)
                self.swap_val.set_text("Nenhum")

            # Top RAM Processes
            out_ram = subprocess.run(
                ["ps", "-eo", "comm,%mem", "--sort=-%mem"],
                capture_output=True, text=True, timeout=1
            )
            lines_ram = out_ram.stdout.splitlines()[1:4]
            for c in self.ram_proc_box.get_children():
                self.ram_proc_box.remove(c)
            for line in lines_ram:
                parts = line.strip().split()
                if len(parts) >= 2:
                    name, pct = parts[0], parts[1]
                    row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
                    row.get_style_context().add_class("proc-item")
                    l_name = Gtk.Label(label=f"▸  {name}")
                    l_name.get_style_context().add_class("proc-name")
                    l_badge = Gtk.Label(label=f"{pct}%")
                    l_badge.get_style_context().add_class("proc-badge")
                    row.pack_start(l_name, False, False, 0)
                    row.pack_end(l_badge, False, False, 0)
                    self.ram_proc_box.pack_start(row, False, False, 0)
            self.ram_proc_box.show_all()
        except Exception:
            pass

        # 3. Update Storage
        try:
            out_df = subprocess.run(["df", "-h", "/"], capture_output=True, text=True)
            last_line = out_df.stdout.strip().splitlines()[-1]
            parts = last_line.split()
            size, used, avail, pct_str = parts[1], parts[2], parts[3], parts[4].replace("%", "")
            pct = int(pct_str)
            self.disk_big_label.set_text(f"{pct}%")
            self.disk_used_label.set_text(f"{used} de {size}")
            self.disk_avail_val.set_text(f"{avail} livre")
            self.disk_bar.set_fraction(max(0.0, min(1.0, pct / 100.0)))
        except Exception:
            pass

        return True # Continue timer

    def on_update_clicked(self, widget):
        update_script = os.path.expanduser("~/dotfiles/scripts/soberano-update.sh")
        subprocess.Popen(["bash", update_script])

    def on_focus_out(self, widget, event):
        Gtk.main_quit()

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

            if not data:
                return True

            parts = data.split(":")
            cmd = parts[0]
            tab = parts[1] if len(parts) > 1 else "cpu"

            current_tab = self.stack.get_visible_child_name()
            if cmd == "toggle":
                if tab == current_tab:
                    Gtk.main_quit()
                else:
                    self.switch_to_tab(tab)
            elif cmd == "switch":
                self.switch_to_tab(tab)
            elif cmd == "close":
                Gtk.main_quit()
        except Exception:
            pass
        return True

    def switch_to_tab(self, tab):
        if tab == "cpu":
            self.btn_cpu.set_active(True)
            self.stack.set_visible_child_name("cpu")
        elif tab == "ram":
            self.btn_ram.set_active(True)
            self.stack.set_visible_child_name("ram")
        elif tab in ("storage", "disk", "disco"):
            self.btn_storage.set_active(True)
            self.stack.set_visible_child_name("storage")

def main():
    action = sys.argv[1] if len(sys.argv) > 1 else "toggle"
    tab = sys.argv[2] if len(sys.argv) > 2 else "cpu"

    if action in ("toggle", "switch", "close"):
        if send_to_server(f"{action}:{tab}"):
            sys.exit(0)

    # Otherwise start the server window
    win = HardwareDropdown(initial_tab=tab)
    win.show_all()
    Gtk.main()

if __name__ == "__main__":
    main()
