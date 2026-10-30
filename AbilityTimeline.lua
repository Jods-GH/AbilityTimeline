local appName, app                             = ...
---@class AbilityTimeline
local private                                  = app
local AceGUI                                   = LibStub("AceGUI-3.0")

private.activeFrames                             = {}

private.AT_THRESHHOLD                          = 0.8

private.createTimelineIcon                     = function(eventID)
   if private.activeFrames[eventID] then
     -- private.Debug("Frame already exists for eventID".. eventID.. "removing existing frame")
      private.removeAtIconFrame(eventID)
   end
   local frame = AceGUI:Create("AtAbilitySpellIcon")
   frame:SetEventInfo(private.manager.getEventInfo(eventID))
   private.activeFrames[eventID] = frame
   frame.frame:Show()
end

private.ENCOUNTER_STATES                       = private.manager.STATES

private.removeAtIconFrame                      = function(eventID)
   local frame = private.activeFrames[eventID]
   if frame then
      frame.frame:Hide()
      frame:Release()
      private.activeFrames[eventID] = nil
   else
      -- private.Debug("No frame found for eventID".. eventID)
   end
end

private.manager.RegisterCallback("AbilityTimeline", "EVENT_DISPLAY_START", function(_, eventID, display)
   if display ~= "timeline" then return end
   if not private.TIMELINE_FRAME.frame:IsVisible() then
      private.handleFrame(true)
   end
   private.createTimelineIcon(eventID)
end)

private.manager.RegisterCallback("AbilityTimeline", "EVENT_DISPLAY_STOP", function(_, eventID, display)
   if display ~= "timeline" then return end
   private.removeAtIconFrame(eventID)
   if not private.manager.hasVisibleEvents() then
      private.handleFrame(false)
   end
end)

private.manager.RegisterCallback("AbilityTimeline", "EVENT_TICK", function(_, eventID)
   local frame = private.activeFrames[eventID]
   if frame then
      frame:PlayHighlight()
   end
end)

private.createTimelineFrame = function()
   private.TIMELINE_FRAME = AceGUI:Create("AtTimelineFrame")

   private.BIGICON_FRAME = AceGUI:Create("AtBigIconFrame")


   private.TEXT_HIGHLIGHT_FRAME = AceGUI:Create("AtTextHighlightFrame")
end

private.handleFrame = function(show)
   if show then
      if not private.TIMELINE_FRAME.frame then
         private.createTimelineFrame()
      end
      private.TIMELINE_FRAME.frame:Show()
   else
      if private.TIMELINE_FRAME.frame then
         private.TIMELINE_FRAME.frame:Hide()
      end
      private.removeAllFrames()
   end
end

private.removeAllFrames = function()
   for eventID, frame in pairs(private.activeFrames) do
      private.removeAtIconFrame(eventID)
   end
end
