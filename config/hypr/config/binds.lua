-- ==============================================================================
-- Soberano Keybindings (Hyprland Lua + Wayle + Matugen + Fuzzel)
-- ==============================================================================

local mainMod = "SUPER"
local launchPrefix = ""
local scriptsDir = os.getenv("HOME") .. "/dotfiles/scripts"

local function digitCode(d)
    return "code:" .. (d == 0 and 19 or (9 + d))
end

---------------------------
---- WINDOW MANAGEMENT ----
---------------------------

hl.bind(mainMod .. " + Escape",      hl.dsp.exec_cmd("hyprctl kill"))
hl.bind(mainMod .. " + Q",           hl.dsp.window.close())
hl.bind(mainMod .. " + Space",       hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + ALT + Space", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + F",           hl.dsp.window.fullscreen())
hl.bind(mainMod .. " + SHIFT + F",   hl.dsp.window.fullscreen({ mode = 1 }))
hl.bind(mainMod .. " + J",           hl.dsp.layout("togglesplit"))

-- Change focus
hl.bind(mainMod .. " + Left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + Right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + Up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + Down",  hl.dsp.focus({ direction = "down" }))
hl.bind("ALT + Tab",           hl.dsp.window.cycle_next())
hl.bind(mainMod .. " + Tab",   hl.dsp.window.cycle_next())

-- Move active window
hl.bind(mainMod .. " + SHIFT + Up",                   hl.dsp.window.move({ direction = "u" }))
hl.bind(mainMod .. " + SHIFT + Right",                hl.dsp.window.move({ direction = "r" }))
hl.bind(mainMod .. " + SHIFT + Left",                 hl.dsp.window.move({ direction = "l" }))
hl.bind(mainMod .. " + SHIFT + Down",                 hl.dsp.window.move({ direction = "d" }))
hl.bind(mainMod .. " + SHIFT + mouse_up",             hl.dsp.window.move({ monitor   = "-1" }))
hl.bind(mainMod .. " + SHIFT + mouse_down",           hl.dsp.window.move({ monitor   = "+1" }))
hl.bind(mainMod .. " + CONTROL + SHIFT + Right",      hl.dsp.window.move({ workspace = "m+1" }))
hl.bind(mainMod .. " + CONTROL + SHIFT + Left",       hl.dsp.window.move({ workspace = "m-1" }))
hl.bind(mainMod .. " + CONTROL + SHIFT + mouse_up",   hl.dsp.window.move({ workspace = "m-1" }))
hl.bind(mainMod .. " + CONTROL + SHIFT + mouse_down", hl.dsp.window.move({ workspace = "m+1" }))

-- Move active window to workspace 1..10
for i = 1, NUM_WPM do
    local key = i % 10
    hl.bind(mainMod .. " + SHIFT + " .. digitCode(key), hl.dsp.window.move({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + ALT + " .. digitCode(key), hl.dsp.window.move({ workspace = i, follow = false }))
end

-- Move & Resize with mouse
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag())
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize())

-- Zoom
local function zoomfunction(value)
    local zoomvalue = hl.get_config("cursor:zoom_factor")
    if (zoomvalue + value) > 3.0 then
        hl.config({ cursor = { zoom_factor = 3.0 } })
    elseif (zoomvalue + value) < 1.0 then
        hl.config({ cursor = { zoom_factor = 1.0 } })
    else
        hl.config({ cursor = { zoom_factor = zoomvalue + value } })
    end
end
hl.bind(mainMod .. " + Minus",   function() zoomfunction(-0.3) end, { repeating = true })
hl.bind(mainMod .. " + Plus",    function() zoomfunction(0.3) end,  { repeating = true })
hl.bind(mainMod .. " + code:82", function() zoomfunction(-0.3) end, { repeating = true })
hl.bind(mainMod .. " + code:86", function() zoomfunction(0.3) end,  { repeating = true })

-----------------------------
---- LAUNCHER & APPS --------
-----------------------------

hl.bind(mainMod .. " + Return",        hl.dsp.exec_cmd(launchPrefix .. TERMINAL))
hl.bind(mainMod .. " + D",             hl.dsp.exec_cmd("pkill -x fuzzel || fuzzel"))
hl.bind(mainMod .. " + E",             hl.dsp.exec_cmd(launchPrefix .. FILE_MANAGER))
hl.bind(mainMod .. " + B",             hl.dsp.exec_cmd(launchPrefix .. BROWSER))
hl.bind(mainMod .. " + T",             hl.dsp.exec_cmd(launchPrefix .. EDITOR))
hl.bind(mainMod .. " + C",             hl.dsp.exec_cmd(launchPrefix .. CALCULATOR))
hl.bind("XF86Calculator",              hl.dsp.exec_cmd(launchPrefix .. CALCULATOR))
hl.bind("CONTROL + SHIFT + Escape",    hl.dsp.exec_cmd(launchPrefix .. TERMINAL .. " -e btop"))
hl.bind(mainMod .. " + Z",             hl.dsp.exec_cmd("wayle panel settings"))

-- Session & Lock
hl.bind(mainMod .. " + L",             hl.dsp.exec_cmd("loginctl lock-session"))
hl.bind("CONTROL + ALT + L",           hl.dsp.exec_cmd("loginctl lock-session"))
hl.bind("CONTROL + ALT + Delete",      hl.dsp.exec_cmd("hyprctl dispatch exit"))

---------------------------
---- HARDWARE CONTROLS ----
---------------------------

hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd("wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),        { locked = true, repeating = true })
hl.bind("XF86AudioMute",         hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),       { locked = true })
hl.bind("XF86AudioMicMute",      hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),     { locked = true })

