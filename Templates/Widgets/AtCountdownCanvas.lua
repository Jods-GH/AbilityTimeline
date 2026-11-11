local appName, app = ...
---@class AbilityTimeline
local private = app
local AceGUI = LibStub("AceGUI-3.0")
local ThemeApply = private.ThemeApply

local LayoutType = "AtCountdownLayout"

local function Layout(self)
    if self.layingOut or self.LayoutPaused then return end
    self.layingOut = true
    local header = 0
    if self.sectionTitle then
        local frame, width = self.frame, math.max(1, self.frame:GetWidth() - self.insetLeft)
        local top = self.sectionStyle == "section" and 12 or 0
        local controls, controlHeight = 0, 0
        for _, child in ipairs(self.headerWidgets or {}) do
            child:SetWidth(child.GetPreferredWidth and child:GetPreferredWidth() or child:GetUserData("preferredWidth"))
            controlHeight = math.max(controlHeight, child.frame:GetHeight())
        end
        for i = #(self.headerWidgets or {}), 1, -1 do
            local child = self.headerWidgets[i]
            child.frame:ClearAllPoints()
            child.frame:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -controls, -top - (controlHeight - child.frame:GetHeight()) / 2)
            child.frame:Show()
            controls = controls + child.frame:GetWidth() + 6
        end
        frame.Title:SetWidth(math.max(1, width - controls))
        local titleHeight = frame.Title:GetStringHeight()
        frame.Title:SetPoint("TOPLEFT", self.insetLeft, -top - math.max(0, controlHeight - titleHeight) / 2)
        header = top + math.max(titleHeight, controlHeight) + 10
    end
    local width = math.max(1, self.frame:GetWidth() - self.insetLeft - self.insetRight)
    local y, row, used, rowHeight = self.paddingTop + header, {}, 0, 0
    local function finishRow()
        if #row == 0 then return end
        local growers = 0
        for _, item in ipairs(row) do if item.widget:GetUserData("grow") then growers = growers + 1 end end
        local extra = growers > 0 and math.max(0, width - used) / growers or 0
        local x = self.insetLeft
        for _, item in ipairs(row) do
            local child = item.widget
            local childWidth = item.width + (child:GetUserData("grow") and extra or 0)
            child:SetWidth(childWidth)
            if child.DoLayout then child:DoLayout() end
            item.x = x
            rowHeight = math.max(rowHeight, child.frame:GetHeight())
            x = x + childWidth + self.gap
        end
        for _, item in ipairs(row) do
            local frame = item.widget.frame
            frame:ClearAllPoints()
            frame:SetPoint("TOPLEFT", self.content, "TOPLEFT", item.x, -y - (rowHeight - frame:GetHeight()) / 2)
            frame:Show()
        end
        y = y + rowHeight + self.gap
        row, used, rowHeight = {}, 0, 0
    end
    for _, child in ipairs(self.children) do
        local childWidth
        if self.mode == "wrap" then childWidth = math.min(width, child.GetPreferredWidth and child:GetPreferredWidth() or child:GetUserData("preferredWidth") or child.frame:GetWidth())
        elseif self.mode == "grid" and child.width ~= "fill" then childWidth = math.max(1, (width - self.gap) / 2)
        else childWidth = width end
        local gap = #row > 0 and self.gap or 0
        if #row > 0 and used + gap + childWidth > width + 0.1 then finishRow(); gap = 0 end
        row[#row + 1] = { widget = child, width = childWidth }
        used = used + gap + childWidth
        if self.mode == "stack" or childWidth >= width then finishRow() end
    end
    finishRow()
    self:SetHeight(math.max(0, y - (#self.children > 0 and self.gap or 0) + self.paddingBottom))
    self.layingOut = nil
end

local function LayoutConstructor()
    local frame = CreateFrame("Frame", nil, UIParent)
    frame:Hide()
    local content = CreateFrame("Frame", nil, frame)
    content:SetAllPoints(frame)
    frame.Title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.Title:SetJustifyH("LEFT")
    frame.Title:SetWordWrap(true)
    frame.Divider = frame:CreateTexture(nil, "BORDER")
    frame.Divider:SetPoint("TOPLEFT", 0, 0)
    frame.Divider:SetPoint("TOPRIGHT", 0, 0)
    frame.Divider:SetHeight(1)
    local widget = {
        type = LayoutType, frame = frame, content = content, DoLayout = Layout, OnWidthSet = Layout,
        OnAcquire = function(self)
            self.mode, self.gap = "stack", 10
            self.insetLeft, self.insetRight, self.paddingTop, self.paddingBottom = 0, 0, 0, 0
            self.sectionTitle, self.sectionStyle = nil, nil
            self.frame.Title:Hide(); self.frame.Divider:Hide()
            self:SetFullWidth(true)
            self:SetHeight(0)
        end,
        OnRelease = function(self)
            for _, child in ipairs(self.headerWidgets or {}) do child:Release() end
            self.headerWidgets, self.layingOut = nil, nil
            self.frame:Hide()
        end,
        AddHeaderWidget = function(self, child)
            self.headerWidgets = self.headerWidgets or {}
            table.insert(self.headerWidgets, child)
            child.frame:SetParent(self.frame)
            self:DoLayout()
        end,
        Configure = function(self, mode, gap, left, right, top, bottom)
            self.mode, self.gap = mode or "stack", gap or 10
            self.insetLeft, self.insetRight, self.paddingTop, self.paddingBottom = left or 0, right or 0, top or 0, bottom or 0
            self:DoLayout()
        end,
        ApplySettings = function(self)
            ThemeApply.FontRole(self.frame.Title, "Heading")
            ThemeApply.Solid(self.frame.Divider, ThemeApply.Color("Edge"))
            self:DoLayout()
        end,
        SetSection = function(self, title, style)
            self.sectionTitle, self.sectionStyle = title, style
            self.frame.Title:SetText(title)
            self.frame.Title:SetShown(title ~= nil)
            self.frame.Divider:SetShown(style == "section")
            self:ApplySettings()
        end,
        LayoutFinished = function() end,
    }
    private.RegisterThemed(widget)
    return AceGUI:RegisterAsContainer(widget)
end

AceGUI:RegisterWidgetType(LayoutType, LayoutConstructor, 2)

local ChoiceType = "AtCountdownChoice"

local function LayoutChoice(self)
    if self.layingOut then return end
    self.layingOut = true
    local frame = self.frame
    frame.Text:SetWidth(math.max(1, frame:GetWidth() - 16))
    frame.Text:ClearAllPoints()
    frame.Text:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -6)
    frame.Text:SetJustifyH(self.diagram and "LEFT" or "CENTER")
    frame.Track:SetShown(self.diagram ~= nil)
    frame.Mark:SetShown(self.diagram ~= nil and self.diagram[2] > self.diagram[1])
    if self.diagram then
        local width = math.max(1, frame:GetWidth() - 16)
        frame.Mark:ClearAllPoints()
        frame.Mark:SetPoint("LEFT", frame.Track, "LEFT", width * self.diagram[1], 0)
        frame.Mark:SetSize(math.max(1, width * (self.diagram[2] - self.diagram[1])), 4)
    end
    self:SetHeight(math.max(26, frame.Text:GetStringHeight() + (self.diagram and 22 or 12)))
    self.layingOut = nil
end

local function ApplyChoice(self)
    local frame = self.frame
    ThemeApply.PanelStyle(frame.AtFill, frame.AtEdge)
    frame.AtFill:SetVertexColor(ThemeApply.MixColor("Field", "Accent", self.selected and 0.14 or 0))
    frame.AtEdge:SetVertexColor(ThemeApply.Color((self.selected or self.hovered) and "Accent" or "Edge"))
    ThemeApply.FontRole(frame.Text, "Control")
    ThemeApply.FontRole(frame.Measure, "Control")
    ThemeApply.Solid(frame.Track, ThemeApply.Color("Track"))
    ThemeApply.Solid(frame.Mark, ThemeApply.Color("Accent", 0.5))
    LayoutChoice(self)
end

local function ChoiceConstructor()
    local frame = CreateFrame("Button", nil, UIParent)
    frame:Hide()
    ThemeApply.CreatePanel(frame)
    frame.Text = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.Text:SetJustifyH("LEFT")
    frame.Text:SetWordWrap(true)
    frame.Measure = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.Measure:SetWordWrap(false)
    frame.Measure:Hide()
    frame.Track = frame:CreateTexture(nil, "ARTWORK")
    frame.Track:SetPoint("BOTTOMLEFT", 8, 6)
    frame.Track:SetPoint("BOTTOMRIGHT", -8, 6)
    frame.Track:SetHeight(4)
    frame.Mark = frame:CreateTexture(nil, "ARTWORK", nil, 1)
    local widget = {
        type = ChoiceType, frame = frame, OnWidthSet = LayoutChoice, ApplySettings = ApplyChoice,
        OnAcquire = function(self)
            self.selected, self.hovered, self.diagram = false, false, nil
            self:SetFullWidth(false)
            self:SetText("")
            self:ApplySettings()
        end,
        OnRelease = function(self) self.layingOut = nil; self.frame:Hide() end,
        SetText = function(self, value)
            self.frame.Text:SetText(value)
            self.frame.Measure:SetText(value)
            LayoutChoice(self)
        end,
        SetSelected = function(self, selected) self.selected = selected; self:ApplySettings() end,
        SetDiagram = function(self, from, to) self.diagram = { from, to }; self:ApplySettings() end,
        GetPreferredWidth = function(self) return math.max(self.diagram and 100 or 1, self.frame.Measure:GetStringWidth() + 16) end,
    }
    frame:SetScript("OnClick", function() widget:Fire("OnClick") end)
    frame:SetScript("OnEnter", function() widget.hovered = true; ApplyChoice(widget) end)
    frame:SetScript("OnLeave", function() widget.hovered = false; ApplyChoice(widget) end)
    private.RegisterThemed(widget)
    return AceGUI:RegisterAsWidget(widget)
end

AceGUI:RegisterWidgetType(ChoiceType, ChoiceConstructor, 1)

local CaptionType = "AtCountdownCaption"

local function CaptionSettings(self)
    ThemeApply.FontRole(self.frame.Text, "Control")
    self:SetHeight(self.frame.Text:GetStringHeight())
end

local function CaptionConstructor()
    local frame = CreateFrame("Frame", nil, UIParent)
    frame:Hide()
    frame.Text = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.Text:SetPoint("LEFT")
    frame.Text:SetWordWrap(false)
    local widget = {
        type = CaptionType, frame = frame, ApplySettings = CaptionSettings,
        OnAcquire = function(self) self:SetFullWidth(false); self:SetText(""); self:ApplySettings() end,
        OnRelease = function(self) self.frame:Hide() end,
        SetText = function(self, value) self.frame.Text:SetText(value); self:SetHeight(self.frame.Text:GetStringHeight()) end,
        GetPreferredWidth = function(self) return self.frame.Text:GetStringWidth() end,
    }
    private.RegisterThemed(widget)
    return AceGUI:RegisterAsWidget(widget)
end

AceGUI:RegisterWidgetType(CaptionType, CaptionConstructor, 1)
