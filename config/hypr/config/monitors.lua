-- ==============================================================================
-- Soberano Monitor Configuration (Auto-configured by Super + M)
-- ==============================================================================

hl.monitor({
    output    = "DP-2",
    mode      = "1920x1080@165.00",
    position  = "0x0",
    scale     = "1",
    transform = 0,
    vrr       = 0,
})

-- Universal Fallback for any secondary displays or laptop screens
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = "auto",
})
