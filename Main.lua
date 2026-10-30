local appName, app = ...
---@class AbilityTimeline
local private = app
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceDBOptions = LibStub("AceDBOptions-3.0")
local CustomNames = C_AddOns.IsAddOnLoaded("CustomNames") and LibStub("CustomNames")
local issecretvalue = issecretvalue or function() return false end
local InChatMessagingLockdown = C_ChatInfo.InChatMessagingLockdown or function() return false end
---@class MyAddon : AceAddon-3.0, AceConsole-3.0, AceConfig-3.0, AceGUI-3.0, AceConfigDialog-3.0
local AbilityTimeline = LibStub("AceAddon-3.0"):NewAddon("AbilityTimeline", "AceConsole-3.0", "AceEvent-3.0")

function AbilityTimeline:OnInitialize()
    local buildVersion, buildNumber, buildDate, interfaceVersion, localizedVersion, buildInfo = GetBuildInfo() -- Mainline
    assert(not private.isRetail or interfaceVersion >= 120000, private.getLocalisation("WrongWoWVersionMessage"))
    -- Called when the addon is loaded
    AbilityTimeline:RegisterEvent("ENCOUNTER_START")
    AbilityTimeline:RegisterEvent("ENCOUNTER_END")
    AbilityTimeline:RegisterEvent("PLAYER_ENTERING_WORLD")
    AbilityTimeline:RegisterEvent("READY_CHECK")
    AbilityTimeline:RegisterEvent("READY_CHECK_FINISHED")
    AbilityTimeline:RegisterEvent("START_PLAYER_COUNTDOWN")
    AbilityTimeline:RegisterEvent("CANCEL_PLAYER_COUNTDOWN")
    AbilityTimeline:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    if private.isRetail then
        AbilityTimeline:RegisterEvent("CHALLENGE_MODE_COMPLETED")
        AbilityTimeline:RegisterEvent("CHALLENGE_MODE_RESET")
        AbilityTimeline:RegisterEvent("CHALLENGE_MODE_START")
    end
    private.db = LibStub("AceDB-3.0"):New("AbilityTimeline", private.OptionDefaults, true) -- Generates Saved Variables with default Values (if they don't already exist)
    private.Debug(private, "AT_Options")
    local OptionTable = {
        type = "group",
        args = {
            profile = AceDBOptions:GetOptionsTable(private.db),
            rest = private.options
        }
    }
    if not private.db.profile.disableLoginMessage then
        AbilityTimeline:Print(private.getLocalisation("AccessOptionsMessage"))
        if not private.isRetail and not C_AddOns.IsAddOnLoaded("DBM-Core") and not C_AddOns.IsAddOnLoaded("BigWigs") then
            AbilityTimeline:Print(private.getLocalisation("NoBossModClassicMessage"))
        end
    end
    AceConfig:RegisterOptionsTable(appName, OptionTable) --
    AceConfigDialog:AddToBlizOptions(appName, appName)
    self:RegisterChatCommand("at", "SlashCommand")
    self:RegisterChatCommand("AT", "SlashCommand")
    self:RegisterChatCommand("pull", "PullCommand")
    if not private.TIMELINE_FRAME then
        private.createTimelineFrame()
    end
    if private.initEncounterTimelineSource then
        private.initEncounterTimelineSource()
    end
    -- SetCVar("encounterWarningsEnabled", "1")

    --init
    private.ToggleEventColorisation(private.db.profile.dispellTextColor)
    if private.initDbmSkin then
        private.initDbmSkin()
    end
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

-- different icons so merged test events can be told apart
local TEST_ICONS = { 135127, 136197, 135808, 132090, 136116, 237538 }
local testEventIDs = {}

local function createTestBars(duration)
    local spellId = 376864
    local index = #testEventIDs + 1

    local eventinfo = {
        source = private.manager.SOURCES.Addon,
        duration = duration,
        maxQueueDuration = duration + 5,
        spellName = "Test Spell " .. index,
        spellID = spellId,
        iconFileID = TEST_ICONS[(index - 1) % #TEST_ICONS + 1],
        severity = 1,
        paused = false

    }


    local eventId = private.manager.addEvent(eventinfo)
    table.insert(testEventIDs, eventId)
    private.Debug("Creating test bar with duration: " .. duration .. " seconds")
    return eventId
end

---creates all test events in the same frame, so equal durations end at exactly the same time
---@param durations number[]
local function createTestBarList(durations)
    local eventIDs = {}
    for _, duration in ipairs(durations) do
        table.insert(eventIDs, createTestBars(duration))
    end
    return eventIDs
end

-- predefined sets of test events for the timeline layout
local TEST_SCENARIOS = {
    -- three identical timers and one inside the default merge window
    merge = { durations = { 12, 12, 12, 12.1 } },
    -- timers close enough to overlap but too far apart to merge
    overlap = { durations = { 12, 12.4, 12.8, 13.2, 13.6 } },
    -- merged and pushed icons together with waiting icons
    mixed = { durations = { 11, 11, 11.5, 12, 16, 16, 25 } },
    -- many icons reaching 0 at once for the queued group and its limit
    queue = { durations = { 3, 3, 3, 3.5, 4, 4, 4.5, 5 } },
    -- some timers get paused shortly after starting
    pause = { durations = { 8, 14, 20, 30 }, pause = { 2, 3 }, pauseDelay = 1.5 },
    -- a lot of random timers
    stress = { random = 20, min = 4, max = 40 },
}

local function printTestUsage()
    AbilityTimeline:Print("/at test <seconds> [<seconds> ...] - starts one test timer per duration at the same time, e.g. /at test 12 12 12.1")
    local names = {}
    for name in pairs(TEST_SCENARIOS) do
        table.insert(names, name)
    end
    table.sort(names)
    AbilityTimeline:Print("/at test <scenario> - starts a predefined set: " .. table.concat(names, ", "))
    AbilityTimeline:Print("/at test pause | resume | clear - pauses, resumes or removes all test timers")
end

---handles everything after "/at test "
---@param args string
local function handleTestCommand(args)
    local command = args:match("^(%a+)")
    if command == "help" then
        printTestUsage()
    elseif command == "clear" then
        for _, eventID in ipairs(testEventIDs) do
            private.manager.removeEvent(eventID)
        end
        wipe(testEventIDs)
    elseif command == "pause" or command == "resume" then
        for _, eventID in ipairs(testEventIDs) do
            if command == "pause" then
                private.manager.pauseEvent(eventID)
            else
                private.manager.resumeEvent(eventID)
            end
        end
    elseif command and TEST_SCENARIOS[command] then
        local scenario = TEST_SCENARIOS[command]
        local durations = scenario.durations
        if scenario.random then
            durations = {}
            for i = 1, scenario.random do
                durations[i] = scenario.min + math.random() * (scenario.max - scenario.min)
            end
        end
        local eventIDs = createTestBarList(durations)
        if scenario.pause then
            C_Timer.After(scenario.pauseDelay, function()
                for _, index in ipairs(scenario.pause) do
                    private.manager.pauseEvent(eventIDs[index])
                end
            end)
        end
    elseif command then
        printTestUsage()
    else
        local durations = {}
        for value in args:gmatch("%S+") do
            local duration = tonumber(value)
            if duration and duration > 0 then
                table.insert(durations, duration)
            end
        end
        if #durations > 0 then
            createTestBarList(durations)
        else
            printTestUsage()
        end
    end
end


function AbilityTimeline:SlashCommand(msg) -- called when slash command is used
    if private.isRetail and not C_EncounterTimeline.IsFeatureEnabled() then
        AbilityTimeline:Print(private.getLocalisation("TimelineNotEnabledMessage"))
    elseif private.isRetail and not C_EncounterTimeline.IsFeatureAvailable() then
        AbilityTimeline:Print(private.getLocalisation("TimelineNotSupportedMessage"))
    elseif msg == "iconeditor" then
        private.openSpellIconSettings()
    elseif msg == "version" then
        AbilityTimeline:Print("Ability Timeline Version: " ..  C_AddOns.GetAddOnMetadata(appName, "Version"))
    elseif msg == "test" and private.isRetail then
        C_EncounterTimeline.AddEditModeEvents()
    elseif msg == "test" then
        private.addTestEvents()
    elseif string.find(string.lower(msg), "^test ") then
        handleTestCommand(string.lower(msg):sub(6))
    elseif string.find(string.lower(msg), "rect") then
        private.Debug(private.TIMELINE_FRAME.frame:GetBoundsRect())
    elseif msg == "eventlist" then
        private.Debug(private.manager.getEventList(), "EventList")
    elseif msg == "debugevents" then
        private.manager.printDebugInfo()
    elseif msg == "debugtimeline" and private.toggleEncounterTimelineDebug then
        private.toggleEncounterTimelineDebug()
    elseif string.find(string.lower(msg), "pause (.-)") then
        local eventID = tonumber(string.match(string.lower(msg), "pause (%d+)"))
        if eventID then
            private.manager.pauseEvent(eventID)
            private.Debug(private.manager.getEventInfo(eventID), "EventInfo")
        end
    elseif string.find(string.lower(msg), "resume (.-)") then
        local eventID = tonumber(string.match(string.lower(msg), "resume (%d+)"))
        if eventID then
            private.manager.resumeEvent(eventID)
        end
    else
        AceConfigDialog:Open(appName)
    end
end

function AbilityTimeline:PLAYER_ENTERING_WORLD()
    if not C_AddOns.IsAddOnLoaded("Blizzard_EncounterJournal") then
        C_AddOns.LoadAddOn("Blizzard_EncounterJournal")
        if private.isRetail then
            C_Timer.After(5, function()
                private.buildInstanceOptions()
            end)
        end
    elseif private.isRetail then
        private.buildInstanceOptions()
    end
end

function AbilityTimeline:ENCOUNTER_START(event, encounterID, encounterName, difficultyID, groupSize, playerDifficultyID)
    -- createTestBars(15)
    private.Debug("Encounter started: " .. tostring(encounterName) .. " " .. tostring(encounterID))
    -- store last encounter info
    private.lastEncounterInfo = {
        encounterID = encounterID,
        encounterName = encounterName,
    }

    if private.db.profile.debugMode and encounterID == 3463 then
        encounterID = 1701
    end
    if not InChatMessagingLockdown() and private.db.profile.enableDNDMessage then
        local name, groupType, isHeroic, isChallengeMode, displayHeroic, displayMythic, toggleDifficultyID, isLFR, minPlayers, maxPlayers =
        GetDifficultyInfo(difficultyID)
        private.db.global.active = true
        C_ChatInfo.SendChatMessage(private.getLocalisation("CurrentlyBusyInEncounter"):format(encounterName, name), "DND")
    end

    private.createReminders(encounterID)
end

function AbilityTimeline:ENCOUNTER_END(event, encounterID, encounterName, difficultyID, groupSize, playerDifficultyID,
                                       success)
    private.Debug("Encounter ended: " ..
    tostring(encounterName) .. " " .. tostring(encounterID) .. ", success: " .. tostring(success))

    private.cancelSheduledReminders()
    if private.db.profile.disableAllOnEncounterEnd then
        private.manager.removeAllEvents(private.manager.SOURCES.Reminder)
    end
    C_Timer.After(1, function() -- since for some reason encounter end fires before combat lockdown is over we delay
        if not InChatMessagingLockdown() and private.db.profile.enableDNDMessage then
            if private.db.global.active then
                C_ChatInfo.SendChatMessage("", "DND") -- clear dnd message
                private.db.global.active = false
            end
        end
    end
    )
end

function AbilityTimeline:READY_CHECK(event, initiator, readyCheckTimeLeft)
    if private.db.profile.disableReadyCheck then
        private.Debug("Ready check detected but reminders on ready check are disabled, not showing reminder.")
        return
    end
    local timeleft = tonumber(readyCheckTimeLeft) or 35
    local _, classFilename, _ = UnitClass(initiator)
    local _, _, _, argbHex = GetClassColor(classFilename)
    local initiatorName
    if CustomNames and not issecretvalue(initiator) then
        initiatorName = CustomNames.Get(initiator)
    else
        initiatorName = initiator
    end
    local overrideName = private.getLocalisation("ReadyCheck")
    if issecretvalue(initiatorName) or initiatorName then
        overrideName = private.getLocalisation("ReadyCheckBy") .. " " .. WrapTextInColorCode(initiatorName, argbHex)
    end
    local eventinfo = {
        source = private.manager.SOURCES.Addon,
        sourceID = "readycheck",
        duration = timeleft,
        maxQueueDuration = 0,
        spellName = overrideName,
        spellID = 0,
        iconFileID = 134400,
        severity = 1,
        paused = false

    }
    private.Debug("Ready check started by " ..
    WrapTextInColorCode(initiatorName, argbHex) .. ", time left: " .. tostring(readyCheckTimeLeft) .. " seconds.")
    private.ReadyCheckEventId = private.manager.addEvent(eventinfo)
end

function AbilityTimeline:READY_CHECK_FINISHED()
    if private.ReadyCheckEventId then
        private.manager.removeEvent(private.ReadyCheckEventId)
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
    local timeleft = tonumber(timeRemaining)
    local color
    local name = initiatedByName
    if issecretvalue(timeleft) or InCombatLockdown() then
        private.Debug("Received START_PLAYER_COUNTDOWN event while in combat or secret value for time left. Ignoring event.")
        return
    end
    if not issecretvalue(initiatedByName) and initiatedByName and UnitClass(initiatedByName) then
        local _, classFilename, _ = UnitClass(initiatedByName)
        local _, _, _, argbHex = GetClassColor(classFilename)
        color = argbHex
    else
        color = 'ffffffff'
    end

    if not issecretvalue(initiatedByName) and initiatedByName and CustomNames then
        name = CustomNames.Get(initiatedByName)
    end

    local overrideName = private.getLocalisation("PullTimer")

    if not issecretvalue(name) and name then
        overrideName = private.getLocalisation("PullTimerBy") .. " " .. WrapTextInColorCode(name, color)
    end

    local eventinfo = {
        source = private.manager.SOURCES.Addon,
        sourceID = "pull",
        duration = timeleft,
        maxQueueDuration = 0,
        spellName = overrideName,
        spellID = 0,
        iconFileID = 134376,
        severity = 1,
        paused = false

    }
    private.Debug("Pull timer started by " ..
    WrapTextInColorCode(name, color) .. ", time left: " .. tostring(timeRemaining) .. " seconds.")
    private.PullTimerEventId = private.manager.addEvent(eventinfo)
end

function AbilityTimeline:CANCEL_PLAYER_COUNTDOWN()
    if private.PullTimerEventId then
        private.manager.removeEvent(private.PullTimerEventId)
        private.PullTimerEventId = nil
    end
end

function AbilityTimeline:CHALLENGE_MODE_RESET(event, mapID)
    if not InChatMessagingLockdown() and private.db.profile.enableDNDMessage and private.db.global.active then
        C_ChatInfo.SendChatMessage(private.getLocalisation("CurrentlyDoingMplusKeyFallback"), "DND")
        private.db.global.active = false
    end
end

function AbilityTimeline:CHALLENGE_MODE_START()
    if not InChatMessagingLockdown() and private.db.profile.enableDNDMessage then
        local message = private.getLocalisation("CurrentlyDoingMplusKeyFallback")
        local activeKeystoneLevel, activeAffixIDs, wasActiveKeystoneCharged = C_ChallengeMode.GetActiveKeystoneInfo()
        local challengeMapID = C_ChallengeMode.GetActiveChallengeMapID()
        if challengeMapID then
            local name, id, timeLimit, texture, backgroundTexture, mapID = C_ChallengeMode.GetMapUIInfo(challengeMapID)
            if name and timeLimit then
                local calenderTime = C_DateAndTime.GetCurrentCalendarTime()
                local adjustedTime = C_DateAndTime.AdjustTimeByMinutes(calenderTime, timeLimit / 60)
                local timeToDisplay = adjustedTime.hour .. ":" .. (adjustedTime.minute)
                message = private.getLocalisation("CurrentlyDoingMplusKey"):format(activeKeystoneLevel, name,
                    timeToDisplay)
            end
        end
        C_ChatInfo.SendChatMessage(message, "DND")
        private.db.global.active = true
    end
end

function AbilityTimeline:CHALLENGE_MODE_COMPLETED()
    if private.db.profile.enableKeyRerollTimer then
        local info = C_ChallengeMode.GetChallengeCompletionInfo()
        if not info or not info.onTime then
            private.Debug("Challenge mode completed but not on time. Not adding timer.")
            return
        end
        local eventinfo = {
            source = private.manager.SOURCES.Addon,
            sourceID = "reroll",
            duration = 300,
            maxQueueDuration = 0,
            spellName = private.getLocalisation("RerollKey"),
            spellID = 0,
            iconFileID = 525134,
            severity = 1,
            paused = false

        }
        private.Debug("Challenge mode completed Adding timer for key reroll: 5 minutes.")
        private.RerollKeyEventId = private.manager.addEvent(eventinfo)
    end
    if private.db.profile.enableDNDMessage and private.db.global.active then
        C_ChatInfo.SendChatMessage("", "DND")
        private.db.global.active = false
    end
end

-- TODO cancel the event if the player actually rerolls the key before the timer ends
function AbilityTimeline:ZONE_CHANGED_NEW_AREA()
    if private.RerollKeyEventId then
        private.manager.removeEvent(private.RerollKeyEventId)
        private.RerollKeyEventId = nil
    end
    if private.db.profile.enableDNDMessage and private.db.global.active and not InChatMessagingLockdown() then
        C_ChatInfo.SendChatMessage("", "DND")
        private.db.global.active = false
    end
end
