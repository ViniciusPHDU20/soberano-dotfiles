-- ==============================================================================
-- Soberano Hyprland Configuration (Native Lua + Wayle + Matugen)
-- ==============================================================================

require("config.variables")
pcall(require, "config.user_variables") -- Optional untracked user overrides
require("config.colors")
require("config.monitors")
require("config.environment")
pcall(require, "config.hardware") -- Auto-generated hardware adaptation (GPU / Laptop)
require("config.inputs")
require("config.animations")
require("config.decorations")
require("config.misc")
require("config.workspaces")
require("config.windowrules")
pcall(require, "config.user_rules")     -- Optional untracked user window/layer rules
require("config.binds")
pcall(require, "config.user_binds")     -- Optional untracked user keybindings
require("config.autostart")
