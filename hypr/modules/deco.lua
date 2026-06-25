-----------------------
---- LOOK AND FEEL ----
-----------------------

hl.config({
	general = {
		gaps_in = 5,
		gaps_out = 18,

		border_size = 2,

		col = {
			active_border = {
				colors = {
					"rgba(9d7cd8ff)",
					"rgba(d8b46aff)",
				},
			},

			inactive_border = "rgba(433d63aa)",
		},

		resize_on_border = false,
		allow_tearing = false,
	},

	decoration = {
		rounding = 16,
		rounding_power = 3.5,

		active_opacity = 0.97,
		inactive_opacity = 0.90,

		shadow = {
			enabled = true,
			range = 45,
			render_power = 5,
			color = "rgba(07040fee)",
		},

		blur = {
			enabled = true,
			size = 10,
			passes = 2,
			new_optimizations = true,
			xray = true,
		},
	},

	animations = {
		enabled = true,
	},
})

-----------------------
---- ANIMATION ----
-----------------------

hl.curve("violet", {
	type = "bezier",
	points = {
		{ 0.05, 0.9 },
		{ 0.1, 1 },
	},
})

hl.curve("letter", {
	type = "bezier",
	points = {
		{ 0.3, 0 },
		{ 0.15, 1 },
	},
})

hl.animation({ leaf = "global", enabled = true, speed = 6, bezier = "violet" })

hl.animation({ leaf = "windows", enabled = true, speed = 5, bezier = "violet" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 5, bezier = "violet", style = "popin 95%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 4, bezier = "letter", style = "popin 95%" })

hl.animation({ leaf = "fade", enabled = true, speed = 4, bezier = "violet" })
hl.animation({ leaf = "layers", enabled = true, speed = 4, bezier = "violet" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 5, bezier = "violet", style = "slidefade" })

hl.animation({ leaf = "zoomFactor", enabled = true, speed = 5, bezier = "violet" })
