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
}

---@param self AtTimingsEditorDataFrame
local function OnAcquire(self)

    self.frame:Show()
    self.container.frame:Show()
    private.Debug(self, "AT_TIMINGS_EDITOR_DATA_FRAME_ONACQUIRE")
end

---@param self AtTimingsEditorDataFrame
local function OnRelease(self)
    self.container:Release()
    for k, v in pairs(self.items) do
        private.Debug(v)
        v.spellContainer:Release()
    end
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

local Reminders = {}
local function AddReminder(self, reminder)
    -- Function to add a reminder to the data frame
end
local function HandleTicks(self)
    for i = 1, #self.timeline.Ticks do
        self.timeline.Ticks[i].frame:Hide()
        self.timeline.Ticks[i]:Release()
    end
    for i=1, math.floor(self.combatDuration/5) do
        local widget = AceGUI:Create("AtTimelineTicks")
        self.timeline.Ticks[i] = widget
        private.Debug(self.timeline, "AT_TIMINGS_EDITOR_TICKS")
        widget:SetTick(self.timeline, i*5, self.timeline:GetWidth(), self.combatDuration, true)
        widget.frame:Show()
    end
end

local function SetCombatDuration(self, duration)
    self.slider:SetSliderValues(0, duration , 1)
    self.slider:SetUserData('maxValue', duration)
    self.combatDuration = duration
    HandleTicks(self)
end

local function SetEncounter(self, dungeonId, encounterNumber, duration)
    local Instancename, Instancedescription, _, InstanceImage, _, _, _, _, _ = EJ_GetInstanceInfo(dungeonId)
    local EncounterName, Encounterdescription, journalEncounterID, rootSectionID, link, journalInstanceID, dungeonEncounterID, instanceID =
    EJ_GetEncounterInfoByIndex(encounterNumber, dungeonId)
    self.container:SetTitle(private.getLocalisation("TimingsEditorTitle") .. Instancename .. " - " .. EncounterName)
    SetCombatDuration(self, 295)  -- Example duration, replace with actual encounter duration if available
    -- for key, value in pairs(private.Instances[dungeonId].encounters[encounterNumber].spells) do
    --     local spellInfo = C_Spell.GetSpellInfo(value.spellID);
    --     frame:AddItem({
    --         spellname = spellInfo.name,
    --         spellicon = spellInfo.iconID,
    --         timings = value.timings,
    --         rowText = "Spell: " .. spellInfo.name .. " (ID: " .. value.spellID .. ")",
    --         type = value.type,
    --     })
    -- end
    self.addEntryButton:SetCallback("OnClick", function()
        if self.addEntry then return end
        private.Debug("Add Entry Button Clicked")
        self.addEntry = AceGUI:Create("AtReminderCreator")

        local timing = AceGUI:Create("EditBox")
        timing:SetLabel(private.getLocalisation("ReminderCreatorTimingLabel"))
        timing:SetText("0")
        self.addEntry:AddChild(timing)

        local addButton = AceGUI:Create("Button")
        addButton:SetText(private.getLocalisation("ReminderCreatorAddButton"))
        self.addEntry:AddChild(addButton)

        self.addEntry.frame:Show()
        self.addEntry.closeButton:SetScript("OnClick", function()
            self.addEntry:Release()
            self.addEntry = nil
        end)
        
    end)
end


