-- Bouncy & Lively - Dynamic spring physics with tactile elastic bounce
hl.curve("bounceSpring", { type = "spring", mass = 1.1, stiffness = 320, dampening = 18 })
hl.curve("gentleSpring", { type = "spring", mass = 1.0, stiffness = 220, dampening = 14 })
hl.curve("overshoot",    { type = "bezier", points = { {0.5, 0.9}, {0.1, 1.15} } })

hl.animation({ leaf = "global",              enabled = true, speed = 4,   spring = "gentleSpring" })
hl.animation({ leaf = "windows",             enabled = true, speed = 4,   spring = "bounceSpring", style = "popin 70%" })
hl.animation({ leaf = "windowsOut",          enabled = true, speed = 3,   bezier = "overshoot",    style = "popin 80%" })
hl.animation({ leaf = "workspaces",          enabled = true, speed = 4,   spring = "gentleSpring", style = "slide" })
hl.animation({ leaf = "specialWorkspaceIn",  enabled = true, speed = 3.5, spring = "bounceSpring", style = "slide top" })
hl.animation({ leaf = "specialWorkspaceOut", enabled = true, speed = 3,   spring = "gentleSpring", style = "slide bottom" })
hl.animation({ leaf = "fadeIn",              enabled = true, speed = 2.5, bezier = "overshoot" })
hl.animation({ leaf = "fadeOut",             enabled = true, speed = 2,   bezier = "overshoot" })
