use gtk4::prelude::*;
use gtk4::{
    gdk, gdk::Texture, gdk_pixbuf::Pixbuf, glib, Application, ApplicationWindow, Box as GtkBox,
    Button, EventControllerKey, FlowBox, FlowBoxChild, GestureClick, Image, Label, Orientation,
    ScrolledWindow, SearchEntry,
};
use gtk4_layer_shell::{Edge, KeyboardMode, Layer, LayerShell};
use std::cell::RefCell;
use std::collections::HashMap;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;
use std::rc::Rc;
use walkdir::WalkDir;

const APP_ID: &str = "org.soberano.wallpaperpicker";
const THUMB_W: i32 = 276;
const THUMB_H: i32 = 155;

#[derive(Clone)]
struct WallpaperItem {
    path: PathBuf,
    name: String,
    thumbnail_path: PathBuf,
}

fn get_cache_dir() -> PathBuf {
    let mut dir = dirs_or_home_cache();
    dir.push("soberano_thumbnails");
    let _ = fs::create_dir_all(&dir);
    dir
}

fn dirs_or_home_cache() -> PathBuf {
    if let Ok(c) = std::env::var("XDG_CACHE_HOME") {
        PathBuf::from(c)
    } else if let Ok(h) = std::env::var("HOME") {
        PathBuf::from(h).join(".cache")
    } else {
        PathBuf::from("/tmp")
    }
}

fn current_wallpaper_path() -> Option<PathBuf> {
    let state = dirs_or_home_cache().join("soberano_wallpaper.txt");
    if let Ok(content) = fs::read_to_string(state) {
        let trimmed = content.trim();
        if !trimmed.is_empty() {
            return Some(PathBuf::from(trimmed));
        }
    }
    None
}

fn get_thumbnail_path(orig: &Path, cache_dir: &Path) -> PathBuf {
    use std::collections::hash_map::DefaultHasher;
    use std::hash::{Hash, Hasher};

    let mut hasher = DefaultHasher::new();
    orig.hash(&mut hasher);
    let hash_val = hasher.finish();
    let fname = format!("{:016x}.jpg", hash_val);
    cache_dir.join(fname)
}

fn ensure_thumbnail(orig: &Path, thumb: &Path) -> bool {
    if thumb.exists() {
        return true;
    }
    if let Ok(pixbuf) = Pixbuf::from_file_at_scale(orig, THUMB_W, THUMB_H, true) {
        let _ = pixbuf.savev(thumb, "jpeg", &[("quality", "85")]);
        return true;
    }
    false
}

fn scan_wallpapers() -> Vec<WallpaperItem> {
    let home = std::env::var("HOME").unwrap_or_else(|_| "/home/viniciusphdu".to_string());
    let wall_dir = PathBuf::from(home).join("dotfiles/wallpapers");
    let cache_dir = get_cache_dir();

    let mut items = Vec::new();
    for entry in WalkDir::new(&wall_dir).max_depth(2).into_iter().filter_map(|e| e.ok()) {
        let p = entry.path();
        if p.is_file() {
            if let Some(ext) = p.extension().and_then(|s| s.to_str()) {
                let ext_lower = ext.to_lowercase();
                if ["png", "jpg", "jpeg", "webp"].contains(&ext_lower.as_str()) {
                    let thumb = get_thumbnail_path(p, &cache_dir);
                    ensure_thumbnail(p, &thumb);

                    let stem = p.file_stem().and_then(|s| s.to_str()).unwrap_or("Wallpaper");
                    items.push(WallpaperItem {
                        path: p.to_path_buf(),
                        name: stem.to_string(),
                        thumbnail_path: thumb,
                    });
                }
            }
        }
    }
    items.sort_by(|a, b| a.name.to_lowercase().cmp(&b.name.to_lowercase()));
    items
}

fn apply_wallpaper(path: &Path) {
    let path_str = path.to_string_lossy();
    let home = std::env::var("HOME").unwrap_or_else(|_| "/home/viniciusphdu".to_string());
    let state_file = dirs_or_home_cache().join("soberano_wallpaper.txt");
    let _ = fs::write(&state_file, path_str.as_ref());

    let wayle_cfg = PathBuf::from(&home).join("dotfiles/config/wayle/config.toml");
    if wayle_cfg.exists() {
        if let Ok(content) = fs::read_to_string(&wayle_cfg) {
            let mut new_lines = Vec::new();
            for line in content.lines() {
                if line.trim_start().starts_with("wallpaper =") {
                    new_lines.push(format!("wallpaper = \"{}\"", path_str));
                } else {
                    new_lines.push(line.to_string());
                }
            }
            let _ = fs::write(&wayle_cfg, new_lines.join("\n"));
        }
    }

    // 1. Wayle native wallpaper / awww
    let _ = Command::new("wayle")
        .args(["wallpaper", "set", &path_str, "--monitor", "DP-1"])
        .spawn();

    let _ = Command::new("awww")
        .args([
            "img",
            &path_str,
            "--transition-type",
            "grow",
            "--transition-fps",
            "144",
        ])
        .spawn();

    // 2. Matugen color extraction (vibrant, prefer saturation, contrast -0.45)
    let _ = Command::new("matugen")
        .args([
            "image",
            &path_str,
            "-t",
            "scheme-vibrant",
            "-m",
            "dark",
            "--prefer",
            "saturation",
            "--contrast",
            "-0.45",
        ])
        .spawn();

    let name = path.file_stem().and_then(|s| s.to_str()).unwrap_or("Novo Wallpaper");
    let _ = Command::new("notify-send")
        .args([
            "-u",
            "low",
            "-a",
            "Soberano",
            "󰸉 Wallpaper Atualizado",
            name,
        ])
        .spawn();
}

