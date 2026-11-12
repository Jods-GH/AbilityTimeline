local appName, app = ...
---@class AbilityTimeline
local private = app
local AceGUI = LibStub("AceGUI-3.0")
local Countdown = private.CooldownText
local L = private.getLocalisation
local Selection = {}
private.CountdownSelection = Selection

function Selection.NewCase()
    return { kind = "all", children = {
        { kind = "test", field = "source", any = true },
        { kind = "test", field = "state", any = true },
    } }
end

function Selection.TimePhrase(test)
    if not test or test.any then return "any" end
    if test.op == "less" or test.op == "atMost" then return "upto" end
    if test.op == "greater" or test.op == "atLeast" then return "least" end
    return "between"
end

function Selection.SetTimePhrase(test, phrase)
    if phrase == "any" then
        test.any, test.value, test.upper, test.op = true, nil, nil, nil
        return
    end
    local previous = Selection.TimePhrase(test)
    if previous == phrase then return end
    local low = (previous == "upto" or previous == "any") and 0 or test.value or 0
    local high = previous == "upto" and test.value or previous == "between" and (test.upper or test.value) or nil
    test.any = nil
    if phrase == "upto" then test.op, test.value = "atMost", high or math.max(30, low)
    elseif phrase == "least" then test.op, test.value = "atLeast", low > 0 and low or 30
    else
        test.op = "between"
        test.value = low > 0 and low or 20
        test.upper = math.max(test.value, high or math.max(45, test.value + 20))
    end
end

function Selection.TimeSummary(test)
    if not test or test.any then return L("CountdownAny") end
    if test.op == "between" and test.value ~= test.upper then
        return string.format(L("CountdownTimeBetweenValue"), test.value or 0, test.upper or test.value or 0)
    end
    local key = ({ less = "CountdownTimeUnderValue", atMost = "CountdownTimeUpToValue", greater = "CountdownTimeOverValue",
        atLeast = "CountdownTimeAtLeastValue", between = "CountdownTimeExactValue" })[test.op]
    return string.format(L(key), test.value or 0)
end

function Selection.Valid(node)
    if not node then return true end
    if node.kind == "not" then return Selection.Valid(node.child) end
    if node.children then
        if node.kind == "any" and #node.children == 0 then return false end
        for _, child in ipairs(node.children) do if not Selection.Valid(child) then return false end end
        return true
    end
    if node.any then return true end
    if node.field == "source" or node.field == "state" then
        if node.values then
            for _, checked in pairs(node.values) do if checked == true then return true end end
            return false
        end
        return node.value ~= nil
    end
    return Countdown.IsFinite(node.value) and node.value >= 0 and
        (node.op ~= "between" or Countdown.IsFinite(node.upper) and node.upper >= node.value)
end

