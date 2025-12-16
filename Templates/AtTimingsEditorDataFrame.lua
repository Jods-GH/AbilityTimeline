local addonName, private = ...
local AceGUI = LibStub("AceGUI-3.0")

local Type = "AtTimingsEditorDataFrame"
local Version = 1
local variables = {
	BackdropBorderColor = { 0.25, 0.25, 0.25, 0.9 },
	BackdropColor = { 0, 0, 0, 0.9 },
	FrameHeight = 600,
	FrameWidth = 800,
	Backdrop = {
		bgFile = nil,
		edgeFile = nil,
		tile = true,
		tileSize = 16,
		edgeSize = 1,
	},
    FrameLeftSize = 240,
    FrameRightSize = 800,
	Padding = { x = 2, y = 2 },
    sliderSize = 1100,
    timelinePixelsPerSecond = 6,
    RowHeight = 44,
    RowPadding = 8,
}

local function formatTime(seconds)
    seconds = tonumber(seconds) or 0
    local minutes = math.floor(seconds / 60)
    local secs = seconds - minutes * 60
    return string.format("%d:%05.2f", minutes, secs)
end

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function copyReminder(reminder)
    local t = {}
    for k, v in pairs(reminder or {}) do
        t[k] = v
    end
    return t
end

local function ensureReminderDB()
    if not private.db.profile.reminders then
        private.db.profile.reminders = {}
    end
end

---@param self AtTimingsEditorDataFrame
local function OnAcquire(self)
    self.frame:Show()
    self.frame:SetPoint("CENTER", UIParent, "CENTER")
    self.frame:SetWidth(variables.FrameLeftSize + variables.FrameRightSize + 40)
    self.frame:SetHeight(variables.FrameHeight)
    private.Debug(self, "AT_TIMINGS_EDITOR_DATA_FRAME_ONACQUIRE")
end

---@param self AtTimingsEditorDataFrame
local function OnRelease(self)

        if self.reminderList then
            self.reminderList:ReleaseChildren()
        end
        if self.items then
            for _, v in pairs(self.items) do
                if v.spellContainer then
                    v.spellContainer:Release()
                end
            end
        end
        if self.reminderPins then
            for _, pin in ipairs(self.reminderPins) do
                if pin and pin.Hide then pin:Hide() end
                if pin and pin.SetParent then pin:SetParent(nil) end
            end
        end
        self.reminderPins = {}
        -- Extra safety: also clear any stray timeline children
        if self.timeline and self.timeline.GetChildren then
            local children = { self.timeline:GetChildren() }
            for _, child in ipairs(children) do
                if child and child.isReminderPin then
                    child:Hide()
                    child:SetParent(nil)
                end
            end
        end
        self.reminderRows = {}
        self.items = {}
end

local ITEMS = {}

local function AddItem(self, item)
    local spellContainer = AceGUI:Create("AtEditorSpellIcon")
    spellContainer:SetAbility(item.spellicon, item.spellname)
    local i = #self.items
    spellContainer.frame:SetSize(variables.FrameLeftSize - 20, 30)
    spellContainer.frame:SetPoint("TOPLEFT", self.leftContent, "TOPLEFT", 10, -10 - (i) * 36)

    local row = CreateFrame("Frame", nil, self.rightContent)
    row:SetSize(1400, 34)
    row:SetPoint("TOPLEFT", self.rightContent, "TOPLEFT", 10, -10 - (i) * 36)
    local t = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    t:SetPoint("LEFT", row, "LEFT", 4, 0)
    t:SetText(item.rowText)

    local separator = CreateFrame("Frame", nil, self.rightContent, "BackdropTemplate")
    separator:SetPoint("LEFT",  self.rightContent, "LEFT",  0, -10 - (i + 1) * 36)
    separator:SetPoint("RIGHT", self.rightContent, "RIGHT", 0, -10 - (i + 1) * 36)
    separator:SetHeight(20)
    separator:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    separator:SetBackdropColor(0.2,0.2,0.2,0.9)
    separator:SetFrameLevel(self.rightContent:GetFrameLevel() + 50)
    separator:Show()



    -- Function to add an item to the data frame
    table.insert(ITEMS, {
        spellContainer = spellContainer,
        row = row,
        separator = separator,
        data = item,
    })

