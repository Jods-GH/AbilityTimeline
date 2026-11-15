local loadAddon = dofile("spec/helpers/load_addon.lua")

describe("DBM timer icons", function()
    for _, iconPath in ipairs({ "Interface/Icons/Spell_Test", "Interface\\Icons\\Spell_Test" }) do
        it("resolves the timer icon path " .. iconPath, function()
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
            -- DBM-Core.lua: RegisterCallback(event, callback); ClientDocumentation.lua: GetFileIDFromPath(filePath).
            loadAddon("Plugins/Dbm.lua", private, {
                string = string,
                C_AddOns = { IsAddOnLoaded = function(name) return name == "DBM-Core" end },
                DBM = { RegisterCallback = function(_, event, callback) callbacks[event] = callback end },
                GetFileIDFromPath = function(path)
                    assert.equals("Interface/Icons/Spell_Test", path)
                    return 123456
                end,
            })

            callbacks.DBM_TimerStart("DBM_TimerStart", "timer-id", "Test", 10, iconPath)

            assert.equals(1, #added)
            assert.equals(123456, added[1].iconFileID)
            assert.equals("timer-id", added[1].sourceID)
        end)
    end
end)