---a saved selection is all{ any{ cards }, not{ card }... }, without the any node every timer is included
function Selection.Parse(node)
    local include, except, all = {}, {}, true
    if node and node.kind == "all" then
        for _, child in ipairs(node.children) do
            if child.kind == "any" then
                all = false
                for _, card in ipairs(child.children) do include[#include + 1] = private.DeepCopy(card) end
            elseif child.kind == "not" then except[#except + 1] = private.DeepCopy(child.child) end
        end
    end
    return all, include, except
end

local function strip(card)
    local result = { kind = "all", children = {} }
    for _, test in ipairs(card.children) do
        if not test.any then table.insert(result.children, private.DeepCopy(test)) end
    end
    return result
end

local function restricts(card)
    for _, test in ipairs(card.children) do if not test.any then return true end end
    return false
end

local Session = {}
Session.__index = Session

function Selection.New(node)
    local _, include, except = Selection.Parse(node)
    local session = setmetatable({ include = include, except = except }, Session)
    session.initial = session:Value()
    return session
end

function Session:Value()
    if #self.include == 0 and #self.except == 0 then return nil end
    local root = { kind = "all", children = {} }
    if #self.include > 0 then
        local cards = { kind = "any", children = {} }
        for _, card in ipairs(self.include) do table.insert(cards.children, strip(card)) end
        table.insert(root.children, cards)
    end
    for _, card in ipairs(self.except) do table.insert(root.children, { kind = "not", child = strip(card) }) end
    return root
end

function Session:Changed()
    return not Countdown.Same(self.initial, self:Value())
end

function Session:Valid()
    for _, list in ipairs({ self.include, self.except }) do
        for _, card in ipairs(list) do if not restricts(card) or not Selection.Valid(card) then return false end end
    end
    return true
end

function Session:Edit(list, index)
    self.editing = { list = list, index = index, checkpoint = private.DeepCopy(self[list][index]) }
end

function Session:Add(list)
    table.insert(self[list], Selection.NewCase())
    self.editing = { list = list, index = #self[list], added = true, section = "source" }
end

function Session:Close(save)
    local current = self.editing
    if not save then
        if current.added then table.remove(self[current.list], current.index)
        else self[current.list][current.index] = current.checkpoint end
    end
    self.editing, self.error = nil, nil
end

function Session:Remove(list, index)
    table.remove(self[list], index)
    self.editing, self.error = nil, nil
end

local function limits(node, into)
    if not node then return end
    if into[node.field] and not node.any then
        if Countdown.IsFinite(node.value) then table.insert(into[node.field], node.value) end
        if Countdown.IsFinite(node.upper) then table.insert(into[node.field], node.upper) end
    end
    if node.child then limits(node.child, into) end
    for _, child in ipairs(node.children or {}) do limits(child, into) end
end

local function samples(values, minimum, maximum)
    local unique, result = {}, {}
    values[#values + 1] = minimum
    if maximum then values[#values + 1] = maximum end
    table.sort(values)
    for _, value in ipairs(values) do
        if value >= minimum and (not maximum or value <= maximum) and not unique[value] then
            unique[value] = true
            local previous = result[#result]
            if previous and previous < value then result[#result + 1] = previous + (value - previous) / 2 end
            result[#result + 1] = value
        end
    end
    if not maximum then
        local last = result[#result]
        result[#result + 1] = last + math.max(1, math.abs(last) * 0.1)
    end
    return result
end

---a timer that matches node at remaining, its elapsed is always duration - remaining
function Selection.Example(node, remaining, preferredDuration)
    local bounds = { duration = {}, elapsed = {}, remaining = {} }
    limits(node, bounds)
    local preferred = math.max(remaining, preferredDuration or remaining)
    local durations = { preferred }
    for _, value in ipairs(bounds.duration) do durations[#durations + 1] = value end
    for _, value in ipairs(bounds.elapsed) do durations[#durations + 1] = remaining + value end
    local candidates = samples(durations, remaining)
    table.insert(candidates, 1, preferred)
    for _, source in ipairs({ "Addon", "EncounterTimeline", "BigWigs", "DBM", "Reminder", "ReadyCheck", "PullTimer", "BreakTimer", "KeyReroll" }) do
        for _, timerState in ipairs({ 0, 1, 4 }) do
            local context = { source = source, state = timerState, remaining = remaining }
            for _, duration in ipairs(candidates) do
                context.duration, context.elapsed = duration, duration - remaining
                if Countdown.Match(node, context) == true then return context end
            end
        end
    end
end

---the numeric filters split remaining into intervals that match all or nothing, so one sample of each is tried
function Selection.ExampleInRange(node, minimum, maximum, preferredDuration)
    local bounds = { duration = { 0 }, elapsed = { 0 }, remaining = {} }
    limits(node, bounds)
    for _, duration in ipairs(bounds.duration) do
        for _, elapsed in ipairs(bounds.elapsed) do bounds.remaining[#bounds.remaining + 1] = duration - elapsed end
    end
    for _, remaining in ipairs(samples(bounds.remaining, minimum, maximum)) do
        if remaining > minimum and remaining <= maximum then
            local example = Selection.Example(node, remaining, preferredDuration)
            if example then return example end
        end
    end
end

function Selection.Intersects(a, b, minimum, maximum)
    local node = { kind = "all", children = {} }
    if a then table.insert(node.children, a) end
    if b then table.insert(node.children, b) end
    return Selection.ExampleInRange(node, minimum, maximum) ~= nil
end

function Session:Render(parent, editor, ui)
    local function changed() self.error, self.conflicts = nil, nil; ui.Refresh() end
    local current = self.editing
    -- the sections the tour points at
    self.parts = {}
    local canvas = AceGUI:Create("AtCountdownLayout")
    canvas:PauseLayout()
    canvas:Configure("stack", 10)
    parent:AddChild(canvas)
    parent = canvas
    local function inside(left, right, top, bottom, callback, title, style)
        local outer = parent
        local group = AceGUI:Create("AtCountdownLayout")
        group:PauseLayout()
        group:Configure("stack", 8, left, right, top, bottom)
        if title then group:SetSection(title, style) end
        outer:AddChild(group)
        parent = group
        callback()
        parent = outer
        group:ResumeLayout()
        group:DoLayout()
        return group.frame
    end
    if not current then
        local function cards(list)
            for index, node in ipairs(self[list]) do
                if index > 1 then ui.Note(parent, L("CountdownOr")) end
                local widget = AceGUI:Create("AtCountdownSituation")
                widget:SetSummary(ui.Card(node))
                widget:SetCallback("OnEdit", function() self:Edit(list, index); ui.Tour("ruleKind"); changed() end)
                widget:SetCallback("OnRemove", function() self:Remove(list, index); changed() end)
                parent:AddChild(widget)
            end
            local add = list == "except" and "CountdownAddException" or #self.include > 0 and "CountdownAddKind" or "CountdownAddFirstKind"
            local button = ui.Action(parent, L(add), function() self:Add(list); ui.Tour("ruleKind"); changed() end)
            if list == "include" then self.parts.add = button.frame end
        end
        editor:SetTitle(L("CountdownSelectTimersTitle"), ui.Scope)
        self.parts.include = inside(0, 0, 0, 0, function()
            if #self.include == 0 then ui.Note(parent, L("CountdownAddKindHint")) end
            cards("include")
        end, L("CountdownUseFor"), "plain")
        self.parts.except = inside(0, 0, 0, 0, function() cards("except") end, L("CountdownButNotFor"), "section")
        self.parts.apply = editor.frame.Done
        if self.error then ui.Note(parent, self.error)
        elseif self:Valid() and not ui.Matches(self:Value()) then ui.Note(parent, L("CountdownNothingMatches")) end
        if self.conflicts then
            ui.Note(parent, L("CountdownOverlap"))
            ui.Action(parent, L("CountdownUseNewLook"), function() ui.Apply(true) end)
            ui.Action(parent, L("CountdownKeepLook"), function() ui.Apply(false) end)
        end
        editor:SetActions({
            Done = { text = L("CountdownApplyTimers"), disabled = not self:Valid(), tooltip = L("CountdownInvalidSelection"),
                callback = function() ui.Apply() end },
            Copy = { text = L("CountdownCancel"), callback = ui.Cancel },
        })
        canvas:ResumeLayout()
        canvas:DoLayout()
        return
    end

    local node = self[current.list][current.index]
    editor:SetTitle(L(current.list == "except" and "CountdownButNotFor" or "CountdownUseFor"), ui.Card(node))
    local function choices(items, mode)
        local group = AceGUI:Create("AtCountdownLayout")
        group:PauseLayout()
        group:Configure(mode and "wrap" or "grid", 6)
        for index, item in ipairs(items) do
            local control = AceGUI:Create("AtCountdownChoice")
            control:SetText(item.text)
            control:SetSelected(item.selected)
            if item.diagram then control:SetDiagram(item.diagram[1], item.diagram[2]) end
            control:SetUserData("grow", mode == "state")
            if not mode and #items % 2 == 1 and index == #items then control:SetFullWidth(true) end
            control:SetCallback("OnClick", item.callback)
            if item.value == "between" then self.parts.between = control.frame end
            group:AddChild(control)
        end
        parent:AddChild(group)
        group:ResumeLayout()
        group:DoLayout()
    end
    local function summary(title, value, expanded, callback, section)
        local widget = AceGUI:Create("AtCountdownSummary")
        widget:SetSummary(title, value, expanded)
        widget:SetStep(({ source = 1, state = 2, timing = 3 })[section])
        widget:SetCallback("OnEdit", callback)
        parent:AddChild(widget)
        return widget.frame
    end
    local parts = {}
    for _, test in ipairs(node.children) do parts[test.field] = test end
    local function editable(field)
        if not parts[field] then
            parts[field] = { kind = "test", field = field, any = true }
            table.insert(node.children, parts[field])
        end
        return parts[field]
    end
    local function facet(field)
        local test = parts[field]
        local values = field == "source" and ui.Sources or ui.States
        local order = field == "source" and { "EncounterTimeline", "BigWigs", "DBM", "Reminder", "ReadyCheck", "PullTimer", "BreakTimer", "KeyReroll" } or { 0, 1, 4 }
        ui.Note(parent, L(field == "source" and "CountdownCanvasSourceQuestion" or "CountdownCanvasStateQuestion"))
        local items = {{ text = L(field == "source" and "CountdownCanvasAnySource" or "CountdownCanvasAnyState"), value = "any", selected = not test or test.any == true,
            callback = function()
                local target = editable(field)
                target.any, target.values, target.value, target.op = true, nil, nil, nil
                changed()
            end }}
        for _, key in ipairs(order) do
            local checked = test and not test.any and test.values and test.values[key] == true
            items[#items + 1] = { text = values[key], value = key, selected = checked == true, callback = function()
                local target = editable(field)
                if target.any then target.values, target.op = {}, "is" end
                target.any = nil
                target.values[key] = target.values[key] ~= true or nil
                if not next(target.values) then target.any, target.values, target.op = true, nil, nil end
                changed()
            end }
        end
        choices(items, field)
    end
    local timeNames = { duration = L("CountdownTimeDuration"), elapsed = L("CountdownTimeElapsed"), remaining = L("CountdownTimeRemaining") }
    local function timing(field)
        local test = parts[field]
        local phrase = Selection.TimePhrase(test)
        ui.Note(parent, L(({ duration = "CountdownTimeDurationHint", elapsed = "CountdownTimeElapsedHint", remaining = "CountdownTimeRemainingHint" })[field]))
        local captions = { any = L("CountdownTimeAny"), upto = L("CountdownTimeUpTo"), least = L("CountdownTimeAtLeast"), between = L("CountdownTimeBetween") }
        local items = {}
        for _, value in ipairs({ "any", "upto", "least", "between" }) do
            items[#items + 1] = { text = captions[value], value = value, selected = phrase == value,
                diagram = ({ any = { 0, 1 }, upto = { 0, 0.45 }, least = { 0.45, 1 }, between = { 0.25, 0.75 } })[value], callback = function()
                Selection.SetTimePhrase(editable(field), value)
                if value == "between" then ui.Tour("ruleBetween") end
                changed()
            end }
        end
        choices(items)
        if phrase ~= "any" then ui.TimeValues(parent, test, changed) end
    end
    local times = {}
    for _, field in ipairs({ "duration", "elapsed", "remaining" }) do
        if parts[field] and not parts[field].any then times[#times + 1] = timeNames[field] .. ": " .. Selection.TimeSummary(parts[field]) end
    end
    for _, section in ipairs({ "source", "state", "timing" }) do
        local value
        if section == "timing" then value = #times > 0 and table.concat(times, L("CountdownFilterJoin")) or L("CountdownTimeAny")
        elseif not parts[section] or parts[section].any then value = L(section == "source" and "CountdownCanvasAnySource" or "CountdownCanvasAnyState")
        else value = ui.Names(parts[section]) end
        self.parts[section] = { summary(L(({ source = "CountdownCanvasSource", state = "CountdownCanvasState", timing = "CountdownCanvasTiming" })[section]), value, current.section == section,
            function() current.section = current.section ~= section and section or nil; changed() end, section) }
        if current.section == section then
            self.parts[section][2] = inside(24, 0, 0, 4, function()
                if section == "timing" then
                    for _, field in ipairs({ "duration", "elapsed", "remaining" }) do
                        local row = summary(timeNames[field], Selection.TimeSummary(parts[field]), current.timing == field,
                            function() current.timing = current.timing ~= field and field or nil; changed() end)
                        if current.timing == field then self.parts.range = { row, inside(8, 8, 4, 8, function() timing(field) end) } end
                    end
                else facet(section) end
            end)
        end
    end

    local filled = Selection.Valid(node)
    if self.error or not filled then ui.Note(parent, self.error or L("CountdownInvalidSelection")) end
    editor:SetActions({
        Done = { text = L("CountdownSaveFilters"), disabled = not filled or not restricts(node),
            tooltip = L(restricts(node) and "CountdownInvalidSelection" or "CountdownNothingPicked"), callback = function() self:Close(true); ui.Tour("ruleKindClosed"); changed() end },
        Copy = { text = L("CountdownCancel"), callback = function() self:Close(false); ui.Tour("ruleKindClosed"); changed() end },
        Remove = not current.added and { text = L("CountdownRemove"), callback = function() self:Remove(current.list, current.index); ui.Tour("ruleKindClosed"); changed() end } or nil,
    })
    self.parts.close = { editor.frame.Done, editor.frame.Copy, editor.frame.Remove }
    canvas:ResumeLayout()
    canvas:DoLayout()
end
