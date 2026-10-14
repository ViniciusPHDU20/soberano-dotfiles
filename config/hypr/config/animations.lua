-- Smooth & Fluid - Elegant ease-in-out curves with balanced fluid motion
hl.curve("easeOutQuint",   { type = "bezier", points = { {0.23, 1}, {0.32, 1} } })
hl.curve("easeInOutCubic", { type = "bezier", points = { {0.65, 0.05}, {0.36, 1} } })
hl.curve("smoothLinear",   { type = "bezier", points = { {0.25, 0.1}, {0.25, 1} } })

hl.animation({ leaf = "global",              enabled = true, speed = 4,   bezier = "easeOutQuint" })
hl.animation({ leaf = "windows",             enabled = true, speed = 4,   bezier = "easeOutQuint",   style = "slide" })
hl.animation({ leaf = "windowsOut",          enabled = true, speed = 3.5, bezier = "easeInOutCubic", style = "slide" })
hl.animation({ leaf = "workspaces",          enabled = true, speed = 4.5, bezier = "easeOutQuint",   style = "slide" })
hl.animation({ leaf = "specialWorkspaceIn",  enabled = true, speed = 3,   bezier = "easeOutQuint",   style = "slide top" })
hl.animation({ leaf = "specialWorkspaceOut", enabled = true, speed = 3,   bezier = "easeInOutCubic", style = "slide bottom" })
hl.animation({ leaf = "fadeIn",              enabled = true, speed = 3,   bezier = "smoothLinear" })
hl.animation({ leaf = "fadeOut",             enabled = true, speed = 3,   bezier = "smoothLinear" })
