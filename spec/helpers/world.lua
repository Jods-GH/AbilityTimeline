-- world.lua: the World of Warcraft client a spec runs against, built in the real global table the way BetterBags
-- builds its own (spec/setup.lua restores the globals Lua and busted start with before every spec file).
-- World.Build{ client = "retail", restricted = false } installs, in order:
--   1. Lua extensions the client adds in C (spec/helpers/lua_extensions.lua) and the secret rules (secrets.lua)
--   2. the client's documented API, Enum and Constants (api_mocks.lua), then undocumented C functions (legacy_api.lua)
--   3. the clock, the widget engine, game state behaviour (game.lua)
--   4. Blizzard's own Lua from the client's UI source (blizzard_lua.lua), then the UI the client creates (ui_frames.lua)
--   5. C_EncodingUtil's real encodings (encoding_util.lua)
--   6. the libraries the packager ships, from /deps/Libs, through the addon's embeds.xml
local Docs = require("spec.helpers.api_docs")
local Secrets = require("spec.helpers.secrets")
local Toc = require("spec.helpers.toc")

local World = {}

World.ROOT = os.getenv("AT_ADDON_ROOT") or "."
World.APP_NAME = "AbilityTimeline"

local pristine
---remembers the globals as Lua and busted start with them (spec/setup.lua)
function World.SnapshotGlobals()
    pristine = {}
    for key, value in pairs(_G) do pristine[key] = value end
end

local restoreSecrets
local function restoreGlobals()
    if restoreSecrets then restoreSecrets() restoreSecrets = nil end
    for key, value in pairs(_G) do
        if pristine[key] ~= value then rawset(_G, key, pristine[key]) end
    end
    for key, value in pairs(pristine) do
        if rawget(_G, key) == nil then rawset(_G, key, value) end
    end
end

-- The XSD's script elements: every frame type takes ScriptsType's, animations AnimScriptsType's and animation groups
-- AnimGroupScriptsType's (Blizzard_SharedXML/UI.xsd).
local scriptSets = {}
local function scriptSetsOf(client)
    if scriptSets[client] then return scriptSets[client] end
    local xsd = assert(Toc.Read(Docs.Root(client) .. "/Interface/AddOns/Blizzard_SharedXML/UI.xsd"), "missing UI.xsd")
    local sets = {}
    for name, body in xsd:gmatch('<xs:complexType name="(%a+)">(.-)</xs:complexType>') do
        if name == "ScriptsType" or name == "AnimScriptsType" or name == "AnimGroupScriptsType" then
            local set = {}
            for script in body:gmatch('<xs:element name="(On%w+)"') do set[script] = true end
            sets[name] = set
        end
    end
    scriptSets[client] = sets
    return sets
end

