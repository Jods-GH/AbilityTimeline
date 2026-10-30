local appName, app = ...
---@class AbilityTimeline
local private = app

if not C_AddOns.IsAddOnLoaded("BigWigs") then return end

local SOURCE = private.manager.SOURCES.BigWigs

local excludedTimers = {
    ["Pull"] = true,
    ["Llamada de jefe"] = true, -- ES-Ex for Pull
    ["Ingaggio"] = true, -- IT-IT for Pull
    ["전투 예정"] = true, -- KO-KR for Pull
    ["Атака"] = true, -- RU-RU for Pull
    ["开怪倒数"] = true, -- CN-ZH for Pull
    ["開怪倒數"] = true, -- CN-ZH-TW for Pull
}

local function TimerStarted(event, module, timerKey, timerMsg, timerDuration, icon, timerIsApprox, timerMaxDuration, eventID, spellIndicators)
    private.Debug("!!!!!!!!!!!!!!!!!!!!!!!!")
    if eventID then
        if private.claimEncounterTimelineEvent then
            private.Debug("Bigwigs timer started for default event, adding to timeline".. eventID)
            private.claimEncounterTimelineEvent(eventID)
        end
        return
    end
    if excludedTimers[timerMsg] then return end
    if type(icon) == "string" then
        -- bigwigs uses filepaths for icons but the script event expects fileIDs, so we need to convert it 
        local iconpath = string.gsub(icon, "\\", "/")
        icon = GetFileIDFromPath(iconpath)
    end

    local eventinfo = {
        source = SOURCE,
        sourceID = timerMsg,
        duration = timerDuration,
        maxQueueDuration = 0,
        spellName = timerMsg,
        spellID = timerKey and type(timerKey) == "number" and timerKey or 58984,
        iconFileID = icon and type (icon) == "number" and icon or 134400,
        severity = 1,
        isApproximate = timerIsApprox,
        paused = false,
    }
    if spellIndicators then
        eventinfo.iconEventID = private.manager.getEventIDFromSource(private.manager.SOURCES.EncounterTimeline, spellIndicators)
    end
    private.Debug("BigWigs Timer Started: " .. timerMsg .. " Duration: " .. timerDuration)
    local color = BigWigs:GetPlugin("Colors"):GetColorTable("barText", module, timerKey)
    if color then
        local r,g,b,a = unpack(color)
        if r ~= 1 or g ~= 1 or b ~= 1 or a ~= 1 then
            eventinfo.textColor = CreateColor(r, g, b, a)
            private.Debug("Found color for bar text, saving to timer event")
            private.Debug("Color values - R: " .. r .. " G: " .. g .. " B: " .. b .. " A: " .. a)
        else
            private.Debug("Color for bar text is default, not saving to timer event")
        end
    else
        private.Debug("No color found for bar text or spell ID, not saving color for timer event")
    end
    local barColor = BigWigs:GetPlugin("Colors"):GetColorTable("barBackground", module, timerKey)
    if barColor then
        local r,g,b,a = unpack(barColor)
        if r ~= 1 or g ~= 1 or b ~= 1 or a ~= 1 then
            eventinfo.borderColor = CreateColor(r, g, b, a)
            private.Debug("Found color for bar background, saving border color for timer event")
        else
            private.Debug("Color for bar background is default, not saving border color for timer event")
        end
    else
        private.Debug("No color found for bar background, not adding border color for timer event")
    end
    private.manager.addEvent(eventinfo)
end

local function TimerStopped(event, module, text)
    local eventID = private.manager.getEventIDFromSource(SOURCE, text)
    if eventID then
        private.manager.removeEvent(eventID)
    end
end

local function TimerUpdated(event, module, text)
    local eventID = private.manager.getEventIDFromSource(SOURCE, text)
    if not eventID then return end
    if event =="BigWigs_PauseBar" then
        private.manager.pauseEvent(eventID)
    elseif event =="BigWigs_ResumeBar" then
        private.manager.resumeEvent(eventID)
    end
end

local function StopAllTimers()
    private.Debug("BigWigs Stop All Timers")
    private.manager.removeAllEvents(SOURCE)
end

local BWCallbackObj = {}
BigWigsLoader.RegisterMessage(BWCallbackObj, "BigWigs_StartBar", TimerStarted);
BigWigsLoader.RegisterMessage(BWCallbackObj, "BigWigs_StopBar", TimerStopped);
BigWigsLoader.RegisterMessage(BWCallbackObj, "BigWigs_PauseBar", TimerUpdated);
BigWigsLoader.RegisterMessage(BWCallbackObj, "BigWigs_ResumeBar", TimerUpdated);
BigWigsLoader.RegisterMessage(BWCallbackObj, "BigWigs_StopBars", StopAllTimers);
BigWigsLoader.RegisterMessage(BWCallbackObj, "BigWigs_OnBossDisable", StopAllTimers);
BigWigsLoader.RegisterMessage(BWCallbackObj, "BigWigs_OnPluginDisable", StopAllTimers);

local function hideBWBar(_, _, bar)
    if private.db.profile.disableBossModsBars then
        bar:SetAlpha(0)
    else
        bar:SetAlpha(1)
    end
end

local function hideBWEmphasizedBar(_, _, bar)
    if private.db.profile.disableBossModsEmphasisedBars then
        bar:SetAlpha(0)
    else
        bar:SetAlpha(1)
    end
end

BigWigsLoader.RegisterMessage(BWCallbackObj, "BigWigs_BarCreated", hideBWBar);
BigWigsLoader.RegisterMessage(BWCallbackObj, "BigWigs_BarEmphasized", hideBWEmphasizedBar);


local function DisableBlizApi(event)
    private.Debug("BigWigs Disable Blizzard Timers")
    private.DisableBlizzTimersBW= true
    if private.refreshEncounterTimelineVisibility then
        private.refreshEncounterTimelineVisibility()
    end
end

local function EnableBlizApi(event)
    private.Debug("BigWigs Enable Blizzard Timers")
    private.DisableBlizzTimersBW = false
    if private.refreshEncounterTimelineVisibility then
        private.refreshEncounterTimelineVisibility()
    end
end

BigWigsLoader.RegisterMessage(BWCallbackObj, "BigWigs_HideBlizzTimers", DisableBlizApi);
BigWigsLoader.RegisterMessage(BWCallbackObj, "BigWigs_ShowBlizzTimers", EnableBlizApi);