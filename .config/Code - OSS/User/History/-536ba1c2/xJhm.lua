-- ============================================================
-- HYPRLAND CUSTOM LAYOUTS: centered_master & infinite_desktop
-- ============================================================

local orderByWs = {}
local modeByWs = {}          -- "auto" or "manual" for centered_master
local sizeOffsets = {}       -- Custom resize offsets per window address
local scrollOffsetByWs = {}  -- Dynamic X scroll offset for Infinite Desktop

local function wsKey(wsId)
    return wsId or "_unknown"
end

local function indexOfAddr(list, addr)
    for i, a in ipairs(list) do
        if a == addr then return i end
    end
    return nil
end

local function getMode(wsId)
    local key = wsKey(wsId)
    return modeByWs[key] or "auto"
end

-- Sync window open/close states across workspaces
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

-- =============================================================================
-- LAYOUT 1: CENTERED MASTER
-- =============================================================================
hl.layout.register("centered_master", {
    recalculate = function(ctx)
        local n = #ctx.targets
        if n == 0 then return end
        local area = ctx.area

        local wsId = nil
        for _, target in ipairs(ctx.targets) do
            if target.window and target.window.workspace then
                wsId = target.window.workspace.id
                break
            end
        end

        local key = wsKey(wsId)
        orderByWs[key] = orderByWs[key] or {}
        local order = orderByWs[key]

        local byAddr = {}
        for _, target in ipairs(ctx.targets) do
            local w = target.window
            if w and w.address then byAddr[w.address] = target end
        end

        for _, target in ipairs(ctx.targets) do
            local w = target.window
            if w and w.address and not indexOfAddr(order, w.address) then
                table.insert(order, w.address)
            end
        end

        if n == 1 then
            local target = byAddr[order[1]] or ctx.targets[1]
            target:place(area)
            return
        end

        local master_w = math.floor(area.w * 0.50)
        local side_w   = math.floor((area.w - master_w) / 2)

        local leftAddrs, rightAddrs = {}, {}
        for i = 2, #order do
            local addr = order[i]
            if byAddr[addr] then
                if (i % 2 == 0) then
                    table.insert(rightAddrs, addr)
                else
                    table.insert(leftAddrs, addr)
                end
            end
        end

        local masterAddr   = order[1]
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
        if msg == "toggle_mode" then
            local active = hl.get_active_window()
            local ws = active and active.workspace and active.workspace.id
            local key = wsKey(ws)
            modeByWs[key] = (getMode(ws) == "auto") and "manual" or "auto"
            return
        end

        if msg == "resizewindow" or msg == "resize" then
            local active = hl.get_active_window()
            if active and active.address then
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

hl.layout.register("infinite_desktop", {
    recalculate = function(ctx)
        local n = #ctx.targets
        if n == 0 then return end
        local area = ctx.area

        local wsId = nil
        for _, target in ipairs(ctx.targets) do
            if target.window and target.window.workspace then
                wsId = target.window.workspace.id
                break
            end
        end

        local key = wsKey(wsId)
        orderByWs[key] = orderByWs[key] or {}
        local order = orderByWs[key]

        local byAddr = {}
        for _, target in ipairs(ctx.targets) do
            local w = target.window
            if w and w.address then byAddr[w.address] = target end
        end

        for _, target in ipairs(ctx.targets) do
            local w = target.window
            if w and w.address and not indexOfAddr(order, w.address) then
                table.insert(order, w.address)
            end
        end

        scrollOffsetByWs[key] = scrollOffsetByWs[key] or 0
        local currentScroll = scrollOffsetByWs[key]

        local col_w = math.floor(area.w * 0.50)
        local center_x = area.x + math.floor((area.w - col_w) / 2)

        for i, addr in ipairs(order) do
            local target = byAddr[addr]
            if target then
                -- Calculate infinite X coordinates panning endlessly left or right
                local pos_x = center_x + ((i - 1) * col_w) - currentScroll
                target:place({
                    x = pos_x,
                    y = area.y,
                    w = col_w,
                    h = area.h,
                })
            end
        end
    end,

    layout_msg = function(ctx, msg)
        local active = hl.get_active_window()
        local ws = active and active.workspace and active.workspace.id
        local key = wsKey(ws)
        local area_w = (ctx.area and ctx.area.w) or 1920
        local col_w = math.floor(area_w * 0.50)

        scrollOffsetByWs[key] = scrollOffsetByWs[key] or 0

        if msg == "scroll_left" then
            scrollOffsetByWs[key] = scrollOffsetByWs[key] - col_w
        elseif msg == "scroll_right" then
            scrollOffsetByWs[key] = scrollOffsetByWs[key] + col_w
        elseif msg == "reset_scroll" then
            scrollOffsetByWs[key] = 0
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