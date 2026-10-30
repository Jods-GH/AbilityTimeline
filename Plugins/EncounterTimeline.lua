local appName, app = ...
---@class AbilityTimeline
local private = app

if not private.isRetail then return end

local SOURCE = private.manager.SOURCES.EncounterTimeline
local timelineEvents = {}
local debugLog = false

local log = function(action, timelineEventID)
    if not debugLog then return end
    local eventInfo = C_EncounterTimeline.GetEventInfo(timelineEventID)
    -- the api returns nothing for removed events so the calls are wrapped to pass nil to tostring
    -- string.format accepts secrets so spell data can be shown even in restricted encounters
    private.DebugLog(string.format("timeline %.2f %s blizzID=%s state=%s blocked=%s track=%s remaining=%s spellID=%s name=%s", GetTime(), action,
        tostring(timelineEventID), tostring((C_EncounterTimeline.GetEventState(timelineEventID))),
        tostring((C_EncounterTimeline.IsEventBlocked(timelineEventID))), tostring((C_EncounterTimeline.GetEventTrack(timelineEventID))),
        tostring((C_EncounterTimeline.GetEventTimeRemaining(timelineEventID))),
        eventInfo and eventInfo.spellID or "nil", eventInfo and eventInfo.spellName or "nil"))
end

local provider = {
    getRemaining = C_EncounterTimeline.GetEventTimeRemaining,
    getElapsed = C_EncounterTimeline.GetEventTimeElapsed,
    getState = C_EncounterTimeline.GetEventState,
    isBlocked = C_EncounterTimeline.IsEventBlocked,
    getTrack = C_EncounterTimeline.GetEventTrack,
    getColor = function(timelineEventID)
        return C_EncounterTimeline.GetEventColor(timelineEventID, Enum.EncounterEventColorTrigger.TimelineEvent)
    end,
    setIconTextures = C_EncounterTimeline.SetEventIconTextures,
}

local isPaused = function(timelineEventID)
    return C_EncounterTimeline.GetEventState(timelineEventID) == Enum.EncounterTimelineEventState.Paused
end

local isTrackHidden = function(timelineEventID)
    local trackID = C_EncounterTimeline.GetEventTrack(timelineEventID)
    return not trackID or trackID == Enum.EncounterTimelineTrack.Indeterminate or C_EncounterTimeline.GetTrackType(trackID) == Enum.EncounterTimelineTrackType.Hidden
end

---returns if the user or a boss mod allows showing the event
local isAllowed = function(timelineEvent)
    if timelineEvent.source ~= Enum.EncounterTimelineEventSource.Encounter then
        return true
    end
    if private.db.profile.disableAllBlizzTimers then
        return false
    end
    return timelineEvent.claimed or not (private.DisableBlizzTimersBW or private.DisableBlizzTimersDBM)
end

---decides when an event first appears, blizzard tracks are only used for this since sorted tracks bounce
---events back to indeterminate whenever they don't fit while our timeline positions by remaining time
local canShow = function(timelineEventID)
    local timelineEvent = timelineEvents[timelineEventID]
    if isPaused(timelineEventID) then
        return false -- ignore paused bars when added, they are always canceled some time later
    end
    if timelineEvent.source == Enum.EncounterTimelineEventSource.Encounter and isTrackHidden(timelineEventID) then
        return false
    end
    return isAllowed(timelineEvent)
end

local setShown = function(timelineEventID, shown)
    local eventID = private.manager.getEventIDFromSource(SOURCE, timelineEventID)
    timelineEvents[timelineEventID].shown = shown
    log(shown and "show" or "hide", timelineEventID)
    if eventID then
        private.manager.setEventHidden(eventID, not shown)
    end
end

local handlers = {}

---@param eventInfo EncounterTimelineEventInfo
handlers.ENCOUNTER_TIMELINE_EVENT_ADDED = function(eventInfo)
    local timelineEventID = eventInfo.id
    timelineEvents[timelineEventID] = {
        source = eventInfo.source,
        shown = false,
    }
    log("added source=" .. tostring(eventInfo.source), timelineEventID)
    private.manager.addEvent({
        source = SOURCE,
        sourceID = eventInfo.id,
        spellName = eventInfo.spellName,
        spellID = eventInfo.spellID,
        iconFileID = eventInfo.iconFileID,
        duration = eventInfo.duration,
        maxQueueDuration = eventInfo.maxQueueDuration,
        icons = eventInfo.icons,
        severity = eventInfo.severity,
        isApproximate = eventInfo.isApproximate,
        provider = provider,
        hidden = true,
    })
    C_Timer.After(0, function()
        -- blizzard events only settle their state and track after the frame they were added in
        if timelineEvents[timelineEventID] and canShow(timelineEventID) then
            setShown(timelineEventID, true)
        end
    end)
