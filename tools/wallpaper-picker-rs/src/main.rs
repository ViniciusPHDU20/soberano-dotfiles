use gtk4::prelude::*;
use gtk4::{
    gdk, gdk::Texture, gdk_pixbuf::Pixbuf, glib, Application, ApplicationWindow, Box as GtkBox,
    EventControllerKey, FlowBox, FlowBoxChild, GestureClick, Image, Label, Orientation,
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
const THUMB_W: i32 = 280;
const THUMB_H: i32 = 158;

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
    let css = r#"
        window.wallpaper-overlay {
            background-color: rgba(6, 7, 10, 0.72);
        }

        .main-card {
            background-color: rgba(18, 19, 26, 0.94);
            border: 1px solid rgba(255, 255, 255, 0.12);
            border-radius: 26px;
            box-shadow: 0 24px 60px rgba(0, 0, 0, 0.75);
            padding: 24px 28px;
        }

        .header-title {
            font-size: 20px;
            font-weight: 700;
            color: #f0f0f5;
            letter-spacing: 0.5px;
        }

        .header-badge {
            font-size: 11px;
            font-weight: 600;
            color: #ff605a;
            background-color: rgba(255, 96, 90, 0.15);
            border-radius: 9999px;
            padding: 4px 12px;
        }

        .search-entry {
            background-color: rgba(255, 255, 255, 0.06);
            border: 1px solid rgba(255, 255, 255, 0.10);
            border-radius: 12px;
            color: #ffffff;
            font-size: 13px;
            padding: 8px 14px;
            min-width: 320px;
            transition: all 200ms ease;
        }

        .search-entry:focus {
            background-color: rgba(255, 255, 255, 0.10);
            border-color: #ff605a;
            box-shadow: 0 0 0 2px rgba(255, 96, 90, 0.25);
        }

        .btn-random {
            background-color: rgba(255, 96, 90, 0.18);
            border: 1px solid rgba(255, 96, 90, 0.4);
            border-radius: 12px;
            color: #ff8e89;
            font-size: 12px;
            font-weight: 600;
            padding: 6px 16px;
            transition: all 200ms ease;
        }

        .btn-random:hover {
            background-color: #ff605a;
            color: #ffffff;
            box-shadow: 0 4px 16px rgba(255, 96, 90, 0.4);
        }

        .wallpaper-card {
            background-color: rgba(28, 29, 38, 0.85);
            border: 1px solid rgba(255, 255, 255, 0.08);
            border-radius: 16px;
            padding: 6px;
            margin: 6px;
            transition: all 220ms cubic-bezier(0.16, 1, 0.3, 1);
        }

        .wallpaper-card:hover {
            background-color: rgba(40, 42, 54, 0.95);
            border-color: #ff605a;
            box-shadow: 0 10px 24px rgba(255, 96, 90, 0.22);
        }

        .wallpaper-card.active {
            border: 2px solid #ff605a;
            box-shadow: 0 0 16px rgba(255, 96, 90, 0.4);
        }

        .card-image {
            border-radius: 12px;
        }

        .card-label {
            font-size: 11px;
            font-weight: 500;
            color: #d8d8e5;
            padding-top: 6px;
            padding-bottom: 2px;
        }

        .wallpaper-card:hover .card-label {
            color: #ff8e89;
            font-weight: 600;
        }
    "#;

    provider.load_from_string(css);
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

    let title_box = GtkBox::new(Orientation::Horizontal, 8);
    let title_label = Label::new(Some("󰸉 Wallpapers"));
    title_label.add_css_class("header-title");
    let count_label = Label::new(Some(&format!("{} imagens", wallpapers.len())));
    count_label.add_css_class("header-badge");
    title_box.append(&title_label);
    title_box.append(&count_label);

    let search_entry = SearchEntry::new();
    search_entry.set_placeholder_text(Some("Buscar wallpaper por nome..."));
    search_entry.add_css_class("search-entry");
    search_entry.set_hexpand(true);

    let random_btn = gtk4::Button::with_label("󰒝 Aleatório");
    random_btn.add_css_class("btn-random");

    header.append(&title_box);
    header.append(&search_entry);
    header.append(&random_btn);

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

        if let Some(ref cur) = current_wp {
            if cur == &item.path {
                card_item.add_css_class("active");
            }
        }

        if let Ok(pixbuf) = Pixbuf::from_file(&item.thumbnail_path) {
            let texture = Texture::for_pixbuf(&pixbuf);
            let img = Image::from_paintable(Some(&texture));
            img.add_css_class("card-image");
            img.set_pixel_size(THUMB_W);
            card_item.append(&img);
        }

        let name_label = Label::new(Some(&item.name));
        name_label.add_css_class("card-label");
        name_label.set_ellipsize(gtk4::pango::EllipsizeMode::End);
        name_label.set_max_width_chars(32);
        card_item.append(&name_label);

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

    // Key controller: Escape closes (using Capture phase so focused inputs don't swallow it)
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
