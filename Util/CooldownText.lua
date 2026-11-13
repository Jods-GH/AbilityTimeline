local appName, app = ...
---@class AbilityTimeline
local private = app
local issecretvalue = issecretvalue or function() return false end

private.CooldownText = {}
local Countdown = private.CooldownText
local properties = { "shown", "color", "size", "format", "precision", "rounding", "glow", "duration", "heartbeat" }
-- a time style change carries its decimals and rounding, so those have no lanes of their own
Countdown.Lanes = { "shown", "color", "size", "format", "glow", "duration", "heartbeat" }
Countdown.Displays = { "SpellIcon", "BigIcon", "TextHighlight" }
-- properties only some displays can show, all others apply to every display
Countdown.PropertyDisplays = { glow = { "SpellIcon", "BigIcon" }, duration = { "SpellIcon", "BigIcon" }, heartbeat = { "SpellIcon", "BigIcon" } }
-- the duration lane's styles, drawn by Util/DurationDisplay.lua, the swipe is the big icon's native cooldown spinner
Countdown.DurationStyles = { "none", "swipe", "bar", "border", "dial", "pips" }
-- a display's look while neither the shared nor its own base sets one
Countdown.DisplayDefaults = { BigIcon = { duration = "swipe" } }
local fields = { remaining = "number", elapsed = "number", duration = "number", source = "string", state = "number" }
local cache
local generation = 0
local items = setmetatable({}, { __mode = "k" })

function Countdown.DisplaysOf(property)
    return Countdown.PropertyDisplays[property] or Countdown.Displays
end

function Countdown.Supports(property, display)
    if display == "Shared" then return true end
    for _, shown in ipairs(Countdown.DisplaysOf(property)) do if shown == display then return true end end
    return false
end

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

---list defaults to the shared changes, a reminder's or boss timer rule's own changes are passed in
function Countdown.Add(property, start, value, list)
    local settings = Countdown.GetSettings()
    local id
    repeat
        id = (list and "item-" or "change-") .. settings.nextId
        settings.nextId = settings.nextId + 1
    until not Countdown.Find(id, list)
    local change = { id = id, property = property, start = start, value = value, priority = settings.nextId }
    table.insert(list or settings.shared.changes, change)
    return change
end

function Countdown.Find(id, list)
    for _, change in ipairs(list or Countdown.GetSettings().shared.changes) do if change.id == id then return change end end
end

---coincident edits of the same look replace the section instead of hiding a second priority behind it
function Countdown.Coalesce(change, list)
    local changes = list or Countdown.GetSettings().shared.changes
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
    if not change.displays then return #Countdown.DisplaysOf(change.property) end
    local count = 0
    for _ in pairs(change.displays) do count = count + 1 end
    return count
end

local function valid(change)
    return finite(change.start) and change.start > 0 and
        (change.finish == nil or finite(change.finish) and change.finish >= 0 and change.finish < change.start)
end

local function compile(changes)
    local data = { required = {}, changes = {} }
    for index, change in ipairs(changes) do
        if change.enabled ~= false and valid(change) then
            local property = change.property
            data.changes[property] = data.changes[property] or {}
            table.insert(data.changes[property], { change = change, index = index })
            requirements(change.selection, data.required)
        end
    end
    for _, list in pairs(data.changes) do
        table.sort(list, function(a, b)
            if a.change.start ~= b.change.start then return a.change.start < b.change.start end
            local ra, rb = reach(a.change), reach(b.change)
            if ra ~= rb then return ra < rb end
            local pa, pb = a.change.priority or a.index, b.change.priority or b.index
            return pa > pb
        end)
    end
    return data
end

local function compiled()
    local settings = Countdown.GetSettings()
    if cache and cache.settings == settings then return cache end
    cache = compile(settings.shared.changes)
    cache.settings = settings
    return cache
end

---a reminder's or boss timer rule's own changes, rebuilt whenever the changes are invalidated
local function itemCompiled(changes)
    local data = items[changes]
    if data and data.generation == generation then return data end
    data = compile(changes)
    data.generation = generation
    items[changes] = data
    return data
end

local needsElapsed = { elapsed = true }

