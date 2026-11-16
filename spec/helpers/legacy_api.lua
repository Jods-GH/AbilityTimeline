-- legacy_api.lua: C functions the addon and its libraries call that the client has but neither
-- Blizzard_APIDocumentationGenerated nor Blizzard's Lua defines, with the signature their warcraft.wiki.gg page gives.
-- Each is installed when the client's documentation does not describe it and the client's GlobalAPI dump lists it
-- (client_dump.lua); Titan (wrath) has no dump, so there all of them are installed. Behaviour comes from game.lua.
local M = {}

-- name -> { wiki page, returns (documented-style fields) }; every entry exists on every supported client
M.FUNCTIONS = {
    InCombatLockdown = { wiki = "API_InCombatLockdown", returns = { { Type = "bool" } } },
    IsInGroup = { wiki = "API_IsInGroup", returns = { { Type = "bool" } } },
    IsInRaid = { wiki = "API_IsInRaid", returns = { { Type = "bool" } } },
    GetNumGroupMembers = { wiki = "API_GetNumGroupMembers", returns = { { Type = "number" } } },
    GetNumSubgroupMembers = { wiki = "API_GetNumSubgroupMembers", returns = { { Type = "number" } } },
    GetRaidRosterInfo = { wiki = "API_GetRaidRosterInfo", returns = {} },
    EJ_GetEncounterInfo = { wiki = "API_EJ_GetEncounterInfo", returns = {} },
    EJ_GetInstanceInfo = { wiki = "API_EJ_GetInstanceInfo", returns = {} },
    EJ_GetCreatureInfo = { wiki = "API_EJ_GetCreatureInfo", returns = {} },
    GetSpecializationInfoByID = { wiki = "API_GetSpecializationInfoByID", returns = {} },
    PlaySoundFile = { wiki = "API_PlaySoundFile", returns = { { Type = "bool" }, { Type = "number" } } },
    StopSound = { wiki = "API_StopSound", returns = {} },
    CreateFont = { wiki = "API_CreateFont", returns = {} },
    GetBuildInfo = { wiki = "API_GetBuildInfo", returns = {} },
    GetGameTime = { wiki = "API_GetGameTime", returns = { { Type = "number" }, { Type = "number" } } },
    GetTime = { wiki = "API_GetTime", returns = { { Type = "number" } } },
    IsShiftKeyDown = { wiki = "API_IsModifierKeyDown", returns = { { Type = "bool" } } },
    IsControlKeyDown = { wiki = "API_IsModifierKeyDown", returns = { { Type = "bool" } } },
    IsMouseButtonDown = { wiki = "API_IsMouseButtonDown", returns = { { Type = "bool" } } },
    UnitClass = { wiki = "API_UnitClass", returns = {} },
    UnitName = { wiki = "API_UnitName", returns = {} },
    -- read by AceDB-3.0 for its profile keys
    UnitRace = { wiki = "API_UnitRace", returns = {} },
    UnitFactionGroup = { wiki = "API_UnitFactionGroup", returns = {} },
    GetCurrentRegionName = { wiki = "API_GetCurrentRegionName", returns = { { Type = "string" } } },
    -- read by Classic's Blizzard_FrameXMLBase Constants.lua for LOCALIZED_CLASS_NAMES_MALE
    FillLocalizedClassList = { wiki = "API_FillLocalizedClassList", returns = {} },
    -- read by AceAddon-3.0; nil before PLAYER_LOGIN
    IsLoggedIn = { wiki = "API_IsLoggedIn", returns = {} },
    GetLocale = { wiki = "API_GetLocale", returns = { { Type = "string" } } },
    GetNormalizedRealmName = { wiki = "API_GetRealmName", returns = {} },
    GetRealmName = { wiki = "API_GetRealmName", returns = { { Type = "string" } } },
    -- API_time and API_date: Lua's os.time and os.date as globals (spec/helpers/clock.lua gives them the world's time)
    time = { wiki = "API_time", returns = { { Type = "number" } } },
    date = { wiki = "API_date", returns = {} },
}

---installs the functions the client's documentation lacks: those its dump's GlobalAPI lists (client_dump.lua), or
---every one for a client without a dump
function M.Install(world, env)
    local Mocks = require("spec.helpers.api_mocks")
    local globalAPI = world.dump.runtime and world.dump.globalAPI
    for name, info in pairs(M.FUNCTIONS) do
        local exists = not globalAPI or globalAPI[name] or name == "time" or name == "date"
        if not world.documented[name] and exists then
            local doc = { Name = name, Returns = info.returns, Legacy = info.wiki }
            world.documented[name] = doc
            world.implementations[name] = function()
                local values = {}
                for i, field in ipairs(info.returns) do values[i] = Mocks.DefaultValue(world.docs, field) end
                return unpack(values, 1, #info.returns)
            end
            Mocks.Place(env, name, function(...)
                Mocks.CheckArguments(world, doc, name, ...)
                return world.implementations[name](...)
            end)
        end
    end
end

return M
