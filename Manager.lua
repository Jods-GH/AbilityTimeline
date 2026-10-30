local appName, app                             = ...
---@class AbilityTimeline
local private                                  = app
local issecretvalue                            = issecretvalue or function() return false end

private.manager                                = {}
private.manager.activeTimers                   = {}
private.manager.callbacks                      = LibStub("CallbackHandler-1.0"):New(private.manager)

-- values match Enum.EncounterTimelineEventState so timeline states can be passed through
-- Queued is our own state for events that reached 0 and wait for the cast or their maxQueueDuration
private.manager.STATES                         = {
   Active = 0,
   Paused = 1,
   Finished = 2,
   Canceled = 3,
   Queued = 4,
}

private.manager.SOURCES                        = {
   EncounterTimeline = "EncounterTimeline",
   BigWigs = "BigWigs",
   DBM = "DBM",
   Reminder = "Reminder",
   Addon = "Addon",
}

private.TIMELINE_TICKS                         = { 5 }
private.BIGICON_THRESHHOLD_TIME                = 5

local STATES                                   = private.manager.STATES
local activeTimers                             = private.manager.activeTimers
local sourceIndex                              = {}
local lastEventID                              = 0

local ICON_ATLASES                             = {
   [1] = "icons_16x16_deadly",
   [2] = "icons_16x16_enrage",
   [4] = "icons_16x16_bleed",
   [8] = "icons_16x16_magic",
   [16] = "icons_16x16_disease",
   [32] = "icons_16x16_curse",
   [64] = "icons_16x16_poison",
   [128] = "icons_16x16_tank",
   [256] = "icons_16x16_heal",
   [512] = "icons_16x16_damage",
}

local isHighlighted = function(remaining, state)
   return state == STATES.Active and remaining > 0 and remaining <= private.BIGICON_THRESHHOLD_TIME
end

---rules deciding when an event is rendered by each display
private.manager.displays = {
   timeline = function(event, remaining, state)
      return state ~= STATES.Active or remaining > 0
   end,
   bigIcon = function(event, remaining, state)
      return private.db.global.bigicon_enabled[private.ACTIVE_EDITMODE_LAYOUT] and isHighlighted(remaining, state)
   end,
   textHighlight = function(event, remaining, state)
      return private.db.global.text_highlight_enabled[private.ACTIVE_EDITMODE_LAYOUT] and isHighlighted(remaining, state)
   end,
   audio = function(event, remaining, state)
      return private.db.profile.useAudioCountdowns and isHighlighted(remaining, state)
   end,
}

local ticker = CreateFrame("Frame")
ticker:Hide()

local getInternalElapsed = function(event)
   return event.pausedElapsed or GetTime() - event.startTime
end

private.manager.getEventRemainingTime = function(eventID)
   local event = activeTimers[eventID]
   if not event then return end
   if event.provider then
      return event.provider.getRemaining(event.sourceID)
   end
   return math.max(event.info.duration - getInternalElapsed(event), 0)
end

private.manager.getEventTimeElapsed = function(eventID)
   local event = activeTimers[eventID]
   if not event then return end
   if event.provider then
      return event.provider.getElapsed(event.sourceID)
   end
   return math.min(getInternalElapsed(event), event.info.duration)
end

private.manager.getEventState = function(eventID)
   local event = activeTimers[eventID]
   if not event then return end
   local state
   if event.provider then
      state = event.provider.getState(event.sourceID)
   elseif event.pausedElapsed then
      state = STATES.Paused
   elseif getInternalElapsed(event) >= event.info.duration + event.info.maxQueueDuration then
      state = STATES.Finished
   else
      state = STATES.Active
   end
   if state ~= STATES.Active or C_CVar.GetCVar("encounterTimelineHideQueuedCountdowns") == "1" then
      return state
   end
   if private.manager.getEventRemainingTime(eventID) == 0 then
      return STATES.Queued
   end
   return state
end

private.manager.getEventTrack = function(eventID)
   local event = activeTimers[eventID]
   if event and event.provider then
      return event.provider.getTrack(event.sourceID)
   end
end

---returns if the cast conditions of an event are currently not met, this is independent from its state since
---blocked events keep counting down and can switch between blocked and unblocked at any time
private.manager.IsEventBlocked = function(eventID)
   local event = activeTimers[eventID]
   if event and event.provider then
      return event.provider.isBlocked(event.sourceID)
   end
   return false
