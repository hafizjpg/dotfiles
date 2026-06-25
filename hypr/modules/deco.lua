-----------------------
---- LOOK AND FEEL ----
-----------------------

hl.config({
    general = {
        gaps_in = 6,
        gaps_out = 25,

        border_size = 3,

        col = {
            active_border = {
                colors = {
                    "rgba(9d7cd8ff)", -- Violet purple
                    "rgba(d8b46aff)", -- Gold
                }
            },

            inactive_border = "rgba(3a3554aa)",
        },

        resize_on_border = false,
        allow_tearing = false,
    },

    decoration = {
        rounding = 16,
        rounding_power = 3,

        active_opacity = 0.96,
        inactive_opacity = 0.82,

        shadow = {
            enabled = true,
            range = 35,
            render_power = 4,
            color = "rgba(0b0915ee)",
        },

        blur = {
            enabled = true,
            size = 8,
            passes = 3,
            vibrancy = 0.35,
        },
    },

    animations = {
        enabled = true,
    },
})
hl.curve("violet", {
    type = "bezier",
    points = {
        {0.22, 1},
        {0.36, 1}
    }
})

hl.curve("letter", {
    type = "bezier",
    points = {
        {0.4, 0},
        {0.2, 1}
    }
})

hl.animation({ leaf = "global",     enabled = true, speed = 8, bezier = "violet" })
hl.animation({ leaf = "border",     enabled = true, speed = 6, bezier = "violet" })
hl.animation({ leaf = "windows",    enabled = true, speed = 5, bezier = "violet" })
hl.animation({ leaf = "windowsIn",  enabled = true, speed = 5, bezier = "violet", style = "popin 90%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 4, bezier = "letter", style = "popin 90%" })

hl.animation({ leaf = "fade",       enabled = true, speed = 5, bezier = "violet" })
hl.animation({ leaf = "fadeIn",     enabled = true, speed = 4, bezier = "violet" })
hl.animation({ leaf = "fadeOut",    enabled = true, speed = 3, bezier = "letter" })

hl.animation({ leaf = "layers",     enabled = true, speed = 5, bezier = "violet" })
hl.animation({ leaf = "layersIn",   enabled = true, speed = 4, bezier = "violet", style = "fade" })
hl.animation({ leaf = "layersOut",  enabled = true, speed = 3, bezier = "letter", style = "fade" })

hl.animation({ leaf = "workspaces", enabled = true, speed = 4, bezier = "violet", style = "fade" })
hl.animation({ leaf = "zoomFactor", enabled = true, speed = 6, bezier = "violet" })