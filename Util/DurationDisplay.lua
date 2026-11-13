local appName, app = ...
---@class AbilityTimeline
local private = app
local ThemeApply = private.ThemeApply

-- the duration display lane's look on spell icons and big icons: the big icon's cooldown spinner, an edge bar, a border
-- trace, a dial around the countdown or final-seconds pips, plus the heartbeat lane's pulsing halo. Every style runs on
-- the spinner's clock: from the remaining time the icon showed with (or the section's start) to the section's end.
local BORDER = { "TopRight", "Right", "Bottom", "Left", "TopLeft" }

local hideStyles = function(layer)
    for _, texture in ipairs(layer.Textures) do texture:Hide() end
    layer.Dial:Hide()
    layer.DialTrack:Hide()
    if layer.Swipe then layer.Swipe:Hide() end
end

local hideAll = function(layer)
    hideStyles(layer)
    layer.Beat.Pulse:Stop()
    layer.Beat:Hide()
    layer.style, layer.beatTime = nil, nil
end

ThemeApply.ResetDuration = function(frame)
    local layer = frame.DurationLayer
    if not layer then return end
    hideAll(layer)
    layer.longest, layer.ends = nil, nil
    layer.Dial.atBegan, layer.Dial.atDuration = nil, nil
    if layer.Swipe then layer.Swipe.atBegan, layer.Swipe.atDuration = nil, nil end
end

---creates the duration layer once, parent is the frame the countdown text sits in
---@param frame Frame
---@param parent Frame
ThemeApply.ConfigureDuration = function(frame, parent)
    local layer = frame.DurationLayer
    if not layer then
        layer = CreateFrame("Frame", nil, parent)
        frame.DurationLayer = layer
        layer:SetAllPoints(frame)
        layer.Textures = {}
        local texture = function(key, sublevel)
            local region = layer:CreateTexture(nil, "OVERLAY", nil, sublevel)
            layer[key] = region
            table.insert(layer.Textures, region)
            return region
        end
        texture("BarTrack", 0)
        texture("BarFill", 1)
        for _, key in ipairs(BORDER) do texture(key, 1) end
        layer.Pips = {}
        for index = 1, 10 do layer.Pips[index] = texture("Pip" .. index, 1) end
        layer.DialTrack = layer:CreateTexture(nil, "ARTWORK")
        -- a native cooldown swipe empties the ring, available on every client
        layer.Dial = CreateFrame("Cooldown", nil, layer)
        layer.Dial:SetDrawEdge(false)
        layer.Dial:SetDrawBling(false)
        layer.Dial:SetUseCircularEdge(true)
        layer.Dial:SetHideCountdownNumbers(true)
        layer.Dial.noCooldownCount = true
        -- the heartbeat halo is the soft edge of its texture cut into eight pieces around the icon, so the whole
        -- falloff shows at any spread instead of a fixed nine-slice margin that a small icon would cover
        layer.Beat = CreateFrame("Frame", nil, layer)
        layer.Beat.Pieces = {}
        for index = 1, 8 do layer.Beat.Pieces[index] = layer.Beat:CreateTexture(nil, "BACKGROUND") end
        layer.Beat.Pulse = layer.Beat:CreateAnimationGroup()
        layer.Beat.Pulse:SetLooping("BOUNCE")
        layer.Beat.Fade = layer.Beat.Pulse:CreateAnimation("Alpha")
        layer.Beat.Fade:SetFromAlpha(0)
        layer.Beat.Fade:SetToAlpha(1)
        layer.Beat.Fade:SetSmoothing("IN_OUT")
        -- big icons have a native cooldown spinner of their own, spell icons have none
        layer.Swipe = frame.CooldownClip and frame.Cooldown
        frame:HookScript("OnHide", ThemeApply.ResetDuration)
    end
    hideAll(layer)
    local spec = private.GetElementStyle("Duration")
    layer.spec = spec
    if not spec.Ring then return end
    ThemeApply.Solid(layer.BarTrack, ThemeApply.Color(spec.Track))
    ThemeApply.Solid(layer.BarFill, 1, 1, 1, 1)
    for _, key in ipairs(BORDER) do ThemeApply.Solid(layer[key], 1, 1, 1, 1) end
    for _, pip in ipairs(layer.Pips) do ThemeApply.Texture(pip, spec.Pips.Art) end
    layer.DialTrack:SetTexture(ThemeApply.File(spec.Ring.File))
    layer.DialTrack:SetVertexColor(ThemeApply.Color(spec.Track))
    layer.dialFile, layer.dialColor = ThemeApply.File(spec.Ring.File), nil
    local edge = spec.Heartbeat.Edge or 0.375
    -- texture coordinates of the corners and sides of the texture's soft edge, clockwise from the top left
    local coords = {
        { 0, edge, 0, edge }, { edge, 1 - edge, 0, edge }, { 1 - edge, 1, 0, edge }, { 1 - edge, 1, edge, 1 - edge },
        { 1 - edge, 1, 1 - edge, 1 }, { edge, 1 - edge, 1 - edge, 1 }, { 0, edge, 1 - edge, 1 }, { 0, edge, edge, 1 - edge },
    }
    for index, piece in ipairs(layer.Beat.Pieces) do
        piece:SetTexture(ThemeApply.File(spec.Heartbeat.Art.File))
        piece:SetTexCoord(unpack(coords[index]))
        piece:SetBlendMode(spec.Heartbeat.Art.BlendMode or "BLEND")
    end
