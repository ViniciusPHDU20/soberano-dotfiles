use gtk4::prelude::*;
use gtk4::{
    gdk, gdk_pixbuf::Pixbuf, glib, Application, ApplicationWindow, Box as GtkBox,
    Button, ContentFit, EventControllerKey, FlowBox, FlowBoxChild, GestureClick, Label, Orientation,
    Picture, Scale, ScrolledWindow, SearchEntry, Switch,
};
use gtk4_layer_shell::{Edge, KeyboardMode, Layer, LayerShell};
use serde::{Deserialize, Serialize};
use std::cell::RefCell;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};
use std::rc::Rc;
use walkdir::WalkDir;

const APP_ID: &str = "org.soberano.wallpaperpicker";
const THUMB_W: i32 = 246;
const THUMB_H: i32 = 138;
const HERO_W: i32 = 440;
const HERO_H: i32 = 248;

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
enum WallpaperKind {
    Static,
    Live { engine_type: String },
}

#[derive(Clone, Debug, Serialize, Deserialize)]
struct WallpaperItem {
    path: PathBuf,
    name: String,
    category: String,
    thumbnail_path: PathBuf,
    preview_path: PathBuf,
    kind: WallpaperKind,
}

#[derive(Deserialize, Default)]
#[allow(dead_code)]
struct ProjectJson {
    title: Option<String>,
    #[serde(rename = "type")]
    item_type: Option<String>,
    preview: Option<String>,
    file: Option<String>,
    tags: Option<Vec<String>>,
}

#[derive(Serialize, Deserialize, Clone, Debug)]
struct LiveWallpaperConfig {
    fps: u32,
    volume: u32,
    silent: bool,
    automute: bool,
    audio_processing: bool,
    fullscreen_pause: bool,
    scaling: String,
    mouse_interaction: bool,
    parallax: bool,
    particles: bool,
}

impl Default for LiveWallpaperConfig {
    fn default() -> Self {
        Self {
            fps: 144,
            volume: 50,
            silent: false,
            automute: false,
            audio_processing: true,
            fullscreen_pause: true,
            scaling: "fill".to_string(),
            mouse_interaction: true,
            parallax: true,
            particles: true,
        }
    }
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
        let r = u8::from_str_radix(&clean[0..2], 16).unwrap_or(255);
        let g = u8::from_str_radix(&clean[2..4], 16).unwrap_or(96);
        let b = u8::from_str_radix(&clean[4..6], 16).unwrap_or(90);
        format!("rgba({}, {}, {}, {})", r, g, b, alpha)
    } else {
        format!("rgba(255, 96, 90, {})", alpha)
    }
}

fn load_system_colors() -> SystemColors {
    let home = std::env::var("HOME").unwrap_or_else(|_| "/home/viniciusphdu".to_string());
    let colors_file = PathBuf::from(&home).join(".config/gtk-4.0/colors.css");

    let mut accent = "#ff605a".to_string();
    let mut window_bg = "#12131a".to_string();
    let mut card_bg = "#1c1d26".to_string();
    let mut window_fg = "#f0f0f5".to_string();

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

fn dirs_or_home_cache() -> PathBuf {
    if let Ok(c) = std::env::var("XDG_CACHE_HOME") {
        PathBuf::from(c)
    } else if let Ok(h) = std::env::var("HOME") {
        PathBuf::from(h).join(".cache")
    } else {
        PathBuf::from("/tmp")
    }
}

fn get_config_file() -> PathBuf {
    let home = std::env::var("HOME").unwrap_or_else(|_| "/home/viniciusphdu".to_string());
    PathBuf::from(home).join(".config/soberano/livewallpaper.json")
}

fn load_live_config() -> LiveWallpaperConfig {
    let path = get_config_file();
    if let Ok(content) = fs::read_to_string(&path) {
        if let Ok(cfg) = serde_json::from_str(&content) {
            return cfg;
        }
    }
    LiveWallpaperConfig::default()
}

fn save_live_config(cfg: &LiveWallpaperConfig) {
    let path = get_config_file();
    if let Some(parent) = path.parent() {
        let _ = fs::create_dir_all(parent);
    }
    if let Ok(json) = serde_json::to_string_pretty(cfg) {
        let _ = fs::write(path, json);
    }
}

fn reload_live_wallpaper() {
    let home = std::env::var("HOME").unwrap_or_else(|_| "/home/viniciusphdu".to_string());
    let script = PathBuf::from(&home).join("dotfiles/scripts/soberano-livewallpaper.sh");
    let _ = Command::new(&script).arg("--reload").spawn();
}

fn get_cache_dir() -> PathBuf {
    let mut dir = dirs_or_home_cache();
    dir.push("soberano_thumbnails");
    let _ = fs::create_dir_all(&dir);
    dir
}

fn is_live_engine_running() -> bool {
    let output = Command::new("systemctl")
        .args(["--user", "is-active", "--quiet", "soberano-livewallpaper"])
        .status();
    if let Ok(s) = output {
        if s.success() {
            return true;
        }
    }

    Command::new("pgrep")
        .args(["-x", "linux-wallpaperengine"])
        .output()
        .map(|o| o.status.success())
        .unwrap_or(false)
}

fn current_active_wallpaper() -> (Option<PathBuf>, bool) {
    let cache_dir = dirs_or_home_cache();
    if is_live_engine_running() {
        let state = cache_dir.join("soberano_livewallpaper.state");
        if let Ok(content) = fs::read_to_string(state) {
            let trimmed = content.trim();
            if !trimmed.is_empty() {
                return (Some(PathBuf::from(trimmed)), true);
            }
        }
    }

    let state = cache_dir.join("soberano_wallpaper.txt");
    if let Ok(content) = fs::read_to_string(state) {
        let trimmed = content.trim();
        if !trimmed.is_empty() {
            return (Some(PathBuf::from(trimmed)), false);
        }
    }

    (None, false)
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

fn find_workshop_dirs() -> Vec<PathBuf> {
    let home = std::env::var("HOME").unwrap_or_else(|_| "/home/viniciusphdu".to_string());
    let mut dirs = Vec::new();

    // 1. Default Steam library
    let default_ws = PathBuf::from(&home).join(".local/share/Steam/steamapps/workshop/content/431960");
    if default_ws.is_dir() {
        dirs.push(default_ws);
    }

    // 2. Parse libraryfolders.vdf
    let vdf_candidates = [
        PathBuf::from(&home).join(".local/share/Steam/steamapps/libraryfolders.vdf"),
        PathBuf::from(&home).join(".steam/steam/steamapps/libraryfolders.vdf"),
    ];

    for vdf in &vdf_candidates {
        if let Ok(content) = fs::read_to_string(vdf) {
            for line in content.lines() {
                let trimmed = line.trim();
                if trimmed.starts_with("\"path\"") {
                    let parts: Vec<&str> = trimmed.split('"').collect();
                    if parts.len() >= 4 {
                        let ws = PathBuf::from(parts[3]).join("steamapps/workshop/content/431960");
                        if ws.is_dir() && !dirs.contains(&ws) {
                            dirs.push(ws);
                        }
                    }
                }
            }
        }
    }

    // 3. User custom live wallpaper directory
    let user_live = PathBuf::from(&home).join("wallpapers/live");
    let _ = fs::create_dir_all(&user_live);
    if user_live.is_dir() && !dirs.contains(&user_live) {
        dirs.push(user_live);
    }

    dirs
}

fn scan_wallpapers() -> Vec<WallpaperItem> {
    let manifest_file = dirs_or_home_cache().join("soberano_wallpapers_manifest.json");

    // Fast-path: Instant load in ~1ms from cached manifest
    if manifest_file.exists() {
        if let Ok(content) = fs::read_to_string(&manifest_file) {
            if let Ok(cached) = serde_json::from_str::<Vec<WallpaperItem>>(&content) {
                if !cached.is_empty() {
                    return cached;
                }
            }
        }
    }

    let home = std::env::var("HOME").unwrap_or_else(|_| "/home/viniciusphdu".to_string());
    let wall_dir = PathBuf::from(&home).join("dotfiles/wallpapers");
    let cache_dir = get_cache_dir();

    let mut items = Vec::new();

    // 1. Scan Static Wallpapers (Our Curated Dotfiles Collection)
    if wall_dir.is_dir() {
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
                            preview_path: p.to_path_buf(),
                            kind: WallpaperKind::Static,
                        });
                    }
                }
            }
        }
    }

    // 2. Scan Steam Workshop & Live Wallpapers (Separate Collection)
    for ws_dir in find_workshop_dirs() {
        if let Ok(entries) = fs::read_dir(&ws_dir) {
            for entry in entries.filter_map(|e| e.ok()) {
                let p = entry.path();
                if p.is_dir() {
                    let project_file = p.join("project.json");
                    let mut title = p.file_name().and_then(|s| s.to_str()).unwrap_or("Workshop Item").to_string();
                    let mut engine_type = "Scene".to_string();
                    let mut preview_found: Option<PathBuf> = None;
                    let mut detected_cat = "Geral".to_string();

                    if project_file.is_file() {
                        if let Ok(content) = fs::read_to_string(&project_file) {
                            if let Ok(meta) = serde_json::from_str::<ProjectJson>(&content) {
                                if let Some(t) = meta.title {
                                    if !t.trim().is_empty() {
                                        title = t.trim().to_string();
                                    }
                                }
                                if let Some(t) = meta.item_type {
                                    if !t.trim().is_empty() {
                                        engine_type = t.trim().to_string();
                                    }
                                }
                                if let Some(prev) = meta.preview {
                                    let prev_p = p.join(prev);
                                    if prev_p.is_file() {
                                        preview_found = Some(prev_p);
                                    }
                                }
                                if let Some(tags) = meta.tags {
                                    let tag_str = tags.join(" ").to_lowercase();
                                    let det = detect_category(&tag_str);
                                    if det != "Outros" {
                                        detected_cat = det.to_string();
                                    }
                                }
                            }
                        }
                    }

                    if preview_found.is_none() {
                        for candidate in ["preview.jpg", "preview.png", "preview.gif", "preview.webp"] {
                            let cand_p = p.join(candidate);
                            if cand_p.is_file() {
                                preview_found = Some(cand_p);
                                break;
                            }
                        }
                    }

                    if let Some(preview_file) = preview_found {
                        let thumb = get_thumbnail_path(&p, &cache_dir);
                        ensure_thumbnail(&preview_file, &thumb);

                        items.push(WallpaperItem {
                            path: p.clone(),
                            name: title,
                            category: detected_cat,
                            thumbnail_path: thumb,
                            preview_path: preview_file,
                            kind: WallpaperKind::Live { engine_type },
                        });
                    }
                }
            }
        }
    }

    items.sort_by(|a, b| a.name.to_lowercase().cmp(&b.name.to_lowercase()));

    if let Ok(json) = serde_json::to_string(&items) {
        let _ = fs::write(manifest_file, json);
    }

    items
}

