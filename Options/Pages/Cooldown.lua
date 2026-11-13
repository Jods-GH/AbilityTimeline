local appName, app = ...
---@class AbilityTimeline
local private = app
local AceGUI = LibStub("AceGUI-3.0")
local Countdown = private.CooldownText
local Selection = private.CountdownSelection
local L = private.getLocalisation
local settingsText = private.DisplaySettingsText

local function words(keys)
    local values = {}
    for key, text in pairs(keys) do values[key] = L(text) end
    return values
end

local propertyNames = words({ color = "CountdownTextColor", size = "CountdownTextSize", format = "CountdownTimeStyle",
    precision = "CountdownDecimals", rounding = "CountdownRounding", glow = "CountdownGlow", duration = "CountdownDuration",
    heartbeat = "CountdownHeartbeat", shown = "CountdownShown" })
local shownNames = words({ auto = "CountdownShownAuto", show = "CountdownShownShow", hide = "CountdownShownHide" })
local durationNames = words({ none = "CountdownDurationNone", swipe = "CountdownDurationSwipe", bar = "CountdownDurationBar", border = "CountdownDurationBorder",
    dial = "CountdownDurationDial", pips = "CountdownDurationPips" })
-- what a section of a lane without a look of its own starts with
local newValues = { duration = "bar", heartbeat = {}, shown = false }
local formats = words({ minutes = "CountdownFormatMinutes", clock = "CountdownFormatClock",
    seconds = "CountdownFormatSeconds", units = "CountdownFormatUnits" })
local roundingNames = words({ up = "CountdownRoundUp", nearest = "CountdownRoundNearest", down = "CountdownRoundDown" })
local precisionNames = words({ [0] = "CountdownWhole", [1] = "CountdownTenths", [2] = "CountdownHundredths", [3] = "CountdownThousandths" })
local sources = words({ EncounterTimeline = "CountdownSourceBlizzard", BigWigs = "CountdownSourceBigWigs", DBM = "CountdownSourceDBM",
    Reminder = "CountdownSourceReminder", ReadyCheck = "ReadyCheck", PullTimer = "PullTimer", BreakTimer = "BreakTimer", KeyReroll = "CountdownSourceReroll" })
local timerStates = words({ [0] = "CountdownStateActive", [1] = "CountdownStatePaused", [4] = "CountdownStateQueued" })
local stateWords = words({ [0] = "CountdownSentenceActive", [1] = "CountdownSentencePaused", [4] = "CountdownSentenceQueued" })
local scopes = { Shared = L("CountdownAllDisplays"), SpellIcon = L("SettingsPageSpellIcons"), BigIcon = L("SettingsPageBigIcon"), TextHighlight = L("SettingsPageTextHighlight") }
-- lanes whose unchanged look has its own editor, clicking any other lane's base adds a change there
local editableBase = { color = true, size = true, format = true, duration = true }

local function label(property, value)
    if value == nil then return propertyNames[property] end
    if property == "format" then return formats[value] end
    if property == "precision" then return precisionNames[value] end
    if property == "rounding" then return roundingNames[value] end
    if property == "size" then return string.format(L("CountdownSizeValue"), value) end
    if property == "glow" then return value and value.type or L("CountdownNoGlow") end
    if property == "duration" then return durationNames[value or "none"] end
    if property == "heartbeat" then return L(value and "CountdownHeartbeatOn" or "CountdownHeartbeatOff") end
    -- "auto" is the lanes' name for a shown lane without a section, the display keeps its own threshold
    if property == "shown" then return shownNames[value == true and "show" or value == false and "hide" or "auto"] end
    return ""
end

local FOREVER = 3600

---the latest moment any card allows, advanced changes take their start from their cards
local function envelope(selection)
    local _, include = Selection.Parse(selection)
    local start = 0
    for _, card in ipairs(include) do
        local limit = FOREVER
        for _, test in ipairs(card.children) do
            if test.field == "remaining" and not test.any then
                if test.op == "atMost" or test.op == "less" then limit = test.value
                elseif test.op == "between" then limit = test.upper end
            end
        end
        start = math.max(start, limit)
    end
    return #include > 0 and start or FOREVER
end

local function onlyTiming(selection)
    local _, include, except = Selection.Parse(selection)
    if #except > 0 or #include > 1 then return false end
    for _, test in ipairs(include[1] and include[1].children or {}) do
        if test.field ~= "remaining" then return false end
    end
    return true
end

local function setMode(change, advanced)
    if advanced then
        local test = { kind = "test", field = "remaining", op = change.exclusiveStart and "less" or "atMost", value = change.start }
        if change.finish then test.op, test.value, test.upper = "between", change.finish, change.start end
        change.selection = { kind = "all", children = { { kind = "any", children = { { kind = "all", children = { test } } } } } }
        change.advanced, change.finish, change.exclusiveStart = true, nil, nil
    else
        local start = envelope(change.selection)
        change.start = start < FOREVER and start or 5
        change.advanced, change.selection, change.yields = nil, nil, nil
    end
end

local function heading(parent, text)
    local widget = AceGUI:Create("AtSettingHeading")
    widget:SetText(settingsText(text))
    parent:AddChild(widget)
end

local function note(parent, text)
    local widget = AceGUI:Create("Label")
    widget:SetFullWidth(true)
    widget:SetText(settingsText(text))
    private.ThemeApply.FontRole(widget.label, "Muted")
    parent:AddChild(widget)
end

local function namesText(test, values)
    local parts = {}
    for key, checked in pairs(test.values or {}) do if checked then table.insert(parts, values[key] or tostring(key)) end end
    table.sort(parts)
    if #parts == 0 then return L("CountdownNoTimersSelected") end
    return table.concat(parts, L("CountdownOrJoin"))
end

local function cardText(card)
    local parts, subject = {}, L("CountdownSentenceAny")
    for _, field in ipairs({ "source", "state", "duration", "elapsed", "remaining" }) do
        for _, test in ipairs(card.children) do
            if test.field == field and not test.any then
                if field == "source" then subject = string.format(L("CountdownSentenceFrom"), namesText(test, sources))
                elseif field == "state" then table.insert(parts, string.format(L("CountdownSentenceWhile"), namesText(test, stateWords)))
                elseif test.op == "between" then table.insert(parts, string.format(L("CountdownBetweenSummary"), L("CountdownField" .. field), test.value or 0, test.upper or test.value or 0))
                else table.insert(parts, string.format(L("CountdownLimitSummary"), L("CountdownField" .. field), L("CountdownOp" .. test.op), test.value or 0)) end
            end
        end
    end
    table.insert(parts, 1, subject)
    return table.concat(parts, L("CountdownSentenceJoin"))
end

local function cardsText(cards)
    local parts = {}
    for _, card in ipairs(cards) do table.insert(parts, cardText(card)) end
    return table.concat(parts, L("CountdownSentenceOr"))
end

local function selectionText(node)
    local all, include, except = Selection.Parse(node)
    local text = all and L("CountdownAllTimers") or #include > 0 and cardsText(include) or L("CountdownNoTimersSelected")
    if #except == 0 then return text end
    return string.format(L("CountdownSentenceButNot"), text, cardsText(except))
end

local function timeSelection(change)
    return { kind = "all", children = {
        { kind = "test", field = "remaining", op = change.exclusiveStart and "less" or "atMost", value = change.start },
        { kind = "test", field = "remaining", op = "greater", value = change.finish or 0 },
        private.DeepCopy(change.selection),
    } }
end

