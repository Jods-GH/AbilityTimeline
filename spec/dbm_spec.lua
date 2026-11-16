local Addon = require("spec.helpers.addon_loader")
local World = require("spec.helpers.world")

describe("DBM timer icons", function()
    for _, iconPath in ipairs({ "Interface/Icons/Spell_Test", "Interface\\Icons\\Spell_Test" }) do
        it("resolves the timer icon path " .. iconPath, function()
            local world = World.Build()
            local callbacks, added = {}, {}
            local private = {
                Debug = function() end,
                GetTimerRule = function() end,
                manager = {
                    SOURCES = { DBM = "DBM" },
                    registerColorSource = function() end,
                    registerBossMod = function() end,
                    addEvent = function(info)
                        added[#added + 1] = info
                        return #added
                    end,
                },
            }
            world.game.addons["DBM-Core"] = { loaded = true }
            -- DBM-Core.lua: RegisterCallback(event, callback); spec files run in their own environment, so the
            -- addon's global goes into _G
            _G.DBM = { RegisterCallback = function(_, event, callback) callbacks[event] = callback end }
            -- ClientDocumentation.lua: GetFileIDFromPath(filePath)
            world.api.set("GetFileIDFromPath", function(path)
                assert.equals("Interface/Icons/Spell_Test", path)
                return 123456
            end)
            Addon.Load("Plugins/Dbm.lua", private)

            callbacks.DBM_TimerStart("DBM_TimerStart", "timer-id", "Test", 10, iconPath)

            assert.equals(1, #added)
            assert.equals(123456, added[1].iconFileID)
            assert.equals("timer-id", added[1].sourceID)
        end)
    end
end)