fn apply_wallpaper(item: &WallpaperItem) {
    let home = std::env::var("HOME").unwrap_or_else(|_| "/home/viniciusphdu".to_string());
    match &item.kind {
        WallpaperKind::Live { .. } => {
            let script = PathBuf::from(&home).join("dotfiles/scripts/soberano-livewallpaper.sh");
            let _ = Command::new(&script)
                .arg(&item.path)
                .stdin(Stdio::null())
                .stdout(Stdio::null())
                .stderr(Stdio::null())
                .spawn();
        }
        WallpaperKind::Static => {
            let script = PathBuf::from(&home).join("dotfiles/scripts/WallpaperSelect.sh");
            if script.exists() {
                let _ = Command::new(&script)
                    .args(["--apply", item.path.to_string_lossy().as_ref()])
                    .stdin(Stdio::null())
                    .stdout(Stdio::null())
                    .stderr(Stdio::null())
                    .spawn();
            } else {
                let _ = Command::new("matugen")
                    .args([
                        "image",
                        item.path.to_string_lossy().as_ref(),
                        "-t",
                        "scheme-vibrant",
                        "-m",
                        "dark",
                        "--prefer",
                        "saturation",
                        "--contrast",
                        "-0.45",
                    ])
                    .stdin(Stdio::null())
                    .stdout(Stdio::null())
                    .stderr(Stdio::null())
                    .spawn();
            }
        }
    }
}

fn stop_live_wallpaper() {
    let home = std::env::var("HOME").unwrap_or_else(|_| "/home/viniciusphdu".to_string());
    let script = PathBuf::from(&home).join("dotfiles/scripts/soberano-livewallpaper.sh");
    let _ = Command::new(&script)
        .arg("--stop")
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .spawn();
}

