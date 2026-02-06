local addonName, private               = ...
local AceGUI                           = LibStub("AceGUI-3.0")

local activeFrames                     = {}
private.ENCOUNTER_TIMELINE_EVENT_ADDED = function(self, eventInfo, initialState)
   if not private.TIMELINE_FRAME.frame:IsVisible() then
      private.handleFrame(true)
   end
   private.addEvent(eventInfo)
end

private.TIMELINE_TICKS                 = { 5 }
private.AT_THRESHHOLD                  = 0.8
private.AT_THRESHHOLD_TIME             = 10

private.BIGICON_THRESHHOLD_TIME                = 5

private.createTimelineIcon             = function(eventInfo)
   local frame = AceGUI:Create("AtAbilitySpellIcon")
   frame:SetEventInfo(eventInfo)
   activeFrames[eventInfo.id] = frame
   frame.frame:Show()

   private.Debug(frame, "AT_TIMELINE_ICON")
end
local activeEvents = {}
private.addEvent = function(eventInfo)
   --local durationObject = C_EncounterTimeline.GetEventTimer(eventInfo.id)
   --activeEvents[eventInfo.id]=durationObject
   private.createTimelineIcon(eventInfo)
end

private.removeEvent = function (eventInfo)
   activeEvents[eventInfo.id] = nil
   private.removeAtIconFrame(eventInfo.id)
end

private.ENCOUNTER_STATES               = {
   Active = 0,
   Paused = 1,
   Finished = 2,
   Canceled = 3,
   Blocked = 4,
}

private.removeAtIconFrame = function(eventID)
   local frame = activeFrames[eventID]
   if frame then
      frame.frame:Hide()
      frame:Release()
      activeFrames[eventID] = nil
   end
end

private.ENCOUNTER_TIMELINE_EVENT_STATE_CHANGED = function(self, eventID)
   local newState = C_EncounterTimeline.GetEventState(eventID)
   if newState == private.ENCOUNTER_STATES.Finished then
      private.removeAtIconFrame(eventID)
   elseif newState == private.ENCOUNTER_STATES.Canceled then
      private.removeAtIconFrame(eventID)
   elseif newState == private.ENCOUNTER_STATES.Paused then
   elseif newState == private.ENCOUNTER_STATES.Active then
   end
end

private.HIGHLIGHT_EVENTS = {
   BigIcons = {},
   HighlightTexts = {}
}
local highlightsTriggered = {}
-- private.EventTicker = C_Timer.NewTicker(0.1, function ()
--    for eventID, durationObject in pairs(activeEvents) do
--       local timeLeft = durationObject:GetRemainingDuration()
--       if timeLeft <= private.BIGICON_THRESHHOLD_TIME and timeLeft > 0 and not highlightsTriggered[eventID] then
--          private.TRIGGER_HIGHLIGHT(C_EncounterTimeline.GetEventInfo(eventID))
--       end
--    end
-- end)


private.TRIGGER_HIGHLIGHT = function(eventInfo)
   highlightsTriggered[eventInfo.id] = true
   if private.db.global.bigicon_enabled[private.ACTIVE_EDITMODE_LAYOUT] and not private.HIGHLIGHT_EVENTS.BigIcons[eventInfo.id] then
      private.createBigIcon(eventInfo)
   end
   if private.db.global.text_highlight_enabled[private.ACTIVE_EDITMODE_LAYOUT] and not private.HIGHLIGHT_EVENTS.HighlightTexts[eventInfo.id] then
      private.createTextHighlight(eventInfo)
   end
   if private.db.profile.useAudioCountdowns then
      private.playAudioAlert(eventInfo)
   end
end
private.ENCOUNTER_TIMELINE_EVENT_REMOVED = function()
   if C_EncounterTimeline.HasAnyEvents() then
   else
      private.handleFrame(false)
   end
end


private.createTimelineFrame = function()
   private.TIMELINE_FRAME = AceGUI:Create("AtTimelineFrame")

   private.BIGICON_FRAME = AceGUI:Create("AtBigIconFrame")


   private.TEXT_HIGHLIGHT_FRAME = AceGUI:Create("AtTextHighlightFrame")

   private.Debug(private.TEXT_HIGHLIGHT_FRAME, "AT_TEXT_HIGHLIGHT_FRAME")
   private.Debug(private.TIMELINE_FRAME, "AT_TIMELINE_FRAME")
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
   end
end