end

private.manager.getEventInfo = function(eventID)
   local event = activeTimers[eventID]
   return event and event.info
end

private.manager.getEventIDFromSource = function(source, sourceID)
   if sourceID == nil or issecretvalue(sourceID) or not sourceIndex[source] then return end
   return sourceIndex[source][sourceID]
end

private.manager.getEventColor = function(eventID)
   local event = activeTimers[eventID]
   if not event then return end
   local icons = event.info.icons
   if issecretvalue(icons) then
      return event.provider and event.provider.getColor(event.sourceID)
   end
   if event.textColor then
      return event.textColor
   end
   if private.db.profile.dispellTextColor and icons and icons ~= 0 then
      for _, value in ipairs(private.dispellTypeList) do
         if bit.band(icons, value.mask) ~= 0 then
            return value.color
         end
      end
   end
   if event.provider then
      return event.provider.getColor(event.sourceID)
   end
end

private.manager.getEventBorderColor = function(eventID)
   local event = activeTimers[eventID]
   return event and event.borderColor
end

---@param eventInfo table
---@return number eventID
private.manager.addEvent = function(eventInfo)
   local source, sourceID = eventInfo.source, eventInfo.sourceID
   if issecretvalue(sourceID) then
      sourceID = nil
   end
   if sourceID ~= nil then
      local existingID = private.manager.getEventIDFromSource(source, sourceID)
      if existingID then
         private.manager.removeEvent(existingID)
      end
   end
   lastEventID = lastEventID + 1
   local eventID = lastEventID
   activeTimers[eventID] = {
      id = eventID,
      source = source,
      sourceID = sourceID,
      info = {
         id = eventID,
         source = source,
         spellName = eventInfo.spellName or "",
         spellID = eventInfo.spellID or 0,
         iconFileID = eventInfo.iconFileID or 134400,
         duration = eventInfo.duration,
         maxQueueDuration = eventInfo.maxQueueDuration or 0,
         icons = eventInfo.icons,
         severity = eventInfo.severity or 1,
         isApproximate = eventInfo.isApproximate,
      },
      startTime = GetTime(),
      pausedElapsed = eventInfo.paused and 0 or nil,
      textColor = eventInfo.textColor,
      borderColor = eventInfo.borderColor,
      iconEventID = eventInfo.iconEventID,
      provider = eventInfo.provider,
      hidden = eventInfo.hidden or false,
      displays = {},
   }
   if sourceID ~= nil then
      sourceIndex[source] = sourceIndex[source] or {}
      sourceIndex[source][sourceID] = eventID
   end
   ticker:Show()
   private.manager.callbacks:Fire("EVENT_ADDED", eventID)
   return eventID
end

private.manager.pauseEvent = function(eventID)
   local event = activeTimers[eventID]
   if event and not event.provider and not event.pausedElapsed then
      event.pausedElapsed = GetTime() - event.startTime
   end
end

private.manager.resumeEvent = function(eventID)
   local event = activeTimers[eventID]
   if event and event.pausedElapsed then
      event.startTime = GetTime() - event.pausedElapsed
      event.pausedElapsed = nil
   end
end

local stopDisplays = function(event)
   local displays = event.displays
   event.displays = {}
   for display in pairs(displays) do
      private.manager.callbacks:Fire("EVENT_DISPLAY_STOP", event.id, display)
   end
end

private.manager.removeEvent = function(eventID)
   local event = activeTimers[eventID]
   if not event then return end
   stopDisplays(event)
   activeTimers[eventID] = nil
   if event.sourceID ~= nil and sourceIndex[event.source] then
      sourceIndex[event.source][event.sourceID] = nil
   end
   if not next(activeTimers) then
      ticker:Hide()
   end
   private.manager.callbacks:Fire("EVENT_REMOVED", eventID)
end

---@param source string|nil removes all events of that source, or every event if nil
private.manager.removeAllEvents = function(source)
   for eventID, event in pairs(activeTimers) do
      if not source or event.source == source then
         private.manager.removeEvent(eventID)
      end
   end
end

