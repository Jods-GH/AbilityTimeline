-- whole_addon.lua: the addon as a client loads and starts it. Every file AbilityTimeline.toc lists for the client's
-- game type is loaded in order (XML expanded, libraries from the fetched .pkgmeta externals), then the client's
-- startup events run through the real AceAddon handlers: ADDON_LOADED, PLAYER_LOGIN, PLAYER_ENTERING_WORLD
-- (warcraft.wiki.gg/wiki/AddOn_loading_process).
local World = require("spec.helpers.world")

local WholeAddon = {}

---@param options table|nil World.Build options plus savedVariables (the AbilityTimeline SavedVariables table) and
---addons ({ [name] = { loaded, version } } other addons the game reports, e.g. DBM-Core)
---@return table handle { world, private, errors, files }
function WholeAddon.Load(options)
    options = options or {}
    local world = World.Build({ client = options.client, restricted = options.restricted, libraries = false })
    for name, info in pairs(options.addons or {}) do world.game.addons[name] = info end
    for key, value in pairs(options.globals or {}) do world.env[key] = value end
    world.env.AbilityTimeline = options.savedVariables
    local private = {}
    local files = {}
    for _, file in ipairs(World.TocFiles(world.info.gameType)) do
        if file.path:find("%.lua$") then
            World.LoadFile(world, file.path, private)
            files[#files + 1] = file.path
        end
    end
    local handle = { world = world, private = private, errors = world.errors, files = files }

    ---runs the startup events: the addon is loaded, the player logs in and enters the world
    function handle:Start()
        world.fireEvent("ADDON_LOADED", World.APP_NAME, false)
        world.game.loggedIn = true
        world.fireEvent("PLAYER_LOGIN")
        world.fireEvent("PLAYER_ENTERING_WORLD", true, false)
        -- the client reports the Edit Mode layouts once the UI has entered the world
        if world.docs.events.EDIT_MODE_LAYOUTS_UPDATED then
            world.fireEvent("EDIT_MODE_LAYOUTS_UPDATED", world.api.call("C_EditMode.GetLayouts"), false)
        end
        world.clock.Frame()
        return self
    end
    return handle
end

return WholeAddon