end

local function HandleTicks(self)
    if not self.timeline then return end
    for i = 1, #self.timeline.Ticks do
        self.timeline.Ticks[i].frame:Hide()
        self.timeline.Ticks[i]:Release()
    end
    wipe(self.timeline.Ticks)
    local tickCount = math.floor((self.combatDuration or 0) / 15)
    local timelineWidth = self.timeline:GetWidth()
    for i = 1, tickCount do
        local widget = AceGUI:Create("AtTimelineTicks")
        self.timeline.Ticks[i] = widget
        widget:SetTick(self.timeline, i * 15, timelineWidth, self.combatDuration, true)
        widget.frame:Show()
    end
end

local function UpdateTimelineWidth(self)
    if not self.rightContent or not self.timeline or not self.rightViewport or not self.hslider then return end
    local width = math.max(variables.FrameRightSize, math.floor((self.combatDuration or 0) * variables.timelinePixelsPerSecond) + 200)
    self.rightContent:SetWidth(width)
    self.timeline:SetWidth(width)
    local maxScroll = math.max(0, width - self.rightViewport:GetWidth())
    self.hslider:SetSliderValues(0, self.combatDuration or 0, 1)
    local value = math.min(self.hslider:GetValue() or 0, self.combatDuration or 0)
    self.hslider:SetValue(value)
    local scrollPos = (value / (self.combatDuration or 1)) * maxScroll
    self.hscroll:SetHorizontalScroll(scrollPos)

    self.hslider:SetCallback("OnValueChanged", function(_, _, value)
        local scrollPos = (value / (self.combatDuration or 1)) * maxScroll
        self.hscroll:SetHorizontalScroll(scrollPos)
    end)
end

local function SetCombatDuration(self, duration)
    self.combatDuration = tonumber(duration) or private.db.profile.editor.defaultEncounterDuration or 300
    if self.durationBox then
        self.durationBox:SetText(tostring(math.floor(self.combatDuration)))
    end
    UpdateTimelineWidth(self)
    HandleTicks(self)
end

local function getReminderTexture(reminder)
    private.Debug(reminder, "Reminder")
    private.Debug("No iconId found in reminder")
    if reminder.spellId then
        print("Getting spell icon for spell ID: ".. tostring(reminder.spellId))
        local icon =  C_Spell.GetSpellTexture(reminder.spellId)
        print(icon)
        if icon then 
            return icon 
            end
    elseif reminder.iconId then 
        return reminder.iconId 
    end
    return 134400
end

local function clearPins(self)
    if not self.reminderPins then return end
    if self.rowBands then
        for _, band in ipairs(self.rowBands) do
            if band and band.Hide then band:Hide() end
            if band and band.SetParent then band:SetParent(nil) end
        end
    end
    self.rowBands = {}
    -- Hide and destroy all tracked pins and their delay bars
    for _, pin in ipairs(self.reminderPins) do
        if pin and pin.delayBar then
            pin.delayBar:Hide()
            if pin.delayBar.Destroy then
                pin.delayBar:Destroy()
            else
                pin.delayBar:SetParent(nil)
            end
        end
        if pin and pin.Hide then
            pin:Hide()
        end
        if pin and pin.SetParent then
            pin:SetParent(nil)
        end
    end
    wipe(self.reminderPins)

    -- Extra safety: also clear any stray children that were not tracked
    if self.timeline and self.timeline.GetChildren then
        local children = { self.timeline:GetChildren() }
        for _, child in ipairs(children) do
            if child and child.isReminderPin then
                child:Hide()
                child:SetParent(nil)
            end
            if child and child.isDelayBar then
                child:Hide()
                if child.Destroy then
                    child:Destroy()
                else
                    child:SetParent(nil)
                end
            end
        end
    end
end

