use gtk4::prelude::*;
use gtk4::{
    gdk, glib, Application, ApplicationWindow, Box as GtkBox, Button, EventControllerKey,
    FlowBox, FlowBoxChild, Label, Orientation, ScrolledWindow,
};
use serde::Deserialize;
use std::cell::RefCell;
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
    #[serde(default)]
    x: i32,
    #[serde(default)]
    y: i32,
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

#[derive(Clone, Debug)]
struct MonitorState {
    name: String,
    mode_str: String,
    scale: f64,
    x: i32,
    y: i32,
    pos_preset: String,
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

fn apply_all_monitors_config(states: &[MonitorState]) {
    let mut lua_blocks = Vec::new();

    for state in states {
        // Execute real-time via hyprctl eval (native Lua dispatcher in Hyprland)
        let eval_cmd = format!(
            "hl.monitor({{ output = \"{}\", mode = \"{}\", position = \"{}x{}\", scale = \"{}\" }})",
            state.name, state.mode_str, state.x, state.y, state.scale
        );
        let _ = Command::new("hyprctl").args(["eval", &eval_cmd]).output();

        // Also send legacy keyword if running with legacy parser
        let legacy_cmd = format!(
            "{},{},{}x{},{}",
            state.name, state.mode_str, state.x, state.y, state.scale
        );
        let _ = Command::new("hyprctl")
            .args(["keyword", "monitor", &legacy_cmd])
            .output();

        lua_blocks.push(format!(
            r#"hl.monitor({{
    output   = "{}",
    mode     = "{}",
    position = "{}x{}",
    scale    = "{}",
}})"#,
            state.name, state.mode_str, state.x, state.y, state.scale
        ));
    }

    // Persist all monitors cleanly to monitors.lua
    if let Ok(home) = std::env::var("HOME") {
        let path = PathBuf::from(&home).join("dotfiles/config/hypr/config/monitors.lua");
        let content = format!(
            r#"-- ==============================================================================
-- Soberano Monitor Configuration (Auto-configured by Super + M)
-- ==============================================================================

{}

-- Universal Fallback for any secondary displays or laptop screens
hl.monitor({{
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = "auto",
}})
"#,
            lua_blocks.join("\n\n")
        );
        let _ = fs::write(path, content);
    }

    let summary = states
        .iter()
        .map(|s| format!("{}: {} ({}x{})", s.name, s.mode_str, s.x, s.y))
        .collect::<Vec<_>>()
        .join("  |  ");

    let _ = Command::new("notify-send")
        .args([
            "-u",
            "normal",
            "-a",
            "Soberano Displays",
            "󰍹 Monitores Configurados",
            &summary,
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
            padding-bottom: 4px;
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
            margin-top: 10px;
            margin-bottom: 6px;
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
            padding: 12px 16px;
            margin: 4px;
            min-width: 170px;
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
            font-size: 14px;
            font-weight: 800;
            color: {window_fg};
        }}

        .hz-badge {{
            font-size: 12px;
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

        .chip-btn {{
            background-color: alpha({card_bg}, 0.75);
            border: 1px solid alpha({accent}, 0.20);
            border-radius: 12px;
            color: {window_fg};
            font-size: 12px;
            font-weight: 700;
            padding: 6px 12px;
            transition: all 150ms ease;
        }}

        .chip-btn:hover {{
            background-color: {card_hover_bg};
            color: {accent};
        }}

        .chip-btn.selected {{
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

    // Initialize per-monitor state
    let mut initial_states = Vec::new();
    for m in &monitors {
        initial_states.push(MonitorState {
            name: m.name.clone(),
            mode_str: format!("{}x{}@{:.2}", m.width, m.height, m.refresh_rate),
            scale: m.scale,
            x: m.x,
            y: m.y,
            pos_preset: "current".to_string(),
        });
    }
    let states = Rc::new(RefCell::new(initial_states));

    let window = ApplicationWindow::builder()
        .application(app)
        .title("Soberano Display Manager")
        .default_width(860)
        .default_height(640)
        .resizable(false)
        .decorated(false)
        .build();

    let card = GtkBox::new(Orientation::Vertical, 10);
    card.add_css_class("modal-card");
    card.set_width_request(840);
    card.set_height_request(600);
    window.set_child(Some(&card));

    // Header
    let handle = gtk4::WindowHandle::new();
    handle.set_cursor_from_name(Some("grab"));
    let header = GtkBox::new(Orientation::Horizontal, 12);
    header.add_css_class("draggable-header");
    handle.set_child(Some(&header));
    card.append(&handle);

    let header_texts = GtkBox::new(Orientation::Vertical, 3);
    let title = Label::new(Some("󰍹  Soberano Displays & Taxa de Atualização"));
    title.add_css_class("header-title");
    title.set_halign(gtk4::Align::Start);
    header_texts.append(&title);

    let subtitle = Label::new(Some(
        "Controle independente de taxa de atualização, resolução e posição para múltiplos monitores.",
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

    // Monitor Selector Chips (Tabs)
    let mon_chips_box = GtkBox::new(Orientation::Horizontal, 8);
    card.append(&mon_chips_box);

    let modes_container = GtkBox::new(Orientation::Vertical, 0);
    modes_container.set_vexpand(true);

    let scale_btn_box = GtkBox::new(Orientation::Horizontal, 6);
    let pos_btn_box = GtkBox::new(Orientation::Horizontal, 6);

    let rebuild_view: Rc<RefCell<Option<Box<dyn Fn()>>>> = Rc::new(RefCell::new(None));

    // Rebuild view closure
    {
        let monitors_clone = monitors.clone();
        let active_mon_idx_c = active_mon_idx.clone();
        let states_c = states.clone();
        let modes_container_c = modes_container.clone();
        let scale_btn_box_c = scale_btn_box.clone();
        let pos_btn_box_c = pos_btn_box.clone();

        *rebuild_view.borrow_mut() = Some(Box::new(move || {
            let idx = *active_mon_idx_c.borrow();
            let mon = &monitors_clone[idx];
            let current_state = states_c.borrow()[idx].clone();

            // 1. Rebuild Modes FlowBox
            while let Some(child) = modes_container_c.first_child() {
                modes_container_c.remove(&child);
            }

            let scroll = ScrolledWindow::builder()
                .hscrollbar_policy(gtk4::PolicyType::Never)
                .vscrollbar_policy(gtk4::PolicyType::Automatic)
                .vexpand(true)
                .build();

            let flow = FlowBox::new();
            flow.set_valign(gtk4::Align::Start);
            flow.set_max_children_per_line(4);
            flow.set_selection_mode(gtk4::SelectionMode::None);
            flow.set_row_spacing(6);
            flow.set_column_spacing(6);

            let parsed_modes = parse_modes(&mon.available_modes);

            for m in parsed_modes {
                let card_box = GtkBox::new(Orientation::Vertical, 4);
                card_box.add_css_class("mode-card");

                if m.raw_str == current_state.mode_str {
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
                let states_ref = states_c.clone();
                let active_idx_ref = active_mon_idx_c.clone();
                let flow_c = flow.clone();

                let gesture = gtk4::GestureClick::new();
                let card_clone = card_box.clone();
                gesture.connect_pressed(move |_, _, _, _| {
                    let cur_idx = *active_idx_ref.borrow();
                    states_ref.borrow_mut()[cur_idx].mode_str = raw.clone();

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

            // 2. Rebuild Scale Chips
            while let Some(child) = scale_btn_box_c.first_child() {
                scale_btn_box_c.remove(&child);
            }

            let scales = [
                (1.0, "100% (1.0x Padrão)"),
                (1.25, "125% (1.25x)"),
                (1.5, "150% (1.5x)"),
                (1.75, "175% (1.75x)"),
                (2.0, "200% (2.0x)"),
            ];

            for (sc, label) in scales {
                let btn = Button::with_label(label);
                btn.add_css_class("chip-btn");
                if (current_state.scale - sc).abs() < 0.05 {
                    btn.add_css_class("selected");
                }

                let sc_val = sc;
                let states_ref = states_c.clone();
                let active_idx_ref = active_mon_idx_c.clone();
                let scale_box_ref = scale_btn_box_c.clone();
                let btn_c = btn.clone();

                btn.connect_clicked(move |_| {
                    let cur_idx = *active_idx_ref.borrow();
                    states_ref.borrow_mut()[cur_idx].scale = sc_val;

                    let mut c = scale_box_ref.first_child();
                    while let Some(child) = c {
                        child.remove_css_class("selected");
                        c = child.next_sibling();
                    }
                    btn_c.add_css_class("selected");
                });
                scale_btn_box_c.append(&btn);
            }

            // 3. Rebuild Position Chips (if > 1 monitor)
            while let Some(child) = pos_btn_box_c.first_child() {
                pos_btn_box_c.remove(&child);
            }

            if monitors_clone.len() > 1 {
                let h = mon.height;
                let w = mon.width;

                let pos_presets = [
                    ("current", format!("Atual ({}x{})", current_state.x, current_state.y), current_state.x, current_state.y),
                    ("top", "⬆ Em Cima (0x-1080)".to_string(), 0, -h),
                    ("bottom", "⬇ Em Baixo (0x1080)".to_string(), 0, h),
                    ("right", "➡ À Direita (1920x0)".to_string(), w, 0),
                    ("left", "⬅ À Esquerda (-1920x0)".to_string(), -w, 0),
                    ("primary", "🎯 Principal (0x0)".to_string(), 0, 0),
                ];

                for (key, label, px, py) in pos_presets {
                    let btn = Button::with_label(&label);
                    btn.add_css_class("chip-btn");
                    if current_state.pos_preset == key || (current_state.pos_preset == "current" && key == "current") {
                        btn.add_css_class("selected");
                    }

                    let states_ref = states_c.clone();
                    let active_idx_ref = active_mon_idx_c.clone();
                    let pos_box_ref = pos_btn_box_c.clone();
                    let btn_c = btn.clone();
                    let key_str = key.to_string();

                    btn.connect_clicked(move |_| {
                        let cur_idx = *active_idx_ref.borrow();
                        {
                            let mut st = states_ref.borrow_mut();
                            st[cur_idx].x = px;
                            st[cur_idx].y = py;
                            st[cur_idx].pos_preset = key_str.clone();
                        }

                        let mut c = pos_box_ref.first_child();
                        while let Some(child) = c {
                            child.remove_css_class("selected");
                            c = child.next_sibling();
                        }
                        btn_c.add_css_class("selected");
                    });
                    pos_btn_box_c.append(&btn);
                }
            }
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
        let rebuild_c = rebuild_view.clone();

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
    if let Some(ref f) = *rebuild_view.borrow() {
        f();
    }

    // Modes section header
    let lbl_modes = Label::new(Some("Taxa de Atualização e Resoluções Disponíveis"));
    lbl_modes.add_css_class("section-label");
    lbl_modes.set_halign(gtk4::Align::Start);
    card.append(&lbl_modes);
    card.append(&modes_container);

    // Position Section (if multiple displays)
    if monitors.len() > 1 {
        let pos_box = GtkBox::new(Orientation::Horizontal, 8);
        let lbl_pos = Label::new(Some("Posição do Monitor:"));
        lbl_pos.add_css_class("section-label");
        lbl_pos.set_margin_top(0);
        lbl_pos.set_margin_bottom(0);
        pos_box.append(&lbl_pos);
        pos_box.append(&pos_btn_box);
        card.append(&pos_box);
    }

    // Scale Section
    let scale_box = GtkBox::new(Orientation::Horizontal, 8);
    let lbl_scale = Label::new(Some("Escala HiDPI:"));
    lbl_scale.add_css_class("section-label");
    lbl_scale.set_margin_top(0);
    lbl_scale.set_margin_bottom(0);
    scale_box.append(&lbl_scale);
    scale_box.append(&scale_btn_box);
    card.append(&scale_box);

    // Footer Action Buttons
    let footer = GtkBox::new(Orientation::Horizontal, 10);
    footer.set_margin_top(6);
    card.append(&footer);

    let btn_preferred = Button::with_label("⚡ Recomendado Automático");
    btn_preferred.add_css_class("action-btn-secondary");
    let win_c1 = window.clone();
    let states_c1 = states.clone();
    let active_idx_c1 = active_mon_idx.clone();

    btn_preferred.connect_clicked(move |_| {
        let cur_idx = *active_idx_c1.borrow();
        states_c1.borrow_mut()[cur_idx].mode_str = "preferred".to_string();
        apply_all_monitors_config(&states_c1.borrow());
        win_c1.close();
    });
    footer.append(&btn_preferred);

    let f_spacer = GtkBox::new(Orientation::Horizontal, 0);
    f_spacer.set_hexpand(true);
    footer.append(&f_spacer);

    let btn_apply = Button::with_label("✓ Aplicar e Salvar Configuração");
    btn_apply.add_css_class("action-btn-primary");
    let win_c2 = window.clone();
    let states_c2 = states.clone();

    btn_apply.connect_clicked(move |_| {
        apply_all_monitors_config(&states_c2.borrow());
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
