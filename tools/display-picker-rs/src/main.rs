use gtk4::prelude::*;
use gtk4::{
    gdk, glib, Application, ApplicationWindow, Box as GtkBox, Button, EventControllerKey,
    FlowBox, FlowBoxChild, Label, Orientation, ScrolledWindow,
};
use gtk4_layer_shell::{Edge, KeyboardMode, Layer, LayerShell};
use serde::Deserialize;
use std::cell::{Cell, RefCell};
use std::fs;
use std::path::PathBuf;
use std::process::Command;
use std::rc::Rc;

const APP_ID: &str = "org.soberano.displaypicker";

#[derive(Debug, Deserialize, Clone)]
struct MonitorRaw {
    name: String,
    description: Option<String>,
    width: i32,
    height: i32,
    #[serde(rename = "refreshRate")]
    refresh_rate: f64,
    scale: f64,
    #[serde(rename = "availableModes", default)]
    available_modes: Vec<String>,
}

#[derive(Clone, Debug, PartialEq)]
struct DisplayMode {
    width: i32,
    height: i32,
    refresh_rate: f64,
    tag: String,
    raw_str: String,
}

struct SystemColors {
    accent: String,
    window_bg: String,
    card_bg: String,
    window_fg: String,
}

fn hex_to_rgba(hex: &str, alpha: f32) -> String {
    let clean = hex.trim_start_matches('#');
    if clean.len() >= 6 {
        let r = u8::from_str_radix(&clean[0..2], 16).unwrap_or(209);
        let g = u8::from_str_radix(&clean[2..4], 16).unwrap_or(128);
        let b = u8::from_str_radix(&clean[4..6], 16).unwrap_or(115);
        format!("rgba({}, {}, {}, {})", r, g, b, alpha)
    } else {
        format!("rgba(209, 128, 115, {})", alpha)
    }
}

fn load_system_colors() -> SystemColors {
    let home = std::env::var("HOME").unwrap_or_else(|_| "/home/viniciusphdu".to_string());
    let colors_file = PathBuf::from(&home).join(".config/gtk-4.0/colors.css");

    let mut accent = "#d18073".to_string();
    let mut window_bg = "#1a1110".to_string();
    let mut card_bg = "#271d1c".to_string();
    let mut window_fg = "#f0dedc".to_string();

    if let Ok(content) = fs::read_to_string(&colors_file) {
        for line in content.lines() {
            let line = line.trim();
            if line.starts_with("@define-color accent_color") {
                if let Some(col) = line.split_whitespace().nth(2) {
                    accent = col.trim_matches(';').to_string();
                }
            } else if line.starts_with("@define-color window_bg_color") {
                if let Some(col) = line.split_whitespace().nth(2) {
                    window_bg = col.trim_matches(';').to_string();
                }
            } else if line.starts_with("@define-color card_bg_color") {
                if let Some(col) = line.split_whitespace().nth(2) {
                    card_bg = col.trim_matches(';').to_string();
                }
            } else if line.starts_with("@define-color window_fg_color") {
                if let Some(col) = line.split_whitespace().nth(2) {
                    window_fg = col.trim_matches(';').to_string();
                }
            }
        }
    }

    SystemColors {
        accent,
        window_bg,
        card_bg,
        window_fg,
    }
}

fn parse_modes(raw_modes: &[String]) -> Vec<DisplayMode> {
    let mut parsed = Vec::new();
    let re = regex_lite::Regex::new(r"(\d+)x(\d+)@([0-9.]+)Hz").unwrap_or_else(|_| {
        regex_lite::Regex::new(r"(\d+)x(\d+)@([0-9.]+)").unwrap()
    });

    for m in raw_modes {
        if let Some(caps) = re.captures(m) {
            let w: i32 = caps[1].parse().unwrap_or(0);
            let h: i32 = caps[2].parse().unwrap_or(0);
            let r: f64 = caps[3].parse().unwrap_or(60.0);

            if w > 0 && h > 0 {
                let tag = if r >= 144.0 {
                    "⚡ Gamer / Alta Taxa".to_string()
                } else if r >= 100.0 {
                    "🚀 Fluido".to_string()
                } else if r >= 75.0 {
                    "✨ Suave".to_string()
                } else {
                    "🖥️ Padrão".to_string()
                };

                parsed.push(DisplayMode {
                    width: w,
                    height: h,
                    refresh_rate: r,
                    tag,
                    raw_str: format!("{}x{}@{:.2}", w, h, r),
                });
            }
        }
    }

    // Sort: width desc, height desc, refresh_rate desc
    parsed.sort_by(|a, b| {
        b.width
            .cmp(&a.width)
            .then(b.height.cmp(&a.height))
            .then(b.refresh_rate.partial_cmp(&a.refresh_rate).unwrap())
    });

    // Deduplicate
    let mut unique = Vec::new();
    for mode in parsed {
        if !unique.iter().any(|u: &DisplayMode| {
            u.width == mode.width
                && u.height == mode.height
                && (u.refresh_rate - mode.refresh_rate).abs() < 0.2
        }) {
            unique.push(mode);
        }
    }
    unique
}

