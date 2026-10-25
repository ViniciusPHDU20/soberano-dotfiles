-- ==============================================================================
-- Soberano Monitor Configuration (Auto-configured by Super + M)
-- ==============================================================================

hl.monitor({
    output   = "DP-1",
    mode     = "1920x1080@165.00",
    position = "0x0",
    scale    = "1.0",
})

hl.monitor({
    output   = "HDMI-A-2",
    mode     = "1920x1080@60.00",
    position = "0x-1080",
    scale    = "1.0",
})

-- Universal Fallback for any secondary displays or laptop screens
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = "auto",
})
