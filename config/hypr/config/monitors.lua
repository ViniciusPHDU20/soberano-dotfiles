-- ==============================================================================
-- Soberano Monitor Configuration (Plug & Play Universal)
-- Auto-detects native resolution & max refresh rate on any monitor / laptop screen
-- Use SUPER + M (display-picker-rs) to switch to custom modes / low-latency presets
-- ==============================================================================

-- Primary high-refresh display profile (Acer / 165Hz / DP-2)
hl.monitor({
    output    = "DP-2",
    mode      = "1920x1080@165.00",
    position  = "0x0",
    scale     = "1",
    transform = 0,
    vrr       = 0,
})

-- Universal Plug & Play Fallback: binds any display (DP, HDMI, eDP laptop, VM) to its native preferred mode
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = "1",
})
