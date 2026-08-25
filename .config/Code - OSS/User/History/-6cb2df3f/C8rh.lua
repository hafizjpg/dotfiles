hl.config({
    general = {
        gaps_in  = 4,
        gaps_out = 10,
        border_size = 2,
        col = {
            active_border   = { colors = { "rgba(6E50EBee)", "rgba(A08CF0ee)" }, angle = 45 },
            inactive_border = "rgba(1a1625aa)",
        },
        resize_on_border = true,
        allow_tearing = false,
        layout = "master",
    },
 a
    decoration = {
        rounding = 14,
        rounding_power = 4,
        active_opacity   = 0.96,
        inactive_opacity = 0.85,
 
        shadow = {
            enabled = true,
            range = 18,
            render_power = 3,
            color = 0xaa2a1a4a,       -- bayangan ungu gelap, bukan hitam polos
            color_inactive = 0x662a1a4a,
        },
 
        blur = {
            enabled = true,
            size = 6,
            passes = 3,
            vibrancy = 0.22,
            new_optimizations = true,
            xray = false,
        },
    },
 
    animations = {
        enabled = true,
    },
})
 
hl.curve("silk",    { type = "bezier", points = { {0.2, 0}, {0.05, 1} } })
hl.curve("bounce",  { type = "spring", mass = 1,   stiffness = 145, dampening = 14 })
hl.curve("drift",   { type = "spring", mass = 0.9, stiffness = 90,  dampening = 16 })
hl.curve("hfz", { type = "bezier", points = { {0.05, 0.7}, {0.1, 1} } })
 
hl.animation({ leaf = "global",  enabled = true, speed = 10,  bezier = "silk" })
 
hl.animation({ leaf = "windows",   enabled = true, speed = 6.2, spring = "bounce" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 4.0, bezier = "hfz", style = "popin 88%" })
hl.animation({ leaf = "windowsOut",enabled = true, speed = 3.2, bezier = "hfz", style = "popin 92%" })
 
hl.animation({ leaf = "border", enabled = true, speed = 5.2, spring = "bounce" })
 
hl.animation({ leaf = "fadeIn",  enabled = true, speed = 3.6, bezier = "hfz" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 2.8, bezier = "hfz" })
hl.animation({ leaf = "fade",    enabled = true, speed = 4.5, bezier = "silk" })
 
hl.animation({ leaf = "layers",    enabled = true, speed = 5.8, spring = "bounce" })
hl.animation({ leaf = "layersIn",  enabled = true, speed = 5.0, spring = "bounce", style = "popin 70%" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 3.6, bezier = "silk",   style = "fade" })
 
hl.animation({ leaf = "workspaces",    enabled = true, speed = 4.6, spring = "drift", style = "slidevert" })
hl.animation({ leaf = "workspacesIn",  enabled = true, speed = 4.6, spring = "drift", style = "slidevert" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 4.6, spring = "drift", style = "slidevert" })
 
hl.animation({ leaf = "zoomFactor", enabled = true, speed = 6.5, bezier = "silk" })