local function anchorPin(self, pin, time, rowIndex)
    local width = self.timeline and self.timeline:GetWidth() or 0
    if width <= 0 or not self.combatDuration or self.combatDuration <= 0 then return end
    local pos = (time / self.combatDuration) * width
    local rowHeight = variables.RowHeight
    local rowPadding = variables.RowPadding
    local y = -rowPadding - (rowIndex - 1) * (rowHeight + rowPadding) - (rowHeight * 0.5)
    pin:ClearAllPoints()
    pin:SetPoint("CENTER", self.timeline, "TOPLEFT", pos, y)
    -- position/size delay bar if present (extends right from the icon)
    if pin.delayBar then
        local delay = tonumber(pin.delaySeconds) or 0
        if delay > 0 then
            local pixelsPerSecond = variables.timelinePixelsPerSecond or 6
            local barWidth = math.max(0, delay * pixelsPerSecond)
            pin.delayBar:ClearAllPoints()
            pin.delayBar:SetPoint("LEFT", self.timeline, "TOPLEFT", pos + 2, y)
            pin.delayBar:SetSize(barWidth, 6)
            pin.delayBar:Show()
        else
            pin.delayBar:Hide()
        end
    end
end

local function SortReminders(self)
    table.sort(self.reminders, function(a, b)
        return (a.CombatTime or 0) < (b.CombatTime or 0)
    end)
end

local function SaveReminders(self)
    ensureReminderDB()
    if not self.encounterID then return end
    local copy = {}
    for _, reminder in ipairs(self.reminders) do
        table.insert(copy, copyReminder(reminder))
    end
    private.db.profile.reminders[self.encounterID] = copy
end

