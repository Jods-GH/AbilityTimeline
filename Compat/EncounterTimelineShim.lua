-- Local implementation of C_EncounterTimeline for Classic Era clients,
-- which do not ship Blizzard's encounter timeline API.
--
-- It emulates the API surface this addon consumes: script events (pull
-- timers, ready checks, reminders, test bars), edit mode preview events
-- and the state/time queries used by the timeline UI. State changes are
-- broadcast as AceEvent messages ("ENCOUNTER_TIMELINE_EVENT_*"), which
-- Main.lua listens to on classic clients.
--
-- Lifecycle of a locally created event:
--   0 <= elapsed < duration                          -> Active
--   duration <= elapsed < duration+maxQueueDuration   -> Active, IsEventBlocked = true
--   elapsed >= duration+maxQueueDuration             -> Finished + removed

local appName, app = ...

-- Some classic builds (e.g. Anniversary 11509) ship the C_EncounterTimeline
-- bindings without any working feature behind them (IsFeatureAvailable=false,
-- no UI module, no cvar). Engage the shim on classic whenever the native
-- implementation is absent OR unusable; never touch retail.
local function nativeTimelineUsable()
    return C_EncounterTimeline ~= nil
        and C_EncounterTimeline.IsFeatureEnabled ~= nil
        and C_EncounterTimeline:IsFeatureEnabled()
        and C_EncounterTimeline.IsFeatureAvailable ~= nil
        and C_EncounterTimeline:IsFeatureAvailable()
end

if not app.IS_CLASSIC then
    return -- retail client: the real API governs
end

if nativeTimelineUsable() then
    return -- this classic build ships a working native timeline: prefer it
end

C_EncounterTimeline = C_EncounterTimeline or {}

-- Resolved lazily: a hard requirement here would abort this file mid-load
-- and leave the API half-populated (empty table, no functions).
local function getAceEvent()
    return LibStub and LibStub("AceEvent-3.0", true)
end

local function broadcast(messageName, ...)
    local AceEvent = getAceEvent()
    if AceEvent then
        AceEvent:SendMessage(messageName, ...)
    end
end

local STATE = Enum.EncounterTimelineEventState
local SOURCE = Enum.EncounterTimelineEventSource

local STANDARD_TRACK_ID = 0

local events = {}
local nextEventId = 1
local updateTicker

local function getElapsedSeconds(event)
    if event.paused then
        return event.elapsedBeforePause
    end
    return GetTime() - event.startAt
end

local function stopTickerIfIdle()
    if updateTicker and not next(events) then
        updateTicker:Cancel()
        updateTicker = nil
    end
end

local function removeEvent(event, newState)
    events[event.id] = nil
    broadcast("ENCOUNTER_TIMELINE_EVENT_STATE_CHANGED", event.id, newState)
    broadcast("ENCOUNTER_TIMELINE_EVENT_REMOVED", event.id)
    stopTickerIfIdle()
end