fn load_css() {
    let provider = gtk4::CssProvider::new();
    let home = std::env::var("HOME").unwrap_or_else(|_| "/home/viniciusphdu".to_string());
    let colors_file = PathBuf::from(&home).join(".config/gtk-4.0/colors.css");

    // Dynamic color tokens from Matugen
    let colors_def = if let Ok(s) = fs::read_to_string(&colors_file) {
        s
    } else {
        r#"
            @define-color accent_color #ff605a;
            @define-color accent_bg_color #ff605a;
            @define-color accent_fg_color #ffffff;
            @define-color window_bg_color #12131a;
            @define-color window_fg_color #f0f0f5;
            @define-color card_bg_color #1c1d26;
            @define-color card_fg_color #d8d8e5;
        "#
        .to_string()
    };

    let ui_css = format!(
        r#"
        {}

        window.wallpaper-overlay {{
            background-color: rgba(4, 5, 8, 0.72);
        }}

        .main-card {{
            background-color: alpha(@window_bg_color, 0.94);
            border: 1px solid alpha(@accent_color, 0.30);
            border-radius: 28px;
            box-shadow: 0 32px 80px rgba(0, 0, 0, 0.85), 0 0 1px alpha(@accent_color, 0.45);
            padding: 24px 28px;
        }}

        .header-icon-badge {{
            font-size: 20px;
            color: @accent_color;
            background-color: alpha(@accent_color, 0.14);
            border: 1px solid alpha(@accent_color, 0.30);
            border-radius: 12px;
            padding: 6px 12px;
        }}

        .header-title {{
            font-size: 18px;
            font-weight: 800;
            color: @window_fg_color;
            letter-spacing: 0.6px;
        }}

        .header-badge {{
            font-size: 11px;
            font-weight: 700;
            color: @accent_color;
            background-color: alpha(@accent_color, 0.14);
            border-radius: 9999px;
            padding: 4px 12px;
            letter-spacing: 0.4px;
        }}

        .search-entry {{
            background-color: rgba(255, 255, 255, 0.05);
            border: 1px solid rgba(255, 255, 255, 0.10);
            border-radius: 9999px;
            color: #ffffff;
            font-size: 13px;
            padding: 8px 18px;
            min-width: 320px;
            transition: all 200ms cubic-bezier(0.16, 1, 0.3, 1);
        }}

        .search-entry:focus {{
            background-color: rgba(255, 255, 255, 0.08);
            border-color: @accent_color;
            box-shadow: 0 0 0 2px alpha(@accent_color, 0.25), 0 0 18px alpha(@accent_color, 0.20);
        }}

        .btn-action {{
            background-color: alpha(@accent_color, 0.14);
            border: 1px solid alpha(@accent_color, 0.35);
            border-radius: 9999px;
            color: @accent_color;
            font-size: 12px;
            font-weight: 700;
            padding: 7px 18px;
            transition: all 200ms cubic-bezier(0.16, 1, 0.3, 1);
        }}

        .btn-action:hover {{
            background-color: @accent_color;
            color: @accent_fg_color;
            box-shadow: 0 4px 18px alpha(@accent_color, 0.45);
        }}

        .btn-close {{
            background-color: rgba(255, 255, 255, 0.06);
            border: 1px solid rgba(255, 255, 255, 0.10);
            border-radius: 9999px;
            color: rgba(255, 255, 255, 0.65);
            font-size: 14px;
            font-weight: bold;
            padding: 7px 14px;
            transition: all 180ms ease;
        }}

        .btn-close:hover {{
            background-color: #ff5450;
            border-color: #ff5450;
            color: #ffffff;
            box-shadow: 0 4px 14px rgba(255, 84, 80, 0.4);
        }}

        .wallpaper-card {{
            background-color: alpha(@card_bg_color, 0.75);
            border: 1px solid rgba(255, 255, 255, 0.07);
            border-radius: 18px;
            padding: 6px;
            margin: 6px;
            transition: all 220ms cubic-bezier(0.16, 1, 0.3, 1);
        }}

        .wallpaper-card:hover {{
            background-color: alpha(@card_bg_color, 0.95);
            border-color: @accent_color;
            box-shadow: 0 14px 30px rgba(0, 0, 0, 0.55), 0 0 22px alpha(@accent_color, 0.32);
        }}

        .wallpaper-card.active {{
            border: 2px solid @accent_color;
            box-shadow: 0 0 22px alpha(@accent_color, 0.45);
        }}

        .card-image {{
            border-radius: 14px;
        }}

        .card-label {{
            font-size: 11px;
            font-weight: 600;
            color: rgba(255, 255, 255, 0.78);
            padding-top: 6px;
            padding-bottom: 2px;
            transition: color 180ms ease;
        }}

        .wallpaper-card:hover .card-label {{
            color: @accent_color;
        }}

        .active-badge {{
            font-size: 9px;
            font-weight: 800;
            color: @accent_fg_color;
            background-color: @accent_color;
            border-radius: 6px;
            padding: 2px 7px;
            letter-spacing: 0.5px;
        }}

        /* Modern minimal scrollbar */
        scrolledwindow scrollbar.vertical {{
            background-color: transparent;
            min-width: 6px;
        }}
        scrolledwindow scrollbar.vertical slider {{
            background-color: alpha(@accent_color, 0.35);
            border-radius: 9999px;
            min-width: 6px;
            transition: background-color 200ms ease;
        }}
        scrolledwindow scrollbar.vertical slider:hover {{
            background-color: @accent_color;
        }}
        "#,
        colors_def
    );

    provider.load_from_string(&ui_css);
    if let Some(display) = gdk::Display::default() {
        gtk4::style_context_add_provider_for_display(
            &display,
            &provider,
            gtk4::STYLE_PROVIDER_PRIORITY_APPLICATION,
        );
    }
}

