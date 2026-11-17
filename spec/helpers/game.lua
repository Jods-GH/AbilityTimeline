-- game.lua: the state of the game the world's API answers from (world.game), and the behaviour of the functions the
-- addon depends on. Every behaviour is set through world.api.set, so it only exists where the client's documentation
-- (or legacy_api.lua) says the function exists; a behaviour for a function a client lacks is skipped. Returns follow
-- each function's documentation (or its warcraft.wiki.gg page for legacy functions).
local M = {}

function M.Install(world)
    local game = {
        locale = "enUS",
        player = { name = "Player", realm = "Realm", class = "MAGE", className = "Mage", classID = 8, specIndex = 1, specID = 63 },
        units = {},          -- unit token -> { name, realm, class, className, classID, leader, assistant }
        group = nil,         -- nil, or { raid = bool, instance = bool, members = { unit tokens } }
        instance = { inInstance = false, type = "none" },
        encounter = nil,     -- the encounter in progress
        inCombat = false,
        -- the client's CVar defaults (client_dump.lua); without a dump, CVar_loadDeprecationFallbacks' release default
        cvars = {},
        loggedIn = false,
        region = "US",
        addons = { AbilityTimeline = { loaded = true, version = "@project-version@" } },
        spells = {},         -- spellID -> { name, iconID }
        atlases = {},        -- atlas name -> AtlasInfo
        journal = { encounters = {}, instances = {} },
        gameTime = { hour = 12, minute = 0 },
        modifiers = {},      -- "SHIFT"/"CTRL" -> down
        sounds = {},         -- PlaySoundFile calls
        speech = {},         -- C_VoiceChat.SpeakText calls
        addonMessages = {},  -- C_ChatInfo.SendAddonMessage calls
        chatMessages = {},   -- C_ChatInfo.SendChatMessage calls
        prefixes = {},
        countdowns = {},
        build = { version = "", number = "", date = "", interface = 0 },
    }
    world.game = game
    if world.dump.runtime then
        for name, value in pairs(world.dump.cvars) do game.cvars[name] = value end
        -- AtlasInfo.lua: width, height, left, right, top, bottom, tilesHorizontally, tilesVertically
        setmetatable(game.atlases, { __index = function(_, atlas)
            local info = world.dump.atlases[atlas]
            if not info then return nil end
            return { width = info[1], height = info[2], leftTexCoord = info[3], rightTexCoord = info[4],
                topTexCoord = info[5], bottomTexCoord = info[6], tilesHorizontally = info[7], tilesVertically = info[8], file = 0 }
        end })
    else
        game.cvars.loadDeprecationFallbacks = "1"
    end

    local function set(name, implementation)
        if world.api.has(name) then world.api.set(name, implementation) end
    end

    local function unit(token)
        if token == "player" then return game.player end
        return game.units[token] or (game.units[token] == nil and nil)
    end
    world.unit = unit

    set("GetLocale", function() return game.locale end)
    -- LocalizedClassList(isFemale) (ClassUtilDocumentation) and API_FillLocalizedClassList(table, isFemale): class file
    -- name -> localized name, from the client's ChrClasses (client_dump.lua)
    local function classNames(isFemale, into)
        into = into or {}
        for file, names in pairs(world.dump.classes) do into[file] = isFemale and names.female or names.male end
        return into
    end
    set("LocalizedClassList", function(isFemale) return classNames(isFemale) end)
    set("FillLocalizedClassList", function(tbl, isFemale) classNames(isFemale, tbl) return tbl end)
    set("GetCurrentRegionName", function() return game.region end)
    set("IsLoggedIn", function() return game.loggedIn or nil end)
    set("GetBuildInfo", function()
        local build = game.build
        return build.version, build.number, build.date, build.interface, build.version, build.version
    end)
    set("UnitName", function(token)
        local info = unit(token)
        if info then return info.name, info.realm ~= game.player.realm and info.realm or nil end
    end)
    set("UnitNameUnmodified", function(token)
        local info = unit(token)
        if info then return info.name, info.realm ~= game.player.realm and info.realm or nil end
    end)
    set("UnitFullName", function(token)
        local info = unit(token)
        if info then return info.name, info.realm end
    end)
    set("UnitClass", function(token)
        local info = unit(token)
        if info then return info.className, info.class, info.classID end
    end)
    set("UnitExists", function(token) return unit(token) ~= nil end)
    -- API_UnitRace: raceName, raceFile, raceID; API_UnitFactionGroup: englishFaction, localizedFaction
    set("UnitRace", function(token)
        if unit(token) then return "Human", "Human", 1 end
    end)
    set("UnitFactionGroup", function(token)
        if unit(token) then return "Alliance", "Alliance" end
    end)
    set("UnitIsGroupLeader", function(token) local info = unit(token) return info and info.leader or false end)
    set("UnitIsGroupAssistant", function(token) local info = unit(token) return info and info.assistant or false end)
    set("UnitInRaid", function(token)
        if not game.group or not game.group.raid then return nil end
        for index, member in ipairs(game.group.members) do
            if member == token or (unit(member) and unit(member).name == token) then return index end
        end
    end)
    set("UnitInParty", function(token)
        if not game.group then return false end
        for _, member in ipairs(game.group.members) do
            if member == token or (unit(member) and unit(member).name == token) then return true end
        end
        return false
    end)
    set("GetRealmName", function() return game.player.realm end)
    set("GetNormalizedRealmName", function() return (game.player.realm:gsub("[%s%-]", "")) end)

    set("IsInGroup", function() return game.group ~= nil end)
    set("IsInRaid", function() return game.group ~= nil and game.group.raid == true end)
    set("GetNumGroupMembers", function() return game.group and #game.group.members or 0 end)
    set("GetNumSubgroupMembers", function()
        if not game.group or game.group.raid then return 0 end
        return math.max(#game.group.members - 1, 0)
    end)
    set("GetRaidRosterInfo", function(index)
        local token = game.group and game.group.raid and game.group.members[index]
        local info = token and unit(token)
        if not info then return end
        return info.name, info.leader and 2 or info.assistant and 1 or 0, info.subgroup or 1, 80, info.className,
            info.class, "", true, false, info.role or "DAMAGER", false, info.role or "DAMAGER"
    end)
    set("IsInInstance", function() return game.instance.inInstance, game.instance.type end)
    set("InCombatLockdown", function() return game.inCombat end)
    set("C_InstanceEncounter.IsEncounterInProgress", function() return game.encounter ~= nil end)
    set("C_ChatInfo.InChatMessagingLockdown", function()
        return world.restricted or world.restrictions.SecretInChatMessagingLockdown or false
    end)
    set("C_ChatInfo.RegisterAddonMessagePrefix", function(prefix)
        game.prefixes[prefix] = true
        return Enum.RegisterAddonMessagePrefixResult and Enum.RegisterAddonMessagePrefixResult.Success or true
    end)
    set("C_ChatInfo.IsAddonMessagePrefixRegistered", function(prefix) return game.prefixes[prefix] == true end)
    set("C_ChatInfo.SendAddonMessage", function(prefix, message, channel, target)
        game.addonMessages[#game.addonMessages + 1] = { prefix = prefix, message = message, channel = channel, target = target }
        return Enum.SendAddonMessageResult and Enum.SendAddonMessageResult.Success or true
    end)
    set("C_ChatInfo.SendChatMessage", function(message, chatType, _, target)
        game.chatMessages[#game.chatMessages + 1] = { message = message, chatType = chatType, target = target }
    end)

    set("C_CVar.GetCVar", function(name) return game.cvars[name] end)
    set("C_CVar.SetCVar", function(name, value)
        game.cvars[name] = value ~= nil and tostring(value) or nil
        return true
    end)
    set("C_CVar.GetCVarBool", function(name) return game.cvars[name] == "1" end)

    set("C_AddOns.IsAddOnLoaded", function(name)
        local addon = game.addons[name]
        return addon ~= nil and addon.loaded == true, addon ~= nil and addon.loaded == true
    end)
    set("C_AddOns.GetAddOnMetadata", function(name, field)
        local addon = game.addons[name]
        if addon and field == "Version" then return addon.version end
        return addon and addon[field]
    end)
    set("C_AddOns.LoadAddOn", function(name)
        local addon = game.addons[name]
        if not addon then return false, "MISSING" end
        addon.loaded = true
        return true
    end)

    set("C_Spell.GetSpellInfo", function(spellID)
        local spell = game.spells[tonumber(spellID) or spellID]
        if not spell then return nil end
        return { name = spell.name, iconID = spell.iconID or 134400, originalIconID = spell.iconID or 134400,
            castTime = 0, minRange = 0, maxRange = 0, spellID = tonumber(spellID) }
    end)
    set("C_Spell.GetSpellName", function(spellID)
        local spell = game.spells[tonumber(spellID) or spellID]
        return spell and spell.name
    end)
    set("C_Spell.GetSpellTexture", function(spellID)
        local spell = game.spells[tonumber(spellID) or spellID]
        if spell then return spell.iconID or 134400, spell.iconID or 134400 end
    end)
    set("C_Texture.GetAtlasInfo", function(atlas) return game.atlases[atlas] end)

    -- C_EditMode.GetLayouts (EditModeManagerDocumentation.lua): EditModeLayouts { layouts = the account's and
    -- character's own layouts, activeLayout = index counting the preset layouts first }; preset 1 is active by default
    game.editMode = { layouts = {}, activeLayout = 1 }
    set("C_EditMode.GetLayouts", function()
        local layouts = {}
        for i, layout in ipairs(game.editMode.layouts) do layouts[i] = layout end
        return { layouts = layouts, activeLayout = game.editMode.activeLayout }
    end)

    -- C_UIFileAsset.IsKnownFile (UIFileAssetDocumentation.lua): whether the client has a file. Paths into this addon
    -- are looked up in the addon's folder (case-insensitively, as the client does); file IDs and other client paths
    -- cannot be checked here and count as known.
    local addonPrefix = "interface/addons/" .. world.appName:lower() .. "/"
    local known = {}
    set("C_UIFileAsset.IsKnownFile", function(file)
        if type(file) ~= "string" then return true end
        local normalized = file:gsub("\\", "/"):lower()
        if normalized:sub(1, #addonPrefix) ~= addonPrefix then return true end
        if known[normalized] == nil then
            local relative = file:gsub("\\", "/"):sub(#addonPrefix + 1)
            known[normalized] = world.fileExists(relative)
        end
        return known[normalized]
    end)

    set("PlaySoundFile", function(sound, channel)
        game.sounds[#game.sounds + 1] = { sound = sound, channel = channel }
        return true, #game.sounds
    end)
    set("C_VoiceChat.SpeakText", function(...)
        game.speech[#game.speech + 1] = { ... }
    end)
    set("C_PartyInfo.DoCountdown", function(seconds)
        game.countdowns[#game.countdowns + 1] = seconds
        return true
    end)
    set("IsShiftKeyDown", function() return game.modifiers.SHIFT == true end)
    set("IsControlKeyDown", function() return game.modifiers.CTRL == true end)
    set("IsMouseButtonDown", function() return false end)

    set("EJ_GetEncounterInfo", function(journalEncounterID)
        local encounter = game.journal.encounters[journalEncounterID]
        if encounter then
            return encounter.name, encounter.description or "", journalEncounterID, encounter.rootSectionID or 0,
                encounter.link or "", encounter.journalInstanceID, encounter.dungeonEncounterID, encounter.instanceID
        end
    end)
    set("EJ_GetInstanceInfo", function(journalInstanceID)
        local instance = game.journal.instances[journalInstanceID]
        if instance then
            return instance.name, instance.description or "", 0, 0, 0, 0, 0, "", false, instance.mapID or 0, 0, instance.isRaid or false
        end
    end)
    set("GetDifficultyInfo", function(difficultyID)
        local difficulty = game.difficulties and game.difficulties[difficultyID]
        if difficulty then
            return difficulty.name, difficulty.type or "raid", difficulty.isHeroic or false, difficulty.isChallengeMode or false,
                difficulty.displayHeroic or false, difficulty.displayMythic or false, nil, false, false, nil
        end
    end)

    -- Blizzard's encounter timeline (EncounterTimelineDocumentation.lua), driven by specs through world.encounterTimeline:
    -- Add fires ENCOUNTER_TIMELINE_EVENT_ADDED with the event's EncounterTimelineEventInfo, its time runs on the
    -- world's clock, SetTrack fires ENCOUNTER_TIMELINE_EVENT_TRACK_CHANGED and Remove ENCOUNTER_TIMELINE_EVENT_REMOVED.
    -- The API returns nothing for an event that is gone, as the plugin's own log expects.
    if world.api.has("C_EncounterTimeline.GetEventInfo") then
        local timeline = { events = {}, trackTypes = {}, nextID = 1000 }
        world.encounterTimeline = timeline
        local function elapsed(event)
            return event.pausedElapsed or (world.clock.now - event.start)
        end
        function timeline.Add(info)
            timeline.nextID = timeline.nextID + 1
            local event = {
                info = {
                    id = timeline.nextID, source = info.source or Enum.EncounterTimelineEventSource.Encounter,
                    spellName = info.spellName or "Spell", spellID = info.spellID or 1, iconFileID = info.iconFileID or 134400,
                    duration = info.duration or 30, maxQueueDuration = info.maxQueueDuration or 0, icons = info.icons or 0,
                    severity = info.severity or 1, isApproximate = info.isApproximate or false,
                },
                start = world.clock.now,
                track = info.track or Enum.EncounterTimelineTrack.Medium,
                pausedElapsed = info.paused and 0 or nil,
                blocked = false,
            }
            timeline.events[event.info.id] = event
            world.fireEvent("ENCOUNTER_TIMELINE_EVENT_ADDED", world.api.call("C_EncounterTimeline.GetEventInfo", event.info.id))
            return event.info.id
        end
        function timeline.SetTrack(id, track)
            timeline.events[id].track = track
            world.fireEvent("ENCOUNTER_TIMELINE_EVENT_TRACK_CHANGED", id)
        end
        function timeline.Pause(id)
            local event = timeline.events[id]
            event.pausedElapsed = elapsed(event)
            world.fireEvent("ENCOUNTER_TIMELINE_EVENT_STATE_CHANGED", id)
        end
        function timeline.Resume(id)
            local event = timeline.events[id]
            event.start, event.pausedElapsed = world.clock.now - event.pausedElapsed, nil
            world.fireEvent("ENCOUNTER_TIMELINE_EVENT_STATE_CHANGED", id)
        end
        function timeline.Remove(id)
            timeline.events[id] = nil
            world.fireEvent("ENCOUNTER_TIMELINE_EVENT_REMOVED", id)
        end
        local function event(id) return timeline.events[id] end
        set("C_EncounterTimeline.GetEventInfo", function(id)
            local e = event(id)
            if not e then return end
            local copy = {}
            for key, value in pairs(e.info) do copy[key] = value end
            return copy
        end)
        set("C_EncounterTimeline.GetEventState", function(id)
            local e = event(id)
            if not e then return end
            if e.pausedElapsed then return Enum.EncounterTimelineEventState.Paused end
            if elapsed(e) >= e.info.duration + e.info.maxQueueDuration then return Enum.EncounterTimelineEventState.Finished end
            return Enum.EncounterTimelineEventState.Active
        end)
        set("C_EncounterTimeline.GetEventTimeRemaining", function(id)
            local e = event(id)
            if e then return math.max(e.info.duration - elapsed(e), 0) end
        end)
        set("C_EncounterTimeline.GetEventTimeElapsed", function(id)
            local e = event(id)
            if e then return math.min(elapsed(e), e.info.duration) end
        end)
        set("C_EncounterTimeline.GetEventTrack", function(id)
            local e = event(id)
            if e then return e.track, 1 end
        end)
        set("C_EncounterTimeline.GetTrackType", function(track)
            return timeline.trackTypes[track] or Enum.EncounterTimelineTrackType.Linear
        end)
        set("C_EncounterTimeline.IsEventBlocked", function(id)
            local e = event(id)
            if e then return e.blocked end
        end)
        set("C_EncounterTimeline.GetEventColor", function(id)
            local e = event(id)
            return e and e.color
        end)
        set("C_EncounterTimeline.SetEventIconTextures", function(id, mask, textures)
            local e = event(id)
            if e then e.iconTextures = { mask = mask, textures = textures } end
        end)
        set("C_EncounterTimeline.IsFeatureAvailable", function() return true end)
        set("C_EncounterTimeline.IsFeatureEnabled", function() return true end)
    end

    -- issecretvalue (FrameScriptDocumentation.lua; API_issecretvalue): true for a secret
    set("issecretvalue", function(value) return world.secrets.IsSecret(value) end)
end

return M
