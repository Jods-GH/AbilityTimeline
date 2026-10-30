local appName, app = ...
---@class AbilityTimeline
local private = app

if not C_AddOns.IsAddOnLoaded("DBM-Core") then return end

local SOURCE = private.manager.SOURCES.DBM
local timerInfos = {}
private.DisableBlizzTimersDBM = false
local excludedTimers = {
    ["pull"] = true,
}
local function TimerStarted(event, timerId, timerMsg, timerDuration, timerIcon, timerType, timerSpellId, timerColordId, timerEncouterId, timerKeep, timerFade, timerSpellName, timerMobGUID, timerCount, timerIsPriority, timerType2, timerHasVariance, timerVariance)
    
    private.Debug("Dbm timer started")
    private.Debug(event)
    private.Debug(timerId)
    private.Debug(timerMsg)
    private.Debug(timerDuration)
    private.Debug(timerIcon)
    private.Debug(timerType)
    private.Debug(timerSpellId)
    private.Debug(timerColordId)
    private.Debug(timerEncouterId)
    private.Debug(timerKeep)
    private.Debug(timerFade)
    private.Debug(timerSpellName)
    private.Debug(timerMobGUID)
    private.Debug("==")
    private.Debug(excludedTimers[timerType])
    private.Debug(excludedTimers, "excluded timers")
    private.Debug("---")
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
        source = SOURCE,
        sourceID = timerId,
        duration = timerDuration,
        maxQueueDuration = timerKeep and 9999 or 0,
        severity = 1,
        paused = false,
        spellID = timerSpellId and type(timerSpellId) == "number" and timerSpellId or 1254530, -- 1254530 is a debug test icon
    }
    if spellName then
        eventinfo.spellName = spellName
    end
    if timerIcon and type(timerIcon) == "number" then
        eventinfo.iconFileID = timerIcon
    elseif timerIcon and type(timerIcon) == "string" then
        if string.find(timerIcon, "\\") then
            local iconpath = string.gsub(timerIcon, "\\", "/")
            local icon = GetFileIDFromPath(iconpath)
            if icon then
                eventinfo.iconFileID = icon
            else
                eventinfo.iconFileID = 134400 -- 134400 is the ? icon
            end
        elseif string.find(timerIcon, "/") then
            local icon = GetFileIDFromPath(iconpath)
            if icon then
                eventinfo.iconFileID = icon
            else
                eventinfo.iconFileID = 134400 -- 134400 is the ? icon
            end
        else
            eventinfo.iconFileID = tonumber(timerIcon)
        end
    elseif spellInfo and spellInfo.iconID then
        eventinfo.iconFileID = spellInfo.iconID
    else
        eventinfo.iconFileID = 134400 -- 134400 is the ? icon
    end
    private.Debug("DBM Timer Started: " .. (spellName or timerId) .. " Duration: " .. timerDuration)
    if timerColordId then
        local r, g, b = DBT:GetColorForType(timerColordId)
        if r and g and b then
            local color = CreateColor(r, g, b)
            eventinfo.textColor = color
            private.Debug("Found DBM Timer Color ID: " .. timerColordId .. " Color: " .. ("R:"..color.r.." G:"..color.g.." B:"..color.b))
        else
            private.Debug("No color found for DBM Timer Color ID: " .. timerColordId)
        end
    end
    private.manager.addEvent(eventinfo)
    timerInfos[timerId] = {
        eventinfo = eventinfo,
        timerDuration = timerDuration,
        timerKeep = timerKeep,
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
    local eventID = private.manager.getEventIDFromSource(SOURCE, timerId)
    if eventID then
        private.manager.removeEvent(eventID)
    end
    timerInfos[timerId] = nil
end

local function TimerUpdated(event, timerId, timerElapsed, timerModified)
    private.Debug("DBM Timer Updated: ".. event.."|"..timerId)
    local eventID = private.manager.getEventIDFromSource(SOURCE, timerId)
    if event =="DBM_TimerPause" then
        if eventID then
            private.manager.pauseEvent(eventID)
        end
    elseif event =="DBM_TimerResume" then
        if eventID then
            private.manager.resumeEvent(eventID)
        end
    elseif timerInfos[timerId] then
        local timerInfo = timerInfos[timerId]
        timerInfo.timerDuration = timerInfo.timerDuration + timerModified
        timerInfo.eventinfo.duration = timerInfo.timerDuration - timerElapsed
        timerInfo.eventinfo.maxQueueDuration = timerInfo.timerKeep and timerInfo.timerDuration or 0
        private.manager.addEvent(timerInfo.eventinfo)
    end
end

local function DisableBlizApi(event)
    if DBM.Options.HideDBMBars then
        private.Debug("DBM bars are hidden by settings, force enabling them")
        DBM.Options.HideDBMBars = false
    end
    private.DisableBlizzTimersDBM = true
    if private.refreshEncounterTimelineVisibility then
        private.refreshEncounterTimelineVisibility()
    end
end

local function EnableBlizApi(event)
    private.DisableBlizzTimersDBM = false
    if private.refreshEncounterTimelineVisibility then
        private.refreshEncounterTimelineVisibility()
    end
end

DBM:RegisterCallback("DBM_TimerStart", TimerStarted)
DBM:RegisterCallback("DBM_TimerStop", TimerStopped)
DBM:RegisterCallback("DBM_TimerBegin", TimerBegin)
DBM:RegisterCallback("DBM_TimerUpdate", TimerUpdated)
DBM:RegisterCallback("DBM_TimerPause", TimerUpdated)
DBM:RegisterCallback("DBM_TimerResume", TimerUpdated)
DBM:RegisterCallback("DBM_IgnoreBlizzAPI", DisableBlizApi)
DBM:RegisterCallback("DBM_ResumeBlizzAPI", EnableBlizApi)

private.initDbmSkin = function()
    if DBT and (private.db.profile.disableBossModsBars or private.db.profile.disableBossModsEmphasisedBars) then
        if not DBT:GetSkins().Better_Timeline_Skin then
            local skin = DBT:RegisterSkin("Better_Timeline_Skin")
            skin.Options = {
                HugeAlpha = private.db.profile.disableBossModsEmphasisedBars and 0.0001 or 1,
                Alpha = private.db.profile.disableBossModsBars and 0.0001 or 1,
                IconLeft = false,
                IconRight = false,
                InlineIcons = false,
                Bar7CustomInline = false,
                ClickThrough = true,
                DisableRightClick = true,
            }
        end
        if DBT:GetSkins().Better_Timeline_Skin then
            private.Debug("Applying Better Timeline Skin to DBM bars to settings")
            DBT:SetSkin("Better_Timeline_Skin")
            DBT:Rearrange()
        end
        if AddOnSkins and AddOnSkins[1]:CheckOption('DBM-Core') == true then
            assert(false, "Hiding DBM bars while AddonSkins skinning is turned on doesn't work pls either disable the DBM-Core option or the addon and try again")
        end
            
        
    elseif DBT and not (private.db.profile.disableBossModsBars or private.db.profile.disableBossModsEmphasisedBars) then
        if DBT:GetSkins().Better_Timeline_Skin then
            private.Debug("Reverting to default DBM skin as bars are enabled in settings")
            DBT:SetSkin("DBM")
        end
    end
end
