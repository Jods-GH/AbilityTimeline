local appName, app = ...
---@class AbilityTimeline
local private = app
local AceGUI = LibStub("AceGUI-3.0")
local ThemeApply = private.ThemeApply

-- a row of the settings window: its label on the left, the control (its only child) on the right, a dot before
-- the label when it differs from the theme and a new badge after it; AtSettingHeading starts a section of rows
local Type = "AtSettingRow"
local HeadingType = "AtSettingHeading"
local Version = 1
local variables = {
    minHeight = 32,
    padding = 4,
    dot = 6,
    headingHeight = 34,
    -- controls of a fixed size are centered with this width: the switch of a check box, the ring of a color picker
    centered = { AtCheckBox = 36, AtColorPicker = 22 },
}

-- AceGUI:Create sets the List layout after OnAcquire, so the row lays itself out instead of registering a layout.
-- The control is anchored to both sides of the content: a pooled row is laid out before it has a width again
---@param self AtSettingRow
local function DoLayout(self)
    local control, content = self.children[1], self.content
    if not control then
        self:LayoutFinished(nil, variables.minHeight)
        return
    end
    control.frame:ClearAllPoints()
    local width = variables.centered[control.type]
    if width then
        control:SetWidth(width)
        control.frame:SetPoint("CENTER", content, "CENTER")
    else
        control.frame:SetPoint("LEFT", content, "LEFT")
        control.frame:SetPoint("RIGHT", content, "RIGHT")
    end
    control.frame:Show()
    self:LayoutFinished(nil, math.max(control.frame:GetHeight(), variables.minHeight) + variables.padding * 2)
end

---@param self AtSettingRow
local function ApplySettings(self)
    local frame = self.frame
    ThemeApply.FontRole(frame.Label, "Control")
    ThemeApply.FontRole(frame.New, "Label")
    frame.New:SetTextColor(ThemeApply.Color("Accent"))
    frame.Dot:SetVertexColor(ThemeApply.Color("Accent"))
    ThemeApply.Solid(frame.Hover, ThemeApply.Color("Highlight"))
    frame.Label:SetAlpha(self.disabled and 0.5 or 1)
end

---@param self AtSettingRow
local function OnAcquire(self)
    self:SetFullWidth(true)
    self:SetLabel("")
    self:SetChanged(false)
    self:SetNew(false)
    self:SetDisabled(false)
    self.frame.Hover:Hide()
    ApplySettings(self)
end

---@param self AtSettingRow
local function OnRelease(self)
    self.frame:ClearAllPoints()
    self.frame:Hide()
end

---@param self AtSettingRow
---@param width number|nil
---@param height number
local function LayoutFinished(self, width, height)
    self:SetHeight(height)
end

---@param self AtSettingRow
---@param text string
local function SetLabel(self, text)
    self.frame.Label:SetText(text)
end

---@param self AtSettingRow
---@param changed boolean
local function SetChanged(self, changed)
    self.frame.Dot:SetShown(changed)
    self.frame.DotHover:SetShown(changed)
end

---@param self AtSettingRow
---@param new boolean
local function SetNew(self, new)
    local frame = self.frame
    frame.New:SetShown(new)
    frame.Label:SetPoint("RIGHT", new and frame.New or self.content, "LEFT", -variables.dot, 0)
end

---@param self AtSettingRow
---@param disabled boolean
local function SetDisabled(self, disabled)
    self.disabled = disabled
    if self.children[1] and self.children[1].SetDisabled then
        self.children[1]:SetDisabled(disabled)
    end
    ApplySettings(self)
end

---@param self AtSettingRow
---@param hovered boolean
local function SetHovered(self, hovered)
    self.frame.Hover:SetShown(hovered)
end