fn get_monitors() -> Vec<MonitorRaw> {
    if let Ok(out) = Command::new("hyprctl").args(["monitors", "-j"]).output() {
        if out.status.success() {
            if let Ok(monitors) = serde_json::from_slice::<Vec<MonitorRaw>>(&out.stdout) {
                return monitors;
            }
        }
    }
    Vec::new()
}

fn apply_monitor_config(mon_name: &str, mode_str: &str, scale: f64) {
    let apply_arg = if mode_str == "preferred" {
        format!("{},preferred,auto,{}", mon_name, scale)
    } else {
        format!("{},{},auto,{}", mon_name, mode_str, scale)
    };

    let _ = Command::new("hyprctl")
        .args(["keyword", "monitor", &apply_arg])
        .output();

    // Persist to monitors.lua
    if let Ok(home) = std::env::var("HOME") {
        let path = PathBuf::from(&home).join("dotfiles/config/hypr/config/monitors.lua");
        let content = format!(
            r#"-- ==============================================================================
-- Soberano Monitor Configuration (Auto-configured by Super + M)
-- ==============================================================================

hl.monitor({{
    output   = "{}",
    mode     = "{}",
    position = "0x0",
    scale    = "{}",
}})

-- Universal Fallback for any secondary displays or laptop screens
hl.monitor({{
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = "auto",
}})
"#,
            mon_name, mode_str, scale
        );
        let _ = fs::write(path, content);
    }

    let _ = Command::new("notify-send")
        .args([
            "-u",
            "normal",
            "-a",
            "Soberano Displays",
            "󰍹 Monitor Configurado",
            &format!("{}: {} (Escala {:.2}x)", mon_name, mode_str, scale),
        ])
        .output();
}