end

-- where each halo piece sits: its corner, the icon corner it hangs off, and the second pair for the stretched sides
local PIECES = {
    { "BOTTOMRIGHT", "TOPLEFT" }, { "BOTTOMLEFT", "TOPLEFT", "BOTTOMRIGHT", "TOPRIGHT" }, { "BOTTOMLEFT", "TOPRIGHT" },
    { "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }, { "TOPLEFT", "BOTTOMRIGHT" },
    { "TOPLEFT", "BOTTOMLEFT", "TOPRIGHT", "BOTTOMRIGHT" }, { "TOPRIGHT", "BOTTOMLEFT" },
    { "TOPRIGHT", "TOPLEFT", "BOTTOMRIGHT", "BOTTOMLEFT" },
}

---the time the timer ends at, kept until the countdown drifts from it (a pause, a restarted preview)
local clock = function(layer, remaining)
    local now = GetTime()
    layer.longest = math.max(layer.longest or 0, remaining)
    if not layer.ends or math.abs(layer.ends - now - remaining) > 0.1 then layer.ends = now + remaining end
    return layer.ends - now
end

---a native cooldown on the shared clock, set again only when the clock or the section moves
local sync = function(cooldown, ends, start, finish)
    local began, duration = ends - start, start - finish
    if cooldown.atBegan ~= began or cooldown.atDuration ~= duration then
        cooldown:SetCooldown(began, duration)
        cooldown.atBegan, cooldown.atDuration = began, duration
    end
    cooldown:Show()
end

local drawBar = function(layer, frame, width, thickness, f, r, g, b, a)
    layer.BarTrack:ClearAllPoints()
    layer.BarTrack:SetPoint("BOTTOMLEFT", frame.SpellIcon, "BOTTOMLEFT")
    layer.BarTrack:SetSize(width, thickness)
    layer.BarTrack:Show()
    layer.BarFill:ClearAllPoints()
    layer.BarFill:SetPoint("BOTTOMLEFT", frame.SpellIcon, "BOTTOMLEFT")
    layer.BarFill:SetSize(math.max(0.01, width * f), thickness)
    layer.BarFill:SetVertexColor(r, g, b, a)
    layer.BarFill:SetShown(f > 0)
end

-- clockwise from the top centre: each edge's share of the path, the corner it grows from and its direction
local drawBorder = function(layer, frame, width, height, thickness, f, r, g, b, a)
    local icon = frame.SpellIcon
    local path = 2 * width + 2 * height
    local cut = (1 - f) * path
    local edges = {
        { key = "TopRight", from = 0, length = width / 2, point = "TOPRIGHT", horizontal = true },
        { key = "Right", from = width / 2, length = height, point = "BOTTOMRIGHT" },
        { key = "Bottom", from = width / 2 + height, length = width, point = "BOTTOMLEFT", horizontal = true },
        { key = "Left", from = 1.5 * width + height, length = height, point = "TOPLEFT" },
        { key = "TopLeft", from = 1.5 * width + 2 * height, length = width / 2, point = "TOPRIGHT", relative = "TOP", horizontal = true },
    }
    for _, edge in ipairs(edges) do
        local texture = layer[edge.key]
        local shown = edge.from + edge.length - math.max(edge.from, cut)
        if shown > 0 then
            texture:ClearAllPoints()
            texture:SetPoint(edge.point, icon, edge.relative or edge.point)
            if edge.horizontal then texture:SetSize(math.min(shown, edge.length), thickness)
            else texture:SetSize(thickness, math.min(shown, edge.length)) end
            texture:SetVertexColor(r, g, b, a)
            texture:Show()
        else
            texture:Hide()
        end
    end
end

local drawPips = function(layer, frame, factor, remaining, r, g, b, a)
    local spec = layer.spec.Pips
    local count = math.max(1, math.min(#layer.Pips, math.floor(spec.Count or 5)))
    local size, spacing = spec.Size * factor, spec.Spacing * factor
    for index, pip in ipairs(layer.Pips) do
        if index <= count then
            pip:ClearAllPoints()
            pip:SetPoint("BOTTOM", frame.SpellIcon, "BOTTOM", (index - (count + 1) / 2) * spacing, spec.Offset * factor)
            pip:SetSize(size, size)
            pip:SetVertexColor(r, g, b, remaining > index - 1 and a or a * (spec.OffAlpha or 0.2))
            pip:Show()
        else
            pip:Hide()
        end
    end
end

local drawDial = function(layer, frame, width, region, start, finish, r, g, b, a)
    local spec = layer.spec.Ring
    local text = region.atCountdownSize or width * 0.4
    local size = math.min(width * 0.9, text * (spec.Scale or 1.9))
    for _, part in ipairs({ layer.DialTrack, layer.Dial }) do
        part:ClearAllPoints()
        part:SetPoint("CENTER", frame.SpellIcon, "CENTER")
        part:SetSize(size, size)
    end
    layer.DialTrack:Show()
    if layer.dialColor ~= r .. g .. b .. a then
        layer.Dial:SetSwipeTexture(layer.dialFile, r, g, b, a)
        layer.dialColor = r .. g .. b .. a
    end
    sync(layer.Dial, layer.ends, start, finish)
end

local drawBeat = function(layer, frame, factor, value, remaining, r, g, b)
    local spec = layer.spec.Heartbeat
    local spread = (spec.Spread or 10) * factor
    if value.color then r, g, b = ThemeApply.Color(value.color) end
    for index, piece in ipairs(layer.Beat.Pieces) do
        local place = PIECES[index]
        piece:ClearAllPoints()
        piece:SetPoint(place[1], frame.SpellIcon, place[2])
        if place[3] then
            piece:SetPoint(place[3], frame.SpellIcon, place[4])
            if index == 2 or index == 6 then piece:SetHeight(spread) else piece:SetWidth(spread) end
        else
            piece:SetSize(spread, spread)
        end
        piece:SetVertexColor(r, g, b, spec.Alpha or 0.6)
    end
    layer.Beat:Show()
    if private.GetAnimationLevel() == private.ANIMATION_LEVELS.OFF then
        layer.Beat.Pulse:Stop()
        layer.Beat:SetAlpha(0.5)
        layer.beatTime = nil
        return
    end
    local time = remaining <= (spec.Urgent or 3) and spec.UrgentTime or spec.Time
    if layer.beatTime ~= time then
        layer.Beat.Pulse:Stop()
        layer.Beat.Fade:SetDuration(time / 2)
        layer.Beat.Pulse:Play()
        layer.beatTime = time
    end
end

---draws the duration and heartbeat lanes of a resolved countdown style
ThemeApply.UpdateDuration = function(frame, display, style, origins, remaining, state, region)
    local layer = frame.DurationLayer
    local spec = layer.spec
    local STATES = private.manager.STATES
    local kind = style.duration ~= "none" and style.duration or false
    if not spec or not spec.Ring or (not kind and not style.heartbeat) or not private.CooldownText.IsFinite(remaining) or
        remaining <= 0 or state == STATES.Queued or state == STATES.Paused then
        -- the big icon starts its spinner when it shows, it stays hidden unless the spinner is the duration display
        if layer.Swipe then layer.Swipe:Hide() end
        if layer.style ~= nil then hideAll(layer) end
        return
    end
    layer:SetFrameLevel(layer:GetParent():GetFrameLevel() + 1)
    local width, height = ThemeApply.IconSize(frame)
    local factor = width / (spec.ReferenceSize or 44)
    local thickness = math.max(1, (spec.Thickness or 3) * factor)
    local r, g, b, a
    if spec.UseCountdownColor ~= false then r, g, b, a = ThemeApply.Color(style.color or private.CooldownText.BaseColor(display))
    else r, g, b, a = ThemeApply.Color(spec.Color) end
    if layer.style ~= kind then
        hideStyles(layer)
        layer.style = kind
    end
    -- the same clock and span the spinner runs on, from the time the icon showed with or the section's later start
    local left = clock(layer, remaining)
    local origin = origins.duration
    local start, finish = layer.longest, origin and origin.finish or 0
    if origin then start = math.min(origin.start, start) end
    local f = start > finish and math.max(0, math.min(1, (left - finish) / (start - finish))) or 1
    if kind == "swipe" then
        if layer.Swipe then sync(layer.Swipe, layer.ends, start, finish) end
    elseif layer.Swipe then
        layer.Swipe:Hide()
    end
    if kind == "bar" then drawBar(layer, frame, width, thickness, f, r, g, b, a)
    elseif kind == "border" then drawBorder(layer, frame, width, height, thickness, f, r, g, b, a)
    elseif kind == "pips" then drawPips(layer, frame, factor, remaining, r, g, b, a)
    elseif kind == "dial" then drawDial(layer, frame, width, region, start, finish, r, g, b, a) end
    if style.heartbeat then drawBeat(layer, frame, factor, style.heartbeat, remaining, r, g, b)
    elseif layer.Beat:IsShown() then
        layer.Beat.Pulse:Stop()
        layer.Beat:Hide()
        layer.beatTime = nil
    end
end
