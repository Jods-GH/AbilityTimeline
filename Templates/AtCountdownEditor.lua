local appName, app = ...
---@class AbilityTimeline
local private = app
local AceGUI = LibStub("AceGUI-3.0")
local ThemeApply = private.ThemeApply
local Type, Version = "AtCountdownEditor", 4
local variables = { width = 440, minHeight = 230, maxHeight = 500, padding = 12, headerHeight = 34, footerHeight = 48, contentBottom = 56 }

local function LayoutHeader(self)
    local frame = self.frame
    local available = frame:GetWidth() - variables.padding * 2 - 32 - (self.toggle and frame.Enabled:GetStringWidth() + 56 or 0)
    local width = math.min(frame.Title:GetStringWidth(), available * 0.65)
    frame.Title:ClearAllPoints()
    frame.Title:SetPoint("LEFT", frame, "TOPLEFT", variables.padding, -self.headerHeight / 2)
    frame.Title:SetWidth(width)
    frame.Scope:ClearAllPoints()
    frame.Scope:SetPoint("LEFT", frame.Title, "RIGHT", 10, 0)
    frame.Scope:SetWidth(math.max(1, available - width - 10))
    self.content:SetPoint("TOPLEFT", frame, "TOPLEFT", variables.padding, -self.headerHeight - variables.padding)
end

local function FitContent(self)
    if not self.scroll then return end
    local limit = math.min(variables.maxHeight, UIParent:GetHeight() - 48)
    for _ = 1, 2 do
        local height = self.headerHeight + variables.padding + self.scroll.content:GetHeight() + variables.contentBottom
        self.frame:SetHeight(math.min(limit, math.max(variables.minHeight, height)))
        self:DoLayout()
        self.scroll:DoLayout()
    end
end

local function ApplySettings(self)
    local frame = self.frame
    local style = private.GetWindowStyle("Dialog")
    ThemeApply.Window(frame, style, frame.CloseButton, frame.Title)
    ThemeApply.FontRole(frame.Scope, "Muted")
    ThemeApply.FontRole(frame.Enabled, "Muted")
    ThemeApply.Solid(frame.FooterLine, ThemeApply.Color("Edge"))
    local anchor
    for _, button in ipairs({ frame.Done, frame.Copy, frame.Remove }) do
        private.ThemedWidgets.DrawButton(button)
        button:SetWidth(math.max(64, button:GetFontString():GetStringWidth() + 20))
        button:ClearAllPoints()
        if button:IsShown() then
            if anchor then button:SetPoint("RIGHT", anchor, "LEFT", -6, 0)
            else button:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -variables.padding, variables.padding) end
            anchor = button
        end
    end
    self.headerHeight = style.HeaderHeight or variables.headerHeight
    LayoutHeader(self)
end

local function OnAcquire(self)
    self.frame:SetSize(math.min(variables.width, UIParent:GetWidth() - 24), math.min(variables.minHeight, UIParent:GetHeight() - 48))
    self:SetActions(nil)
end

local function OnRelease(self)
    self.frame:StopMovingOrSizing()
    ThemeApply.StopEnterEffects(self.frame)
    self.frame:Hide()
    self:SetEnabledToggle(nil)
    self.scroll = nil
    self.actions = nil
end

local function ShowBeside(self, owner)
    local frame = self.frame
    frame:ClearAllPoints()
    if owner then
        frame:SetFrameLevel(owner:GetFrameLevel() + 20)
        -- at the bottom of the window, the lanes above stay visible
        if owner.Nav then frame:SetPoint("BOTTOMLEFT", owner.Nav, "BOTTOMRIGHT", 12, -6)
        else frame:SetPoint("BOTTOMLEFT", owner, "BOTTOMLEFT", 16, 16) end
    else frame:SetPoint("CENTER", UIParent, "CENTER") end
    frame:Show()
end

