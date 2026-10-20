-- Universal Monitor Configuration

hl.monitor({
    output   = MONITOR1,
    mode     = "preferred",
    position = "0x0",
    scale    = "1",
})

-- Universal Fallback for any PC / Laptop / Secondary Displays
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = "auto",
})
