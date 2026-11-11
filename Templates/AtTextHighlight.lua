local appName, app = ...
---@class AbilityTimeline
local private = app
local AceGUI = LibStub("AceGUI-3.0")
local Type = "AtTextHighlight"
local Version = 1
local issecretvalue = issecretvalue or function() return false end
local variables = {
    text_height = 20,
    text_width = 300,
}


local HandleTexts

local function ApplySettings(self)
    local text = private.GetElementStyle("TextHighlight").Text
    private.ThemeApply.Font(self.frame.SpellName, text.Font)
    private.CooldownText.ConfigureFont(self.frame.CooldownText, "TextHighlight", text.Font)

    if private.db.profile.highlight_text_settings.strata then
		self.frame:SetFrameStrata(private.db.profile.highlight_text_settings.strata)
	end

    local background = text.Background
    if background.Show then
        self.frame.SpellNameBackground:SetPoint("LEFT", self.frame.SpellName, "LEFT", -background.Offset.x, 0)
        self.frame.SpellNameBackground:SetPoint("RIGHT", self.frame.CooldownText, "RIGHT", background.Offset.x, 0)
        self.frame.SpellNameBackground:SetPoint("TOP", self.frame, "TOP", 0, background.Offset.y)
        self.frame.SpellNameBackground:SetPoint("BOTTOM", self.frame, "BOTTOM", 0, -background.Offset.y)
        private.ThemeApply.Texture(self.frame.SpellNameBackground, background)
        self.frame.SpellNameBackground:Show()
    else
        self.frame.SpellNameBackground:Hide()
    end
    if self.eventInfo and self.frame.atCountdownRemaining then
        HandleTexts(self, self.eventInfo, self.frame.atCountdownRemaining)
    end
end

---@param self AtTextHighlight
local function OnAcquire(self)
    ApplySettings(self)
end

---@param self AtTextHighlight
local function OnRelease(self)
    private.StopGlow(self.frame)
    private.CooldownText.Reset(self.frame, self.frame.CooldownText)
    self.eventInfo = nil
    private.ThemeApply.StopEnterEffects(self.frame)
    self.frame:SetScript("OnUpdate", nil)
    self.frame.eventInfo = nil
    self.frame.mergeCount = nil
    self.frame.mergedInto = nil
    self.frame.pendingEnter = nil
end


---comment
---@param self any
---@param remainingTime any
---@return unknown
HandleTexts = function(widget, eventInfo, remainingDuration)
    local frame = widget.frame
    frame.atCountdownRemaining = remainingDuration
    local count = widget.frame.mergeCount or 1
    local name = count > 1 and string.format(private.getLocalisation("MultipleTimers"), count) or eventInfo.spellName
    frame.SpellName:SetText(string.format(private.getLocalisation("CountdownSpellPrefix"), name))
    if eventInfo.id then private.manager.SetEventIconTextures(eventInfo.id, 126, frame.dispellTypeIcons) end
    frame.dispellTypeTexture:SetShown(private.db.profile.highlight_text_settings.dispellIcons)
    private.CooldownText.Apply(frame, frame.CooldownText, "TextHighlight", remainingDuration, eventInfo)
    local font = frame.CooldownText.atCountdownFont
    if font then
        if frame.atMeasureSize ~= frame.CooldownText.atCountdownSize or frame.atMeasurePath ~= font.path or frame.atMeasureFlags ~= font.flags then
            frame.CountdownMeasure:SetFont(font.path, frame.CooldownText.atCountdownSize, font.flags)
            frame.atMeasureSize, frame.atMeasurePath, frame.atMeasureFlags = frame.CooldownText.atCountdownSize, font.path, font.flags
        end
        frame.CountdownMeasure:SetText(frame.CooldownText.atCountdownText)
        local width = frame.CountdownMeasure:GetStringWidth()
        -- Measure only the public number on an independent region, never a secret name or its anchors.
        if not issecretvalue(width) then
            frame.SpellName:ClearAllPoints()
            frame.SpellName:SetPoint("CENTER", frame, "CENTER", -width / 2, 0)
        end
        local _, nameSize = frame.SpellName:GetFont()
        local height = math.max(variables.text_height, nameSize + 6, frame.CooldownText.atCountdownSize + 6)
        if frame:GetHeight() ~= height then
            frame:SetHeight(height)
            if not frame.countdownPreview and private.refreshTextHighlightSize then private.refreshTextHighlightSize() end
        end
    end
    frame.SpellName:SetTextColor(private.ThemeApply.Color(private.GetElementStyle("TextHighlight").Text.Font.Color))
    if count > 1 then
        widget.frame.SpellName:SetTextColor(private.ThemeApply.Color(private.GetElementStyle("TextHighlight").Text.Font.Color))
    elseif private.db.profile.text_settings.useEventColor then
        local color = private.manager.getEventColor(eventInfo.id)
        if color then
            widget.frame.SpellName:SetTextColor(color.r, color.g, color.b)
        end
    end
