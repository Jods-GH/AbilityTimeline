local addonName, private = ...
local AceGUI = LibStub("AceGUI-3.0")

private.HIGHLIGHT_TEXTS = {}
private.TEXT_HIGHLIGHT_TEXT_HEIGHT = 20 -- move this to the template?
private.TEXT_HIGHLIGHT_MARGIN = 5-- move this to the template?
private.TEXT_HIGHLIGHT_TEXT_WIDTH = 300-- move this to the template?
-- TODO Positioning is currently completly random and it just jumps around which is terribly
private.evaluateTextPositions = function()
   local visibleIcons = 0
   table.sort(private.HIGHLIGHT_TEXTS, function(a, b) return a.eventInfo.duration < b.eventInfo.duration end)
   for i, frame in ipairs(private.HIGHLIGHT_TEXTS) do
      if frame and frame:IsShown() then
         local yOffset = (private.TEXT_HIGHLIGHT_TEXT_HEIGHT + private.TEXT_HIGHLIGHT_MARGIN) * (visibleIcons)
         if frame.yOffset ~=  yOffset then
            frame.yOffset = yOffset
            frame:SetPoint("BOTTOM", private.TEXT_HIGHLIGHT_FRAME.frame, "BOTTOM", 0, yOffset)
         end
         visibleIcons = visibleIcons + 1
      end
   end
end

private.createTextHighlight = function(eventInfo)
    local frame = AceGUI:Create("AtTextHighlight")
    frame:SetEventInfo(eventInfo)
    table.insert(private.HIGHLIGHT_TEXTS, frame)
    private.HIGHLIGHT_EVENTS.HighlightTexts[eventInfo.id] = true
    private.evaluateTextPositions()
end






