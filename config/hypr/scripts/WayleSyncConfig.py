#!/usr/bin/env python3
"""
WayleSyncConfig.py - Synchronizes active JaKooLit Layout + active JaKooLit Style
into ~/.config/wayle/config.toml, ~/.config/wayle/styles/index.scss, and Rofi colors.
"""
import os
import sys
import tomllib

HOME = os.path.expanduser("~")
CONFIG_HOME = os.environ.get("XDG_CONFIG_HOME", os.path.join(HOME, ".config"))
STATE_HOME = os.environ.get("XDG_STATE_HOME", os.path.join(HOME, ".local/state"))

WAYLE_DIR = os.path.join(CONFIG_HOME, "wayle")
LAYOUTS_DIR = os.path.join(WAYLE_DIR, "layouts")
THEMES_DIR = os.path.join(WAYLE_DIR, "themes")
STYLES_DIR = os.path.join(WAYLE_DIR, "styles")
STATE_DIR = os.path.join(STATE_HOME, "wayle")

ACTIVE_LAYOUT_FILE = os.path.join(STATE_DIR, "active_layout")
ACTIVE_STYLE_FILE = os.path.join(STATE_DIR, "active_style")
CONFIG_TOML = os.path.join(WAYLE_DIR, "config.toml")
RUNTIME_TOML = os.path.join(WAYLE_DIR, "runtime.toml")
INDEX_SCSS = os.path.join(STYLES_DIR, "index.scss")

os.makedirs(STATE_DIR, exist_ok=True)

def read_state(path, default):
    if os.path.isfile(path):
        with open(path, "r", encoding="utf-8") as f:
            val = f.read().strip()
            if val:
                return val
    return default

layout_name = sys.argv[1] if len(sys.argv) > 1 and sys.argv[1] != "-" else read_state(ACTIVE_LAYOUT_FILE, "TOP-Default")
style_name = sys.argv[2] if len(sys.argv) > 2 and sys.argv[2] != "-" else read_state(ACTIVE_STYLE_FILE, "Catppuccin-Mocha")

layout_path = os.path.join(LAYOUTS_DIR, f"{layout_name}.toml")
if not os.path.isfile(layout_path):
    layout_name = "TOP-Default"
    layout_path = os.path.join(LAYOUTS_DIR, "TOP-Default.toml")

style_path = os.path.join(THEMES_DIR, f"{style_name}.toml")
if not os.path.isfile(style_path):
    style_name = "Catppuccin-Mocha"
    style_path = os.path.join(THEMES_DIR, "Catppuccin-Mocha.toml")

with open(layout_path, "rb") as f:
    layout_data = tomllib.load(f)

with open(style_path, "rb") as f:
    style_data = tomllib.load(f)

# Save active state
with open(ACTIVE_LAYOUT_FILE, "w", encoding="utf-8") as f:
    f.write(layout_name + "\n")
with open(ACTIVE_STYLE_FILE, "w", encoding="utf-8") as f:
    f.write(style_name + "\n")

# Extract layout raw [[bar.layout]] block from layout file
with open(layout_path, "r", encoding="utf-8") as f:
    layout_raw = f.read()
bar_layout_idx = layout_raw.find("[[bar.layout]]")
bar_layout_block = layout_raw[bar_layout_idx:].strip() if bar_layout_idx != -1 else ""

bar_geom = layout_data.get("bar", {})
bar_style = style_data.get("bar_style", {})
palette = style_data.get("palette", {})
scss_slug = style_data.get("scss", "catppuccin-mocha")

# If style uses wallust and Wallust-Dynamic.toml exists, use Wallust extracted palette
wallust_dyn_path = os.path.join(THEMES_DIR, "Wallust-Dynamic.toml")
if bar_style.get("theme-provider") == "wallust" and os.path.isfile(wallust_dyn_path):
    try:
        with open(wallust_dyn_path, "rb") as wf:
            wdata = tomllib.load(wf)
            if "palette" in wdata:
                palette = wdata["palette"]
    except Exception:
        pass

ws_indicator = bar_style.get("workspace-indicator", "background")
is_bordered = bar_style.get("button-border-location", "none") != "none"