local function Constructor()
    local frame = CreateFrame("Frame", Type .. AceGUI:GetNextWidgetNum(Type), UIParent)
    frame:Hide()
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    table.insert(UISpecialFrames, frame:GetName())

    frame.Title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.Title:SetJustifyH("LEFT")
    frame.Title:SetWordWrap(false)
    frame.Scope = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.Scope:SetJustifyH("LEFT")
    frame.Scope:SetWordWrap(false)
    frame.Enabled = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.Enabled:SetText(private.getLocalisation("CountdownEnabled"))
    frame.Enabled:Hide()

    frame.CloseButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    frame.CloseButton:SetScript("OnClick", function() frame:Hide() end)
    for name, key in pairs({ Done = "CountdownDone", Copy = "CountdownCopy", Remove = "CountdownRemove" }) do
        local button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        private.ThemedWidgets.SkinButton(button)
        button:SetHeight(24)
        button:SetText(private.getLocalisation(key))
        frame[name] = button
    end

    frame.FooterLine = frame:CreateTexture(nil, "BORDER")
    frame.FooterLine:SetPoint("LEFT", frame, "BOTTOMLEFT", variables.padding, variables.footerHeight)
    frame.FooterLine:SetPoint("RIGHT", frame, "BOTTOMRIGHT", -variables.padding, variables.footerHeight)
    frame.FooterLine:SetHeight(1)

    local content = CreateFrame("Frame", nil, frame)
    content:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -variables.padding, variables.contentBottom)
    local widget = {
        type = Type, frame = frame, content = content, OnAcquire = OnAcquire, OnRelease = OnRelease,
        ApplySettings = ApplySettings, ShowBeside = ShowBeside, FitContent = FitContent, LayoutFinished = function() end,
        SetTitle = function(self, title, scope)
            self.frame.Title:SetText(title)
            self.frame.Scope:SetText(scope)
            LayoutHeader(self)
        end,
        SetEnabledToggle = function(self, value, callback)
            if value == nil then
                if self.toggle then self.toggle:Release() end
                self.toggle = nil
                self.frame.Enabled:Hide()
            else
                if not self.toggle then
                    self.toggle = AceGUI:Create("AtCheckBox")
                    self.toggle:SetLabel("")
                    self.toggle:SetWidth(36)
                    self.toggle.frame:SetParent(self.frame)
                    self.toggle.frame:ClearAllPoints()
                    self.toggle.frame:SetPoint("RIGHT", self.frame.CloseButton, "LEFT", -6, 0)
                    self.toggle.frame:Show()
                    self.frame.Enabled:ClearAllPoints()
                    self.frame.Enabled:SetPoint("RIGHT", self.toggle.frame, "LEFT", -6, 0)
                    self.frame.Enabled:Show()
                end
                self.toggle:SetValue(value)
                self.toggle:SetCallback("OnValueChanged", function(_, _, checked) callback(checked) end)
            end
            LayoutHeader(self)
        end,
        SetActions = function(self, actions)
            self.actions = actions
            for _, name in ipairs({ "Done", "Copy", "Remove" }) do
                local action = actions and actions[name]
                local button = self.frame[name]
                button:SetShown(action ~= nil or not actions)
                button:SetText(action and action.text or private.getLocalisation("Countdown" .. name))
                button:SetEnabled(not action or not action.disabled)
                button:SetAlpha(button:IsEnabled() and 1 or 0.45)
            end
            ApplySettings(self)
        end,
    }
    for _, name in ipairs({ "Done", "Copy", "Remove" }) do
        frame[name]:SetScript("OnClick", function()
            local action = widget.actions and widget.actions[name]
            if action then action.callback()
            elseif name == "Done" then frame:Hide()
            else widget:Fire("On" .. name) end
        end)
    end
    -- a disabled action tells why it is
    local tooltips = { Copy = "CountdownDuplicate", Remove = "CountdownRemoveChange" }
    for _, name in ipairs({ "Done", "Copy", "Remove" }) do
        local button = frame[name]
        button:SetMotionScriptsWhileDisabled(true)
        button:HookScript("OnEnter", function()
            local action = widget.actions and widget.actions[name]
            local text
            if action then text = not button:IsEnabled() and action.tooltip
            else text = tooltips[name] and private.getLocalisation(tooltips[name]) end
            if not text then return end
            GameTooltip:SetOwner(button, "ANCHOR_TOPRIGHT")
            GameTooltip:AddLine(text, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        button:HookScript("OnLeave", function() GameTooltip:Hide() end)
    end
    frame:SetScript("OnHide", function()
        if not frame:IsShown() and not widget:IsReleasing() then widget:Fire("OnClose") end
    end)
    private.RegisterThemed(widget)
    return AceGUI:RegisterAsContainer(widget)
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)

local FieldType = "AtCountdownField"

local function LayoutField(self)
    if self.layingOut then return end
    self.layingOut = true
    local control = self.children[1]
    local hasLabel = self.labelText ~= ""
    -- narrow controls sit at the right edge and leave the rest of the row to the label
    local narrow = control and (control.type == "AtColorPicker" and 22 or control.type == "AtCheckBox" and 36 or control:GetUserData("preferredWidth"))
    local width = self.frame:GetWidth()
    local labelWidth = not hasLabel and 0 or narrow and math.max(1, width - narrow - 10) or math.min(158, width * 0.4)
    self.frame.Label:SetShown(hasLabel)
    self.frame.Label:SetWidth(labelWidth)
    self.content:SetPoint("TOPLEFT", self.frame, "TOPLEFT", hasLabel and labelWidth + 10 or 0, 0)
    self.content:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT")
    local height = 28
    if control then
        local available = math.max(1, width - (hasLabel and labelWidth + 10 or 0))
        control:SetWidth(narrow and math.min(narrow, available) or available)
        -- centered edit box text keeps the position it had at the old width until it is set again
        if control.editbox then
            control.editbox:SetText(control.editbox:GetText())
            control.editbox:SetCursorPosition(0)
        end
        control.frame:ClearAllPoints()
        control.frame:SetPoint("RIGHT", self.content, "RIGHT")
        if not narrow then control.frame:SetPoint("LEFT", self.content, "LEFT") end
        control.frame:Show()
        height = math.max(height, control.frame:GetHeight() + 4)
    end
    if hasLabel then height = math.max(height, self.frame.Label:GetStringHeight() + 4) end
    self:SetHeight(height)
    self.layingOut = nil
end

local function FieldConstructor()
    local frame = CreateFrame("Frame", nil, UIParent)
    frame:Hide()
    frame.Label = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.Label:SetPoint("LEFT", frame, "LEFT")
    frame.Label:SetJustifyH("LEFT")
    frame.Label:SetWordWrap(true)
    local content = CreateFrame("Frame", nil, frame)
    local widget = {
        type = FieldType, frame = frame, content = content, DoLayout = LayoutField, OnWidthSet = LayoutField,
        OnAcquire = function(self)
            self:SetFullWidth(true)
            self:SetLabel("")
            self:ApplySettings()
        end,
        OnRelease = function(self) self.labelText, self.layingOut = "", nil end,
        SetLabel = function(self, text) self.labelText = text; self.frame.Label:SetText(text); self:DoLayout() end,
        ApplySettings = function(self) ThemeApply.FontRole(self.frame.Label, "Control"); self:DoLayout() end,
        LayoutFinished = function() end,
    }
    private.RegisterThemed(widget)
    return AceGUI:RegisterAsContainer(widget)
end

AceGUI:RegisterWidgetType(FieldType, FieldConstructor, 1)

local CardType = "AtCountdownSituation"

local function LayoutCard(self)
    local frame = self.frame
    frame.Summary:SetWidth(math.max(1, frame:GetWidth() - 172))
    self:SetHeight(math.max(44, frame.Summary:GetStringHeight() + 24))
end

local function ApplyCard(self)
    local frame = self.frame
    ThemeApply.PanelStyle(frame.AtFill, frame.AtEdge)
    frame.AtFill:SetVertexColor(ThemeApply.Color("Field"))
    frame.AtEdge:SetVertexColor(ThemeApply.Color("Edge"))
    ThemeApply.FontRole(frame.Summary, "Control")
    private.ThemedWidgets.DrawButton(frame.Edit)
    private.ThemedWidgets.DrawButton(frame.Remove)
    LayoutCard(self)
end

local function CardConstructor()
    local frame = CreateFrame("Button", nil, UIParent)
    frame:Hide()
    ThemeApply.CreatePanel(frame)
    frame.Summary = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.Summary:SetPoint("TOPLEFT", 12, -12)
    frame.Summary:SetJustifyH("LEFT")
    frame.Summary:SetWordWrap(true)
    for name, key in pairs({ Edit = "CountdownEditSituation", Remove = "CountdownRemove" }) do
        local button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        private.ThemedWidgets.SkinButton(button)
        button:SetSize(68, 24)
        button:SetText(private.getLocalisation(key))
        frame[name] = button
    end
    frame.Remove:SetPoint("RIGHT", -10, 0)
    frame.Edit:SetPoint("RIGHT", frame.Remove, "LEFT", -6, 0)
    local widget = {
        type = CardType, frame = frame, OnWidthSet = LayoutCard, ApplySettings = ApplyCard,
        OnAcquire = function(self)
            self:SetFullWidth(true)
            self:SetRemoveText(private.getLocalisation("CountdownRemove"))
            self:ApplySettings()
        end,
        OnRelease = function(self) self.frame:Hide() end,
        SetRemoveText = function(self, text) self.frame.Remove:SetText(text) end,
        SetSummary = function(self, summary)
            self.frame.Summary:SetText(summary)
            ApplyCard(self)
        end,
    }
    frame:SetScript("OnClick", function() widget:Fire("OnEdit") end)
    frame.Edit:SetScript("OnClick", function() widget:Fire("OnEdit") end)
    frame.Remove:SetScript("OnClick", function() widget:Fire("OnRemove") end)
    private.RegisterThemed(widget)
    return AceGUI:RegisterAsWidget(widget)
end

AceGUI:RegisterWidgetType(CardType, CardConstructor, 3)

local SummaryType = "AtCountdownSummary"

local function LayoutSummary(self)
    if self.layingOut then return end
    self.layingOut = true
    local frame = self.frame
    local labelWidth = math.min(148, frame:GetWidth() * 0.42)
    frame.Title:ClearAllPoints()
    frame.Title:SetPoint("LEFT", self.step and 28 or 10, 0)
    frame.Title:SetWidth(labelWidth - (self.step and 18 or 0))
    frame.Value:SetWidth(math.max(1, frame:GetWidth() - labelWidth - 36))
    self:SetHeight(math.max(32, frame.Title:GetStringHeight() + 14, frame.Value:GetStringHeight() + 14))
    self.layingOut = nil
end

local function ApplySummary(self)
    local frame = self.frame
    ThemeApply.PanelStyle(frame.AtFill, frame.AtEdge)
    frame.AtFill:SetVertexColor(ThemeApply.Color("Field"))
    frame.AtEdge:SetVertexColor(ThemeApply.Color(self.expanded and "Accent" or "Edge"))
    ThemeApply.FontRole(frame.Title, "Control")
    ThemeApply.FontRole(frame.Value, "Muted")
    ThemeApply.FontRole(frame.Step, "Muted")
    LayoutSummary(self)
end

local function SummaryConstructor()
    local frame = CreateFrame("Button", nil, UIParent)
    frame:Hide()
    ThemeApply.CreatePanel(frame)
    frame.Title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.Title:SetPoint("LEFT", 10, 0)
    frame.Title:SetJustifyH("LEFT")
    frame.Title:SetWordWrap(true)
    frame.Value = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.Value:SetPoint("RIGHT", -10, 0)
    frame.Value:SetJustifyH("RIGHT")
    frame.Value:SetWordWrap(true)
    frame.Step = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.Step:SetPoint("LEFT", 10, 0)
    frame.Step:SetWidth(14)
    frame.Step:SetJustifyH("LEFT")
    local widget = {
        type = SummaryType, frame = frame, ApplySettings = ApplySummary, OnWidthSet = LayoutSummary,
        OnAcquire = function(self) self:SetFullWidth(true); self.expanded, self.step = false, nil; self.frame.Step:Hide(); self:ApplySettings() end,
        OnRelease = function(self) self.expanded, self.layingOut = nil, nil; self.frame:Hide() end,
        SetSummary = function(self, title, value, expanded)
            self.expanded = expanded
            self.frame.Title:SetText(title)
            self.frame.Value:SetText(value)
            self:ApplySettings()
        end,
        SetStep = function(self, step)
            self.step = step
            self.frame.Step:SetShown(step ~= nil)
            self.frame.Step:SetText(step and tostring(step) or "")
            LayoutSummary(self)
        end,
    }
    frame:SetScript("OnClick", function() widget:Fire("OnEdit") end)
    frame:SetScript("OnEnter", function() frame.AtEdge:SetVertexColor(ThemeApply.Color("Accent")) end)
    frame:SetScript("OnLeave", function() ApplySummary(widget) end)
    private.RegisterThemed(widget)
    return AceGUI:RegisterAsWidget(widget)
end

AceGUI:RegisterWidgetType(SummaryType, SummaryConstructor, 2)
