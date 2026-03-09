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
        if eventInfo.source ~= Enum.EncounterTimelineEventSource.Script and eventInfo.source ~= Enum.EncounterTimelineEventSource.EditMode then
            private.addEvent(eventInfo)
        end
        return
    end
    if excludedTimers[timerMsg] then return end
    if type(icon) == "string" then
        -- bigwigs uses filepaths for icons but the script event expects fileIDs, so we need to convert it 
        local iconpath = string.gsub(icon, "\\", "/")
        icon = GetFileIDFromPath(iconpath)
    end
    -- TODO make it selectable if users want to use bartext or barcolor or none
    local color = BigWigs:GetPlugin("Colors"):GetColorTable("barText", module, timerKey)
    local msg = ""
    if color then
        local r,g,b,a = unpack(color)
        if r ~= 1 or g ~= 1 or b ~= 1 or a ~= 1 then
            local actualColor = CreateColor(r, g, b, a)
            msg = string.format("|c%s%s|r", actualColor:GenerateHexColor(),
            timerMsg)
        end
    else 
        msg = timerMsg
    end
            
    local eventinfo = {
        duration = timerDuration,
        maxQueueDuration = 0,
        overrideName = msg,
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
        C_EncounterTimeline.CancelScriptEvent(private.BWTimers[timerId].eventID)
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

local function StopAllTimers()
    private.Debug("BigWigs Stop All Timers")
    C_EncounterTimeline.CancelAllScriptEvents()
    for timerId, timerData in pairs(private.BWTimers) do
        private.BWTimers[timerId] = nil
    end
    private.removeAllFrames()
end

local BWCallbackObj = {}
BigWigsLoader.RegisterMessage(BWCallbackObj, "BigWigs_StartBar", TimerStarted);
BigWigsLoader.RegisterMessage(BWCallbackObj, "StopSpecificBar", TimerStopped);
BigWigsLoader.RegisterMessage(BWCallbackObj, "BigWigs_PauseBar", TimerUpdated);
BigWigsLoader.RegisterMessage(BWCallbackObj, "BigWigs_ResumeBar", TimerUpdated);
BigWigsLoader.RegisterMessage(BWCallbackObj, "BigWigs_StopBars", StopAllTimers);
BigWigsLoader.RegisterMessage(BWCallbackObj, "BigWigs_OnBossDisable", StopAllTimers);
BigWigsLoader.RegisterMessage(BWCallbackObj, "BigWigs_OnPluginDisable", StopAllTimers);

local function hideBWBar(_, _, bar)
    bar:SetAlpha(0)
end

BigWigsLoader.RegisterMessage(BWCallbackObj, "BigWigs_BarCreated", hideBWBar);
BigWigsLoader.RegisterMessage(BWCallbackObj, "BigWigs_BarEmphasized", hideBWBar);