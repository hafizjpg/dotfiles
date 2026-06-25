hl.config({
    general = {
        layout = "master"
    },
})

-- See https://wiki.hypr.land/Configuring/Layouts/Dwindle-Layout/ for more
hl.config({
    dwindle = {
        preserve_split = true, -- You probably want this
    },
})

-- See https://wiki.hypr.land/Configuring/Layouts/Master-Layout/ for more
hl.config({
    master = {
        new_status = "master",
    },
})

-- See https://wiki.hypr.land/Configuring/Layouts/Scrolling-Layout/ for more
hl.config({
    scrolling = {
        fullscreen_on_one_column = true,
    },
})

hl.layer_rule({
    name = "rofianim",
    match = {namespace = "rofi"},
    animation = "slide left",
    dim_around = true

})hl.layer_rule({
    name = "qs",
    match = {namespace = "qs"},
    animation = "slide right",
    dim_around = true
})

