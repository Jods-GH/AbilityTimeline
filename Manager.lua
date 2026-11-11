local appName, app                             = ...
---@class AbilityTimeline
local private                                  = app
local issecretvalue                            = issecretvalue or function() return false end

private.manager                                = {}
private.manager.activeTimers                   = {}
private.MAX_MERGED_TIMER_ICONS                  = 4
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
-- Addon timers with a sourceID are told apart in countdown timer selections
private.manager.COUNTDOWN_SOURCES              = { readycheck = "ReadyCheck", pull = "PullTimer", reroll = "KeyReroll" }

private.TIMELINE_TICKS                         = { 5 }

local STATES                                   = private.manager.STATES
local activeTimers                             = private.manager.activeTimers
local sourceIndex                              = {}
local lastEventID                              = 0

---groups widgets by their positionRemaining, measured from the first event in each cluster
---@param widgets table
---@param clusters table -- reused storage
---@param settings table -- merge settings for this display
---@return number clusterCount
private.manager.clusterTimers = function(widgets, clusters, settings)
   table.sort(widgets, function(a, b)
      if a.frame.positionRemaining ~= b.frame.positionRemaining then
         return a.frame.positionRemaining < b.frame.positionRemaining
      end
      return a.frame.eventInfo.id < b.frame.eventInfo.id
   end)
   local count = 0
   for _, widget in ipairs(widgets) do
      local remaining = widget.frame.positionRemaining
      local cluster = clusters[count]
      if settings.merge_timers and cluster and
          (widget.frame.mergeState or widget.frame.currentState) ==
              (cluster.members[1].frame.mergeState or cluster.members[1].frame.currentState) and
          #cluster.members < private.MAX_MERGED_TIMER_ICONS and
          remaining - cluster.remaining <= settings.merge_window then
         table.insert(cluster.members, widget)
      else
         count = count + 1
         cluster = clusters[count] or { members = {} }
         clusters[count] = cluster
         wipe(cluster.members)
         cluster.remaining = remaining
         table.insert(cluster.members, widget)
      end
   end
   return count
end

local ICON_ATLASES                             = {
   [1] = "icons_16x16_deadly",
   [2] = "icons_16x16_enrage",
   [4] = "icons_16x16_blood",
   [8] = "icons_16x16_magic",
   [16] = "icons_16x16_disease",
   [32] = "icons_16x16_curse",
   [64] = "icons_16x16_poison",
   [128] = "icons_16x16_tank",
   [256] = "icons_16x16_heal",
   [512] = "icons_16x16_damage",
}

local ICON_FALLBACKS = {
   -- Pixel rectangles from Blizzard's 512x256 EJ atlas sheet (FileDataID 7494373).
   [1] = { 199, 231, 199, 231 },
   [2] = { 299, 331, 1, 33 },
   [4] = { 1, 33, 199, 231 },
   [8] = { 469, 501, 1, 33 },
   [16] = { 265, 297, 1, 33 },
   [32] = { 67, 99, 199, 231 },
   [64] = { 265, 297, 69, 101 },
   [128] = { 265, 297, 103, 135 },
   [256] = { 333, 365, 1, 33 },
   [512] = { 133, 165, 199, 231 },
}
for _, rect in pairs(ICON_FALLBACKS) do
   rect.File = "blizzard_ej_icons"
   rect.Coords = { rect[1] / 512, rect[2] / 512, rect[3] / 256, rect[4] / 256 }
end

private.manager.getEventIconArt = function(iconBit)
   local atlas = ICON_ATLASES[iconBit]
   if atlas and private.ThemeApply.AtlasInfo(atlas) then return { Atlas = atlas } end
   return ICON_FALLBACKS[iconBit]
end

local isHighlighted = function(remaining, state, threshold)
   return state == STATES.Active and remaining > 0 and remaining <= threshold
end