local function sharesDisplay(a, b)
    for _, display in ipairs(Countdown.Displays) do
        if (not a.displays or a.displays[display]) and (not b.displays or b.displays[display]) then return true end
    end
end

-- where each display sits in the combined preview: its top edge and the height it is scaled to
local slots = { SpellIcon = { y = 0, height = 36 }, BigIcon = { y = 50, height = 50 }, TextHighlight = { y = 128, height = 22 } }

-- LibCustomGlow parameters per glow type with the library's own defaults
local glowOptions = {
    PIXEL = {
        { key = "lines", text = "CountdownGlowLines", default = 8, minimum = 1, maximum = 32 },
        { key = "frequency", text = "CountdownGlowSpeed", default = 0.25, minimum = -5, maximum = 5 },
        { key = "length", text = "CountdownGlowLength", default = 0, maximum = 200, zeroIsAuto = true },
        { key = "thickness", text = "CountdownGlowThickness", default = 1, minimum = 1, maximum = 20 },
        { key = "xOffset", text = "CountdownGlowXOffset", default = 0, minimum = -100, maximum = 100 },
        { key = "yOffset", text = "CountdownGlowYOffset", default = 0, minimum = -100, maximum = 100 },
        { key = "border", text = "CountdownGlowBorder", default = true },
    },
    AUTOCAST = {
        { key = "lines", text = "CountdownGlowParticles", default = 4, minimum = 1, maximum = 16 },
        { key = "frequency", text = "CountdownGlowSpeed", default = 0.125, minimum = -5, maximum = 5 },
        { key = "scale", text = "CountdownGlowScale", default = 1, minimum = 0.1, maximum = 5 },
        { key = "xOffset", text = "CountdownGlowXOffset", default = 0, minimum = -100, maximum = 100 },
        { key = "yOffset", text = "CountdownGlowYOffset", default = 0, minimum = -100, maximum = 100 },
    },
    BUTTON = {
        { key = "frequency", text = "CountdownGlowSpeed", default = 0.25, minimum = 0.01, maximum = 5 },
    },
    PROC = {
        { key = "startAnim", text = "CountdownGlowStartAnim", default = true },
        { key = "duration", text = "CountdownGlowDuration", default = 1, minimum = 0.1, maximum = 10 },
        { key = "xOffset", text = "CountdownGlowXOffset", default = 0, minimum = -100, maximum = 100 },
        { key = "yOffset", text = "CountdownGlowYOffset", default = 0, minimum = -100, maximum = 100 },
    },
}

local function section(parent, title, style, callback)
    local group = AceGUI:Create("AtCountdownLayout")
    group:PauseLayout()
    group:Configure("stack", 8, 0, 0, 0, 6)
    group:SetSection(title, style)
    parent:AddChild(group)
    callback(group)
    group:ResumeLayout()
    group:DoLayout()
    return group.frame
end

local function chip(text, isSelected, callback)
    local control = AceGUI:Create("AtCountdownChoice")
    control:SetText(text)
    control:SetSelected(isSelected)
    control:SetCallback("OnClick", callback)
    return control
end

---a timer selection's summary beside the button that edits it, returns the button's frame
local function selectionLine(parent, selection, onEdit)
    local line = AceGUI:Create("AtCountdownLayout")
    line:PauseLayout()
    line:Configure("grid", 10)
    local summary = AceGUI:Create("Label")
    summary:SetText(selectionText(selection))
    private.ThemeApply.FontRole(summary.label, "Muted")
    line:AddChild(summary)
    local edit = AceGUI:Create("AtButton")
    edit:SetText(L("CountdownChooseTimers"))
    edit:SetCallback("OnClick", onEdit)
    line:AddChild(edit)
    parent:AddChild(line)
    line:ResumeLayout()
    line:DoLayout()
    return edit.frame
end

