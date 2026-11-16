-- api_docs.lua: Blizzard's generated API documentation of each client the TOC supports, read from the UI source that
-- .github/validation/fetch_deps.sh fetches (github.com/Gethe/wow-ui-source, one branch per client). Each file of
-- Blizzard_APIDocumentationGenerated is plain Lua that hands one table to APIDocumentation:AddDocumentationTable; the
-- tables describe the client's functions, events, enumerations, structures, constants and widget methods
-- (ScriptObject), including when values are secret. The WoW mocks are generated from this (spec/helpers/wow_mocks.lua).
local M = {}

M.DEPS = os.getenv("AT_DEPS") or "/deps"

-- The client of each UI source branch, by the game type the TOC's [AllowLoadGameType] names. Each branch's
-- version.txt gives its interface number, which spec/toc_spec.lua matches against the TOC's ## Interface list.
M.CLIENTS = {
    retail = { branch = "live", dump = "live", wago = "wow", gameType = "standard", retail = true },
    ptr = { branch = "ptr", dump = "ptr", wago = "wowt", gameType = "standard", retail = true },
    forever = { branch = "forever", dump = "forever", wago = "wowf", gameType = "forever" },
    mists = { branch = "classic", dump = "classic", wago = "wow_classic", gameType = "mists" },
    wrath = { branch = "classic_titan", wago = "wow_classic_titan", gameType = "wrath" },
    tbc = { branch = "classic_anniversary", dump = "classic_anniversary", wago = "wow_anniversary", gameType = "tbc" },
    vanilla = { branch = "classic_era", dump = "classic_era", wago = "wow_classic_era", gameType = "vanilla" },
}
M.CLIENT_ORDER = { "retail", "ptr", "forever", "mists", "wrath", "tbc", "vanilla" }

---the folder of a client's UI source
---@param client string
---@return string
function M.Root(client)
    local info = assert(M.CLIENTS[client], "unknown client " .. tostring(client))
    return M.DEPS .. "/ui/" .. info.branch
end

local function readFile(path)
    local file = io.open(path, "rb")
    if not file then return nil end
    local content = file:read("*a")
    file:close()
    return content
end
M.ReadFile = readFile

