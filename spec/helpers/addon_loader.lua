-- addon_loader.lua: loads the addon's own files into a world as the client loads them, each called with the addon's
-- name and its namespace table (`local appName, app = ...`). Specs load the files they test next to stubs of the rest;
-- spec/helpers/whole_addon.lua loads all of them.
local World = require("spec.helpers.world")

local Addon = {}

---loads addon files (paths relative to the addon root) into the current world with one namespace
---@param paths string|string[]
---@param namespace table|nil the shared namespace, a new one by default
---@return table namespace
function Addon.Load(paths, namespace)
    namespace = namespace or {}
    if type(paths) == "string" then paths = { paths } end
    local world = assert(World.current, "no world built")
    for _, path in ipairs(paths) do
        World.LoadFile(world, World.ROOT .. "/" .. path, namespace)
    end
    return namespace
end

---sets namespace[key] = value and returns value; for stubbing what other addon files provide
function Addon.Stub(namespace, key, value)
    namespace[key] = value
    return value
end

return Addon
