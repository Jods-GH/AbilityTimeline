local appName, app = ...
---@class AbilityTimeline
local private = app

if not C_AddOns.IsAddOnLoaded("BigWigs") then return end

private.DisableBlizzTimersBW = true
private.BWTimers = {}

local excludedTimers = {
    ["Pull"] = true,
}

local function TimerStarted(event, module, timerKey, timerMsg, timerDuration, icon, timerIsApprox, timerMaxDuration, eventID, spellIndicators)

    if eventID then
        local eventInfo = C_EncounterTimeline.GetEventInfo(eventID)
        if eventInfo.source ~= Enum.EncounterTimelineEventSource.Script then
            private.addEvent(eventInfo)
        end
        return
    end
    if excludedTimers[timerMsg] then return end
    local eventinfo = {
        duration = timerDuration,
        maxQueueDuration = 0,
        overrideName = timerMsg,
        spellID = 58984,
        iconFileID = icon,
        severity = 1,
        paused = false,
    }
    
    local eventID = C_EncounterTimeline.AddScriptEvent(eventinfo)
    private.BWTimers[eventID] = {
        eventID = eventID,
        info = {
            timerMsg = timerMsg,
            timerDuration = timerDuration,
            timerIcon = icon,
        }
    }
end

local function TimerStopped(event, module, text, timerId)
    private.Debug("BigWigs Timer Stopped: ")
    if private.BWTimers[timerId] and C_EncounterTimeline.GetEventInfo(private.BWTimers[timerId].eventID) then
        C_EncounterTimeline.RemoveScriptEvent(private.BWTimers[timerId].eventID)
        private.BWTimers[timerId] = nil
    end
end

local function TimerUpdated(event, _, _, timerId)
    if event =="BigWigs_PauseBar" then
        if private.BWTimers[timerId] and C_EncounterTimeline.GetEventInfo(private.BWTimers[timerId].eventID) then
            C_EncounterTimeline.PauseScriptEvent(private.BWTimers[timerId].eventID)
        end
    elseif event =="BigWigs_ResumeBar" then
        if private.BWTimers[timerId] and C_EncounterTimeline.GetEventInfo(private.BWTimers[timerId].eventID) then
            C_EncounterTimeline.ResumeScriptEvent(private.BWTimers[timerId].eventID)
        end
    end
end

local BWCallbackObj = {}
BigWigsLoader.RegisterMessage(BWCallbackObj, "BigWigs_StartBar", TimerStarted);
BigWigsLoader.RegisterMessage(BWCallbackObj, "StopSpecificBar", TimerStopped);
BigWigsLoader.RegisterMessage(BWCallbackObj, "BigWigs_PauseBar", TimerUpdated);
BigWigsLoader.RegisterMessage(BWCallbackObj, "BigWigs_ResumeBar", TimerUpdated);
 --   BigWigsLoader.RegisterMessage(PHOGUILD_WA_RAT_BWCallbackObj, "BigWigs_StopBars", TimerStopped);
 --   BigWigsLoader.RegisterMessage(PHOGUILD_WA_RAT_BWCallbackObj, "BigWigs_OnBossDisable", TimerStopped);