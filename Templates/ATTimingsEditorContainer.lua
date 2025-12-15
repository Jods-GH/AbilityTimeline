local addonName, private = ...
local AceGUI = LibStub("AceGUI-3.0")

local Type = "ATTimingsEditorContainer"
local Version = 1
local variables = {
	BackdropBorderColor = { 0.25, 0.25, 0.25, 0.9 },
	BackdropColor = { 0, 0, 0, 0.9 },
	FrameHeight = 600,
	FrameWidth = 800,
	BarHeight = 10,
	Backdrop = {
		bgFile = nil,
		edgeFile = nil,
		tile = true,
		tileSize = 16,
		edgeSize = 1,
	},
	ContentFramePadding = { x = 15, y = 15 },
	Padding = { x = 2, y = 2 },
}

---@param self ATTimingsEditorContainer
local function OnAcquire(self)
	self.frame:Show()
	self.frame:SetPoint("CENTER", UIParent, "CENTER")
end

---@param self ATTimingsEditorContainer
local function OnRelease(self)
	self.frame:Hide()
end


local function SetTitle(self, title)
	self.frame:SetTitle(title)
end

local function Constructor()
	local count = AceGUI:GetNextWidgetNum(Type)

	local frame = CreateFrame("Frame", Type .. count, UIParent, "DefaultPanelTemplate")
	frame:SetSize(variables.FrameWidth, variables.FrameHeight)
	private.Debug(frame, "AT_TIMINGS_EDITOR_FRAME_BASE")
    frame:SetPoint("CENTER", UIParent, "CENTER")
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

	local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
	closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT")
	closeButton:SetScript("OnClick", function()
		private.closeTimingsEditor()
	end)

	local contentFrameName = Type .. "ContentFrame" .. count
	local contentFrame = CreateFrame("Frame", contentFrameName, frame)

	contentFrame:SetPoint(
		"TOPLEFT",
		frame,
		"TOPLEFT",
		variables.Padding.x,
		-variables.ContentFramePadding.y - frame.TitleContainer:GetHeight()
	)
	contentFrame:SetPoint(
		"BOTTOMRIGHT",
		frame,
		"BOTTOMRIGHT"
	)

	---@class ATTimingsEditorContainer : AceGUIWidget
	local widget = {
		OnAcquire = OnAcquire,
		OnRelease = OnRelease,
		SetTitle = SetTitle,
		content = contentFrame,
		frame = frame,
		type = Type,
		count = count,
	}

	return AceGUI:RegisterAsContainer(widget)
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)