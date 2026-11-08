local appName, app = ...
---@class AbilityTimeline
local private = app
local AceGUI = LibStub("AceGUI-3.0")
local Type = "AtDialogFrame"
local Version = 1
local variables = { width = 380, offsetY = 120, padding = 16, headerHeight = 34, buttonHeight = 24 }

local function ApplySettings(self)
    if not self.active then return end
    private.ThemeApply.Window(self.frame, private.GetWindowStyle("Dialog"), nil, self.frame.Title)
    private.ThemeApply.FontRole(self.frame.Text, "Control")
end

local function Answer(self, accepted)
    local question = self.question
    if not question then return end
    local checked = self.check.frame:IsShown() and self.check:GetValue()
    self.question = nil
    self.frame:Hide()
    self:Fire("OnClose")
    if accepted then
        question.onAccept(checked)
    elseif question.onBack then
        question.onBack()
    end
end

local function OnAcquire(self)
    local frame = self.frame
    self.active = true
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, variables.offsetY)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetWidth(variables.width)
    local padding = variables.padding
    local check = AceGUI:Create("AtCheckBox")
    check.frame:SetParent(frame)
    check:SetWidth(variables.width - padding * 2)
    check.frame:SetPoint("TOPLEFT", frame.Text, "BOTTOMLEFT", 0, -padding)

    local createButton = function(anchor)
        local button = AceGUI:Create("AtButton")
        button:SetWidth((variables.width - padding * 3) / 2)
        button.frame:SetParent(frame)
        button.frame:SetPoint(anchor, frame, anchor, anchor == "BOTTOMLEFT" and padding or -padding, padding)
        button.frame:Show()
        return button
    end
    local back = createButton("BOTTOMLEFT")
    local accept = createButton("BOTTOMRIGHT")
    self.check, self.back, self.accept = check, back, accept
    back:SetCallback("OnClick", function() Answer(self, false) end)
    accept:SetCallback("OnClick", function() Answer(self, true) end)
    ApplySettings(self)
    if not self.closeHooked then
        frame:HookScript("OnHide", function()
            if not frame:IsShown() and not self:IsReleasing() then Answer(self, false) end
        end)
        self.closeHooked = true
    end
end

local function OnRelease(self)
    self.active = false
    self.question = nil
    private.ThemeApply.StopEnterEffects(self.frame)
    self.check:Release()
    self.back:Release()
    self.accept:Release()
    self.check, self.back, self.accept = nil, nil, nil
    self.frame.Title:SetText("")
    self.frame.Text:SetText("")
end

---asks { title, text, accept, acceptStyle, back, check, onAccept(checked), onBack }
local function SetQuestion(self, question)
    local frame = self.frame
    self.question = question
    frame.Title:SetText(question.title)
    frame.Text:SetText(question.text)
    self.check:SetLabel(question.check or "")
    self.check:SetValue(false)
    self.check.frame:SetShown(question.check ~= nil)
    self.accept:SetText(question.accept)
    self.accept:SetStyle(question.acceptStyle or "Primary")
    self.back:SetText(question.back)
    local padding = variables.padding
    frame:SetHeight(variables.headerHeight + padding * 3 + frame.Text:GetStringHeight() +
        (question.check and self.check.frame:GetHeight() + padding or 0) + variables.buttonHeight + padding)
    frame:Show()
end

local function Constructor()
    local frame = CreateFrame("Frame", Type .. AceGUI:GetNextWidgetNum(Type), UIParent)
    frame:Hide()
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetWidth(variables.width)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, variables.offsetY)
    frame:EnableMouse(true)
    -- closes with escape
    table.insert(UISpecialFrames, frame:GetName())
    local padding = variables.padding

    frame.Title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.Title:SetPoint("TOPLEFT", frame, "TOPLEFT", padding, -10)
    frame.Text = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.Text:SetPoint("TOPLEFT", frame, "TOPLEFT", padding, -variables.headerHeight - padding)
    frame.Text:SetWidth(variables.width - padding * 2)
    frame.Text:SetJustifyH("LEFT")
    frame.Text:SetWordWrap(true)
    frame.Text:SetSpacing(3)

    local widget = {
        type = Type,
        frame = frame,
        OnAcquire = OnAcquire,
        OnRelease = OnRelease,
        ApplySettings = ApplySettings,
        SetQuestion = SetQuestion,
    }
    private.RegisterThemed(widget)
    return AceGUI:RegisterAsWidget(widget)
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)