---builds a fresh world into the globals and returns it
---@param options table|nil { client = "retail", restricted = false, libraries = true, blizzard = true }
function World.Build(options)
    options = options or {}
    restoreGlobals()
    local client = options.client or "retail"
    local info = assert(Docs.CLIENTS[client], "unknown client " .. client)
    local env = _G
    local world = {
        client = client, info = info, env = env, docs = Docs.Load(client),
        errors = {}, restricted = options.restricted or false, restrictions = {},
        implementations = {}, documented = {}, templates = {}, undocumentedEvents = {},
    }
    world.secrets = Secrets

    ---calls f the way the client calls scripts and callbacks: an error goes to the error handler
    function world.call(f, ...)
        return env.securecallfunction(f, ...)
    end

    world.api = {}
    ---replaces what a documented (or legacy) function does; the name must exist on the world's client
    function world.api.set(name, implementation)
        if not world.documented[name] then
            error(("world.api.set: %s does not exist on the %s client"):format(name, client), 2)
        end
        world.implementations[name] = implementation
    end
    function world.api.has(name) return world.documented[name] ~= nil end
    function world.api.call(name, ...) return world.implementations[name](...) end

    local sets = scriptSetsOf(client)
    local Widgets = require("spec.helpers.widgets")
    function world.scriptsOf(widgetType)
        if Widgets.IsA(widgetType, "AnimationGroup") then return sets.AnimGroupScriptsType end
        if Widgets.IsA(widgetType, "Animation") then return sets.AnimScriptsType end
        return sets.ScriptsType
    end

    require("spec.helpers.lua_extensions").Install(world, env)
    restoreSecrets = Secrets.Install(env)
    require("spec.helpers.api_mocks").Install(world, env)
    require("spec.helpers.legacy_api").Install(world, env)

    world.clock = require("spec.helpers.clock").New(world)
    world.widgets = Widgets.New(world)
    world.clock.Install(env)
    env.CreateFrame = world.widgets.CreateFrame
    world.api.set("CreateFont", world.widgets.CreateFont)

    require("spec.helpers.xml_templates").Install(world, env)
    require("spec.helpers.game").Install(world, env)

    if options.blizzard ~= false then
        local Blizzard = require("spec.helpers.blizzard_lua")
        local wanted = Blizzard.AddonGlobals(World.ROOT .. "/.luacheckrc")
        for _, mixin in ipairs(world.templateMixins(World.TemplatesInUse(world))) do wanted[#wanted + 1] = mixin end
        world.blizzardPlan = Blizzard.Plan(client, wanted)
        world.blizzardFailures = Blizzard.Load(world, world.blizzardPlan)
    end
    require("spec.helpers.ui_frames").Install(world, env)
    require("spec.helpers.encoding_util").Install(world)

    ---fires a game event at every frame that registered it; its payload is secret where the documentation says so
    function world.fireEvent(event, ...)
        local doc = world.docs.events[event]
        if not doc and not world.undocumentedEvents[event] then
            error(("world.fireEvent: %s is not an event of the %s client"):format(event, client), 2)
        end
        if doc then
            local Mocks = require("spec.helpers.api_mocks")
            local count = select("#", ...)
            local payload = { ... }
            if Mocks.IsSecretNow(world, doc) or (doc.Payload and doc.SecretInChatMessagingLockdown and world.restrictions.SecretInChatMessagingLockdown) then
                for i = 1, count do
                    payload[i] = Mocks.Secretize(world.docs, doc.Payload and doc.Payload[i] or { Type = "unknown" }, payload[i])
                end
            end
            world.widgets.FireEvent(event, unpack(payload, 1, count))
        else
            world.widgets.FireEvent(event, ...)
        end
    end

    if options.libraries ~= false then
        world.libraryFiles = World.LoadLibraries(world)
    end

    World.current = world
    return world
end

---where a path the TOC or an XML file names is read from: the addon root, or for Libs/ the folder fetch_deps.sh puts
---the .pkgmeta externals in (the repository's own Libs/ is never read, so tests run what the packager ships)
function World.Resolve(path)
    path = path:gsub("\\", "/")
    local rootPattern = "^" .. World.ROOT:gsub("%p", "%%%0") .. "/"
    local relative = path:gsub(rootPattern, ""):gsub("^%./", "")
    -- normalise a/b/../c, which nested library XML produces
    repeat
        local before = relative
        relative = relative:gsub("[^/]+/%.%./", "", 1)
    until relative == before
    local library = relative:match("^Libs/(.*)$")
    if library then return Docs.DEPS .. "/Libs/" .. library end
    if path:find("^" .. Docs.DEPS:gsub("%p", "%%%0") .. "/") then return path end
    return World.ROOT .. "/" .. relative
end

---loads a Lua file of the addon or its libraries as the client does: with the addon's name and namespace
function World.LoadFile(world, path, namespace)
    local chunk = assert(loadfile(path))
    setfenv(chunk, world.env)
    return chunk(World.APP_NAME, namespace)
end

---every file the client loads for the addon's TOC, in order, with Libs/ read from the fetched externals
function World.TocFiles(gameType, filter)
    return (Toc.Files(World.ROOT .. "/AbilityTimeline.toc", gameType, function(path)
        local resolved = World.Resolve(path)
        if filter and not filter(resolved) then return nil end
        return resolved
    end))
end

local templatesInUse = {}
---the Blizzard templates the addon and its libraries name in their Lua (string literals that are template names)
function World.TemplatesInUse(world)
    if templatesInUse[world.client] then return templatesInUse[world.client] end
    local names, seen = {}, {}
    for _, file in ipairs(World.TocFiles(world.info.gameType)) do
        if file.path:find("%.lua$") then
            local content = Toc.Read(file.path) or ""
            for literal in content:gmatch("[\"']([%w_]+)[\"']") do
                if world.templateRegistry[literal] and not seen[literal] then
                    seen[literal] = true
                    names[#names + 1] = literal
                end
            end
        end
    end
    templatesInUse[world.client] = names
    return names
end

---loads the libraries embeds.xml lists, from /deps/Libs
function World.LoadLibraries(world)
    local loaded = {}
    local depsPattern = "^" .. Docs.DEPS:gsub("%p", "%%%0") .. "/"
    for _, file in ipairs(World.TocFiles(world.info.gameType, function(path)
        return path:find("embeds%.xml$") or path:find(depsPattern)
    end)) do
        if file.path:find("%.lua$") then
            World.LoadFile(world, file.path, {})
            loaded[#loaded + 1] = file.path
        end
    end
    return loaded
end

return World