local function Constructor()
    local count = AceGUI:GetNextWidgetNum(Type)
    local frame = CreateFrame("Frame", nil, UIParent)
    frame:Hide()
    frame:EnableMouse(true)

    frame.Hover = frame:CreateTexture(nil, "BACKGROUND")
    frame.Hover:SetAllPoints(frame)
    frame.Label = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.Dot = frame:CreateTexture(nil, "ARTWORK")
    frame.Dot:SetTexture(ThemeApply.File("circle"))
    frame.Dot:SetSize(variables.dot, variables.dot)
    frame.Dot:SetPoint("LEFT", frame, "LEFT", 8, 0)
    frame.Label:SetPoint("LEFT", frame.Dot, "RIGHT", variables.dot, 0)
    frame.Label:SetJustifyH("LEFT")
    -- the dot is small, a larger area around it shows what it means
    frame.DotHover = CreateFrame("Frame", nil, frame)
    frame.DotHover:SetSize(variables.dot * 3, variables.dot * 3)
    frame.DotHover:SetPoint("CENTER", frame.Dot, "CENTER")

    local content = CreateFrame("Frame", nil, frame)
    content:SetPoint("TOPLEFT", frame, "TOP", 0, 0)
    content:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 0)
    frame.New = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.New:SetPoint("RIGHT", content, "LEFT", -variables.dot, 0)
    frame.New:SetText(private.getLocalisation("SettingsNew"))

    ---@class AtSettingRow : AceGUIContainer
    local widget = {
        OnAcquire = OnAcquire,
        OnRelease = OnRelease,
        ApplySettings = ApplySettings,
        LayoutFinished = LayoutFinished,
        DoLayout = DoLayout,
        SetLabel = SetLabel,
        SetChanged = SetChanged,
        SetNew = SetNew,
        SetDisabled = SetDisabled,
        SetHovered = SetHovered,
        type = Type,
        count = count,
        frame = frame,
        content = content,
    }
    frame:SetScript("OnEnter", function()
        widget:Fire("OnEnter")
    end)
    frame.DotHover:SetScript("OnEnter", function()
        widget:Fire("OnEnter")
        GameTooltip:SetOwner(frame.DotHover, "ANCHOR_TOP")
        GameTooltip:AddLine(private.getLocalisation("SettingsChangedTooltip"))
        GameTooltip:Show()
    end)
    frame.DotHover:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    private.RegisterThemed(widget)

    return AceGUI:RegisterAsContainer(widget)
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)

---@param self AtSettingHeading
local function ApplyHeadingSettings(self)
    ThemeApply.FontRole(self.frame.Text, "Heading")
    ThemeApply.Solid(self.frame.Line, ThemeApply.Color("Line"))
end

---@param self AtSettingHeading
local function OnHeadingAcquire(self)
    self:SetFullWidth(true)
    self:SetHeight(variables.headingHeight)
    ApplyHeadingSettings(self)
end

---@param self AtSettingHeading
---@param text string
local function SetText(self, text)
    self.frame.Text:SetText(text)
end

local function HeadingConstructor()
    local frame = CreateFrame("Frame", nil, UIParent)
    frame:Hide()
    frame.Text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.Text:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 8, 6)
    frame.Text:SetJustifyH("LEFT")
    frame.Line = frame:CreateTexture(nil, "ARTWORK")
    frame.Line:SetHeight(1)
    frame.Line:SetPoint("LEFT", frame.Text, "RIGHT", 8, 0)
    frame.Line:SetPoint("RIGHT", frame, "RIGHT", -8, 0)

    ---@class AtSettingHeading : AceGUIWidget
    local widget = {
        OnAcquire = OnHeadingAcquire,
        OnRelease = OnRelease,
        ApplySettings = ApplyHeadingSettings,
        SetText = SetText,
        type = HeadingType,
        frame = frame,
    }
    private.RegisterThemed(widget)

    return AceGUI:RegisterAsWidget(widget)
end

AceGUI:RegisterWidgetType(HeadingType, HeadingConstructor, Version)