hl.bind("XF86AudioPlay",         hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPause",        hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioNext",         hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPrev",         hl.dsp.exec_cmd("playerctl previous"),   { locked = true })

hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl set 5%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl set 5%-"), { locked = true, repeating = true })

-----------------------------------
---- SOBERANO ENGINE & THEMING ----
-----------------------------------

-- Screen Capture
hl.bind(mainMod .. " + P",     hl.dsp.exec_cmd("hyprpicker -a -n"))
hl.bind("Print",               hl.dsp.exec_cmd("grim -g \"$(slurp)\" - | wl-copy"))
hl.bind(mainMod .. " + Print", hl.dsp.exec_cmd("grim - | wl-copy"))

-- Wallpaper + Matugen Dynamic Material You
hl.bind(mainMod .. " + W",           hl.dsp.exec_cmd(scriptsDir .. "/WallpaperSelect.sh"))
hl.bind(mainMod .. " + SHIFT + W",   hl.dsp.exec_cmd(scriptsDir .. "/WallpaperSelect.sh"))
hl.bind(mainMod .. " + ALT + W",     hl.dsp.exec_cmd(scriptsDir .. "/WallpaperSelect.sh --random"))
hl.bind(mainMod .. " + ALT + B",     hl.dsp.exec_cmd(scriptsDir .. "/MatugenSchemeSelect.sh"))
hl.bind(mainMod .. " + CONTROL + B", hl.dsp.exec_cmd(scriptsDir .. "/WayleBarPresetSelect.sh"))
hl.bind(mainMod .. " + ALT + A",     hl.dsp.exec_cmd(scriptsDir .. "/HyprAnimationsSelector.sh"))

-- Game Mode (Ryzen 9 9950X + RTX 3060 Ti Low-Latency Mode)
hl.bind(mainMod .. " + SHIFT + G",   hl.dsp.exec_cmd(scriptsDir .. "/GameMode.sh"))
hl.bind(mainMod .. " + G",           hl.dsp.exec_cmd(scriptsDir .. "/GameMode.sh"))
hl.bind(mainMod .. " + F1",          hl.dsp.exec_cmd(scriptsDir .. "/GameMode.sh"))

-- Clipboard History (Cliphist + Fuzzel)
hl.bind(mainMod .. " + V",           hl.dsp.exec_cmd("cliphist list | fuzzel --dmenu -p '󰅌 Clipboard ❯ ' -w 60 -l 12 | cliphist decode | wl-copy"))

-- Refresh Wayle UI
hl.bind(mainMod .. " + ALT + R",     hl.dsp.exec_cmd("systemctl --user restart wayle.service"))

-- Workspace Overview (Quickshell)
hl.bind(mainMod .. " + A",           hl.dsp.exec_cmd(scriptsDir .. "/OverviewToggle.sh"))

-- Keybindings Visual HUD
hl.bind(mainMod .. " + SHIFT + K",   hl.dsp.exec_cmd(scriptsDir .. "/KeyBinds.sh"))
hl.bind(mainMod .. " + K",           hl.dsp.exec_cmd(scriptsDir .. "/KeyBinds.sh"))
hl.bind(mainMod .. " + H",           hl.dsp.exec_cmd(scriptsDir .. "/KeyBinds.sh"))
hl.bind(mainMod .. " + question",    hl.dsp.exec_cmd(scriptsDir .. "/KeyBinds.sh"))
hl.bind(mainMod .. " + SHIFT + slash", hl.dsp.exec_cmd(scriptsDir .. "/KeyBinds.sh"))

-------------------------------
---- WORKSPACES & MONITORS ----
-------------------------------

for i = 1, NUM_WPM do
    local key = i % 10
    hl.bind(mainMod .. " + " .. digitCode(key), hl.dsp.focus({ workspace = i }))
end

hl.bind(mainMod .. " + CONTROL + Right",       hl.dsp.focus({ workspace = "m+1" }))
hl.bind(mainMod .. " + CONTROL + Left",        hl.dsp.focus({ workspace = "m-1" }))
hl.bind(mainMod .. " + CONTROL + Down",        hl.dsp.focus({ workspace = "emptym" }))

hl.bind(mainMod .. " + mouse_down",           hl.dsp.focus({ workspace = "m-1" }))
hl.bind(mainMod .. " + mouse_up",             hl.dsp.focus({ workspace = "m+1" }))
hl.bind(mainMod .. " + CONTROL + mouse_up",   hl.dsp.focus({ workspace = "m-1" }))
hl.bind(mainMod .. " + CONTROL + mouse_down", hl.dsp.focus({ workspace = "m+1" }))

hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special" }))
hl.bind(mainMod .. " + S",         hl.dsp.workspace.toggle_special())
