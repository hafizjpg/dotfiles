-----------------------
---- LOOK AND FEEL ----
-----------------------

hl.config({
general = {
gaps_in  = 20,
gaps_out = 5,

border_size = 2,

col = {
active_border   = { colors = {"rgba(6e50ebaa)", "rgba(9b7cf0aa)", angle = 45}},
inactive_border = "rgba(59595966)",
        },

resize_on_border = true,
allow_tearing = false,
layout = "dwindle",
    },

decoration = {
rounding       = 5,
rounding_power = 5,

active_opacity   = 0.9,
inactive_opacity = 0.8,

shadow = {
enabled      = false,
range        = 4,
render_power = 3,
color        = 0xee1a1a1a,
        },

blur = {
enabled   = true,
size      = 4,
passes    = 3,
vibrancy  = 0.1696,
        },
    },

animations = {
enabled = true,
    },
})

hl.curve("glass",     { type = "spring", mass = 0.6, stiffness = 130, dampening = 11 })
hl.curve("snap",      { type = "bezier", points = { {0.1, 1.4}, {0.3, 1} } })
hl.curve("slingshot", { type = "bezier", points = { {0.65, -0.5}, {0.15, 1.5} } })
hl.curve("silk",      { type = "bezier", points = { {0.2, 0}, {0.05, 1} } })
hl.curve("bounce",    { type = "spring", mass = 1, stiffness = 170, dampening = 9 })

hl.animation({ leaf = "global",        enabled = true, speed = 10,   bezier = "silk" })

hl.animation({ leaf = "windows",       enabled = true, speed = 6.2,  spring = "bounce" })
hl.animation({ leaf = "windowsIn",     enabled = true, speed = 5.2,  bezier = "slingshot", style = "popin 65%" })
hl.animation({ leaf = "windowsOut",    enabled = true, speed = 4.2,  bezier = "slingshot", style = "popin 70%" })

hl.animation({ leaf = "border",        enabled = true, speed = 5.2,  spring = "bounce" })

hl.animation({ leaf = "fadeIn",        enabled = true, speed = 3.8,  bezier = "silk" })
hl.animation({ leaf = "fadeOut",       enabled = true, speed = 3.0,  bezier = "silk" })
hl.animation({ leaf = "fade",          enabled = true, speed = 4.5,  bezier = "silk" })

hl.animation({ leaf = "layers",        enabled = true, speed = 5.8,  spring = "bounce" })
hl.animation({ leaf = "layersIn",      enabled = true, speed = 5.0,  spring = "bounce",  style = "popin 70%" })
hl.animation({ leaf = "layersOut",     enabled = true, speed = 3.6,  bezier = "silk",   style = "fade" })

hl.animation({ leaf = "workspaces",    enabled = true, speed = 5.0,  bezier = "slingshot", style = "slidefade 80%" })
hl.animation({ leaf = "workspacesIn",  enabled = true, speed = 4.2,  bezier = "slingshot", style = "slidefade 80%" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 3.4,  bezier = "silk",       style = "slidefade 80%" })

hl.animation({ leaf = "zoomFactor",    enabled = true, speed = 6.5,  bezier = "silk" })