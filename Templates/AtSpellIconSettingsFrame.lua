local addonName, private = ...
local AceGUI = LibStub("AceGUI-3.0")
local Type = "AtSpellIconSettingsFrame"
local Version = 1
local variables = {
    width = 800,
    height = 500,
    ContentFramePadding = { x = 15, y = 15 },
	Padding = { x = 2, y = 2 },
}

---@param self AtSpellIconSettingsFrame
local function OnAcquire(self)
end

---@param self AtSpellIconSettingsFrame
local function OnRelease(self)
end

local function Constructor()
    local count = AceGUI:GetNextWidgetNum(Type)
    local frame = CreateFrame("Frame", "AtSpellIconSettingsFrame", UIParent, "PortraitFrameTemplateNoCloseButton")
    frame:SetPortraitTextureRaw("Interface\\AddOns\\AbilityTimeline\\Media\\Textures\\portrait.tga")
    frame:SetPoint("CENTER", UIParent, "CENTER")
    frame:SetWidth(variables.width)
    frame:SetHeight(variables.height)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

    frame:SetTitle(private.getLocalisation("SpellIconSettings"))

    frame.CloseButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    frame.CloseButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)
    frame.CloseButton:SetScript("OnClick", function() private.closeSpellIconSettings() end)
    frame:Show()

    local contentFrameName = Type .. "ContentFrame" .. count
	local contentFrame = CreateFrame("Frame", contentFrameName, frame)
    contentFrame:ClearAllPoints()
	contentFrame:SetPoint(
		"TOPLEFT",
		frame,
		"TOPLEFT",
		variables.Padding.x + variables.ContentFramePadding.x,
		-variables.ContentFramePadding.y - frame.TitleContainer:GetHeight()
	)
	contentFrame:SetPoint(
		"BOTTOMRIGHT",
		frame,
		"BOTTOM"
	)
    local rightContentFrameName = Type .. "RightContentFrame" .. count
    local rightContentFrame = CreateFrame("Frame", rightContentFrameName, frame , "BackdropTemplate")
    rightContentFrame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 32, right = 32, top = 48, bottom = 32 }
    })
    rightContentFrame:ClearAllPoints()
	rightContentFrame:SetPoint(
		"TOPLEFT",
		frame,
		"TOP",
		variables.Padding.x,
		-variables.ContentFramePadding.y - frame.TitleContainer:GetHeight()
	)
	rightContentFrame:SetPoint(
		"BOTTOMRIGHT",
		frame,
		"BOTTOMRIGHT"
	)

    local IconPreviewTitle = rightContentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    IconPreviewTitle:SetFontHeight(32)
    IconPreviewTitle:SetPoint("CENTER", rightContentFrame, "TOP", 0, -32)
    IconPreviewTitle:SetText(private.getLocalisation("IconPreview"))


    ---@class AtSpellIconSettingsFrame : AceGUIWidget
    local widget = {
        OnAcquire = OnAcquire,
        OnRelease = OnRelease,
        type = Type,
        count = count,
        frame = frame,
        content = contentFrame,
        rightContent = rightContentFrame,
    }

    return AceGUI:RegisterAsContainer(widget)
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)
