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
}

---@param self AtTimingsEditorDataFrame
local function OnAcquire(self)

    self.frame:Show()
    self.container.frame:Show()
    DevTool:AddData(self, "AT_TIMINGS_EDITOR_DATA_FRAME_ONACQUIRE")
end

---@param self AtTimingsEditorDataFrame
local function OnRelease(self)
    self.container:Release()
    for k, v in pairs(self.items) do
        DevTools_Dump(v)
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
    separator:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background" })
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


    -- RIGHT column: a Clip/viewport frame that will host a horizontal ScrollFrame
    local rightViewport = CreateFrame("Frame", Type .."_RightViewport", content)
    rightViewport:SetPoint("TOPLEFT", content, "TOPLEFT", variables.FrameLeftSize + 10, 0)
    rightViewport:SetSize(variables.FrameRightSize, vscroll:GetHeight()) -- visible viewport size inside content

    -- right horizontal ScrollFrame (no vertical bar). It is a child of content so it moves with parent vertical scroll.
    local hscroll = CreateFrame("ScrollFrame", Type .."_RightHScroll", rightViewport)
    hscroll:SetAllPoints(rightViewport)

    -- right content must be wider than viewport to allow horizontal scroll
    local rightContent = CreateFrame("Frame", Type .."_RightContent", hscroll)
    rightContent:SetSize(1600, content:GetHeight()) -- make it wide; height matches content so vertical scroll is handled by parent
    hscroll:SetScrollChild(rightContent)


    -- add a horizontal slider under rightViewport to control horizontal scroll
    local hslider = CreateFrame("Slider", Type .."_HSlider", main, "OptionsSliderTemplate")
    hslider:SetOrientation("HORIZONTAL")
    hslider:SetPoint("TOPLEFT", main, "BOTTOMLEFT", variables.FrameLeftSize, 14)
    hslider:SetPoint("TOPRIGHT", main, "BOTTOMRIGHT", -40, 14)
    hslider:SetMinMaxValues(0, math.max(0, rightContent:GetWidth() - rightViewport:GetWidth()))
    hslider:SetValueStep(1)
    hslider:SetValue(0)
    hslider:SetScript("OnValueChanged", function(self, val)
        hscroll:SetHorizontalScroll(val)
    end)

    -- update slider range if sizes change
    local function UpdateRanges()
        local maxh = math.max(0, rightContent:GetWidth() - rightViewport:GetWidth())
        hslider:SetMinMaxValues(0, maxh)
        -- vertical scrollbar range handled automatically by UIPanelScrollFrameTemplate; if you use a custom scroll you must update it here
    end

    -- call UpdateRanges after layout or when content size changes
    UpdateRanges()

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
        leftContent = left
	}

	return AceGUI:RegisterAsWidget(widget)
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)