# Ensure runtime.toml is empty so it never locks config.toml changes
with open(RUNTIME_TOML, "w", encoding="utf-8") as f:
    f.write("")

# 1. Write styles/index.scss
index_scss_content = f"""// ==============================================================================
// JaKooLit Hyprland-Dots Style Entry Point for Wayle
// Active Style: {style_name} | Active Layout: {layout_name}
// ==============================================================================

@import "base";
@import "{scss_slug}";
"""
with open(INDEX_SCSS, "w", encoding="utf-8") as f:
    f.write(index_scss_content)

# 2. Write config.toml
config_content = f"""imports = []

[general]
font-sans = "Inter"
font-mono = "JetBrainsMono Nerd Font"
tearing-mode = false

# ==============================================================================
# JaKooLit Active Layout: {layout_name}
# JaKooLit Active Style:  {style_name}
# ==============================================================================
[bar]
location = "{bar_geom.get('location', 'top')}"
scale = 1.02
inset-edge = {bar_geom.get('inset-edge', 0.35)}
inset-ends = {bar_geom.get('inset-ends', 0.55)}
padding = {bar_geom.get('padding', 0.35)}
padding-ends = {bar_geom.get('padding-ends', 0.55)}
module-gap = {bar_geom.get('module-gap', 0.45)}
exclusive = true
layer = "top"
bg = "{bar_style.get('bg', 'transparent')}"
background-opacity = {bar_style.get('background-opacity', 0)}
border-location = "{bar_style.get('border-location', 'none')}"
border-width = {bar_style.get('border-width', 0)}
border-color = "{bar_style.get('border-color', 'border-accent')}"
rounding = "{bar_style.get('rounding', 'none')}"
shadow = "{bar_style.get('shadow', 'none')}"
button-variant = "{bar_style.get('button-variant', 'block-prefix')}"
button-opacity = {bar_style.get('button-opacity', 100)}
button-bg-opacity = {bar_style.get('button-bg-opacity', 90)}
button-icon-size = 1.0
button-icon-padding = 0.85
button-label-size = 0.96
button-label-weight = "bold"
button-label-padding = 0.85
button-rounding = "{bar_style.get('button-rounding', 'full')}"
button-gap = 0.65
button-icon-position = "start"
button-border-location = "{bar_style.get('button-border-location', 'all')}"
button-border-width = {bar_style.get('button-border-width', 1)}
button-group-border-location = "{bar_style.get('button-group-border-location', 'all')}"
button-group-border-width = {bar_style.get('button-group-border-width', 1)}
button-group-padding = {bar_style.get('button-group-padding', 0.25)}
button-group-module-gap = {bar_style.get('button-group-module-gap', 0.35)}
button-group-background = "{bar_style.get('button-group-background', 'bg-surface')}"
button-group-opacity = {bar_style.get('button-group-opacity', 90)}
button-group-border-color = "{bar_style.get('button-group-border-color', 'border-accent')}"
button-group-rounding = "{bar_style.get('button-group-rounding', 'full')}"
dropdown-shadow = true
dropdown-opacity = 96
dropdown-autohide = true
dropdown-freeze-label = true

{bar_layout_block}

[styling]
scale = 1.01
rounding = "md"
theme-provider = "wayle"
theming-monitor = ""
matugen-scheme = "tonal-spot"
matugen-contrast = 0.0
matugen-source-color = 0
matugen-light = false
wallust-palette = "dark16"
wallust-saturation = 0
wallust-check-contrast = true
wallust-backend = "fastresize"
wallust-colorspace = "labmixed"
wallust-apply-globally = true

[styling.palette]
bg = "{palette.get('bg', '#1e1e2e')}"
surface = "{palette.get('surface', '#181825')}"
elevated = "{palette.get('elevated', '#313244')}"
fg = "{palette.get('fg', '#cdd6f4')}"
fg-muted = "{palette.get('fg-muted', '#a6adc8')}"
primary = "{palette.get('primary', '#cba6f7')}"
red = "{palette.get('red', '#f38ba8')}"
yellow = "{palette.get('yellow', '#f9e2af')}"
green = "{palette.get('green', '#a6e3a1')}"
blue = "{palette.get('blue', '#89b4fa')}"

# ==============================================================================
# Built-in Wayle Modules (Configured for JaKooLit Workflow)
# ==============================================================================
[modules.dashboard]
icon-override = "󰣇"
border-show = {'true' if is_bordered else 'false'}
border-color = "accent"
icon-color = "auto"
icon-bg-color = "accent"
left-click = "pkill rofi || true; $HOME/.config/hypr/scripts/RofiFocusedWallpaperLink.sh >/dev/null 2>&1 || true; rofi -show drun -modi drun,filebrowser,run,window -config $HOME/.config/hypr/rofi/config.rasi"
right-click = "$HOME/.config/hypr/scripts/WaybarLayout.sh"
middle-click = "$HOME/.config/hypr/scripts/WaybarStyles.sh"
dropdown-lock-command = "$HOME/.config/hypr/scripts/LockScreen.sh"
dropdown-logout-command = "$HOME/.config/hypr/scripts/Logout.sh"
dropdown-reboot-command = "systemctl reboot"
dropdown-poweroff-command = "systemctl poweroff"

[modules.hyprland-workspaces]
min-workspace-count = 5
monitor-specific = true
show-special = false
urgent-show = true
urgent-mode = "workspace"
display-mode = "label"
label-use-name = false
numbering = "absolute"
divider = " "
app-icons-show = false
app-icons-dedupe = true
icon-gap = 0.3
workspace-padding = 0.55
icon-size = 1.0
label-size = 1.0
active-indicator = "{ws_indicator}"
active-color = "accent"
occupied-color = "fg-default"
empty-color = "fg-subtle"
container-bg-color = "bg-surface-elevated"
border-show = {'true' if is_bordered else 'false'}
border-color = "border-accent"

[modules.window-title]
format = "{{{{ title }}}}"
icon-name = "ld-app-window-symbolic"
border-show = {'true' if is_bordered else 'false'}
border-color = "blue"
icon-show = true
icon-color = "auto"
icon-bg-color = "blue"
label-show = true
label-color = "fg-default"
label-max-length = 42
button-bg-color = "bg-surface-elevated"

[modules.cava]
bars = 16
framerate = 60
stereo = false
noise-reduction = 0.65
low-cutoff = 50
high-cutoff = 17000
input = "pipe-wire"
source = "auto"
style = "bars"
direction = "normal"
color = "accent"
button-bg-color = "bg-surface-elevated"
bar-width = 5
bar-gap = 1
internal-padding = 0.5
border-show = {'true' if is_bordered else 'false'}
border-color = "border-accent"

[modules.media]
icon-type = "spinning-disc"
format = "{{{{ title }}}} - {{{{ artist }}}}"
icon-name = "ld-music-symbolic"
spinning-disc-icon = "ld-disc-3-symbolic"
border-show = {'true' if is_bordered else 'false'}
border-color = "blue"
icon-show = true
icon-color = "auto"
icon-bg-color = "blue"
label-show = true
label-color = "fg-default"
label-max-length = 30
button-bg-color = "bg-surface-elevated"
left-click = "dropdown:media"
right-click = "playerctl next"
middle-click = "playerctl play-pause"

[modules.clock]
format = "%a %d %b  %H:%M"
icon-name = "tb-calendar-time-symbolic"
border-show = {'true' if is_bordered else 'false'}
border-color = "border-accent"
icon-show = true
icon-color = "auto"
icon-bg-color = "accent"
label-show = true
label-color = "fg-default"
button-bg-color = "bg-surface-elevated"
left-click = "dropdown:calendar"
right-click = "dropdown:weather"

[modules.weather]
provider = "open-meteo"
location = "Sao Paulo"
units = "metric"
format = "{{{{ temp }}}}{{{{ temp_unit }}}}"
time-format = "24h"
refresh-interval-seconds = 1800
icon-name = "ld-sun-symbolic"
border-show = {'true' if is_bordered else 'false'}
border-color = "yellow"
icon-show = true
icon-color = "auto"
icon-bg-color = "yellow"
label-show = true
label-color = "fg-default"
button-bg-color = "bg-surface-elevated"
left-click = "dropdown:weather"

[modules.cpu]
poll-interval-ms = 2000
temp-sensor = "auto"
format = "{{{{ percent }}}}%"
icon-name = "ld-cpu-symbolic"
border-show = {'true' if is_bordered else 'false'}
border-color = "blue"
icon-show = true
icon-color = "auto"
icon-bg-color = "blue"
label-show = true
label-color = "fg-default"
button-bg-color = "bg-surface-elevated"
left-click = "kitty --title btop sh -c 'btop'"

[modules.ram]
poll-interval-ms = 4000
format = "{{{{ percent }}}}%"
icon-name = "ld-memory-stick-symbolic"
border-show = {'true' if is_bordered else 'false'}
border-color = "green"
icon-show = true
icon-color = "auto"
icon-bg-color = "green"
label-show = true
label-color = "fg-default"
button-bg-color = "bg-surface-elevated"
left-click = "kitty --title btop sh -c 'btop'"

[modules.storage]
poll-interval-ms = 30000
mount-point = "/"
format = "{{{{ percent }}}}%"
icon-name = "ld-hard-drive-symbolic"
border-show = {'true' if is_bordered else 'false'}
border-color = "yellow"
icon-show = true
icon-color = "auto"
icon-bg-color = "yellow"
label-show = true
label-color = "fg-default"
button-bg-color = "bg-surface-elevated"

[modules.volume]
border-show = {'true' if is_bordered else 'false'}
border-color = "accent"
icon-show = true
icon-color = "auto"
icon-bg-color = "accent"
label-show = true
label-color = "fg-default"
format = "{{{{ percent }}}}%"
button-bg-color = "bg-surface-elevated"
left-click = "dropdown:audio"
middle-click = "wayle audio output-mute"
right-click = "pavucontrol"
scroll-up = "$HOME/.config/hypr/scripts/Volume.sh --inc"
scroll-down = "$HOME/.config/hypr/scripts/Volume.sh --dec"

[modules.microphone]
border-show = {'true' if is_bordered else 'false'}
border-color = "red"
icon-show = true
icon-color = "auto"
icon-bg-color = "red"
label-show = false
button-bg-color = "bg-surface-elevated"
left-click = "dropdown:audio"
middle-click = "wayle audio input-mute"

[modules.network]
border-show = {'true' if is_bordered else 'false'}
border-color = "green"
icon-show = true
icon-color = "auto"
icon-bg-color = "green"
label-show = true
label-color = "fg-default"
label-max-length = 14
button-bg-color = "bg-surface-elevated"
left-click = "dropdown:network"

[modules.netstat]
poll-interval-ms = 2000
interface = "auto"
format = "↓{{{{ down_auto }}}} ↑{{{{ up_auto }}}}"
icon-name = "ld-activity-symbolic"
border-show = {'true' if is_bordered else 'false'}
border-color = "green"
icon-show = true
icon-color = "auto"
icon-bg-color = "green"
label-show = true
label-color = "fg-default"
button-bg-color = "bg-surface-elevated"

[modules.bluetooth]
border-show = {'true' if is_bordered else 'false'}
border-color = "blue"
icon-show = true
icon-color = "auto"
icon-bg-color = "blue"
label-show = false
button-bg-color = "bg-surface-elevated"
left-click = "dropdown:bluetooth"

[modules.brightness]
border-show = {'true' if is_bordered else 'false'}
border-color = "yellow"
icon-show = true
icon-color = "auto"
icon-bg-color = "yellow"
label-show = true
label-color = "fg-default"
format = "{{{{ percent }}}}%"
button-bg-color = "bg-surface-elevated"
left-click = "dropdown:brightness"

[modules.battery]
border-show = {'true' if is_bordered else 'false'}
border-color = "green"
icon-show = true
icon-color = "auto"
icon-bg-color = "green"
label-show = true
label-color = "fg-default"
format = "{{{{ percent }}}}%"
button-bg-color = "bg-surface-elevated"
left-click = "dropdown:battery"

[modules.notifications]
border-show = {'true' if is_bordered else 'false'}
border-color = "yellow"
icon-show = true
icon-color = "auto"
icon-bg-color = "yellow"
label-show = true
label-color = "fg-default"
button-bg-color = "bg-surface-elevated"
left-click = "dropdown:notification"
right-click = "wayle notify dnd"
popup-position = "top-right"
popup-max-visible = 5
popup-duration = 5000

[modules.idle-inhibit]
startup-duration = 60
format = ""
border-show = {'true' if is_bordered else 'false'}
border-color = "green"
icon-show = true
icon-color = "auto"
icon-bg-color = "green"
label-show = false
button-bg-color = "bg-surface-elevated"
left-click = "wayle idle toggle --indefinite"

[modules.hyprsunset]
format = ""
temperature = 4500
gamma = 100
border-show = {'true' if is_bordered else 'false'}
border-color = "yellow"
icon-show = true
icon-color = "auto"
icon-bg-color = "yellow"
label-show = false
button-bg-color = "bg-surface-elevated"
left-click = ":toggle"

[modules.keyboard-input]
format = "{{{{ alias }}}}"
icon-name = "ld-keyboard-symbolic"
border-show = {'true' if is_bordered else 'false'}
border-color = "blue"
icon-show = true
icon-color = "auto"
icon-bg-color = "blue"
label-show = true
label-color = "fg-default"
button-bg-color = "bg-surface-elevated"
left-click = "$HOME/.config/hypr/scripts/KeyboardLayout.sh switch"

[modules.keybind-mode]
format = "{{{{ mode }}}}"
icon-name = "ld-layers-symbolic"
auto-hide = true
border-show = true
border-color = "red"
icon-show = true
icon-color = "auto"
icon-bg-color = "red"
label-show = true
label-color = "red"
button-bg-color = "bg-surface-elevated"

[modules.systray]
icon-scale = 1.0
item-gap = 0.3
internal-padding = 0.5
border-show = {'true' if is_bordered else 'false'}
border-color = "border-accent"
button-bg-color = "bg-surface-elevated"

[modules.power]
icon-name = "ld-power-symbolic"
border-show = {'true' if is_bordered else 'false'}
border-color = "red"
icon-color = "auto"
icon-bg-color = "red"
left-click = "$HOME/.config/hypr/scripts/Wlogout.sh"
right-click = "$HOME/.config/hypr/scripts/ChangeBlur.sh"
middle-click = "$HOME/.config/hypr/scripts/LockScreen.sh"

# ==============================================================================
# JaKooLit Custom Modules Ported to Wayle
# ==============================================================================
[[modules.custom]]
id = "hypr-layout"
mode = "poll"
interval-ms = 3000
command = "$HOME/.config/hypr/scripts/HyprLayoutModule.sh status"
format = "{{{{ text | default('󰙀') }}}}"
tooltip-format = "{{{{ tooltip | default('Layout do Hyprland') }}}}"
icon-show = false
label-show = true
label-color = "accent"
button-bg-color = "bg-surface-elevated"
border-show = {'true' if is_bordered else 'false'}
border-color = "accent"
left-click = "$HOME/.config/hypr/scripts/HyprLayoutModule.sh menu"
right-click = "$HOME/.config/hypr/scripts/HyprLayoutModule.sh next"

[[modules.custom]]
id = "hint"
mode = "poll"
interval-ms = 3600000
command = "echo '󰺁 HINT!'"
format = "{{{{ output }}}}"
tooltip-format = "Esq: Dicas Rápidas | Dir: Buscar Atalhos"
icon-show = false
label-show = true
label-color = "yellow"
button-bg-color = "bg-surface-elevated"
border-show = {'true' if is_bordered else 'false'}
border-color = "yellow"
left-click = "$HOME/.config/hypr/scripts/KeyHints.sh"
right-click = "$HOME/.config/hypr/scripts/KeyBinds.sh"

[[modules.custom]]
id = "updater"
mode = "poll"
interval-ms = 1800000
command = "c=$(checkupdates 2>/dev/null | wc -l); [ \\"$c\\" -gt 0 ] && echo \\" $c\\" || echo \\"\\""
format = "{{{{ output }}}}"
hide-if-empty = true
tooltip-format = "Atualizações pendentes no Arch/CachyOS"
icon-show = false
label-show = true
label-color = "green"
button-bg-color = "bg-surface-elevated"
border-show = {'true' if is_bordered else 'false'}
border-color = "green"
left-click = "kitty --title system-update sh -c 'sudo pacman -Syu'"

[[modules.custom]]
id = "cycle-wall"
mode = "poll"
interval-ms = 3600000
command = "echo ''"
format = "{{{{ output }}}}"
tooltip-format = "Esq: Selecionar Wallpaper | Meio: Estilos Wayle | Dir: Wallpaper Aleatório"
icon-show = false
label-show = true
label-color = "blue"
button-bg-color = "bg-surface-elevated"
border-show = {'true' if is_bordered else 'false'}
border-color = "blue"
left-click = "$HOME/.config/hypr/scripts/WallpaperSelect.sh"
middle-click = "$HOME/.config/hypr/scripts/WaybarStyles.sh"
right-click = "$HOME/.config/hypr/scripts/WallpaperRandom.sh"

[[modules.custom]]
id = "light-dark"
mode = "poll"
interval-ms = 3600000
command = "echo '󰔎'"
format = "{{{{ output }}}}"
tooltip-format = "Alternar Tema Claro/Escuro ou Estilo Wayle"
icon-show = false
label-show = true
label-color = "yellow"
button-bg-color = "bg-surface-elevated"
border-show = {'true' if is_bordered else 'false'}
border-color = "yellow"
left-click = "$HOME/.config/hypr/scripts/WaybarStyles.sh"
right-click = "$HOME/.config/hypr/scripts/DarkLight.sh"

[[modules.custom]]
id = "lock"
mode = "poll"
interval-ms = 3600000
command = "echo '󰌾'"
format = "{{{{ output }}}}"
tooltip-format = "Bloquear Tela (Hyprlock)"
icon-show = false
label-show = true
label-color = "red"
button-bg-color = "bg-surface-elevated"
border-show = {'true' if is_bordered else 'false'}
border-color = "red"
left-click = "$HOME/.config/hypr/scripts/LockScreen.sh"

[[modules.custom]]
id = "settings"
mode = "poll"
interval-ms = 3600000
command = "echo ''"
format = "{{{{ output }}}}"
tooltip-format = "Esq: KooL Quick Settings | Dir: Wayle Settings"
icon-show = false
label-show = true
label-color = "accent"
button-bg-color = "bg-surface-elevated"
border-show = {'true' if is_bordered else 'false'}
border-color = "accent"
left-click = "$HOME/.config/hypr/scripts/Kool_Quick_Settings.sh"
right-click = "wayle panel settings"

[[modules.custom]]
id = "files"
mode = "poll"
interval-ms = 3600000
command = "echo ''"
format = "{{{{ output }}}}"
tooltip-format = "Abrir Gerenciador de Arquivos (Thunar)"
icon-show = false
label-show = true
label-color = "blue"
button-bg-color = "bg-surface-elevated"
border-show = {'true' if is_bordered else 'false'}
border-color = "blue"
left-click = "thunar"

[[modules.custom]]
id = "tty"
mode = "poll"
interval-ms = 3600000
command = "echo ''"
format = "{{{{ output }}}}"
tooltip-format = "Abrir Terminal (Kitty)"
icon-show = false
label-show = true
label-color = "green"
button-bg-color = "bg-surface-elevated"
border-show = {'true' if is_bordered else 'false'}
border-color = "green"
left-click = "kitty"

[[modules.custom]]
id = "browser"
mode = "poll"
interval-ms = 3600000
command = "echo ''"
format = "{{{{ output }}}}"
tooltip-format = "Abrir Navegador"
icon-show = false
label-show = true
label-color = "yellow"
button-bg-color = "bg-surface-elevated"
border-show = {'true' if is_bordered else 'false'}
border-color = "yellow"
left-click = "xdg-open https://"

[osd]
enabled = true
position = "bottom"
duration = 2000
monitor = "primary"
margin = 120.0
border = true
layer = "overlay"

[wallpaper]
engine-enabled = false
"""

with open(CONFIG_TOML, "w", encoding="utf-8") as f:
    f.write(config_content)

print(f"Synced Wayle config: Layout='{layout_name}', Style='{style_name}' (scss='{scss_slug}')")
