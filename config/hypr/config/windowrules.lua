-- ==============================================================================
-- Soberano Window & Layer Rules (Gaming + Modals + Wayle + Fuzzel Blur)
-- ==============================================================================

local gamingApps = "^(steam_app_.*|.*[Gg]ame.*|.*\\.exe|gamescope|cs2|dota2|Overwatch.*)$"
local gamingWorkspace = "10"

-- Battle.net & Overwatch
hl.window_rule({ match = { class = "^(.*[Bb]attle\\.net.*)$" }, workspace = 1, float = true, center = true, size = { 1280, 720 } })
hl.window_rule({ match = { initial_class = "^(.*[Bb]attle\\.net.*)$" }, workspace = 1, float = true, center = true, size = { 1280, 720 } })
hl.window_rule({ match = { title = "^(.*[Bb]attle\\.net.*)$" }, workspace = 1, float = true, center = true, size = { 1280, 720 } })
hl.window_rule({ match = { initial_title = "^(.*[Bb]attle\\.net.*)$" }, workspace = 1, float = true, center = true, size = { 1280, 720 } })
hl.window_rule({ match = { title = "^([Oo]verwatch.*)$" }, workspace = gamingWorkspace, content = "game", fullscreen_state = 2, sync_fullscreen = true })

-- Games
hl.window_rule({ match = { content = "game" }, workspace = gamingWorkspace })
hl.window_rule({ match = { xdg_tag = "^(.*game.*)$" }, workspace = gamingWorkspace, fullscreen_state = 2, content = "game", sync_fullscreen = true })
hl.window_rule({ match = { class = gamingApps }, workspace = gamingWorkspace })
hl.window_rule({ match = { class = "^(steam)$", title = "^(Friends List)$" }, float = true })
hl.window_rule({ match = { class = "^(steam)$", title = "^(Launching\\.{3})$" }, float = true, center = true, workspace = gamingWorkspace })
hl.window_rule({
    match = {
        class         = gamingApps,
        title         = "^(.+)$",
        initial_title = "negative:^(.*\\\\home\\\\.*)$",
    },
    content          = "game",
    decorate         = false,
    fullscreen_state = 2,
    size             = { "monitor_w", "monitor_h" },
    sync_fullscreen  = true,
})
hl.window_rule({
    match = {
        class         = "^(steam_app_[0-9]+)$",
        initial_title = "^$",
    },
    center           = true,
    float            = true,
    fullscreen       = false,
    fullscreen_state = 0,
    workspace        = gamingWorkspace,
})
hl.window_rule({
    match = { class = "^(steam_app_default)$" },
    workspace = 1,
    float = true,
    center = true,
})

-- General Apps
hl.window_rule({ match = { class = "^(.*\\.exe)$", float = true }, monitor = PRIMARY_MONITOR, center = true, fullscreen_state = 0 })
hl.window_rule({ match = { class = "^(.*[Ll]auncher.*)$" }, float = true, monitor = PRIMARY_MONITOR })
hl.window_rule({ match = { class = "^(vesktop|discord)$" }, monitor = PRIMARY_MONITOR })
hl.window_rule({ match = { class = "^(.*[Cc]alc.*)$" }, float = true, size = { "max(monitor_w, monitor_h)*0.17", "min(monitor_w, monitor_h)*0.43" } })
hl.window_rule({ match = { class = "^(org\\.kde\\.keditfiletype)$" }, float = true })
hl.window_rule({ match = { class = "^(org\\.kde\\.ark)$" }, size = { "max(monitor_w, monitor_h)*0.40", "min(monitor_w, monitor_h)*0.40" } })
hl.window_rule({
    match = {
        class = "^(org\\.kde\\.dolphin|[Tt]hunar)$",
        title = "negative:^(Moving.*|Create New.*|Extract.*|Compress.*|Copying.*|Progress.*|Configure.*|Properties.*|Choose\\sApplication.*)$",
    },
    float = true,
    size = { "max(monitor_w, monitor_h)*0.50", "min(monitor_w, monitor_h)*0.55" },
    move = {
        "max(20, min(cursor_x - (window_w*0.50), monitor_w - window_w + 20))",
        "max(20, min(cursor_y - 50, monitor_h - window_h + 20))",
    },
})

-- Opacity Overrides
local terminals = "^(kitty|ghostty|[Kk]onsole|Alacritty|gnome-terminal|xfce[0-9]?-terminal)$"
hl.window_rule({ match = { class = "^(firefox|zen)$" }, opacity = "1.0 override" })
hl.window_rule({ match = { class = terminals }, opacity = "1.0 override" })
hl.window_rule({ match = { class = "^(mpv|org.kde.haruna|.*plex.*|org\\.kde\\.gwenview|.*vlc.*)$" }, opacity = "1.0 override" })

-- Float Utility Windows & Modals
local floatApps = {
    { class = "^(kvantummanager|qt[56]ct|nwg-look)$" },
    { class = "^(org.pulseaudio.pavucontrol|blueman-manager|nm-applet|nm-connection-editor)$" },
    { title = "^(Winetricks.*|Protontricks.*)$" },
    { title = "^(Open|Authentication Required|Add Folder to Workspace|Choose Files|Save As|Confirm to replace files|File Operation Progress)$" },
    { initial_title = "^(Open File)$" },
    { class = "^([Xx]dg-desktop-portal-gtk)$" },
    { title = "^(File Upload|Choose wallpaper|Library)(.*)$" },
    { class = "^(.*dialog.*)$" },
    { title = "^(.*dialog.*)$" },
    { class = "^(hyprland-share-picker)$" },
    { class = "^(float_monitor)$" },
}
for _, m in ipairs(floatApps) do hl.window_rule({ match = m, float = true }) end

hl.window_rule({
    match = { class = "^(float_monitor)$" },
    float = true,
    center = true,
    size = { 960, 600 },
})

hl.window_rule({
    name  = "suppress-maximize-events",
    match = { class = ".*" },
    suppress_event = "maximize",
})

hl.window_rule({
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },
    no_focus = true,
})

-- Layer Blur Rules (Wayle + Fuzzel)
hl.layer_rule({
    name = "wayle",
    match = { namespace = "^(wayle.*)$" },
    no_anim = false,
    ignore_alpha = 0.5,
    blur = true,
    blur_popups = true,
})

hl.layer_rule({
    name = "fuzzel",
    match = { namespace = "^(launcher|fuzzel)$" },
    no_anim = false,
    ignore_alpha = 0.3,
    blur = true,
})

-- Keybindings Visual Glass HUD
hl.window_rule({
    match = { class = "^(hypr-keybinds-hud)$" },
    float = true,
    center = true,
    size = { 1080, 780 },
    pin = true,
})

-- Soberano Native Rust Display & Refresh Rate Picker (Super + M)
hl.window_rule({
    match = { class = "^(org\\.soberano\\.displaypicker)$" },
    float = true,
    center = true,
    size = { 840, 620 },
    pin = true,
})
