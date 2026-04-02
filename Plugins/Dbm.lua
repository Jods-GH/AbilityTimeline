local appName, app = ...
---@class AbilityTimeline
local private = app

if not C_AddOns.IsAddOnLoaded("DBM-Core") then return end

private.DBMTimers = {}
private.DisableBlizzTimersDBM = false
private.ActiveBossModTimers = private.ActiveBossModTimers or {}
private.BossModsColors = private.BossModsColors or {}
local excludedTimers = {
    ["pull"] = true,
}
local function TimerStarted(event, timerId, timerMsg, timerDuration, timerIcon, timerType, timerSpellId, timerColordId, timerEncouterId, timerKeep, timerFade, timerSpellName, timerMobGUID, timerCount, timerIsPriority, timerType2, timerHasVariance, timerVariance)
    
    -- private.Debug("Dbm timer started")
    -- private.Debug(event)
    -- private.Debug(timerId)
    -- private.Debug(timerMsg)
    -- private.Debug(timerDuration)
    -- private.Debug(timerIcon)
    -- private.Debug(timerType)
    -- private.Debug(timerSpellId)
    -- private.Debug(timerColordId)
    -- private.Debug(timerEncouterId)
    -- private.Debug(timerKeep)
    -- private.Debug(timerFade)
    -- private.Debug(timerSpellName)
    -- private.Debug(timerMobGUID)
    -- private.Debug("==")
    -- private.Debug(excludedTimers[timerType])
    -- private.Debug(excludedTimers, "excluded timers")
    -- private.Debug("---")
    if excludedTimers[timerType] then 
        private.Debug("DBM Timer Ignored (Excluded Type): ".. timerId .. " Type: " .. timerType)
        return 
    end
    
    local spellInfo = nil
    if timerSpellId and type(timerSpellId) == "number" then
        spellInfo = C_Spell.GetSpellInfo(timerSpellId)
    end
    local spellName = nil
    if timerMsg and timerMsg ~= "" then
        spellName = timerMsg
    elseif spellInfo then
        spellName = spellInfo.name
    end
    local eventinfo = {
        duration = timerDuration,
        maxQueueDuration = timerKeep and 9999 or 0,
        severity = 1,
        paused = false,
        spellID = timerSpellId and type(timerSpellId) == "number" and timerSpellId or 1254530, -- 1254530 is a debug test icon
    }
    if spellName then
        eventinfo.overrideName = spellName
    end
    if timerIcon and type(timerIcon) == "number" then
        eventinfo.iconFileID = timerIcon
    elseif timerIcon and type(timerIcon) == "string" then
        eventinfo.iconFileID = tonumber(timerIcon)
    elseif spellInfo and spellInfo.iconID then
        eventinfo.iconFileID = spellInfo.iconID
    else
        eventinfo.iconFileID = 134400 -- 134400 is the ? icon
    end
    private.Debug("DBM Timer Started: " .. (spellName or timerId) .. " Duration: " .. timerDuration)
    if private.DBMTimers[timerId] and C_EncounterTimeline.GetEventInfo(private.DBMTimers[timerId].eventID) then
        C_EncounterTimeline.CancelScriptEvent(private.DBMTimers[timerId].eventID) -- Cancel the existing event to update it with new info
        private.DBMTimers[timerId] = nil
        private.ActiveBossModTimers[private.DBMTimers[timerId].eventID] = nil
    end
    local eventID = C_EncounterTimeline.AddScriptEvent(eventinfo)
    private.ActiveBossModTimers[eventID] = true
    private.DBMTimers[timerId] = {
        eventID = eventID,
        info = {
            timerId = timerId,
            timerMsg = timerMsg,
            timerDuration = timerDuration,
            timerType = timerType,
            timerSpellId = timerSpellId,
            timerColordId = timerColordId,
            timerEncouterId = timerEncouterId,
            timerKeep = timerKeep,
            timerFade = timerFade,
            timerSpellName = timerSpellName,
            timerMobGUID = timerMobGUID,
        }
    }

