local loadAddon = dofile("spec/helpers/load_addon.lua")

describe("Boss timer rules", function()
    it("prefers an applicable difficulty rule over an earlier general fallback", function()
        local fallback = { match = "spell", value = "123" }
        local specific = { match = "spell", value = "123", difficulties = { heroic = true, normal = false } }
        local private = loadAddon("Plugins/TimerRules.lua", {
            activeEncounterID = 1,
            activeDifficulty = "heroic",
            db = { profile = { timerRules = { [1] = { fallback, specific } } } },
        })

        assert.equals(specific, private.GetTimerRule(123))
        private.activeDifficulty = "normal"
        assert.equals(fallback, private.GetTimerRule(123))
    end)
end)