---what a timer's context has to look up for the shared sections and, with info, its own sections and glow
function Countdown.Required(info)
    local shared = compiled().required
    if shared.elapsed or not info then return shared end
    if info.glowSelection or info.countdownChanges and itemCompiled(info.countdownChanges).required.elapsed then
        return needsElapsed
    end
    return shared
end

---an imported timer selection, kept only when it is valid; JSON turns the numeric keys of a timer state set into
---strings, they become numbers again
function Countdown.CleanSelection(selection)
    if type(selection) ~= "table" then return end
    local function clean(node)
        if type(node) ~= "table" then return false end
        if node.kind == "not" then return clean(node.child) end
        if node.kind == "all" or node.kind == "any" then
            if type(node.children) ~= "table" then return false end
            for _, child in ipairs(node.children) do if not clean(child) then return false end end
            return true
        end
        if node.kind ~= "test" or not fields[node.field] then return false end
        if node.any then return true end
        if node.values ~= nil then
            if type(node.values) ~= "table" or node.field ~= "state" and node.field ~= "source" then return false end
            local values = {}
            for key, checked in pairs(node.values) do
                if node.field == "state" then key = tonumber(key) end
                if type(key) ~= fields[node.field] or type(checked) ~= "boolean" then return false end
                values[key] = checked
            end
            node.values = values
            return node.op == "is" or node.op == "isNot"
        end
        if type(node.value) ~= fields[node.field] then return false end
        if node.op == "is" or node.op == "isNot" then return true end
        return fields[node.field] == "number" and
            (node.op == "less" or node.op == "atMost" or node.op == "greater" or node.op == "atLeast" or node.op == "between")
    end
    if clean(selection) and private.CountdownSelection.Valid(selection) then return selection end
end

---keeps the valid changes of an imported reminder or boss timer rule, with their timer selections like the shared ones
local styles = {}
for _, style in ipairs(Countdown.DurationStyles) do styles[style] = true end
local function colorValue(value)
    return type(value) == "table" and finite(value.r) and finite(value.g) and finite(value.b) and
        (value.a == nil or finite(value.a))
end

local values = {
    shown = function(value) return type(value) == "boolean" end,
    color = colorValue,
    size = function(value) return finite(value) and value > 0 end,
    format = function(value) return value == "minutes" or value == "clock" or value == "seconds" or value == "units" end,
    glow = function(value)
        if value == false then return true end
        if type(value) ~= "table" or not private.GlowTypes[value.type] or value.color ~= nil and not colorValue(value.color) then return false end
        if value.options ~= nil then
            if type(value.options) ~= "table" then return false end
            for key, option in pairs(value.options) do
                if key == "border" or key == "startAnim" then
                    if type(option) ~= "boolean" then return false end
                elseif not finite(option) then return false end
            end
        end
        return true
    end,
    duration = function(value) return styles[value] == true end,
    heartbeat = function(value)
        return value == false or type(value) == "table" and (value.color == nil or colorValue(value.color))
    end,
}

