local appName, app = ...
---@class AbilityTimeline
local private = app
local AceGUI = LibStub("AceGUI-3.0")
local SharedMedia = LibStub("LibSharedMedia-3.0")
local CustomNames = C_AddOns.IsAddOnLoaded("CustomNames") and LibStub("CustomNames", true)
local ThemeApply = private.ThemeApply
local ThemedWidgets = private.ThemedWidgets
local L = private.getLocalisation
local issecretvalue = issecretvalue or function() return false end
-- the editor also opens from a link in chat, on every client
local hasMenus = MenuUtil and MenuUtil.CreateContextMenu
local getSpellName = function(spellId)
    if C_Spell.GetSpellName then
        return C_Spell.GetSpellName(spellId)
    end
    local spellInfo = C_Spell.GetSpellInfo(spellId)
    return spellInfo and spellInfo.name
end

-- the timings editor: a timeline per boss mod stage with a row for each who a reminder is for, the selected reminder
-- is edited in the panel on the right
local Type = "AtTimingsEditorDataFrame"
local Version = 3
local variables = {
    width = 1100,
    height = 640,
    padding = 12,
    gap = 6,
    groupGap = 18,
    toolbarHeight = 26,
    tabHeight = 24,
    tabWidth = 96,
    closeSize = 12,
    arrowWidth = 22,
    labelWidth = 130,
    inspectorWidth = 340,
    headerHeight = 40,
    headerIcon = 30,
    rulerHeight = 22,
    laneHeight = 28,
    rowPadding = 4,
    pinSize = 22,
    textPinMaxWidth = 120,
    defaultPixelsPerSecond = 12,
    maxPixelsPerSecond = 60,
    tickSpacing = 70,
    tickSteps = { 1, 2, 5, 10, 15, 30, 60, 120, 300 },
    snap = 0.5,
    -- how far the pointer moves before a pressed reminder is dragged instead of clicked
    dragThreshold = 4,
    scrollBarSize = 8,
    footerHeight = 34,
    lengthWidth = 70,
    onlyMineWidth = 120,
    minLength = 60,
    lengthMargin = 30,
    undoSteps = 50,
    -- typing into the same field within this time is one undo step
    undoMergeTime = 2,
    suggestions = 8,
    iconSize = 18,
}

local SEVERITIES = { [0] = "EditorSeverityInfo", [1] = "EditorSeverityAlert", [2] = "EditorSeverityCritical" }
local EFFECTS = {
    { bit = 1, key = "DeadlyEffect" },
    { bit = 2, key = "EnrageEffect" },
    { bit = 4, key = "BleedEffect" },
    { bit = 8, key = "MagicEffect" },
    { bit = 16, key = "DiseaseEffect" },
    { bit = 32, key = "CurseEffect" },
    { bit = 64, key = "PoisonEffect" },
    { bit = 128, key = "TankRole" },
    { bit = 256, key = "HealerRole" },
    { bit = 512, key = "DpsRole" },
}
local DISPLAYS = {
    { key = "timeline", name = "EditorShowTimeline" },
    { key = "bigIcon", name = "EditorShowBigIcon" },
    { key = "textHighlight", name = "EditorShowTextHighlight" },
}
local INSPECTOR_TABS = { "basics", "look", "sound" }
-- the words a reminder's "for" knows besides names and classes (Util/ImportUtil.lua DoesTagApplyToPlayer)
local TAG_WORDS = { "everyone", "tank", "healer", "damager", "melee", "ranged" }
local NONE = "NONE"

---@param seconds number
---@return string
local formatTime = function(seconds)
    local minutes = math.floor(seconds / 60)
    local rest = seconds - minutes * 60
    if rest == math.floor(rest) then
        return string.format("%d:%02d", minutes, rest)
    end
    return string.format("%d:%04.1f", minutes, rest)
end

---@param text string
---@return number|nil -- seconds from "75", "1:15" or "1:15.5"
local parseTime = function(text)
    local minutes, seconds = strtrim(text):match("^(%d+):(%d+%.?%d*)$")
    if minutes then
        return tonumber(minutes) * 60 + tonumber(seconds)
    end
    local value = tonumber(text)
    return value and value >= 0 and value or nil
end

local copyReminder = function(reminder)
    local copy = {}
    for key, value in pairs(reminder) do
        copy[key] = type(value) == "table" and CopyTable(value) or value
    end
    return copy
end

---@param reminder table
---@return number
local stageOf = function(reminder)
    return tonumber(reminder.phase) or 1
end

---@param reminder table
---@return string
local tagOf = function(reminder)
    return reminder.tag and reminder.tag ~= "" and reminder.tag or "everyone"
end

---@param reminder table
---@return boolean
local isTextReminder = function(reminder)
    return not reminder.spellId or reminder.spellId <= 0
end

---@param reminder table
---@return number|string
local getTexture = function(reminder)
    local spellId = reminder.spellId or 0
    return spellId > 0 and C_Spell.GetSpellTexture(spellId) or reminder.iconId or 134400
end

---@param class string|nil
---@return string -- the class name in its color
local coloredClassName = function(class)
    local color = class and RAID_CLASS_COLORS[class]
    local name = class and LOCALIZED_CLASS_NAMES_MALE[class] or class or ""
    return color and color:WrapTextInColorCode(name) or name
end

---the class of a cooldown in its color, or its specs when only one or two have it (Ascendance of each shaman spec)
---@param cooldown table -- a Data/Cooldowns.lua entry
---@return string
local specsName = function(cooldown)
    local color = RAID_CLASS_COLORS[cooldown.class]
    if #cooldown.specs <= 2 and GetSpecializationInfoByID then
        local names = {}
        for _, specID in ipairs(cooldown.specs) do
            local _, name = GetSpecializationInfoByID(specID)
            table.insert(names, name)
        end
        if #names > 0 then
            local text = table.concat(names, ", ")
            return color and color:WrapTextInColorCode(text) or text
        end
    end
    return coloredClassName(cooldown.class)
end

---the group's members with their nickname and class
---@return table[] -- { name, nick, class }
local getGroupMembers = function()
    local units = { "player" }
    if IsInRaid() then
        units = {}
        for i = 1, GetNumGroupMembers() do
            table.insert(units, "raid" .. i)
        end
    else
        for i = 1, GetNumSubgroupMembers() do
            table.insert(units, "party" .. i)
        end
    end
    local members = {}
    for _, unit in ipairs(units) do
        local name = UnitName(unit)
        if name and not issecretvalue(name) then
            local nick = CustomNames and CustomNames.UnitName(unit) or name
            local _, class = UnitClass(unit)
            table.insert(members, { name = name, nick = nick, class = class })
        end
    end
    return members
end

---@param name string -- a character name
---@return string
local nicknameOf = function(name)
    if not CustomNames then return name end
    return CustomNames.Get(name)
end

---the character a word of a "for" stands for, a nickname is turned into its character's name
---@param word string
---@return string
local characterOf = function(word)
    if not CustomNames then return word end
    local lower = word:lower()
    for _, member in ipairs(getGroupMembers()) do
        if member.nick:lower() == lower then
            return member.name
        end
    end
    local realm = GetNormalizedRealmName()
    for character, nick in pairs(CustomNames.GetList()) do
        if nick:lower() == lower then
            local name, characterRealm = strsplit("-", character)
            return characterRealm == realm and name or character
        end
    end
    return word
end

---a "for" as it is shown: nicknames for characters
---@param tag string
---@return string
local displayTag = function(tag)
    if tag == "everyone" then
        return L("EditorEveryone")
    end
    local words = {}
    for word in tag:gmatch("%S+") do
        table.insert(words, nicknameOf(word))
    end
    return table.concat(words, " ")
end

---a "for" as it is saved: character names for nicknames
---@param text string
---@return string|nil
local storeTag = function(text)
    local words = {}
    for word in text:gmatch("%S+") do
        table.insert(words, characterOf(word))
    end
    return #words > 0 and table.concat(words, " ") or nil
end

---takes the next of a pool's frames or textures, made by create when there is none left
local acquire = function(pool, create)
    pool.used = (pool.used or 0) + 1
    local item = pool[pool.used]
    if not item then
        item = create()
        pool[pool.used] = item
    end
    item:Show()
    return item
end

---starts taking a pool's items from the first again, they stay shown so a reminder being dragged keeps its pin
local reuse = function(pool)
    pool.used = 0
end

---hides the items of a pool that were not taken again
local trim = function(pool)
    for i = (pool.used or 0) + 1, #pool do
        pool[i]:Hide()
    end
end

---a thin track with a thumb, dragging the thumb or clicking the track calls onScroll with the progress (0 to 1)
---@param parent Frame
---@param horizontal boolean
---@param onScroll fun(progress: number)
---@return Button
local createScrollBar = function(parent, horizontal, onScroll)
    local track = CreateFrame("Button", nil, parent)
    track.horizontal = horizontal
    track.Back = track:CreateTexture(nil, "BACKGROUND")
    track.Back:SetAllPoints(track)
    track.Thumb = track:CreateTexture(nil, "ARTWORK")
    track.thumbStart, track.thumbSize = 0, 0
    local getCursor = function()
        local x, y = GetCursorPosition()
        local scale = track:GetEffectiveScale()
        if horizontal then
            return x / scale - track:GetLeft()
        end
        return track:GetTop() - y / scale
    end
    track:SetScript("OnMouseDown", function()
        local cursor = getCursor()
        local onThumb = cursor >= track.thumbStart and cursor <= track.thumbStart + track.thumbSize
        local grab = onThumb and cursor - track.thumbStart or track.thumbSize / 2
        track:SetScript("OnUpdate", function()
            if not IsMouseButtonDown("LeftButton") then
                track:SetScript("OnUpdate", nil)
                return
            end
            local length = horizontal and track:GetWidth() or track:GetHeight()
            local free = math.max(length - track.thumbSize, 1)
            onScroll(math.max(0, math.min((getCursor() - grab) / free, 1)))
        end)
    end)
    return track
end

---places the thumb for a view of a total, scrolled by offset
---@param track Button
---@param view number
---@param total number
---@param offset number
local drawScrollBar = function(track, view, total, offset)
    local length = track.horizontal and track:GetWidth() or track:GetHeight()
    local size = total > view and math.max(24, length * view / total) or length
    local start = total > view and (length - size) * offset / (total - view) or 0
    track.thumbStart, track.thumbSize = start, size
    track.Thumb:ClearAllPoints()
    if track.horizontal then
        track.Thumb:SetPoint("TOPLEFT", track, "TOPLEFT", start, 0)
        track.Thumb:SetPoint("BOTTOMLEFT", track, "BOTTOMLEFT", start, 0)
        track.Thumb:SetWidth(size)
    else
        track.Thumb:SetPoint("TOPLEFT", track, "TOPLEFT", 0, -start)
        track.Thumb:SetPoint("TOPRIGHT", track, "TOPRIGHT", 0, -start)
        track.Thumb:SetHeight(size)
    end
    track.Thumb:SetAlpha(total > view and 1 or 0.35)
end

---@param parent Frame
---@param text string
---@param onClick function
---@param style string|nil -- Plain, Primary or Danger
---@return Button
local createButton = function(parent, text, onClick, style)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    ThemedWidgets.SkinButton(button)
    button.atStyle = style
    button:SetHeight(variables.toolbarHeight)
    button:SetText(text)
    button:SetWidth(button:GetFontString():GetStringWidth() + 28)
    button:SetScript("OnClick", onClick)
    return button
end

