local appName, app = ...
---@class AbilityTimeline
local private = app
local AceGUI = LibStub("AceGUI-3.0")
local Type = "AtTextHighlight"
local Version = 1
local variables = {
    text_height = 20,
    text_width = 300,
}


local function ApplySettings(self)
    local text = private.GetElementStyle("TextHighlight").Text
    private.ThemeApply.Font(self.frame.SpellName, text.Font)

    if private.db.profile.highlight_text_settings.strata then
		self.frame:SetFrameStrata(private.db.profile.highlight_text_settings.strata)
	end

    local background = text.Background
    if background.Show then
        self.frame.SpellNameBackground:SetPoint("LEFT", self.frame.SpellName, "LEFT", -background.Offset.x, 0)
        self.frame.SpellNameBackground:SetPoint("RIGHT", self.frame.SpellName, "RIGHT", background.Offset.x, 0)
        self.frame.SpellNameBackground:SetPoint("TOP", self.frame.SpellName, "TOP", 0, background.Offset.y)
        self.frame.SpellNameBackground:SetPoint("BOTTOM", self.frame.SpellName, "BOTTOM", 0, -background.Offset.y)
        private.ThemeApply.Texture(self.frame.SpellNameBackground, background)
        self.frame.SpellNameBackground:Show()
    else
        self.frame.SpellNameBackground:Hide()
    end
end

---@param self AtTextHighlight
local function OnAcquire(self)
    ApplySettings(self)
end

---@param self AtTextHighlight
local function OnRelease(self)
    self.frame:SetScript("OnUpdate", nil)
end


---comment
---@param self any
---@param remainingTime any
---@return unknown
local GetTextColor = function(self, remainingTime)
    if private.db.profile.cooldown_settings.cooldown_highlight and private.db.profile.cooldown_settings.cooldown_highlight.enabled then
        for _, value in pairs(private.db.profile.cooldown_settings.cooldown_highlight.highlights) do
            local time, color = value.time, value.color
            if (remainingTime <= time) then
                local createdColor = CreateColor(color.r, color.g, color.b)
                return createdColor:GenerateHexColor()
            end
        end
    end
    local r, g, b = private.ThemeApply.Color(private.GetElementStyle("Cooldown").Font.Color)
    return CreateColor(r, g, b):GenerateHexColor()
end
---hides and shows texts to create colored texts (illegal btw)
---@param widget any
---@param eventInfo any
---@param remainingDuration any
local HandleTexts = function(widget, eventInfo, remainingDuration)
    local textColor = GetTextColor(widget, remainingDuration)
    private.manager.SetEventIconTextures(eventInfo.id, 126, widget.frame.dispellTypeIcons)
    local atlas = widget.frame.dispellTypeIcons[1]:GetAtlas()
    local formatedText = string.format("%s in |c%s%i|r", eventInfo.spellName, textColor,
        math.ceil(remainingDuration))
    if private.db.profile.highlight_text_settings.dispellIcons and atlas then
        formatedText = string.format("|A:%s:20:20|a %s in |c%s%i|r", atlas, eventInfo.spellName, textColor,
            math.ceil(remainingDuration))
    end
    widget.frame.SpellName:SetText(formatedText)
    if private.db.profile.text_settings.useEventColor then
        local color = private.manager.getEventColor(eventInfo.id)
        if color then
            widget.frame.SpellName:SetTextColor(color.r, color.g, color.b)
        end
    end
end

local SetEventInfo = function(widget, eventInfo, disableOnUpdate)
    widget.eventInfo = eventInfo
    if not disableOnUpdate then
        private.ThemeApply.PlayEnter(widget.frame, private.GetElementStyle("TextHighlight").Enter)
        HandleTexts(widget, eventInfo, eventInfo.duration)
        widget.frame:SetScript("OnUpdate", function(self)
            local remainingDuration = private.manager.getEventRemainingTime(widget.eventInfo.id)
            if remainingDuration and remainingDuration > 0 then
                HandleTexts(widget, eventInfo, remainingDuration)
            end
        end)
    end
    widget.frame:Show()
end

local function Constructor()
    local count = AceGUI:GetNextWidgetNum(Type)
    local frame = CreateFrame("Frame", "HIGHLIGHT_TEXT_" .. count, private.TEXT_HIGHLIGHT_FRAME.frame)
    frame.SpellName = frame:CreateFontString(nil, "OVERLAY", "SystemFont_Shadow_Med3")
    frame.SpellName:SetWordWrap(false)
    frame.SpellName:SetPoint("CENTER", frame, "CENTER")
    frame:SetFrameStrata(private.FrameStrata.FULLSCREEN)

    frame.SpellNameBackground = frame:CreateTexture(nil, "BACKGROUND")
    frame.SpellNameBackground:Hide()
    frame:SetWidth(variables.text_width)
    frame:SetHeight(variables.text_height)

    frame.dispellTypeTexture = frame:CreateTexture(nil, "OVERLAY")
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
        eventInfo = {},
        GetTextColor = GetTextColor,
        ApplySettings = ApplySettings,
    }
    private.RegisterThemed(widget)

    return AceGUI:RegisterAsWidget(widget)
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)