local function Constructor()
	local count = AceGUI:GetNextWidgetNum(Type)

    -- main window
    local container = AceGUI:Create("ATTimingsEditorContainer")
    local main = container.content

    -- parent vertical ScrollFrame (this controls vertical scrolling for both columns)
    local vscroll = CreateFrame("ScrollFrame", Type .."_VScroll", main, "UIPanelScrollFrameTemplate")
    vscroll:SetPoint("TOPLEFT", main, "TOPLEFT", 10, -10)
    vscroll:SetPoint("BOTTOMRIGHT", main, "BOTTOMRIGHT", -10, 10)

    -- content frame that is the scroll child. Height must be >= visible content height.
    local content = CreateFrame("Frame", Type .."_Content", vscroll)
    content:SetSize(variables.FrameLeftSize + variables.FrameRightSize, 1200) -- content height bigger than visible to allow vertical scroll
    vscroll:SetScrollChild(content)

    -- LEFT column (fixed width). 
    local left = CreateFrame("Frame", Type .."_Left", content , "BackdropTemplate")
    left:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
    left:SetSize(variables.FrameLeftSize, content:GetHeight())
    left:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    left:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
    left:SetBackdropBorderColor(0.25, 0.25, 0.25, 0.9)

    local leftContent = AceGUI:Create("SimpleGroup")
    leftContent:SetLayout("Flow")
    leftContent:SetParent(left)
    leftContent.frame:SetAllPoints(left)
    leftContent.frame:SetFrameLevel(left:GetFrameLevel() + 50)

    local addEntryButton = AceGUI:Create("Button")
    addEntryButton:SetText(private.getLocalisation("TimingsEditorAddEntryButton"))
    leftContent:AddChild(addEntryButton)



    -- RIGHT column: a Clip/viewport frame that will host a horizontal ScrollFrame
    local rightViewport = CreateFrame("Frame", Type .."_RightViewport", content)
    rightViewport:SetPoint("TOPLEFT", content, "TOPLEFT", variables.FrameLeftSize + 10, 0)
    rightViewport:SetSize(variables.FrameRightSize, vscroll:GetHeight()- 20) -- visible viewport size inside content

    -- right horizontal ScrollFrame (no vertical bar). It is a child of content so it moves with parent vertical scroll.
    local hscroll = CreateFrame("ScrollFrame", Type .."_RightHScroll", rightViewport)
    hscroll:SetAllPoints(rightViewport)

    -- right content must be wider than viewport to allow horizontal scroll
    local rightContent = CreateFrame("Frame", Type .."_RightContent", hscroll, "BackdropTemplate")
    rightContent:SetSize(1600, content:GetHeight()) -- make it wide; height matches content so vertical scroll is handled by parent
    hscroll:SetScrollChild(rightContent)

    rightContent:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 0, right = 0, top = 0, bottom = 0}
    })

    local timeline = CreateFrame("Frame", Type .."_Timeline", rightContent , "BackdropTemplate")
    timeline:SetPoint("TOPLEFT", rightContent, "TOPLEFT", 0, 0)
    timeline:SetPoint("TOPRIGHT", rightContent, "TOPRIGHT", 0, 0)
    timeline:SetHeight(40)
    timeline:SetFrameLevel(rightContent:GetFrameLevel() + 50)
    timeline.Ticks = {}


    -- add a horizontal slider under rightViewport to control horizontal scroll
    local hslider = AceGUI:Create("Slider")
    hslider.frame:SetSize(main:GetWidth() - variables.FrameLeftSize - 30, 20)
    hslider:SetPoint("BOTTOMRIGHT", main, "BOTTOMRIGHT", -10, 25)
    hslider:SetSliderValues(0, 300 , 1)
    hslider:SetUserData('maxValue', 300)
    hslider:SetValue(0)
    hslider:SetCallback("OnValueChanged", function(_, _, value)
        local sliderval = value/hslider:GetUserData('maxValue') * variables.sliderSize
        hscroll:SetHorizontalScroll(sliderval)
        print("HSlider value changed to " .. value .. ", setting hscroll to " .. sliderval)
    end)
    private.Debug(hslider, "AT_TIMINGS_EDITOR_HSLIDER")

	---@class AtTimingsEditorDataFrame : AceGUIWidget
	local widget = {
		OnAcquire = OnAcquire,
		OnRelease = OnRelease,
        AddItem = AddItem,
		frame = main,
        content = content,
		type = Type,
		count = count,
        container = container,
        items = ITEMS,
        rightContent = rightContent,
        leftContent = leftContent,
        slider = hslider,
        addEntryButton = addEntryButton,
        SetEncounter = SetEncounter,
        timeline = timeline,
	}

	return AceGUI:RegisterAsWidget(widget)
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)