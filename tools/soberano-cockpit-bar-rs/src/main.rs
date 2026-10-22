use glib::ControlFlow;
use gtk4::prelude::*;
use gtk4::{
    Application, Box as GtkBox, Button, Calendar, CenterBox, EventControllerScroll,
    EventControllerScrollFlags, GestureClick, Label, Orientation, ScrolledWindow, Window,
};
use gtk4_layer_shell::{Edge, Layer, LayerShell};
use std::process::Command;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;

const APP_ID: &str = "org.soberano.cockpit.bottombar";

#[derive(Clone)]
struct NotificationItem {
    id: u32,
    app: String,
    title: String,
    body: String,
}

fn main() {
    let app = Application::builder().application_id(APP_ID).build();

    app.connect_activate(build_ui);
    app.run_with_args(&Vec::<String>::new());
}

fn get_system_volume() -> (u32, bool) {
    let output = Command::new("wpctl")
        .args(["get-volume", "@DEFAULT_AUDIO_SINK@"])
        .output();

    if let Ok(out) = output {
        let s = String::from_utf8_lossy(&out.stdout);
        let is_muted = s.contains("[MUTED]");
        let parts: Vec<&str> = s.split_whitespace().collect();
        if parts.len() >= 2 {
            if let Ok(vol_f) = parts[1].parse::<f32>() {
                return ((vol_f * 100.0).round() as u32, is_muted);
            }
        }
    }
    (100, false)
}

fn adjust_volume(step: i32) {
    let sign = if step > 0 { "+" } else { "-" };
    let abs = step.abs();
    let _ = Command::new("wpctl")
        .args(["set-volume", "@DEFAULT_AUDIO_SINK@", &format!("{}%{}", abs, sign)])
        .spawn();
}

fn toggle_mute() {
    let _ = Command::new("wpctl")
        .args(["set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"])
        .spawn();
}

fn get_network_info() -> (&'static str, String) {
    if let Ok(out) = Command::new("nmcli")
        .args(["-t", "-f", "TYPE,STATE,CONNECTION", "dev"])
        .output()
    {
        let s = String::from_utf8_lossy(&out.stdout);
        for line in s.lines() {
            let parts: Vec<&str> = line.split(':').collect();
            if parts.len() >= 3 && parts[1] == "connected" {
                if parts[0] == "ethernet" {
                    return ("󰈀", "ETH".to_string());
                } else if parts[0] == "wifi" {
                    return ("󰤨", parts[2].to_string());
                }
            }
        }
    }
    ("󰤭", "OFF".to_string())
}

fn get_notification_count() -> u32 {
    if let Ok(out) = Command::new("wayle").args(["notify", "status"]).output() {
        let s = String::from_utf8_lossy(&out.stdout);
        for line in s.lines() {
            if line.starts_with("Notifications:") {
                if let Some(cnt) = line.split(':').nth(1) {
                    if let Ok(num) = cnt.trim().parse::<u32>() {
                        return num;
                    }
                }
            }
        }
    }
    0
}

fn fetch_notifications() -> Vec<NotificationItem> {
    let mut list = Vec::new();
    if let Ok(out) = Command::new("wayle").args(["notify", "list"]).output() {
        let s = String::from_utf8_lossy(&out.stdout);
        let mut cur_id = 0u32;
        let mut cur_app = String::new();
        let mut cur_title = String::new();
        let mut cur_body = String::new();

        for line in s.lines() {
            let trimmed = line.trim();
            if trimmed.is_empty() || trimmed == "Notifications:" {
                continue;
            }
            if trimmed.starts_with('[') && trimmed.contains(']') {
                if cur_id > 0 {
                    list.push(NotificationItem {
                        id: cur_id,
                        app: cur_app.clone(),
                        title: cur_title.clone(),
                        body: cur_body.trim().to_string(),
                    });
                    cur_body.clear();
                }
                if let Some(end_bracket) = trimmed.find(']') {
                    let id_str = &trimmed[1..end_bracket];
                    cur_id = id_str.parse::<u32>().unwrap_or(0);
                    let rest = trimmed[end_bracket + 1..].trim();
                    if let Some(colon) = rest.find(':') {
                        cur_app = rest[..colon].trim().to_string();
                        cur_title = rest[colon + 1..].trim().to_string();
                    } else {
                        cur_app = "App".to_string();
                        cur_title = rest.to_string();
                    }
                }
            } else if cur_id > 0 {
                if !cur_body.is_empty() {
                    cur_body.push(' ');
                }
                cur_body.push_str(trimmed);
            }
        }
        if cur_id > 0 {
            list.push(NotificationItem {
                id: cur_id,
                app: cur_app,
                title: cur_title,
                body: cur_body.trim().to_string(),
            });
        }
    }
    list
}

