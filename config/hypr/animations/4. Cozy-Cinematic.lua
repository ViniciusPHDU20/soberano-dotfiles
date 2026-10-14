-- Cozy & Cinematic - Luxurious slow-motion ease for relaxed workflow
hl.curve("cinematicEase", { type = "bezier", points = { {0.16, 1}, {0.3, 1} } })
hl.curve("softDecel",     { type = "bezier", points = { {0.05, 0.7}, {0.1, 1} } })

hl.animation({ leaf = "global",              enabled = true, speed = 6,   bezier = "cinematicEase" })
hl.animation({ leaf = "windows",             enabled = true, speed = 6.5, bezier = "cinematicEase", style = "slide" })
hl.animation({ leaf = "windowsOut",          enabled = true, speed = 5,   bezier = "softDecel",     style = "slide" })
hl.animation({ leaf = "workspaces",          enabled = true, speed = 7,   bezier = "cinematicEase", style = "slide" })
hl.animation({ leaf = "specialWorkspaceIn",  enabled = true, speed = 5,   bezier = "cinematicEase", style = "slide top" })
hl.animation({ leaf = "specialWorkspaceOut", enabled = true, speed = 5,   bezier = "softDecel",     style = "slide bottom" })
hl.animation({ leaf = "fadeIn",              enabled = true, speed = 4.5, bezier = "softDecel" })
hl.animation({ leaf = "fadeOut",             enabled = true, speed = 4,   bezier = "softDecel" })