fn setup_css(colors: &SystemColors) {
    let provider = gtk4::CssProvider::new();
    let accent = &colors.accent;
    let window_bg = &colors.window_bg;
    let card_bg = &colors.card_bg;
    let window_fg = &colors.window_fg;

    let bg_rgba = hex_to_rgba(window_bg, 0.95);
    let card_bg_rgba = hex_to_rgba(card_bg, 0.70);
    let card_hover_bg = hex_to_rgba(card_bg, 0.95);
    let accent_border = hex_to_rgba(accent, 0.40);
    let accent_glow = hex_to_rgba(accent, 0.25);

    let css = format!(
        r#"
        window {{
            background-color: transparent;
        }}

        .modal-card {{
            background-color: {bg_rgba};
            border: 1px solid {accent_border};
            border-radius: 24px;
            padding: 24px;
            box-shadow: 0 20px 50px rgba(0, 0, 0, 0.8), 0 0 30px {accent_glow};
        }}

        .draggable-header {{
            cursor: grab;
            padding-bottom: 4px;
        }}

        .draggable-header:active {{
            cursor: grabbing;
        }}

        .header-title {{
            font-size: 18px;
            font-weight: 800;
            color: {window_fg};
            letter-spacing: 0.3px;
        }}

        .header-subtitle {{
            font-size: 13px;
            font-weight: 500;
            color: alpha({window_fg}, 0.6);
        }}

        .btn-close {{
            background-color: alpha({card_bg}, 0.8);
            border: 1px solid alpha({accent}, 0.3);
            border-radius: 12px;
            color: {window_fg};
            font-weight: 700;
            font-size: 13px;
            padding: 8px 16px;
            transition: all 160ms ease;
        }}

        .btn-close:hover {{
            background-color: #ff5450;
            border-color: #ff5450;
            color: #ffffff;
        }}

        .section-label {{
            font-size: 12px;
            font-weight: 800;
            color: {accent};
            text-transform: uppercase;
            letter-spacing: 0.8px;
            margin-top: 14px;
            margin-bottom: 8px;
        }}

        .display-tab-btn {{
            background-color: alpha({card_bg}, 0.8);
            border: 1px solid alpha({accent}, 0.25);
            border-radius: 12px;
            color: {window_fg};
            font-size: 13px;
            font-weight: 700;
            padding: 8px 18px;
            transition: all 150ms ease;
        }}

        .display-tab-btn.active {{
            background-color: {accent};
            border-color: {accent};
            color: #140c0b;
        }}

        .mode-card {{
            background-color: {card_bg_rgba};
            border: 1px solid alpha({accent}, 0.20);
            border-radius: 16px;
            padding: 14px 18px;
            margin: 6px;
            min-width: 175px;
            transition: all 180ms cubic-bezier(0.16, 1, 0.3, 1);
        }}

        .mode-card:hover {{
            background-color: {card_hover_bg};
            border-color: {accent};
            box-shadow: 0 8px 20px rgba(0, 0, 0, 0.5), 0 0 15px {accent_glow};
        }}

        .mode-card.selected {{
            background-color: alpha({accent}, 0.18);
            border: 2px solid {accent};
            box-shadow: 0 0 18px {accent_glow};
        }}

        .res-text {{
            font-size: 15px;
            font-weight: 800;
            color: {window_fg};
        }}

        .hz-badge {{
            font-size: 13px;
            font-weight: 800;
            color: {accent};
            background-color: alpha({accent}, 0.15);
            border-radius: 6px;
            padding: 3px 8px;
        }}

        .tag-text {{
            font-size: 11px;
            font-weight: 600;
            color: alpha({window_fg}, 0.55);
            margin-top: 4px;
        }}

        .scale-btn {{
            background-color: alpha({card_bg}, 0.75);
            border: 1px solid alpha({accent}, 0.20);
            border-radius: 12px;
            color: {window_fg};
            font-size: 12px;
            font-weight: 700;
            padding: 8px 14px;
            transition: all 150ms ease;
        }}

        .scale-btn:hover {{
            background-color: {card_hover_bg};
            color: {accent};
        }}

        .scale-btn.selected {{
            background-color: {accent};
            border-color: {accent};
            color: #140c0b;
        }}

        .action-btn-primary {{
            background-color: {accent};
            color: #140c0b;
            border: none;
            border-radius: 12px;
            font-size: 13px;
            font-weight: 800;
            padding: 10px 20px;
            box-shadow: 0 4px 16px {accent_glow};
            transition: all 150ms ease;
        }}

        .action-btn-primary:hover {{
            box-shadow: 0 6px 22px {accent_glow};
        }}

        .action-btn-secondary {{
            background-color: alpha({card_bg}, 0.85);
            color: {window_fg};
            border: 1px solid alpha({accent}, 0.35);
            border-radius: 12px;
            font-size: 13px;
            font-weight: 700;
            padding: 10px 18px;
        }}

        .action-btn-secondary:hover {{
            background-color: alpha({accent}, 0.20);
            color: {accent};
        }}

        scrolledwindow scrollbar.vertical {{
            background-color: transparent;
            min-width: 6px;
        }}
        scrolledwindow scrollbar.vertical slider {{
            background-color: alpha({accent}, 0.3);
            border-radius: 9999px;
            min-width: 6px;
        }}
        scrolledwindow scrollbar.vertical slider:hover {{
            background-color: {accent};
        }}
        "#
    );

    provider.load_from_string(&css);
    if let Some(display) = gdk::Display::default() {
        gtk4::style_context_add_provider_for_display(
            &display,
            &provider,
            gtk4::STYLE_PROVIDER_PRIORITY_USER,
        );
    }
}

