local appName, app = ...
---@class AbilityTimeline
local private = app
local issecretvalue = issecretvalue or function() return false end

private.CooldownText = {}
local Countdown = private.CooldownText
local properties = { "color", "size", "format", "precision", "rounding", "glow" }
-- a time style change carries its decimals and rounding, so those have no lanes of their own
Countdown.Lanes = { "color", "size", "format", "glow" }
Countdown.Displays = { "SpellIcon", "BigIcon", "TextHighlight" }
local fields = { remaining = "number", elapsed = "number", duration = "number", source = "string", state = "number" }
local cache
local generation = 0

local function finite(value)
    return not issecretvalue(value) and type(value) == "number" and value == value and value > -math.huge and value < math.huge
end
Countdown.IsFinite = finite

local function same(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then return a == b end
    for key, value in pairs(a) do if not same(value, b[key]) then return false end end
    for key in pairs(b) do if a[key] == nil then return false end end
    return true
end
Countdown.Same = same

---unknown inputs stay unknown through exclusions, they never become a match by negation
function Countdown.Match(selection, context)
    if not selection then return true end
    local kind = selection.kind
    if kind == "not" then
        local result = Countdown.Match(selection.child, context)
        if result == nil then return nil end
        return not result
    elseif kind == "all" or kind == "any" then
        local unknown = false
        for _, child in ipairs(selection.children or {}) do
            local result = Countdown.Match(child, context)
            if kind == "all" and result == false then return false end
            if kind == "any" and result == true then return true end
            unknown = unknown or result == nil
        end
        if unknown then return nil end
        return kind == "all"
    elseif kind ~= "test" or not fields[selection.field] then
        return nil
    end
    if selection.any then return true end
    local value = context[selection.field]
    if issecretvalue(value) or type(value) ~= fields[selection.field] then return nil end
    if fields[selection.field] == "number" and not finite(value) then return nil end
    local expected, op = selection.value, selection.op
    if selection.values then
        local found = selection.values[value] == true
        return op == "isNot" and not found or op ~= "isNot" and found
    end
    if type(expected) ~= type(value) or issecretvalue(expected) then return nil end
    if op == "is" then return value == expected end
    if op == "isNot" then return value ~= expected end
    if not finite(expected) then return nil end
    if op == "less" then return value < expected end
    if op == "atMost" then return value <= expected end
    if op == "greater" then return value > expected end
    if op == "atLeast" then return value >= expected end
    if op == "between" and finite(selection.upper) then return value >= expected and value <= selection.upper end
    return nil
end

local function requirements(selection, into)
    if not selection then return end
    if selection.field and not selection.any then into[selection.field] = true end
    if selection.child then requirements(selection.child, into) end
    for _, child in ipairs(selection.children or {}) do requirements(child, into) end
end

function Countdown.GetSettings()
    return private.db.profile.cooldown_settings.appearance
end

function Countdown.Invalidate()
    cache = nil
    generation = generation + 1
end

function Countdown.Changed()
    Countdown.Invalidate()
    private.RefreshTheme()
end

local function baseDefaults(appearance)
    local base = appearance.shared.base
    base.format, base.precision, base.rounding = "minutes", 0, "nearest"
    for _, scope in pairs(appearance.displays) do scope.base.format, scope.base.precision, scope.base.rounding = nil, nil, nil end
end

local function defaults(appearance)
    baseDefaults(appearance)
    table.insert(appearance.shared.changes, { id = "default-yellow", property = "color", start = 5, value = { r = 1, g = 1, b = 0, a = 1 } })
    table.insert(appearance.shared.changes, { id = "default-red", property = "color", start = 3, value = { r = 1, g = 0, b = 0, a = 1 } })
    table.insert(appearance.shared.changes, { id = "default-seconds", property = "format", start = 60, value = "seconds", precision = 0, rounding = "up" })
    table.insert(appearance.shared.changes, { id = "default-tenths", property = "format", start = 1, exclusiveStart = true, value = "seconds", precision = 1, rounding = "up" })
end

function Countdown.SetupDefaults(settings)
    if not settings.appearance then
        settings.appearance = { nextId = 1, shared = { base = { size = 100 }, changes = {} }, displays = {} }
        defaults(settings.appearance)
    end
    Countdown.Invalidate()
end

function Countdown.ResetStyle()
    baseDefaults(Countdown.GetSettings())
    Countdown.Invalidate()
end

function Countdown.ResetAll()
    local settings = private.db.profile.cooldown_settings
    settings.appearance = nil
    Countdown.SetupDefaults(settings)
end

---base appearance of a display, every change lives in the shared list with its own display set
function Countdown.Scope(display, create)
    local settings = Countdown.GetSettings()
    if display == "Shared" then return settings.shared end
    if create and not settings.displays[display] then settings.displays[display] = { base = {} } end
    return settings.displays[display]
end

function Countdown.Add(property, start, value)
    local settings = Countdown.GetSettings()
    local id = "change-" .. settings.nextId
    settings.nextId = settings.nextId + 1
    local change = { id = id, property = property, start = start, value = value, priority = settings.nextId }
    table.insert(settings.shared.changes, change)
    return change
end

function Countdown.Find(id)
    for _, change in ipairs(Countdown.GetSettings().shared.changes) do if change.id == id then return change end end
end

---coincident edits of the same look replace the section instead of hiding a second priority behind it
function Countdown.Coalesce(change)
    local changes = Countdown.GetSettings().shared.changes
    for i = #changes, 1, -1 do
        local other = changes[i]
        if other ~= change and other.property == change.property and other.start == change.start and other.finish == change.finish and
            same(other.displays, change.displays) and
            (same(other.selection, change.selection) or Countdown.Match(other.selection, {}) == true and Countdown.Match(change.selection, {}) == true) then
            table.remove(changes, i)
        end
    end
end

local function reach(change)
    if not change.displays then return #Countdown.Displays end
    local count = 0
    for _ in pairs(change.displays) do count = count + 1 end
    return count
end

---at the same start a change for fewer displays wins, so a display's own look sits above the general one
local function compiled()
    local settings = Countdown.GetSettings()
    if cache and cache.settings == settings then return cache end
    cache = { settings = settings, required = {}, changes = {} }
    for index, change in ipairs(settings.shared.changes) do
        if change.enabled ~= false and finite(change.start) and change.start > 0 and
            (change.finish == nil or finite(change.finish) and change.finish >= 0 and change.finish < change.start) then
            local property = change.property
            cache.changes[property] = cache.changes[property] or {}
            table.insert(cache.changes[property], { change = change, index = index })
            requirements(change.selection, cache.required)
        end
    end
    for _, list in pairs(cache.changes) do
        table.sort(list, function(a, b)
            if a.change.start ~= b.change.start then return a.change.start < b.change.start end
            local ra, rb = reach(a.change), reach(b.change)
            if ra ~= rb then return ra < rb end
            local pa, pb = a.change.priority or a.index, b.change.priority or b.index
            return pa > pb
        end)
    end
    return cache
end

local function choose(list, context, skip, display)
    if not finite(context.remaining) then return end
    local function applies(change)
        if context.previewChange and context.previewChange.id == change.id then change = context.previewChange end
        return change.id ~= skip and (not change.displays or change.displays[display]) and
            context.remaining <= change.start and (not change.exclusiveStart or context.remaining < change.start) and
            (not change.finish or context.remaining > change.finish) and Countdown.Match(change.selection, context) == true and change
    end
    for _, entry in ipairs(list or {}) do
        local change = applies(entry.change)
        local yields = false
        for _, other in ipairs(change and change.yields and list or {}) do
            if change.yields[other.change.id] and applies(other.change) then yields = true; break end
        end
        if change and not yields then return change end
    end
end

function Countdown.Resolve(display, context, result, origins, skip)
    result, origins = result or {}, origins or {}
    local settings, data = Countdown.GetSettings(), compiled()
    local own = settings.displays[display]
    for _, property in ipairs(properties) do
        result[property] = settings.shared.base[property]
        if own and own.base[property] ~= nil then result[property] = own.base[property] end
        origins[property] = nil
        local change = not (property == "glow" and display == "TextHighlight") and choose(data.changes[property], context, skip, display)
        if change then result[property], origins[property] = change.value, change end
    end
    local style = origins.format
    if style and style.precision ~= nil then result.precision = style.precision end
    if style and style.rounding then result.rounding = style.rounding end
    return result, origins
end

function Countdown.Format(remaining, style)
    if not finite(remaining) or remaining <= 0 then return "" end
    local precision = math.max(0, math.min(3, math.floor(tonumber(style.precision) or 0)))
    local mode, rounding = style.format or "seconds", style.rounding or "up"
    local function round(number)
        return rounding == "down" and math.floor(number) or rounding == "nearest" and math.floor(number + 0.5) or math.ceil(number)
    end
    if mode == "minutes" then return string.format(private.getLocalisation("CountdownMinutes"), round(remaining / 60)) end
    local factor = 10 ^ precision
    local scaled = remaining * factor
    -- only floating point noise at a whole display step is compensated
    local nearest = math.floor(scaled + 0.5)
    if nearest > 0 and math.abs(scaled - nearest) < 0.0000001 then scaled = nearest end
    local value = round(scaled) / factor
    local format = "%0." .. precision .. "f"
    if (mode == "clock" or mode == "units") and value >= 60 then
        local minutes = math.floor(value / 60)
        local seconds = string.format(format, value - minutes * 60)
        if mode == "units" then return string.format(private.getLocalisation("CountdownMinutesSeconds"), minutes, seconds) end
        if value - minutes * 60 < 10 then seconds = "0" .. seconds end
        return minutes .. ":" .. seconds
    end
    return string.format(format, value)
end

function Countdown.BaseColor(display)
    local style = private.GetElementStyle("Cooldown")
    return style.DisplayColors and style.DisplayColors[display] or style.Font.Color
end

function Countdown.ConfigureFont(region, display, spec)
    private.ThemeApply.Font(region, spec or private.GetElementStyle("Cooldown").Font)
    local path, size, flags = region:GetFont()
    local style = private.GetElementStyle("Cooldown")
    local own = style.DisplaySizes and style.DisplaySizes[display]
    size = own and own > 0 and own or size * (display == "BigIcon" and (style.BigIconScale or 2) or 1)
    region.atCountdownFont = { path = path, size = size, flags = flags }
    region.atCountdownSize = nil
end

function Countdown.Context(frame, remaining, info, state)
    if frame.countdownPreview then
        local context = frame.countdownPreview
        context.remaining = remaining
        if context.autoElapsed then context.elapsed = math.max(0, context.duration - remaining) end
        return context
    end
    frame.atCountdownContext = frame.atCountdownContext or {}
    return private.manager.GetCountdownContext(info and info.id, remaining, info, state, frame.atCountdownContext, compiled().required)
end

function Countdown.Apply(frame, region, display, remaining, info, state, ownGlow)
    local context = Countdown.Context(frame, remaining, info, state)
    state = state or context.state
    frame.atCountdownStyle, frame.atCountdownOrigins = Countdown.Resolve(display,
        context, frame.atCountdownStyle, frame.atCountdownOrigins)
    local style = frame.atCountdownStyle
    local text = state == private.manager.STATES.Queued and "" or Countdown.Format(remaining, style)
    if region.atCountdownText ~= text then region:SetText(text); region.atCountdownText = text end
    local font = region.atCountdownFont
    if font then
        local size = font.size * (tonumber(style.size) or 100) / 100
        if size ~= region.atCountdownSize then
            region:SetFont(font.path, size, font.flags)
            region.atCountdownSize = size
        end
    end
    local color = style.color or Countdown.BaseColor(display)
    region:SetTextColor(private.ThemeApply.Color(color))
    if ownGlow then
        frame.atCountdownGlow = nil
    elseif style.glow and remaining > 0 and state ~= private.manager.STATES.Queued and
        (not frame.countdownPreview or frame:IsVisible()) then
        local duration = remaining
        if state == private.manager.STATES.Paused then duration = nil end
        private.EnableGlow(frame, style.glow.type, duration, style.glow.color, style.glow.advanced and style.glow.options or nil)
        frame.atCountdownGlow = true
    elseif frame.atCountdownGlow then
        private.StopGlow(frame)
        frame.atCountdownGlow = nil
    end
    frame.atCountdownGeneration = generation
    return style
end

function Countdown.Reset(frame, region)
    frame.atCountdownStyle, frame.atCountdownOrigins, frame.atCountdownContext = nil, nil, nil
    frame.atCountdownGlow, frame.atCountdownGeneration, frame.countdownPreview = nil, nil, nil
    frame.atCountdownRemaining, frame.atSourceCountdownGlow = nil, nil
    region.atCountdownFont, region.atCountdownSize, region.atCountdownText = nil, nil, nil
end

Countdown.Generation = function() return generation end
