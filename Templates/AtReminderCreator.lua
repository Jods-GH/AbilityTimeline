local addonName, private = ...
local AceGUI = LibStub("AceGUI-3.0")
local Type = "AtReminderCreator"
local Version = 1
local variables = {
   x = 400,
   y = 200,
}


---@param self AtReminderCreator
local function OnAcquire(self)
end

---@param self AtReminderCreator
local function OnRelease(self)
end

local function Constructor()
    local count = AceGUI:GetNextWidgetNum(Type)
    local frame = CreateFrame("Frame", Type .. count, private.TIMINGS_EDITOR_WINDOW.frame , "BackdropTemplate")
    frame:SetFrameStrata("DIALOG")
    frame:SetSize(variables.x, variables.y)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    frame:SetPoint("CENTER", private.TIMINGS_EDITOR_WINDOW.frame, "CENTER")
    local titleBar = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleBar:SetPoint("TOP", frame, "TOP", 0, -10)
    titleBar:SetText(private.getLocalisation("ReminderCreatorTitle"))

    local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
	closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT")

    local group = AceGUI:Create("SimpleGroup")
    group:SetLayout("Fill")
    group:SetParent(frame)
    group:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -40)
    group:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 10)
    frame:Show()
    group.frame:SetFrameStrata('FULLSCREEN')
    group.frame:SetFrameLevel(frame:GetFrameLevel() + 10)
    private.Debug(frame, "AT_REMINDER_CREATOR_FRAME")

    local sizeSetting = AceGUI:Create("Slider")
    sizeSetting:SetLabel(private.getLocalisation("IconSize"))
    private.AddFrameTooltip(sizeSetting.frame, "IconSizeDescription")
    sizeSetting:SetSliderValues(1, 100, 1)

    group:AddChild(sizeSetting)


    ---@class AtReminderCreator : AceGUIWidget
    local widget = {
        OnAcquire = OnAcquire,
        OnRelease = OnRelease,
        type = Type,
        count = count,
        frame = frame,
        closeButton = closeButton,
    }

    return AceGUI:RegisterAsWidget(widget)
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)
