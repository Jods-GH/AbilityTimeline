local appName, app = ...
---@class AbilityTimeline
local private = app
local AceGUI = LibStub("AceGUI-3.0")

private.HIGHLIGHT_TEXTS = {}

local GROW_POSITION = {
   UP = "TOP",
   DOWN = "BOTTOM",
}

local RELATIVE_GROW_POSITION = {
   UP = "BOTTOM",
   DOWN = "TOP",
}
private.evaluateTextPositions = function()
   local visibleIcons = 0
   table.sort(private.HIGHLIGHT_TEXTS, function(a, b)
      local aRemaining = private.manager.getEventRemainingTime(a.eventInfo.id)
      local bRemaining = private.manager.getEventRemainingTime(b.eventInfo.id)
      if aRemaining and bRemaining and aRemaining ~= bRemaining then
         return aRemaining < bRemaining
      else
         return a.eventInfo.id < b.eventInfo.id
      end
   end)
   for i, frame in ipairs(private.HIGHLIGHT_TEXTS) do
      if frame and frame:IsShown() then
         local anchorFrame = private.TEXT_HIGHLIGHT_FRAME.frame
         local relAnchor
         local margin = private.db.global.text_highlight[private.ACTIVE_EDITMODE_LAYOUT].margin
         if i ~= 1 then
            anchorFrame = private.HIGHLIGHT_TEXTS[i - 1].frame
            relAnchor = GROW_POSITION[private.db.global.text_highlight[private.ACTIVE_EDITMODE_LAYOUT].grow_direction]
         else
            relAnchor = RELATIVE_GROW_POSITION
            [private.db.global.text_highlight[private.ACTIVE_EDITMODE_LAYOUT].grow_direction]
            margin = 0
         end
         if private.db.global.text_highlight[private.ACTIVE_EDITMODE_LAYOUT].grow_direction == 'UP' then
            if frame.anchorFrame ~= anchorFrame or relAnchor ~= frame.relAnchor or frame.margin ~= margin or frame.growdirection ~= 'UP' then
               frame.anchorFrame = anchorFrame
               frame.relAnchor = relAnchor
               frame.margin = margin
               frame:ClearAllPoints()
               frame:SetPoint("BOTTOM", anchorFrame, relAnchor, 0, margin)
               frame.growdirection = 'UP'
            end
         elseif private.db.global.text_highlight[private.ACTIVE_EDITMODE_LAYOUT].grow_direction == 'DOWN' then
            if frame.anchorFrame ~= anchorFrame or relAnchor ~= frame.relAnchor or frame.margin ~= margin or frame.growdirection ~= 'DOWN' then
               frame.anchorFrame = anchorFrame
               frame.relAnchor = relAnchor
               frame.margin = margin
               frame:ClearAllPoints()
               frame:SetPoint("TOP", anchorFrame, relAnchor, 0, -margin)
               frame.growdirection = 'DOWN'
            end
         end

         visibleIcons = visibleIcons + 1
      end
   end
end

local textHighlights = {}

private.createTextHighlight = function(eventID)
   local frame = AceGUI:Create("AtTextHighlight")
   frame:SetEventInfo(private.manager.getEventInfo(eventID))
   table.insert(private.HIGHLIGHT_TEXTS, frame)
   textHighlights[eventID] = frame
   private.evaluateTextPositions()
end

private.manager.RegisterCallback("AtTextHighlight", "EVENT_DISPLAY_START", function(_, eventID, display)
   if display == "textHighlight" and not textHighlights[eventID] then
      private.createTextHighlight(eventID)
   end
end)

private.manager.RegisterCallback("AtTextHighlight", "EVENT_DISPLAY_STOP", function(_, eventID, display)
   if display == "textHighlight" and textHighlights[eventID] then
      textHighlights[eventID]:Release()
      textHighlights[eventID] = nil
   end
end)
