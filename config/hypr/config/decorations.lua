-- Decorations & Dynamic Matugen Borders & Gaps
pcall(require, "config.colors_dynamic")
pcall(require, "config.gaps_dynamic")

local active1  = DYNAMIC_ACTIVE_1 or CACHYLGREEN
local active2  = DYNAMIC_ACTIVE_2 or CACHYDGREEN
local inactive = DYNAMIC_INACTIVE or CACHYGRAY

local d_gaps_in  = DYNAMIC_GAPS_IN or 3
local d_gaps_out = DYNAMIC_GAPS_OUT or 8
local d_rounding = DYNAMIC_ROUNDING or 10
local d_border   = DYNAMIC_BORDER_SIZE or 2

hl.config({
    general = {
        gaps_in = d_gaps_in,
        gaps_out = d_gaps_out,
        border_size = d_border,
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
        rounding = d_rounding,
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