---a square button with the theme's undo arrow, mirrored for redo
---@param parent Frame
---@param mirrored boolean
---@param onClick function
---@return Button
local createIconButton = function(parent, mirrored, onClick)
    local button = createButton(parent, "", onClick)
    button:SetWidth(variables.toolbarHeight + 6)
    button.Icon = button:CreateTexture(nil, "OVERLAY")
    button.Icon:SetTexture(ThemeApply.File("undo"))
    button.Icon:SetSize(variables.iconSize, variables.iconSize)
    button.Icon:SetPoint("CENTER")
    if mirrored then
        button.Icon:SetTexCoord(1, 0, 0, 1)
    end
    return button
end

---@param button Button
---@param enabled boolean
local setButtonEnabled = function(button, enabled)
    button:SetEnabled(enabled)
    button:SetAlpha(enabled and 1 or 0.45)
end

---@param widget table -- an AceGUI widget
---@param key string -- localisation of the tooltip
local addTooltip = function(widget, key)
    widget:SetCallback("OnEnter", function()
        GameTooltip:SetOwner(widget.frame, "ANCHOR_TOPLEFT")
        GameTooltip:AddLine(L(key), 1, 1, 1, true)
        GameTooltip:Show()
    end)
    widget:SetCallback("OnLeave", function()
        GameTooltip:Hide()
    end)
end

---@param self AtTimingsEditorDataFrame
local function SaveReminders(self)
    if not self.encounterID then return end
    local copy = {}
    for _, reminder in ipairs(self.reminders) do
        local stored = copyReminder(reminder)
        -- the journal ids restore the encounter on the reminders page
        stored.journalEncounterID = self.journalEncounterID
        stored.journalInstanceID = self.journalInstanceID
        stored.instanceName = self.instanceName
        stored.encounterName = self.encounterName
        table.insert(copy, stored)
    end
    table.sort(copy, function(a, b)
        return (a.CombatTime or 0) < (b.CombatTime or 0)
    end)
    private.db.profile.reminders[self.encounterID] = copy
    local rules = {}
    for _, rule in ipairs(self.rules) do
        table.insert(rules, copyReminder(rule))
    end
    private.db.profile.timerRules = private.db.profile.timerRules or {}
    private.db.profile.timerRules[self.encounterID] = #rules > 0 and rules or nil
end

---@param self AtTimingsEditorDataFrame
---@return number[]
local getStages = function(self)
    local seen, stages = {}, {}
    local add = function(stage)
        if not seen[stage] then
            seen[stage] = true
            table.insert(stages, stage)
        end
    end
    add(1)
    add(self.stage)
    for _, reminder in ipairs(self.reminders) do
        add(stageOf(reminder))
    end
    for stage in pairs(self.extraStages) do
        add(stage)
    end
    table.sort(stages)
    return stages
end

---@param self AtTimingsEditorDataFrame
---@param stage number
---@return number
local countStage = function(self, stage)
    local count = 0
    for _, reminder in ipairs(self.reminders) do
        if stageOf(reminder) == stage then
            count = count + 1
        end
    end
    return count
end

---@param self AtTimingsEditorDataFrame
---@return number -- seconds the open stage's timeline shows
local getLength = function(self)
    local length = math.max(self.length or 0, variables.minLength)
    for _, reminder in ipairs(self.reminders) do
        if stageOf(reminder) == self.stage then
            local stays = tonumber(reminder.CombatTimeDelay) or 0
            length = math.max(length, (reminder.CombatTime or 0) + stays + variables.lengthMargin)
        end
    end
    return length
end

---@param self AtTimingsEditorDataFrame
---@return number
local getPixelsPerSecond = function(self)
    -- never less than the whole stage fitting in
    local fit = math.max(self.canvas:GetWidth() - variables.pinSize, 1) / getLength(self)
    return math.max(fit, math.min(self.pixelsPerSecond, variables.maxPixelsPerSecond))
end

---@param self AtTimingsEditorDataFrame
---@return number -- the furthest the rows scroll
local getMaxRowScroll = function(self)
    return math.max(0, (self.contentHeight or 0) - self.rows:GetHeight())
end

---@param self AtTimingsEditorDataFrame
---@return number -- the furthest the timeline scrolls
local getMaxScroll = function(self)
    return math.max(0, getLength(self) * getPixelsPerSecond(self) + variables.pinSize - self.canvas:GetWidth())
end

---@param self AtTimingsEditorDataFrame
---@return number -- seconds at the cursor
local getCursorTime = function(self)
    local x = GetCursorPosition() / self.canvas:GetEffectiveScale() - self.canvas:GetLeft() + self.scroll -
        variables.pinSize / 2
    return x / getPixelsPerSecond(self)
end

---@param time number
---@return number
local snapTime = function(time)
    return math.max(0, math.floor(time / variables.snap + 0.5) * variables.snap)
end

local RefreshTimeline, ShowInspector, refreshHeader, refreshView