---one lane editor: the Cooldown changes page edits the shared lanes, a reminder or boss timer rule its own
---target: Changes(), Commit(), Rebuild(), Owner(), and for an item: item, Inherited, source, zoom
local function Session(target)
    local state = { scope = "Shared", remaining = target.zoom or 10, zoom = target.zoom or 10, viewEnd = 0, loop = 0, source = target.source or "Addon", timerState = 0 }
    local previews, laneWidget = {}, nil
    local editor, chooser
    -- the sections of the rule window the tour points at, and the event it waits for until the page is drawn again
    local tourParts, tourEvent = {}, nil
    local displayRow
    local renderEditor, closeEditor

    local function list()
        return target.item and target.Changes() or nil
    end

    local function tour(event)
        if not target.item then private.OnTourEvent(event) end
    end

    local function refreshTour()
        if not target.item then private.RefreshTourStep() end
    end

    local function context(time)
        local remaining = time or state.remaining
        local duration = math.max(remaining, state.duration or state.zoom)
        return { remaining = remaining, duration = duration, elapsed = duration - remaining,
            source = state.source, state = state.timerState, previewChange = state.previewChange, previewDuration = state.duration or state.zoom,
            changes = list(), item = target.Item and target.Item() }
    end

    local function restartPreview()
        state.remaining, state.loop = state.zoom, state.loop + 1
    end

    local function changes()
        return target.Changes()
    end

    local function selected()
        return state.selected and Countdown.Find(state.selected, list())
    end

    local function previewDisplay()
        return state.scope == "Shared" and "SpellIcon" or state.scope
    end

    local function updatePreviewContext()
        state.source, state.timerState = target.source or "Addon", private.manager.STATES.Active
        state.duration, state.previewChange = state.zoom, nil
        local change = selected()
        if not change then return end
        local selection = change.selection
        if chooser then
            selection = chooser:Value()
            state.previewChange = private.DeepCopy(change)
            state.previewChange.selection = selection
            state.previewChange.start, state.previewChange.finish, state.previewChange.exclusiveStart = envelope(selection), nil, nil
        end
        if not selection then return end
        local from, to = math.min(change.start, state.zoom), math.max(change.finish or 0, state.viewEnd)
        if from <= to then from, to = change.start, change.finish or 0 end
        local example = Selection.Example(selection, to + (from - to) / 2, state.zoom)
            or Selection.ExampleInRange(selection, to, from, state.zoom)
            or Selection.ExampleInRange(selection, change.finish or 0, change.start, state.zoom)
        if example then state.source, state.timerState, state.duration = example.source, example.state, example.duration end
    end

    local history = { undo = {}, redo = {} }

    ---every edit ends in refresh, comparing with the settings seen last there records one undo step per edit
    local function track()
        local current = Countdown.GetSettings()
        if history.last and Countdown.Same(history.last, current) then return end
        if history.last then
            table.insert(history.undo, history.last)
            if #history.undo > 50 then table.remove(history.undo, 1) end
            history.redo = {}
        end
        history.last = private.DeepCopy(current)
    end

    local function refresh(rebuild)
        if not target.item then track() end
        updatePreviewContext()
        if laneWidget and laneWidget.model then
            laneWidget.model.context, laneWidget.model.selected, laneWidget.model.base = context(), state.selected, state.base
        end
        target.Commit()
        if rebuild then target.Rebuild() end
    end

    local function replaceSettings(appearance)
        if appearance then private.db.profile.cooldown_settings.appearance = appearance else Countdown.ResetAll() end
        state.profile, chooser = Countdown.GetSettings(), nil
        if state.selected and not Countdown.Find(state.selected, list()) then state.selected = nil end
    end

    local function travel(from, to)
        local snapshot = table.remove(from)
        if not snapshot then return end
        table.insert(to, history.last)
        history.last = private.DeepCopy(snapshot)
        replaceSettings(snapshot)
        refresh(true)
    end

    ---whether displays holds every display that can show the property
    local function baseAll(displays, property)
        for _, display in ipairs(Countdown.DisplaysOf(property)) do
            if not displays[display] then return false end
        end
        return true
    end

    local function baseFirst(displays)
        for _, display in ipairs(Countdown.Displays) do if displays[display] then return display end end
    end

    local function getBase(displays, key)
        local first = baseFirst(displays)
        local own = Countdown.Scope(first)
        local value = own and own.base[key]
        if value == nil then value = Countdown.Scope("Shared").base[key] end
        if value == nil and Countdown.DisplayDefaults[first] then value = Countdown.DisplayDefaults[first][key] end
        return value
    end

    ---all displays share the value, a smaller set gets its own
    local function setBase(displays, key, value)
        local all = baseAll(displays, key)
        if all then Countdown.Scope("Shared").base[key] = value end
        for _, display in ipairs(Countdown.Displays) do
            if displays[display] then Countdown.Scope(display, true).base[key] = not all and value or nil end
        end
    end

    local function setBaseColor(displays, value)
        local all = baseAll(displays, "color")
        if all then private.SetThemeModification("Elements.Cooldown.Font.Color", value) end
        for _, display in ipairs(Countdown.Displays) do
            if displays[display] then private.SetThemeModification("Elements.Cooldown.DisplayColors." .. display, not all and value or false) end
        end
    end

    local function baseKey(property, display, style)
        if property == "format" then return tostring(style.format) .. tostring(style.precision) .. tostring(style.rounding) end
        if property == "color" then return table.concat({ private.ThemeApply.Color(Countdown.BaseColor(display)) }, "|") end
        if property == "duration" or property == "shown" then return tostring(style[property]) end
        if property == "glow" then return tostring(style.glow and style.glow.type) end
        return ""
    end

    local function resetBase(property)
        if target.item then
            -- an item's unchanged look is its "Shows on" and glow
            target.EditItem(function(item)
                if property == "shown" then item.displays = nil
                else item.glow, item.glowWhen, item.glowSelection = nil, nil, nil end
            end)
        elseif property == "format" then Countdown.ResetStyle()
        elseif property == "duration" then
            Countdown.Scope("Shared").base.duration = nil
            for _, display in ipairs(Countdown.Displays) do
                local own = Countdown.Scope(display)
                if own then own.base.duration = nil end
            end
        elseif property == "color" then
            private.ResetThemeModifications("Elements.Cooldown.Font.Color")
            private.ResetThemeModifications("Elements.Cooldown.DisplayColors")
        else
            private.ResetThemeModifications("Elements.Cooldown.Font.Size")
            private.ResetThemeModifications("Elements.Cooldown.DisplaySizes")
            private.ResetThemeModifications("Elements.Cooldown.BigIconScale")
        end
    end

    local pick

    local function show()
        updatePreviewContext()
        state.error = nil
        local opening = not editor
        if not editor then
            editor = AceGUI:Create("AtCountdownEditor")
            editor:SetLayout("Fill")
            editor:SetCallback("OnClose", function() closeEditor() end)
            editor:SetCallback("OnCopy", function()
                local change = selected()
                local duplicate = Countdown.Add(change.property, math.max(0.1, change.start / 2), private.DeepCopy(change.value), list())
                duplicate.selection, duplicate.displays = private.DeepCopy(change.selection), private.DeepCopy(change.displays)
                if change.advanced then duplicate.advanced, duplicate.start = true, change.start end
                duplicate.precision, duplicate.rounding = change.precision, change.rounding
                refresh(false)
                pick(duplicate)
            end)
            editor:SetCallback("OnRemove", function()
                tDeleteItem(changes(), selected())
                state.selected, chooser = nil, nil
                refresh(true)
            end)
            local scroll = AceGUI:Create("AtScrollFrame")
            scroll:SetLayout("List")
            editor:AddChild(scroll)
            editor.scroll = scroll
        end
        editor.scroll:SetStatusTable({})
        renderEditor()
        if opening then
            local owner = target.Owner()
            editor:ShowBeside(owner and owner.frame)
        end
        target.Rebuild()
    end

    pick = function(change)
        if not change.advanced and change.finish and not change.selection then setMode(change, true) end
        if change.selection then change.advanced = true end
        state.selected, state.base, chooser, state.confirmSimple = change.id, nil, nil, nil
        show()
        tour("ruleOpen")
    end


    local function push(parent, text, control, themePath)
        local row = AceGUI:Create(editor and (parent == editor.scroll or parent.type == "AtCountdownLayout") and "AtCountdownField" or "AtSettingRow")
        row:SetLabel(settingsText(text))
        if themePath then
            row:SetChanged(private.IsThemeModified(themePath))
            local function details()
                row:SetChanged(private.IsThemeModified(themePath))
                local window = private.GetSettingsWindow()
                if window then
                    window:ShowDetails(settingsText(text), L("CountdownThemeSetting"), function()
                        private.ResetThemeModifications(themePath)
                        target.Rebuild()
                    end)
                end
            end
            row:SetCallback("OnEnter", details)
            control:SetCallback("OnEnter", details)
        end
        row:AddChild(control)
        parent:AddChild(row)
        return control
    end


    local function dropdown(parent, text, values, value, callback, width, order)
        local control = AceGUI:Create("AtDropdown")
        control:SetUserData("preferredWidth", width)
        control:SetList(values, order)
        control:SetValue(value)
        control:SetCallback("OnValueChanged", function(_, _, choice) callback(choice) end)
        return push(parent, text, control)
    end

    local function toggle(parent, text, value, callback)
        local control = AceGUI:Create("AtCheckBox")
        control:SetLabel("")
        control:SetValue(value)
        control:SetCallback("OnValueChanged", function(_, _, checked) callback(checked) end)
        return push(parent, text, control)
    end

    local function numberInput(value, callback, minimum, maximum)
        local control = AceGUI:Create("AtEditBox")
        control:SetLabel("")
        control:SetText(tostring(value))
        control:SetCallback("OnEnterPressed", function(_, _, entered)
            local parsed = tonumber(entered)
            if Countdown.IsFinite(parsed) and parsed >= (minimum or 0) and (not maximum or parsed <= maximum) then
                state.error = nil
                callback(parsed)
            else
                control:SetText(tostring(value))
                state.error = L("CountdownInvalidNumber")
                if chooser then chooser.error = state.error end
                target.Rebuild()
            end
        end)
        return control
    end

    local function number(parent, text, value, callback, minimum, maximum, themePath, width)
        local control = numberInput(value, callback, minimum, maximum)
        control:SetUserData("preferredWidth", width)
        return push(parent, text, control, themePath)
    end

    local function timeValues(parent, test, changed)
        local line = AceGUI:Create("AtCountdownLayout")
        line:PauseLayout()
        line:Configure("wrap", 6)
        local function caption(key)
            local widget = AceGUI:Create("AtCountdownCaption")
            widget:SetText(L(key))
            line:AddChild(widget)
        end
        caption(({ less = "CountdownTimeUnderPrefix", atMost = "CountdownTimeUpToPrefix", greater = "CountdownTimeOverPrefix", atLeast = "CountdownTimeAtLeastPrefix",
            between = "CountdownTimeBetweenPrefix" })[test.op])
        local lower = numberInput(test.value or 0, function(value)
            test.value = value
            if test.op == "between" and (test.upper or value) < value then test.upper = value end
            changed()
        end)
        lower:SetUserData("preferredWidth", 80)
        line:AddChild(lower)
        if test.op == "between" then
            caption("CountdownTimeAnd")
            local upper = numberInput(test.upper or test.value or 0, function(value) test.upper = value; changed() end, test.value or 0)
            upper:SetUserData("preferredWidth", 80)
            line:AddChild(upper)
        end
        caption("CountdownTimeSeconds")
        parent:AddChild(line)
        line:ResumeLayout()
        line:DoLayout()
    end

    local function action(parent, text, callback)
        local control = AceGUI:Create("AtButton")
        control:SetText(text)
        control:SetCallback("OnClick", callback)
        return push(parent, "", control)
    end

    local function color(parent, text, value, callback, themePath)
        local control = AceGUI:Create("AtColorPicker")
        control:SetLabel("")
        control:SetHasAlpha(true)
        control:SetColor(private.ThemeApply.Color(value))
        control:SetCallback("OnValueChanged", function(_, _, r, g, b, a) callback({ r = r, g = g, b = b, a = a }) end)
        return push(parent, text, control, themePath)
    end

    local function overlaps(change)
        if not change.selection or Countdown.Match(change.selection, {}) == true then return {} end
        local result = {}
        local needsChoice = false
        for _, other in ipairs(changes()) do
            if other.id ~= change.id and other.enabled ~= false and other.property == change.property and sharesDisplay(change, other) and
                not (other.yields and other.yields[change.id]) and not (change.yields and change.yields[other.id]) and
                (other.finish or 0) < change.start and (change.finish or 0) < other.start and
                Selection.Intersects(timeSelection(change), timeSelection(other), math.max(change.finish or 0, other.finish or 0), math.min(change.start, other.start)) then
                table.insert(result, other)
                needsChoice = needsChoice or other.start < change.start or other.selection and Countdown.Match(other.selection, {}) ~= true
            end
        end
        return needsChoice and result or {}
    end

    local function applySelection(useNew)
        if not chooser:Valid() then return end
        if not chooser:Changed() then chooser = nil; refresh(true); return end
        local pending = private.DeepCopy(selected())
        pending.selection = chooser:Value()
        pending.start, pending.finish, pending.exclusiveStart, pending.advanced = envelope(pending.selection), nil, nil, true
        if useNew == nil then
            local conflict = overlaps(pending)
            if #conflict > 0 then chooser.conflicts = conflict; renderEditor(); return end
        end
        local change = selected()
        change.selection, change.start, change.finish, change.exclusiveStart, change.advanced = pending.selection, pending.start, nil, nil, true
        for _, other in ipairs(chooser.conflicts or {}) do
            local loser, winner = useNew and other or change, useNew and change or other
            loser.yields = loser.yields or {}
            loser.yields[winner.id] = true
        end
        chooser = nil
        refresh(true)
    end

    local previewInfo = { spellName = L("TestIcon"), maxQueueDuration = 0 }
    local allPreview

    local function tick(elapsed)
        if state.remaining <= state.viewEnd then restartPreview()
        else state.remaining = math.max(state.viewEnd, state.remaining - elapsed) end
        if laneWidget then laneWidget:SetTime(state.remaining) end
    end

    local function draw(display)
        local widget = previews[display]
        local ctx = context()
        widget.frame.countdownPreview = ctx
        widget.frame.state = state.timerState
        previewInfo.duration, previewInfo.source = ctx.duration, state.source
        if display == "BigIcon" and (widget.countdownLoop ~= state.loop or widget.countdownDuration ~= ctx.duration) then
            widget.frame.Cooldown:SetCooldown(GetTime() - ctx.elapsed, ctx.duration)
            widget.countdownLoop = state.loop
            widget.countdownDuration = ctx.duration
        end
        if display == "TextHighlight" then widget:HandleTexts(previewInfo, state.remaining)
        else widget.HandleCooldown(widget.frame, state.remaining) end
    end

    local function displayPreview(display)
        if not previews[display] then
            local widget = private.CreateSettingsPreview(display)
            previews[display] = widget
            widget.frame:HookScript("OnHide", function(frame)
                private.StopGlow(frame)
                frame.atCountdownGlow = nil
            end)
        end
        return previews[display].frame
    end


    ---one display on its own, or all three at fixed sizes in fixed places
    local function preview()
        local display = state.scope
        if display ~= "Shared" then
            local frame = displayPreview(display)
            frame:SetScale(1)
            frame:SetScript("OnUpdate", function(_, elapsed) tick(elapsed); draw(display) end)
            return frame
        end
        if not allPreview then
            allPreview = CreateFrame("Frame", nil, UIParent)
            allPreview:SetSize(300, 150)
            allPreview:SetScript("OnUpdate", function(_, elapsed)
                tick(elapsed)
                for _, shown in ipairs(Countdown.Displays) do
                    -- the settings window hides the preview it showed before, which can be one of these
                    previews[shown].frame:Show()
                    draw(shown)
                end
            end)
        end
        for _, shown in ipairs(Countdown.Displays) do
            local frame, slot = displayPreview(shown), slots[shown]
            local scale = math.min(slot.height / math.max(1, frame:GetHeight()), 300 / math.max(1, frame:GetWidth()))
            frame:SetScript("OnUpdate", nil)
            frame:SetParent(allPreview)
            frame:SetScale(scale)
            frame:ClearAllPoints()
            frame:SetPoint("TOP", allPreview, "TOP", 0, -slot.y / scale)
            frame:Show()
        end
        return allPreview
    end

    local function baseRows(parent)
        if state.scope == "Shared" then
            local media = AceGUI:Create("AtMediaPicker")
            media:SetMediaType("font")
            local font = private.GetThemeValue("Elements.Cooldown.Font")
            media:SetValue(font.Media or font.Path or font.Object)
            media:SetCallback("OnValueChanged", function(_, _, value) private.SetThemeModification("Elements.Cooldown.Font.Media", value) end)
            push(parent, L("CooldownFont"), media, "Elements.Cooldown.Font.Media")
            number(parent, L("CooldownFontSize"), font.Size or 24, function(value) private.SetThemeModification("Elements.Cooldown.Font.Size", value) end, 1, 128, "Elements.Cooldown.Font.Size")
            color(parent, L("DefaultCooldownColor"), font.Color, function(value) private.SetThemeModification("Elements.Cooldown.Font.Color", value) end, "Elements.Cooldown.Font.Color")
            action(parent, L("CountdownResetFont"), function() private.ResetThemeModifications("Elements.Cooldown.Font"); target.Rebuild() end)
        else
            local path = "Elements.Cooldown.DisplaySizes." .. state.scope
            local size = private.GetThemeValue(path) or 0
            toggle(parent, L("CountdownOwnFontSize"), size > 0, function(checked)
                local widget = previews[state.scope]
                local region = widget and (widget.frame.CooldownText or widget.frame.Cooldown)
                local font = region and region.atCountdownFont
                local inherited = font and font.size or private.GetElementStyle("Cooldown").Font.Size or 24
                private.SetThemeModification(path, checked and inherited or 0)
                target.Rebuild()
            end)
            if size > 0 then number(parent, L("CooldownFontSize"), size, function(value) private.SetThemeModification(path, value) end, 1, 512, path) end
            local colorPath = "Elements.Cooldown.DisplayColors." .. state.scope
            local ownColor = private.GetThemeValue(colorPath)
            toggle(parent, L("CountdownOwnColor"), ownColor and true or false, function(checked)
                private.SetThemeModification(colorPath, checked and private.DeepCopy(private.GetElementStyle("Cooldown").Font.Color) or false)
                target.Rebuild()
            end)
            if ownColor then color(parent, L("DefaultCooldownColor"), ownColor, function(value) private.SetThemeModification(colorPath, value) end, colorPath) end
            action(parent, L("CountdownResetBase"), function()
                Countdown.Scope(state.scope, true).base = {}
                private.ResetThemeModifications(path)
                private.ResetThemeModifications(colorPath)
                state.selected = nil
                refresh(true)
            end)
        end
        if state.scope == "Shared" or state.scope == "BigIcon" then
            number(parent, L("CountdownBigScale"), private.GetElementStyle("Cooldown").BigIconScale or 2,
                function(value) private.SetThemeModification("Elements.Cooldown.BigIconScale", value) end, 0.25, 4, "Elements.Cooldown.BigIconScale")
        end
    end

    local function advancedSwitch(body, value, callback)
        local caption = AceGUI:Create("AtCountdownCaption")
        caption:SetText(L("CountdownModeAdvanced"))
        body:AddHeaderWidget(caption)
        local switch = AceGUI:Create("AtCheckBox")
        switch:SetLabel("")
        switch:SetValue(value)
        switch:SetUserData("preferredWidth", 36)
        switch:SetCallback("OnValueChanged", function(_, _, checked) callback(checked) end)
        body:AddHeaderWidget(switch)
        return { caption.frame, switch.frame }
    end

    local function renderChange(scroll)
        local change = selected()
        if not change then return end
        if state.error then note(scroll, state.error) end
        tourParts.look = section(scroll, L("CountdownSectionLook"), "plain", function(body)
            if change.property == "color" then
                color(body, L("CountdownMakeText"), change.value or Countdown.BaseColor(previewDisplay()), function(value) change.value = value; refresh(false) end)
            elseif change.property == "size" then
                number(body, L("CountdownSizePercent"), change.value or 100, function(value) change.value = value; refresh(false) end, 25, 400, nil, 80)
            elseif change.property == "glow" then
                local values = private.DeepCopy(private.GlowTypes)
                values.NONE = L("CountdownNoGlow")
                dropdown(body, L("CountdownGlow"), values, change.value and change.value.type or "NONE", function(value)
                    change.value = value ~= "NONE" and { type = value, color = change.value and change.value.color or { r = 1, g = 1, b = 1, a = 1 } } or false
                    refresh(true)
                end, 180)
                local glow = change.value
                if glow then
                    advancedSwitch(body, glow.advanced == true, function(checked) glow.advanced = checked or nil; refresh(true) end)
                    color(body, L("CooldownGlowColor"), glow.color, function(value) glow.color = value; refresh(false) end)
                    if glow.advanced then
                        for _, option in ipairs(glowOptions[glow.type] or {}) do
                            local current = glow.options and glow.options[option.key]
                            if current == nil then current = option.default end
                            local function set(value)
                                glow.options = glow.options or {}
                                glow.options[option.key] = value
                                refresh(false)
                            end
                            if type(option.default) == "boolean" then toggle(body, L(option.text), current, set)
                            else
                                number(body, L(option.text), current, function(value)
                                    if option.key == "lines" then value = math.floor(value) end
                                    if option.zeroIsAuto and value == 0 then value = nil end
                                    set(value)
                                end, option.minimum or 0, option.maximum, nil, 80)
                            end
                        end
                    end
                end
            elseif change.property == "shown" then
                dropdown(body, propertyNames.shown, shownNames, change.value and "show" or "hide", function(value)
                    change.value = value == "show"; refresh(true)
                end, 180, { "show", "hide" })
                note(body, L("CountdownShownHint"))
            elseif change.property == "duration" then
                dropdown(body, propertyNames.duration, durationNames, change.value or "none", function(value)
                    change.value = value; refresh(true)
                end, 180, Countdown.DurationStyles)
            elseif change.property == "heartbeat" then
                toggle(body, propertyNames.heartbeat, change.value and true or false, function(checked)
                    change.value = checked and {} or false; refresh(true)
                end)
                local beat = change.value
                if beat then
                    toggle(body, L("CountdownHeartbeatOwnColor"), beat.color ~= nil, function(checked)
                        beat.color = checked and { r = 1, g = 1, b = 1, a = 1 } or nil; refresh(true)
                    end)
                    if beat.color then color(body, L("CountdownHeartbeatColor"), beat.color, function(value) beat.color = value; refresh(false) end) end
                end
            elseif change.property == "format" then
                local own, base = Countdown.Scope(previewDisplay()), Countdown.Scope("Shared").base
                dropdown(body, propertyNames.format, formats, change.value, function(value) change.value = value; refresh(true) end)
                if change.value ~= "minutes" then
                    dropdown(body, propertyNames.precision, precisionNames, change.precision or own and own.base.precision or base.precision or 0,
                        function(value) change.precision = tonumber(value); refresh(false) end)
                end
                dropdown(body, propertyNames.rounding, roundingNames, change.rounding or own and own.base.rounding or base.rounding or "up",
                    function(value) change.rounding = value; refresh(false) end)
            end
        end)
        local advanced = change.advanced == true
        tourParts.when = section(scroll, L("CountdownSectionWhen"), "section", function(body)
            tourParts.advanced = advancedSwitch(body, advanced, function(checked)
                if not checked and not onlyTiming(change.selection) and state.confirmSimple ~= change.id then state.confirmSimple = change.id
                else state.confirmSimple = nil; setMode(change, checked) end
                if checked then tourEvent = "ruleAdvanced" end
                refresh(true)
            end)
            if state.confirmSimple == change.id then note(body, L("CountdownModeConfirm")) end
            if advanced then
                tourParts.choose = selectionLine(body, change.selection, function()
                    chooser = Selection.New(change.selection)
                    tourEvent = "ruleTimers"
                    refresh(true)
                end)
            else
                number(body, L("CountdownFrom"), change.start, function(value)
                    change.start = value
                    Countdown.Coalesce(change, list())
                    refresh(true)
                end, 0.01, nil, nil, 80)
            end
        end)
        tourParts.showOn = section(scroll, L("CountdownShowOn"), "section", function(body)
            local line = AceGUI:Create("AtCountdownLayout")
            line:PauseLayout()
            line:Configure("wrap", 6)
            local supported = Countdown.DisplaysOf(change.property)
            for _, display in ipairs(supported) do
                local control = chip(settingsText(scopes[display]), not change.displays or change.displays[display] == true, function()
                    local shown = change.displays and private.DeepCopy(change.displays)
                    if not shown then
                        shown = {}
                        for _, other in ipairs(supported) do shown[other] = true end
                    end
                    shown[display] = not shown[display] or nil
                    if not next(shown) then return end
                    local all = true
                    for _, other in ipairs(supported) do all = all and shown[other] == true end
                    change.displays = not all and shown or nil
                    refresh(true)
                end)
                control:SetUserData("grow", true)
                line:AddChild(control)
            end
            body:AddChild(line)
            line:ResumeLayout()
            line:DoLayout()
        end)
    end

    ---opens the timer selection editor on a selection of its own, apply gets the new selection (nil for any timer)
    local function editSelection(selection, title, apply)
        closeEditor()
        state.selected, state.base = nil, nil
        state.selectionEdit = { title = title, apply = apply }
        chooser = Selection.New(selection)
        show()
    end

    ---an item's own look: the "Shows on" and glow its reminder or boss timer rule sets in the timings editor
    local function renderItemDefault(scroll)
        local property, item = state.base.property, target.Raw()
        if property == "shown" then
            section(scroll, L("EditorShowsOn"), "section", function(body)
                local line = AceGUI:Create("AtCountdownLayout")
                line:PauseLayout()
                line:Configure("wrap", 6)
                for _, display in ipairs(Countdown.Displays) do
                    local key = Countdown.DisplayKeys[display]
                    local control = chip(settingsText(scopes[display]), not item.displays or item.displays[key] ~= false, function()
                        target.EditItem(function(r)
                            local shown = r.displays or { timeline = true, bigIcon = true, textHighlight = true }
                            shown[key] = shown[key] == false
                            local all = true
                            for _, other in pairs(Countdown.DisplayKeys) do all = all and shown[other] ~= false end
                            r.displays = not all and shown or nil
                        end)
                        refresh(true)
                    end)
                    control:SetUserData("grow", true)
                    line:AddChild(control)
                end
                body:AddChild(line)
                line:ResumeLayout()
                line:DoLayout()
            end)
            return
        end
        section(scroll, L("CountdownSectionLook"), "plain", function(body)
            local values = private.DeepCopy(private.GlowTypes)
            values.NONE = L("CountdownNoGlow")
            dropdown(body, L("EditorGlow"), values, item.glow or "NONE", function(value)
                target.EditItem(function(r) r.glow = value ~= "NONE" and value or nil end)
                refresh(true)
            end, 180)
        end)
        if not item.glow then return end
        -- when it glows: the simple choice, or a timer selection of its own like a rule's
        section(scroll, L("CountdownSectionWhen"), "section", function(body)
            local custom = item.glowWhen == "custom"
            advancedSwitch(body, custom, function(checked)
                target.EditItem(function(r) r.glowWhen = checked and "custom" or nil end)
                refresh(true)
            end)
            if custom then
                selectionLine(body, item.glowSelection, function()
                    editSelection(item.glowSelection, L("EditorGlowSelectionTitle"), function(selection)
                        target.EditItem(function(r) r.glowSelection = selection end)
                        refresh(true)
                    end)
                end)
            else
                dropdown(body, L("EditorGlowWhen"), { always = L("EditorGlowAlways"), close = L("EditorGlowClose") },
                    item.glowWhen or "always", function(value)
                        target.EditItem(function(r) r.glowWhen = value ~= "always" and value or nil end)
                        refresh(true)
                    end, 180, { "always", "close" })
            end
        end)
    end

    local function renderDefault(scroll)
        if target.item then renderItemDefault(scroll); return end
        local base = state.base
        local property, displays = base.property, base.displays
        section(scroll, L("CountdownSectionLook"), "plain", function(body)
            if property == "format" then
                local function set(key) return function(value) setBase(displays, key, key == "precision" and tonumber(value) or value); refresh(true) end end
                dropdown(body, propertyNames.format, formats, getBase(displays, "format"), set("format"))
                if getBase(displays, "format") ~= "minutes" then
                    dropdown(body, propertyNames.precision, precisionNames, getBase(displays, "precision") or 0, set("precision"))
                end
                dropdown(body, propertyNames.rounding, roundingNames, getBase(displays, "rounding") or "up", set("rounding"))
            elseif property == "color" then
                color(body, L("DefaultCooldownColor"), Countdown.BaseColor(baseFirst(displays)), function(value) setBaseColor(displays, value) end)
            elseif property == "duration" then
                dropdown(body, propertyNames.duration, durationNames, getBase(displays, "duration") or "none", function(value)
                    setBase(displays, "duration", value); refresh(true)
                end, 180, Countdown.DurationStyles)
            else
                local font = private.GetThemeValue("Elements.Cooldown.Font")
                number(body, L("CooldownFontSize"), font.Size or 24, function(value) private.SetThemeModification("Elements.Cooldown.Font.Size", value) end, 1, 128, nil, 80)
                for _, display in ipairs(Countdown.Displays) do
                    local path = "Elements.Cooldown.DisplaySizes." .. display
                    number(body, string.format(L("CountdownDisplayFontSize"), settingsText(scopes[display])), private.GetThemeValue(path) or 0,
                        function(value) private.SetThemeModification(path, value) end, 0, 512, nil, 80)
                end
                number(body, L("CountdownBigScale"), private.GetElementStyle("Cooldown").BigIconScale or 2,
                    function(value) private.SetThemeModification("Elements.Cooldown.BigIconScale", value) end, 0.25, 4, nil, 80)
            end
        end)
        if property == "size" then return end
        section(scroll, L("CountdownShowOn"), "section", function(body)
            local line = AceGUI:Create("AtCountdownLayout")
            line:PauseLayout()
            line:Configure("wrap", 6)
            for _, display in ipairs(Countdown.DisplaysOf(property)) do
                local control = chip(settingsText(scopes[display]), displays[display] == true, function()
                    local shown = CopyTable(displays)
                    shown[display] = not shown[display] or nil
                    if not next(shown) then return end
                    if shown[display] then
                        -- a display that joins takes over the default being edited
                        if property == "color" then setBaseColor(shown, Countdown.BaseColor(baseFirst(displays)))
                        elseif property == "duration" then setBase(shown, "duration", getBase(displays, "duration"))
                        else
                            local values = { format = getBase(displays, "format"), precision = getBase(displays, "precision"), rounding = getBase(displays, "rounding") }
                            for key, value in pairs(values) do setBase(shown, key, value) end
                        end
                    end
                    base.displays = shown
                    refresh(true)
                end)
                control:SetUserData("grow", true)
                line:AddChild(control)
            end
            body:AddChild(line)
            line:ResumeLayout()
            line:DoLayout()
        end)
    end

    closeEditor = function()
        local current = editor
        editor = nil
        chooser, state.error, state.base, state.selectionEdit = nil, nil, nil, nil
        if current then
            current:Release()
            tour("ruleClosed")
        end
        updatePreviewContext()
        if laneWidget and laneWidget.model then
            laneWidget.model.context = context()
            laneWidget:Draw()
        end
    end

    ---the timer selection editor's helpers, apply and cancel are what its footer does
    local function chooserUI(apply, cancel)
        return {
            Scope = settingsText(scopes[state.scope]), Card = cardText, Sources = sources, States = timerStates,
            Names = function(test) return namesText(test, test.field == "source" and sources or timerStates) end,
            Matches = function(selection) return Selection.ExampleInRange(selection, 0, envelope(selection)) ~= nil end,
            Note = note, TimeValues = timeValues, Action = action,
            Refresh = function() refresh(true) end, Apply = apply, Cancel = cancel,
            Tour = function(event) tourEvent = event end,
        }
    end

    renderEditor = function()
        if not editor then return end
        local change = selected()
        if not change and not state.base and not state.selectionEdit then closeEditor(); return end
        local scroll = editor.scroll
        tourParts = {}
        scroll:PauseLayout()
        scroll:ReleaseChildren()
        if state.selectionEdit then
            -- a timer selection of its own, e.g. when a reminder glows, in the same editor as a rule's
            local edit = state.selectionEdit
            editor:SetTitle(settingsText(edit.title), "")
            editor:SetEnabledToggle(nil)
            chooser:Render(scroll, editor, chooserUI(function()
                if not chooser:Valid() then return end
                local value = chooser:Value()
                closeEditor()
                edit.apply(value)
            end, function() closeEditor() end))
        elseif not change then
            local property = state.base.property
            editor:SetTitle(settingsText(string.format(L("CountdownEditDefault"), label(property))), "")
            editor:SetEnabledToggle(nil)
            editor:SetActions({
                Done = { text = L("CountdownDone"), callback = function() closeEditor() end },
                Remove = { text = L("CountdownResetDefault"), callback = function() resetBase(property); refresh(true) end },
            })
            renderDefault(scroll)
            -- a default has no time of its own, a rule from the clicked time changes it for a time window
            local time = state.base.time
            if time and time > 0 then
                section(scroll, L("CountdownSectionWhen"), "section", function(body)
                    note(body, L("CountdownDefaultWhen"))
                    action(body, string.format(L("CountdownAddRuleAt"), time), function()
                        laneWidget:Fire("OnSelect", property, nil, time)
                    end)
                end)
            end
        elseif chooser then
            editor:SetTitle(settingsText(string.format(L("CountdownEditChange"), label(change.property))), settingsText(scopes[state.scope]))
            editor:SetEnabledToggle(nil)
            chooser:Render(scroll, editor, chooserUI(applySelection, function() chooser = nil; refresh(true) end))
        else
            editor:SetTitle(settingsText(string.format(L("CountdownEditChange"), label(change.property))), settingsText(scopes[state.scope]))
            editor:SetActions(nil)
            editor:SetEnabledToggle(change.enabled ~= false, function(value) change.enabled = value; refresh(true) end)
            renderChange(scroll)
            tourParts.enabled, tourParts.copy, tourParts.remove = editor.toggle.frame, editor.frame.Copy, editor.frame.Remove
        end
        scroll:ResumeLayout()
        editor:DoLayout()
        scroll:DoLayout()
        editor:FitContent()
        if change and not chooser then tour("ruleShown") end
        refreshTour()
    end

    local function checkProfile()
        if state.profile ~= Countdown.GetSettings() then
            closeEditor()
            state.profile, state.selected = Countdown.GetSettings(), nil
            history.undo, history.redo, history.last = {}, {}, nil
            updatePreviewContext()
        end
    end

    local function scopeRow(parent, key)
        return dropdown(parent, L(key), scopes, state.scope, function(value)
            closeEditor()
            state.scope, state.selected = value, nil
            updatePreviewContext()
            target.Rebuild()
        end)
    end

    local function renderChanges(scroll, header)
        checkProfile()
        if not target.item then track() end
        if header then displayRow = scopeRow(header, "CountdownPreview").parent.frame end
        laneWidget = AceGUI:Create("AtCountdownLanes")
        local lanes = {}
        for _, property in ipairs(Countdown.Lanes) do
            if Countdown.Supports(property, state.scope) then table.insert(lanes, property) end
        end
        laneWidget:Setup({ display = state.scope, zoom = state.zoom, viewEnd = state.viewEnd, lanes = lanes,
            selected = state.selected, base = state.base, context = context(), Changes = changes, Inherited = target.Inherited, Label = label,
            Displays = scopes, BaseKey = baseKey, Boundaries = target.Boundaries })
        laneWidget:SetCallback("OnSelectBase", function(_, _, property, displays, time)
            -- an item's unchanged shown and glow are its "Shows on" and glow, its other lanes start a section
            local editable = target.item and (property == "shown" or property == "glow") or not target.item and editableBase[property]
            if not editable then laneWidget:Fire("OnSelect", property, nil, time); return end
            local shown = {}
            for _, display in ipairs(displays) do shown[display] = true end
            state.selected, state.base, chooser = nil, { property = property, displays = shown, time = time }, nil
            show()
        end)
        laneWidget:SetCallback("OnViewChanging", function(_, _, from, to)
            if state.zoom == from and state.viewEnd == to then return end
            state.zoom, state.viewEnd = from, to
            restartPreview()
            updatePreviewContext()
            laneWidget.model.context = context()
        end)
        laneWidget:SetCallback("OnViewChanged", function() target.Rebuild() end)
        laneWidget:SetCallback("OnSelect", function(_, _, property, id, time, display)
            local change = id and Countdown.Find(id, list())
            if not change then
                local style, origins = Countdown.Resolve(display or previewDisplay(), context(time))
                local origin = origins[property]
                local value = private.DeepCopy(style[property])
                if value == nil then value = private.DeepCopy(newValues[property]) end
                change = Countdown.Add(property, time, value or false, list())
                if origin then change.displays = private.DeepCopy(origin.displays) end
                if property == "format" then change.precision, change.rounding = style.precision, style.rounding end
                Countdown.Coalesce(change, list())
                refresh(false)
            end
            pick(change)
        end)
        laneWidget:SetCallback("OnDrag", function(_, _, id, edge, time)
            local change = Countdown.Find(id, list())
            state.selected, laneWidget.model.selected = change.id, change.id
            if edge == "start" then change.start = math.max((change.finish or 0) + 0.05, time)
            else change.finish = math.max(0, math.min(change.start - 0.05, time)) end
            Countdown.Coalesce(change, list())
            Countdown.Invalidate()
        end)
        laneWidget:SetCallback("OnChanged", function() refresh(true) end)
        scroll:AddChild(laneWidget)
        note(scroll, L("CountdownAddSectionHint"))
        local disabled = {}
        for _, change in ipairs(changes()) do
            if change.enabled == false then table.insert(disabled, change) end
        end
        if #disabled > 0 then
            section(scroll, L("CountdownDisabledChanges"), "section", function(body)
                -- more than two rows scroll in place, so the page itself never scrolls the lanes away
                local list, viewport = body, nil
                if #disabled > 2 then
                    viewport = AceGUI:Create("AtScrollFrame")
                    viewport:SetLayout("List")
                    viewport:SetFullWidth(true)
                    viewport:SetHeight(96)
                    state.disabledScroll = state.disabledScroll or {}
                    viewport:SetStatusTable(state.disabledScroll)
                    body:AddChild(viewport)
                    list = AceGUI:Create("AtCountdownLayout")
                    list:PauseLayout()
                    list:Configure("stack", 8)
                    viewport:AddChild(list)
                end
                for _, change in ipairs(disabled) do
                    local value = change.property ~= "color" and label(change.property, change.value) or ""
                    local name = value ~= "" and propertyNames[change.property] .. ": " .. value or propertyNames[change.property]
                    local row = AceGUI:Create("AtCountdownSituation")
                    row:SetSummary(change.advanced and name .. L("CountdownFilterJoin") .. selectionText(change.selection) or
                        string.format(L("CountdownEarlierChange"), name, change.start))
                    row:SetRemoveText(L("CountdownEnable"))
                    row:SetCallback("OnEdit", function() pick(change) end)
                    row:SetCallback("OnRemove", function() change.enabled = nil; refresh(true) end)
                    list:AddChild(row)
                end
                if viewport then
                    list:ResumeLayout()
                    list:DoLayout()
                    viewport:DoLayout()
                end
            end)
        end
        renderEditor()
        local event = tourEvent
        tourEvent = nil
        C_Timer.After(0, function()
            if event then tour(event) end
            refreshTour()
        end)
    end

    local function renderBase(scroll, header)
        checkProfile()
        scopeRow(header, "CountdownAppliesTo")
        heading(scroll, L("CountdownBaseAppearance"))
        baseRows(scroll)
    end

    local function hidePage()
        closeEditor()
        state.selected = nil
        updatePreviewContext()
        laneWidget, displayRow, tourEvent = nil, nil, nil
        for _, widget in pairs(previews) do private.StopGlow(widget.frame); widget.frame.atCountdownGlow = nil end
    end

    return {
        Preview = preview, RenderBase = renderBase, RenderChanges = renderChanges, Restart = restartPreview, Hide = hidePage, Close = closeEditor,
        Reset = function() closeEditor(); state.selected = nil; replaceSettings(nil); refresh(true) end,
        History = function()
            return #history.undo > 0 and function() travel(history.undo, history.redo) end or false,
                #history.redo > 0 and function() travel(history.redo, history.undo) end or false
        end,
        EditSelection = editSelection,
        Redraw = function() renderEditor() end,
        -- an item's lanes start unselected with their view from its timer's length to the ability
        Open = function(zoom)
            closeEditor()
            state.selected, state.base, chooser = nil, nil, nil
            state.zoom, state.viewEnd = zoom, 0
            restartPreview()
            updatePreviewContext()
        end,
        Editor = function() return editor, selected(), chooser, tourParts end,
        Lanes = function() return laneWidget, displayRow end,
        State = state,
    }
