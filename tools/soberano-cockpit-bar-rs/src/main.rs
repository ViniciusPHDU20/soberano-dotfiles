use glib::ControlFlow;
use gtk4::prelude::*;
use gtk4::{Application, CenterBox, EventControllerScroll, EventControllerScrollFlags, GestureClick, Label, Orientation, Box as GtkBox};
use gtk4_layer_shell::{Edge, Layer, LayerShell};
use std::process::Command;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;

const APP_ID: &str = "org.soberano.cockpit.bottombar";

fn main() {
    let app = Application::builder()
        .application_id(APP_ID)
        .build();

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

fn build_ui(app: &Application) {
    let window = gtk4::ApplicationWindow::builder()
        .application(app)
        .title("Soberano Cockpit Bottom Bar")
        .build();

    // Layer shell setup
    window.init_layer_shell();
    window.set_layer(Layer::Top);
    window.set_exclusive_zone(26);
    window.set_anchor(Edge::Bottom, true);
    window.set_anchor(Edge::Left, true);
    window.set_anchor(Edge::Right, true);
    window.set_anchor(Edge::Top, false);

    window.set_margin(Edge::Bottom, 3);
    window.set_margin(Edge::Left, 6);
    window.set_margin(Edge::Right, 6);

    // Apply CSS
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
            background-color: rgba(22, 23, 30, 0.96);
            border: 1px solid alpha(@accent_color, 0.85);
            border-radius: 0px;
            padding: 2px 10px;
            box-shadow: 0 2px 6px rgba(0, 0, 0, 0.35);
        }}
        .cockpit-island:hover {{
            background-color: rgba(28, 29, 38, 0.98);
            border-color: @accent_color;
        }}
        .cockpit-label {{
            font-size: 12px;
            font-weight: 700;
            color: @window_fg_color;
            letter-spacing: 0.2px;
        }}
        .cockpit-accent {{
            color: @accent_color;
            font-weight: 800;
            font-size: 12px;
        }}
        .cockpit-chip {{
            background-color: rgba(255, 255, 255, 0.06);
            border-radius: 0px;
            padding: 2px 6px;
            margin: 0 1px;
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
    let f24_click = Arc::clone(&format_24h);

    let click_clock = GestureClick::new();
    click_clock.connect_released(move |_, _, _, _| {
        let cur = f24_click.load(Ordering::Relaxed);
        f24_click.store(!cur, Ordering::Relaxed);
    });
    left_island.add_controller(click_clock);

    let clock_lbl_clone = clock_label.clone();
    let f24_timer = Arc::clone(&format_24h);
    let update_time = move || {
        let now = glib::DateTime::now_local().or_else(|_| glib::DateTime::now_utc()).unwrap();
        let fmt = if f24_timer.load(Ordering::Relaxed) {
            now.format("%H:%M:%S  •  %a, %d %b").unwrap_or_else(|_| "00:00:00".into())
        } else {
            now.format("%I:%M:%S %p  •  %a, %d %b").unwrap_or_else(|_| "00:00:00".into())
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
    let right_island = GtkBox::new(Orientation::Horizontal, 8);
    right_island.add_css_class("cockpit-island");

    // Volume Widget with scroll to change and click for mute / pavucontrol
    let vol_box = GtkBox::new(Orientation::Horizontal, 4);
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
            vol_ico_refresh.set_text(if v > 65 { "󰕾" } else if v > 25 { "󰖀" } else { "󰕿" });
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

    // Network Widget
    let net_box = GtkBox::new(Orientation::Horizontal, 4);
    net_box.add_css_class("cockpit-chip");
    let net_icon = Label::new(Some("󰤨"));
    net_icon.add_css_class("cockpit-accent");
    let net_label = Label::new(Some("ONLINE"));
    net_label.add_css_class("cockpit-label");
    net_box.append(&net_icon);
    net_box.append(&net_label);

    // Notifications Button
    let notif_box = GtkBox::new(Orientation::Horizontal, 4);
    notif_box.add_css_class("cockpit-chip");
    let notif_icon = Label::new(Some("󰂚"));
    notif_icon.add_css_class("cockpit-accent");
    let notif_label = Label::new(Some("0"));
    notif_label.add_css_class("cockpit-label");
    notif_box.append(&notif_icon);
    notif_box.append(&notif_label);

    let click_notif = GestureClick::new();
    click_notif.connect_released(move |_, _, _, _| {
        let _ = Command::new("swaync-client").arg("-t").spawn();
    });
    notif_box.add_controller(click_notif);

    right_island.append(&vol_box);
    right_island.append(&net_box);
    right_island.append(&notif_box);

    root.set_end_widget(Some(&right_island));

    window.set_child(Some(&root));
    window.present();
}
