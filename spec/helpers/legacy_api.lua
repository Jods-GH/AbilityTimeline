-- legacy_api.lua: C functions the addon calls that the client has but neither Blizzard_APIDocumentationGenerated nor
-- Blizzard's Lua defines. Each is installed only when the client's documentation does not describe it, with the
-- signature and game types its warcraft.wiki.gg page gives. The wiki lists no Titan (wrath) game type; Titan is a
-- Classic client, so these count it with the other Classic clients. Behaviour comes from spec/helpers/game.lua.
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
    GetLocale = { wiki = "API_GetLocale", returns = { { Type = "string" } } },
    GetNormalizedRealmName = { wiki = "API_GetRealmName", returns = {} },
    GetRealmName = { wiki = "API_GetRealmName", returns = { { Type = "string" } } },
    -- API_time and API_date: Lua's os.time and os.date as globals (spec/helpers/clock.lua gives them the world's time)
    time = { wiki = "API_time", returns = { { Type = "number" } } },
    date = { wiki = "API_date", returns = {} },
}

---installs the functions the client's documentation lacks
function M.Install(world, env)
    local Mocks = require("spec.helpers.api_mocks")
    for name, info in pairs(M.FUNCTIONS) do
        if not world.documented[name] then
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