---@param self AtTimingsEditorDataFrame
local refreshUndoButtons = function(self)
    setButtonEnabled(self.undoButton, #self.undoStack > 0)
    setButtonEnabled(self.redoButton, #self.redoStack > 0)
end

---@param self AtTimingsEditorDataFrame
---@return table
local snapshot = function(self)
    local copyList = function(list)
        local copy, selected = {}, nil
        for i, item in ipairs(list) do
            copy[i] = copyReminder(item)
            if item == self.selected then
                selected = i
            end
        end
        return copy, selected
    end
    local reminders, selectedReminder = copyList(self.reminders)
    local rules, selectedRule = copyList(self.rules)
    return {
        reminders = reminders,
        rules = rules,
        selected = selectedReminder or selectedRule,
        mode = self.mode,
        stage = self.stage,
        extraStages = CopyTable(self.extraStages),
    }
end

---remembers the reminders before a change so it can be undone, changes of one field in a row are one step
---@param self AtTimingsEditorDataFrame
---@param key string|nil -- what is changed, nil for changes that are always their own step
local record = function(self, key)
    local now = GetTime()
    if key and key == self.lastRecord and now - self.lastRecordTime < variables.undoMergeTime then
        self.lastRecordTime = now
        return
    end
    self.lastRecord, self.lastRecordTime = key, now
    table.insert(self.undoStack, snapshot(self))
    if #self.undoStack > variables.undoSteps then
        table.remove(self.undoStack, 1)
    end
    wipe(self.redoStack)
    refreshUndoButtons(self)
end

local Select

---@param self AtTimingsEditorDataFrame
---@param state table
local restore = function(self, state)
    self.reminders = state.reminders
    self.rules = state.rules
    self.mode = state.mode
    self.extraStages = state.extraStages
    self.stage = state.stage
    self.lastRecord = nil
    SaveReminders(self)
    local selected = state.selected and (self.mode == "rules" and self.rules or self.reminders)[state.selected]
    Select(self, selected)
    refreshUndoButtons(self)
end

---@param self AtTimingsEditorDataFrame
local undo = function(self)
    local state = table.remove(self.undoStack)
    if not state then return end
    table.insert(self.redoStack, snapshot(self))
    restore(self, state)
end

---@param self AtTimingsEditorDataFrame
local redo = function(self)
    local state = table.remove(self.redoStack)
    if not state then return end
    table.insert(self.undoStack, snapshot(self))
    restore(self, state)
end

---@param self AtTimingsEditorDataFrame
---@param reminder table|nil -- a reminder, or a boss timer rule on the Boss timers tab
Select = function(self, reminder)
    self.selected = reminder
    if reminder and self.mode ~= "rules" then
        self.stage = stageOf(reminder)
        -- a reminder selected out of view is scrolled to
        local x = (reminder.CombatTime or 0) * getPixelsPerSecond(self)
        local width = self.canvas:GetWidth()
        if x < self.scroll or x > self.scroll + width - variables.pinSize then
            self.scroll = x - width / 3
        end
    end
    self:RefreshTabs()
    refreshView(self)
    ShowInspector(self)
end

---the reminder changed in the panel or by dragging
---@param self AtTimingsEditorDataFrame
local changed = function(self)
    SaveReminders(self)
    refreshView(self)
    refreshHeader(self)
end

---changes the selected reminder, typing into one field (key) is one undo step, a change without key always its own
---@param self AtTimingsEditorDataFrame
---@param key string|nil
---@param apply fun(reminder: table)
local update = function(self, key, apply)
    local reminder = self.selected
    if not reminder then return end
    record(self, key and key .. tostring(reminder))
    apply(reminder)
    changed(self)
end

---@param self AtTimingsEditorDataFrame
---@param time number
---@param tag string|nil
local addReminder = function(self, time, tag)
    record(self)
    local reminder = {
        text = L("EditorNewReminder"),
        spellId = 0,
        iconId = 134400,
        CombatTime = time,
        CombatTimeDelay = 0,
        StartTimerAfter = 0,
        severity = 1,
        effectTypes = 0,
        phase = self.stage,
        tag = tag ~= "everyone" and tag or nil,
    }
    table.insert(self.reminders, reminder)
    SaveReminders(self)
    self.inspectorTab = "basics"
    Select(self, reminder)
    if self.textBox then
        self.textBox:SetFocus()
        self.textBox.editbox:HighlightText()
    end
    private.OnTourEvent("reminderAdded")
end

---@param self AtTimingsEditorDataFrame
local addRule = function(self)
    record(self)
    local rule = { match = "spell", value = "" }
    table.insert(self.rules, rule)
    SaveReminders(self)
    self.inspectorTab = "basics"
    Select(self, rule)
    if self.textBox then
        self.textBox:SetFocus()
    end
end

---@param self AtTimingsEditorDataFrame
local duplicateSelected = function(self)
    if not self.selected then return end
    record(self)
    local copy = copyReminder(self.selected)
    if self.mode == "rules" then
        table.insert(self.rules, copy)
    else
        copy.CombatTime = (copy.CombatTime or 0) + 5
        table.insert(self.reminders, copy)
    end
    SaveReminders(self)
    Select(self, copy)
end

---@param self AtTimingsEditorDataFrame
local deleteSelected = function(self)
    if not self.selected then return end
    record(self)
    tDeleteItem(self.mode == "rules" and self.rules or self.reminders, self.selected)
    SaveReminders(self)
    Select(self, nil)
end

---moves every reminder of a stage to another
---@param self AtTimingsEditorDataFrame
---@param from number
---@param to number
local moveStage = function(self, from, to)
    record(self)
    for _, reminder in ipairs(self.reminders) do
        if stageOf(reminder) == from then
            reminder.phase = to
        end
    end
    self.extraStages[from] = nil
    self.stage = to
    SaveReminders(self)
    Select(self, self.selected and stageOf(self.selected) == to and self.selected or nil)
end

---@param self AtTimingsEditorDataFrame
---@param stage number
local deleteStage = function(self, stage)
    record(self)
    for i = #self.reminders, 1, -1 do
        if stageOf(self.reminders[i]) == stage then
            table.remove(self.reminders, i)
        end
    end
    self.extraStages[stage] = nil
    if self.stage == stage then
        self.stage = 1
    end
    SaveReminders(self)
    Select(self, nil)
end

---removes a stage, its reminders are moved to another one or deleted as the player picks
---@param self AtTimingsEditorDataFrame
---@param stage number
---@param owner Region
local removeStage = function(self, stage, owner)
    local count = countStage(self, stage)
    if count > 0 and not hasMenus then
        moveStage(self, stage, 1)
        return
    end
    if count == 0 then
        record(self)
        self.extraStages[stage] = nil
        if self.stage == stage then
            self.stage = 1
        end
        Select(self, nil)
        return
    end
    MenuUtil.CreateContextMenu(owner, function(_, rootDescription)
        rootDescription:CreateTitle(L("EditorRemoveStage"):format(tostring(stage), count))
        for _, target in ipairs(getStages(self)) do
            if target ~= stage then
                rootDescription:CreateButton(L("EditorRemoveStageMove"):format(tostring(target)), function()
                    moveStage(self, stage, target)
                end)
            end
        end
        rootDescription:CreateButton(L("EditorRemoveStageDelete"), function()
            deleteStage(self, stage)
        end)
    end)
end

---@param pin Button
local drawPin = function(pin)
    local selected, hover = pin.selected and 1 or 0, pin.hover and 1 or 0
    local isText = pin.isText
    pin.AtFill:SetVertexColor(ThemeApply.MixColor("Track", "FieldHover", hover, isText and 1 or 0, isText and 1 or 0))
    pin.AtEdge:SetVertexColor(ThemeApply.MixColor("Edge", "Accent", math.max(selected, hover * 0.6)))
    pin.Line:SetColorTexture(ThemeApply.Color(pin.selected and "Accent" or "Accent2", pin.selected and 0.9 or 0.45))
    pin.Delay:SetColorTexture(ThemeApply.Color("Accent2", 0.35))
    ThemeApply.FontRole(pin.Text, "Control")
    local color = pin.reminder and private.GetUsedColor(pin.reminder)
    if color then
        pin.Text:SetTextColor(color.r, color.g, color.b)
    end
end

---ends dragging a reminder, a press that did not move it only selected it
---@param self AtTimingsEditorDataFrame
local finishDrag = function(self)
    local dragging = self.dragging
    self.dragging = nil
    self.rows:SetScript("OnUpdate", nil)
    if dragging and dragging.moved then
        changed(self)
        ShowInspector(self)
        private.OnTourEvent("reminderMoved")
    end
end

---moves the dragged reminder to the time under the pointer, near an edge the timeline scrolls along
---@param self AtTimingsEditorDataFrame
local updateDrag = function(self)
    local dragging = self.dragging
    if not dragging or not IsMouseButtonDown("LeftButton") then
        finishDrag(self)
        return
    end
    local scale = self.canvas:GetEffectiveScale()
    local x = GetCursorPosition() / scale
    if not dragging.moved then
        if math.abs(x - dragging.startX) < variables.dragThreshold then return end
        dragging.moved = true
        record(self)
    end
    local canvasX, width = x - self.canvas:GetLeft(), self.canvas:GetWidth()
    if canvasX < variables.pinSize then
        self.scroll = math.max(0, self.scroll - variables.pinSize / 2)
    elseif canvasX > width - variables.pinSize then
        self.scroll = math.min(getMaxScroll(self), self.scroll + variables.pinSize / 2)
    end
    local time = snapTime(getCursorTime(self) - dragging.offset)
    if time ~= dragging.reminder.CombatTime or dragging.scroll ~= self.scroll then
        dragging.reminder.CombatTime = time
        dragging.scroll = self.scroll
        RefreshTimeline(self)
    end
end

---@param self AtTimingsEditorDataFrame
---@return Button
local createPin = function(self)
    local canvas = self.rows
    local pin = CreateFrame("Button", nil, canvas)
    pin:SetHeight(variables.pinSize)
    pin:SetFrameLevel(canvas:GetFrameLevel() + 5)
    ThemeApply.CreatePanel(pin)
    pin.Icon = pin:CreateTexture(nil, "ARTWORK")
    pin.Icon:SetPoint("TOPLEFT", 1, -1)
    pin.Icon:SetPoint("BOTTOMLEFT", 1, 1)
    pin.Icon:SetWidth(variables.pinSize - 2)
    pin.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    pin.Text = pin:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    pin.Text:SetPoint("LEFT", 6, 0)
    pin.Text:SetWordWrap(false)
    pin.Text:SetJustifyH("LEFT")
    -- the line from the top of its row marks the exact time, the bar how long it stays after 0
    pin.Line = canvas:CreateTexture(nil, "BORDER")
    pin.Line:SetWidth(1)
    pin.Delay = canvas:CreateTexture(nil, "BORDER")
    pin.Delay:SetHeight(3)
    pin:HookScript("OnHide", function()
        pin.Line:Hide()
        pin.Delay:Hide()
    end)
    -- pressing selects, moving the pointer while pressed drags it in time
    pin:SetScript("OnMouseDown", function(_, button)
        if button ~= "LeftButton" then return end
        local reminder = pin.reminder
        self.dragging = {
            reminder = reminder,
            offset = getCursorTime(self) - (reminder.CombatTime or 0),
            startX = GetCursorPosition() / self.canvas:GetEffectiveScale(),
            scroll = self.scroll,
        }
        GameTooltip:Hide()
        if self.selected ~= reminder then
            Select(self, reminder)
        end
        self.rows:SetScript("OnUpdate", function()
            updateDrag(self)
        end)
    end)
    pin:SetScript("OnMouseUp", function()
        finishDrag(self)
    end)
    pin:SetScript("OnEnter", function()
        pin.hover = true
        drawPin(pin)
        if self.dragging then return end
        local reminder = pin.reminder
        GameTooltip:SetOwner(pin, "ANCHOR_TOP")
        GameTooltip:AddLine(private.GetReminderName(reminder) or L("EditorNewReminder"))
        GameTooltip:AddLine(L("EditorTooltipStage"):format(tostring(stageOf(reminder)), formatTime(reminder.CombatTime or 0)),
            1, 1, 1)
        GameTooltip:AddLine(L("EditorTooltipFor"):format(displayTag(tagOf(reminder))), 1, 1, 1)
        GameTooltip:AddLine(L("EditorTooltipDrag"), 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    pin:SetScript("OnLeave", function()
        pin.hover = false
        drawPin(pin)
        GameTooltip:Hide()
    end)
    return pin
end

---@param self AtTimingsEditorDataFrame
local refreshScrollBars = function(self)
    local width, height = self.canvas:GetWidth(), self.rows:GetHeight()
    drawScrollBar(self.scrollX, width, width + getMaxScroll(self), self.scroll)
    drawScrollBar(self.scrollY, height, math.max(self.contentHeight or 0, height), self.rowScroll)
end

---@param self AtTimingsEditorDataFrame
---@param scroll number
local setScroll = function(self, scroll)
    self.scroll = math.max(0, math.min(scroll, getMaxScroll(self)))
    RefreshTimeline(self)
end

---@param self AtTimingsEditorDataFrame
---@param scroll number
local setRowScroll = function(self, scroll)
    self.rowScroll = math.max(0, math.min(scroll, getMaxRowScroll(self)))
    RefreshTimeline(self)
end

---draws the rows, pins and ruler of the open stage
---@param self AtTimingsEditorDataFrame
RefreshTimeline = function(self)
    local canvas, labels, rowsFrame = self.canvas, self.labels, self.rows
    if canvas:GetWidth() <= 0 or not self.scrollY then return end
    local pools = { self.pins, self.bands, self.gridLines, self.labelTexts, self.rulerTexts }
    for _, pool in ipairs(pools) do
        reuse(pool)
    end
    wipe(self.rowSpans)
    self.scroll = math.max(0, math.min(self.scroll, getMaxScroll(self)))

    local pixelsPerSecond = getPixelsPerSecond(self)
    local length = getLength(self)
    local scroll = self.scroll
    local onlyMine = self.onlyMine:GetValue()

    local rows, rowList = {}, {}
    local addRow = function(tag)
        if not rows[tag] then
            rows[tag] = { tag = tag, pins = {}, lanes = {} }
            table.insert(rowList, rows[tag])
        end
        return rows[tag]
    end
    local stageReminders = {}
    for _, reminder in ipairs(self.reminders) do
        if stageOf(reminder) == self.stage then
            table.insert(stageReminders, reminder)
        end
    end
    table.sort(stageReminders, function(a, b)
        return (a.CombatTime or 0) < (b.CombatTime or 0)
    end)
    addRow("everyone")
    for _, reminder in ipairs(stageReminders) do
        local row = addRow(tagOf(reminder))
        local pin = acquire(self.pins, function() return createPin(self) end)
        pin.reminder = reminder
        pin.selected = reminder == self.selected
        pin.isText = isTextReminder(reminder)
        pin.Icon:SetShown(not pin.isText)
        pin.Text:SetShown(pin.isText)
        if pin.isText then
            pin.Text:SetText(private.GetReminderName(reminder) or "")
            ThemeApply.FontRole(pin.Text, "Control")
            pin:SetWidth(math.min(pin.Text:GetStringWidth() + 12, variables.textPinMaxWidth))
            pin.Text:SetPoint("RIGHT", -6, 0)
        else
            pin.Icon:SetTexture(getTexture(reminder))
            pin:SetWidth(variables.pinSize)
        end
        -- pins that would overlap go to the next lane of their row
        local x = (reminder.CombatTime or 0) * pixelsPerSecond
        local lane = 1
        while row.lanes[lane] and row.lanes[lane] > x - 2 do
            lane = lane + 1
        end
        row.lanes[lane] = x + pin:GetWidth()
        pin.lane, pin.x = lane, x
        table.insert(row.pins, pin)
    end
    table.sort(rowList, function(a, b)
        if a.tag == "everyone" or b.tag == "everyone" then
            return a.tag == "everyone" and b.tag ~= "everyone"
        end
        return displayTag(a.tag):lower() < displayTag(b.tag):lower()
    end)

    -- the rows scroll below the ruler, which stays
    local contentHeight = 0
    for _, row in ipairs(rowList) do
        row.height = math.max(#row.lanes, 1) * variables.laneHeight + variables.rowPadding * 2
        contentHeight = contentHeight + row.height
    end
    self.contentHeight = contentHeight
    self.rowScroll = math.max(0, math.min(self.rowScroll, getMaxRowScroll(self)))
    local top = -self.rowScroll
    for index, row in ipairs(rowList) do
        local height = row.height
        local dimmed = onlyMine and not private.ImportUtil:DoesTagApplyToPlayer(row.tag)
        table.insert(self.rowSpans, { tag = row.tag, top = top, bottom = top + height })
        if index % 2 == 0 then
            local band = acquire(self.bands, function() return rowsFrame:CreateTexture(nil, "BACKGROUND", nil, 2) end)
            band:ClearAllPoints()
            band:SetPoint("TOPLEFT", rowsFrame, "TOPLEFT", 0, -top)
            band:SetPoint("TOPRIGHT", rowsFrame, "TOPRIGHT", 0, -top)
            band:SetHeight(height)
            band:SetColorTexture(ThemeApply.Color("Highlight"))
        end
        local label = acquire(self.labelTexts, function()
            local text = labels:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            text:SetJustifyH("LEFT")
            text:SetWordWrap(false)
            return text
        end)
        ThemeApply.FontRole(label, "Control")
        label:ClearAllPoints()
        label:SetPoint("TOPLEFT", labels, "TOPLEFT", variables.padding, -top - variables.rowPadding)
        label:SetPoint("RIGHT", labels, "RIGHT", -6, 0)
        label:SetHeight(variables.laneHeight)
        label:SetText(displayTag(row.tag))
        local _, classFile = UnitClass(row.tag)
        local classColor = classFile and RAID_CLASS_COLORS[classFile]
        if classColor then
            label:SetTextColor(classColor.r, classColor.g, classColor.b)
        end
        label:SetAlpha(dimmed and 0.4 or 1)
        for _, pin in ipairs(row.pins) do
            local y = top + variables.rowPadding + (pin.lane - 0.5) * variables.laneHeight
            pin:ClearAllPoints()
            pin:SetPoint("LEFT", rowsFrame, "TOPLEFT", pin.x - scroll + variables.pinSize / 2, -y)
            pin:SetAlpha(dimmed and 0.4 or 1)
            pin.Line:ClearAllPoints()
            pin.Line:SetPoint("TOPLEFT", rowsFrame, "TOPLEFT", pin.x - scroll + variables.pinSize / 2, -top)
            pin.Line:SetHeight(height)
            pin.Line:Show()
            local stays = tonumber(pin.reminder.CombatTimeDelay) or 0
            pin.Delay:SetShown(stays > 0)
            if stays > 0 then
                pin.Delay:ClearAllPoints()
                pin.Delay:SetPoint("TOPLEFT", pin, "BOTTOMLEFT", 0, -1)
                pin.Delay:SetWidth(stays * pixelsPerSecond)
            end
            drawPin(pin)
        end
        top = top + height
    end

    -- the ruler: a time every few seconds and its grid line through the rows
    local step = variables.tickSteps[#variables.tickSteps]
    for _, candidate in ipairs(variables.tickSteps) do
        if candidate * pixelsPerSecond >= variables.tickSpacing then
            step = candidate
            break
        end
    end
    for time = 0, length, step do
        local x = time * pixelsPerSecond - scroll + variables.pinSize / 2
        if x >= -variables.tickSpacing and x <= canvas:GetWidth() + variables.tickSpacing then
            local line = acquire(self.gridLines, function() return canvas:CreateTexture(nil, "BACKGROUND", nil, 3) end)
            line:ClearAllPoints()
            line:SetPoint("TOPLEFT", canvas, "TOPLEFT", x, -variables.rulerHeight + 4)
            line:SetPoint("BOTTOMLEFT", canvas, "BOTTOMLEFT", x, 0)
            line:SetWidth(1)
            line:SetColorTexture(ThemeApply.Color("Edge"))
            local text = acquire(self.rulerTexts, function()
                return canvas:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            end)
            ThemeApply.FontRole(text, "Muted")
            text:ClearAllPoints()
            text:SetPoint("TOPLEFT", canvas, "TOPLEFT", x + 4, -4)
            text:SetText(formatTime(time))
        end
    end
    for _, pool in ipairs(pools) do
        trim(pool)
    end
    self.canvas.Empty:SetShown(#stageReminders == 0)
    refreshScrollBars(self)
end

---@param tab Button
local drawTab = function(tab)
    tab.atStyle = tab.selected and "Primary" or "Plain"
    ThemedWidgets.DrawButton(tab)
    tab.Close:SetShown(tab.removable and (tab.selected or tab:IsMouseOver()))
    tab.Close.Icon:SetVertexColor(ThemeApply.Color(tab.selected and "Black" or "Muted"))
end

---@param self AtTimingsEditorDataFrame
---@return Button
local createTab = function(self)
    local tab = createButton(self.tabStrip, "", function(tab, mouseButton)
        if mouseButton == "RightButton" and hasMenus then
            -- the stages of a note can be numbered other than the boss mod's, all its reminders move at once
            MenuUtil.CreateContextMenu(tab, function(_, rootDescription)
                rootDescription:CreateTitle(L("EditorStage"):format(tostring(tab.stage)))
                local stages = getStages(self)
                local targets = {}
                for _, target in ipairs(stages) do
                    table.insert(targets, target)
                end
                table.insert(targets, math.floor(stages[#stages]) + 1)
                for _, target in ipairs(targets) do
                    if target ~= tab.stage then
                        rootDescription:CreateButton(L("EditorMoveStage"):format(tostring(target)), function()
                            moveStage(self, tab.stage, target)
                        end)
                    end
                end
            end)
            return
        end
        local selected = self.mode ~= "rules" and self.selected
        self.mode = "stages"
        self.stage = tab.stage
        Select(self, selected and stageOf(selected) == tab.stage and selected or nil)
        private.OnTourEvent("stageOpen")
    end)
    tab:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    tab:SetWidth(variables.tabWidth)
    tab:SetHeight(variables.tabHeight)
    tab.Close = CreateFrame("Button", nil, tab)
    tab.Close:SetSize(variables.closeSize + 4, variables.closeSize + 4)
    tab.Close:SetPoint("RIGHT", tab, "RIGHT", -4, 0)
    tab.Close.Icon = tab.Close:CreateTexture(nil, "OVERLAY")
    tab.Close.Icon:SetTexture(ThemeApply.File("close"))
    tab.Close.Icon:SetSize(variables.closeSize, variables.closeSize)
    tab.Close.Icon:SetPoint("CENTER")
    tab.Close:SetScript("OnClick", function(close)
        removeStage(self, tab.stage, close)
    end)
    tab.Close:SetScript("OnEnter", function(close)
        GameTooltip:SetOwner(close, "ANCHOR_TOP")
        GameTooltip:AddLine(L("EditorRemoveStageTooltip"), 1, 1, 1)
        GameTooltip:Show()
    end)
    tab.Close:SetScript("OnLeave", function()
        GameTooltip:Hide()
        drawTab(tab)
    end)
    tab:HookScript("OnEnter", function() drawTab(tab) end)
    tab:HookScript("OnLeave", function() drawTab(tab) end)
    return tab
end

---@param self AtTimingsEditorDataFrame
---@param offset number
local scrollTabs = function(self, offset)
    self.tabScroll = offset
    self:RefreshTabs()
end

---draws the stage tabs, a strip that scrolls with its arrows when they don't fit
---@param self AtTimingsEditorDataFrame
local function RefreshTabs(self)
    local stages = getStages(self)
    local step = variables.tabWidth + 4
    local total = #stages * step - 4
    local available = self.tabBar:GetWidth() - self.addStageButton:GetWidth() - self.rulesButton:GetWidth() -
        variables.gap * 2
    local overflow = total > available
    self.tabPrev:SetShown(overflow)
    self.tabNext:SetShown(overflow)
    local strip = self.tabStrip
    -- the anchors go one way only: "+" never hangs on the strip while the strip hangs on the arrow next to "+"
    strip:ClearAllPoints()
    self.addStageButton:ClearAllPoints()
    if overflow then
        self.addStageButton:SetPoint("RIGHT", self.rulesButton, "LEFT", -variables.gap, 0)
        strip:SetPoint("LEFT", self.tabPrev, "RIGHT", 4, 0)
        strip:SetPoint("RIGHT", self.tabNext, "LEFT", -4, 0)
    else
        strip:SetPoint("LEFT", self.tabBar, "LEFT")
        strip:SetWidth(math.max(total, 1))
        self.addStageButton:SetPoint("LEFT", strip, "RIGHT", variables.gap, 0)
    end
    strip:SetHeight(variables.tabHeight)
    local stripWidth = overflow and available - (variables.arrowWidth + 4) * 2 or total
    -- the open stage stays in view
    local maxScroll = math.max(0, total - stripWidth)
    for index, stage in ipairs(stages) do
        if stage == self.stage and self.tabScrollTo ~= stage then
            local left = (index - 1) * step
            if left < self.tabScroll then
                self.tabScroll = left
            elseif left + variables.tabWidth > self.tabScroll + stripWidth then
                self.tabScroll = left + variables.tabWidth - stripWidth
            end
            self.tabScrollTo = stage
        end
    end
    self.tabScroll = overflow and math.max(0, math.min(self.tabScroll, maxScroll)) or 0
    setButtonEnabled(self.tabPrev, self.tabScroll > 0)
    setButtonEnabled(self.tabNext, self.tabScroll < maxScroll)

    reuse(self.tabs)
    for index, stage in ipairs(stages) do
        local tab = acquire(self.tabs, function() return createTab(self) end)
        tab.stage = stage
        tab.selected = self.mode ~= "rules" and stage == self.stage
        -- the first stage always has a tab
        tab.removable = stage ~= 1
        tab:SetText(L("EditorStage"):format(tostring(stage)))
        tab:ClearAllPoints()
        tab:SetPoint("LEFT", strip, "LEFT", (index - 1) * step - self.tabScroll, 0)
        drawTab(tab)
    end
    trim(self.tabs)
    self.rulesButton.atStyle = self.mode == "rules" and "Primary" or "Plain"
    ThemedWidgets.DrawButton(self.rulesButton)
    -- stages and boss timer rules both come from the boss mods
    local usesStages = #stages > 1 or stages[1] ~= 1
    local noBossMod = not C_AddOns.IsAddOnLoaded("BigWigs") and not C_AddOns.IsAddOnLoaded("DBM-Core")
    self.noBossMod:SetText(L(self.mode == "rules" and "EditorRulesNoBossMod" or "EditorNoBossMod"))
    self.noBossMod:SetShown(noBossMod and (usesStages or self.mode == "rules"))
end

---the "for" suggestions for the word being typed: group members, the tag words, groups and classes
---@param self AtTimingsEditorDataFrame
---@param text string
---@return table[]
local getTagSuggestions = function(self, text)
    local typed = (text:match("(%S*)$") or ""):lower()
    local used = {}
    for word in text:gmatch("(%S+)%s") do
        used[characterOf(word):lower()] = true
    end
    local candidates, seen = {}, {}
    local add = function(suggestion)
        local key = suggestion.value:lower()
        if seen[key] or used[key] then return end
        seen[key] = true
        table.insert(candidates, suggestion)
    end
    for _, member in ipairs(getGroupMembers()) do
        -- a nickname with a space would split into two words, the character's name is put in then
        add({
            text = member.nick,
            insert = member.nick:find("%s") and member.name or member.nick,
            value = member.name,
            detail = member.nick ~= member.name and member.name or L("EditorTagGroup"),
            color = member.class and RAID_CLASS_COLORS[member.class],
        })
    end
    for _, word in ipairs(TAG_WORDS) do
        add({ text = word, insert = word, value = word, detail = L("EditorTag_" .. word) })
    end
    for group = 1, 8 do
        add({ text = "group" .. group, insert = "group" .. group, value = "group" .. group, detail = L("EditorTagSubgroup") })
    end
    for class in pairs(RAID_CLASS_COLORS) do
        if LOCALIZED_CLASS_NAMES_MALE[class] then
            add({ text = class:lower(), insert = class:lower(), value = class:lower(), detail = coloredClassName(class) })
        end
    end
    -- not the edited reminder's own, its words are being typed
    for _, reminder in ipairs(self.reminders) do
        if reminder ~= self.selected then
            for word in tagOf(reminder):gmatch("%S+") do
                local nick = nicknameOf(word)
                add({ text = nick, insert = nick:find("%s") and word or nick, value = word, detail = L("EditorTagUsed") })
            end
        end
    end
    -- nicknames of characters not in the group, once something is typed
    if CustomNames and #typed >= 2 then
        local realm = GetNormalizedRealmName()
        for character, nick in pairs(CustomNames.GetList()) do
            local name, characterRealm = strsplit("-", character)
            if name and nick:lower():find(typed, 1, true) then
                local value = characterRealm == realm and name or character
                add({ text = nick, insert = nick:find("%s") and value or nick, value = value, detail = character })
            end
        end
    end
    local results = {}
    for index, suggestion in ipairs(candidates) do
        local textMatch = suggestion.text:lower():find(typed, 1, true)
        local valueMatch = suggestion.value:lower():find(typed, 1, true)
        if typed == "" or textMatch or valueMatch then
            suggestion.rank = (textMatch == 1 or valueMatch == 1) and index or index + #candidates
            table.insert(results, suggestion)
        end
    end
    table.sort(results, function(a, b) return a.rank < b.rank end)
    for i = #results, variables.suggestions + 1, -1 do
        results[i] = nil
    end
    return results
end

---the spells a reminder of this boss likely is about: its abilities, spells already used for it, the player's own
---spells and the cooldowns of every class (Data/Cooldowns.lua), made once per encounter
---@param self AtTimingsEditorDataFrame
---@return table[]
local getSpellCandidates = function(self)
    if self.spellCandidates then
        return self.spellCandidates
    end
    local candidates, seen = {}, {}
    local add = function(spellId, detail, name, icon, isBoss)
        if not spellId or spellId <= 0 or seen[spellId] then return end
        name = name or getSpellName(spellId)
        if not name or name == "" then return end
        seen[spellId] = true
        table.insert(candidates, {
            spellId = spellId,
            name = name,
            lower = name:lower(),
            icon = icon or C_Spell.GetSpellTexture(spellId),
            detail = detail,
            isBoss = isBoss,
        })
    end
    if self.journalEncounterID and EJ_GetEncounterInfo and C_EncounterJournal and C_EncounterJournal.GetSectionInfo then
        local _, _, _, rootSectionID = EJ_GetEncounterInfo(self.journalEncounterID)
        local sections = { rootSectionID }
        while #sections > 0 do
            local info = C_EncounterJournal.GetSectionInfo(table.remove(sections))
            if info then
                add(info.spellID, L("EditorSpellBoss"), info.title, info.abilityIcon ~= 0 and info.abilityIcon or nil, true)
                table.insert(sections, info.siblingSectionID)
                table.insert(sections, info.firstChildSectionID)
            end
        end
    end
    for _, reminder in ipairs(self.reminders) do
        add(reminder.spellId, L("EditorSpellUsed"))
    end
    if C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines then
        for line = 1, C_SpellBook.GetNumSpellBookSkillLines() do
            local lineInfo = C_SpellBook.GetSpellBookSkillLineInfo(line)
            if lineInfo and not lineInfo.shouldHide then
                for slot = lineInfo.itemIndexOffset + 1, lineInfo.itemIndexOffset + lineInfo.numSpellBookItems do
                    local item = C_SpellBook.GetSpellBookItemInfo(slot, Enum.SpellBookSpellBank.Player)
                    if item and item.spellID and not item.isPassive and item.itemType == Enum.SpellBookItemType.Spell then
                        add(item.spellID, L("EditorSpellOwn"), item.name, item.iconID)
                    end
                end
            end
        end
    end
    for spellId, cooldown in pairs(private.Cooldowns or {}) do
        add(spellId, string.format("%s  %s", specsName(cooldown), formatTime(cooldown.cooldown)))
    end
    self.spellCandidates = candidates
    return candidates
end

---@param self AtTimingsEditorDataFrame
---@param text string
---@return table[]
---@param bossOnly boolean|nil -- boss timer rules: only the boss's abilities have BigWigs and DBM bars
local getSpellSuggestions = function(self, text, bossOnly)
    local typed = strtrim(text):lower()
    if typed == "" then return {} end
    local byId = typed:match("^%d+$")
    local results = {}
    for index, candidate in ipairs(getSpellCandidates(self)) do
        local position = byId and tostring(candidate.spellId):find(typed, 1, true) or candidate.lower:find(typed, 1, true)
        if position and not (byId and position ~= 1) and (candidate.isBoss or not bossOnly) then
            table.insert(results, {
                text = candidate.name,
                spellId = candidate.spellId,
                value = tostring(candidate.spellId),
                detail = candidate.detail,
                icon = candidate.icon,
                rank = position == 1 and index or index + 100000,
            })
        end
    end
    table.sort(results, function(a, b) return a.rank < b.rank end)
    for i = #results, variables.suggestions + 1, -1 do
        results[i] = nil
    end
    return results
end

---adds a row of the panel: its label on the left, the control on the right
---@param self AtTimingsEditorDataFrame
---@param key string
---@param control table
---@param tooltip string|nil
local addRow = function(self, key, control, tooltip)
    local row = AceGUI:Create("AtSettingRow")
    row:SetLabel(L(key))
    row:AddChild(control)
    if tooltip then
        addTooltip(control, tooltip)
    end
    self.inspector:AddChild(row)
    return row
end

---@param self AtTimingsEditorDataFrame
---@param key string
---@param value string
---@param onChange fun(text: string)
---@param tooltip string|nil
---@return AtEditBox
local addEditBox = function(self, key, value, onChange, tooltip)
    local box = AceGUI:Create("AtEditBox")
    box:SetLabel("")
    box:SetText(value)
    box:DisableButton(true)
    box:SetCallback("OnTextChanged", function(_, _, text)
        onChange(text)
        private.RefreshAutoComplete(box)
    end)
    addRow(self, key, box, tooltip)
    return box
end

---@param self AtTimingsEditorDataFrame
---@param key string
---@param list table
---@param order table
---@param multiselect boolean|nil
---@param tooltip string|nil
---@return AtDropdown
local addDropdown = function(self, key, list, order, multiselect, tooltip)
    local dropdown = AceGUI:Create("AtDropdown")
    dropdown:SetLabel("")
    -- the items are made by SetList, as toggles only in a multiselect
    dropdown:SetMultiselect(multiselect or false)
    dropdown:SetList(list, order)
    addRow(self, key, dropdown, tooltip)
    return dropdown
end

---@param self AtTimingsEditorDataFrame
---@param key string
---@param value boolean
---@param onChange fun(value: boolean)
---@param tooltip string|nil
---@return AtCheckBox
local addCheckBox = function(self, key, value, onChange, tooltip)
    local check = AceGUI:Create("AtCheckBox")
    check:SetLabel("")
    check:SetValue(value)
    check:SetCallback("OnValueChanged", function(_, _, checked)
        onChange(checked)
    end)
    addRow(self, key, check, tooltip)
    return check
end

---@param box AtEditBox
---@param text string
local setTextAndFocus = function(box, text)
    box:SetText(text)
    box:SetFocus()
    box.editbox:SetCursorPosition(#text)
end

---@param self AtTimingsEditorDataFrame
---@param reminder table
local addBasics = function(self, reminder)
    self.textBox = addEditBox(self, "EditorText", reminder.text or reminder.name or "", function(text)
        update(self, "text", function(r)
            r.text = text ~= "" and text or nil
            r.name = nil
        end)
    end, "EditorTextDescription")
    local setSpell = function(text)
        update(self, "spell", function(r)
            local spellId = tonumber(text) or 0
            local spellInfo = spellId > 0 and C_Spell.GetSpellInfo(spellId)
            r.spellId = spellInfo and spellId or 0
            r.spellName = spellInfo and spellInfo.name or nil
            r.iconId = spellInfo and spellInfo.iconID or 134400
        end)
    end
    local spellBox = addEditBox(self, "EditorSpell",
        reminder.spellId and reminder.spellId > 0 and tostring(reminder.spellId) or "", setSpell, "EditorSpellDescription")
    private.AttachAutoComplete(spellBox, function(text)
        return getSpellSuggestions(self, text)
    end, function(suggestion)
        setTextAndFocus(spellBox, suggestion.value)
        setSpell(suggestion.value)
    end)
    addEditBox(self, "EditorStageLabel", tostring(stageOf(reminder)), function(text)
        local stage = tonumber(text)
        if not stage or stage <= 0 or stage == stageOf(reminder) then return end
        update(self, "stage", function(r) r.phase = stage end)
        self.stage = stage
        self:RefreshTabs()
        RefreshTimeline(self)
    end, "EditorStageDescription")
    addEditBox(self, "EditorTime", formatTime(reminder.CombatTime or 0), function(text)
        local time = parseTime(text)
        if not time then return end
        update(self, "time", function(r) r.CombatTime = time end)
    end, "EditorTimeDescription")
    local tagBox
    local setTag = function(text)
        update(self, "tag", function(r) r.tag = storeTag(text) end)
    end
    tagBox = addEditBox(self, "EditorFor", reminder.tag and displayTag(reminder.tag) or "", setTag, "EditorForDescription")
    private.AttachAutoComplete(tagBox, function(text)
        return getTagSuggestions(self, text)
    end, function(suggestion)
        local text = (tagBox:GetText():gsub("%S*$", "")) .. suggestion.insert .. " "
        setTextAndFocus(tagBox, text)
        setTag(text)
    end)
    addEditBox(self, "EditorStays", tostring(reminder.CombatTimeDelay or 0), function(text)
        update(self, "stays", function(r) r.CombatTimeDelay = tonumber(text) or 0 end)
    end, "ReminderDelayDescription")
    addEditBox(self, "EditorShowAfter", tostring(reminder.StartTimerAfter or 0), function(text)
        update(self, "showAfter", function(r) r.StartTimerAfter = tonumber(text) or 0 end)
    end, "StartTimerAfterDescription")
end

---@param self AtTimingsEditorDataFrame
---@param reminder table
---@param isRule boolean|nil -- boss mod bars have their own severity and effect types
local addLook = function(self, reminder, isRule)
    local displayList, displayOrder = {}, {}
    for _, display in ipairs(DISPLAYS) do
        displayList[display.key] = L(display.name)
        table.insert(displayOrder, display.key)
    end
    local displays = addDropdown(self, "EditorShowsOn", displayList, displayOrder, true, "EditorShowsOnDescription")
    for _, display in ipairs(DISPLAYS) do
        displays:SetItemValue(display.key, not reminder.displays or reminder.displays[display.key] ~= false)
    end
    displays:SetCallback("OnValueChanged", function(_, _, key, checked)
        update(self, nil, function(r)
            local shown = r.displays or { timeline = true, bigIcon = true, textHighlight = true }
            shown[key] = checked
            local all = true
            for _, display in ipairs(DISPLAYS) do
                all = all and shown[display.key] ~= false
            end
            r.displays = not all and shown or nil
        end)
    end)
    -- rows that only matter with another one set are shown with it, the panel is filled again when it changes
    -- turned off, the color stays saved and unused (useColor)
    local ownColor = private.GetUsedColor(reminder)
    addCheckBox(self, "EditorOwnColor", ownColor ~= nil, function(checked)
        update(self, nil, function(r)
            r.color = r.color or { r = 1, g = 1, b = 1 }
            -- unset is used, so data from before the switch keeps working
            if checked then
                r.useColor = nil
            else
                r.useColor = false
            end
        end)
        ShowInspector(self)
    end, "EditorOwnColorDescription")
    if ownColor then
        local picker = AceGUI:Create("AtColorPicker")
        picker:SetLabel("")
        picker:SetHasAlpha(false)
        picker:SetColor(ThemeApply.Color(ownColor))
        -- AceGUI confirms only colors with alpha, the color is taken as it changes, one undo step while picking
        local setColor = function(_, _, r, g, b)
            update(self, "color", function(target) target.color = { r = r, g = g, b = b } end)
        end
        picker:SetCallback("OnValueChanged", setColor)
        picker:SetCallback("OnValueConfirmed", setColor)
        addRow(self, "EditorColor", picker)
    end
    local glowList, glowOrder = { [NONE] = L("EditorNone") }, { NONE }
    for _, glowType in pairs(private.GlowTypes) do
        glowList[glowType] = glowType
        table.insert(glowOrder, glowType)
    end
    table.sort(glowOrder, function(a, b) return a == NONE or b ~= NONE and a < b end)
    local glow = addDropdown(self, "EditorGlow", glowList, glowOrder, false, "EditorGlowDescription")
    glow:SetValue(reminder.glow or NONE)
    glow:SetCallback("OnValueChanged", function(_, _, value)
        update(self, nil, function(r) r.glow = value ~= NONE and value or nil end)
        ShowInspector(self)
    end)
    if reminder.glow then
        local glowWhen = addDropdown(self, "EditorGlowWhen",
            { always = L("EditorGlowAlways"), close = L("EditorGlowClose") }, { "always", "close" }, false,
            "EditorGlowWhenDescription")
        glowWhen:SetValue(reminder.glowWhen or "always")
        glowWhen:SetCallback("OnValueChanged", function(_, _, value)
            update(self, nil, function(r) r.glowWhen = value ~= "always" and value or nil end)
        end)
    end
    if isRule then return end
    local severityList = {}
    for value, key in pairs(SEVERITIES) do
        severityList[value] = L(key)
    end
    local severity = addDropdown(self, "ReminderSeverityLabel", severityList, { 0, 1, 2 })
    severity:SetValue(reminder.severity or 1)
    severity:SetCallback("OnValueChanged", function(_, _, value)
        update(self, nil, function(r) r.severity = value end)
    end)
    local effectList, effectOrder = {}, {}
    for _, effect in ipairs(EFFECTS) do
        effectList[effect.bit] = L(effect.key)
        table.insert(effectOrder, effect.bit)
    end
    local effects = addDropdown(self, "ReminderEffectTypesLabel", effectList, effectOrder, true)
    for _, effect in ipairs(EFFECTS) do
        effects:SetItemValue(effect.bit, bit.band(reminder.effectTypes or 0, effect.bit) ~= 0)
    end
    effects:SetCallback("OnValueChanged", function(_, _, value, checked)
        update(self, nil, function(r)
            local current = r.effectTypes or 0
            r.effectTypes = checked and bit.bor(current, value) or bit.band(current, bit.bnot(value))
        end)
    end)
end

---@param self AtTimingsEditorDataFrame
---@param reminder table
local addSound = function(self, reminder)
    local countdownList = { [-1] = L("EditorCountdownDefault"), [0] = L("EditorCountdownOff") }
    local countdownOrder = { -1, 0 }
    for seconds = 1, 5 do
        countdownList[seconds] = tostring(seconds)
        table.insert(countdownOrder, seconds)
    end
    local countdown = addDropdown(self, "EditorCountdown", countdownList, countdownOrder, false,
        "EditorCountdownDescription")
    countdown:SetValue(reminder.countdown and math.min(reminder.countdown, 5) or -1)
    countdown:SetCallback("OnValueChanged", function(_, _, value)
        update(self, nil, function(r) r.countdown = value >= 0 and value or nil end)
    end)
    -- turned off, the spoken text stays saved and unused (useTTS)
    local speaks = private.GetUsedTTS(reminder) ~= nil
    addCheckBox(self, "EditorSpeak", speaks, function(checked)
        update(self, nil, function(r)
            r.TTS = r.TTS or true
            -- unset is used, so data from before the switch keeps working
            if checked then
                r.useTTS = nil
            else
                r.useTTS = false
            end
        end)
        ShowInspector(self)
    end)
    if speaks then
        addEditBox(self, "EditorSpokenText", type(reminder.TTS) == "string" and reminder.TTS or "", function(text)
            update(self, "spoken", function(r) r.TTS = text ~= "" and text or true end)
        end, "EditorSpokenTextDescription")
    end
    local soundList, soundOrder = { [NONE] = L("EditorNone") }, { NONE }
    for _, name in ipairs(SharedMedia:List("sound")) do
        soundList[name] = name
        table.insert(soundOrder, name)
    end
    local sound = addDropdown(self, "EditorSound", soundList, soundOrder)
    sound:SetValue(reminder.sound and soundList[reminder.sound] and reminder.sound or NONE)
    sound:SetCallback("OnValueChanged", function(_, _, value)
        local hadSound = reminder.sound ~= nil
        update(self, nil, function(r) r.sound = value ~= NONE and value or nil end)
        if hadSound ~= (reminder.sound ~= nil) then
            ShowInspector(self)
        end
    end)
    if speaks or reminder.sound then
        addEditBox(self, "EditorSoundLead", reminder.TTSTimer and tostring(reminder.TTSTimer) or "", function(text)
            update(self, "lead", function(r) r.TTSTimer = tonumber(text) end)
        end, "EditorSoundLeadDescription")
    end
end

---@param rule table
---@return number|nil
local ruleSpellId = function(rule)
    return rule.match ~= "text" and tonumber(rule.value) or nil
end

---what bars a rule is for: the spell's name and ID or the text the bars have
---@param rule table
---@return string
local ruleTarget = function(rule)
    local spellId = ruleSpellId(rule)
    if spellId then
        return L("EditorRuleSpellTarget"):format(getSpellName(spellId) or "?", spellId)
    end
    if rule.match == "text" and (rule.value or "") ~= "" then
        return L("EditorRuleTextTarget"):format(rule.value)
    end
    return L("EditorRuleNoTarget")
end

---@param self AtTimingsEditorDataFrame
---@param rule table
local addRuleBasics = function(self, rule)
    local match = addDropdown(self, "EditorRuleMatch", { spell = L("EditorRuleMatchSpell"), text = L("EditorRuleMatchText") },
        { "spell", "text" }, false, "EditorRuleMatchDescription")
    match:SetValue(rule.match or "spell")
    match:SetCallback("OnValueChanged", function(_, _, value)
        update(self, nil, function(r) r.match = value end)
        ShowInspector(self)
    end)
    local isText = rule.match == "text"
    local setValue = function(text)
        update(self, "value", function(r) r.value = strtrim(text) end)
    end
    local valueBox = addEditBox(self, isText and "EditorRuleText" or "EditorSpell", rule.value or "", setValue,
        isText and "EditorRuleTextDescription" or "EditorRuleSpellDescription")
    if not isText then
        private.AttachAutoComplete(valueBox, function(text)
            return getSpellSuggestions(self, text, true)
        end, function(suggestion)
            setTextAndFocus(valueBox, suggestion.value)
            setValue(suggestion.value)
        end)
    end
    self.textBox = valueBox
    addEditBox(self, "EditorRuleName", rule.name or "", function(text)
        update(self, "name", function(r) r.name = text ~= "" and text or nil end)
    end, "EditorRuleNameDescription")
end

---the selected reminder's icon, name and where it is above the panel's tabs
---@param self AtTimingsEditorDataFrame
refreshHeader = function(self)
    local reminder = self.selected
    if not reminder then return end
    local header = self.inspectorPanel.Header
    if self.mode == "rules" then
        local spellId = ruleSpellId(reminder)
        header.Icon:SetTexture(spellId and C_Spell.GetSpellTexture(spellId) or 134400)
        header.Title:SetText(reminder.name or ruleTarget(reminder))
        header.Where:SetText(reminder.name and ruleTarget(reminder) or L("EditorRuleWhere"))
        return
    end
    header.Icon:SetTexture(getTexture(reminder))
    header.Title:SetText(private.GetReminderName(reminder) or L("EditorNewReminder"))
    header.Where:SetText(L("EditorHeaderWhere"):format(tostring(stageOf(reminder)), formatTime(reminder.CombatTime or 0),
        displayTag(tagOf(reminder))))
end

---fills the panel with the fields of the selected reminder's open tab
---@param self AtTimingsEditorDataFrame
ShowInspector = function(self)
    local panel, inspector = self.inspectorPanel, self.inspector
    local reminder = self.selected
    private.HideAutoComplete()
    inspector:ReleaseChildren()
    self.textBox = nil
    panel.Empty:SetShown(reminder == nil)
    panel.Empty:SetText(L(self.mode == "rules" and "EditorRulesSelectHint" or "EditorSelectHint"))
    for _, region in ipairs({ inspector.frame, panel.Header, panel.Tabs, panel.Footer }) do
        region:SetShown(reminder ~= nil)
    end
    if not reminder then return end
    refreshHeader(self)
    for _, tab in ipairs(panel.Tabs.Buttons) do
        tab.atStyle = tab.key == self.inspectorTab and "Primary" or "Plain"
        ThemedWidgets.DrawButton(tab)
    end
    inspector:PauseLayout()
    local isRule = self.mode == "rules"
    if self.inspectorTab == "look" then
        addLook(self, reminder, isRule)
    elseif self.inspectorTab == "sound" then
        addSound(self, reminder)
    elseif isRule then
        addRuleBasics(self, reminder)
    else
        addBasics(self, reminder)
    end
    inspector:ResumeLayout()
    inspector:DoLayout()
end

---lists the boss timer rules of the encounter, the selected one stands out
---@param self AtTimingsEditorDataFrame
local refreshRules = function(self)
    local list = self.ruleList
    list:ReleaseChildren()
    self.rulesView.Empty:SetShown(#self.rules == 0)
    list:PauseLayout()
    for _, rule in ipairs(self.rules) do
        local row = AceGUI:Create("AtSettingRow")
        local spellId = ruleSpellId(rule)
        local icon = spellId and C_Spell.GetSpellTexture(spellId)
        row:SetLabel((icon and "|T" .. icon .. ":16:16:0:0:64:64:5:59:5:59|t " or "") .. ruleTarget(rule))
        row:SetHovered(rule == self.selected)
        local edit = AceGUI:Create("AtButton")
        edit:SetText(rule.name or L("EditorRuleEdit"))
        if rule == self.selected then
            edit:SetStyle("Primary")
        end
        edit:SetCallback("OnClick", function()
            Select(self, rule)
        end)
        row:AddChild(edit)
        list:AddChild(row)
    end
    list:ResumeLayout()
    list:DoLayout()
end

---shows the timeline of the open stage or the boss timer rules
---@param self AtTimingsEditorDataFrame
refreshView = function(self)
    local rules = self.mode == "rules"
    for _, part in ipairs(self.timelineParts) do
        part:SetShown(not rules)
    end
    self.rulesView:SetShown(rules)
    self.addButton:SetText(L(rules and "EditorAddRule" or "EditorAddReminder"))
    self.addButton:SetWidth(self.addButton:GetFontString():GetStringWidth() + 28)
    if rules then
        refreshRules(self)
    else
        RefreshTimeline(self)
    end
end

---@param self AtTimingsEditorDataFrame
local function ApplySettings(self)
    for _, panel in ipairs({ self.board, self.inspectorPanel }) do
        panel.AtFill:SetVertexColor(ThemeApply.Color("Card"))
        panel.AtEdge:SetVertexColor(ThemeApply.Color("Edge"))
    end
    self.canvas.Back:SetColorTexture(ThemeApply.Color("Field"))
    self.labels.Divider:SetColorTexture(ThemeApply.Color("Edge"))
    self.inspectorPanel.Header.Line:SetColorTexture(ThemeApply.Color("Line"))
    for _, track in ipairs({ self.scrollX, self.scrollY }) do
        track.Back:SetColorTexture(ThemeApply.Color("Track", 0.5))
        track.Thumb:SetColorTexture(ThemeApply.Color("Accent2", 0.8))
    end
    for _, text in ipairs({ self.canvas.Empty, self.inspectorPanel.Empty, self.help, self.lengthLabel,
        self.inspectorPanel.Header.Where, self.rulesView.Empty }) do
        ThemeApply.FontRole(text, "Muted")
    end
    ThemeApply.FontRole(self.inspectorPanel.Header.Title, "Heading")
    ThemeApply.FontRole(self.noBossMod, "Control")
    self.noBossMod:SetTextColor(ThemeApply.Color("Danger"))
    for _, button in ipairs({ self.addButton, self.undoButton, self.redoButton, self.importButton, self.exportButton,
        self.addStageButton, self.tabPrev, self.tabNext, self.duplicateButton, self.deleteButton, self.rulesButton }) do
        ThemedWidgets.DrawButton(button)
    end
    for _, button in ipairs({ self.tabPrev, self.tabNext, self.undoButton, self.redoButton }) do
        button.Icon:SetVertexColor(ThemeApply.Color("Text"))
    end
    if self.reminders then
        self:RefreshTabs()
        refreshView(self)
        ShowInspector(self)
    end
end

---@param self AtTimingsEditorDataFrame
local function OnAcquire(self)
    local frame = self.frame
    frame:SetSize(variables.width, variables.height)
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER")
    -- the import and export dialogs open above it
    frame:SetFrameStrata("HIGH")
    -- ctrl+z / ctrl+y: every key goes on to the game, which can only be set up out of combat
    if not InCombatLockdown() then
        frame:EnableKeyboard(true)
        frame:SetPropagateKeyboardInput(true)
    end
    frame:Show()
end

---@param self AtTimingsEditorDataFrame
local function OnRelease(self)
    private.HideAutoComplete()
    self.inspector:ReleaseChildren()
    self.ruleList:ReleaseChildren()
    self.rows:SetScript("OnUpdate", nil)
    if not InCombatLockdown() then
        self.frame:EnableKeyboard(false)
    end
    self.selected = nil
    self.dragging = nil
    self.textBox = nil
    self.reminders = {}
    self.rules = {}
    wipe(self.undoStack)
    wipe(self.redoStack)
end

---@param self AtTimingsEditorDataFrame
---@param encounterID number
local function LoadReminders(self, encounterID)
    self.reminders = {}
    for _, reminder in ipairs(private.db.profile.reminders[encounterID] or {}) do
        table.insert(self.reminders, copyReminder(reminder))
    end
    self.rules = {}
    for _, rule in ipairs(private.db.profile.timerRules and private.db.profile.timerRules[encounterID] or {}) do
        table.insert(self.rules, copyReminder(rule))
    end
    self.spellCandidates = nil
end

---draws everything again after the reminders were loaded anew
---@param self AtTimingsEditorDataFrame
local function RefreshReminders(self)
    if self.selected and not tContains(self.reminders, self.selected) and not tContains(self.rules, self.selected) then
        self.selected = nil
    end
    self:RefreshTabs()
    refreshView(self)
    ShowInspector(self)
end

---@param self AtTimingsEditorDataFrame
---@param encounterParams table -- journalEncounterID and journalInstanceID or dungeonEncounterID
local function SetEncounter(self, encounterParams)
    assert(type(encounterParams) == "table", "SetEncounter requires a table parameter")
    assert(encounterParams.journalEncounterID and encounterParams.journalInstanceID or encounterParams.dungeonEncounterID,
        "SetEncounter requires journalEncounterID, journalInstanceID, and dungeonEncounterID")
    self.journalEncounterID = encounterParams.journalEncounterID
    self.journalInstanceID = encounterParams.journalInstanceID
    self.encounterID = encounterParams.dungeonEncounterID
    -- Classic Era has no Adventure Guide
    local instanceName = self.journalInstanceID and EJ_GetInstanceInfo and EJ_GetInstanceInfo(self.journalInstanceID)
    local encounterName = self.journalEncounterID and EJ_GetEncounterInfo and EJ_GetEncounterInfo(self.journalEncounterID)
    self.instanceName = instanceName or encounterParams.instanceName
    self.encounterName = encounterName or encounterParams.name
    self.container:SetTitle(string.format("%s%s - %s", L("TimingsEditorTitle"), self.instanceName or "",
        self.encounterName or L("EncounterFallbackName"):format(self.encounterID or 0)))
    self.length = private.db.profile.editor.defaultEncounterDuration or 300
    self.lengthBox:SetText(tostring(self.length))
    self.stage = 1
    self.mode = "stages"
    self.extraStages = {}
    self.selected = nil
    self.scroll = 0
    self.rowScroll = 0
    self.tabScroll = 0
    self.tabScrollTo = nil
    self.pixelsPerSecond = variables.defaultPixelsPerSecond
    self.inspectorTab = "basics"
    wipe(self.undoStack)
    wipe(self.redoStack)
    refreshUndoButtons(self)
    LoadReminders(self, self.encounterID)
    RefreshReminders(self)
    self.frame:Show()
end

---called before the reminders change from outside the editor, an import, so it can be undone
---@param self AtTimingsEditorDataFrame
local function RecordUndo(self)
    record(self)
end

local function Constructor()
    local count = AceGUI:GetNextWidgetNum(Type)
    local container = AceGUI:Create("ATTimingsEditorContainer")
    local main = container.content
    local padding, gap = variables.padding, variables.gap

    ---@class AtTimingsEditorDataFrame : AceGUIWidget
    local widget = {
        OnAcquire = OnAcquire,
        OnRelease = OnRelease,
        ApplySettings = ApplySettings,
        SetEncounter = SetEncounter,
        LoadReminders = LoadReminders,
        RefreshReminders = RefreshReminders,
        RefreshTabs = RefreshTabs,
        SaveReminders = SaveReminders,
        RecordUndo = RecordUndo,
        frame = container.frame,
        content = main,
        container = container,
        type = Type,
        count = count,
        reminders = {},
        rules = {},
        -- "stages" shows the timeline of a stage, "rules" the boss timer rules
        mode = "stages",
        extraStages = {},
        stage = 1,
        scroll = 0,
        rowScroll = 0,
        tabScroll = 0,
        pixelsPerSecond = variables.defaultPixelsPerSecond,
        inspectorTab = "basics",
        undoStack = {},
        redoStack = {},
        pins = {},
        bands = {},
        gridLines = {},
        labelTexts = {},
        rulerTexts = {},
        tabs = {},
        -- where each row of the open stage is, from the top of the rows
        rowSpans = {},
    }

    container.frame:SetScript("OnKeyDown", function(_, key)
        if not IsControlKeyDown() then return end
        if key == "Z" then
            if IsShiftKeyDown() then
                redo(widget)
            else
                undo(widget)
            end
        elseif key == "Y" then
            redo(widget)
        end
    end)

    -- the toolbar: adding and undoing on the left, what the timeline shows and import / export on the right
    local toolbar = CreateFrame("Frame", nil, main)
    toolbar:SetPoint("TOPLEFT", main, "TOPLEFT", padding, -padding)
    toolbar:SetPoint("TOPRIGHT", main, "TOPRIGHT", -padding, -padding)
    toolbar:SetHeight(variables.toolbarHeight)
    widget.addButton = createButton(toolbar, L("EditorAddReminder"), function()
        if widget.mode == "rules" then
            addRule(widget)
            return
        end
        local selected = widget.selected
        local time = selected and stageOf(selected) == widget.stage and (selected.CombatTime or 0) + 5
        addReminder(widget, time or snapTime(widget.scroll / getPixelsPerSecond(widget)) + 10,
            selected and tagOf(selected))
    end, "Primary")
    widget.addButton:SetPoint("LEFT", toolbar, "LEFT")
    widget.undoButton = createIconButton(toolbar, false, function() undo(widget) end)
    widget.undoButton:SetPoint("LEFT", widget.addButton, "RIGHT", variables.groupGap, 0)
    widget.redoButton = createIconButton(toolbar, true, function() redo(widget) end)
    widget.redoButton:SetPoint("LEFT", widget.undoButton, "RIGHT", gap, 0)
    for _, button in ipairs({ widget.undoButton, widget.redoButton }) do
        button:HookScript("OnEnter", function()
            GameTooltip:SetOwner(button, "ANCHOR_BOTTOM")
            GameTooltip:AddLine(L(button == widget.undoButton and "EditorUndoDescription" or "EditorRedoDescription"),
                1, 1, 1)
            GameTooltip:Show()
        end)
        button:HookScript("OnLeave", function() GameTooltip:Hide() end)
    end

    widget.exportButton = createButton(toolbar, L("EditorExport"), function()
        if widget.encounterID then
            private.showExportDialog(widget.encounterID)
        end
    end)
    widget.exportButton:SetPoint("RIGHT", toolbar, "RIGHT")
    widget.importButton = createButton(toolbar, L("EditorImport"), function()
        if widget.encounterID then
            private.showImportDialog(widget.encounterID, widget)
        end
    end)
    widget.importButton:SetPoint("RIGHT", widget.exportButton, "LEFT", -gap, 0)
    local lengthBox = AceGUI:Create("AtEditBox")
    lengthBox:SetLabel("")
    lengthBox:DisableButton(true)
    lengthBox:SetWidth(variables.lengthWidth)
    lengthBox.frame:SetParent(toolbar)
    lengthBox.frame:SetPoint("RIGHT", widget.importButton, "LEFT", -variables.groupGap, 0)
    lengthBox.frame:Show()
    lengthBox:SetCallback("OnTextChanged", function(_, _, text)
        local length = parseTime(text)
        if length then
            widget.length = length
            RefreshTimeline(widget)
        end
    end)
    addTooltip(lengthBox, "EditorLengthDescription")
    widget.lengthBox = lengthBox
    widget.lengthLabel = toolbar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    widget.lengthLabel:SetPoint("RIGHT", lengthBox.frame, "LEFT", -gap, 0)
    widget.lengthLabel:SetText(L("EditorLength"))
    local onlyMine = AceGUI:Create("AtCheckBox")
    onlyMine:SetLabel(L("EditorOnlyMine"))
    onlyMine:SetWidth(variables.onlyMineWidth)
    onlyMine.frame:SetParent(toolbar)
    onlyMine.frame:SetPoint("RIGHT", widget.lengthLabel, "LEFT", -variables.groupGap, 0)
    onlyMine.frame:Show()
    onlyMine:SetCallback("OnValueChanged", function()
        RefreshTimeline(widget)
    end)
    addTooltip(onlyMine, "EditorOnlyMineDescription")
    widget.onlyMine = onlyMine

    -- the stage tabs above the timeline, they scroll with the arrows when there are too many
    local tabBar = CreateFrame("Frame", nil, main)
    tabBar:SetPoint("TOPLEFT", toolbar, "BOTTOMLEFT", 0, -padding)
    tabBar:SetPoint("RIGHT", main, "RIGHT", -padding * 2 - variables.inspectorWidth, 0)
    tabBar:SetHeight(variables.tabHeight)
    tabBar:SetScript("OnSizeChanged", function() widget:RefreshTabs() end)
    widget.tabBar = tabBar
    local createArrow = function(left)
        local arrow = createButton(tabBar, "", function()
            local step = variables.tabWidth + 4
            scrollTabs(widget, widget.tabScroll + (left and -step or step))
        end)
        arrow:SetSize(variables.arrowWidth, variables.tabHeight)
        arrow.Icon = arrow:CreateTexture(nil, "OVERLAY")
        arrow.Icon:SetTexture(ThemeApply.File("chevron"))
        arrow.Icon:SetSize(10, 10)
        arrow.Icon:SetPoint("CENTER")
        -- the chevron points down
        arrow.Icon:SetRotation(left and -math.pi / 2 or math.pi / 2)
        return arrow
    end
    widget.tabPrev = createArrow(true)
    widget.tabPrev:SetPoint("LEFT", tabBar, "LEFT")
    widget.rulesButton = createButton(tabBar, L("EditorBossTimers"), function()
        widget.mode = "rules"
        Select(widget, nil)
        private.OnTourEvent("bossTimersOpen")
    end)
    widget.rulesButton:SetHeight(variables.tabHeight)
    widget.rulesButton:SetPoint("RIGHT", tabBar, "RIGHT")
    widget.rulesButton:HookScript("OnEnter", function(button)
        GameTooltip:SetOwner(button, "ANCHOR_TOP")
        GameTooltip:AddLine(L("EditorBossTimersDescription"), 1, 1, 1, true)
        GameTooltip:Show()
    end)
    widget.rulesButton:HookScript("OnLeave", function() GameTooltip:Hide() end)
    widget.addStageButton = createButton(tabBar, "+", function()
        local stages = getStages(widget)
        local stage = math.floor(stages[#stages]) + 1
        record(widget)
        widget.extraStages[stage] = true
        widget.mode = "stages"
        widget.stage = stage
        Select(widget, nil)
    end)
    widget.addStageButton:SetSize(variables.tabHeight + 4, variables.tabHeight)
    widget.addStageButton:HookScript("OnEnter", function(button)
        GameTooltip:SetOwner(button, "ANCHOR_TOP")
        GameTooltip:AddLine(L("EditorAddStageDescription"), 1, 1, 1, true)
        GameTooltip:Show()
    end)
    widget.addStageButton:HookScript("OnLeave", function() GameTooltip:Hide() end)
    widget.tabNext = createArrow(false)
    widget.tabNext:SetPoint("RIGHT", widget.addStageButton, "LEFT", -gap, 0)
    widget.tabStrip = CreateFrame("Frame", nil, tabBar)
    widget.tabStrip:SetClipsChildren(true)
    widget.tabStrip:EnableMouseWheel(true)
    widget.tabStrip:SetScript("OnMouseWheel", function(_, delta)
        scrollTabs(widget, widget.tabScroll - delta * (variables.tabWidth + 4))
    end)

    -- the timeline of the open stage: who it is for on the left, the rows with their pins on the right
    local board = CreateFrame("Frame", nil, main)
    board:SetPoint("TOPLEFT", tabBar, "BOTTOMLEFT", 0, -gap)
    board:SetPoint("BOTTOMRIGHT", main, "BOTTOMRIGHT", -padding * 2 - variables.inspectorWidth, padding)
    ThemeApply.CreatePanel(board)
    widget.board = board

    local labels = CreateFrame("Frame", nil, board)
    labels:SetPoint("TOPLEFT", board, "TOPLEFT", 0, -1 - variables.rulerHeight)
    labels:SetPoint("BOTTOMLEFT", board, "BOTTOMLEFT", 0, variables.footerHeight)
    labels:SetWidth(variables.labelWidth)
    labels:SetClipsChildren(true)
    labels.Divider = labels:CreateTexture(nil, "BORDER")
    labels.Divider:SetPoint("TOPRIGHT")
    labels.Divider:SetPoint("BOTTOMRIGHT")
    labels.Divider:SetWidth(1)
    labels:EnableMouseWheel(true)
    labels:SetScript("OnMouseWheel", function(_, delta)
        setRowScroll(widget, widget.rowScroll - delta * variables.laneHeight)
    end)
    widget.labels = labels

    local canvas = CreateFrame("Frame", nil, board)
    canvas:SetPoint("TOPLEFT", board, "TOPLEFT", variables.labelWidth, -1)
    canvas:SetPoint("BOTTOMRIGHT", board, "BOTTOMRIGHT", -variables.scrollBarSize - 8, variables.footerHeight)
    canvas:SetClipsChildren(true)
    canvas.Back = canvas:CreateTexture(nil, "BACKGROUND", nil, 1)
    canvas.Back:SetAllPoints(canvas)
    canvas.Empty = canvas:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    canvas.Empty:SetPoint("CENTER")
    canvas.Empty:SetWidth(360)
    canvas.Empty:SetText(L("EditorEmptyStage"))
    widget.canvas = canvas
    canvas:SetScript("OnSizeChanged", function()
        RefreshTimeline(widget)
    end)
    -- the rows below the ruler, they scroll on their own
    local rows = CreateFrame("Frame", nil, canvas)
    rows:SetPoint("TOPLEFT", canvas, "TOPLEFT", 0, -variables.rulerHeight)
    rows:SetPoint("BOTTOMRIGHT", canvas, "BOTTOMRIGHT")
    rows:SetClipsChildren(true)
    widget.rows = rows

    -- the empty part of the rows: a click unselects, a double click adds a reminder at that time and row
    local background = CreateFrame("Button", nil, rows)
    background:SetAllPoints(rows)
    background:SetFrameLevel(rows:GetFrameLevel() + 1)
    background:SetScript("OnClick", function()
        if widget.selected then
            Select(widget, nil)
        end
    end)
    background:SetScript("OnDoubleClick", function()
        local _, cursorY = GetCursorPosition()
        local y = rows:GetTop() - cursorY / rows:GetEffectiveScale()
        local tag
        for _, span in ipairs(widget.rowSpans) do
            if y >= span.top and y < span.bottom then
                tag = span.tag
            end
        end
        addReminder(widget, snapTime(getCursorTime(widget)), tag)
    end)
    canvas:EnableMouseWheel(true)
    canvas:SetScript("OnMouseWheel", function(_, delta)
        if IsControlKeyDown() then
            -- zooms around the time under the pointer
            local time = getCursorTime(widget)
            local cursorX = time * getPixelsPerSecond(widget) - widget.scroll
            widget.pixelsPerSecond = math.min(getPixelsPerSecond(widget) * (delta > 0 and 1.25 or 0.8),
                variables.maxPixelsPerSecond)
            setScroll(widget, time * getPixelsPerSecond(widget) - cursorX)
        elseif IsShiftKeyDown() then
            setRowScroll(widget, widget.rowScroll - delta * variables.laneHeight)
        else
            setScroll(widget, widget.scroll - delta * canvas:GetWidth() / 6)
        end
    end)

    widget.scrollX = createScrollBar(board, true, function(progress)
        setScroll(widget, progress * getMaxScroll(widget))
    end)
    widget.scrollX:SetPoint("TOPLEFT", canvas, "BOTTOMLEFT", 0, -6)
    widget.scrollX:SetPoint("TOPRIGHT", canvas, "BOTTOMRIGHT", 0, -6)
    widget.scrollX:SetHeight(variables.scrollBarSize)
    widget.scrollY = createScrollBar(board, false, function(progress)
        setRowScroll(widget, progress * getMaxRowScroll(widget))
    end)
    widget.scrollY:SetPoint("TOPLEFT", rows, "TOPRIGHT", 4, 0)
    widget.scrollY:SetPoint("BOTTOMLEFT", rows, "BOTTOMRIGHT", 4, 0)
    widget.scrollY:SetWidth(variables.scrollBarSize)
    widget.help = board:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    widget.help:SetPoint("BOTTOMLEFT", board, "BOTTOMLEFT", padding, 5)
    widget.help:SetText(L("EditorHelp"))
    widget.noBossMod = board:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    widget.noBossMod:SetPoint("BOTTOMRIGHT", board, "BOTTOMRIGHT", -padding, 5)
    widget.noBossMod:SetText(L("EditorNoBossMod"))
    widget.timelineParts = { labels, canvas, widget.scrollX, widget.scrollY, widget.help }

    -- the Boss timers tab: the rules of the encounter where the timeline is
    local rulesView = CreateFrame("Frame", nil, board)
    rulesView:SetPoint("TOPLEFT", board, "TOPLEFT", padding / 2, -padding / 2)
    rulesView:SetPoint("BOTTOMRIGHT", board, "BOTTOMRIGHT", -padding / 2, variables.footerHeight - 6)
    rulesView:Hide()
    rulesView.Empty = rulesView:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    rulesView.Empty:SetPoint("TOPLEFT", padding, -padding)
    rulesView.Empty:SetPoint("TOPRIGHT", -padding, -padding)
    rulesView.Empty:SetJustifyH("LEFT")
    rulesView.Empty:SetSpacing(3)
    rulesView.Empty:SetText(L("EditorRulesEmpty"))
    widget.rulesView = rulesView
    local ruleList = AceGUI:Create("AtScrollFrame")
    ruleList:SetLayout("List")
    ruleList.frame:SetParent(rulesView)
    ruleList.frame:SetAllPoints(rulesView)
    widget.ruleList = ruleList

    -- the panel of the selected reminder: its name, three tabs of fields and duplicate / delete always at the bottom
    local panel = CreateFrame("Frame", nil, main)
    panel:SetPoint("TOPLEFT", toolbar, "BOTTOMRIGHT", -variables.inspectorWidth, -padding)
    panel:SetPoint("BOTTOMRIGHT", main, "BOTTOMRIGHT", -padding, padding)
    ThemeApply.CreatePanel(panel)
    panel.Empty = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    panel.Empty:SetPoint("TOPLEFT", padding, -padding)
    panel.Empty:SetPoint("TOPRIGHT", -padding, -padding)
    panel.Empty:SetJustifyH("LEFT")
    panel.Empty:SetSpacing(3)
    panel.Empty:SetText(L("EditorSelectHint"))
    widget.inspectorPanel = panel

    local header = CreateFrame("Frame", nil, panel)
    header:SetPoint("TOPLEFT", panel, "TOPLEFT", padding, -padding)
    header:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -padding, -padding)
    header:SetHeight(variables.headerHeight)
    header.Icon = header:CreateTexture(nil, "ARTWORK")
    header.Icon:SetSize(variables.headerIcon, variables.headerIcon)
    header.Icon:SetPoint("LEFT")
    header.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    header.Title = header:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    header.Title:SetPoint("TOPLEFT", header.Icon, "TOPRIGHT", 10, -1)
    header.Title:SetPoint("RIGHT", header, "RIGHT")
    header.Title:SetJustifyH("LEFT")
    header.Title:SetWordWrap(false)
    header.Where = header:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    header.Where:SetPoint("BOTTOMLEFT", header.Icon, "BOTTOMRIGHT", 10, 1)
    header.Where:SetPoint("RIGHT", header, "RIGHT")
    header.Where:SetJustifyH("LEFT")
    header.Where:SetWordWrap(false)
    header.Line = header:CreateTexture(nil, "ARTWORK")
    header.Line:SetHeight(1)
    header.Line:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 0, -6)
    header.Line:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", 0, -6)
    panel.Header = header

    local tabs = CreateFrame("Frame", nil, panel)
    tabs:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -padding)
    tabs:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, -padding)
    tabs:SetHeight(variables.tabHeight)
    tabs.Buttons = {}
    local tabWidth = (variables.inspectorWidth - padding * 2 - gap * (#INSPECTOR_TABS - 1)) / #INSPECTOR_TABS
    for index, key in ipairs(INSPECTOR_TABS) do
        local tab = createButton(tabs, L("EditorTab_" .. key), function()
            widget.inspectorTab = key
            ShowInspector(widget)
        end)
        tab.key = key
        tab:SetSize(tabWidth, variables.tabHeight)
        tab:SetPoint("LEFT", tabs, "LEFT", (index - 1) * (tabWidth + gap), 0)
        tabs.Buttons[index] = tab
    end
    panel.Tabs = tabs

    local footer = CreateFrame("Frame", nil, panel)
    footer:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", padding, padding)
    footer:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -padding, padding)
    footer:SetHeight(variables.toolbarHeight)
    local half = (variables.inspectorWidth - padding * 2 - gap) / 2
    widget.duplicateButton = createButton(footer, L("EditorDuplicate"), function() duplicateSelected(widget) end)
    widget.duplicateButton:SetWidth(half)
    widget.duplicateButton:SetPoint("LEFT", footer, "LEFT")
    widget.deleteButton = createButton(footer, L("ReminderDeleteButton"), function() deleteSelected(widget) end, "Danger")
    widget.deleteButton:SetWidth(half)
    widget.deleteButton:SetPoint("RIGHT", footer, "RIGHT")
    panel.Footer = footer

    local inspector = AceGUI:Create("AtScrollFrame")
    inspector:SetLayout("List")
    inspector.frame:SetParent(panel)
    inspector.frame:SetPoint("TOPLEFT", tabs, "BOTTOMLEFT", -4, -gap)
    inspector.frame:SetPoint("BOTTOMRIGHT", footer, "TOPRIGHT", 4, gap)
    widget.inspector = inspector

    ApplySettings(widget)
    private.RegisterThemed(widget)

    return AceGUI:RegisterAsWidget(widget)
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)
