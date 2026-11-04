local appName, app = ...
---@class AbilityTimeline
local private = app
local AceGUI = LibStub("AceGUI-3.0")

-- the window of the timings editor, a plain frame drawn in the theme like the settings window: Blizzard's window
-- templates bring art of their own that differs between the game versions
local Type = "ATTimingsEditorContainer"
local Version = 2
local variables = {
    width = 800,
    height = 600,
    padding = 12,
    headerHeight = 34,
    footerHeight = 30,
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

---@param self ATTimingsEditorContainer
---@param title string
local function SetTitle(self, title)
    self.frame.Title:SetText(title)
end

---@param self ATTimingsEditorContainer
local function ApplySettings(self)
    local style = private.GetWindowStyle("Window")
    private.ThemeApply.Window(self.frame, style, self.closeButton, self.frame.Title)
    private.DrawFooterLinks(self.frame.Footer, style)
end

local function Constructor()
    local count = AceGUI:GetNextWidgetNum(Type)

    local frame = CreateFrame("Frame", Type .. count, UIParent)
    frame:SetSize(variables.width, variables.height)
    frame:SetPoint("CENTER", UIParent, "CENTER")
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

    frame.Title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.Title:SetPoint("TOPLEFT", frame, "TOPLEFT", variables.padding + 4, -10)
    frame.Title:SetPoint("RIGHT", frame, "RIGHT", -40, 0)
    frame.Title:SetJustifyH("LEFT")
    frame.Title:SetWordWrap(false)

    local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeButton:SetScript("OnClick", function()
        private.closeTimingsEditor()
    end)

    local contentFrame = CreateFrame("Frame", Type .. "ContentFrame" .. count, frame)
    contentFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -variables.headerHeight)
    contentFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, variables.footerHeight)

    frame.Footer = CreateFrame("Frame", nil, frame)
    frame.Footer:SetHeight(variables.footerHeight)
    frame.Footer:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 1, 1)
    frame.Footer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
    frame.Footer.Background = frame.Footer:CreateTexture(nil, "BACKGROUND")
    frame.Footer.Background:SetAllPoints(frame.Footer)
    frame.Footer.AddonName = frame.Footer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.Footer.AddonName:SetPoint("LEFT", frame.Footer, "LEFT", variables.padding + 4, 0)
    frame.Footer.AddonName:SetFormattedText("%s %s", private.getLocalisation("SettingsTitle"),
        C_AddOns.GetAddOnMetadata(appName, "Version"))
    private.CreateFooterLinks(frame.Footer)

    ---@class ATTimingsEditorContainer : AceGUIWidget
    local widget = {
        OnAcquire = OnAcquire,
        OnRelease = OnRelease,
        SetTitle = SetTitle,
        ApplySettings = ApplySettings,
        closeButton = closeButton,
        content = contentFrame,
        frame = frame,
        type = Type,
        count = count,
    }
    ApplySettings(widget)
    private.RegisterThemed(widget)

    return AceGUI:RegisterAsContainer(widget)
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)