end

---the shared lanes of the Cooldown changes page
local page = Session({
    Changes = function() return Countdown.GetSettings().shared.changes end,
    Commit = function() Countdown.Changed() end,
    Rebuild = function() private.RefreshSettingsPage() end,
    Owner = function() return private.GetSettingsWindow() end,
})

---the rule window for the tour: the editor, the rule it edits, its timer selection while that is open and the frames
---of its sections
private.GetTimerRuleEditor = function()
    return page.Editor()
end

---the lanes and the display dropdown of the Timer Rules page for the tour
private.GetTimerRulesPage = function()
    return page.Lanes()
end

private.CountdownSelectionText = selectionText

-- the timer selection editor of the Timer Rules page on a selection of its own, e.g. when a reminder glows
local selectionSession
selectionSession = Session({
    item = true,
    Changes = function() return {} end,
    Commit = function() end,
    Rebuild = function() selectionSession.Redraw() end,
    Owner = function() end,
})

---edits when a reminder or boss timer rule glows, apply gets the new selection (nil for any timer)
private.EditGlowSelection = function(selection, apply)
    selectionSession.EditSelection(selection, L("EditorGlowSelectionTitle"), apply)
end

private.CloseGlowSelection = function()
    selectionSession.Close()
end

-- a reminder's or boss timer rule's own lanes, edited in a window of their own over a copy of its changes
local itemTarget = { item = true }
local itemSession, itemWindow, itemDraft, itemSaving