private.manager.setEventHidden = function(eventID, hidden)
   local event = activeTimers[eventID]
   if not event or event.hidden == hidden then return end
   event.hidden = hidden
   if hidden then
      stopDisplays(event)
   end
end

private.manager.getEventList = function()
   local eventList = {}
   for eventID in pairs(activeTimers) do
      table.insert(eventList, eventID)
   end
   return eventList
end

---writes the state of every tracked event to the debug log window
private.manager.printDebugInfo = function()
   private.openDebugLog()
   for eventID, event in pairs(activeTimers) do
      local displays = {}
      for display in pairs(event.displays) do
         table.insert(displays, display)
      end
      local line = string.format("event %d %s state=%s blocked=%s remaining=%.1f elapsed=%.1f duration=%.1f queue=%.1f hidden=%s displays=%s spellID=%s name=%s",
         eventID, tostring(event.source), tostring(private.manager.getEventState(eventID)), tostring(private.manager.IsEventBlocked(eventID)),
         private.manager.getEventRemainingTime(eventID) or -1, private.manager.getEventTimeElapsed(eventID) or -1,
         event.info.duration, event.info.maxQueueDuration, tostring(event.hidden), table.concat(displays, ","),
         event.info.spellID, event.info.spellName)
      if event.source == private.manager.SOURCES.EncounterTimeline and private.getEncounterTimelineDebugText then
         line = line .. " " .. private.getEncounterTimelineDebugText(event.sourceID)
      end
      private.DebugLog(line)
   end
   private.DebugLog(string.format("---- manager events at %.2f ----", GetTime()))
end

private.manager.hasEvents = function()
   return next(activeTimers) ~= nil
end

private.manager.hasVisibleEvents = function()
   for _, event in pairs(activeTimers) do
      if event.displays.timeline then
         return true
      end
   end
   return false
end

private.manager.hasPausedEvents = function()
   for eventID in pairs(activeTimers) do
      if private.manager.getEventState(eventID) == STATES.Paused then
         return true
      end
   end
   return false
end

---Updates the textures to show the icons of an event, works with secret icons for timeline events
---@param eventID number
---@param mask number EncounterEventIconmask bits to include
---@param textures table array of textures
private.manager.SetEventIconTextures = function(eventID, mask, textures)
   local event = activeTimers[eventID]
   if not event then return end
   if event.iconEventID and activeTimers[event.iconEventID] then
      event = activeTimers[event.iconEventID]
   end
   if event.provider then
      event.provider.setIconTextures(event.sourceID, mask, textures)
      return
   end
   local icons = event.info.icons or 0
   local index = 1
   local iconBit = 1
   while iconBit <= 512 do
      if textures[index] and bit.band(mask, iconBit) ~= 0 and bit.band(icons, iconBit) ~= 0 then
         textures[index]:SetAtlas(ICON_ATLASES[iconBit])
         textures[index]:SetAlpha(1)
         index = index + 1
      end
      iconBit = iconBit * 2
   end
   for i = index, #textures do
      textures[i]:SetTexture(nil)
      textures[i]:SetAlpha(0)
   end
end

ticker:SetScript("OnUpdate", function()
   for eventID, event in pairs(activeTimers) do
      local state = private.manager.getEventState(eventID)
      if not state or state == STATES.Finished or state == STATES.Canceled then
         private.manager.removeEvent(eventID)
      else
         if state ~= event.state then
            event.state = state
            private.manager.callbacks:Fire("EVENT_STATE_CHANGED", eventID, state)
         end
         local remaining = private.manager.getEventRemainingTime(eventID)
         if not event.hidden then
            for display, shouldDisplay in pairs(private.manager.displays) do
               local isDisplayed = shouldDisplay(event, remaining, state) and true or nil
               if isDisplayed ~= event.displays[display] then
                  event.displays[display] = isDisplayed
                  private.manager.callbacks:Fire(isDisplayed and "EVENT_DISPLAY_START" or "EVENT_DISPLAY_STOP", eventID,
                     display)
               end
            end
            if event.lastRemaining and state == STATES.Active then
               for _, time in ipairs(private.TIMELINE_TICKS) do
                  if event.lastRemaining > time and remaining <= time then
                     private.manager.callbacks:Fire("EVENT_TICK", eventID, time)
                  end
               end
            end
         end
         event.lastRemaining = remaining
      end
   end
end)
