local addonName, private = ...
local AceGUI = LibStub("AceGUI-3.0")
local Type = "AtTextHighlight"
local Version = 1
local variables = {
   
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
local SetEventInfo = function(widget, eventInfo)
    widget.eventInfo = eventInfo
    local yOffset = (private.TEXT_HIGHLIGHT_TEXT_HEIGHT + private.TEXT_HIGHLIGHT_MARGIN) * (#private.HIGHLIGHT_TEXTS)
    widget.yOffset = yOffset
    widget.frame.text:SetFormattedText("%s in %i", eventInfo.spellName, eventInfo.duration)
    widget.frame:SetScript("OnUpdate", function(self)
        local remainingDuration = C_EncounterTimeline.GetEventTimeRemaining(widget.eventInfo.id)
        if not remainingDuration or remainingDuration <= 0 then
            widget:Release()
        else
            self.text:SetFormattedText("%s in %i", eventInfo.spellName, math.ceil(remainingDuration))
        end
    end)
    widget.frame:SetPoint("BOTTOM", private.TEXT_HIGHLIGHT_FRAME.frame, "BOTTOM", 0, yOffset)
    widget.frame:Show()
end

local function Constructor()
    local count = AceGUI:GetNextWidgetNum(Type)
    local frame = CreateFrame("Frame", "HIGHLIGHT_TEXT_"..count, private.TEXT_HIGHLIGHT_FRAME.frame) 
    local yOffset = (private.TEXT_HIGHLIGHT_TEXT_HEIGHT + private.TEXT_HIGHLIGHT_MARGIN) * (#private.HIGHLIGHT_TEXTS)
    frame.yOffset = yOffset
    frame.text = frame:CreateFontString(nil, "OVERLAY", "SystemFont_Shadow_Med3")
    frame.text:SetWidth(private.TEXT_HIGHLIGHT_TEXT_WIDTH)
    frame.text:SetWordWrap(false)
    frame.text:SetPoint("CENTER", frame, "CENTER")
    frame:SetWidth(private.TEXT_HIGHLIGHT_TEXT_WIDTH)
    frame:SetHeight(private.TEXT_HIGHLIGHT_TEXT_HEIGHT)
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