fn load_css() {
    let provider = gtk4::CssProvider::new();
    let colors = load_system_colors();

    let accent = &colors.accent;
    let window_bg = &colors.window_bg;
    let card_bg = &colors.card_bg;
    let window_fg = &colors.window_fg;

    let deck_bg = hex_to_rgba(window_bg, 0.94);
    let deck_border = hex_to_rgba(accent, 0.38);
    let deck_glow = hex_to_rgba(accent, 0.55);

    let hero_bg = hex_to_rgba(card_bg, 0.70);
    let hero_border = hex_to_rgba(accent, 0.25);
    let hero_frame_border = hex_to_rgba(accent, 0.50);
    let hero_frame_glow = hex_to_rgba(accent, 0.32);

    let accent_badge_bg = hex_to_rgba(accent, 0.16);
    let accent_badge_border = hex_to_rgba(accent, 0.38);

    let btn_apply_shadow = hex_to_rgba(accent, 0.45);
    let btn_apply_hover_shadow = hex_to_rgba(accent, 0.65);

    let search_focus_border = accent;
    let search_focus_shadow = hex_to_rgba(accent, 0.25);

    let card_bg_rgba = hex_to_rgba(card_bg, 0.78);
    let card_hover_bg = hex_to_rgba(card_bg, 0.98);
    let card_hover_border = accent;
    let card_hover_glow = hex_to_rgba(accent, 0.38);
    let card_selected_glow = hex_to_rgba(accent, 0.55);

    let scroll_slider_bg = hex_to_rgba(accent, 0.40);
    let text_secondary = hex_to_rgba(window_fg, 0.70);
    let text_muted = hex_to_rgba(window_fg, 0.45);

    let ui_css = format!(
        r#"
        window.wallpaper-overlay {{
            background-color: rgba(3, 4, 7, 0.75);
        }}

        /* The Cinema Studio Floating Deck */
        .studio-deck {{
            background-color: {deck_bg};
            border: 1px solid {deck_border};
            border-radius: 30px;
            box-shadow: 0 35px 90px rgba(0, 0, 0, 0.9), 0 0 2px {deck_glow};
            padding: 24px;
        }}

        /* Left Hero Stage (Curator Showcase) */
        .hero-stage {{
            background-color: {hero_bg};
            border: 1px solid {hero_border};
            border-radius: 26px;
            padding: 22px;
            min-width: 480px;
        }}

        .hero-image-frame {{
            border-radius: 20px;
            border: 2px solid {hero_frame_border};
            box-shadow: 0 18px 40px rgba(0, 0, 0, 0.70), 0 0 30px {hero_frame_glow};
            min-width: 440px;
            min-height: 248px;
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
            color: {accent};
            background-color: {accent_badge_bg};
            border: 1px solid {accent_badge_border};
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
            color: #ffffff;
            background-color: {accent};
            box-shadow: 0 0 14px {card_hover_glow};
        }}

        .hero-status-pill.idle {{
            color: rgba(255, 255, 255, 0.65);
            background-color: rgba(255, 255, 255, 0.08);
        }}

        .hero-btn-apply {{
            background-color: {accent};
            border: none;
            border-radius: 16px;
            color: #ffffff;
            font-size: 14px;
            font-weight: 800;
            letter-spacing: 0.6px;
            padding: 13px 20px;
            box-shadow: 0 6px 22px {btn_apply_shadow};
            transition: all 200ms cubic-bezier(0.16, 1, 0.3, 1);
        }}

        .hero-btn-apply:hover {{
            background-color: {accent};
            box-shadow: 0 8px 30px {btn_apply_hover_shadow};
            transform: translateY(-2px);
        }}

        .hero-btn-random {{
            background-color: {accent_badge_bg};
            border: 1px solid {accent_badge_border};
            border-radius: 16px;
            color: {accent};
            font-size: 13px;
            font-weight: 700;
            padding: 10px 18px;
            transition: all 200ms cubic-bezier(0.16, 1, 0.3, 1);
        }}

        .hero-btn-random:hover {{
            background-color: {accent};
            color: #ffffff;
            box-shadow: 0 4px 16px {card_hover_glow};
        }}

        .hero-btn-stop {{
            background-color: rgba(255, 84, 80, 0.16);
            border: 1px solid rgba(255, 84, 80, 0.45);
            border-radius: 16px;
            color: #ff5450;
            font-size: 13px;
            font-weight: 700;
            padding: 10px 18px;
            transition: all 200ms cubic-bezier(0.16, 1, 0.3, 1);
        }}

        .hero-btn-stop:hover {{
            background-color: #ff5450;
            color: #ffffff;
            box-shadow: 0 4px 16px rgba(255, 84, 80, 0.4);
        }}

        .hero-hint {{
            font-size: 11px;
            color: {text_muted};
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
            min-width: 240px;
            transition: all 220ms ease;
        }}

        .search-field:focus {{
            background-color: rgba(255, 255, 255, 0.09);
            border-color: {search_focus_border};
            box-shadow: 0 0 0 2px {search_focus_shadow};
        }}

        /* Top Navigation Tabs */
        .tab-btn {{
            background-color: rgba(255, 255, 255, 0.05);
            border: 1px solid rgba(255, 255, 255, 0.10);
            border-radius: 14px;
            color: {text_secondary};
            font-size: 12px;
            font-weight: 700;
            padding: 9px 15px;
            transition: all 180ms ease;
        }}

        .tab-btn:hover {{
            background-color: rgba(255, 255, 255, 0.12);
            color: #ffffff;
        }}

        .tab-btn.active {{
            background-color: {accent};
            border-color: {accent};
            color: #ffffff;
            box-shadow: 0 4px 14px {card_hover_glow};
        }}

        /* Category Filter Chips */
        .category-chip {{
            background-color: rgba(255, 255, 255, 0.05);
            border: 1px solid rgba(255, 255, 255, 0.10);
            border-radius: 9999px;
            color: {text_secondary};
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
            background-color: {accent};
            border-color: {accent};
            color: #ffffff;
            box-shadow: 0 4px 14px {card_hover_glow};
        }}

        .vault-close-btn {{
            background-color: rgba(255, 255, 255, 0.06);
            border: 1px solid rgba(255, 255, 255, 0.10);
            border-radius: 14px;
            color: {text_secondary};
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
            background-color: {card_bg_rgba};
            border: 1px solid rgba(255, 255, 255, 0.08);
            border-radius: 18px;
            padding: 6px;
            margin: 5px;
            transition: all 220ms cubic-bezier(0.16, 1, 0.3, 1);
        }}

        .vault-card:hover {{
            background-color: {card_hover_bg};
            border-color: {card_hover_border};
            box-shadow: 0 12px 28px rgba(0, 0, 0, 0.6), 0 0 20px {card_hover_glow};
            transform: scale(1.03) translateY(-2px);
        }}

        .vault-card.selected {{
            border: 2px solid {accent};
            box-shadow: 0 0 22px {card_selected_glow};
        }}

        .card-thumb-image {{
            border-radius: 13px;
        }}

        .card-caption {{
            font-size: 11px;
            font-weight: 600;
            color: {window_fg};
            padding-top: 5px;
            padding-bottom: 2px;
        }}

        .vault-card:hover .card-caption {{
            color: {accent};
        }}

        .card-badge-active {{
            font-size: 9px;
            font-weight: 800;
            color: #ffffff;
            background-color: {accent};
            border-radius: 5px;
            padding: 2px 6px;
            letter-spacing: 0.5px;
        }}

        .card-badge-live {{
            font-size: 9px;
            font-weight: 800;
            color: #ffffff;
            background-color: #ff5450;
            border-radius: 5px;
            padding: 2px 6px;
            letter-spacing: 0.5px;
        }}

        /* Wallpaper Engine Settings Dashboard Cards */
        .settings-card {{
            background-color: {card_bg_rgba};
            border: 1px solid rgba(255, 255, 255, 0.08);
            border-radius: 20px;
            padding: 18px 22px;
            margin-bottom: 12px;
        }}

        .settings-card-title {{
            font-size: 14px;
            font-weight: 800;
            color: #ffffff;
            letter-spacing: 0.5px;
            margin-bottom: 8px;
        }}

        .settings-row-label {{
            font-size: 13px;
            font-weight: 600;
            color: #ffffff;
        }}

        .settings-row-desc {{
            font-size: 11px;
            color: {text_muted};
        }}

        /* Modern GTK Scale Slider */
        scale trough {{
            background-color: rgba(255, 255, 255, 0.10);
            border-radius: 9999px;
            min-height: 8px;
        }}

        scale highlight {{
            background-color: {accent};
            border-radius: 9999px;
            min-height: 8px;
        }}

        scale slider {{
            background-color: #ffffff;
            border-radius: 9999px;
            min-width: 16px;
            min-height: 16px;
            box-shadow: 0 2px 6px rgba(0, 0, 0, 0.5);
        }}

        /* Modern GTK Switch */
        switch {{
            background-color: rgba(255, 255, 255, 0.12);
            border-radius: 9999px;
            border: 1px solid rgba(255, 255, 255, 0.15);
            min-width: 44px;
            min-height: 24px;
        }}

        switch:checked {{
            background-color: {accent};
            border-color: {accent};
        }}

        /* Custom Modern Scrollbar */
        scrolledwindow scrollbar.vertical {{
            background-color: transparent;
            min-width: 6px;
        }}
        scrolledwindow scrollbar.vertical slider {{
            background-color: {scroll_slider_bg};
            border-radius: 9999px;
            min-width: 6px;
            transition: background-color 200ms ease;
        }}
        scrolledwindow scrollbar.vertical slider:hover {{
            background-color: {accent};
        }}
        "#,
    );

    provider.load_from_string(&ui_css);
    if let Some(display) = gdk::Display::default() {
        gtk4::style_context_add_provider_for_display(
            &display,
            &provider,
            gtk4::STYLE_PROVIDER_PRIORITY_USER,
        );
    }
}

