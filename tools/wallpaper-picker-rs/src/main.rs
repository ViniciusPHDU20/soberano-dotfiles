use gtk4::prelude::*;
use gtk4::{
    gdk, gdk::Texture, gdk_pixbuf::Pixbuf, glib, Application, ApplicationWindow, Box as GtkBox,
    Button, EventControllerKey, FlowBox, FlowBoxChild, GestureClick, Image, Label, Orientation,
    ScrolledWindow, SearchEntry,
};
use gtk4_layer_shell::{Edge, KeyboardMode, Layer, LayerShell};
use std::cell::RefCell;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;
use std::rc::Rc;
use walkdir::WalkDir;

const APP_ID: &str = "org.soberano.wallpaperpicker";
const THUMB_W: i32 = 240;
const THUMB_H: i32 = 135;
const HERO_W: i32 = 380;
const HERO_H: i32 = 214;

#[derive(Clone, Debug)]
struct WallpaperItem {
    path: PathBuf,
    name: String,
    category: String,
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

fn detect_category(name_lower: &str) -> &'static str {
    if name_lower.contains("dynamic") {
        "Dynamic"
    } else if name_lower.contains("anime") || name_lower.contains("girl") || name_lower.contains("chan") || name_lower.contains("manga") {
        "Anime"
    } else if name_lower.contains("lofi") || name_lower.contains("chill") || name_lower.contains("room") || name_lower.contains("coffee") || name_lower.contains("cafe") || name_lower.contains("study") {
        "Lofi"
    } else if name_lower.contains("space") || name_lower.contains("moon") || name_lower.contains("star") || name_lower.contains("galaxy") || name_lower.contains("aurora") || name_lower.contains("northern") || name_lower.contains("eclipse") {
        "Space"
    } else if name_lower.contains("city") || name_lower.contains("street") || name_lower.contains("building") || name_lower.contains("road") {
        "City"
    } else if name_lower.contains("nature") || name_lower.contains("forest") || name_lower.contains("mountain") || name_lower.contains("lake") || name_lower.contains("river") || name_lower.contains("beach") || name_lower.contains("sunset") || name_lower.contains("sunrise") {
        "Natureza"
    } else {
        "Outros"
    }
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
                    let category = detect_category(&stem.to_lowercase()).to_string();
                    items.push(WallpaperItem {
                        path: p.to_path_buf(),
                        name: stem.to_string(),
                        category,
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

    // 2. Matugen color extraction
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

    let colors_def = if let Ok(s) = fs::read_to_string(&colors_file) {
        s
    } else {
        r#"
            @define-color accent_color #30ac00;
            @define-color accent_bg_color #30ac00;
            @define-color accent_fg_color #ffffff;
            @define-color window_bg_color #0f150b;
            @define-color window_fg_color #b5bdad;
            @define-color card_bg_color #171d13;
            @define-color card_fg_color #b5bdad;
        "#
        .to_string()
    };

    let ui_css = format!(
        r#"
        {}

        window.wallpaper-overlay {{
            background-color: rgba(3, 4, 7, 0.75);
        }}

        /* The Cinema Studio Floating Deck */
        .studio-deck {{
            background-color: alpha(@window_bg_color, 0.94);
            border: 1px solid alpha(@accent_color, 0.35);
            border-radius: 30px;
            box-shadow: 0 35px 90px rgba(0, 0, 0, 0.9), 0 0 2px alpha(@accent_color, 0.6);
            padding: 24px;
        }}

        /* Left Hero Stage (Curator Showcase) */
        .hero-stage {{
            background-color: alpha(@card_bg_color, 0.65);
            border: 1px solid alpha(@accent_color, 0.20);
            border-radius: 24px;
            padding: 20px;
            min-width: 400px;
            max-width: 400px;
        }}

        .hero-image-frame {{
            border-radius: 18px;
            border: 2px solid alpha(@accent_color, 0.40);
            box-shadow: 0 16px 36px rgba(0, 0, 0, 0.65), 0 0 25px alpha(@accent_color, 0.25);
        }}

        .hero-title {{
            font-size: 20px;
            font-weight: 800;
            color: #ffffff;
            letter-spacing: 0.5px;
            margin-top: 12px;
        }}

        .hero-category-badge {{
            font-size: 11px;
            font-weight: 700;
            color: @accent_color;
            background-color: alpha(@accent_color, 0.16);
            border: 1px solid alpha(@accent_color, 0.35);
            border-radius: 9999px;
            padding: 4px 12px;
            letter-spacing: 0.5px;
        }}

        .hero-status-pill {{
            font-size: 11px;
            font-weight: 700;
            border-radius: 9999px;
            padding: 4px 12px;
        }}

        .hero-status-pill.active {{
            color: @accent_fg_color;
            background-color: @accent_color;
            box-shadow: 0 0 12px alpha(@accent_color, 0.5);
        }}

        .hero-status-pill.idle {{
            color: rgba(255, 255, 255, 0.6);
            background-color: rgba(255, 255, 255, 0.08);
        }}

        .hero-btn-apply {{
            background-color: @accent_color;
            border: none;
            border-radius: 16px;
            color: @accent_fg_color;
            font-size: 14px;
            font-weight: 800;
            letter-spacing: 0.6px;
            padding: 12px 20px;
            box-shadow: 0 6px 20px alpha(@accent_color, 0.4);
            transition: all 200ms cubic-bezier(0.16, 1, 0.3, 1);
        }}

        .hero-btn-apply:hover {{
            background-color: alpha(@accent_color, 0.9);
            box-shadow: 0 8px 26px alpha(@accent_color, 0.6);
            transform: translateY(-2px);
        }}

        .hero-btn-random {{
            background-color: alpha(@accent_color, 0.12);
            border: 1px solid alpha(@accent_color, 0.30);
            border-radius: 16px;
            color: @accent_color;
            font-size: 13px;
            font-weight: 700;
            padding: 10px 18px;
            transition: all 200ms cubic-bezier(0.16, 1, 0.3, 1);
        }}

        .hero-btn-random:hover {{
            background-color: alpha(@accent_color, 0.25);
            border-color: @accent_color;
            box-shadow: 0 4px 16px alpha(@accent_color, 0.3);
        }}

        .hero-hint {{
            font-size: 11px;
            color: rgba(255, 255, 255, 0.45);
            letter-spacing: 0.3px;
            padding-top: 6px;
        }}

        /* Right Vault Stage */
        .vault-stage {{
            padding-left: 12px;
        }}

        .search-field {{
            background-color: rgba(255, 255, 255, 0.06);
            border: 1px solid rgba(255, 255, 255, 0.12);
            border-radius: 16px;
            color: #ffffff;
            font-size: 13px;
            padding: 10px 18px;
            min-width: 300px;
            transition: all 220ms ease;
        }}

        .search-field:focus {{
            background-color: rgba(255, 255, 255, 0.09);
            border-color: @accent_color;
            box-shadow: 0 0 0 2px alpha(@accent_color, 0.3), 0 0 18px alpha(@accent_color, 0.25);
        }}

        /* Category Filter Chips */
        .category-chip {{
            background-color: rgba(255, 255, 255, 0.05);
            border: 1px solid rgba(255, 255, 255, 0.10);
            border-radius: 9999px;
            color: rgba(255, 255, 255, 0.70);
            font-size: 12px;
            font-weight: 600;
            padding: 6px 14px;
            transition: all 180ms ease;
        }}

        .category-chip:hover {{
            background-color: rgba(255, 255, 255, 0.12);
            color: #ffffff;
            border-color: rgba(255, 255, 255, 0.25);
        }}

        .category-chip.active {{
            background-color: @accent_color;
            border-color: @accent_color;
            color: @accent_fg_color;
            box-shadow: 0 4px 14px alpha(@accent_color, 0.4);
        }}

        .vault-close-btn {{
            background-color: rgba(255, 255, 255, 0.06);
            border: 1px solid rgba(255, 255, 255, 0.10);
            border-radius: 14px;
            color: rgba(255, 255, 255, 0.6);
            font-size: 13px;
            font-weight: bold;
            padding: 8px 14px;
            transition: all 160ms ease;
        }}

        .vault-close-btn:hover {{
            background-color: #ff5450;
            border-color: #ff5450;
            color: #ffffff;
            box-shadow: 0 4px 14px rgba(255, 84, 80, 0.4);
        }}

        /* Wallpaper Thumbnails Grid */
        .vault-card {{
            background-color: alpha(@card_bg_color, 0.75);
            border: 1px solid rgba(255, 255, 255, 0.08);
            border-radius: 18px;
            padding: 6px;
            margin: 5px;
            transition: all 220ms cubic-bezier(0.16, 1, 0.3, 1);
        }}

        .vault-card:hover {{
            background-color: alpha(@card_bg_color, 0.98);
            border-color: @accent_color;
            box-shadow: 0 12px 28px rgba(0, 0, 0, 0.6), 0 0 20px alpha(@accent_color, 0.35);
            transform: scale(1.03) translateY(-2px);
        }}

        .vault-card.selected {{
            border: 2px solid @accent_color;
            box-shadow: 0 0 22px alpha(@accent_color, 0.5);
        }}

        .card-thumb-image {{
            border-radius: 13px;
        }}

        .card-caption {{
            font-size: 11px;
            font-weight: 600;
            color: rgba(255, 255, 255, 0.82);
            padding-top: 5px;
            padding-bottom: 2px;
        }}

        .vault-card:hover .card-caption {{
            color: @accent_color;
        }}

        .card-badge-active {{
            font-size: 9px;
            font-weight: 800;
            color: @accent_fg_color;
            background-color: @accent_color;
            border-radius: 5px;
            padding: 2px 6px;
            letter-spacing: 0.5px;
        }}

        /* Custom Modern Scrollbar */
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
        .title("Soberano Wallpaper Studio")
        .default_width(1380)
        .default_height(820)
        .build();

    window.add_css_class("wallpaper-overlay");

    // Wayland Layer Shell
    window.init_layer_shell();
    window.set_layer(Layer::Overlay);
    window.set_keyboard_mode(KeyboardMode::Exclusive);
    window.set_anchor(Edge::Top, true);
    window.set_anchor(Edge::Bottom, true);
    window.set_anchor(Edge::Left, true);
    window.set_anchor(Edge::Right, true);

    let wallpapers = scan_wallpapers();
    let current_wp = current_wallpaper_path();

    // Find currently selected item (default to active wallpaper, or first in list)
    let initial_idx = if let Some(ref cur) = current_wp {
        wallpapers
            .iter()
            .position(|w| &w.path == cur)
            .unwrap_or(0)
    } else {
        0
    };

    let selected_item = Rc::new(RefCell::new(
        wallpapers.get(initial_idx).cloned().unwrap_or(WallpaperItem {
            path: PathBuf::new(),
            name: "Nenhum".to_string(),
            category: "Todos".to_string(),
            thumbnail_path: PathBuf::new(),
        }),
    ));

    // Root overlay container
    let root_box = GtkBox::new(Orientation::Vertical, 0);
    root_box.set_valign(gtk4::Align::Center);
    root_box.set_halign(gtk4::Align::Center);

    // Studio Deck Main Container
    let studio_deck = GtkBox::new(Orientation::Horizontal, 18);
    studio_deck.add_css_class("studio-deck");
    studio_deck.set_size_request(1320, 780);

    // -------------------------------------------------------------------------
    // LEFT STAGE: The Curator Showcase (Hero View)
    // -------------------------------------------------------------------------
    let hero_stage = GtkBox::new(Orientation::Vertical, 14);
    hero_stage.add_css_class("hero-stage");

    // Large Hero Image
    let hero_image = Image::new();
    hero_image.add_css_class("hero-image-frame");
    hero_image.set_size_request(HERO_W, HERO_H);

    let update_hero_image = |img_widget: &Image, path: &Path| {
        if let Ok(pixbuf) = Pixbuf::from_file_at_scale(path, HERO_W, HERO_H, true) {
            let texture = Texture::for_pixbuf(&pixbuf);
            img_widget.set_paintable(Some(&texture));
        }
    };
    update_hero_image(&hero_image, &selected_item.borrow().path);

    // Metadata Row
    let meta_row = GtkBox::new(Orientation::Horizontal, 8);
    meta_row.set_valign(gtk4::Align::Center);

    let category_badge = Label::new(Some(&selected_item.borrow().category));
    category_badge.add_css_class("hero-category-badge");

    let is_cur_active = current_wp.as_ref() == Some(&selected_item.borrow().path);
    let status_pill = Label::new(Some(if is_cur_active { "✓ ATUAL NO DESKTOP" } else { "PRONTO PARA APLICAR" }));
    status_pill.add_css_class("hero-status-pill");
    status_pill.add_css_class(if is_cur_active { "active" } else { "idle" });

    meta_row.append(&category_badge);
    meta_row.append(&status_pill);

    // Big Wallpaper Title
    let hero_title = Label::new(Some(&selected_item.borrow().name));
    hero_title.add_css_class("hero-title");
    hero_title.set_halign(gtk4::Align::Start);
    hero_title.set_ellipsize(gtk4::pango::EllipsizeMode::End);
    hero_title.set_max_width_chars(28);

    // Action Buttons Row
    let actions_box = GtkBox::new(Orientation::Vertical, 10);
    actions_box.set_vexpand(true);
    actions_box.set_valign(gtk4::Align::End);

    let apply_btn = Button::with_label("󰸉  Aplicar Wallpaper");
    apply_btn.add_css_class("hero-btn-apply");

    let win_apply = window.clone();
    let sel_for_apply = Rc::clone(&selected_item);
    apply_btn.connect_clicked(move |_| {
        let item = sel_for_apply.borrow();
        if item.path.exists() {
            apply_wallpaper(&item.path);
            win_apply.close();
            std::process::exit(0);
        }
    });

    let random_btn = Button::with_label("󰒝  Sortear Aleatório");
    random_btn.add_css_class("hero-btn-random");

    let all_wps_rand = wallpapers.clone();
    let win_rand = window.clone();
    random_btn.connect_clicked(move |_| {
        if !all_wps_rand.is_empty() {
            use std::time::SystemTime;
            let seed = SystemTime::now()
                .duration_since(SystemTime::UNIX_EPOCH)
                .map(|d| d.as_nanos())
                .unwrap_or(42);
            let idx = (seed as usize) % all_wps_rand.len();
            apply_wallpaper(&all_wps_rand[idx].path);
            win_rand.close();
            std::process::exit(0);
        }
    });

    let hint_label = Label::new(Some("Atalhos:  [Enter] Aplicar  •  [Esc] Fechar  •  [Setas] Navegar"));
    hint_label.add_css_class("hero-hint");
    hint_label.set_halign(gtk4::Align::Center);

    actions_box.append(&apply_btn);
    actions_box.append(&random_btn);
    actions_box.append(&hint_label);

    hero_stage.append(&hero_image);
    hero_stage.append(&meta_row);
    hero_stage.append(&hero_title);
    hero_stage.append(&actions_box);

    // -------------------------------------------------------------------------
    // RIGHT STAGE: The Wallpaper Vault
    // -------------------------------------------------------------------------
    let vault_stage = GtkBox::new(Orientation::Vertical, 14);
    vault_stage.add_css_class("vault-stage");
    vault_stage.set_hexpand(true);

    // Top Controls Bar (Search + Close)
    let top_bar = GtkBox::new(Orientation::Horizontal, 12);
    top_bar.set_valign(gtk4::Align::Center);

    let search_entry = SearchEntry::new();
    search_entry.set_placeholder_text(Some("Pesquisar entre todos os wallpapers..."));
    search_entry.add_css_class("search-field");
    search_entry.set_hexpand(true);

    let count_badge = Label::new(Some(&format!("{} Wallpapers", wallpapers.len())));
    count_badge.add_css_class("category-chip");

    let close_btn = Button::with_label("✕");
    close_btn.add_css_class("vault-close-btn");
    let win_close = window.clone();
    close_btn.connect_clicked(move |_| {
        win_close.close();
        std::process::exit(0);
    });

    top_bar.append(&search_entry);
    top_bar.append(&count_badge);
    top_bar.append(&close_btn);

    // Category Filter Chips Bar
    let chips_bar = GtkBox::new(Orientation::Horizontal, 8);
    let categories = ["Todos", "Dynamic", "Anime", "Lofi", "Natureza", "City", "Space"];
    let active_category = Rc::new(RefCell::new("Todos".to_string()));
    let category_buttons = Rc::new(RefCell::new(Vec::<Button>::new()));

    // FlowBox Grid of Cards
    let flowbox = FlowBox::new();
    flowbox.set_valign(gtk4::Align::Start);
    flowbox.set_max_children_per_line(3);
    flowbox.set_min_children_per_line(3);
    flowbox.set_selection_mode(gtk4::SelectionMode::None);
    flowbox.set_homogeneous(true);

    struct CardMeta {
        child: FlowBoxChild,
        container: GtkBox,
        name_lower: String,
        category: String,
        item: WallpaperItem,
    }
    let card_registry = Rc::new(RefCell::new(Vec::<CardMeta>::new()));

    // Closure to update hero stage when card selected
    let hero_img_rc = hero_image.clone();
    let hero_title_rc = hero_title.clone();
    let cat_badge_rc = category_badge.clone();
    let status_pill_rc = status_pill.clone();
    let cur_wp_rc = current_wp.clone();
    let sel_item_rc = Rc::clone(&selected_item);
    let card_reg_for_sel = Rc::clone(&card_registry);

    let select_card = Rc::new(move |item: WallpaperItem| {
        *sel_item_rc.borrow_mut() = item.clone();

        // Update hero image & metadata
        update_hero_image(&hero_img_rc, &item.path);
        hero_title_rc.set_text(&item.name);
        cat_badge_rc.set_text(&item.category);

        let is_now_active = cur_wp_rc.as_ref() == Some(&item.path);
        status_pill_rc.set_text(if is_now_active { "✓ ATUAL NO DESKTOP" } else { "PRONTO PARA APLICAR" });
        if is_now_active {
            status_pill_rc.remove_css_class("idle");
            status_pill_rc.add_css_class("active");
        } else {
            status_pill_rc.remove_css_class("active");
            status_pill_rc.add_css_class("idle");
        }

        // Highlight selected card border
        let reg = card_reg_for_sel.borrow();
        for meta in reg.iter() {
            if meta.item.path == item.path {
                meta.container.add_css_class("selected");
            } else {
                meta.container.remove_css_class("selected");
            }
        }
    });

    // Populate thumbnails in FlowBox
    for item in &wallpapers {
        let card_item = GtkBox::new(Orientation::Vertical, 4);
        card_item.add_css_class("vault-card");
        card_item.set_size_request(THUMB_W + 12, THUMB_H + 34);

        let is_initial = &item.path == &selected_item.borrow().path;
        if is_initial {
            card_item.add_css_class("selected");
        }

        let is_active_now = current_wp.as_ref() == Some(&item.path);

        if let Ok(pixbuf) = Pixbuf::from_file(&item.thumbnail_path) {
            let texture = Texture::for_pixbuf(&pixbuf);
            let img = Image::from_paintable(Some(&texture));
            img.add_css_class("card-thumb-image");
            img.set_pixel_size(THUMB_W);
            card_item.append(&img);
        }

        let label_row = GtkBox::new(Orientation::Horizontal, 6);
        let name_label = Label::new(Some(&item.name));
        name_label.add_css_class("card-caption");
        name_label.set_ellipsize(gtk4::pango::EllipsizeMode::End);
        name_label.set_hexpand(true);
        name_label.set_halign(gtk4::Align::Start);
        label_row.append(&name_label);

        if is_active_now {
            let badge = Label::new(Some("✓ ATIVO"));
            badge.add_css_class("card-badge-active");
            label_row.append(&badge);
        }
        card_item.append(&label_row);

        // Click Gesture: Single click selects hero, double click applies & exits
        let click = GestureClick::new();
        let item_click = item.clone();
        let sel_fn = Rc::clone(&select_card);
        let win_apply_quick = window.clone();
        click.connect_released(move |_, n_press, _, _| {
            sel_fn(item_click.clone());
            if n_press >= 2 {
                apply_wallpaper(&item_click.path);
                win_apply_quick.close();
                std::process::exit(0);
            }
        });
        card_item.add_controller(click);

        let child = FlowBoxChild::new();
        child.set_child(Some(&card_item));
        flowbox.append(&child);

        card_registry.borrow_mut().push(CardMeta {
            child,
            container: card_item,
            name_lower: item.name.to_lowercase(),
            category: item.category.clone(),
            item: item.clone(),
        });
    }

    // Filter cards handler
    let card_reg_filter = Rc::clone(&card_registry);
    let search_rc = search_entry.clone();
    let act_cat_rc = Rc::clone(&active_category);

    let recompute_filter = Rc::new(move || {
        let query = search_rc.text().to_lowercase();
        let cat = act_cat_rc.borrow().clone();
        let reg = card_reg_filter.borrow();

        for meta in reg.iter() {
            let matches_query = query.is_empty() || meta.name_lower.contains(&query);
            let matches_cat = cat == "Todos" || meta.category == cat;
            meta.child.set_visible(matches_query && matches_cat);
        }
    });

    // Connect search entry
    let recomp_search = Rc::clone(&recompute_filter);
    search_entry.connect_search_changed(move |_| {
        recomp_search();
    });

    // Populate category buttons
    for cat_name in categories {
        let btn = Button::with_label(cat_name);
        btn.add_css_class("category-chip");
        if cat_name == "Todos" {
            btn.add_css_class("active");
        }

        let cat_val = cat_name.to_string();
        let act_cat_set = Rc::clone(&active_category);
        let btn_list = Rc::clone(&category_buttons);
        let recomp_cat = Rc::clone(&recompute_filter);

        btn.connect_clicked(move |clicked_btn| {
            *act_cat_set.borrow_mut() = cat_val.clone();
            for b in btn_list.borrow().iter() {
                b.remove_css_class("active");
            }
            clicked_btn.add_css_class("active");
            recomp_cat();
        });

        category_buttons.borrow_mut().push(btn.clone());
        chips_bar.append(&btn);
    }

    let scroll = ScrolledWindow::builder()
        .hscrollbar_policy(gtk4::PolicyType::Never)
        .vscrollbar_policy(gtk4::PolicyType::Automatic)
        .child(&flowbox)
        .vexpand(true)
        .build();

    vault_stage.append(&top_bar);
    vault_stage.append(&chips_bar);
    vault_stage.append(&scroll);

    studio_deck.append(&hero_stage);
    studio_deck.append(&vault_stage);
    root_box.append(&studio_deck);

    // Click outside deck closes window
    let bg_click = GestureClick::new();
    let win_bg = window.clone();
    bg_click.connect_released(move |gesture, _, x, y| {
        if let Some(widget) = gesture.widget() {
            let width = widget.width() as f64;
            let height = widget.height() as f64;
            let deck_w = 1320.0;
            let deck_h = 780.0;
            let min_x = (width - deck_w) / 2.0;
            let max_x = min_x + deck_w;
            let min_y = (height - deck_h) / 2.0;
            let max_y = min_y + deck_h;

            if x < min_x || x > max_x || y < min_y || y > max_y {
                win_bg.close();
                std::process::exit(0);
            }
        }
    });
    window.add_controller(bg_click);

    // Global Key Controller
    let key_controller = EventControllerKey::new();
    key_controller.set_propagation_phase(gtk4::PropagationPhase::Capture);
    let win_key = window.clone();
    let sel_for_key = Rc::clone(&selected_item);

    key_controller.connect_key_pressed(move |_, keyval, _, _| {
        if keyval == gdk::Key::Escape {
            win_key.close();
            std::process::exit(0);
        } else if keyval == gdk::Key::Return || keyval == gdk::Key::KP_Enter {
            let item = sel_for_key.borrow();
            if item.path.exists() {
                apply_wallpaper(&item.path);
                win_key.close();
                std::process::exit(0);
            }
            glib::Propagation::Stop
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
