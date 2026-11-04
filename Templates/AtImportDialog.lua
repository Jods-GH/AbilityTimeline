local appName, app = ...
---@class AbilityTimeline
local private = app
local AceGUI = LibStub("AceGUI-3.0")
local ThemeApply = private.ThemeApply

-- the window of the import and export dialogs: a plain frame in the theme's dialog style like the timings editor, a
-- note below its header and its rows (List layout) below that, as high as they need
local Type = "AtImportDialog"
local Version = 2
local variables = {
    width = 620,
    padding = 16,
    headerHeight = 34,
}

---@param self AtImportDialog
local function OnAcquire(self)
    self.frame:ClearAllPoints()
    self.frame:SetPoint("CENTER", UIParent, "CENTER")
    -- above the timings editor (HIGH)
    self.frame:SetFrameStrata("DIALOG")
    self:SetLayout("List")
    self:SetNote(nil)
    self.frame:Show()
end

---@param self AtImportDialog
local function OnRelease(self)
    self.frame:Hide()
end

---@param self AtImportDialog
---@param title string
local function SetTitle(self, title)
    self.frame.Title:SetText(title)
end

---a line below the header, nil leaves it out
---@param self AtImportDialog
---@param note string|nil
local function SetNote(self, note)
    local frame = self.frame
    frame.Note:SetText(note or "")
    frame.Note:SetShown(note ~= nil)
    self.content:ClearAllPoints()
    self.content:SetPoint("TOPLEFT", note and frame.Note or frame, note and "BOTTOMLEFT" or "TOPLEFT", note and 0 or
        variables.padding, note and -variables.padding / 2 or -variables.headerHeight - variables.padding / 2)
    self.content:SetPoint("RIGHT", frame, "RIGHT", -variables.padding, 0)
end

---@param self AtImportDialog
---@param width number|nil
---@param height number
local function LayoutFinished(self, width, height)
    local note = self.frame.Note
    local top = variables.headerHeight + variables.padding / 2 +
        (note:IsShown() and note:GetStringHeight() + variables.padding / 2 or 0)
    self.content:SetHeight(height)
    self.frame:SetHeight(top + height + variables.padding)
end

---@param self AtImportDialog
local function ApplySettings(self)
    ThemeApply.Window(self.frame, private.GetWindowStyle("Dialog"), self.closeButton, self.frame.Title)
    ThemeApply.FontRole(self.frame.Note, "Muted")
end

local function Constructor()
    local count = AceGUI:GetNextWidgetNum(Type)
    local frame = CreateFrame("Frame", Type .. count, UIParent)
    frame:SetFrameStrata("DIALOG")
    frame:SetSize(variables.width, 400)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

    frame.Title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.Title:SetPoint("TOPLEFT", frame, "TOPLEFT", variables.padding, -10)
    frame.Title:SetPoint("RIGHT", frame, "RIGHT", -40, 0)
    frame.Title:SetJustifyH("LEFT")

    frame.Note = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.Note:SetPoint("TOPLEFT", frame, "TOPLEFT", variables.padding, -variables.headerHeight - variables.padding / 2)
    frame.Note:SetPoint("RIGHT", frame, "RIGHT", -variables.padding, 0)
    frame.Note:SetJustifyH("LEFT")
    frame.Note:SetSpacing(3)

    local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeButton:SetScript("OnClick", function()
        frame:Hide()
    end)

    local contentFrame = CreateFrame("Frame", Type .. "ContentFrame" .. count, frame)

    ---@class AtImportDialog : AceGUIContainer
    local widget = {
        OnAcquire = OnAcquire,
        OnRelease = OnRelease,
        LayoutFinished = LayoutFinished,
        type = Type,
        count = count,
        frame = frame,
        closeButton = closeButton,
        content = contentFrame,
        SetTitle = SetTitle,
        SetNote = SetNote,
        ApplySettings = ApplySettings,
    }
    SetNote(widget, nil)
    ApplySettings(widget)
    private.RegisterThemed(widget)

    return AceGUI:RegisterAsContainer(widget)
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)