fn build_ui(app: &Application) {
    load_css();

    let window = ApplicationWindow::builder()
        .application(app)
        .title("Soberano Wallpaper Studio")
        .default_width(1440)
        .default_height(840)
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

    let all_wallpapers = scan_wallpapers();

    // Separate Curated Static Wallpapers from Steam Live/Video Wallpapers
    let mut static_wallpapers = Vec::new();
    let mut live_wallpapers = Vec::new();

    for w in all_wallpapers {
        match w.kind {
            WallpaperKind::Static => static_wallpapers.push(w),
            WallpaperKind::Live { .. } => live_wallpapers.push(w),
        }
    }

    // Single check of current active wallpaper (Eliminates the 105 pgrep subprocesses bottleneck!)
    let (current_active_path, is_live_active) = current_active_wallpaper();

    // Default selected item
    let initial_item = if let Some(ref cur) = current_active_path {
        if is_live_active {
            live_wallpapers.iter().find(|w| &w.path == cur).cloned()
        } else {
            static_wallpapers.iter().find(|w| &w.path == cur).cloned()
        }
    } else {
        None
    };

    let selected_item = Rc::new(RefCell::new(
        initial_item.unwrap_or_else(|| {
            static_wallpapers.first().cloned().unwrap_or(WallpaperItem {
                path: PathBuf::new(),
                name: "Nenhum".to_string(),
                category: "Todos".to_string(),
                thumbnail_path: PathBuf::new(),
                preview_path: PathBuf::new(),
                kind: WallpaperKind::Static,
            })
        }),
    ));

    let live_config = Rc::new(RefCell::new(load_live_config()));

    // Root overlay container
    let root_box = GtkBox::new(Orientation::Vertical, 0);
    root_box.set_valign(gtk4::Align::Center);
    root_box.set_halign(gtk4::Align::Center);

    // Studio Deck Main Container
    let studio_deck = GtkBox::new(Orientation::Horizontal, 20);
    studio_deck.add_css_class("studio-deck");
    studio_deck.set_size_request(1380, 800);

    // -------------------------------------------------------------------------
    // LEFT STAGE: The Curator Showcase (Hero View)
    // -------------------------------------------------------------------------
    let hero_stage = GtkBox::new(Orientation::Vertical, 16);
    hero_stage.add_css_class("hero-stage");

    let hero_picture = Picture::new();
    hero_picture.set_content_fit(ContentFit::Cover);
    hero_picture.set_can_shrink(true);
    hero_picture.set_size_request(HERO_W, HERO_H);
    hero_picture.add_css_class("hero-image-frame");

    let update_hero_image = |pic_widget: &Picture, path: &Path| {
        pic_widget.set_filename(Some(path));
    };
    update_hero_image(&hero_picture, &selected_item.borrow().preview_path);

    // Metadata Row
    let meta_row = GtkBox::new(Orientation::Horizontal, 8);
    meta_row.set_valign(gtk4::Align::Center);

    let category_badge = Label::new(None);
    category_badge.add_css_class("hero-category-badge");

    let status_pill = Label::new(None);
    status_pill.add_css_class("hero-status-pill");

    let cur_active_path_rc = current_active_path.clone();
    let update_meta_labels = move |cat_widget: &Label, status_widget: &Label, item: &WallpaperItem| {
        match &item.kind {
            WallpaperKind::Live { engine_type } => {
                cat_widget.set_text(&format!("󰑋 VÍDEO • {}", engine_type.to_uppercase()));
            }
            WallpaperKind::Static => {
                cat_widget.set_text(&format!("󰸉 {}", item.category));
            }
        }

        let is_cur_active = cur_active_path_rc.as_ref() == Some(&item.path);

        if is_cur_active {
            status_widget.set_text(if is_live_active { "✓ LIVE ATIVO NO DESKTOP" } else { "✓ ATUAL NO DESKTOP" });
            status_widget.remove_css_class("idle");
            status_widget.add_css_class("active");
        } else {
            status_widget.set_text("PRONTO PARA APLICAR");
            status_widget.remove_css_class("active");
            status_widget.add_css_class("idle");
        }
    };
    update_meta_labels(&category_badge, &status_pill, &selected_item.borrow());

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

    let update_apply_btn_label = |btn: &Button, item: &WallpaperItem| {
        match &item.kind {
            WallpaperKind::Live { engine_type } => {
                btn.set_label(&format!("󰑋  Iniciar Vídeo ({})", engine_type.to_uppercase()));
            }
            WallpaperKind::Static => {
                btn.set_label("󰸉  Aplicar Wallpaper");
            }
        }
    };
    update_apply_btn_label(&apply_btn, &selected_item.borrow());

    let win_apply = window.clone();
    let sel_for_apply = Rc::clone(&selected_item);
    apply_btn.connect_clicked(move |_| {
        let item = sel_for_apply.borrow();
        apply_wallpaper(&item);
        win_apply.close();
        std::thread::sleep(std::time::Duration::from_millis(60));
        std::process::exit(0);
    });

    let random_btn = Button::with_label("󰒝  Sortear Aleatório");
    random_btn.add_css_class("hero-btn-random");

    let all_static_rand = static_wallpapers.clone();
    let win_rand = window.clone();
    random_btn.connect_clicked(move |_| {
        if !all_static_rand.is_empty() {
            use std::time::SystemTime;
            let seed = SystemTime::now()
                .duration_since(SystemTime::UNIX_EPOCH)
                .map(|d| d.as_nanos())
                .unwrap_or(42);
            let idx = (seed as usize) % all_static_rand.len();
            apply_wallpaper(&all_static_rand[idx]);
            win_rand.close();
            std::thread::sleep(std::time::Duration::from_millis(60));
            std::process::exit(0);
        }
    });

    let stop_btn = Button::with_label("⏹  Parar Live Wallpaper");
    stop_btn.add_css_class("hero-btn-stop");
    let win_stop = window.clone();
    stop_btn.connect_clicked(move |_| {
        stop_live_wallpaper();
        win_stop.close();
        std::process::exit(0);
    });

    let hint_label = Label::new(Some("Atalhos:  [Enter] Aplicar  •  [Esc] Fechar  •  Duplo Clique Aplica"));
    hint_label.add_css_class("hero-hint");
    hint_label.set_halign(gtk4::Align::Center);

    actions_box.append(&apply_btn);
    actions_box.append(&random_btn);
    actions_box.append(&stop_btn);
    actions_box.append(&hint_label);

    hero_stage.append(&hero_picture);
    hero_stage.append(&meta_row);
    hero_stage.append(&hero_title);
    hero_stage.append(&actions_box);

    // -------------------------------------------------------------------------
    // RIGHT STAGE: Dedicated Tabs (Nossos Wallpapers vs Vídeos vs Settings)
    // -------------------------------------------------------------------------
    let vault_stage = GtkBox::new(Orientation::Vertical, 14);
    vault_stage.add_css_class("vault-stage");
    vault_stage.set_hexpand(true);

    // Top Controls Bar (Tabs + Search + Close)
    let top_bar = GtkBox::new(Orientation::Horizontal, 10);
    top_bar.set_valign(gtk4::Align::Center);

    let tabs_box = GtkBox::new(Orientation::Horizontal, 6);
    let tab_static_btn = Button::with_label("󰸉  Nossos Wallpapers");
    tab_static_btn.add_css_class("tab-btn");

    let tab_live_btn = Button::with_label("󰑋  Vídeos & Steam Engine");
    tab_live_btn.add_css_class("tab-btn");

    let tab_settings_btn = Button::with_label("󰒓  Configurar Áudio & Motor");
    tab_settings_btn.add_css_class("tab-btn");

    if is_live_active {
        tab_live_btn.add_css_class("active");
    } else {
        tab_static_btn.add_css_class("active");
    }

    tabs_box.append(&tab_static_btn);
    tabs_box.append(&tab_live_btn);
    tabs_box.append(&tab_settings_btn);

    let search_entry = SearchEntry::new();
    search_entry.set_placeholder_text(Some("Pesquisar nesta seção..."));
    search_entry.add_css_class("search-field");
    search_entry.set_hexpand(true);

    let count_badge = Label::new(Some(&format!(
        "{} itens",
        if is_live_active { live_wallpapers.len() } else { static_wallpapers.len() }
    )));
    count_badge.add_css_class("category-chip");

    let close_btn = Button::with_label("✕");
    close_btn.add_css_class("vault-close-btn");
    let win_close = window.clone();
    close_btn.connect_clicked(move |_| {
        win_close.close();
        std::process::exit(0);
    });

    top_bar.append(&tabs_box);
    top_bar.append(&search_entry);
    top_bar.append(&count_badge);
    top_bar.append(&close_btn);

    // Shared Card Select Closure
    let hero_img_rc = hero_picture.clone();
    let hero_title_rc = hero_title.clone();
    let cat_badge_rc = category_badge.clone();
    let status_pill_rc = status_pill.clone();
    let apply_btn_rc = apply_btn.clone();
    let sel_item_rc = Rc::clone(&selected_item);

    struct CardMeta {
        child: FlowBoxChild,
        container: GtkBox,
        name_lower: String,
        category: String,
        item: WallpaperItem,
    }
    let static_registry = Rc::new(RefCell::new(Vec::<CardMeta>::new()));
    let live_registry = Rc::new(RefCell::new(Vec::<CardMeta>::new()));

    let static_reg_for_sel = Rc::clone(&static_registry);
    let live_reg_for_sel = Rc::clone(&live_registry);

    let select_card = Rc::new(move |item: WallpaperItem| {
        *sel_item_rc.borrow_mut() = item.clone();

        update_hero_image(&hero_img_rc, &item.preview_path);
        hero_title_rc.set_text(&item.name);
        update_meta_labels(&cat_badge_rc, &status_pill_rc, &item);
        update_apply_btn_label(&apply_btn_rc, &item);

        for meta in static_reg_for_sel.borrow().iter() {
            if meta.item.path == item.path {
                meta.container.add_css_class("selected");
            } else {
                meta.container.remove_css_class("selected");
            }
        }

        for meta in live_reg_for_sel.borrow().iter() {
            if meta.item.path == item.path {
                meta.container.add_css_class("selected");
            } else {
                meta.container.remove_css_class("selected");
            }
        }
    });

    // -------------------------------------------------------------------------
    // SECTION 1: Nossos Wallpapers Estáticos (Curados)
    // -------------------------------------------------------------------------
    let static_view = GtkBox::new(Orientation::Vertical, 12);
    static_view.set_vexpand(true);
    static_view.set_visible(!is_live_active);

    let static_chips_bar = GtkBox::new(Orientation::Horizontal, 8);
    let static_categories = ["Todos", "Dynamic", "Anime", "Lofi", "Natureza", "City", "Space"];
    let static_active_category = Rc::new(RefCell::new("Todos".to_string()));
    let static_category_buttons = Rc::new(RefCell::new(Vec::<Button>::new()));

    let static_flowbox = FlowBox::new();
    static_flowbox.set_valign(gtk4::Align::Start);
    static_flowbox.set_max_children_per_line(3);
    static_flowbox.set_min_children_per_line(3);
    static_flowbox.set_selection_mode(gtk4::SelectionMode::None);
    static_flowbox.set_homogeneous(true);

    for item in &static_wallpapers {
        let card_item = GtkBox::new(Orientation::Vertical, 4);
        card_item.add_css_class("vault-card");
        card_item.set_size_request(THUMB_W + 12, THUMB_H + 34);

        if item.path == selected_item.borrow().path {
            card_item.add_css_class("selected");
        }

        let is_active_now = current_active_path.as_ref() == Some(&item.path);

        let pic = Picture::for_filename(&item.thumbnail_path);
        pic.set_content_fit(ContentFit::Cover);
        pic.set_can_shrink(true);
        pic.set_size_request(THUMB_W, THUMB_H);
        pic.add_css_class("card-thumb-image");
        card_item.append(&pic);

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

        let click = GestureClick::new();
        let item_click = item.clone();
        let sel_fn = Rc::clone(&select_card);
        let win_apply_quick = window.clone();
        click.connect_released(move |_, n_press, _, _| {
            sel_fn(item_click.clone());
            if n_press >= 2 {
                apply_wallpaper(&item_click);
                win_apply_quick.close();
                std::thread::sleep(std::time::Duration::from_millis(60));
                std::process::exit(0);
            }
        });
        card_item.add_controller(click);

        let child = FlowBoxChild::new();
        child.set_child(Some(&card_item));
        static_flowbox.append(&child);

        static_registry.borrow_mut().push(CardMeta {
            child,
            container: card_item,
            name_lower: item.name.to_lowercase(),
            category: item.category.clone(),
            item: item.clone(),
        });
    }

    let static_scroll = ScrolledWindow::builder()
        .hscrollbar_policy(gtk4::PolicyType::Never)
        .vscrollbar_policy(gtk4::PolicyType::Automatic)
        .child(&static_flowbox)
        .vexpand(true)
        .build();

    static_view.append(&static_chips_bar);
    static_view.append(&static_scroll);

    // -------------------------------------------------------------------------
    // SECTION 2: Vídeos & Steam Wallpaper Engine (Separado)
    // -------------------------------------------------------------------------
    let live_view = GtkBox::new(Orientation::Vertical, 12);
    live_view.set_vexpand(true);
    live_view.set_visible(is_live_active);

    let live_flowbox = FlowBox::new();
    live_flowbox.set_valign(gtk4::Align::Start);
    live_flowbox.set_max_children_per_line(3);
    live_flowbox.set_min_children_per_line(3);
    live_flowbox.set_selection_mode(gtk4::SelectionMode::None);
    live_flowbox.set_homogeneous(true);

    for item in &live_wallpapers {
        let card_item = GtkBox::new(Orientation::Vertical, 4);
        card_item.add_css_class("vault-card");
        card_item.set_size_request(THUMB_W + 12, THUMB_H + 34);

        if item.path == selected_item.borrow().path {
            card_item.add_css_class("selected");
        }

        let is_active_now = current_active_path.as_ref() == Some(&item.path);

        let pic = Picture::for_filename(&item.thumbnail_path);
        pic.set_content_fit(ContentFit::Cover);
        pic.set_can_shrink(true);
        pic.set_size_request(THUMB_W, THUMB_H);
        pic.add_css_class("card-thumb-image");
        card_item.append(&pic);

        let label_row = GtkBox::new(Orientation::Horizontal, 6);
        let name_label = Label::new(Some(&item.name));
        name_label.add_css_class("card-caption");
        name_label.set_ellipsize(gtk4::pango::EllipsizeMode::End);
        name_label.set_hexpand(true);
        name_label.set_halign(gtk4::Align::Start);
        label_row.append(&name_label);

        let live_tag = Label::new(Some("󰑋 VÍDEO"));
        live_tag.add_css_class("card-badge-live");
        label_row.append(&live_tag);

        if is_active_now {
            let badge = Label::new(Some("✓ LIVE"));
            badge.add_css_class("card-badge-active");
            label_row.append(&badge);
        }
        card_item.append(&label_row);

        let click = GestureClick::new();
        let item_click = item.clone();
        let sel_fn = Rc::clone(&select_card);
        let win_apply_quick = window.clone();
        click.connect_released(move |_, n_press, _, _| {
            sel_fn(item_click.clone());
            if n_press >= 2 {
                apply_wallpaper(&item_click);
                win_apply_quick.close();
                std::thread::sleep(std::time::Duration::from_millis(60));
                std::process::exit(0);
            }
        });
        card_item.add_controller(click);

        let child = FlowBoxChild::new();
        child.set_child(Some(&card_item));
        live_flowbox.append(&child);

        live_registry.borrow_mut().push(CardMeta {
            child,
            container: card_item,
            name_lower: item.name.to_lowercase(),
            category: item.category.clone(),
            item: item.clone(),
        });
    }

    let live_scroll = ScrolledWindow::builder()
        .hscrollbar_policy(gtk4::PolicyType::Never)
        .vscrollbar_policy(gtk4::PolicyType::Automatic)
        .child(&live_flowbox)
        .vexpand(true)
        .build();

    live_view.append(&live_scroll);

    // Search and Filtering across active section
    let active_tab_state = Rc::new(RefCell::new(if is_live_active { "live" } else { "static" }));

    let static_reg_filter = Rc::clone(&static_registry);
    let live_reg_filter = Rc::clone(&live_registry);
    let search_rc = search_entry.clone();
    let static_cat_rc = Rc::clone(&static_active_category);
    let tab_state_filter = Rc::clone(&active_tab_state);

    let recompute_filter = Rc::new(move || {
        let query = search_rc.text().to_lowercase();
        let tab = *tab_state_filter.borrow();

        if tab == "static" {
            let cat = static_cat_rc.borrow().clone();
            for meta in static_reg_filter.borrow().iter() {
                let matches_q = query.is_empty() || meta.name_lower.contains(&query);
                let matches_c = cat == "Todos" || meta.category == cat;
                meta.child.set_visible(matches_q && matches_c);
            }
        } else if tab == "live" {
            for meta in live_reg_filter.borrow().iter() {
                let matches_q = query.is_empty() || meta.name_lower.contains(&query);
                meta.child.set_visible(matches_q);
            }
        }
    });

    let recomp_search = Rc::clone(&recompute_filter);
    search_entry.connect_search_changed(move |_| {
        recomp_search();
    });

    for cat_name in static_categories {
        let btn = Button::with_label(cat_name);
        btn.add_css_class("category-chip");
        if cat_name == "Todos" {
            btn.add_css_class("active");
        }

        let cat_val = cat_name.to_string();
        let act_cat_set = Rc::clone(&static_active_category);
        let btn_list = Rc::clone(&static_category_buttons);
        let recomp_cat = Rc::clone(&recompute_filter);

        btn.connect_clicked(move |clicked_btn| {
            *act_cat_set.borrow_mut() = cat_val.clone();
            for b in btn_list.borrow().iter() {
                b.remove_css_class("active");
            }
            clicked_btn.add_css_class("active");
            recomp_cat();
        });

        static_category_buttons.borrow_mut().push(btn.clone());
        static_chips_bar.append(&btn);
    }

    // -------------------------------------------------------------------------
    // SECTION 3: Wallpaper Engine Control Center (Settings)
    // -------------------------------------------------------------------------
    let settings_view = GtkBox::new(Orientation::Vertical, 12);
    settings_view.set_vexpand(true);
    settings_view.set_visible(false);

    let settings_content = GtkBox::new(Orientation::Vertical, 10);
    settings_content.set_margin_top(4);
    settings_content.set_margin_bottom(12);
    settings_content.set_margin_start(4);
    settings_content.set_margin_end(8);

    // Audio & Volume Card
    let audio_card = GtkBox::new(Orientation::Vertical, 10);
    audio_card.add_css_class("settings-card");

    let audio_title = Label::new(Some("󰕾  Controle de Áudio & Volume"));
    audio_title.add_css_class("settings-card-title");
    audio_title.set_halign(gtk4::Align::Start);
    audio_card.append(&audio_title);

    let vol_box = GtkBox::new(Orientation::Vertical, 4);
    let vol_header_row = GtkBox::new(Orientation::Horizontal, 8);
    let vol_lbl = Label::new(Some("Volume Principal"));
    vol_lbl.add_css_class("settings-row-label");
    vol_lbl.set_hexpand(true);
    vol_lbl.set_halign(gtk4::Align::Start);

    let vol_val_lbl = Label::new(Some(&format!("{}%", live_config.borrow().volume)));
    vol_val_lbl.add_css_class("hero-category-badge");
    vol_header_row.append(&vol_lbl);
    vol_header_row.append(&vol_val_lbl);

    let vol_scale = Scale::with_range(Orientation::Horizontal, 0.0, 100.0, 1.0);
    vol_scale.set_value(live_config.borrow().volume as f64);
    vol_scale.set_draw_value(false);
    vol_scale.set_hexpand(true);

    let cfg_vol = Rc::clone(&live_config);
    let vol_val_lbl_clone = vol_val_lbl.clone();
    vol_scale.connect_value_changed(move |s| {
        let v = s.value().round() as u32;
        cfg_vol.borrow_mut().volume = v;
        vol_val_lbl_clone.set_text(&format!("{}%", v));
        save_live_config(&cfg_vol.borrow());
    });

    vol_box.append(&vol_header_row);
    vol_box.append(&vol_scale);
    audio_card.append(&vol_box);

    let mute_row = GtkBox::new(Orientation::Horizontal, 12);
    let mute_texts = GtkBox::new(Orientation::Vertical, 2);
    mute_texts.set_hexpand(true);
    let mute_title = Label::new(Some("Mudo Total (--silent)"));
    mute_title.add_css_class("settings-row-label");
    mute_title.set_halign(gtk4::Align::Start);
    let mute_desc = Label::new(Some("Desativa completamente o som reproduzido pelo wallpaper"));
    mute_desc.add_css_class("settings-row-desc");
    mute_desc.set_halign(gtk4::Align::Start);
    mute_texts.append(&mute_title);
    mute_texts.append(&mute_desc);

    let mute_switch = Switch::new();
    mute_switch.set_active(live_config.borrow().silent);
    mute_switch.set_valign(gtk4::Align::Center);
    let cfg_mute = Rc::clone(&live_config);
    mute_switch.connect_active_notify(move |sw| {
        cfg_mute.borrow_mut().silent = sw.is_active();
        save_live_config(&cfg_mute.borrow());
    });
    mute_row.append(&mute_texts);
    mute_row.append(&mute_switch);
    audio_card.append(&mute_row);

    let automute_row = GtkBox::new(Orientation::Horizontal, 12);
    let automute_texts = GtkBox::new(Orientation::Vertical, 2);
    automute_texts.set_hexpand(true);
    let automute_title = Label::new(Some("Auto-Mute Inteligente"));
    automute_title.add_css_class("settings-row-label");
    automute_title.set_halign(gtk4::Align::Start);
    let automute_desc = Label::new(Some("Silencia o wallpaper quando outro app (Spotify, Jogos) tocar áudio"));
    automute_desc.add_css_class("settings-row-desc");
    automute_desc.set_halign(gtk4::Align::Start);
    automute_texts.append(&automute_title);
    automute_texts.append(&automute_desc);

    let automute_switch = Switch::new();
    automute_switch.set_active(live_config.borrow().automute);
    automute_switch.set_valign(gtk4::Align::Center);
    let cfg_automute = Rc::clone(&live_config);
    automute_switch.connect_active_notify(move |sw| {
        cfg_automute.borrow_mut().automute = sw.is_active();
        save_live_config(&cfg_automute.borrow());
    });
    automute_row.append(&automute_texts);
    automute_row.append(&automute_switch);
    audio_card.append(&automute_row);

    let audioproc_row = GtkBox::new(Orientation::Horizontal, 12);
    let audioproc_texts = GtkBox::new(Orientation::Vertical, 2);
    audioproc_texts.set_hexpand(true);
    let audioproc_title = Label::new(Some("Processamento Reativo de Áudio"));
    audioproc_title.add_css_class("settings-row-label");
    audioproc_title.set_halign(gtk4::Align::Start);
    let audioproc_desc = Label::new(Some("Habilita equalizadores dinâmicos e reações visuais ao som do sistema"));
    audioproc_desc.add_css_class("settings-row-desc");
    audioproc_desc.set_halign(gtk4::Align::Start);
    audioproc_texts.append(&audioproc_title);
    audioproc_texts.append(&audioproc_desc);

    let audioproc_switch = Switch::new();
    audioproc_switch.set_active(live_config.borrow().audio_processing);
    audioproc_switch.set_valign(gtk4::Align::Center);
    let cfg_audioproc = Rc::clone(&live_config);
    audioproc_switch.connect_active_notify(move |sw| {
        cfg_audioproc.borrow_mut().audio_processing = sw.is_active();
        save_live_config(&cfg_audioproc.borrow());
    });
    audioproc_row.append(&audioproc_texts);
    audioproc_row.append(&audioproc_switch);
    audio_card.append(&audioproc_row);

    // Performance & FPS Card
    let perf_card = GtkBox::new(Orientation::Vertical, 10);
    perf_card.add_css_class("settings-card");

    let perf_title = Label::new(Some("󰓅  Desempenho & Taxa de Atualização"));
    perf_title.add_css_class("settings-card-title");
    perf_title.set_halign(gtk4::Align::Start);
    perf_card.append(&perf_title);

    let fps_box = GtkBox::new(Orientation::Vertical, 6);
    let fps_lbl = Label::new(Some("Limite de Taxa de Quadros (FPS)"));
    fps_lbl.add_css_class("settings-row-label");
    fps_lbl.set_halign(gtk4::Align::Start);
    fps_box.append(&fps_lbl);

    let fps_chips_row = GtkBox::new(Orientation::Horizontal, 8);
    let fps_options = [30, 60, 120, 144, 240];
    let fps_buttons = Rc::new(RefCell::new(Vec::<Button>::new()));

    for &f in &fps_options {
        let btn = Button::with_label(&format!("{} FPS", f));
        btn.add_css_class("category-chip");
        if f == live_config.borrow().fps {
            btn.add_css_class("active");
        }

        let cfg_fps = Rc::clone(&live_config);
        let btns_clone = Rc::clone(&fps_buttons);
        btn.connect_clicked(move |clicked| {
            cfg_fps.borrow_mut().fps = f;
            for b in btns_clone.borrow().iter() {
                b.remove_css_class("active");
            }
            clicked.add_css_class("active");
            save_live_config(&cfg_fps.borrow());
        });

        fps_buttons.borrow_mut().push(btn.clone());
        fps_chips_row.append(&btn);
    }
    fps_box.append(&fps_chips_row);
    perf_card.append(&fps_box);

    let pause_row = GtkBox::new(Orientation::Horizontal, 12);
    let pause_texts = GtkBox::new(Orientation::Vertical, 2);
    pause_texts.set_hexpand(true);
    let pause_title = Label::new(Some("Pausar em Janelas Fullscreen / Jogos"));
    pause_title.add_css_class("settings-row-label");
    pause_title.set_halign(gtk4::Align::Start);
    let pause_desc = Label::new(Some("Suspende a renderização para 0% de uso de GPU em tela cheia"));
    pause_desc.add_css_class("settings-row-desc");
    pause_desc.set_halign(gtk4::Align::Start);
    pause_texts.append(&pause_title);
    pause_texts.append(&pause_desc);

    let pause_switch = Switch::new();
    pause_switch.set_active(live_config.borrow().fullscreen_pause);
    pause_switch.set_valign(gtk4::Align::Center);
    let cfg_pause = Rc::clone(&live_config);
    pause_switch.connect_active_notify(move |sw| {
        cfg_pause.borrow_mut().fullscreen_pause = sw.is_active();
        save_live_config(&cfg_pause.borrow());
    });
    pause_row.append(&pause_texts);
    pause_row.append(&pause_switch);
    perf_card.append(&pause_row);

    let scale_box = GtkBox::new(Orientation::Vertical, 6);
    let scale_lbl = Label::new(Some("Enquadramento de Imagem (Scaling)"));
    scale_lbl.add_css_class("settings-row-label");
    scale_lbl.set_halign(gtk4::Align::Start);
    scale_box.append(&scale_lbl);

    let scale_chips_row = GtkBox::new(Orientation::Horizontal, 8);
    let scale_options = [("fill", "Preencher (Fill)"), ("fit", "Ajustar (Fit)"), ("stretch", "Esticar (Stretch)")];
    let scale_buttons = Rc::new(RefCell::new(Vec::<Button>::new()));

    for &(s_mode, s_label) in &scale_options {
        let btn = Button::with_label(s_label);
        btn.add_css_class("category-chip");
        if s_mode == live_config.borrow().scaling {
            btn.add_css_class("active");
        }

        let cfg_scale = Rc::clone(&live_config);
        let s_val = s_mode.to_string();
        let s_btns_clone = Rc::clone(&scale_buttons);
        btn.connect_clicked(move |clicked| {
            cfg_scale.borrow_mut().scaling = s_val.clone();
            for b in s_btns_clone.borrow().iter() {
                b.remove_css_class("active");
            }
            clicked.add_css_class("active");
            save_live_config(&cfg_scale.borrow());
        });

        scale_buttons.borrow_mut().push(btn.clone());
        scale_chips_row.append(&btn);
    }
    scale_box.append(&scale_chips_row);
    perf_card.append(&scale_box);

    // Effects Card
    let fx_card = GtkBox::new(Orientation::Vertical, 10);
    fx_card.add_css_class("settings-card");

    let fx_title = Label::new(Some("󰍽  Interatividade & Física de Efeitos"));
    fx_title.add_css_class("settings-card-title");
    fx_title.set_halign(gtk4::Align::Start);
    fx_card.append(&fx_title);

    let mouse_row = GtkBox::new(Orientation::Horizontal, 12);
    let mouse_texts = GtkBox::new(Orientation::Vertical, 2);
    mouse_texts.set_hexpand(true);
    let mouse_title = Label::new(Some("Interação com o Cursor do Mouse"));
    mouse_title.add_css_class("settings-row-label");
    mouse_title.set_halign(gtk4::Align::Start);
    let mouse_desc = Label::new(Some("Permite que partículas e objetos reajam à posição e cliques do cursor"));
    mouse_desc.add_css_class("settings-row-desc");
    mouse_desc.set_halign(gtk4::Align::Start);
    mouse_texts.append(&mouse_title);
    mouse_texts.append(&mouse_desc);

    let mouse_switch = Switch::new();
    mouse_switch.set_active(live_config.borrow().mouse_interaction);
    mouse_switch.set_valign(gtk4::Align::Center);
    let cfg_mouse = Rc::clone(&live_config);
    mouse_switch.connect_active_notify(move |sw| {
        cfg_mouse.borrow_mut().mouse_interaction = sw.is_active();
        save_live_config(&cfg_mouse.borrow());
    });
    mouse_row.append(&mouse_texts);
    mouse_row.append(&mouse_switch);
    fx_card.append(&mouse_row);

    let parallax_row = GtkBox::new(Orientation::Horizontal, 12);
    let parallax_texts = GtkBox::new(Orientation::Vertical, 2);
    parallax_texts.set_hexpand(true);
    let parallax_title = Label::new(Some("Câmera Paralaxe 3D"));
    parallax_title.add_css_class("settings-row-label");
    parallax_title.set_halign(gtk4::Align::Start);
    let parallax_desc = Label::new(Some("Efeito tridimensional de profundidade ao mover o mouse"));
    parallax_desc.add_css_class("settings-row-desc");
    parallax_desc.set_halign(gtk4::Align::Start);
    parallax_texts.append(&parallax_title);
    parallax_texts.append(&parallax_desc);

    let parallax_switch = Switch::new();
    parallax_switch.set_active(live_config.borrow().parallax);
    parallax_switch.set_valign(gtk4::Align::Center);
    let cfg_parallax = Rc::clone(&live_config);
    parallax_switch.connect_active_notify(move |sw| {
        cfg_parallax.borrow_mut().parallax = sw.is_active();
        save_live_config(&cfg_parallax.borrow());
    });
    parallax_row.append(&parallax_texts);
    parallax_row.append(&parallax_switch);
    fx_card.append(&parallax_row);

    let part_row = GtkBox::new(Orientation::Horizontal, 12);
    let part_texts = GtkBox::new(Orientation::Vertical, 2);
    part_texts.set_hexpand(true);
    let part_title = Label::new(Some("Renderização de Partículas"));
    part_title.add_css_class("settings-row-label");
    part_title.set_halign(gtk4::Align::Start);
    let part_desc = Label::new(Some("Ativa chuva, neve, brasas e folhas flutuantes na cena"));
    part_desc.add_css_class("settings-row-desc");
    part_desc.set_halign(gtk4::Align::Start);
    part_texts.append(&part_title);
    part_texts.append(&part_desc);

    let part_switch = Switch::new();
    part_switch.set_active(live_config.borrow().particles);
    part_switch.set_valign(gtk4::Align::Center);
    let cfg_part = Rc::clone(&live_config);
    part_switch.connect_active_notify(move |sw| {
        cfg_part.borrow_mut().particles = sw.is_active();
        save_live_config(&cfg_part.borrow());
    });
    part_row.append(&part_texts);
    part_row.append(&part_switch);
    fx_card.append(&part_row);

    // Actions Row
    let actions_row = GtkBox::new(Orientation::Horizontal, 12);
    actions_row.set_margin_top(6);

    let apply_reload_btn = Button::with_label("󰑋  Aplicar Alterações no Wallpaper Ativo");
    apply_reload_btn.add_css_class("hero-btn-apply");
    apply_reload_btn.set_hexpand(true);

    let cfg_save_reload = Rc::clone(&live_config);
    apply_reload_btn.connect_clicked(move |_| {
        save_live_config(&cfg_save_reload.borrow());
        reload_live_wallpaper();
    });

    let stop_engine_btn = Button::with_label("⏹  Parar Engine");
    stop_engine_btn.add_css_class("hero-btn-stop");
    stop_engine_btn.connect_clicked(move |_| {
        stop_live_wallpaper();
    });

    actions_row.append(&apply_reload_btn);
    actions_row.append(&stop_engine_btn);

    settings_content.append(&audio_card);
    settings_content.append(&perf_card);
    settings_content.append(&fx_card);
    settings_content.append(&actions_row);

    let settings_scroll = ScrolledWindow::builder()
        .hscrollbar_policy(gtk4::PolicyType::Never)
        .vscrollbar_policy(gtk4::PolicyType::Automatic)
        .child(&settings_content)
        .vexpand(true)
        .build();

    settings_view.append(&settings_scroll);

    // Connect Tab Switchers
    let stat_view_rc = static_view.clone();
    let live_view_rc = live_view.clone();
    let set_view_rc = settings_view.clone();
    let tab_stat_rc = tab_static_btn.clone();
    let tab_live_rc = tab_live_btn.clone();
    let tab_set_rc = tab_settings_btn.clone();
    let search_rc_tab = search_entry.clone();
    let count_rc_tab = count_badge.clone();
    let tab_state_1 = Rc::clone(&active_tab_state);
    let static_len = static_wallpapers.len();
    let live_len = live_wallpapers.len();

    // Tab 1: Nossos Wallpapers
    let stat_view_c1 = stat_view_rc.clone();
    let live_view_c1 = live_view_rc.clone();
    let set_view_c1 = set_view_rc.clone();
    let t_stat_c1 = tab_stat_rc.clone();
    let t_live_c1 = tab_live_rc.clone();
    let t_set_c1 = tab_set_rc.clone();
    let search_c1 = search_rc_tab.clone();
    let count_c1 = count_rc_tab.clone();
    let tab_state_c1 = Rc::clone(&tab_state_1);
    tab_static_btn.connect_clicked(move |_| {
        *tab_state_c1.borrow_mut() = "static";
        t_stat_c1.add_css_class("active");
        t_live_c1.remove_css_class("active");
        t_set_c1.remove_css_class("active");

        stat_view_c1.set_visible(true);
        live_view_c1.set_visible(false);
        set_view_c1.set_visible(false);

        search_c1.set_visible(true);
        count_c1.set_visible(true);
        count_c1.set_text(&format!("{} Wallpapers", static_len));
    });

    // Tab 2: Vídeos & Steam Engine
    let stat_view_c2 = stat_view_rc.clone();
    let live_view_c2 = live_view_rc.clone();
    let set_view_c2 = set_view_rc.clone();
    let t_stat_c2 = tab_stat_rc.clone();
    let t_live_c2 = tab_live_rc.clone();
    let t_set_c2 = tab_set_rc.clone();
    let search_c2 = search_rc_tab.clone();
    let count_c2 = count_rc_tab.clone();
    let tab_state_c2 = Rc::clone(&tab_state_1);
    tab_live_btn.connect_clicked(move |_| {
        *tab_state_c2.borrow_mut() = "live";
        t_live_c2.add_css_class("active");
        t_stat_c2.remove_css_class("active");
        t_set_c2.remove_css_class("active");

        stat_view_c2.set_visible(false);
        live_view_c2.set_visible(true);
        set_view_c2.set_visible(false);

        search_c2.set_visible(true);
        count_c2.set_visible(true);
        count_c2.set_text(&format!("{} Vídeos Steam", live_len));
    });

    // Tab 3: Configurar Áudio & Motor
    let stat_view_c3 = stat_view_rc.clone();
    let live_view_c3 = live_view_rc.clone();
    let set_view_c3 = set_view_rc.clone();
    let t_stat_c3 = tab_stat_rc.clone();
    let t_live_c3 = tab_live_rc.clone();
    let t_set_c3 = tab_set_rc.clone();
    let search_c3 = search_rc_tab.clone();
    let count_c3 = count_rc_tab.clone();
    let tab_state_c3 = Rc::clone(&tab_state_1);
    tab_settings_btn.connect_clicked(move |_| {
        *tab_state_c3.borrow_mut() = "settings";
        t_set_c3.add_css_class("active");
        t_stat_c3.remove_css_class("active");
        t_live_c3.remove_css_class("active");

        stat_view_c3.set_visible(false);
        live_view_c3.set_visible(false);
        set_view_c3.set_visible(true);

        search_c3.set_visible(false);
        count_c3.set_visible(false);
    });

    vault_stage.append(&top_bar);
    vault_stage.append(&static_view);
    vault_stage.append(&live_view);
    vault_stage.append(&settings_view);

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
            let deck_w = 1380.0;
            let deck_h = 800.0;
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
            apply_wallpaper(&item);
            win_key.close();
            std::thread::sleep(std::time::Duration::from_millis(60));
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
