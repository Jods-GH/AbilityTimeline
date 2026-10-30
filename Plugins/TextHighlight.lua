local appName, app = ...
---@class AbilityTimeline
local private = app
local AceGUI = LibStub("AceGUI-3.0")

private.HIGHLIGHT_TEXTS = {}

local textHighlightGroup = private.DynamicGroup.Create(function()
   local settings = private.db.global.text_highlight[private.ACTIVE_EDITMODE_LAYOUT]
   return {
      grow = settings.grow_direction,
      spacing = settings.margin,
      limit = settings.limit,
      sort = settings.sort,
   }
end, function()
   return private.TEXT_HIGHLIGHT_FRAME and private.TEXT_HIGHLIGHT_FRAME.frame
end)

private.evaluateTextPositions = function()
   textHighlightGroup:Layout()
end

local textHighlights = {}

private.createTextHighlight = function(eventID)
   local frame = AceGUI:Create("AtTextHighlight")
   frame:SetEventInfo(private.manager.getEventInfo(eventID))
   table.insert(private.HIGHLIGHT_TEXTS, frame)
   textHighlights[eventID] = frame
   textHighlightGroup:Add(eventID, frame.frame)
   private.evaluateTextPositions()
end

local removeTextHighlight = function(eventID)
   local frame = textHighlights[eventID]
   if not frame then return end
   textHighlights[eventID] = nil
   for i, f in ipairs(private.HIGHLIGHT_TEXTS) do
      if f == frame then
         table.remove(private.HIGHLIGHT_TEXTS, i)
         break
      end
   end
   textHighlightGroup:Remove(eventID)
   frame:Release()
   private.evaluateTextPositions()
end

private.manager.RegisterCallback("AtTextHighlight", "EVENT_DISPLAY_START", function(_, eventID, display)
   if display == "textHighlight" and not textHighlights[eventID] then
      private.createTextHighlight(eventID)
   end
end)

private.manager.RegisterCallback("AtTextHighlight", "EVENT_DISPLAY_STOP", function(_, eventID, display)
   if display == "textHighlight" then
      removeTextHighlight(eventID)
   end
end)
