assert(_VERSION == "Lua 5.1", "AbilityTimeline tests require Lua 5.1")
package.path = "./?.lua;" .. package.path

-- Every spec file starts from a world of its own (spec/helpers/world.lua): the globals Lua and busted start with,
-- then a fresh Retail world. A spec builds another world (another client, restricted) with World.Build.
local World = require("spec.helpers.world")
World.SnapshotGlobals()

local busted = require("busted")
busted.subscribe({ "file", "start" }, function()
    World.Build()
    return nil, true
end)