end

local function TimerBegin(event, timerId, timerMsg, timerDuration, timerIcon, timerType, timerSpellId, timerColordId, timerEncouterId, timerKeep, timerFade, timerSpellName, timerMobGUID, timerCount, timerIsPriority, timerType2, timerHasVariance, timerVariance, isEnabled)
    if not isEnabled then 
        private.Debug("DBM Timer Begin Ignored (Disabled): ".. timerId)
        return end
    TimerStarted(event, timerId, timerMsg, timerDuration, timerIcon, timerType, timerSpellId, timerColordId, timerEncouterId, timerKeep, timerFade, timerSpellName, timerMobGUID, timerCount, timerIsPriority, timerType2, timerHasVariance, timerVariance)
end

local function TimerStopped(event, timerId)
    private.Debug("DBM Timer Stopped: ".. timerId)
    if private.DBMTimers[timerId] and C_EncounterTimeline.GetEventInfo(private.DBMTimers[timerId].eventID) then
        C_EncounterTimeline.CancelScriptEvent(private.DBMTimers[timerId].eventID)
        private.ActiveBossModTimers[private.DBMTimers[timerId].eventID] = nil
        private.DBMTimers[timerId] = nil
    end
end

local function TimerUpdated(event, timerId, timerElapsed, timerModified)
    private.Debug("DBM Timer Updated: ".. event.."|"..timerId)
    if event =="DBM_TimerPause" then
        if private.DBMTimers[timerId] and C_EncounterTimeline.GetEventInfo(private.DBMTimers[timerId].eventID) then
            C_EncounterTimeline.PauseScriptEvent(private.DBMTimers[timerId].eventID)
        end
    elseif event =="DBM_TimerResume" then
        if private.DBMTimers[timerId] and C_EncounterTimeline.GetEventInfo(private.DBMTimers[timerId].eventID) then
            C_EncounterTimeline.ResumeScriptEvent(private.DBMTimers[timerId].eventID)
        end
    elseif private.DBMTimers[timerId] then
        if C_EncounterTimeline.GetEventInfo(private.DBMTimers[timerId].eventID) then
            C_EncounterTimeline.CancelScriptEvent(private.DBMTimers[timerId].eventID)
            private.ActiveBossModTimers[private.DBMTimers[timerId].eventID] = nil
        end
        local timerInfo = private.DBMTimers[timerId].info
        timerInfo.timerDuration = timerInfo.timerDuration + timerModified
        local eventinfo = {
            duration = timerInfo.timerDuration - timerElapsed,
            maxQueueDuration = timerInfo.timerKeep and timerInfo.timerDuration or 0,
            overrideName = timerInfo.timerMsg and timerInfo.timerMsg ~= "" and timerInfo.timerMsg or timerInfo.timerSpellName,
            spellID = timerInfo.timerSpellId,
            iconFileID = timerInfo.icon,
            severity = 1,
            paused = false,
            icons = {},
        }
        local eventID = C_EncounterTimeline.AddScriptEvent(eventinfo)
        private.DBMTimers[timerId] = {
            eventID = eventID,
            info = timerInfo
        }
    end
end

local function DisableBlizApi(event)
    private.DisableBlizzTimersDBM = true
end

local function EnableBlizApi(event)
    private.DisableBlizzTimersDBM = false
end

DBM:RegisterCallback("DBM_TimerStart", TimerStarted)
DBM:RegisterCallback("DBM_TimerStop", TimerStopped)
DBM:RegisterCallback("DBM_TimerBegin", TimerBegin)
DBM:RegisterCallback("DBM_TimerUpdate", TimerUpdated)
DBM:RegisterCallback("DBM_TimerPause", TimerUpdated)
DBM:RegisterCallback("DBM_TimerResume", TimerUpdated)
DBM:RegisterCallback("DBM_IgnoreBlizzAPI", DisableBlizApi)
DBM:RegisterCallback("DBM_ResumeBlizzAPI", EnableBlizApi)