---rules deciding when an event is rendered by each display
private.manager.displays = {
   timeline = function(event, remaining, state)
      return private.db.profile.useTimelineModule and private.db.global.timeline_frame[private.ACTIVE_EDITMODE_LAYOUT].enabled and
         (state ~= STATES.Active or remaining > 0)
   end,
   bigIcon = function(event, remaining, state)
      local layoutName = private.ACTIVE_EDITMODE_LAYOUT
      return private.db.global.bigicon_enabled[layoutName] and
         isHighlighted(remaining, state, private.db.profile.big_icon_settings.threshold_time)
   end,
   textHighlight = function(event, remaining, state)
      local layoutName = private.ACTIVE_EDITMODE_LAYOUT
      return private.db.global.text_highlight_enabled[layoutName] and
         isHighlighted(remaining, state, private.db.profile.highlight_text_settings.threshold_time)
   end,
   audio = function(event, remaining, state)
      if event.info.countdown then
         return isHighlighted(remaining, state, event.info.countdown)
      end
      return private.db.profile.useAudioCountdowns and
         isHighlighted(remaining, state, private.db.profile.audioCountdownTime)
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

---the timer context countdown changes select by, elapsed is only looked up when a change needs it
private.manager.GetCountdownContext = function(eventID, remaining, info, state, context, required)
   local event = eventID and activeTimers[eventID]
   context.remaining = remaining
   context.source = event and event.source or info and info.source
   if event and event.source == private.manager.SOURCES.Addon then
      context.source = private.manager.COUNTDOWN_SOURCES[event.sourceID] or context.source
   end
   context.duration = info and info.duration
   context.state = state or (event and private.manager.getEventState(eventID))
   context.elapsed = nil
   if required.elapsed then
      context.elapsed = event and private.manager.getEventTimeElapsed(eventID) or nil
   end
   return context
end

private.manager.getEventIDFromSource = function(source, sourceID)
   if sourceID == nil or issecretvalue(sourceID) or not sourceIndex[source] then return end
   return sourceIndex[source][sourceID]
end

local getDispelColor = function(event)
   local icons = event.info.icons
   if not issecretvalue(icons) and icons and icons ~= 0 then
      for _, value in ipairs(private.dispellTypeList) do
         if bit.band(icons, value.mask) ~= 0 then
            return CreateColor(private.ThemeApply.DispelColor(value))
         end
      end
   end
   -- secret icons are colored through the timeline's own event color (EventColorisation)
   return event.provider and event.provider.getColor(event.sourceID)
end

-- the sources a spell name is colored by, tried in the order of an element's colorOrder. Plugins register their own:
-- { name = locale key, getColor = fun(event), fallbackFor = { [key] = true } }
local colorSources = {
   dispel = { name = "ColorSourceDispel", getColor = getDispelColor },
}

---@param key string
---@param source table
private.manager.registerColorSource = function(key, source)
   colorSources[key] = source
end

---the source answering for key: its own, or while that isn't registered (its addon isn't loaded) one that is a
---fallback for it
---@param key string
---@return table|nil
private.manager.getColorSource = function(key)
   if colorSources[key] then return colorSources[key] end
   for _, source in pairs(colorSources) do
      if source.fallbackFor and source.fallbackFor[key] then
         return source
      end
   end
end

---@param eventID number
---@param order string[] -- the colorOrder of the element, "default" ends it
private.manager.getEventColor = function(eventID, order)
   local event = activeTimers[eventID]
   if not event then return end
   -- a color the user gave a reminder or boss timer rule always wins
   if event.customColor then
      return event.customColor
   end
   for _, key in ipairs(order) do
      if key == "default" then return end
      local source = private.manager.getColorSource(key)
      local color = source and source.getColor(event)
      if color then return color end
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
         -- { timeline, bigIcon, textHighlight } set to false hides the event there
         allowedDisplays = eventInfo.allowedDisplays,
         -- its own audio countdown in seconds, 0 for none
         countdown = eventInfo.countdown,
         glow = eventInfo.glow,
         glowColor = eventInfo.glowColor,
         -- glows from the start, not only once it is close (boss timer rules)
         glowAlways = eventInfo.glowAlways,
      },
      startTime = GetTime(),
      pausedElapsed = eventInfo.paused and 0 or nil,
      textColor = eventInfo.textColor,
      borderColor = eventInfo.borderColor,
      customColor = eventInfo.customColor,
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