local function createPin(self, reminder, rowIndex)
    local pin = CreateFrame("Button", nil, self.timeline, "BackdropTemplate")
    pin:SetSize(20, 20)
    -- mark so we can reliably clear later
    pin.isReminderPin = true
    pin.icon = pin:CreateTexture(nil, "ARTWORK")
    pin.icon:SetAllPoints()
    local texture = getReminderTexture(reminder)
    private.Debug("Setting texture: ".. texture)
    pin.icon:SetTexture(texture)
    -- optional delay bar behind the icon representing CombatTimeDelay
    local delay = tonumber(reminder.CombatTimeDelay) or 0
    pin.delaySeconds = delay
    pin.delayBar = CreateFrame("Frame", nil, self.timeline, "BackdropTemplate")
    pin.delayBar.isDelayBar = true  -- mark for cleanup
    pin.delayBar:SetFrameLevel(pin:GetFrameLevel() - 1)
    pin.delayBar:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        tile = true,
        tileSize = 8,
        edgeSize = 0,
    })
    pin.delayBar:SetBackdropColor(1, 1, 1, 0.6) -- semi-transparent white bar
    pin.delayBar:Hide()
    pin:SetScript("OnEnter", function()
        GameTooltip:SetOwner(pin, "ANCHOR_TOP")
        GameTooltip:AddLine(reminder.name or reminder.spellName or private.getLocalisation("ReminderCreatorTitle"))
        GameTooltip:AddLine(formatTime(reminder.CombatTime or 0), 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    pin:SetScript("OnLeave", function() GameTooltip:Hide() end)
    -- Disable dragging for now to prevent XY drag bugs and duplication
    -- If needed later, implement X-only dragging with constrained repositioning.
    anchorPin(self, pin, reminder.CombatTime or 0, rowIndex)
    table.insert(self.reminderPins, pin)
end

local function clearReminderRows(self)
    if self.reminderList then
        self.reminderList:ReleaseChildren()
    end
    wipe(self.reminderRows)
end

local function deleteReminder(self, index)
    table.remove(self.reminders, index)
    SaveReminders(self)
    self:RefreshReminders()
end

local function createRow(self, reminder, index)
    local row = AceGUI:Create("SimpleGroup")
    row:SetLayout("Flow")
    row:SetFullWidth(true)

    local icon = AceGUI:Create("Icon")
    icon:SetImage(getReminderTexture(reminder))
    icon:SetImageSize(18, 18)
    icon:SetWidth(24)
    row:AddChild(icon)

    local label = AceGUI:Create("InteractiveLabel")
    local name = reminder.name or reminder.spellName or private.getLocalisation("ReminderCreatorTitle")
    label:SetText(string.format("%s - %s", name, formatTime(reminder.CombatTime)))
    label:SetFullWidth(true)
    label:SetCallback("OnClick", function()
        self:OpenReminderDialog(index)
    end)
    row:AddChild(label)

    local editBtn = AceGUI:Create("Button")
    editBtn:SetText(private.getLocalisation("ReminderEditButton"))
    editBtn:SetWidth(60)
    editBtn:SetCallback("OnClick", function()
        self:OpenReminderDialog(index)
    end)
    row:AddChild(editBtn)

    local deleteBtn = AceGUI:Create("Button")
    deleteBtn:SetText(private.getLocalisation("ReminderDeleteButton"))
    deleteBtn:SetWidth(60)
    deleteBtn:SetCallback("OnClick", function()
        deleteReminder(self, index)
    end)
    row:AddChild(deleteBtn)

    self.reminderList:AddChild(row)
    table.insert(self.reminderRows, row)
end

local function RefreshReminders(self)
    clearReminderRows(self)
    clearPins(self)
    if #self.reminders == 0 then
        local emptyLabel = AceGUI:Create("Label")
        emptyLabel:SetText(private.getLocalisation("ReminderListEmpty"))
        emptyLabel:SetFullWidth(true)
        self.reminderList:AddChild(emptyLabel)
        table.insert(self.reminderRows, emptyLabel)
        UpdateTimelineWidth(self)
        HandleTicks(self)
        return
    end

    SortReminders(self)

    -- Build a map from reminder reference to its index in the master list so edit/delete target the correct entry
    local reminderIndexMap = {}
    for i, r in ipairs(self.reminders) do
        reminderIndexMap[r] = i
    end

    -- Group reminders by spell (or name) so each spell gets its own row on the timeline
    local groups = {}
    local order = {}
    for _, reminder in ipairs(self.reminders) do
        local rawKey = reminder.spellId or reminder.spellName or reminder.name or reminder.iconId or "Unknown"
        local key = tostring(rawKey)
        local name = reminder.spellName or reminder.name or "Unknown"
        if type(name) ~= "string" then name = tostring(name) end
        if not groups[key] then
            groups[key] = {
                key = key,
                name = name,
                icon = getReminderTexture(reminder),
                reminders = {},
            }
            table.insert(order, key)
        end
        table.insert(groups[key].reminders, reminder)
    end

    table.sort(order, function(a, b)
        return tostring(groups[a].name or "") < tostring(groups[b].name or "")
    end)

    local rowHeight = variables.RowHeight
    local rowPadding = variables.RowPadding
    local rowsCount = #order
    local totalRowsHeight = rowsCount * (rowHeight + rowPadding) + rowPadding

    -- Ensure the timeline and its scroll child are tall enough to show all rows
    local targetHeight = math.max(totalRowsHeight + 20, self.rightViewport:GetHeight())
    self.timeline:SetHeight(targetHeight)
    self.rightContent:SetHeight(targetHeight + 20)

    -- Alternate row backgrounds for readability
    self.rowBands = self.rowBands or {}
    for idx, key in ipairs(order) do
        local top = -rowPadding - (idx - 1) * (rowHeight + rowPadding)
        local band = self.timeline:CreateTexture(nil, "BACKGROUND", nil, -8)
        local shade = (idx % 2 == 0) and 0.10 or 0.14
        band:SetColorTexture(shade, shade, shade, 0.55)
        band:SetPoint("TOPLEFT", self.timeline, "TOPLEFT", 0, top)
        band:SetPoint("TOPRIGHT", self.timeline, "TOPRIGHT", 0, top)
        band:SetHeight(rowHeight)
        table.insert(self.rowBands, band)
    end

    -- Build rows in the reminder list (kept sorted by time within each spell)
    local maxTime = 0
    local rowIndex = 0
    for _, key in ipairs(order) do
        rowIndex = rowIndex + 1
        local group = groups[key]
        table.sort(group.reminders, function(a, b)
            return (a.CombatTime or 0) < (b.CombatTime or 0)
        end)
        for _, reminder in ipairs(group.reminders) do
            maxTime = math.max(maxTime, reminder.CombatTime or 0)
            local actualIndex = reminderIndexMap[reminder]
            createRow(self, reminder, actualIndex)
            createPin(self, reminder, rowIndex)
        end
    end

    SetCombatDuration(self, math.max(self.combatDuration or 0, maxTime + 10))
    UpdateTimelineWidth(self)
    HandleTicks(self)
end

local function OpenReminderDialog(self, reminderIndex)
    if self.addEntry then
        self.addEntry:Release()
    end

    local isEditing = reminderIndex ~= nil and self.reminders[reminderIndex] ~= nil
    local current = isEditing and copyReminder(self.reminders[reminderIndex]) or {}
    local dialog = AceGUI:Create("AtReminderCreator")

    local nameBox = AceGUI:Create("EditBox")
    nameBox:SetLabel(private.getLocalisation("ReminderNameLabel"))
    nameBox:SetText(current.name or current.spellName or "")
    nameBox:SetFullWidth(true)
    dialog:AddChild(nameBox)

    local spellIdBox = AceGUI:Create("EditBox")
    spellIdBox:SetLabel(private.getLocalisation("ReminderSpellIdLabel"))
    spellIdBox:SetText(current.spellId and tostring(current.spellId) or "")
    spellIdBox:SetFullWidth(true)
    dialog:AddChild(spellIdBox)

    local iconPreview = AceGUI:Create("Icon")
    iconPreview:SetImage(getReminderTexture(current))
    iconPreview:SetImageSize(24, 24)
    dialog:AddChild(iconPreview)

    local timingBox = AceGUI:Create("EditBox")
    timingBox:SetLabel(private.getLocalisation("ReminderCreatorTimingLabel"))
    timingBox:SetText(tostring(current.CombatTime or 0))
    timingBox:SetFullWidth(true)
    dialog:AddChild(timingBox)

    local delayBox = AceGUI:Create("EditBox")
    delayBox:SetLabel(private.getLocalisation("ReminderDelayLabel"))
    delayBox:SetText(tostring(current.CombatTimeDelay or 0))
    delayBox:SetFullWidth(true)
    dialog:AddChild(delayBox)

    local severity = AceGUI:Create("Dropdown")
    severity:SetLabel(private.getLocalisation("ReminderSeverityLabel"))
    severity:SetList({
        [0] = "Info",
        [1] = "Alert",
        [2] = "Critical",
    })
    severity:SetValue(current.severity or 0)
    dialog:AddChild(severity)

    local function refreshSpellInfo()
        local spellId = tonumber(spellIdBox:GetText())
        if spellId then
            local spellName, _, icon = C_Spell.GetSpellInfo(spellId)
            if spellName then
                iconPreview:SetImage(icon)
                if nameBox:GetText() == "" then
                    nameBox:SetText(spellName)
                end
            end
        end
    end

    spellIdBox:SetCallback("OnEnterPressed", function()
        refreshSpellInfo()
    end)

    local buttons = AceGUI:Create("SimpleGroup")
    buttons:SetLayout("Flow")
    buttons:SetFullWidth(true)

    local saveButton = AceGUI:Create("Button")
    saveButton:SetText(private.getLocalisation("ReminderSaveButton"))
    saveButton:SetCallback("OnClick", function()
        local timeValue = tonumber(timingBox:GetText())
        if not timeValue then
            print(private.getLocalisation("ReminderInvalidTime"))
            return
        end
        local spellId = tonumber(spellIdBox:GetText())
        local spellName, _, icon = spellId and C_Spell.GetSpellInfo(spellId) or nil
        local reminder = {
            name = nameBox:GetText() ~= "" and nameBox:GetText() or spellName,
            spellId = spellId,
            spellName = spellName or nameBox:GetText(),
            iconId = icon or getReminderTexture(current),
            CombatTime = timeValue,
            CombatTimeDelay = tonumber(delayBox:GetText()) or 0,
            severity = severity:GetValue() or 0,
        }
        if isEditing then
            self.reminders[reminderIndex] = reminder
        else
            table.insert(self.reminders, reminder)
        end
        SortReminders(self)
        SaveReminders(self)
        SetCombatDuration(self, math.max(self.combatDuration or 0, timeValue + 5))
        self:RefreshReminders()
        dialog:Release()
        self.addEntry = nil
    end)
    buttons:AddChild(saveButton)

    if isEditing then
        local deleteButton = AceGUI:Create("Button")
        deleteButton:SetText(private.getLocalisation("ReminderDeleteButton"))
        deleteButton:SetCallback("OnClick", function()
            deleteReminder(self, reminderIndex)
            dialog:Release()
            self.addEntry = nil
        end)
        buttons:AddChild(deleteButton)
    end

    local cancelButton = AceGUI:Create("Button")
    cancelButton:SetText(private.getLocalisation("ReminderCancelButton"))
    cancelButton:SetCallback("OnClick", function()
        dialog:Release()
        self.addEntry = nil
    end)
    buttons:AddChild(cancelButton)

    dialog:AddChild(buttons)

    dialog.frame:Show()
    dialog.closeButton:SetScript("OnClick", function()
        dialog:Release()
        self.addEntry = nil
    end)

    self.addEntry = dialog
end

local function loadReminders(self, encounterID)
    ensureReminderDB()
    local stored = private.db.profile.reminders[encounterID] or {}
    self.reminders = {}
    for _, reminder in ipairs(stored) do
        table.insert(self.reminders, copyReminder(reminder))
    end
    SortReminders(self)
end

local function SetEncounter(self, dungeonId, encounterNumber, duration, encounterID)
    local Instancename = EJ_GetInstanceInfo(dungeonId)
    local EncounterName, _, journalEncounterID = EJ_GetEncounterInfoByIndex(encounterNumber, dungeonId)
    self.encounterID = encounterID or journalEncounterID
    self.container:SetTitle(string.format("%s%s - %s", private.getLocalisation("TimingsEditorTitle"), Instancename or "", EncounterName or ""))
    -- Clear any existing pins/rows before loading new encounter data
    clearPins(self)
    clearReminderRows(self)
    loadReminders(self, self.encounterID)
    SetCombatDuration(self, duration or private.db.profile.editor.defaultEncounterDuration)
    UpdateTimelineWidth(self)
    HandleTicks(self)
    self:RefreshReminders()
    self.addEntryButton:SetCallback("OnClick", function()
        self:OpenReminderDialog(nil)
    end)
    -- Ensure everything is visible
    if self.container and self.container.frame then
        self.container.frame:Show()
    end
    self.frame:Show()
end


local function Constructor()
	local count = AceGUI:GetNextWidgetNum(Type)

    -- main window
    local container = AceGUI:Create("ATTimingsEditorContainer")
    local main = container.content

    -- LEFT column (fixed width)
    local left = CreateFrame("Frame", Type .."_Left", main, "BackdropTemplate")
    left:SetPoint("TOPLEFT", main, "TOPLEFT", 10, -10)
    left:SetPoint("BOTTOMLEFT", main, "BOTTOMLEFT", 10, 40)
    left:SetWidth(variables.FrameLeftSize)
    left:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    left:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
    left:SetBackdropBorderColor(0.25, 0.25, 0.25, 0.9)

    -- Create a container for controls at top (label, duration, button)
    local controlsContainer = AceGUI:Create("SimpleGroup")
    controlsContainer:SetLayout("List")
    controlsContainer:SetParent(left)
    controlsContainer.frame:SetPoint("TOPLEFT", left, "TOPLEFT", 0, 0)
    controlsContainer.frame:SetPoint("TOPRIGHT", left, "TOPRIGHT", 0, 0)
    controlsContainer.frame:SetFrameLevel(left:GetFrameLevel() + 50)

    local durationBox = AceGUI:Create("EditBox")
    durationBox:SetLabel(private.getLocalisation("ReminderDurationLabel"))
    durationBox:SetText(tostring(private.db.profile.editor.defaultEncounterDuration or 300))
    durationBox:SetFullWidth(true)
    controlsContainer:AddChild(durationBox)

    local addEntryButton = AceGUI:Create("Button")
    addEntryButton:SetText(private.getLocalisation("TimingsEditorAddEntryButton"))
    addEntryButton:SetRelativeWidth(1)
    addEntryButton:SetHeight(20)
    controlsContainer:AddChild(addEntryButton)

    -- Reminder list below controls, filling remaining space
    local reminderList = AceGUI:Create("ScrollFrame")
    reminderList:SetLayout("List")
    reminderList:SetParent(left)
    reminderList.frame:SetPoint("TOPLEFT", left, "TOPLEFT", 0, -125)
    reminderList.frame:SetPoint("BOTTOMRIGHT", left, "BOTTOMRIGHT", 0, 0)
    reminderList.frame:SetFrameLevel(left:GetFrameLevel() + 50)

    -- RIGHT column: viewport with horizontal scroll for timeline
    local rightViewport = CreateFrame("Frame", Type .."_RightViewport", main)
    rightViewport:SetPoint("TOPLEFT", main, "TOPLEFT", variables.FrameLeftSize + 20, -10)
    rightViewport:SetPoint("TOPRIGHT", main, "TOPRIGHT", -10, -10)
    rightViewport:SetPoint("BOTTOMRIGHT", main, "BOTTOMRIGHT", -10, 40)

    -- right horizontal ScrollFrame
    local hscroll = CreateFrame("ScrollFrame", Type .."_RightHScroll", rightViewport)
    hscroll:SetAllPoints(rightViewport)

    -- right content must be wider than viewport to allow horizontal scroll
    local rightContent = CreateFrame("Frame", Type .."_RightContent", hscroll, "BackdropTemplate")
    rightContent:SetSize(2000, rightViewport:GetHeight())
    hscroll:SetScrollChild(rightContent)

    rightContent:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 0, right = 0, top = 0, bottom = 0}
    })
    rightContent:SetBackdropColor(0.08, 0.08, 0.08, 0.9)
    rightContent:SetBackdropBorderColor(0.2, 0.2, 0.2, 0.9)

    local timeline = CreateFrame("Frame", Type .."_Timeline", rightContent, "BackdropTemplate")
    timeline:SetPoint("TOPLEFT", rightContent, "TOPLEFT", 10, -25)
    timeline:SetPoint("BOTTOMRIGHT", rightContent, "BOTTOMRIGHT", -10, 10)
    timeline:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 0, right = 0, top = 0, bottom = 0}
    })
    timeline:SetBackdropColor(0.05, 0.05, 0.06, 0.95)
    timeline:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.9)
    timeline:SetFrameLevel(rightContent:GetFrameLevel() + 50)
    timeline.Ticks = {}

    -- add a horizontal slider under rightViewport to control horizontal scroll
    local hslider = AceGUI:Create("Slider")
    hslider.frame:SetSize(rightViewport:GetWidth() - 20, 20)
    hslider:SetPoint("TOPLEFT", rightViewport, "BOTTOMLEFT", 0, 8)
    hslider:SetPoint("BOTTOMRIGHT", main, "BOTTOMRIGHT", -10, 8)
    hslider:SetSliderValues(0, 0, 1)
    hslider:SetUserData('maxScroll', 0)
    hslider:SetValue(0)
    hslider:SetCallback("OnValueChanged", function(_, _, value)
        hscroll:SetHorizontalScroll(value)
    end)
    private.Debug(hslider, "AT_TIMINGS_EDITOR_HSLIDER")
    
    -- Create a dummy content frame for compatibility
    local content = rightContent

	---@class AtTimingsEditorDataFrame : AceGUIWidget
	local widget = {
		OnAcquire = OnAcquire,
		OnRelease = OnRelease,
		frame = container.frame,
        content = main,
		type = Type,
		count = count,
        container = container,
        items = ITEMS,
        rightContent = rightContent,
        leftContent = controlsContainer,
        addEntryButton = addEntryButton,
        SetEncounter = SetEncounter,
        timeline = timeline,
        reminderList = reminderList,
        reminderPins = {},
        reminderRows = {},
        reminders = {},
        durationBox = durationBox,
        hslider = hslider,
        hscroll = hscroll,
        rightViewport = rightViewport,
        left = left,
        HandleTicks = HandleTicks,
        SetCombatDuration = SetCombatDuration,
        RefreshReminders = RefreshReminders,
        OpenReminderDialog = OpenReminderDialog,
        SaveReminders = SaveReminders,
        SortReminders = SortReminders,
	}

    durationBox:SetCallback("OnEnterPressed", function(_, _, value)
        widget:SetCombatDuration(value)
        widget:RefreshReminders()
    end)

	return AceGUI:RegisterAsWidget(widget)
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)