end

local SetMergedIcons = function(widget, members)
    local count = members and #members or 1
    if widget.frame.mergeCount == count then return end
    widget.frame.mergeCount = count
    local remaining = private.manager.getEventRemainingTime(widget.eventInfo.id)
    HandleTexts(widget, widget.eventInfo, remaining or widget.eventInfo.duration)
end

local SetEventInfo = function(widget, eventInfo, disableOnUpdate, deferDisplay)
    widget.eventInfo = eventInfo
    widget.frame.eventInfo = eventInfo
    if not disableOnUpdate then
        if deferDisplay then
            widget.frame.pendingEnter = true
        else
            private.ThemeApply.PlayEnter(widget.frame, private.GetElementStyle("TextHighlight").Enter)
        end
        HandleTexts(widget, eventInfo, eventInfo.duration)
        widget.frame:SetScript("OnUpdate", function(self)
            local remainingDuration = private.manager.getEventRemainingTime(widget.eventInfo.id)
            if remainingDuration and remainingDuration > 0 then
                HandleTexts(widget, eventInfo, remainingDuration)
            end
        end)
    end
    if deferDisplay then widget.frame:Hide() else widget.frame:Show() end
end

local function Constructor()
    local count = AceGUI:GetNextWidgetNum(Type)
    local frame = CreateFrame("Frame", "HIGHLIGHT_TEXT_" .. count, private.TEXT_HIGHLIGHT_FRAME.frame)
    frame.SpellName = frame:CreateFontString(nil, "OVERLAY", "SystemFont_Shadow_Med3")
    frame.SpellName:SetWordWrap(false)
    frame.SpellName:SetPoint("CENTER", frame, "CENTER")
    frame.CooldownText = frame:CreateFontString(nil, "OVERLAY", "SystemFont_Shadow_Med3")
    frame.CooldownText:SetPoint("LEFT", frame.SpellName, "RIGHT")
    frame.CooldownText:SetWordWrap(false)
    frame.CountdownMeasure = frame:CreateFontString(nil, "OVERLAY", "SystemFont_Shadow_Med3")
    frame.CountdownMeasure:SetPoint("CENTER", frame, "CENTER")
    frame.CountdownMeasure:Hide()
    frame:SetFrameStrata(private.FrameStrata.FULLSCREEN)

    frame.SpellNameBackground = frame:CreateTexture(nil, "BACKGROUND")
    frame.SpellNameBackground:Hide()
    frame:SetWidth(variables.text_width)
    frame:SetHeight(variables.text_height)

    frame.dispellTypeTexture = frame:CreateTexture(nil, "OVERLAY")
    frame.dispellTypeTexture:SetSize(20, 20)
    frame.dispellTypeTexture:SetPoint("RIGHT", frame.SpellName, "LEFT", -4, 0)
    frame.dispellTypeIcons = {}
    table.insert(frame.dispellTypeIcons, frame.dispellTypeTexture)

    ---@class AtTextHighlight : AceGUIWidget
    local widget = {
        OnAcquire = OnAcquire,
        OnRelease = OnRelease,
        type = Type,
        count = count,
        frame = frame,
        SetEventInfo = SetEventInfo,
        SetMergedIcons = SetMergedIcons,
        eventInfo = {},
        HandleTexts = HandleTexts,
        ApplySettings = ApplySettings,
    }
    private.RegisterThemed(widget)

    return AceGUI:RegisterAsWidget(widget)
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)
