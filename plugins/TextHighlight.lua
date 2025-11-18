local addonName, private = ...

private.TEXT_HIGHLIGHT_WIDTH = 400
private.TEXT_HIGHLIGHT_HEIGHT = 30
private.TEXT_HIGHLIGHT_MARGIN = 10

private.HIGHLIGHT_TEXTS = {}

private.evaluateTextPositions = function()
   print("Evaluating text highlight positions")
   local visibleIcons = 0
   table.sort(private.HIGHLIGHT_TEXTS, function(a, b) return a.eventInfo.duration < b.eventInfo.duration end)
   for i, frame in ipairs(private.HIGHLIGHT_TEXTS) do
      if frame and frame:IsShown() then
         local yOffset = (private.TEXT_HIGHLIGHT_HEIGHT + private.TEXT_HIGHLIGHT_MARGIN) * (visibleIcons)
         if frame.yOffset ~=  yOffset then
            frame.yOffset = yOffset
            frame:SetPoint("BOTTOM", private.TEXT_HIGHLIGHT_FRAME, "BOTTOM", 0, yOffset)
         end
         visibleIcons = visibleIcons + 1
      end
   end
end

private.createTextHighlight = function(eventInfo)
    local frame = CreateFrame("Frame", "HIGHLIGHT_TEXT_"..eventInfo.id, private.TEXT_HIGHLIGHT_FRAME) -- TODO CHANGE THIS TO ICON POOL with template
    print("HIGHLIGHT TEXT for event " .. eventInfo.id)
    local yOffset = (private.TEXT_HIGHLIGHT_HEIGHT + private.TEXT_HIGHLIGHT_MARGIN) * (#private.HIGHLIGHT_TEXTS)
    frame.yOffset = yOffset
    frame.eventInfo = eventInfo
    frame.text = frame:CreateFontString(nil, "OVERLAY", "SystemFont_Shadow_Med3")
    frame.text:SetWidth(private.TEXT_HIGHLIGHT_WIDTH)
    frame.text:SetFormattedText("%s in %i", C_Spell.GetSpellName(eventInfo.tooltipSpellID), eventInfo.duration)
    frame.text:SetWordWrap(false)
    frame.text:SetPoint("CENTER", frame, "CENTER")
    frame:SetScript("OnUpdate", function(self)
        local remainingDuration = C_EncounterTimeline.GetEventTimeRemaining(self.eventInfo.id)
        if not remainingDuration or remainingDuration <= 0 then
            frame:Hide()
            frame:SetScript("OnUpdate", nil)
            private.HIGHLIGHT_EVENTS.HighlightTexts[self.eventInfo.id] = nil
            for i, f in ipairs(private.HIGHLIGHT_TEXTS) do
                if f == frame then
                    table.remove(private.HIGHLIGHT_TEXTS, i)
                    break
                end
            end
            private.evaluateTextPositions()
        else
            self.text:SetFormattedText("%s in %i", C_Spell.GetSpellName(eventInfo.tooltipSpellID), math.ceil(remainingDuration))
        end
    end)
    frame:SetWidth(private.TEXT_HIGHLIGHT_WIDTH)
    frame:SetHeight(private.TEXT_HIGHLIGHT_HEIGHT)
    frame:SetPoint("BOTTOM", private.TEXT_HIGHLIGHT_FRAME, "BOTTOM", 0, yOffset)
    frame:EnableMouse(true)
    frame:Show()
    table.insert(private.HIGHLIGHT_TEXTS, frame)
    private.HIGHLIGHT_EVENTS.HighlightTexts[eventInfo.id] = true
    private.evaluateTextPositions()
end






