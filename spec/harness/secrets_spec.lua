-- Secret values as warcraft.wiki.gg/wiki/Secret_Values describes them, and their documentation-driven use.
local World = require("spec.helpers.world")
local Secrets = require("spec.helpers.secrets")

describe("secret values", function()
    before_each(function() World.Build({ libraries = false }) end)

    it("report their real type and are recognised by issecretvalue", function()
        local secret = Secrets.Secret(5)
        assert.equals("number", type(secret))
        assert.is_true(issecretvalue(secret))
        assert.is_false(issecretvalue(5))
    end)

    it("refuse arithmetic, comparison, indexing, calling and use as a guarded table key", function()
        local secret = Secrets.Secret(5)
        assert.has_error(function() return secret + 1 end)
        assert.has_error(function() return secret < Secrets.Secret(6) end)
        assert.has_error(function() return secret.field end)
        assert.has_error(function() secret() end)
        local guarded = Secrets.KeyGuard({})
        assert.has_error(function() guarded[secret] = true end)
    end)

    it("concatenate and format into secrets", function()
        local secret = Secrets.Secret("Boss")
        assert.is_true(Secrets.IsSecret("The " .. secret))
        assert.equals("The Boss", Secrets.Reveal("The " .. secret))
        assert.is_true(Secrets.IsSecret(("%s!"):format(secret)))
    end)

    it("are refused by functions not documented to take them from addon code", function()
        -- EncounterTimelineDocumentation.lua: GetEventInfo has SecretArguments = "NotAllowed"
        assert.has_error(function() C_EncounterTimeline.GetEventInfo(Secrets.Secret(1)) end)
    end)
end)

describe("a restricted world", function()
    it("makes documented returns secret except their NeverSecret fields", function()
        local world = World.Build({ libraries = false, restricted = true })
        world.api.set("C_EncounterTimeline.GetEventInfo", function(id)
            return { id = id, source = 0, spellName = "Spell", spellID = 1, iconFileID = 1, duration = 10, maxQueueDuration = 0 }
        end)
        -- EncounterTimelineEventInfo: id, source, duration are NeverSecret; spellName is not
        local info = C_EncounterTimeline.GetEventInfo(7)
        assert.equals(7, info.id)
        assert.equals(10, info.duration)
        assert.is_true(Secrets.IsSecret(info.spellName))
    end)

    it("keeps returns plain while no restriction applies", function()
        local world = World.Build({ libraries = false })
        world.api.set("C_EncounterTimeline.GetEventInfo", function(id) return { id = id, spellName = "Spell" } end)
        assert.equals("Spell", C_EncounterTimeline.GetEventInfo(7).spellName)
    end)
end)
