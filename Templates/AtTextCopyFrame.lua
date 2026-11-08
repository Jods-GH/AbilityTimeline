local appName, app = ...
---@class AbilityTimeline
local private = app
local AceGUI = LibStub("AceGUI-3.0")

local Type = "AtTextCopyFrame"
local Version = 2
local variables = {
    width = 440,
    padding = 16,
    headerHeight = 34,
    editBoxHeight = 26,
}

---@param self AtTextCopyFrame
local function OnAcquire(self)
    self.frame:SetWidth(variables.width)
    self:ApplySettings()
    self.EditBox.frame:Show()
    self.Hint:Show()
    self.CloseButton:Show()
end

---@param self AtTextCopyFrame
local function OnRelease(self)
    self.focusRequest = nil
    self.EditBox.editbox:SetScript("OnKeyUp", nil)
    self.EditBox.editbox:SetScript("OnTextChanged", nil)
    self.EditBox:ClearFocus()
    self.EditBox:SetText('')
    self.activeText = nil
    self.EditBox.frame:Hide()
    self.Hint:Hide()
    self.CloseButton:Hide()
end

local function RegisterKeyBinds(widget)
    widget.EditBox.editbox:SetScript("OnKeyUp", function(self, key)
        if IsControlKeyDown() then
            -- handle copy or cut
            if key == "C" or key == "X" then
                if widget and widget.frame then
                    widget.frame.CloseButton:Click()
                    widget.EditBox.editbox:SetScript("OnKeyUp", nil)
                end
            end
        end
    end)
    widget.EditBox.editbox:SetScript("OnTextChanged", function(self)
        if self:GetText() ~= widget.activeText then
            self:SetText(widget.activeText)
        end
        self:SetFocus()
        self:HighlightText()
    end)
end

local function SetValues(self, text)
    self.activeText = text
    self.EditBox:SetText(text)
    self.EditBox.editbox:SetTextInsets(6, 6, 3, 3)
    RegisterKeyBinds(self)
    -- Delay focus and highlight to ensure it works after frame is shown
    local request = {}
    self.focusRequest = request
    C_Timer.After(0.05, function()
        if self.focusRequest == request and self.frame:IsShown() then
            self.EditBox.editbox:SetFocus()
            self.EditBox.editbox:HighlightText()
        end
    end)
end


---@param self AtTextCopyFrame
local function ApplySettings(self)
    private.ThemeApply.Window(self.frame, private.GetWindowStyle("Dialog"), self.frame.CloseButton, self.frame.Title)
    private.ThemeApply.FontRole(self.frame.Hint, "Muted")
    self.frame:SetHeight(variables.headerHeight + variables.editBoxHeight + self.Hint:GetStringHeight() +
        variables.padding * 3)
end

local function Constructor()
    local count = AceGUI:GetNextWidgetNum(Type)

    local frame = CreateFrame("Frame", Type .. count, UIParent)

    frame:SetPoint("TOP", UIParent, "TOP", 0, -50)
    frame:SetWidth(variables.width)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:EnableMouse(true)
    frame.Title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.Title:SetPoint("TOPLEFT", frame, "TOPLEFT", variables.padding, -10)
    frame.Title:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -40, -10)
    frame.Title:SetJustifyH("LEFT")
    frame.Title:SetText(private.getLocalisation("CopyText"))

    frame.EditBox = AceGUI:Create("AtEditBox")
    frame.EditBox.frame:SetParent(frame)
    frame.EditBox:SetPoint("TOPLEFT", frame, "TOPLEFT", variables.padding, -variables.headerHeight - variables.padding)
    frame.EditBox:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -variables.padding, -variables.headerHeight - variables.padding)
    frame.EditBox:SetLabel('')
    frame.EditBox:SetHeight(variables.editBoxHeight)
    frame.EditBox:DisableButton(true)
    frame.EditBox.editbox:SetTextInsets(6, 6, 3, 3)

    frame.Hint = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.Hint:SetPoint("TOPLEFT", frame.EditBox.frame, "BOTTOMLEFT", 0, -variables.padding)
    frame.Hint:SetPoint("TOPRIGHT", frame.EditBox.frame, "BOTTOMRIGHT", 0, -variables.padding)
    frame.Hint:SetWordWrap(true)
    frame.Hint:SetJustifyH("LEFT")
    frame.Hint:SetText(private.getLocalisation("TextCopyHint"))

    frame.CloseButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    frame.CloseButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)
    frame:Show()

    ---@class AtTextCopyFrame : AceGUIWidget
    local widget = {
        OnAcquire = OnAcquire,
        OnRelease = OnRelease,
        frame = frame,
        type = Type,
        count = count,
        SetValues = SetValues,
        EditBox = frame.EditBox,
        Hint = frame.Hint,
        CloseButton = frame.CloseButton,
        RegisterKeyBinds = RegisterKeyBinds,
        ApplySettings = ApplySettings,
    }
    ApplySettings(widget)
    private.RegisterThemed(widget)

    return AceGUI:RegisterAsWidget(widget)
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)
