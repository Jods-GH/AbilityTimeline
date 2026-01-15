local addonName, private = ...
local AceGUI = LibStub("AceGUI-3.0")
local Type = "AtTextHighlight"
local Version = 1
local variables = {
   text_height = 20,
   text_width = 300,
}


---@param self AtTextHighlight
local function OnAcquire(self)
end

---@param self AtTextHighlight
local function OnRelease(self)
    self.frame:SetScript("OnUpdate", nil)
    private.HIGHLIGHT_EVENTS.HighlightTexts[self.eventInfo.id] = nil
    for i, f in ipairs(private.HIGHLIGHT_TEXTS) do
        if f == self then
            table.remove(private.HIGHLIGHT_TEXTS, i)
            break
        end
    end
    private.evaluateTextPositions()
end

---comment
---@param self any
---@param remainingTime any
---@return unknown
local GetTextColor = function(self, remainingTime)
	if private.db.profile.cooldown_settings.cooldown_highlight and private.db.profile.cooldown_settings.cooldown_highlight.enabled then
		for _,value in pairs(private.db.profile.cooldown_settings.cooldown_highlight.highlights) do
			local time, color = value.time , value.color
			if (remainingTime <= time) then
                local createdColor = CreateColor(color.r, color.g, color.b)
                return createdColor:GenerateHexColor()
			end
		end
	end
	if private.db.profile.cooldown_settings.cooldown_color then
		local color = private.db.profile.cooldown_settings.cooldown_color
        local createdColor = CreateColor(color.r, color.g, color.b)
        return createdColor:GenerateHexColor()
	end
    return "ffffff"
end

local SetEventInfo = function(widget, eventInfo)
    widget.eventInfo = eventInfo
    local yOffset = (variables.text_height + private.db.global.text_highlight[private.ACTIVE_EDITMODE_LAYOUT].margin) * (#private.HIGHLIGHT_TEXTS)
    widget.yOffset = yOffset
    widget.frame.text:SetFormattedText("%s in %i", eventInfo.spellName, eventInfo.duration)
    widget.frame:SetScript("OnUpdate", function(self)
        local remainingDuration = C_EncounterTimeline.GetEventTimeRemaining(widget.eventInfo.id)
        if not remainingDuration or remainingDuration <= 0 then
            widget:Release()
        else
            local textColor = GetTextColor(widget, remainingDuration)
            local dispellTypeIcons = {}
            local dispellTypeTexture = widget.frame:CreateTexture(nil, "OVERLAY" )
            table.insert(dispellTypeIcons, dispellTypeTexture)
            C_EncounterTimeline.SetEventIconTextures(eventInfo.id, 126, dispellTypeIcons)
            local atlas = dispellTypeIcons[1]:GetAtlas()

            self.text:SetFormattedText("|A:%s:20:20|a %s in |c%s%i|r", atlas, eventInfo.spellName, textColor, math.ceil(remainingDuration))
        end
    end)
    widget.frame:SetPoint("BOTTOM", private.TEXT_HIGHLIGHT_FRAME.frame, "BOTTOM", 0, yOffset)
    widget.frame:Show()
end

local function Constructor()
    local count = AceGUI:GetNextWidgetNum(Type)
    local frame = CreateFrame("Frame", "HIGHLIGHT_TEXT_"..count, private.TEXT_HIGHLIGHT_FRAME.frame) 
    local yOffset = (variables.text_height + private.db.global.text_highlight[private.ACTIVE_EDITMODE_LAYOUT].margin) * (#private.HIGHLIGHT_TEXTS)
    frame.yOffset = yOffset
    frame.text = frame:CreateFontString(nil, "OVERLAY", "SystemFont_Shadow_Med3")
    frame.text:SetWidth(variables.text_width)
    frame.text:SetWordWrap(false)
    frame.text:SetPoint("CENTER", frame, "CENTER")
    frame:SetWidth(variables.text_width)
    frame:SetHeight(variables.text_height)
    frame:SetPoint("BOTTOM", private.TEXT_HIGHLIGHT_FRAME.frame, "BOTTOM", 0, yOffset)

    ---@class AtTextHighlight : AceGUIWidget
    local widget = {
        OnAcquire = OnAcquire,
        OnRelease = OnRelease,
        type = Type,
        count = count,
        frame = frame,
        SetEventInfo = SetEventInfo,
        eventInfo = {},
        yOffset = 0,
    }

    return AceGUI:RegisterAsWidget(widget)
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)