local function renderItemWindow()
    if not itemWindow then return end
    local scroll = itemWindow.scroll
    itemWindow:SetActions({
        Done = { text = L("CountdownDone"), callback = private.CloseItemLanes },
        Remove = { text = L("ItemLanesReset"), disabled = #itemDraft == 0, tooltip = L("ItemLanesResetEmpty"), callback = function()
            private.AskQuestion({
                title = L("ItemLanesResetTitle"),
                text = L("ItemLanesResetText"),
                accept = L("ItemLanesReset"),
                acceptStyle = "Danger",
                back = CANCEL,
                onAccept = function()
                    itemSession.Close()
                    wipe(itemDraft)
                    itemTarget.Commit()
                    renderItemWindow()
                end,
            })
        end },
    })
    scroll:PauseLayout()
    scroll:ReleaseChildren()
    -- the lanes of the Timer Rules page for all displays at once, without its preview and display dropdown
    itemSession.RenderChanges(scroll)
    scroll:ResumeLayout()
    itemWindow:DoLayout()
    scroll:DoLayout()
    itemWindow:FitContent()
end

private.CloseItemLanes = function()
    local window = itemWindow
    if not window then return end
    itemWindow = nil
    itemSession.Hide()
    window:Release()
end

---draws the lanes window again after its item's "Shows on" or glow changed in the timings editor
private.RefreshItemLanes = function()
    if itemWindow and not itemSaving then renderItemWindow() end