---the files a TOC lists, in order, without comments, directives and blank lines
---@param path string
---@return string[]
function M.TocFiles(path)
    local files = {}
    for line in assert(readFile(path), "missing " .. path):gmatch("[^\r\n]+") do
        line = line:gsub("^%s+", ""):gsub("%s+$", "")
        if line ~= "" and not line:find("^#") then
            files[#files + 1] = line:gsub("\\", "/")
        end
    end
    return files
end

---the client's version and interface number (version.txt, "12.1.5.70783" is 120105)
---@param client string
---@return string version, number interface
function M.Version(client)
    local version = assert(readFile(M.Root(client) .. "/version.txt"), "missing version.txt of " .. client):match("[%d%.]+")
    local major, minor, patch = version:match("^(%d+)%.(%d+)%.(%d+)")
    return version, tonumber(major) * 10000 + tonumber(minor) * 100 + tonumber(patch)
end

-- While the documentation loads, Enum.X.Y and Constants.X.Y are references, resolved once every table is known.
-- Documentation does arithmetic on them (CharacterCustomizationSharedDocumentation.lua), which stays deferred too.
local referenceMeta = {}
local function deferred(operation, a, b)
    return setmetatable({ reference = "expression", operation = operation, a = a, b = b }, referenceMeta)
end
for event, operation in pairs({ __add = "add", __sub = "sub", __mul = "mul", __div = "div", __mod = "mod", __concat = "concat" }) do
    referenceMeta[event] = function(a, b) return deferred(operation, a, b) end
end
referenceMeta.__unm = function(a) return deferred("unm", a) end

local function referenceTable(kind)
    return setmetatable({}, { __index = function(_, tableName)
        return setmetatable({}, { __index = function(_, field)
            return setmetatable({ reference = kind, table = tableName, field = field }, referenceMeta)
        end })
    end })
end

local OPERATIONS = {
    add = function(a, b) return a + b end,
    sub = function(a, b) return a - b end,
    mul = function(a, b) return a * b end,
    div = function(a, b) return a / b end,
    mod = function(a, b) return a % b end,
    concat = function(a, b) return a .. b end,
    unm = function(a) return -a end,
}

local function resolve(docs, value)
    if getmetatable(value) ~= referenceMeta then return value end
    if value.reference == "expression" then
        local a, b = resolve(docs, value.a), resolve(docs, value.b)
        if getmetatable(a) == referenceMeta or getmetatable(b) == referenceMeta or a == nil or (value.operation ~= "unm" and b == nil) then
            return value
        end
        local ok, result = pcall(OPERATIONS[value.operation], a, b)
        return ok and result or value
    end
    local source = value.reference == "Enum" and docs.enums[value.table] or docs.constants[value.table]
    local resolved = source and source[value.field]
    if resolved == nil then return value end
    return resolve(docs, resolved)
end

local cache = {}

---every documentation table of a client, indexed
---@param client string
---@return table docs
function M.Load(client)
    if cache[client] then return cache[client] end
    local folder = M.Root(client) .. "/Interface/AddOns/Blizzard_APIDocumentationGenerated/"
    local tables = {}
    local environment = {
        APIDocumentation = { AddDocumentationTable = function(_, documentation) tables[#tables + 1] = documentation end },
        Enum = referenceTable("Enum"),
        Constants = referenceTable("Constants"),
    }
    for _, file in ipairs(M.TocFiles(folder .. "Blizzard_APIDocumentationGenerated.toc")) do
        local chunk = assert(loadfile(folder .. file))
        setfenv(chunk, environment)
        chunk()
    end

    local docs = {
        client = client,
        systems = tables,
        functions = {},   -- "C_Spell.GetSpellInfo" or "GetTime" -> function documentation
        namespaces = {},  -- "C_Spell" -> true
        events = {},      -- "ENCOUNTER_START" -> event documentation
        types = {},       -- "SpellInfo" -> structure, enumeration or callback documentation
        enums = {},       -- "EncounterTimelineEventState" -> { Active = 0, ... }
        constants = {},   -- "SomeConstants" -> { NAME = value }
        scriptObjects = {}, -- "SimpleFrameAPI" -> { [method] = function documentation }
    }
    for _, system in ipairs(tables) do
        if system.Type == "ScriptObject" then
            local methods = {}
            for _, method in ipairs(system.Functions or {}) do
                method.System = system
                methods[method.Name] = method
            end
            docs.scriptObjects[system.Name] = methods
        else
            if system.Namespace then docs.namespaces[system.Namespace] = true end
            for _, func in ipairs(system.Functions or {}) do
                func.System = system
                func.FullName = system.Namespace and (system.Namespace .. "." .. func.Name) or func.Name
                docs.functions[func.FullName] = func
            end
            for _, event in ipairs(system.Events or {}) do
                event.System = system
                docs.events[event.LiteralName] = event
            end
        end
        for _, documented in ipairs(system.Tables or {}) do
            docs.types[documented.Name] = documented
            if documented.Type == "Enumeration" then
                local enum = {}
                for _, field in ipairs(documented.Fields or {}) do
                    enum[field.Name] = field.EnumValue
                end
                docs.enums[documented.Name] = enum
            elseif documented.Type == "Constants" then
                docs.constants[documented.Name] = {}
            end
        end
    end
    -- Constants may name enumerations and other constants: resolve until nothing changes.
    for _, system in ipairs(tables) do
        for _, documented in ipairs(system.Tables or {}) do
            if documented.Type == "Constants" then
                for _, value in ipairs(documented.Values or {}) do
                    -- A constant of an enumeration type may give the enumeration's field name instead of its value.
                    local enum = docs.enums[value.Type]
                    local constant = value.Value
                    if enum and type(constant) == "string" and enum[constant] ~= nil then
                        constant = enum[constant]
                    end
                    docs.constants[documented.Name][value.Name] = constant
                end
            end
        end
    end
    local changed = true
    while changed do
        changed = false
        for _, values in pairs(docs.constants) do
            for name, value in pairs(values) do
                local resolved = resolve(docs, value)
                if resolved ~= value and resolved ~= nil then
                    values[name] = resolved
                    changed = true
                end
            end
        end
    end
    docs.resolve = function(value) return resolve(docs, value) end
    cache[client] = docs
    return docs
end

return M