end

handlers.ENCOUNTER_TIMELINE_EVENT_STATE_CHANGED = function(timelineEventID)
    if timelineEvents[timelineEventID] then
        log("state changed", timelineEventID)
    end
end

handlers.ENCOUNTER_TIMELINE_EVENT_REMOVED = function(timelineEventID)
    log("removed", timelineEventID)
    local eventID = private.manager.getEventIDFromSource(SOURCE, timelineEventID)
    if eventID then
        private.manager.removeEvent(eventID)
    end
    timelineEvents[timelineEventID] = nil
end

local tryShow = function(timelineEventID)
    local timelineEvent = timelineEvents[timelineEventID]
    if timelineEvent.shown or not isAllowed(timelineEvent) then return end
    local remainingTime = C_EncounterTimeline.GetEventTimeRemaining(timelineEventID)
    if remainingTime and remainingTime > 1 and canShow(timelineEventID) then
        setShown(timelineEventID, true)
    end
end

-- shown events stay until they finish or get canceled so icons never disappear while counting down
handlers.ENCOUNTER_TIMELINE_EVENT_TRACK_CHANGED = function(timelineEventID)
    C_Timer.After(0, function()
        if not timelineEvents[timelineEventID] then return end
        log("track changed", timelineEventID)
        tryShow(timelineEventID)
    end)
end

handlers.ENCOUNTER_TIMELINE_EVENT_BLOCK_STATE_CHANGED = function(timelineEventID)
    if timelineEvents[timelineEventID] then
        log("block changed", timelineEventID)
    end
end

local eventFrame = CreateFrame("Frame")
for event in pairs(handlers) do
    eventFrame:RegisterEvent(event)
end
eventFrame:SetScript("OnEvent", function(self, event, ...)
    handlers[event](...)
end)

private.refreshEncounterTimelineVisibility = function()
    for timelineEventID, timelineEvent in pairs(timelineEvents) do
        if timelineEvent.shown and not isAllowed(timelineEvent) then
            setShown(timelineEventID, false)
        elseif not timelineEvent.shown and isAllowed(timelineEvent) and canShow(timelineEventID) then
            setShown(timelineEventID, true)
        end
    end
end

---marks a timeline event as used by a boss mod so it is shown even if blizzard timers are disabled by it
---@param timelineEventID EncounterTimelineEventID
private.claimEncounterTimelineEvent = function(timelineEventID)
    local timelineEvent = timelineEvents[timelineEventID]
    if timelineEvent then
        timelineEvent.claimed = true
        if not timelineEvent.shown and canShow(timelineEventID) then
            setShown(timelineEventID, true)
        end
    end
end

private.toggleEncounterTimelineDebug = function()
    debugLog = not debugLog
    if debugLog then
        private.openDebugLog()
    end
    private.DebugLog("timeline debug log " .. (debugLog and "enabled" or "disabled"))
end

private.getEncounterTimelineDebugText = function(timelineEventID)
    local timelineEvent = timelineEvents[timelineEventID]
    if not timelineEvent then return "untracked" end
    local trackID = C_EncounterTimeline.GetEventTrack(timelineEventID)
    return string.format("blizzID=%s blizzSource=%s blizzState=%s blocked=%s track=%s trackType=%s shown=%s claimed=%s",
        tostring(timelineEventID), tostring(timelineEvent.source), tostring((C_EncounterTimeline.GetEventState(timelineEventID))),
        tostring((C_EncounterTimeline.IsEventBlocked(timelineEventID))), tostring(trackID),
        tostring(trackID and C_EncounterTimeline.GetTrackType(trackID)), tostring(timelineEvent.shown), tostring(timelineEvent.claimed))
end

private.initEncounterTimelineSource = function()
    SetCVar("encounterTimelineEnabled", "1")
    private.Debug(EncounterTimeline, "encounterTimeline")

    if private.db.profile.useTimelineModule then
        EncounterTimeline:UnregisterAllEvents()
        EncounterTimeline:Hide()
        EncounterTimeline:HookScript("OnShow", function() EncounterTimeline:Hide() end)
    end
end