local function pruneExpiredEvents()
    local expiredEvents
    for _, event in pairs(events) do
        local totalLifetime = event.duration + (event.maxQueueDuration or 0)
        if getElapsedSeconds(event) >= totalLifetime then
            expiredEvents = expiredEvents or {}
            expiredEvents[#expiredEvents + 1] = event
        end
    end
    if expiredEvents then
        for _, event in ipairs(expiredEvents) do
            removeEvent(event, STATE.Finished)
        end
    end
end

-- Drives the automatic transition into the Finished state once an event's
-- duration and queue window have fully passed. Only runs while events exist.
local function ensureUpdateTicker()
    if not updateTicker then
        updateTicker = C_Timer.NewTicker(0.05, function()
            pruneExpiredEvents()
            stopTickerIfIdle()
        end)
    end
end

local function buildEventInfoSnapshot(event)
    local spellName = event.overrideName
    if not spellName and event.spellID and C_Spell.GetSpellInfo then
        local spellInfo = C_Spell.GetSpellInfo(event.spellID)
        spellName = spellInfo and spellInfo.name
    end
    return {
        id = event.id,
        duration = event.duration,
        maxQueueDuration = event.maxQueueDuration,
        overrideName = event.overrideName,
        spellID = event.spellID,
        iconFileID = event.iconFileID,
        severity = event.severity,
        source = event.source,
        paused = event.paused,
        icons = event.icons,
        spellName = spellName or "?",
    }
end

local function createEvent(eventInfo, source)
    local id = nextEventId
    nextEventId = nextEventId + 1

    local event = {
        id = id,
        duration = eventInfo.duration or 0,
        maxQueueDuration = eventInfo.maxQueueDuration or 0,
        overrideName = eventInfo.overrideName,
        spellID = eventInfo.spellID,
        iconFileID = eventInfo.iconFileID,
        severity = eventInfo.severity,
        source = source,
        startAt = GetTime(),
        elapsedBeforePause = 0,
        paused = false,
        state = STATE.Active,
        icons = 0,
    }
    events[id] = event
    ensureUpdateTicker()
    broadcast("ENCOUNTER_TIMELINE_EVENT_ADDED", buildEventInfoSnapshot(event), STATE.Active)
    return id
end


function C_EncounterTimeline.AddScriptEvent(eventInfo)
    return createEvent(eventInfo, SOURCE.Script)
end

function C_EncounterTimeline.CancelScriptEvent(eventID)
    local event = events[eventID]
    if not event then
        return
    end
    removeEvent(event, STATE.Canceled)
end

function C_EncounterTimeline.PauseScriptEvent(eventID)
    local event = events[eventID]
    if not event or event.paused then
        return
    end
    event.elapsedBeforePause = getElapsedSeconds(event)
    event.paused = true
    broadcast("ENCOUNTER_TIMELINE_EVENT_STATE_CHANGED", eventID, STATE.Paused)
end

function C_EncounterTimeline.ResumeScriptEvent(eventID)
    local event = events[eventID]
    if not event or not event.paused then
        return
    end
    event.startAt = GetTime() - (event.elapsedBeforePause or 0)
    event.paused = false
    broadcast("ENCOUNTER_TIMELINE_EVENT_STATE_CHANGED", eventID, STATE.Active)
end

function C_EncounterTimeline.CancelAllScriptEvents()
    for _, event in pairs(events) do
        if event.source == SOURCE.Script then
            removeEvent(event, STATE.Canceled)
        end
    end
end

function C_EncounterTimeline.AddEditModeEvents()
    C_EncounterTimeline.CancelEditModeEvents()

    -- Preview bars mimicking retail's edit mode encounter events.
    local previewDurations = { 5, 10, 15 }
    for _, duration in ipairs(previewDurations) do
        createEvent({
            duration = duration,
            maxQueueDuration = 5,
            overrideName = "Preview",
            spellID = 376864,
            iconFileID = 135127,
            severity = 1,
            paused = false,
        }, SOURCE.EditMode)
    end
end

function C_EncounterTimeline.CancelEditModeEvents()
    for _, event in pairs(events) do
        if event.source == SOURCE.EditMode then
            removeEvent(event, STATE.Canceled)
        end
    end
end

function C_EncounterTimeline.IsFeatureEnabled()
    return true
end

function C_EncounterTimeline.IsFeatureAvailable()
    return true
end

function C_EncounterTimeline.GetEventList()
    local eventIDs = {}
    for _, event in pairs(events) do
        eventIDs[#eventIDs + 1] = event.id
    end
    table.sort(eventIDs)
    return eventIDs
end

function C_EncounterTimeline.HasAnyEvents()
    return next(events) ~= nil
end

function C_EncounterTimeline.HasActiveEvents()
    return next(events) ~= nil
end

function C_EncounterTimeline.GetEventInfo(eventID)
    local event = events[eventID]
    if not event then
        return nil
    end
    return buildEventInfoSnapshot(event)
end

function C_EncounterTimeline.GetEventState(eventID)
    local event = events[eventID]
    if not event then
        return nil
    end
    return event.state
end

function C_EncounterTimeline.GetEventTimeElapsed(eventID)
    local event = events[eventID]
    if not event then
        return nil
    end
    return getElapsedSeconds(event)
end

function C_EncounterTimeline.GetEventTimeRemaining(eventID)
    local event = events[eventID]
    if not event then
        return nil
    end
    local remaining = event.duration - getElapsedSeconds(event)
    if remaining < 0 then
        remaining = 0
    end
    return remaining
end

function C_EncounterTimeline.IsEventBlocked(eventID)
    local event = events[eventID]
    if not event then
        return false
    end
    local elapsed = getElapsedSeconds(event)
    return elapsed >= event.duration and elapsed < event.duration + (event.maxQueueDuration or 0)
end

function C_EncounterTimeline.GetEventTrack(eventID)
    return events[eventID] and STANDARD_TRACK_ID or nil
end

function C_EncounterTimeline.GetTrackType(trackID)
    if trackID == STANDARD_TRACK_ID then
        return Enum.EncounterTimelineTrackType.Standard
    end
    return nil
end

---Retail signature: SetEventIconTextures(eventID, iconMask, textures).
---Locally created events carry no blizzard icon data, so whenever the event
---does not have the requested icon bit set the supplied textures are hidden;
---the addon draws its own decorations otherwise.
function C_EncounterTimeline.SetEventIconTextures(eventID, iconMask, textures)
    local event = events[eventID]
    local hasBit = event and iconMask and bit.band(event.icons, iconMask) ~= 0
    if hasBit or not textures then
        return
    end
    for _, texture in ipairs(textures) do
        texture:SetTexture(nil)
        texture:Hide()
    end
end

local eventColors = {}

---Returns the color configured for an event (white by default).
function C_EncounterTimeline.GetEventColor(eventID, colorTrigger)
    return eventColors[eventID] or CreateColor(1, 1, 1, 1)
end

---Marks this table as the addon's shim so consumers can tell it apart from
---Blizzard's native implementation (which never carries this key).
C_EncounterTimeline.__ABILITYTIMELINE_SHIM = true