fn build_ui(app: &Application) {
    load_css();

    let window = ApplicationWindow::builder()
        .application(app)
        .title("Soberano Wallpaper Picker")
        .default_width(1280)
        .default_height(800)
        .build();

    window.add_css_class("wallpaper-overlay");

    // Wayland Layer Shell initialization
    window.init_layer_shell();
    window.set_layer(Layer::Overlay);
    window.set_keyboard_mode(KeyboardMode::Exclusive);
    window.set_anchor(Edge::Top, true);
    window.set_anchor(Edge::Bottom, true);
    window.set_anchor(Edge::Left, true);
    window.set_anchor(Edge::Right, true);

    let wallpapers = scan_wallpapers();
    let current_wp = current_wallpaper_path();

    // Main layout: Center the floating card inside the overlay
    let root_box = GtkBox::new(Orientation::Vertical, 0);
    root_box.set_valign(gtk4::Align::Center);
    root_box.set_halign(gtk4::Align::Center);

    let card = GtkBox::new(Orientation::Vertical, 16);
    card.add_css_class("main-card");
    card.set_size_request(1180, 720);

    // Header bar
    let header = GtkBox::new(Orientation::Horizontal, 14);
    header.set_valign(gtk4::Align::Center);

    let title_box = GtkBox::new(Orientation::Horizontal, 10);
    title_box.set_valign(gtk4::Align::Center);

    let icon_badge = Label::new(Some("󰸉"));
    icon_badge.add_css_class("header-icon-badge");

    let text_col = GtkBox::new(Orientation::Vertical, 2);
    let title_label = Label::new(Some("WALLPAPERS"));
    title_label.add_css_class("header-title");
    title_label.set_halign(gtk4::Align::Start);

    let count_label = Label::new(Some(&format!("{} IMAGENS DISPONÍVEIS", wallpapers.len())));
    count_label.add_css_class("header-badge");
    count_label.set_halign(gtk4::Align::Start);

    text_col.append(&title_label);
    text_col.append(&count_label);

    title_box.append(&icon_badge);
    title_box.append(&text_col);

    let search_entry = SearchEntry::new();
    search_entry.set_placeholder_text(Some("Buscar por nome..."));
    search_entry.add_css_class("search-entry");
    search_entry.set_hexpand(true);

    let random_btn = Button::with_label("󰒝 Aleatório");
    random_btn.add_css_class("btn-action");

    let close_btn = Button::with_label("✕");
    close_btn.add_css_class("btn-close");
    let win_close = window.clone();
    close_btn.connect_clicked(move |_| {
        win_close.close();
        std::process::exit(0);
    });

    header.append(&title_box);
    header.append(&search_entry);
    header.append(&random_btn);
    header.append(&close_btn);

    // FlowBox for wallpapers grid
    let flowbox = FlowBox::new();
    flowbox.set_valign(gtk4::Align::Start);
    flowbox.set_max_children_per_line(4);
    flowbox.set_min_children_per_line(3);
    flowbox.set_selection_mode(gtk4::SelectionMode::None);
    flowbox.set_homogeneous(true);

    let child_map = Rc::new(RefCell::new(HashMap::<String, FlowBoxChild>::new()));

    for item in &wallpapers {
        let card_item = GtkBox::new(Orientation::Vertical, 4);
        card_item.add_css_class("wallpaper-card");
        card_item.set_size_request(THUMB_W + 12, THUMB_H + 34);

        let is_active = if let Some(ref cur) = current_wp {
            cur == &item.path
        } else {
            false
        };

        if is_active {
            card_item.add_css_class("active");
        }

        if let Ok(pixbuf) = Pixbuf::from_file(&item.thumbnail_path) {
            let texture = Texture::for_pixbuf(&pixbuf);
            let img = Image::from_paintable(Some(&texture));
            img.add_css_class("card-image");
            img.set_pixel_size(THUMB_W);
            card_item.append(&img);
        }

        let label_box = GtkBox::new(Orientation::Horizontal, 6);
        let name_label = Label::new(Some(&item.name));
        name_label.add_css_class("card-label");
        name_label.set_ellipsize(gtk4::pango::EllipsizeMode::End);
        name_label.set_hexpand(true);
        name_label.set_halign(gtk4::Align::Start);
        label_box.append(&name_label);

        if is_active {
            let badge = Label::new(Some("✓ ATIVO"));
            badge.add_css_class("active-badge");
            label_box.append(&badge);
        }
        card_item.append(&label_box);

        let click = GestureClick::new();
        let path_clone = item.path.clone();
        let win_clone = window.clone();
        click.connect_released(move |_, _, _, _| {
            apply_wallpaper(&path_clone);
            win_clone.close();
            std::process::exit(0);
        });
        card_item.add_controller(click);

        let child = FlowBoxChild::new();
        child.set_child(Some(&card_item));
        flowbox.append(&child);

        child_map
            .borrow_mut()
            .insert(item.name.to_lowercase(), child);
    }

    // Filter logic for search entry
    let child_map_filter = Rc::clone(&child_map);
    search_entry.connect_search_changed(move |entry| {
        let query = entry.text().to_lowercase();
        let map = child_map_filter.borrow();
        for (name, child) in map.iter() {
            child.set_visible(query.is_empty() || name.contains(&query));
        }
    });

    // Random button handler
    let all_wps = wallpapers.clone();
    let win_rand = window.clone();
    random_btn.connect_clicked(move |_| {
        if !all_wps.is_empty() {
            use std::time::SystemTime;
            let seed = SystemTime::now()
                .duration_since(SystemTime::UNIX_EPOCH)
                .map(|d| d.as_nanos())
                .unwrap_or(42);
            let idx = (seed as usize) % all_wps.len();
            apply_wallpaper(&all_wps[idx].path);
            win_rand.close();
            std::process::exit(0);
        }
    });

    let scroll = ScrolledWindow::builder()
        .hscrollbar_policy(gtk4::PolicyType::Never)
        .vscrollbar_policy(gtk4::PolicyType::Automatic)
        .child(&flowbox)
        .vexpand(true)
        .build();

    card.append(&header);
    card.append(&scroll);
    root_box.append(&card);

    // Click outside card closes window
    let bg_click = GestureClick::new();
    let win_bg = window.clone();
    bg_click.connect_released(move |gesture, _, x, y| {
        if let Some(widget) = gesture.widget() {
            let width = widget.width() as f64;
            let height = widget.height() as f64;
            let card_w = 1180.0;
            let card_h = 720.0;
            let min_x = (width - card_w) / 2.0;
            let max_x = min_x + card_w;
            let min_y = (height - card_h) / 2.0;
            let max_y = min_y + card_h;

            if x < min_x || x > max_x || y < min_y || y > max_y {
                win_bg.close();
                std::process::exit(0);
            }
        }
    });
    window.add_controller(bg_click);

    // Key controller: Escape closes in Capture phase
    let key_controller = EventControllerKey::new();
    key_controller.set_propagation_phase(gtk4::PropagationPhase::Capture);
    let win_key = window.clone();
    key_controller.connect_key_pressed(move |_, keyval, _, _| {
        if keyval == gdk::Key::Escape {
            win_key.close();
            std::process::exit(0);
        } else {
            glib::Propagation::Proceed
        }
    });
    window.add_controller(key_controller);

    window.set_child(Some(&root_box));
    window.present();
}

fn main() -> glib::ExitCode {
    let app = Application::builder().application_id(APP_ID).build();
    app.connect_activate(build_ui);
    app.run()
}
