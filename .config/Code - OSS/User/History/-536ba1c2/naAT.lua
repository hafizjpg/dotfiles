local orderByWs = {}
local modeByWs = {}    
local sizeOffsets = {}       

local function wsKey(wsId)
    return wsId or "_unknown"
end

local function indexOfAddr(list, addr)
    for i, a in ipairs(list) do
        if a == addr then return i end
    end
    return nil
end

hl.on("window.open", function(win)
    local ok = pcall(function()
        if not win or not win.address then return end
        local ws = win.workspace and win.workspace.id
        local key = wsKey(ws)
        orderByWs[key] = orderByWs[key] or {}
        if not indexOfAddr(orderByWs[key], win.address) then
            table.insert(orderByWs[key], win.address)
        end
    end)
    if not ok then hl.print("layout: window.open handler failed") end
end)

hl.on("window.close", function(win)
    local ok = pcall(function()
        if not win or not win.address then return end
        for _, list in pairs(orderByWs) do
            local idx = indexOfAddr(list, win.address)
            if idx then table.remove(list, idx) end
        end
        sizeOffsets[win.address] = nil
    end)
    if not ok then hl.print("layout: window.close handler failed") end
end)

hl.layout.register("centered_master", {
    recalculate = function(ctx)
        -- Separate tiled windows from floating windows
        local tiledTargets = {}
        for _, target in ipairs(ctx.targets) do
            local w = target.window
            -- If the window is floating, do not place it; let manual mouse/keyboard drag handle it
            if w and not w.floating then
                table.insert(tiledTargets, target)
            end
        end

        local n = #tiledTargets
        if n == 0 then return end
        local area = ctx.area

        local wsId = nil
        for _, target in ipairs(tiledTargets) do
            if target.window and target.window.workspace then
                wsId = target.window.workspace.id
                break
            end
        end

        local key = wsKey(wsId)
        orderByWs[key] = orderByWs[key] or {}
        local order = orderByWs[key]

        local byAddr = {}
        for _, target in ipairs(tiledTargets) do
            local w = target.window
            if w and w.address then byAddr[w.address] = target end
        end

        -- Filter order list to keep track of active tiled windows
        local activeOrder = {}
        for _, addr in ipairs(order) do
            if byAddr[addr] then
                table.insert(activeOrder, addr)
            end
        end

        -- Self-heal: any window Hyprland wants placed but that's missing
        -- from the tracked order (stale/racy window.open registration,
        -- wrong workspace key at insert time, etc.) gets appended here
        -- instead of silently never being placed. This is the fix for
        -- "second app doesn't show until I trigger a keybind" — previously
        -- such a window would simply never receive a :place() call.
        local seen = {}
        for _, addr in ipairs(activeOrder) do seen[addr] = true end
        for _, target in ipairs(tiledTargets) do
            local w = target.window
            if w and w.address and not seen[w.address] then
                table.insert(order, w.address)
                table.insert(activeOrder, w.address)
                seen[w.address] = true
            end
        end

        if n == 1 then
            local target = byAddr[activeOrder[1]] or tiledTargets[1]
            target:place(area)
            return
        end

        local master_w = math.floor(area.w * 0.50)
        local side_w   = math.floor((area.w - master_w) / 2)

        local leftAddrs, rightAddrs = {}, {}
        for i = 2, #activeOrder do
            local addr = activeOrder[i]
            if (i % 2 == 0) then
                table.insert(rightAddrs, addr)
            else
                table.insert(leftAddrs, addr)
            end
        end

        local masterAddr   = activeOrder[1]
        local masterTarget = masterAddr and byAddr[masterAddr]
        if masterTarget then
            local offset = sizeOffsets[masterAddr] or { dw = 0, dh = 0 }
            local final_w = math.max(100, master_w + offset.dw)
            local final_x = area.x + side_w - math.floor(offset.dw / 2)
            
            masterTarget:place({
                x = final_x,
                y = area.y,
                w = final_w,
                h = area.h,
            })
        end

        local function stackColumn(addrs, x)
            local count = #addrs
            if count == 0 then return end
            local h = math.floor(area.h / count)
            for i, addr in ipairs(addrs) do
                local target = byAddr[addr]
                if target then
                    local isLast = (i == count)
                    local offset = sizeOffsets[addr] or { dw = 0, dh = 0 }
                    target:place({
                        x = x,
                        y = area.y + (i - 1) * h,
                        w = math.max(100, side_w + offset.dw),
                        h = isLast and (area.h - (i - 1) * h) or math.max(50, h + offset.dh),
                    })
                end
            end
        end

        stackColumn(leftAddrs,  area.x)
        stackColumn(rightAddrs, area.x + side_w + master_w)
    end,

    layout_msg = function(ctx, msg, param)
        if msg == "resizewindow" or msg == "resize" then
            local active = hl.get_active_window()
            if active and active.address then
                -- If it's floating, use standard Hyprland resize dispatcher instead of manual offset
                if active.floating then
                    return
                end

                local addr = active.address
                sizeOffsets[addr] = sizeOffsets[addr] or { dw = 0, dh = 0 }

                local dw, dh = 0, 0
                if type(param) == "table" then
                    dw = tonumber(param.x or param[1]) or 0
                    dh = tonumber(param.y or param[2]) or 0
                elseif type(param) == "string" then
                    local x, y = param:match("(%-?%d+)%s+(%-?%d+)")
                    dw = tonumber(x) or 0
                    dh = tonumber(y) or 0
                end

                sizeOffsets[addr].dw = sizeOffsets[addr].dw + dw
                sizeOffsets[addr].dh = sizeOffsets[addr].dh + dh
            end
            return
        end

        if msg == "swapfocused" then
            local active = hl.get_active_window()
            if not active or not active.address then return end
            local ws  = active.workspace and active.workspace.id
            local key = wsKey(ws)
            local order = orderByWs[key]
            if not order then return end

            local idx = indexOfAddr(order, active.address)
            if idx and idx > 1 then
                order[idx], order[1] = order[1], order[idx]
            end
        end
    end,
})

hl.config({
    general = {
        layout = "lua:centered_master",
    },
    misc = {
        focus_on_activate = false,
    },
})