fn build_ui(app: &Application) {
    let window = gtk4::ApplicationWindow::builder()
        .application(app)
        .title("Soberano Cockpit Bottom Bar")
        .build();

    // Layer shell setup - identical margins to top bar
    window.init_layer_shell();
    window.set_layer(Layer::Top);
    window.set_exclusive_zone(32);
    window.set_anchor(Edge::Bottom, true);
    window.set_anchor(Edge::Left, true);
    window.set_anchor(Edge::Right, true);
    window.set_anchor(Edge::Top, false);

    window.set_margin(Edge::Bottom, 5);
    window.set_margin(Edge::Left, 9);
    window.set_margin(Edge::Right, 9);

    // Apply CSS directly from Matugen GTK theme
    let provider = gtk4::CssProvider::new();
    let home = std::env::var("HOME").unwrap_or_else(|_| "/home/viniciusphdu".to_string());
    let gtk_css = format!("{}/.config/gtk-4.0/gtk.css", home);

    let custom_css = format!(
        "@import url(\"file://{}\");\n
        window {{
            background-color: transparent;
        }}
        .cockpit-container {{
            background-color: transparent;
            padding: 0;
        }}
        .cockpit-island {{
            background-color: @card_bg_color;
            border: 1px solid @accent_color;
            border-radius: 0px;
            padding: 3px 12px;
            box-shadow: none;
        }}
        .cockpit-island:hover {{
            border-color: @accent_color;
        }}
        .cockpit-label {{
            font-size: 13px;
            font-weight: 700;
            color: @window_fg_color;
            letter-spacing: 0.3px;
        }}
        .cockpit-accent {{
            color: @accent_color;
            font-weight: 800;
            font-size: 13px;
        }}
        .cockpit-chip {{
            background-color: transparent;
            border-radius: 0px;
            padding: 2px 6px;
            margin: 0;
            transition: background 150ms ease;
        }}
        .cockpit-chip:hover {{
            background-color: alpha(@accent_color, 0.15);
        }}
        .cockpit-sep {{
            color: alpha(@window_fg_color, 0.22);
            font-size: 11px;
            margin: 0 2px;
        }}
        /* Popups */
        .cockpit-popup-card {{
            background-color: @card_bg_color;
            border: 1px solid @accent_color;
            border-radius: 0px;
            padding: 12px;
            box-shadow: 0 8px 24px rgba(0, 0, 0, 0.70);
        }}
        .cockpit-popup-header {{
            font-size: 12px;
            font-weight: 800;
            color: @accent_color;
            letter-spacing: 0.5px;
            margin-bottom: 8px;
            padding-bottom: 6px;
            border-bottom: 1px solid alpha(@window_fg_color, 0.15);
        }}
        .cockpit-btn-clear {{
            background-color: alpha(@accent_color, 0.12);
            color: @accent_color;
            border: 1px solid alpha(@accent_color, 0.5);
            border-radius: 0px;
            padding: 2px 8px;
            font-size: 11px;
            font-weight: 700;
        }}
        .cockpit-btn-clear:hover {{
            background-color: @accent_color;
            color: @accent_fg_color;
        }}
        .cockpit-notif-item {{
            background-color: alpha(@window_fg_color, 0.05);
            border-left: 2px solid @accent_color;
            padding: 6px 10px;
            margin-bottom: 6px;
            border-radius: 0px;
        }}
        .cockpit-notif-app {{
            font-size: 10.5px;
            font-weight: 800;
            color: @accent_color;
            text-transform: uppercase;
        }}
        .cockpit-notif-title {{
            font-size: 12px;
            font-weight: 700;
            color: @window_fg_color;
        }}
        .cockpit-notif-body {{
            font-size: 11px;
            color: alpha(@window_fg_color, 0.75);
        }}
        .cockpit-notif-close {{
            background: transparent;
            border: none;
            color: alpha(@window_fg_color, 0.5);
            font-size: 11px;
            padding: 0 4px;
        }}
        .cockpit-notif-close:hover {{
            color: @destructive_color;
        }}
        calendar {{
            background-color: transparent;
            border: none;
            color: @window_fg_color;
            font-size: 13px;
        }}
        calendar:selected {{
            background-color: @accent_color;
            color: @accent_fg_color;
            border-radius: 0px;
        }}
        calendar header {{
            color: @accent_color;
            font-weight: 800;
        }}
        ",
        gtk_css
    );
    provider.load_from_string(&custom_css);

    if let Some(display) = gtk4::gdk::Display::default() {
        gtk4::style_context_add_provider_for_display(
            &display,
            &provider,
            gtk4::STYLE_PROVIDER_PRIORITY_APPLICATION,
        );
    }

    // -------------------------------------------------------------------------
    // POPUP 1: CALENDÁRIO TÁTICO (Bottom-Left)
    // -------------------------------------------------------------------------
    let cal_window = Window::builder().title("Calendário Tático").build();
    cal_window.init_layer_shell();
    cal_window.set_layer(Layer::Overlay);
    cal_window.set_exclusive_zone(-1);
    cal_window.set_anchor(Edge::Bottom, true);
    cal_window.set_anchor(Edge::Left, true);
    cal_window.set_anchor(Edge::Right, false);
    cal_window.set_anchor(Edge::Top, false);
    cal_window.set_margin(Edge::Bottom, 42);
    cal_window.set_margin(Edge::Left, 9);

    let cal_card = GtkBox::new(Orientation::Vertical, 6);
    cal_card.add_css_class("cockpit-popup-card");

    let cal_header = Label::new(Some("󰃰  CALENDÁRIO"));
    cal_header.add_css_class("cockpit-popup-header");
    cal_header.set_xalign(0.0);

    let calendar_widget = Calendar::new();
    calendar_widget.set_show_day_names(true);
    calendar_widget.set_show_heading(true);

    cal_card.append(&cal_header);
    cal_card.append(&calendar_widget);
    cal_window.set_child(Some(&cal_card));
    cal_window.set_visible(false);

    // -------------------------------------------------------------------------
    // POPUP 2: CENTRAL DE NOTIFICAÇÕES (Bottom-Right)
    // -------------------------------------------------------------------------
    let notif_window = Window::builder().title("Central de Notificações").build();
    notif_window.init_layer_shell();
    notif_window.set_layer(Layer::Overlay);
    notif_window.set_exclusive_zone(-1);
    notif_window.set_anchor(Edge::Bottom, true);
    notif_window.set_anchor(Edge::Right, true);
    notif_window.set_anchor(Edge::Left, false);
    notif_window.set_anchor(Edge::Top, false);
    notif_window.set_margin(Edge::Bottom, 42);
    notif_window.set_margin(Edge::Right, 9);

    let notif_card = GtkBox::new(Orientation::Vertical, 8);
    notif_card.add_css_class("cockpit-popup-card");
    notif_card.set_width_request(340);

    let notif_head_box = GtkBox::new(Orientation::Horizontal, 8);
    let notif_header = Label::new(Some("󰂚  NOTIFICAÇÕES"));
    notif_header.add_css_class("cockpit-popup-header");
    notif_header.set_hexpand(true);
    notif_header.set_xalign(0.0);

    let btn_clear = Button::with_label("󰎟 Limpar");
    btn_clear.add_css_class("cockpit-btn-clear");

    notif_head_box.append(&notif_header);
    notif_head_box.append(&btn_clear);
    notif_card.append(&notif_head_box);

    let scroll = ScrolledWindow::builder()
        .hscrollbar_policy(gtk4::PolicyType::Never)
        .vscrollbar_policy(gtk4::PolicyType::Automatic)
        .min_content_height(140)
        .max_content_height(280)
        .build();

    let notif_list_box = GtkBox::new(Orientation::Vertical, 4);
    scroll.set_child(Some(&notif_list_box));
    notif_card.append(&scroll);
    notif_window.set_child(Some(&notif_card));
    notif_window.set_visible(false);

    // Rebuild function for notification list
    let notif_list_clone = notif_list_box.clone();
    let populate_notifications = move || {
        // clear existing
        while let Some(child) = notif_list_clone.first_child() {
            notif_list_clone.remove(&child);
        }

        let items = fetch_notifications();
        if items.is_empty() {
            let empty_lbl = Label::new(Some("Nenhuma notificação no momento."));
            empty_lbl.add_css_class("cockpit-notif-body");
            empty_lbl.set_margin_top(16);
            empty_lbl.set_margin_bottom(16);
            notif_list_clone.append(&empty_lbl);
        } else {
            for item in items {
                let row = GtkBox::new(Orientation::Vertical, 2);
                row.add_css_class("cockpit-notif-item");

                let top_row = GtkBox::new(Orientation::Horizontal, 4);
                let app_lbl = Label::new(Some(&item.app));
                app_lbl.add_css_class("cockpit-notif-app");
                app_lbl.set_hexpand(true);
                app_lbl.set_xalign(0.0);

                let close_btn = Button::with_label("✕");
                close_btn.add_css_class("cockpit-notif-close");
                let item_id = item.id;
                let notif_sub_clone = notif_list_clone.clone();
                let row_clone = row.clone();
                close_btn.connect_clicked(move |_| {
                    let _ = Command::new("wayle")
                        .args(["notify", "dismiss", &item_id.to_string()])
                        .spawn();
                    notif_sub_clone.remove(&row_clone);
                });

                top_row.append(&app_lbl);
                top_row.append(&close_btn);

                let title_lbl = Label::new(Some(&item.title));
                title_lbl.add_css_class("cockpit-notif-title");
                title_lbl.set_xalign(0.0);
                title_lbl.set_wrap(true);

                row.append(&top_row);
                row.append(&title_lbl);

                if !item.body.is_empty() {
                    let body_lbl = Label::new(Some(&item.body));
                    body_lbl.add_css_class("cockpit-notif-body");
                    body_lbl.set_xalign(0.0);
                    body_lbl.set_wrap(true);
                    row.append(&body_lbl);
                }
                notif_list_clone.append(&row);
            }
        }
    };

    let notif_list_for_clear = notif_list_box.clone();
    btn_clear.connect_clicked(move |_| {
        let _ = Command::new("wayle").args(["notify", "dismiss-all"]).spawn();
        while let Some(child) = notif_list_for_clear.first_child() {
            notif_list_for_clear.remove(&child);
        }
        let empty_lbl = Label::new(Some("Todas as notificações foram limpas."));
        empty_lbl.add_css_class("cockpit-notif-body");
        empty_lbl.set_margin_top(16);
        empty_lbl.set_margin_bottom(16);
        notif_list_for_clear.append(&empty_lbl);
    });

    let root = CenterBox::new();
    root.add_css_class("cockpit-container");

    // -------------------------------------------------------------------------
    // BLOCO 3 (Ponta Inferior Esquerda): Relógio & Cronômetro Tático
    // -------------------------------------------------------------------------
    let left_island = GtkBox::new(Orientation::Horizontal, 8);
    left_island.add_css_class("cockpit-island");

    let clock_icon = Label::new(Some("󰃰"));
    clock_icon.add_css_class("cockpit-accent");

    let clock_label = Label::new(None);
    clock_label.add_css_class("cockpit-label");

    left_island.append(&clock_icon);
    left_island.append(&clock_label);

    let format_24h = Arc::new(AtomicBool::new(true));

    // CLICK CLOCK: Toggle Calendar Popup
    let cal_win_toggle = cal_window.clone();
    let notif_win_close = notif_window.clone();
    let click_clock = GestureClick::new();
    click_clock.connect_released(move |_, _, _, _| {
        notif_win_close.set_visible(false);
        let cur_vis = cal_win_toggle.is_visible();
        cal_win_toggle.set_visible(!cur_vis);
    });
    left_island.add_controller(click_clock);

    let clock_lbl_clone = clock_label.clone();
    let f24_timer = Arc::clone(&format_24h);
    let update_time = move || {
        let now = glib::DateTime::now_local()
            .or_else(|_| glib::DateTime::now_utc())
            .unwrap();
        let fmt = if f24_timer.load(Ordering::Relaxed) {
            now.format("%H:%M:%S  •  %a, %d %b")
                .unwrap_or_else(|_| "00:00:00".into())
        } else {
            now.format("%I:%M:%S %p  •  %a, %d %b")
                .unwrap_or_else(|_| "00:00:00".into())
        };
        clock_lbl_clone.set_text(&fmt);
        ControlFlow::Continue
    };
    update_time();
    glib::timeout_add_local(std::time::Duration::from_millis(1000), update_time);

    root.set_start_widget(Some(&left_island));
    root.set_center_widget(None::<&GtkBox>);

    // -------------------------------------------------------------------------
    // BLOCO 4 (Ponta Inferior Direita): Status Vital (Volume + Rede + Notificações)
    // -------------------------------------------------------------------------
    let right_island = GtkBox::new(Orientation::Horizontal, 4);
    right_island.add_css_class("cockpit-island");

    // 1. Volume Widget with scroll to change and click for mute / pavucontrol
    let vol_box = GtkBox::new(Orientation::Horizontal, 5);
    vol_box.add_css_class("cockpit-chip");

    let vol_icon = Label::new(Some("󰕾"));
    vol_icon.add_css_class("cockpit-accent");
    let vol_label = Label::new(Some("100%"));
    vol_label.add_css_class("cockpit-label");

    vol_box.append(&vol_icon);
    vol_box.append(&vol_label);

    let vol_lbl_clone = vol_label.clone();
    let vol_ico_clone = vol_icon.clone();
    let update_vol_ui = move || {
        let (vol, muted) = get_system_volume();
        if muted {
            vol_ico_clone.set_text("󰝟");
            vol_lbl_clone.set_text("MUTED");
        } else {
            let ico = if vol > 65 {
                "󰕾"
            } else if vol > 25 {
                "󰖀"
            } else {
                "󰕿"
            };
            vol_ico_clone.set_text(ico);
            vol_lbl_clone.set_text(&format!("{}%", vol));
        }
        ControlFlow::Continue
    };
    update_vol_ui();

    let scroll = EventControllerScroll::new(EventControllerScrollFlags::VERTICAL);
    let vol_timer_refresh = vol_label.clone();
    let vol_ico_refresh = vol_icon.clone();
    scroll.connect_scroll(move |_, _, dy| {
        if dy < 0.0 {
            adjust_volume(5);
        } else if dy > 0.0 {
            adjust_volume(-5);
        }
        let (v, m) = get_system_volume();
        if m {
            vol_ico_refresh.set_text("󰝟");
            vol_timer_refresh.set_text("MUTED");
        } else {
            vol_ico_refresh.set_text(if v > 65 {
                "󰕾"
            } else if v > 25 {
                "󰖀"
            } else {
                "󰕿"
            });
            vol_timer_refresh.set_text(&format!("{}%", v));
        }
        glib::Propagation::Stop
    });
    vol_box.add_controller(scroll);

    let click_vol = GestureClick::new();
    click_vol.connect_released(move |_, n_press, _, _| {
        if n_press == 1 {
            toggle_mute();
        } else if n_press >= 2 {
            let _ = Command::new("pavucontrol").spawn();
        }
    });
    vol_box.add_controller(click_vol);
    glib::timeout_add_local(std::time::Duration::from_millis(2500), update_vol_ui);

    // Separator 1
    let sep1 = Label::new(Some("│"));
    sep1.add_css_class("cockpit-sep");

    // 2. Network Widget
    let net_box = GtkBox::new(Orientation::Horizontal, 5);
    net_box.add_css_class("cockpit-chip");
    let net_icon = Label::new(Some("󰈀"));
    net_icon.add_css_class("cockpit-accent");
    let net_label = Label::new(Some("ETH"));
    net_label.add_css_class("cockpit-label");
    net_box.append(&net_icon);
    net_box.append(&net_label);

    let net_ico_clone = net_icon.clone();
    let net_lbl_clone = net_label.clone();
    let update_net_ui = move || {
        let (ico, text) = get_network_info();
        net_ico_clone.set_text(ico);
        net_lbl_clone.set_text(&text);
        ControlFlow::Continue
    };
    update_net_ui();
    glib::timeout_add_local(std::time::Duration::from_millis(5000), update_net_ui);

    // Separator 2
    let sep2 = Label::new(Some("│"));
    sep2.add_css_class("cockpit-sep");

    // 3. Notifications Button
    let notif_box = GtkBox::new(Orientation::Horizontal, 5);
    notif_box.add_css_class("cockpit-chip");
    let notif_icon = Label::new(Some("󰂚"));
    notif_icon.add_css_class("cockpit-accent");
    let notif_label = Label::new(Some("0"));
    notif_label.add_css_class("cockpit-label");
    notif_box.append(&notif_icon);
    notif_box.append(&notif_label);

    let notif_lbl_clone = notif_label.clone();
    let update_notif_ui = move || {
        let count = get_notification_count();
        notif_lbl_clone.set_text(&count.to_string());
        ControlFlow::Continue
    };
    update_notif_ui();
    glib::timeout_add_local(std::time::Duration::from_millis(3000), update_notif_ui);

    // CLICK NOTIFICATIONS: Toggle Notifications Popup & Populate
    let notif_win_toggle = notif_window.clone();
    let cal_win_close = cal_window.clone();
    let click_notif = GestureClick::new();
    click_notif.connect_released(move |_, _, _, _| {
        cal_win_close.set_visible(false);
        let cur_vis = notif_win_toggle.is_visible();
        if !cur_vis {
            populate_notifications();
            notif_win_toggle.set_visible(true);
        } else {
            notif_win_toggle.set_visible(false);
        }
    });
    notif_box.add_controller(click_notif);

    right_island.append(&vol_box);
    right_island.append(&sep1);
    right_island.append(&net_box);
    right_island.append(&sep2);
    right_island.append(&notif_box);

    root.set_end_widget(Some(&right_island));

    window.set_child(Some(&root));
    window.present();
}
