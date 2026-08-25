-- ===================== Config =====================
local CFG = {
    gap_out              = 10,
    gap_in               = 8,
    master_ratio_default = 0.55,
    master_ratio_min     = 0.20,
    master_ratio_max     = 0.80,
}

-- ===================== State =====================
local orderByWs       = {}
local modeByWs         = {}
local sizeOffsets      = {}
local masterRatioByWs  = {}
local sideByAddr       = {}   -- persistent left/right column membership per window

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
    return modeByWs[wsKey(wsId)] or "auto"
end

local function getMasterRatio(wsId)
    local key = wsKey(wsId)
    return masterRatioByWs[key] or CFG.master_ratio_default
end

-- Give a new (non-master) window a permanent side, balanced against
-- whichever column is currently shorter, so windows stop jumping
-- between left/right every time the stack count changes.
local function assignSide(addr, leftCount, rightCount)
    if sideByAddr[addr] then return sideByAddr[addr] end
    local side = (leftCount <= rightCount) and "left" or "right"
    sideByAddr[addr] = side
    return side
end

local function place_with_gap(target, x, y, w, h)
    local gi = CFG.gap_in / 2
    target:place({
        x = x + gi,
        y = y + gi,
        w = math.max(50, w - CFG.gap_in),
        h = math.max(50, h - CFG.gap_in),
    })
end

-- ===================== Window tracking =====================
hl.on("window.open", function(win)
    local ok, err = pcall(function()
        if not win or not win.address then return end
        local ws = win.workspace and win.workspace.id
        local key = wsKey(ws)
        orderByWs[key] = orderByWs[key] or {}
        if not indexOfAddr(orderByWs[key], win.address) then
            table.insert(orderByWs[key], win.address)
        end
    end)
    if not ok then hl.print("layout: window.open handler failed: " .. tostring(err)) end
end)

hl.on("window.close", function(win)
    local ok, err = pcall(function()
        if not win or not win.address then return end
        for _, list in pairs(orderByWs) do
            local idx = indexOfAddr(list, win.address)
            if idx then table.remove(list, idx) end
        end
        sizeOffsets[win.address] = nil
        sideByAddr[win.address]  = nil
    end)
    if not ok then hl.print("layout: window.close handler failed: " .. tostring(err)) end
end)

-- ===================== Layout =====================
hl.layout.register("centered_master", {
    recalculate = function(ctx)
        local ok, err = pcall(function()
            local n = #ctx.targets
            if n == 0 then return end

            -- outer gap around the whole usable area
            local area = {
                x = ctx.area.x + CFG.gap_out,
                y = ctx.area.y + CFG.gap_out,
                w = ctx.area.w - CFG.gap_out * 2,
                h = ctx.area.h - CFG.gap_out * 2,
            }

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

            -- register any windows missing from order (safety net)
            for _, target in ipairs(ctx.targets) do
                local w = target.window
                if w and w.address and not indexOfAddr(order, w.address) then
                    table.insert(order, w.address)
                end
            end

            -- drop stale addresses no longer present on this workspace
            for i = #order, 1, -1 do
                if not byAddr[order[i]] then table.remove(order, i) end
            end

            if n == 1 then
                local target = byAddr[order[1]] or ctx.targets[1]
                place_with_gap(target, area.x, area.y, area.w, area.h)
                return
            end

            local ratio    = getMasterRatio(wsId)
            local master_w = math.floor(area.w * ratio)
            local side_w   = math.floor((area.w - master_w) / 2)

            local leftAddrs, rightAddrs = {}, {}
            for i = 2, #order do
                local addr = order[i]
                if byAddr[addr] then
                    local side = assignSide(addr, #leftAddrs, #rightAddrs)
                    if side == "left" then
                        table.insert(leftAddrs, addr)
                    else
                        table.insert(rightAddrs, addr)
                    end
                end
            end

            local masterAddr   = order[1]
            local masterTarget = masterAddr and byAddr[masterAddr]
            if masterTarget then
                local offset  = sizeOffsets[masterAddr] or { dw = 0, dh = 0 }
                local final_w = math.max(150, master_w + offset.dw)
                local final_x = area.x + side_w - math.floor(offset.dw / 2)
                place_with_gap(masterTarget, final_x, area.y, final_w, area.h)
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
                        local ph = isLast and (area.h - (i - 1) * h) or math.max(80, h + offset.dh)
                        place_with_gap(target, x, area.y + (i - 1) * h, math.max(150, side_w + offset.dw), ph)
                    end
                end
            end

            stackColumn(leftAddrs,  area.x)
            stackColumn(rightAddrs, area.x + side_w + master_w)
        end)
        if not ok then hl.print("layout: recalculate failed: " .. tostring(err)) end
    end,

    layout_msg = function(ctx, msg, param)
        if msg == "toggle_mode" then
            local active = hl.get_active_window()
            local ws = active and active.workspace and active.workspace.id
            local key = wsKey(ws)
            modeByWs[key] = (getMode(ws) == "auto") and "manual" or "auto"
            hl.print("layout: mode -> " .. modeByWs[key])
            return
        end

        -- adjust master column width, e.g. bind to "mfact +0.05" / "mfact -0.05"
        if msg == "mfact" then
            local active = hl.get_active_window()
            local ws = active and active.workspace and active.workspace.id
            local key = wsKey(ws)
            local delta = tonumber(param) or 0
            local newRatio = getMasterRatio(ws) + delta
            newRatio = math.max(CFG.master_ratio_min, math.min(CFG.master_ratio_max, newRatio))
            masterRatioByWs[key] = newRatio
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

        -- promote the focused window to master
        if msg == "swapfocused" or msg == "swap_master" then
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
            return
        end

        -- rotate the focused window's position through the stack order
        if msg == "cyclenext" or msg == "cycleprev" then
            local active = hl.get_active_window()
            if not active or not active.address then return end
            local ws  = active.workspace and active.workspace.id
            local key = wsKey(ws)
            local order = orderByWs[key]
            if not order or #order < 2 then return end

            local idx = indexOfAddr(order, active.address)
            if not idx then return end

            local otherIdx
            if msg == "cyclenext" then
                otherIdx = (idx % #order) + 1
            else
                otherIdx = ((idx - 2) % #order) + 1
            end
            order[idx], order[otherIdx] = order[otherIdx], order[idx]
            return
        end

        -- clear manual resize offsets and reset the master ratio
        if msg == "resetsizes" then
            local active = hl.get_active_window()
            local ws = active and active.workspace and active.workspace.id
            local key = wsKey(ws)
            sizeOffsets = {}
            masterRatioByWs[key] = CFG.master_ratio_default
            return
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