fn build_ui(app: &Application) {
    let colors = load_system_colors();
    setup_css(&colors);

    let monitors = get_monitors();
    if monitors.is_empty() {
        eprintln!("No monitors found via hyprctl");
        return;
    }

    let active_mon_idx = Rc::new(RefCell::new(0usize));
    let selected_mode_str = Rc::new(RefCell::new(String::new()));
    let selected_scale = Rc::new(RefCell::new(monitors[0].scale));

    // Initialize current active mode
    let cur_w = monitors[0].width;
    let cur_h = monitors[0].height;
    let cur_r = monitors[0].refresh_rate;
    *selected_mode_str.borrow_mut() = format!("{}x{}@{:.2}", cur_w, cur_h, cur_r);

    let window = ApplicationWindow::builder()
        .application(app)
        .title("Soberano Display Manager")
        .default_width(840)
        .default_height(620)
        .resizable(false)
        .build();

    let mon_w = monitors[0].width;
    let mon_h = monitors[0].height;
    let win_w = 820;
    let win_h = 580;
    let init_left = (mon_w - win_w) / 2;
    let init_top = (mon_h - win_h) / 2;

    // Layer-Shell Setup
    window.init_layer_shell();
    window.set_layer(Layer::Overlay);
    window.set_keyboard_mode(KeyboardMode::Exclusive);
    window.set_anchor(Edge::Top, true);
    window.set_anchor(Edge::Left, true);
    window.set_anchor(Edge::Bottom, false);
    window.set_anchor(Edge::Right, false);
    window.set_margin(Edge::Left, init_left);
    window.set_margin(Edge::Top, init_top);

    // Modal Card
    let card = GtkBox::new(Orientation::Vertical, 12);
    card.add_css_class("modal-card");
    card.set_width_request(win_w);
    card.set_height_request(win_h);
    window.set_child(Some(&card));

    // Header (Draggable)
    let header = GtkBox::new(Orientation::Horizontal, 12);
    header.add_css_class("draggable-header");
    card.append(&header);

    // Header Drag Controller (Optimized Coalesced Motion - Zero Mouse Lag)
    let drag = gtk4::GestureDrag::new();
    let start_pos = Rc::new(Cell::new((init_left, init_top)));
    let cur_margin = Rc::new(Cell::new((init_left, init_top)));
    let pending_update = Rc::new(Cell::new(false));

    let start_pos_c1 = start_pos.clone();
    let cur_margin_c1 = cur_margin.clone();
    drag.connect_drag_begin(move |_, _, _| {
        let (cx, cy) = cur_margin_c1.get();
        start_pos_c1.set((cx, cy));
    });

    let win_drag2 = window.clone();
    let start_pos_c2 = start_pos.clone();
    let cur_margin_c2 = cur_margin.clone();
    let pending_c = pending_update.clone();

    drag.connect_drag_update(move |_, offset_x, offset_y| {
        let (sx, sy) = start_pos_c2.get();
        let nx = sx + offset_x as i32;
        let ny = sy + offset_y as i32;
        cur_margin_c2.set((nx, ny));

        if !pending_c.get() {
            pending_c.set(true);
            let win_ref = win_drag2.clone();
            let margin_ref = cur_margin_c2.clone();
            let pend_ref = pending_c.clone();
            glib::idle_add_local_once(move || {
                let (x, y) = margin_ref.get();
                win_ref.set_margin(Edge::Left, x);
                win_ref.set_margin(Edge::Top, y);
                pend_ref.set(false);
            });
        }
    });

    let win_drag3 = window.clone();
    let start_pos_c3 = start_pos.clone();
    let cur_margin_c3 = cur_margin.clone();
    drag.connect_drag_end(move |_, offset_x, offset_y| {
        let (sx, sy) = start_pos_c3.get();
        let nx = sx + offset_x as i32;
        let ny = sy + offset_y as i32;
        cur_margin_c3.set((nx, ny));
        win_drag3.set_margin(Edge::Left, nx);
        win_drag3.set_margin(Edge::Top, ny);
    });

    header.add_controller(drag);

    let header_texts = GtkBox::new(Orientation::Vertical, 3);
    let title = Label::new(Some("󰍹  Soberano Displays & Taxa de Atualização"));
    title.add_css_class("header-title");
    title.set_halign(gtk4::Align::Start);
    header_texts.append(&title);

    let subtitle = Label::new(Some(
        "Selecione a resolução nativa, taxa em Hertz (Hz) e escala HiDPI com aplicação em tempo real.",
    ));
    subtitle.add_css_class("header-subtitle");
    subtitle.set_halign(gtk4::Align::Start);
    header_texts.append(&subtitle);

    header.append(&header_texts);

    let spacer = GtkBox::new(Orientation::Horizontal, 0);
    spacer.set_hexpand(true);
    header.append(&spacer);

    let btn_close = Button::with_label("✕ Fechar (Esc)");
    btn_close.add_css_class("btn-close");
    let win_clone = window.clone();
    btn_close.connect_clicked(move |_| {
        win_clone.close();
    });
    header.append(&btn_close);

    // Monitor Selector Chips (if > 1)
    let mon_chips_box = GtkBox::new(Orientation::Horizontal, 8);
    card.append(&mon_chips_box);

    let modes_container = GtkBox::new(Orientation::Vertical, 0);
    modes_container.set_vexpand(true);

    let rebuild_modes: Rc<RefCell<Option<Box<dyn Fn()>>>> = Rc::new(RefCell::new(None));

    // Dynamic Mode builder
    {
        let monitors_clone = monitors.clone();
        let active_mon_idx_c = active_mon_idx.clone();
        let selected_mode_str_c = selected_mode_str.clone();
        let modes_container_c = modes_container.clone();

        *rebuild_modes.borrow_mut() = Some(Box::new(move || {
            // Clear existing
            while let Some(child) = modes_container_c.first_child() {
                modes_container_c.remove(&child);
            }

            let idx = *active_mon_idx_c.borrow();
            let mon = &monitors_clone[idx];
            let parsed_modes = parse_modes(&mon.available_modes);

            let scroll = ScrolledWindow::builder()
                .hscrollbar_policy(gtk4::PolicyType::Never)
                .vscrollbar_policy(gtk4::PolicyType::Automatic)
                .vexpand(true)
                .build();

            let flow = FlowBox::new();
            flow.set_valign(gtk4::Align::Start);
            flow.set_max_children_per_line(4);
            flow.set_selection_mode(gtk4::SelectionMode::None);
            flow.set_row_spacing(8);
            flow.set_column_spacing(8);

            let cur_selected = selected_mode_str_c.borrow().clone();

            for m in parsed_modes {
                let card_box = GtkBox::new(Orientation::Vertical, 4);
                card_box.add_css_class("mode-card");

                if m.raw_str == cur_selected {
                    card_box.add_css_class("selected");
                }

                let top_h = GtkBox::new(Orientation::Horizontal, 6);
                let lbl_res = Label::new(Some(&format!("{} × {}", m.width, m.height)));
                lbl_res.add_css_class("res-text");
                lbl_res.set_halign(gtk4::Align::Start);
                top_h.append(&lbl_res);

                let sp = GtkBox::new(Orientation::Horizontal, 0);
                sp.set_hexpand(true);
                top_h.append(&sp);

                let lbl_hz = Label::new(Some(&format!("{:.0} Hz", m.refresh_rate)));
                lbl_hz.add_css_class("hz-badge");
                top_h.append(&lbl_hz);
                card_box.append(&top_h);

                let lbl_tag = Label::new(Some(&m.tag));
                lbl_tag.add_css_class("tag-text");
                lbl_tag.set_halign(gtk4::Align::Start);
                card_box.append(&lbl_tag);

                let raw = m.raw_str.clone();
                let sel_ref = selected_mode_str_c.clone();
                let flow_c = flow.clone();

                let gesture = gtk4::GestureClick::new();
                let card_clone = card_box.clone();
                gesture.connect_pressed(move |_, _, _, _| {
                    *sel_ref.borrow_mut() = raw.clone();
                    // Update classes
                    let mut child = flow_c.first_child();
                    while let Some(c) = child {
                        if let Some(fb_child) = c.downcast_ref::<FlowBoxChild>() {
                            if let Some(inner) = fb_child.child() {
                                inner.remove_css_class("selected");
                            }
                        }
                        child = c.next_sibling();
                    }
                    card_clone.add_css_class("selected");
                });
                card_box.add_controller(gesture);

                flow.append(&card_box);
            }

            scroll.set_child(Some(&flow));
            modes_container_c.append(&scroll);
        }));
    }

    // Build Monitor Tabs
    for (i, m) in monitors.iter().enumerate() {
        let name_desc = if let Some(ref d) = m.description {
            format!("󰍹 {} ({})", m.name, d)
        } else {
            format!("󰍹 {}", m.name)
        };
        let tab_btn = Button::with_label(&name_desc);
        tab_btn.add_css_class("display-tab-btn");
        if i == 0 {
            tab_btn.add_css_class("active");
        }

        let active_mon_idx_c = active_mon_idx.clone();
        let mon_chips_box_c = mon_chips_box.clone();
        let tab_btn_c = tab_btn.clone();
        let rebuild_c = rebuild_modes.clone();

        tab_btn.connect_clicked(move |_| {
            *active_mon_idx_c.borrow_mut() = i;
            let mut c = mon_chips_box_c.first_child();
            while let Some(child) = c {
                child.remove_css_class("active");
                c = child.next_sibling();
            }
            tab_btn_c.add_css_class("active");
            if let Some(ref f) = *rebuild_c.borrow() {
                f();
            }
        });
        mon_chips_box.append(&tab_btn);
    }

    // Call initial rebuild
    if let Some(ref f) = *rebuild_modes.borrow() {
        f();
    }

    // Modes section header
    let lbl_modes = Label::new(Some("Taxa de Atualização e Resoluções Disponíveis"));
    lbl_modes.add_css_class("section-label");
    lbl_modes.set_halign(gtk4::Align::Start);
    card.append(&lbl_modes);
    card.append(&modes_container);

    // Scale Section
    let scale_box = GtkBox::new(Orientation::Horizontal, 8);
    let lbl_scale = Label::new(Some("Escala HiDPI:"));
    lbl_scale.add_css_class("section-label");
    lbl_scale.set_margin_top(0);
    lbl_scale.set_margin_bottom(0);
    scale_box.append(&lbl_scale);

    let scales = [
        (1.0, "100% (1.0x Padrão)"),
        (1.25, "125% (1.25x 2K)"),
        (1.5, "150% (1.5x 4K)"),
        (1.75, "175% (1.75x)"),
        (2.0, "200% (2.0x HiDPI)"),
    ];

    let scale_btn_box = GtkBox::new(Orientation::Horizontal, 6);
    let selected_scale_c = selected_scale.clone();

    for (sc, label) in scales {
        let btn = Button::with_label(label);
        btn.add_css_class("scale-btn");
        if (monitors[0].scale - sc).abs() < 0.05 {
            btn.add_css_class("selected");
        }

        let sc_val = sc;
        let sel_sc_ref = selected_scale_c.clone();
        let scale_btn_box_c = scale_btn_box.clone();
        let btn_c = btn.clone();

        btn.connect_clicked(move |_| {
            *sel_sc_ref.borrow_mut() = sc_val;
            let mut c = scale_btn_box_c.first_child();
            while let Some(child) = c {
                child.remove_css_class("selected");
                c = child.next_sibling();
            }
            btn_c.add_css_class("selected");
        });
        scale_btn_box.append(&btn);
    }
    scale_box.append(&scale_btn_box);
    card.append(&scale_box);

    // Footer Action Buttons
    let footer = GtkBox::new(Orientation::Horizontal, 10);
    footer.set_margin_top(8);
    card.append(&footer);

    let btn_preferred = Button::with_label("⚡ Recomendado Automático");
    btn_preferred.add_css_class("action-btn-secondary");
    let win_c1 = window.clone();
    let mon_list_c1 = monitors.clone();
    let active_idx_c1 = active_mon_idx.clone();
    let scale_ref_c1 = selected_scale.clone();

    btn_preferred.connect_clicked(move |_| {
        let idx = *active_idx_c1.borrow();
        let mon_name = &mon_list_c1[idx].name;
        let sc = *scale_ref_c1.borrow();
        apply_monitor_config(mon_name, "preferred", sc);
        win_c1.close();
    });
    footer.append(&btn_preferred);

    let f_spacer = GtkBox::new(Orientation::Horizontal, 0);
    f_spacer.set_hexpand(true);
    footer.append(&f_spacer);

    let btn_apply = Button::with_label("✓ Aplicar e Salvar Configuração");
    btn_apply.add_css_class("action-btn-primary");
    let win_c2 = window.clone();
    let mon_list_c2 = monitors.clone();
    let active_idx_c2 = active_mon_idx.clone();
    let mode_ref_c2 = selected_mode_str.clone();
    let scale_ref_c2 = selected_scale.clone();

    btn_apply.connect_clicked(move |_| {
        let idx = *active_idx_c2.borrow();
        let mon_name = &mon_list_c2[idx].name;
        let mode = mode_ref_c2.borrow().clone();
        let sc = *scale_ref_c2.borrow();
        let final_mode = if mode.is_empty() { "preferred" } else { &mode };
        apply_monitor_config(mon_name, final_mode, sc);
        win_c2.close();
    });
    footer.append(&btn_apply);

    // Escape Key Controller
    let key_controller = EventControllerKey::new();
    let win_c3 = window.clone();
    key_controller.connect_key_pressed(move |_, keyval, _, _| {
        if keyval == gdk::Key::Escape {
            win_c3.close();
            glib::Propagation::Stop
        } else {
            glib::Propagation::Proceed
        }
    });
    window.add_controller(key_controller);

    window.present();
}

fn main() {
    let app = Application::builder().application_id(APP_ID).build();
    app.connect_activate(build_ui);
    app.run();
}
