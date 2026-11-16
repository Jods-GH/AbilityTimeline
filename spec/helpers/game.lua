-- game.lua: the state of the game the world's API answers from (world.game), and the behaviour of the functions the
-- addon depends on. Every behaviour is set through world.api.set, so it only exists where the client's documentation
-- (or legacy_api.lua) says the function exists; a behaviour for a function a client lacks is skipped. Returns follow
-- each function's documentation (or its warcraft.wiki.gg page for legacy functions).
local M = {}

function M.Install(world, env)
    local game = {
        locale = "enUS",
        player = { name = "Player", realm = "Realm", class = "MAGE", className = "Mage", classID = 8, specIndex = 1, specID = 63 },
        units = {},          -- unit token -> { name, realm, class, className, classID, leader, assistant }
        group = nil,         -- nil, or { raid = bool, instance = bool, members = { unit tokens } }
        instance = { inInstance = false, type = "none" },
        encounter = nil,     -- the encounter in progress
        inCombat = false,
        cvars = {},
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

    local function set(name, implementation)
        if world.api.has(name) then world.api.set(name, implementation) end
    end

    local function unit(token)
        if token == "player" then return game.player end
        return game.units[token] or (game.units[token] == nil and nil)
    end
    world.unit = unit

    set("GetLocale", function() return game.locale end)
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
    set("C_ChatInfo.SendChatMessage", function(message, chatType, languageID, target)
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

    -- issecretvalue (FrameScriptDocumentation.lua; API_issecretvalue): true for a secret
    set("issecretvalue", function(value) return world.secrets.IsSecret(value) end)
end

return M
