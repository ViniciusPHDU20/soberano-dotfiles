-- Decorations & Dynamic Matugen Borders
pcall(require, "config.colors_dynamic")

local active1  = DYNAMIC_ACTIVE_1 or CACHYLGREEN
local active2  = DYNAMIC_ACTIVE_2 or CACHYDGREEN
local inactive = DYNAMIC_INACTIVE or CACHYGRAY

hl.config({
    general = {
        gaps_in = 3,
        gaps_out = 8,
        border_size = 2,
        extend_border_grab_area = 10,
        resize_on_border = true,
        col = {
            active_border = {
                colors = { active1, active2 },
                angle = 45,
            },
            inactive_border = inactive,
        },
    },
    group = {
        col = {
            border_active = active1,
            border_inactive = inactive,
            border_locked_active = active2,
            border_locked_inactive = inactive,
        },
        groupbar = {
            col = {
                active = active1,
                inactive = inactive,
                locked_active = active2,
                locked_inactive = inactive,
            },
        },
    },
    decoration = {
        dim_special = 0.3,
        rounding = 10,
        active_opacity = 0.95,
        inactive_opacity = 0.88,
        fullscreen_opacity = 1.0,
        blur = {
            size = 5,
            passes = 4,
            special = true,
        },
    },
})