function Countdown.CleanChanges(changes)
    if type(changes) ~= "table" then return end
    local clean = {}
    for _, change in ipairs(changes) do
        if type(change) == "table" and values[change.property] and values[change.property](change.value) and valid(change) and
            (change.displays == nil or type(change.displays) == "table") then
            local selection = Countdown.CleanSelection(change.selection)
            if change.selection == nil or selection then
                change.selection = selection
                change.advanced = selection ~= nil or nil
                if not finite(change.priority) then change.priority = nil end
                if type(change.yields) ~= "table" then change.yields = nil end
                if type(change.id) ~= "string" then change.id = "item-import-" .. (#clean + 1) end
                table.insert(clean, change)
            end
        end
    end
    if #clean > 0 then return clean end
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

---whether a shown section forces a display on or off at the context's time, nil keeps its own threshold
-- the displays of a countdown by the keys a reminder's or boss timer rule's "Shows on" uses
Countdown.DisplayKeys = { SpellIcon = "timeline", BigIcon = "bigIcon", TextHighlight = "textHighlight" }
local glowBases = setmetatable({}, { __mode = "k" })

---a reminder's or boss timer rule's own look under its own sections: "Shows on" is the base of its shown lane, its
---glow the base of its glow lane: always, only below the big icon threshold ("close") or while its own timer selection
---matches (glowSelection, false for any timer)
---@param info table -- the event info, or the editor's stand-in for it: allowedDisplays, glow, glowColor, glowAlways,
---glowSelection
local function itemBase(info, property, display, context)
    if property == "shown" then
        local allowed = info.allowedDisplays
        if allowed and allowed[Countdown.DisplayKeys[display]] == false then return false end
    elseif property == "glow" and info.glow and (info.glowAlways or
        info.glowSelection ~= nil and (info.glowSelection == false or Countdown.Match(info.glowSelection, context) == true) or
        info.glowSelection == nil and context.remaining <= private.db.profile.big_icon_settings.threshold_time) then
        local glow = glowBases[info] or {}
        glow.type, glow.color = info.glow, info.glowColor
        glowBases[info] = glow
        return glow
    end
end

---the item's sections first, then its own look, then the shared sections
local function chooseFor(property, display, context, skip, item)
    local change = item and choose(item.changes[property], context, skip, display)
    if change then return change.value, change end
    if context.item and finite(context.remaining) then
        local value = itemBase(context.item, property, display, context)
        if value ~= nil then return value end
    end
    change = choose(compiled().changes[property], context, skip, display)
    if change then return change.value, change end
end

---whether a shown section or "Shows on" forces a display on or off at the context's time, nil keeps its threshold
function Countdown.Shown(display, context)
    return (chooseFor("shown", display, context, nil, context.changes and itemCompiled(context.changes)))
end

---whether anything could turn a display on or off for an event, the manager skips the lookup otherwise
function Countdown.HasShown(info)
    return compiled().changes.shown ~= nil or info.allowedDisplays ~= nil or
        info.countdownChanges ~= nil and itemCompiled(info.countdownChanges).changes.shown ~= nil
end

function Countdown.Resolve(display, context, result, origins, skip)
    result, origins = result or {}, origins or {}
    local settings = Countdown.GetSettings()
    local own = settings.displays[display]
    local item = context.changes and itemCompiled(context.changes)
    for _, property in ipairs(properties) do
        result[property] = settings.shared.base[property]
        if own and own.base[property] ~= nil then result[property] = own.base[property] end
        if result[property] == nil and Countdown.DisplayDefaults[display] then result[property] = Countdown.DisplayDefaults[display][property] end
        origins[property] = nil
        if Countdown.Supports(property, display) then
            local value, change = chooseFor(property, display, context, skip, item)
            if value ~= nil then result[property], origins[property] = value, change end
        end
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
    return private.manager.GetCountdownContext(info and info.id, remaining, info, state, frame.atCountdownContext, Countdown.Required(info))
end

function Countdown.Apply(frame, region, display, remaining, info, state)
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
    if style.glow and remaining > 0 and state ~= private.manager.STATES.Queued and
        (not frame.countdownPreview or frame:IsVisible()) then
        local duration = remaining
        if state == private.manager.STATES.Paused then duration = nil end
        private.EnableGlow(frame, style.glow.type, duration, style.glow.color, style.glow.advanced and style.glow.options or nil)
        frame.atCountdownGlow = true
    elseif frame.atCountdownGlow then
        private.StopGlow(frame)
        frame.atCountdownGlow = nil
    end
    if frame.DurationLayer then
        private.ThemeApply.UpdateDuration(frame, display, style, frame.atCountdownOrigins, remaining, state, region)
    end
    -- the manager hides live displays, a settings preview only dims while a shown section hides it
    if frame.countdownPreview then
        local dimmed = style.shown == false
        if frame.atShownDimmed ~= dimmed then
            frame:SetAlpha(dimmed and 0.35 or 1)
            frame.atShownDimmed = dimmed
        end
    end
    frame.atCountdownGeneration = generation
    return style
end

function Countdown.Reset(frame, region)
    frame.atCountdownStyle, frame.atCountdownOrigins, frame.atCountdownContext = nil, nil, nil
    frame.atCountdownGlow, frame.atCountdownGeneration, frame.countdownPreview = nil, nil, nil
    frame.atCountdownRemaining = nil
    if frame.atShownDimmed then frame:SetAlpha(1) end
    frame.atShownDimmed = nil
    private.ThemeApply.ResetDuration(frame)
    region.atCountdownFont, region.atCountdownSize, region.atCountdownText = nil, nil, nil
end

Countdown.Generation = function() return generation end
