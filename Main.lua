local appName, private = ...
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceDBOptions = LibStub("AceDBOptions-3.0")
---@class MyAddon : AceAddon-3.0, AceConsole-3.0, AceConfig-3.0, AceGUI-3.0, AceConfigDialog-3.0
local AbilityTimeline = LibStub("AceAddon-3.0"):NewAddon("AbilityTimeline", "AceConsole-3.0", "AceEvent-3.0")

function AbilityTimeline:OnInitialize()
    local buildVersion, buildNumber, buildDate, interfaceVersion, localizedVersion, buildInfo = GetBuildInfo()  -- Mainline
    assert(interfaceVersion >= 120000, private.getLocalisation("WrongWoWVersionMessage"))
    -- Called when the addon is loaded
    AbilityTimeline:Print(private.getLocalisation("AccessOptionsMessage"))
    AbilityTimeline:RegisterEvent("ENCOUNTER_TIMELINE_EVENT_ADDED")
    AbilityTimeline:RegisterEvent("ENCOUNTER_TIMELINE_EVENT_REMOVED")
    AbilityTimeline:RegisterEvent("ENCOUNTER_TIMELINE_EVENT_STATE_CHANGED")
    AbilityTimeline:RegisterEvent("ENCOUNTER_START")
    AbilityTimeline:RegisterEvent("PLAYER_ENTERING_WORLD")
    AbilityTimeline:RegisterEvent("READY_CHECK")
    AbilityTimeline:RegisterEvent("READY_CHECK_FINISHED")
    AbilityTimeline:RegisterEvent("START_PLAYER_COUNTDOWN")
    AbilityTimeline:RegisterEvent("CANCEL_PLAYER_COUNTDOWN")
    AbilityTimeline:RegisterEvent("CHALLENGE_MODE_COMPLETED")
    AbilityTimeline:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    private.db = LibStub("AceDB-3.0"):New("AbilityTimeline", private.OptionDefaults, true) -- Generates Saved Variables with default Values (if they don't already exist)
    private.Debug(private, "AT_Options")
    local OptionTable = {
        type = "group",
        args = {
            profile = AceDBOptions:GetOptionsTable(private.db),
            rest = private.options
        }
    }
    AceConfig:RegisterOptionsTable(appName, OptionTable) --
    AceConfigDialog:AddToBlizOptions(appName, appName)
    self:RegisterChatCommand("at", "SlashCommand")
    self:RegisterChatCommand("AT", "SlashCommand")
    self:RegisterChatCommand("pull", "PullCommand")
    if not private.TIMELINE_FRAME then
      private.createTimelineFrame()
    end
    SetCVar("encounterTimelineEnabled", "1")
    EncounterTimeline.View:UnregisterAllEvents()
    EncounterTimeline.View:Hide()
    -- SetCVar("encounterWarningsEnabled", "1")
end

function AbilityTimeline:OnEnable()
    -- Called when the addon is enabled
end

function AbilityTimeline:OnDisable()
    -- Called when the addon is disabled
end

function AbilityTimeline_AddonCompartmentFunction()
    AbilityTimeline:SlashCommand("AddonCompartmentFrame")
end

local function createTestBars(duration)
    local spellId = 376864
    local iconId = 135127

    local eventinfo = {
        duration = duration,
        maxQueueDuration = duration + 5,
        overrideName = "Test Spell",
        spellID = spellId,
        iconFileID = iconId,
        severity = 1,
        paused = false

    }


    local eventId = C_EncounterTimeline.AddScriptEvent(eventinfo)
    private.Debug("Creating test bar with duration: " .. duration .. " seconds")
end


function AbilityTimeline:SlashCommand(msg) -- called when slash command is used
    if not C_EncounterTimeline.IsFeatureEnabled() then
        AbilityTimeline:Print(private.getLocalisation("TimelineNotEnabledMessage"))
    elseif not C_EncounterTimeline.IsFeatureAvailable() then
        AbilityTimeline:Print(private.getLocalisation("TimelineNotSupportedMessage"))
    elseif msg == "test" then
        C_EncounterTimeline.AddEditModeEvents()
    elseif string.find(string.lower(msg), "test (.-)") then
        local duration = tonumber(string.match(string.lower(msg), "test (%d+)"))
        if duration then
            createTestBars(duration)
        end
    elseif string.find(string.lower(msg), "rect") then
        private.Debug(private.TIMELINE_FRAME.frame:GetBoundsRect())
    elseif msg == "editor" then
        private.openTimingsEditor(1203, 1)
    elseif msg == "eventlist" then
       private.Debug(C_EncounterTimeline.GetEventList(), "EventList")
    elseif string.find(string.lower(msg), "pause (.-)") then
        local eventID = tonumber(string.match(string.lower(msg), "pause (%d+)"))
        if eventID then
            C_EncounterTimeline.PauseScriptEvent(eventID)
            private.Debug(C_EncounterTimeline.GetEventInfo(eventID), "EventInfo")
        end
    elseif string.find(string.lower(msg), "resume (.-)") then
        local eventID = tonumber(string.match(string.lower(msg), "resume (%d+)"))
        if eventID then
            C_EncounterTimeline.ResumeScriptEvent(eventID)
        end
    else
        AceConfigDialog:Open(appName)
    end
end

function AbilityTimeline:ENCOUNTER_TIMELINE_EVENT_ADDED(event, eventInfo, initialState)
    private.ENCOUNTER_TIMELINE_EVENT_ADDED(self, eventInfo, initialState)
end

function AbilityTimeline:ENCOUNTER_TIMELINE_EVENT_REMOVED(event, eventInfo, initialState)
    private.ENCOUNTER_TIMELINE_EVENT_REMOVED(self, eventInfo, initialState)
end

function AbilityTimeline:ENCOUNTER_TIMELINE_EVENT_STATE_CHANGED(event, eventID, newState)
    private.ENCOUNTER_TIMELINE_EVENT_STATE_CHANGED(self, eventID, newState)
end

function AbilityTimeline:PLAYER_ENTERING_WORLD()
    private.buildInstanceOptions()
end

function AbilityTimeline:ENCOUNTER_START(event, encounterID, encounterName, difficultyID, groupSize, playerDifficultyID)
    -- createTestBars(15)
    private.Debug("Encounter started: " .. encounterName)
end

function AbilityTimeline:READY_CHECK(event, initiatorName, readyCheckTimeLeft)
    local timeleft = tonumber(readyCheckTimeLeft) or 35
    local _, classFilename, _ = UnitClass(initiatorName)
    local _, _, _, argbHex = GetClassColor(classFilename)
    local eventinfo = {
        duration = timeleft,
        maxQueueDuration = 0,
        overrideName = private.getLocalisation("ReadyCheckBy") .. " " .. WrapTextInColorCode(initiatorName, argbHex),
        spellID = 0,
        iconFileID = 134400,
        severity = 1,
        paused = false

    }
    private.Debug("Ready check started by " .. WrapTextInColorCode(initiatorName, argbHex) .. ", time left: " .. tostring(readyCheckTimeLeft) .. " seconds.")
    private.ReadyCheckEventId = C_EncounterTimeline.AddScriptEvent(eventinfo)
end

function AbilityTimeline:READY_CHECK_FINISHED()
    if private.ReadyCheckEventId then
        C_EncounterTimeline.CancelScriptEvent(private.ReadyCheckEventId)
        private.ReadyCheckEventId = nil
    end
end

function AbilityTimeline:PullCommand(msg)
    if msg and msg:lower():trim() == "cancel" then
        C_PartyInfo.DoCountdown(0)
        return 
    end
    local inInstance, instanceType = IsInInstance()
    local smartSeconds = 10
    if inInstance then
        if instanceType == "raid" then
            smartSeconds = 10
        elseif instanceType == "party" then
            smartSeconds = 3
        end
    end
    local seconds = tonumber(msg) or smartSeconds
    C_PartyInfo.DoCountdown(seconds)
end

function AbilityTimeline:START_PLAYER_COUNTDOWN(event, initiatedBy, timeRemaining, totalTime, informChat, initiatedByName)
    local timeleft = tonumber(timeRemaining) or 35
    local color
    if initiatedByName and UnitClass(initiatedByName) then
        local _, classFilename, _ = UnitClass(initiatedByName)
        local _, _, _, argbHex = GetClassColor(classFilename)
        color = argbHex
    else 
        color = 'ffffffff'
    end
    local eventinfo = {
        duration = timeleft,
        maxQueueDuration = 0,
        overrideName = private.getLocalisation("PullTimerBy") .. " " .. WrapTextInColorCode(initiatedByName, color),
        spellID = 0,
        iconFileID = 134376,
        severity = 1,
        paused = false

    }
    private.Debug("Pull timer started by " .. WrapTextInColorCode(initiatedByName, color) .. ", time left: " .. tostring(timeRemaining) .. " seconds.")
    private.PullTimerEventId = C_EncounterTimeline.AddScriptEvent(eventinfo)
end

function AbilityTimeline:CANCEL_PLAYER_COUNTDOWN()
    if private.PullTimerEventId then
        C_EncounterTimeline.CancelScriptEvent(private.PullTimerEventId)
        private.PullTimerEventId = nil
    end
end

-- TODO only add the timer if the key was upgraded succesfully
function AbilityTimeline:CHALLENGE_MODE_COMPLETED()
    if private.db.profile.enableKeyRerollTimer then
        local eventinfo = {
            duration = 300,
            maxQueueDuration = 0,
            overrideName = private.getLocalisation("RerollKey"),
            spellID = 0,
            iconFileID = 134376,
            severity = 1,
            paused = false

        }
        private.RerollKeyEventId = C_EncounterTimeline.AddScriptEvent(eventinfo)
    end
end
-- TODO cancel the event if the player actually rerolls the key before the timer ends
function AbilityTimeline:ZONE_CHANGED_NEW_AREA()
    if private.RerollKeyEventId then
        C_EncounterTimeline.CancelScriptEvent(private.RerollKeyEventId)
        private.RerollKeyEventId = nil
    end
end