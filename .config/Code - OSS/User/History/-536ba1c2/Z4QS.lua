-- ===================== Config =====================
local CFG = {
    gap_out              = 10,
    gap_in               = 8,
    master_ratio_default = 0.55,
    master_ratio_min     = 0.20,
    master_ratio_max     = 0.80,
    side_ratio_default   = 0.50,  -- left vs right share of the remaining side space
    side_ratio_min       = 0.15,
    side_ratio_max       = 0.85,
    weight_min           = 0.20,  -- min/max relative height weight for a stacked window
    weight_max           = 6.00,
}

-- ===================== State =====================
local orderByWs        = {}
local modeByWs          = {}
local masterRatioByWs   = {}
local sideRatioByWs     = {}
local sideByAddr        = {}   -- persistent left/right column membership per window
local heightWeightByAddr = {}  -- relative height weight per window inside its column
local lastAreaByWs      = {}   -- cached usable area per workspace, used to convert px deltas -> ratio deltas

local function wsKey(wsId)
    return wsId or "_unknown"
end

local function clamp(v, lo, hi)
    return math.max(lo, math.min(hi, v))
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

local function getSideRatio(wsId)
    local key = wsKey(wsId)
    return sideRatioByWs[key] or CFG.side_ratio_default
end

local function getWeight(addr)
    return heightWeightByAddr[addr] or 1
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

local function parseDelta(param)
    local dw, dh = 0, 0
    if type(param) == "table" then
        dw = tonumber(param.x or param[1]) or 0
        dh = tonumber(param.y or param[2]) or 0
    elseif type(param) == "string" then
        local x, y = param:match("(%-?%d+%.?%d*)%s+(%-?%d+%.?%d*)")
        dw = tonumber(x) or 0
        dh = tonumber(y) or 0
    end
    return dw, dh
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
        sideByAddr[win.address]        = nil
        heightWeightByAddr[win.address] = nil
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
            lastAreaByWs[key] = area

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

            local ratio     = getMasterRatio(wsId)
            local master_w  = math.floor(area.w * ratio)
            local side_total = area.w - master_w

            local sideRatio = getSideRatio(wsId)
            local left_w    = math.floor(side_total * sideRatio)
            local right_w   = side_total - left_w

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
                place_with_gap(masterTarget, area.x + left_w, area.y, master_w, area.h)
            end

            -- distribute column height by relative weight so resizing one
            -- window borrows space from its neighbour instead of overlapping it
            local function stackColumn(addrs, x, w)
                local count = #addrs
                if count == 0 then return end

                local totalWeight = 0
                for _, addr in ipairs(addrs) do totalWeight = totalWeight + getWeight(addr) end
                if totalWeight <= 0 then totalWeight = count end

                local yCursor = area.y
                for i, addr in ipairs(addrs) do
                    local target = byAddr[addr]
                    if target then
                        local isLast = (i == count)
                        local wh = math.floor(area.h * (getWeight(addr) / totalWeight))
                        local ph = isLast and (area.y + area.h - yCursor) or math.max(60, wh)
                        place_with_gap(target, x, yCursor, w, ph)
                        yCursor = yCursor + ph
                    end
                end
            end

            stackColumn(leftAddrs,  area.x, left_w)
            stackColumn(rightAddrs, area.x + left_w + master_w, right_w)
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

        -- keybind-driven master width adjust, e.g. bind to "mfact +0.05" / "mfact -0.05"
        if msg == "mfact" then
            local active = hl.get_active_window()
            local ws = active and active.workspace and active.workspace.id
            local key = wsKey(ws)
            local delta = tonumber(param) or 0
            masterRatioByWs[key] = clamp(getMasterRatio(ws) + delta, CFG.master_ratio_min, CFG.master_ratio_max)
            return
        end

        -- keybind-driven left/right split adjust, e.g. bind to "sidefact +0.05"
        if msg == "sidefact" then
            local active = hl.get_active_window()
            local ws = active and active.workspace and active.workspace.id
            local key = wsKey(ws)
            local delta = tonumber(param) or 0
            sideRatioByWs[key] = clamp(getSideRatio(ws) + delta, CFG.side_ratio_min, CFG.side_ratio_max)
            return
        end

        -- interactive resize: mouse-drag a window border, or bind a delta manually.
        -- master column border -> adjusts mfact. side column border -> adjusts
        -- sidefact horizontally and borrows height from the neighbouring window
        -- in the same column vertically. Always keeps the layout fully packed
        -- (no overlaps, no gaps), unlike raw pixel offsets.
        if msg == "resizewindow" or msg == "resize" then
            local active = hl.get_active_window()
            if not (active and active.address) then return end
            local addr = active.address
            local ws   = active.workspace and active.workspace.id
            local key  = wsKey(ws)

            local order = orderByWs[key]
            local area  = lastAreaByWs[key]
            if not order or not area or area.w <= 0 or area.h <= 0 then return end

            local dw, dh = parseDelta(param)
            local idx = indexOfAddr(order, addr)
            if not idx then return end

            if idx == 1 then
                -- master window: horizontal drag resizes the master column
                if dw ~= 0 then
                    masterRatioByWs[key] = clamp(getMasterRatio(ws) + (dw / area.w), CFG.master_ratio_min, CFG.master_ratio_max)
                end
                return
            end

            local side = sideByAddr[addr]

            if dw ~= 0 then
                local sideDelta = dw / area.w
                local cur = getSideRatio(ws)
                local newSide = (side == "left") and (cur + sideDelta) or (cur - sideDelta)
                sideRatioByWs[key] = clamp(newSide, CFG.side_ratio_min, CFG.side_ratio_max)
            end

            if dh ~= 0 then
                local colAddrs = {}
                for i = 2, #order do
                    local a = order[i]
                    if sideByAddr[a] == side then table.insert(colAddrs, a) end
                end
                local pos = indexOfAddr(colAddrs, addr)
                if pos and #colAddrs > 1 then
                    local neighborPos = (pos < #colAddrs) and (pos + 1) or (pos - 1)
                    local neighborAddr = colAddrs[neighborPos]
                    local weightDelta = (dh / area.h) * #colAddrs

                    -- growing downward border (not the last window) borrows from the
                    -- next window; the last window's bottom border borrows from the one above
                    if pos >= neighborPos then weightDelta = -weightDelta end

                    local w1 = clamp(getWeight(addr) + weightDelta, CFG.weight_min, CFG.weight_max)
                    local w2 = clamp(getWeight(neighborAddr) - weightDelta, CFG.weight_min, CFG.weight_max)
                    heightWeightByAddr[addr]        = w1
                    heightWeightByAddr[neighborAddr] = w2
                end
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

        -- clear manual resizing (ratios + height weights) back to defaults
        if msg == "resetsizes" then
            local active = hl.get_active_window()
            local ws = active and active.workspace and active.workspace.id
            local key = wsKey(ws)
            local order = orderByWs[key] or {}

            masterRatioByWs[key] = CFG.master_ratio_default
            sideRatioByWs[key]   = CFG.side_ratio_default
            for _, addr in ipairs(order) do
                heightWeightByAddr[addr] = nil
            end
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