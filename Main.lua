local appName, private = ...
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceDBOptions = LibStub("AceDBOptions-3.0")
---@class MyAddon : AceAddon-3.0, AceConsole-3.0, AceConfig-3.0, AceGUI-3.0, AceConfigDialog-3.0
local AbilityTimeline = LibStub("AceAddon-3.0"):NewAddon("AbilityTimeline", "AceConsole-3.0", "AceEvent-3.0")

function AbilityTimeline:OnInitialize()
    -- Called when the addon is loaded
    AbilityTimeline:Print(private.getLocalisation("AccessOptionsMessage"))
    AbilityTimeline:RegisterEvent("ENCOUNTER_TIMELINE_EVENT_ADDED")
    AbilityTimeline:RegisterEvent("ENCOUNTER_TIMELINE_EVENT_REMOVED")
    AbilityTimeline:RegisterEvent("ENCOUNTER_TIMELINE_EVENT_STATE_CHANGED")
    AbilityTimeline:RegisterEvent("ENCOUNTER_START")
    AbilityTimeline:RegisterEvent("PLAYER_ENTERING_WORLD")
    private.db = LibStub("AceDB-3.0"):New("AbilityTimeline", private.OptionDefaults, true) -- Generates Saved Variables with default Values (if they don't already exist)
    DevTool:AddData(private, "AT_Options")
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
end

function AbilityTimeline:OnEnable()
    --Debug
    -- DevTool:AddData(RaiderIO.GetProfile("Lemikedh-ragnaros",1),"RioProfile")
end

function AbilityTimeline:OnDisable()
    -- Called when the addon is disabled
end

function AbilityTimeline_AddonCompartmentFunction()
    AbilityTimeline:SlashCommand("AddonCompartmentFrame")
end

local function createTestBars(duration)
    print("Creating test bar with duration: " .. duration .. " seconds")
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
    -- print("--")
    --print(eventId)
    --print(C_EncounterTimeline.AddEditModeEvents())
    --print(C_EncounterTimeline.IsTimelineEnabled())
    --print(C_EncounterTimeline.IsTimelineSupported())
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
    elseif msg == "editor" then
        private.openTimingsEditor(1203, 1)
    elseif msg == "eventlist" then
        DevTools_Dump(C_EncounterTimeline.GetEventList())
    elseif string.find(string.lower(msg), "pause (.-)") then
        local eventID = tonumber(string.match(string.lower(msg), "pause (%d+)"))
        if eventID then
            C_EncounterTimeline.PauseScriptEvent(eventID)
            DevTools_Dump(C_EncounterTimeline.GetEventInfo(eventID))
        end
    elseif string.find(string.lower(msg), "resume (.-)") then
        local eventID = tonumber(string.match(string.lower(msg), "resume (%d+)"))
        if eventID then
            C_EncounterTimeline.ResumeScriptEvent(eventID)
        end
    else
        AbilityTimeline:Print(private.getLocalisation("AccessOptionsMessage"))
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
    createTestBars(15)
    print("Encounter started: " .. encounterName)
end