---changes how an added event shows: spellName, allowedDisplays, countdown, glow, glowColor, glowAlways, customColor,
---borderColor
---@param eventID number
---@param overrides table
private.manager.setEventOverrides = function(eventID, overrides)
   local event = activeTimers[eventID]
   if not event then return end
   for _, key in ipairs({ "spellName", "allowedDisplays", "countdown", "glow", "glowColor", "glowAlways" }) do
      if overrides[key] ~= nil then
         event.info[key] = overrides[key]
      end
   end
   event.customColor = overrides.customColor or event.customColor
   event.borderColor = overrides.borderColor or event.borderColor
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
   local wasUpdatingDisplays = private.manager.isUpdatingDisplays
   private.manager.isUpdatingDisplays = true
   for eventID, event in pairs(activeTimers) do
      if not source or event.source == source then
         private.manager.removeEvent(eventID)
      end
   end
   private.manager.isUpdatingDisplays = wasUpdatingDisplays
   if not wasUpdatingDisplays then private.manager.callbacks:Fire("EVENT_DISPLAYS_UPDATED") end
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
         local art = private.manager.getEventIconArt(iconBit)
         if art.Atlas and private.ThemeApply.AtlasInfo(art.Atlas) then
            textures[index]:SetAtlas(art.Atlas)
            textures[index]:SetTexCoord(0, 1, 0, 1)
         else
            textures[index]:SetTexture(private.ThemeApply.File(art.File))
            textures[index]:SetTexCoord(unpack(art.Coords))
         end
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

local mergedDisplayTimes = { bigIcon = {}, textHighlight = {} }
local mergedDisplaySettings = { bigIcon = "big_icon_settings", textHighlight = "highlight_text_settings" }
local displayClusters = {}

-- A merged display enters and leaves at its first timer's boundary, just like its shared countdown.
local updateMergedDisplayTimes = function()
   for display, key in pairs(mergedDisplaySettings) do
      local times = mergedDisplayTimes[display]
      wipe(times)
      if private.db.profile[key].merge_timers then
         local widgets = {}
         for id, event in pairs(activeTimers) do
            local state = private.manager.getEventState(id)
            local allowed = event.info.allowedDisplays
            if not event.hidden and (not allowed or allowed[display] ~= false) and state and
                state ~= STATES.Paused and state ~= STATES.Canceled then
               local elapsed = private.manager.getEventTimeElapsed(id)
               if not elapsed or elapsed < 0 then elapsed = event.info.duration end
               table.insert(widgets, {
                  frame = { eventInfo = event.info, positionRemaining = event.info.duration - elapsed },
                  remaining = private.manager.getEventRemainingTime(id),
                  state = state,
               })
            end
         end
         local count = private.manager.clusterTimers(widgets, displayClusters, {
            merge_timers = true,
            merge_window = private.db.profile.timeline_settings.merge_window,
         })
         for i = 1, count do
            local members = displayClusters[i].members
            for _, widget in ipairs(members) do
               times[widget.frame.eventInfo.id] = members[1]
            end
         end
      end
   end
end

ticker:SetScript("OnUpdate", function()
   updateMergedDisplayTimes()
   private.manager.isUpdatingDisplays = true
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
            local allowed = event.info.allowedDisplays
            for display, shouldDisplay in pairs(private.manager.displays) do
               local merged = mergedDisplayTimes[display] and mergedDisplayTimes[display][eventID]
               local ended = event.mergedDisplayEndRemaining and event.mergedDisplayEndRemaining[display]
               local settingsKey = mergedDisplaySettings[display]
               if ended and (not private.db.profile[settingsKey].merge_timers or remaining > ended) then
                  event.mergedDisplayEndRemaining[display] = nil
                  ended = nil
               end
               -- The first event may be removed before its slightly later partners. Do not restart their
               -- display for the leftover fraction of the merge window; a timing extension can show it again.
               if merged and state == STATES.Active and (merged.state ~= STATES.Active or merged.remaining <= 0) then
                  event.mergedDisplayEndRemaining = event.mergedDisplayEndRemaining or {}
                  event.mergedDisplayEndRemaining[display] = remaining
                  ended = remaining
               end
               local isDisplayed = not ended and (not allowed or allowed[display] ~= false) and
                  shouldDisplay(event, merged and merged.remaining or remaining, merged and merged.state or state) and
                  true or nil
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
   private.manager.isUpdatingDisplays = nil
   private.manager.callbacks:Fire("EVENT_DISPLAYS_UPDATED")
end)
