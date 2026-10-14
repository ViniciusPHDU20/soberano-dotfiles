-- Fast & Snappy - High-speed responsiveness for competitive gaming & rapid tiling
hl.curve("quick",  { type = "bezier", points = { {0.15, 0}, {0.1, 1} } })
hl.curve("snappy", { type = "bezier", points = { {0.05, 0.9}, {0.1, 1.05} } })

hl.animation({ leaf = "global",              enabled = true, speed = 2,   bezier = "quick" })
hl.animation({ leaf = "windows",             enabled = true, speed = 2.5, bezier = "snappy", style = "popin 80%" })
hl.animation({ leaf = "windowsOut",          enabled = true, speed = 2,   bezier = "quick",  style = "popin 80%" })
hl.animation({ leaf = "workspaces",          enabled = true, speed = 3,   bezier = "quick",  style = "slide" })
hl.animation({ leaf = "specialWorkspaceIn",  enabled = true, speed = 2,   bezier = "quick",  style = "slide top" })
hl.animation({ leaf = "specialWorkspaceOut", enabled = true, speed = 2,   bezier = "quick",  style = "slide bottom" })
hl.animation({ leaf = "fadeIn",              enabled = true, speed = 1.5, bezier = "quick" })
hl.animation({ leaf = "fadeOut",             enabled = true, speed = 1.5, bezier = "quick" })
