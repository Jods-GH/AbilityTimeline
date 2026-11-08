local appName, app = ...
---@class AbilityTimeline
local private = app
local AceGUI = LibStub("AceGUI-3.0")

private.HIGHLIGHT_TEXTS = {}

local textHighlightGroup = private.DynamicGroup.CreateMerged(function()
   local settings = private.db.global.text_highlight[private.ACTIVE_EDITMODE_LAYOUT]
   return {
      grow = settings.grow_direction,
      spacing = settings.margin,
      limit = private.db.profile.highlight_text_settings.limit,
      sort = private.db.profile.highlight_text_settings.sort,
      merge_timers = private.db.profile.highlight_text_settings.merge_timers,
      merge_window = private.db.profile.timeline_settings.merge_window,
   }
end, function()
   return private.TEXT_HIGHLIGHT_FRAME and private.TEXT_HIGHLIGHT_FRAME.frame
end, function(widget)
   private.ThemeApply.PlayEnter(widget.frame, private.GetElementStyle("TextHighlight").Enter)
end)

private.evaluateTextPositions = function()
   if private.manager.isUpdatingDisplays then textHighlightGroup:MarkDirty() else textHighlightGroup:Layout() end
end

local textHighlights = {}

private.createTextHighlight = function(eventID)
   local frame = AceGUI:Create("AtTextHighlight")
   frame.frame:Hide()
   frame:SetEventInfo(private.manager.getEventInfo(eventID), false, true)
   table.insert(private.HIGHLIGHT_TEXTS, frame)
   textHighlights[eventID] = frame
   textHighlightGroup:AddWidget(eventID, frame)
   private.evaluateTextPositions()
end

local removeTextHighlight = function(eventID)
   local frame = textHighlights[eventID]
   if not frame then return end
   textHighlights[eventID] = nil
   textHighlightGroup:RemoveWidget(eventID)
   for i, f in ipairs(private.HIGHLIGHT_TEXTS) do
      if f == frame then
         table.remove(private.HIGHLIGHT_TEXTS, i)
         break
      end
   end
   local exitTime = 0
   if frame.frame:IsVisible() then
      exitTime = private.ThemeApply.PlayExit(frame.frame, private.GetElementStyle("TextHighlight").Exit)
   end
   -- the other texts keep their place until the text finished its exit
   textHighlightGroup:Hold(eventID, exitTime)
   frame:Release()
   private.evaluateTextPositions()
end

private.manager.RegisterCallback("AtTextHighlight", "EVENT_DISPLAY_START", function(_, eventID, display)
   if display == "textHighlight" and not textHighlights[eventID] then
      private.createTextHighlight(eventID)
   end
end)

private.manager.RegisterCallback("AtTextHighlight", "EVENT_DISPLAYS_UPDATED", function()
   if textHighlightGroup:IsDirty() then textHighlightGroup:Layout() end
end)

private.manager.RegisterCallback("AtTextHighlight", "EVENT_DISPLAY_STOP", function(_, eventID, display)
   if display == "textHighlight" then
      removeTextHighlight(eventID)
   end
end)