end

---opens the lanes of a reminder or boss timer rule, edit(apply, own) saves through its editor's undo, own when its
---"Shows on" or glow changed so the editor's panel shows them again
---@param item table
---@param options table -- { title, zoom, source, edit = fun(apply: fun(item: table), own: boolean|nil) }
private.OpenItemLanes = function(item, options)
    private.CloseItemLanes()
    itemDraft = private.DeepCopy(item.changes or {})
    local save = function(apply, own)
        itemSaving = true
        options.edit(apply, own)
        itemSaving = nil
        Countdown.Invalidate()
    end
    itemTarget.Inherited = Countdown.GetSettings().shared.changes
    itemTarget.source = options.source
    itemTarget.Changes = function() return itemDraft end
    itemTarget.Raw = function() return item end
    -- the timer's own look under its sections, as its event would carry it
    itemTarget.Item = function()
        local info = private.GetTimerRuleOverrides(item)
        info.countdownChanges = itemDraft
        return info
    end
    itemTarget.EditItem = function(apply) save(apply, true) end
    itemTarget.Boundaries = function(property)
        -- the glow lane splits where its own glow starts: the big icon threshold, or the remaining times its timer
        -- selection names
        if property == "glow" and item.glow and item.glowWhen == "close" then
            return { private.db.profile.big_icon_settings.threshold_time }
        elseif property == "glow" and item.glow and item.glowWhen == "custom" then
            local times = {}
            local function walk(node)
                if type(node) ~= "table" then return end
                if node.field == "remaining" and not node.any then
                    table.insert(times, node.value)
                    table.insert(times, node.upper)
                end
                walk(node.child)
                for _, child in ipairs(node.children or {}) do walk(child) end
            end
            walk(item.glowSelection)
            return times
        end
    end
    itemTarget.Commit = function()
        local saved = #itemDraft > 0 and private.DeepCopy(itemDraft) or nil
        save(function(target) target.changes = saved end)
    end
    itemTarget.Rebuild = renderItemWindow
    itemTarget.Owner = function() return itemWindow end
    itemSession = itemSession or Session(itemTarget)
    itemSession.State.scope = "Shared"
    itemSession.Open(options.zoom)
    itemWindow = AceGUI:Create("AtCountdownEditor")
    itemWindow:SetLayout("Fill")
    itemWindow.frame:SetWidth(math.min(640, UIParent:GetWidth() - 24))
    itemWindow.maxHeight = 640
    itemWindow.frame.atSideBySide = true
    itemWindow:SetTitle(settingsText(L("ItemLanesTitle")), options.title)
    itemWindow:SetCallback("OnClose", private.CloseItemLanes)
    local scroll = AceGUI:Create("AtScrollFrame")
    scroll:SetLayout("List")
    itemWindow:AddChild(scroll)
    itemWindow.scroll = scroll
    itemWindow:ShowBeside(nil)
    renderItemWindow()
