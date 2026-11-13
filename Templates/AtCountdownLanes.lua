local appName, app = ...
---@class AbilityTimeline
local private = app
local AceGUI = LibStub("AceGUI-3.0")
local ThemeApply = private.ThemeApply
local Countdown = private.CooldownText
local Type, Version = "AtCountdownLanes", 1
local labelWidth, rowHeight = 90, 42

local function SetTime(self, remaining)
    if not self.model then return end
    local width = math.max(1, self.frame:GetWidth() - labelWidth - 8)
    local row = self.rows[#self.rows]
    local playhead = self.playhead
    local viewEnd = self.model.viewEnd or 0
    playhead:SetShown(row ~= nil and remaining >= viewEnd and remaining <= self.model.zoom)
    if row then
        playhead:ClearAllPoints()
        playhead:SetPoint("TOPLEFT", self.frame, "TOPLEFT", labelWidth + (self.model.zoom - remaining) / (self.model.zoom - viewEnd) * width - 1, -20)
        playhead:SetSize(2, math.max(1, -row.y + row.height - 32))
        ThemeApply.Solid(playhead.Line, ThemeApply.Color("Text"))
        ThemeApply.Solid(playhead.Cap, ThemeApply.Color("Text"))
    end
    self.model.context.remaining = remaining
end

local function cursorTime(self)
    local x = GetCursorPosition()
    local width = math.max(1, self.frame:GetWidth() - labelWidth - 8)
    local offset = x / self.frame:GetEffectiveScale() - self.frame:GetLeft() - labelWidth
    local viewEnd = self.model.viewEnd or 0
    return math.max(math.max(0.1, viewEnd), math.min(self.model.zoom, math.floor((self.model.zoom - offset / width * (self.model.zoom - viewEnd)) * 10 + 0.5) / 10))
end

local function SetView(self, from, to, finished)
    local limit = self.zoomLimit or 600
    from = math.max(1, math.min(limit, math.floor(from * 10 + 0.5) / 10))
    to = math.max(0, math.min(from - 1, math.floor(to * 10 + 0.5) / 10))
    if self.model.zoom ~= from or (self.model.viewEnd or 0) ~= to then
        self.model.zoom, self.model.viewEnd = from, to
        self:Fire("OnViewChanging", from, to)
        self:Draw()
    end
    if finished then self:Fire("OnViewChanged", from, to) end
end

local function zoomTime(self)
    local x = GetCursorPosition()
    local bar = self.zoomBar.track
    local fraction = math.max(0, math.min(1, (x / bar:GetEffectiveScale() - bar:GetLeft()) / bar:GetWidth()))
    if fraction == 0 then return self.zoomLimit end
    -- logarithmic, so the last seconds stay wide enough to drag on long timers
    return math.exp((1 - fraction) * math.log(1 + self.zoomLimit)) - 1
end

local function finishZoom(self)
    if not self.zoomDrag then return end
    self.zoomDrag = nil
    self.frame:SetScript("OnUpdate", nil)
    self:Fire("OnViewChanged", self.model.zoom, self.model.viewEnd or 0)
end

local function zoomBar(self)
    local bar = { track = CreateFrame("Button", nil, self.frame), label = self.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight"),
        caption = self.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight") }
    bar.fill = bar.track:CreateTexture(nil, "BACKGROUND")
    bar.fill:SetPoint("LEFT")
    bar.fill:SetPoint("RIGHT")
    bar.fill:SetHeight(4)
    bar.thumb = CreateFrame("Button", nil, bar.track)
    bar.thumb.fill = bar.thumb:CreateTexture(nil, "ARTWORK")
    bar.thumb.fill:SetPoint("LEFT")
    bar.thumb.fill:SetPoint("RIGHT")
    bar.thumb.fill:SetHeight(6)
    bar.handles = {}
    for _, edge in ipairs({ "start", "finish" }) do
        local handle = CreateFrame("Button", nil, bar.track)
        handle:SetSize(16, 20)
        handle.art = handle:CreateTexture(nil, "OVERLAY")
        handle.art:SetSize(10, 10)
        handle.art:SetPoint("CENTER")
        bar.handles[edge] = handle
    end
    local function begin(mode, key)
        if key == "RightButton" then self:SetView(10, 0, true); return end
        if key ~= "LeftButton" then return end
        local time = zoomTime(self)
        local from, to = self.model.zoom, self.model.viewEnd or 0
        if mode == "track" then
            local span = from - to
            to = math.max(0, math.min(self.zoomLimit - span, time - span / 2))
            self:SetView(to + span, to, false)
            mode = "pan"
        end
        self.zoomDrag = { mode = mode, time = time, from = self.model.zoom, to = self.model.viewEnd or 0 }
        self.frame:SetScript("OnUpdate", function()
            if not IsMouseButtonDown("LeftButton") then finishZoom(self); return end
            local drag = self.zoomDrag
            local delta = zoomTime(self) - drag.time
            if drag.mode == "start" then self:SetView(math.max(drag.to + 1, drag.from + delta), drag.to, false)
            elseif drag.mode == "finish" then self:SetView(drag.from, drag.to + delta, false)
            else
                delta = math.max(-drag.to, math.min(self.zoomLimit - drag.from, delta))
                self:SetView(drag.from + delta, drag.to + delta, false)
            end
        end)
    end
    for mode, target in pairs({ track = bar.track, pan = bar.thumb, start = bar.handles.start, finish = bar.handles.finish }) do
        target:SetScript("OnMouseDown", function(_, key) begin(mode, key) end)
        target:SetScript("OnMouseUp", function(_, key) if key == "LeftButton" then finishZoom(self) end end)
        target:EnableMouseWheel(true)
        target:SetScript("OnMouseWheel", function(_, delta)
            local to = self.model.viewEnd or 0
            local span = math.max(1, math.min(self.zoomLimit, (self.model.zoom - to) * (delta > 0 and 0.8 or 1.25)))
            local from = math.min(self.zoomLimit, to + span)
            self:SetView(from, from - span, true)
        end)
        target:SetScript("OnEnter", function(frame)
            GameTooltip:SetOwner(frame, "ANCHOR_TOP")
            GameTooltip:SetText(private.getLocalisation("CountdownZoomHint"))
            GameTooltip:Show()
        end)
        target:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    -- the caption doubles as a field to type the visible seconds
    bar.input = CreateFrame("EditBox", nil, self.frame)
    bar.input:SetSize(70, 20)
    bar.input:SetAutoFocus(false)
    bar.input:SetJustifyH("CENTER")
    bar.input:SetFrameLevel(self.frame:GetFrameLevel() + 6)
    bar.input.AtField = private.ThemedWidgets.CreateField(bar.input, bar.input, 0, 0, 0, 0)
    bar.input:Hide()
    bar.input:SetScript("OnEnterPressed", function(input)
        local seconds = tonumber(input:GetText())
        input:Hide()
        if seconds and seconds >= 1 then
            self.zoomLimit = math.max(self.zoomLimit or 600, seconds)
            self:SetView(seconds, math.min(self.model.viewEnd or 0, seconds - 1), true)
        end
    end)
    bar.input:SetScript("OnEscapePressed", function(input) input:Hide() end)
    bar.input:SetScript("OnEditFocusLost", function(input) input:Hide() end)
    bar.input:SetScript("OnHide", function() bar.caption:Show() end)
    bar.edit = CreateFrame("Button", nil, self.frame)
    bar.edit:SetAllPoints(bar.caption)
    bar.edit:SetScript("OnClick", function()
        bar.caption:Hide()
        bar.input:ClearAllPoints()
        bar.input:SetPoint("CENTER", bar.edit, "CENTER")
        bar.input:SetText(tostring(self.model.zoom))
        bar.input:Show()
        bar.input:SetFocus()
        bar.input:HighlightText()
    end)
    bar.edit:SetScript("OnEnter", function(frame)
        GameTooltip:SetOwner(frame, "ANCHOR_BOTTOM")
        GameTooltip:SetText(private.getLocalisation("CountdownZoomType"))
        GameTooltip:Show()
    end)
    bar.edit:SetScript("OnLeave", function() GameTooltip:Hide() end)
    self.zoomBar = bar
end

local function drawZoom(self, offset, width, changes)
    local bar = self.zoomBar
    local limit = 600
    for _, change in ipairs(changes) do
        if Countdown.IsFinite(change.start) then limit = math.max(limit, change.start) end
    end
    self.zoomLimit = math.max(limit, self.model.zoom)
    local function position(time) return width * (1 - math.log(1 + time) / math.log(1 + self.zoomLimit)) end
    local left, right = position(self.model.zoom), position(self.model.viewEnd or 0)
    if right - left < 20 then
        left = math.max(0, math.min(width - 20, (left + right) / 2 - 10))
        right = left + 20
    end
    ThemeApply.FontRole(bar.label, "Control")
    bar.label:SetText(private.getLocalisation("CountdownZoom"))
    bar.label:ClearAllPoints()
    bar.label:SetPoint("LEFT", self.frame, "TOPLEFT", 2, -offset - 8)
    bar.label:SetWidth(labelWidth - 8)
    bar.label:SetJustifyH("LEFT")
    bar.label:SetWordWrap(true)
    bar.track:ClearAllPoints()
    bar.track:SetPoint("LEFT", self.frame, "TOPLEFT", labelWidth, -offset - 8)
    bar.track:SetSize(width, 20)
    ThemeApply.Solid(bar.fill, ThemeApply.Color("Track"))
    bar.thumb:ClearAllPoints()
    bar.thumb:SetPoint("LEFT", bar.track, "LEFT", left, 0)
    bar.thumb:SetSize(math.max(1, right - left), 20)
    ThemeApply.Solid(bar.thumb.fill, ThemeApply.Color("Muted"))
    for edge, handle in pairs(bar.handles) do
        handle:ClearAllPoints()
        handle:SetPoint("CENTER", bar.track, "LEFT", edge == "start" and left or right, 0)
        handle.art:SetTexture(ThemeApply.File("circle"))
        handle.art:SetVertexColor(ThemeApply.Color("Text"))
    end
    ThemeApply.FontRole(bar.caption, "Muted")
    bar.input:SetFontObject(ThemeApply.FontObject("Control"))
    bar.input:SetTextColor(ThemeApply.FontObject("Control"):GetTextColor())
    private.ThemedWidgets.DrawField(bar.input.AtField)
    local from = string.format(private.getLocalisation("CountdownSeconds"), self.model.zoom)
    local to = self.model.viewEnd or 0
    bar.caption:SetText(to == 0 and string.format(private.getLocalisation("CountdownZoomFinal"), from) or
        string.format(private.getLocalisation("CountdownZoomRange"), from, string.format(private.getLocalisation("CountdownSeconds"), to)))
    bar.caption:ClearAllPoints()
    bar.caption:SetPoint("TOPLEFT", bar.track, "BOTTOMLEFT", 0, -2)
    bar.caption:SetWidth(width)
    bar.caption:SetJustifyH("CENTER")
    bar.caption:SetWordWrap(true)
    return math.max(48, 24 + bar.caption:GetStringHeight())
end

local function finishDrag(self)
    if not self.drag then return end
    local drag = self.drag
    self.drag = nil
    self.frame:SetScript("OnUpdate", nil)
    self:Fire("OnChanged", true)
    if not drag.moved then self:Fire("OnSelect", drag.property, drag.id, drag.lastTime) end
end

local function button(self, index)
    local item = self.buttons[index]
    if item then return item end
    item = CreateFrame("Button", nil, self.frame)
    item.fill = item:CreateTexture(nil, "BACKGROUND")
    item.fill:SetAllPoints(item)
    item.line = item:CreateTexture(nil, "OVERLAY")
    item.line:SetPoint("TOPLEFT")
    item.line:SetPoint("TOPRIGHT")
    item.line:SetHeight(2)
    item.text = item:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    item.text:SetPoint("CENTER")
    item.text:SetWordWrap(false)
    item:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    item:SetScript("OnClick", function(frame, key)
        if frame.handle or self.justDragged then self.justDragged = nil; return end
        local id = frame.change and frame.change.id
        if key == "RightButton" then id = nil
        elseif not id then self:Fire("OnSelectBase", frame.property, frame.displays, cursorTime(self)); return end
        self:Fire("OnSelect", frame.property, id, cursorTime(self), frame.display)
    end)
    item:SetScript("OnMouseDown", function(frame, key)
        if key ~= "LeftButton" or not frame.handle then return end
        self.drag = { id = frame.change.id, edge = frame.edge, property = frame.property, lastTime = cursorTime(self) }
        self.frame:SetScript("OnUpdate", function()
            if not IsMouseButtonDown("LeftButton") then
                self.justDragged = true
                finishDrag(self)
                return
            end
            local time = cursorTime(self)
            if time ~= self.drag.lastTime then
                self.drag.moved, self.drag.lastTime = true, time
                self:Fire("OnDrag", self.drag.id, self.drag.edge, time)
                self:Draw()
            end
        end)
    end)
    item:SetScript("OnMouseUp", function(_, key)
        if key == "LeftButton" and self.drag then self.justDragged = true; finishDrag(self) end
    end)
    item:SetScript("OnEnter", function(frame)
        if not frame.description then return end
        GameTooltip:SetOwner(frame, "ANCHOR_TOP")
        GameTooltip:SetText(frame.description)
        GameTooltip:Show()
    end)
    item:SetScript("OnLeave", function() GameTooltip:Hide() end)
    self.buttons[index] = item
    return item
end

local function selectionBoundaries(selection, duration, zoom, viewEnd, boundaries)
    if not selection then return end
    if not selection.any and (selection.field == "remaining" or (selection.field == "elapsed" or selection.field == "duration") and Countdown.IsFinite(duration)) then
        for _, key in ipairs({ "value", "upper" }) do
            local time = selection[key]
            if Countdown.IsFinite(time) then
                if selection.field == "elapsed" then time = duration - time end
                if time > viewEnd and time < zoom and (selection.field ~= "duration" or time >= duration) then table.insert(boundaries, time) end
            end
        end
    end
    if selection.child then selectionBoundaries(selection.child, duration, zoom, viewEnd, boundaries) end
    for _, child in ipairs(selection.children or {}) do selectionBoundaries(child, duration, zoom, viewEnd, boundaries) end
end

local function Draw(self)
    local model = self.model
    if not model or self.drawing then return end
    self.drawing = true
    local width = math.max(1, self.frame:GetWidth() - labelWidth - 8)
    local used = 0
    for _, item in ipairs(self.buttons) do item:Hide() end
    local changes = model.Changes()
    local own = {}
    for _, change in ipairs(changes) do own[change.id] = true end
    local displays = model.display == "Shared" and Countdown.Displays or { model.display }
    local viewEnd = model.viewEnd or 0
    local span = model.zoom - viewEnd
    local offset = 28
    wipe(self.rows)
    for index, property in ipairs(model.lanes) do
        local y = -offset
        self.labels[index] = self.labels[index] or self.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        local label = self.labels[index]
        ThemeApply.FontRole(label, "Control")
        label:SetWidth(labelWidth - 8)
        label:SetJustifyH("LEFT")
        label:SetText(model.Label(property))
        label:SetWordWrap(true)
        local boundaries = { viewEnd, model.zoom }
        -- times an unchanged look changes at, like a glow only "when close"
        for _, time in ipairs(model.Boundaries and model.Boundaries(property) or {}) do
            if time > viewEnd and time < model.zoom then table.insert(boundaries, time) end
        end
        -- a reminder's or boss timer rule's lanes also split where the shared lanes they sit on change
        for _, list in ipairs({ changes, model.Inherited or {} }) do
            for _, change in ipairs(list) do
                if model.context.previewChange and model.context.previewChange.id == change.id then change = model.context.previewChange end
                if change.property == property and change.enabled ~= false then
                    if change.start > viewEnd and change.start < model.zoom then table.insert(boundaries, change.start) end
                    if change.finish and change.finish > viewEnd and change.finish < model.zoom then table.insert(boundaries, change.finish) end
                    selectionBoundaries(change.selection, model.context.previewDuration or model.context.duration, model.zoom, viewEnd, boundaries)
                end
            end
        end
        table.sort(boundaries, function(a, b) return a > b end)
        -- displays that resolve to the same change share a strip, a segment only splits where they differ
        local segments, strips = {}, 1
        for i = 1, #boundaries - 1 do
            local from, to = boundaries[i], boundaries[i + 1]
            if from > to then
                -- a shallow copy keeps an item's change list itself, so its compiled lanes are reused
                local context = {}
                for key, value in pairs(model.context) do context[key] = value end
                context.remaining = (from + to) / 2
                context.duration = math.max(context.previewDuration or context.duration, context.remaining)
                context.elapsed = math.max(0, context.duration - context.remaining)
                local groups = {}
                for _, shown in ipairs(#displays > 1 and Countdown.DisplaysOf(property) or displays) do
                    local style, origins = Countdown.Resolve(shown, context)
                    local group
                    local base = not origins[property] and model.BaseKey(property, shown, style) or nil
                    for _, existing in ipairs(groups) do if existing.change == origins[property] and existing.base == base then group = existing end end
                    if not group then
                        group = { change = origins[property], base = base, value = style[property], display = shown, names = {}, displays = {} }
                        groups[#groups + 1] = group
                    end
                    table.insert(group.names, model.Displays[shown])
                    table.insert(group.displays, shown)
                end
                segments[#segments + 1] = { from = from, to = to, groups = groups }
                strips = math.max(strips, #groups)
            end
        end
        local height = math.max(rowHeight, label:GetStringHeight() + 12, strips * 24 + 10)
        label:ClearAllPoints()
        label:SetPoint("LEFT", self.frame, "TOPLEFT", 2, y - (height - 12) / 2)
        label:Show()
        self.rows[index] = { y = y, height = height }
        for _, segment in ipairs(segments) do
            local count = #segment.groups
            local stripHeight = (height - 12 - (count - 1) * 2) / count
            for position, group in ipairs(segment.groups) do
                used = used + 1
                local item = button(self, used)
                item.handle, item.edge, item.property, item.change = nil, nil, property, group.change
                item.display, item.displays = count > 1 and group.display or nil, group.displays
                item.fill:ClearAllPoints()
                item.fill:SetAllPoints(item)
                item:ClearAllPoints()
                item:SetPoint("TOPLEFT", self.frame, "TOPLEFT", labelWidth + (model.zoom - segment.from) / span * width, y - (position - 1) * (stripHeight + 2))
                item:SetSize(math.max(1, (segment.from - segment.to) / span * width), stripHeight)
                local isColor = property == "color"
                -- a shared section under an item's lanes is drawn like an unchanged look, clicking it adds the item's own
                local changed = group.change and own[group.change.id]
                local color = isColor and (group.value or Countdown.BaseColor(group.display)) or (changed and "Accent" or "Muted")
                local r, g, b = ThemeApply.Color(color)
                ThemeApply.Solid(item.fill, r, g, b, changed and 0.3 or 0.15)
                ThemeApply.Solid(item.line, ThemeApply.Color("Accent"))
                local default = model.base
                item.line:SetShown(group.change ~= nil and group.change.id == model.selected or
                    not group.change and default ~= nil and default.property == property and default.displays[group.display] == true)
                ThemeApply.FontRole(item.text, "Control")
                item.text:SetWidth(math.max(1, item:GetWidth() - 8))
                local raw = group.value
                if raw == nil then raw = property == "shown" and "auto" or false end
                local value = model.Label(property, raw)
                local names = count > 1 and table.concat(group.names, ", ") or nil
                local text = isColor and (names or "") or names and names .. ": " .. value or value
                item.text:SetText(item:GetWidth() > 65 and text or "")
                if isColor then
                    item.description = string.format(private.getLocalisation("CountdownLaneTiming"), model.Label(property), segment.from, segment.to)
                else
                    item.description = string.format(private.getLocalisation("CountdownLaneSection"), model.Label(property), value, segment.from, segment.to)
                end
                if names then item.description = names .. "\n" .. item.description end
                item:Show()
            end
        end
        for _, change in ipairs(changes) do
            if change.property == property and change.enabled ~= false then
                for _, edge in ipairs({ "start", "finish" }) do
                    local time = change[edge]
                    if time and time > 0 and time >= viewEnd and time <= model.zoom and not change.advanced and (edge == "start" or change.id == model.selected) then
                        used = used + 1
                        local item = button(self, used)
                        item.handle, item.edge, item.property, item.change, item.display = true, edge, property, change, nil
                        item:ClearAllPoints()
                        item:SetPoint("TOP", self.frame, "TOPLEFT", labelWidth + (model.zoom - time) / span * width, y + 3)
                        item:SetSize(12, height - 6)
                        ThemeApply.Solid(item.fill, ThemeApply.Color("Accent"))
                        item.fill:ClearAllPoints()
                        item.fill:SetPoint("TOP", item, "TOP")
                        item.fill:SetPoint("BOTTOM", item, "BOTTOM")
                        item.fill:SetWidth(2)
                        item.line:Hide()
                        item.text:SetText("")
                        item.description = string.format(private.getLocalisation(edge == "start" and "CountdownStartsAt" or "CountdownEndsAt"), time)
                        item:Show()
                    end
                end
            end
        end
        offset = offset + height
    end
    for index = #model.lanes + 1, #self.labels do self.labels[index]:Hide() end
    for i, tick in ipairs(self.ticks) do
        ThemeApply.FontRole(tick, "Muted")
        tick:SetText(i == 3 and viewEnd == 0 and private.getLocalisation("CountdownAbility") or
            string.format(private.getLocalisation("CountdownSeconds"), i == 1 and model.zoom or i == 3 and viewEnd or (model.zoom + viewEnd) / 2))
    end
    self.ticks[1]:SetPoint("TOPLEFT", self.frame, "TOPLEFT", labelWidth, -4)
    self.ticks[2]:SetPoint("TOP", self.frame, "TOPLEFT", labelWidth + width / 2, -4)
    self.ticks[3]:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", -8, -4)
    self:SetHeight(offset + drawZoom(self, offset, width, changes))
    self:SetTime(model.context.remaining)
    self.drawing = nil
end

local function Constructor()
    local frame = CreateFrame("Frame", nil, UIParent)
    frame:Hide()
    local playhead = CreateFrame("Frame", nil, frame)
    playhead:SetFrameLevel(frame:GetFrameLevel() + 5)
    playhead.Line = playhead:CreateTexture(nil, "OVERLAY")
    playhead.Line:SetAllPoints(playhead)
    playhead.Cap = playhead:CreateTexture(nil, "OVERLAY")
    playhead.Cap:SetPoint("BOTTOM", playhead, "TOP")
    playhead.Cap:SetSize(8, 5)
    playhead:Hide()
    local widget = {
        type = Type, frame = frame, buttons = {}, labels = {}, ticks = {}, playhead = playhead, rows = {}, Draw = Draw, SetTime = SetTime, SetView = SetView, ApplySettings = Draw, OnWidthSet = Draw,
        OnAcquire = function(self) self:SetFullWidth(true); self:SetHeight(200) end,
        OnRelease = function(self)
            self.frame:SetScript("OnUpdate", nil)
            self.zoomBar.input:Hide()
            self.model, self.drag, self.zoomDrag, self.justDragged = nil, nil, nil, nil
            GameTooltip:Hide()
        end,
        Setup = function(self, model) self.model = model; self:Draw() end,
    }
    zoomBar(widget)
    for i = 1, 3 do widget.ticks[i] = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight") end
    private.RegisterThemed(widget)
    return AceGUI:RegisterAsWidget(widget)
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)