end

private.RegisterSettingsPage({
    key = "Cooldown", order = 50, name = L("SettingsPageCooldown"), desc = L("CountdownBaseDescription"), rows = {},
    searchTerms = table.concat({ L("CountdownTimeStyle"), L("CountdownDecimals"), L("CountdownRounding"), L("CooldownFont"), L("CooldownFontSize"), L("DefaultCooldownColor") }, " "),
    GetPreview = page.Preview, Render = page.RenderBase, OnShow = page.Restart, OnHide = page.Hide,
})

private.RegisterSettingsPage({
    key = "CooldownChanges", order = 51, name = L("SettingsPageCooldownChanges"), desc = L("CountdownPageDescription"), rows = {},
    searchTerms = table.concat({ L("CountdownTimeStyle"), L("CountdownDecimals"), L("CountdownRounding"), L("CountdownGlow"), L("CountdownTextColor"), L("CountdownTextSize"), L("CountdownChooseTimers"), L("CountdownDuration"), L("CountdownHeartbeat"), L("CountdownShown") }, " "),
    GetPreview = page.Preview, Render = page.RenderChanges, OnShow = page.Restart, OnHide = page.Hide,
    resetText = L("CountdownResetAll"),
    ResetPage = page.Reset,
    GetHistory = page.History,
})
