-- client_dump.lua: what the client creates in C that the UI source lacks, fetched per client by fetch_deps.sh:
-- - wago.tools DB2 tables (every client): GlobalStrings (the localized strings, enUS) and GlobalColor (the color
--   objects such as NORMAL_FONT_COLOR, ARGB)
-- - Ketho/BlizzardInterfaceResources, dumped in a running client by the KethoDoc addon (every client but Titan):
--   LuaEnum.lua (the client's Enum and Constants tables and its C constants such as LE_* and NUM_*, which override the
--   documentation's where both have a value), GlobalAPI.lua (every global C function, deciding whether an
--   undocumented function exists, legacy_api.lua), CVars.lua (CVar defaults), Events.lua (every event) and
--   AtlasInfo.lua (atlas sizes and coordinates)
local Docs = require("spec.helpers.api_docs")
local Toc = require("spec.helpers.toc")

local M = {}

local function run(path, env)
    local chunk = assert(Toc.LoadLua(path))
    setfenv(chunk, env or {})
    return chunk()
end

---the rows of a CSV file (RFC 4180: quoted fields, doubled quotes, newlines inside quotes), header row first
function M.ParseCsv(content)
    local rows, row, field, position, length = {}, {}, {}, 1, #content
    local quoted = false
    while position <= length do
        local c = content:sub(position, position)
        if quoted then
            if c == '"' then
                if content:sub(position + 1, position + 1) == '"' then
                    field[#field + 1] = '"'
                    position = position + 1
                else
                    quoted = false
                end
            else
                field[#field + 1] = c
            end
        elseif c == '"' then
            quoted = true
        elseif c == "," then
            row[#row + 1] = table.concat(field)
            field = {}
        elseif c == "\n" or c == "\r" then
            if c == "\r" and content:sub(position + 1, position + 1) == "\n" then position = position + 1 end
            row[#row + 1] = table.concat(field)
            rows[#rows + 1] = row
            row, field = {}, {}
        else
            field[#field + 1] = c
        end
        position = position + 1
    end
    if #field > 0 or #row > 0 then
        row[#row + 1] = table.concat(field)
        rows[#rows + 1] = row
    end
    return rows
end

local function csvTable(path)
    local content = Toc.Read(path)
    if not content then return nil end
    local rows = M.ParseCsv(content)
    local header, records = rows[1], {}
    for i = 2, #rows do
        local record = {}
        for column, name in ipairs(header) do record[name] = rows[i][column] end
        records[#records + 1] = record
    end
    return records
end

---a GlobalColor's signed 32-bit ARGB as 0..1 components
function M.ArgbComponents(value)
    value = tonumber(value) % 4294967296
    local a = math.floor(value / 16777216)
    local r = math.floor(value / 65536) % 256
    local g = math.floor(value / 256) % 256
    local b = value % 256
    return r / 255, g / 255, b / 255, a / 255
end

-- warcraft.wiki.gg/wiki/WOW_PROJECT_ID: the project constants the client defines in C
M.WOW_PROJECTS = {
    WOW_PROJECT_MAINLINE = 1, WOW_PROJECT_CLASSIC = 2, WOW_PROJECT_WOWLABS = 3,
    WOW_PROJECT_BURNING_CRUSADE_CLASSIC = 5, WOW_PROJECT_WRATH_CLASSIC = 11, WOW_PROJECT_CATACLYSM_CLASSIC = 14,
    WOW_PROJECT_CAMELOT = 18, WOW_PROJECT_MISTS_CLASSIC = 19,
}
-- WOW_PROJECT_ID of a client without a runtime dump: the wiki lists Titan Reforged under WOW_PROJECT_WRATH_CLASSIC
M.PROJECT_WITHOUT_DUMP = { wrath = 11 }

local cache = {}

---the client's dump: { strings, colors, and when Ketho has the client: Enum, Constants, constants, globalAPI, cvars,
---events, atlases }
function M.Load(client)
    if cache[client] then return cache[client] end
    local info = Docs.CLIENTS[client]
    local dump = { client = client }

    local folder = Docs.DEPS .. "/wago/" .. info.wago .. "/"
    dump.strings, dump.colors = {}, {}
    for _, record in ipairs(assert(csvTable(folder .. "GlobalStrings.csv"), "missing wago GlobalStrings of " .. client)) do
        dump.strings[record.BaseTag] = record.TagText_lang
    end
    for _, record in ipairs(assert(csvTable(folder .. "GlobalColor.csv"), "missing wago GlobalColor of " .. client)) do
        dump.colors[record.LuaConstantName] = { M.ArgbComponents(record.Color) }
    end
    -- ChrClasses: class file name -> male and female names (Name_lang when a gendered name is empty)
    dump.classes = {}
    local classByID = {}
    for _, record in ipairs(assert(csvTable(folder .. "ChrClasses.csv"), "missing wago ChrClasses of " .. client)) do
        if record.Filename and record.Filename ~= "" then
            local male = record.Name_male_lang ~= "" and record.Name_male_lang or record.Name_lang
            local female = record.Name_female_lang ~= "" and record.Name_female_lang or record.Name_lang
            dump.classes[record.Filename] = { male = male, female = female, id = tonumber(record.ID) }
            classByID[tonumber(record.ID)] = record.Filename
        end
    end
    -- ChrSpecialization: spec ID -> its class file and name (empty before Mists of Pandaria)
    dump.specs = {}
    for _, record in ipairs(csvTable(folder .. "ChrSpecialization.csv") or {}) do
        local class = classByID[tonumber(record.ClassID)]
        if class and tonumber(record.ID) then
            dump.specs[tonumber(record.ID)] = { class = class, name = record.Name_lang, role = record.Role }
        end
    end

    dump.projectID = M.PROJECT_WITHOUT_DUMP[client]
    local resources = info.dump and Docs.DEPS .. "/dump/" .. info.dump .. "/Resources/"
    if resources and Toc.Exists(resources .. "LuaEnum.lua") then
        dump.runtime = true
        -- the README records what the dumping client returned: "WOW_PROJECT_ID => WOW_PROJECT_CAMELOT (18)"
        local readme = Toc.Read(Docs.DEPS .. "/dump/" .. info.dump .. "/README.md") or ""
        dump.projectID = tonumber(readme:match("WOW_PROJECT_ID => [%w_]+ %((%d+)%)"))
        local enumEnv = {}
        run(resources .. "LuaEnum.lua", enumEnv)
        dump.Enum, dump.Constants = enumEnv.Enum or {}, enumEnv.Constants or {}
        dump.constants = {}
        for key, value in pairs(enumEnv) do
            if key ~= "Enum" and key ~= "Constants" then dump.constants[key] = value end
        end
        dump.globalAPI = {}
        for _, list in ipairs(run(resources .. "GlobalAPI.lua")) do
            for _, name in ipairs(list) do dump.globalAPI[name] = true end
        end
        dump.cvars = {}
        for name, cvar in pairs((run(resources .. "CVars.lua")[1] or {}).var or {}) do dump.cvars[name] = cvar[1] end
        dump.events = {}
        for _, events in pairs(run(resources .. "Events.lua")) do
            for _, event in ipairs(events) do dump.events[event] = true end
        end
        dump.atlases = {}
        for _, atlases in pairs(run(resources .. "AtlasInfo.lua")) do
            for name, atlas in pairs(atlases) do dump.atlases[name] = atlas end
        end
    end

    cache[client] = dump
    return dump
end

local function merge(target, source)
    for key, value in pairs(source) do
        if type(value) == "table" and type(target[key]) == "table" then
            merge(target[key], value)
        else
            target[key] = value
        end
    end
end

---installs the dump's enums, constants and strings into env; world.dump is the dump
function M.Install(world, env)
    local dump = M.Load(world.client)
    world.dump = dump
    for key, value in pairs(dump.strings) do
        if env[key] == nil then env[key] = value end
    end
    for key, value in pairs(M.WOW_PROJECTS) do env[key] = value end
    env.WOW_PROJECT_ID = assert(dump.projectID, "no WOW_PROJECT_ID known for " .. world.client)
    if not dump.runtime then return end
    merge(env.Enum, dump.Enum)
    env.Constants = env.Constants or {}
    merge(env.Constants, dump.Constants)
    for key, value in pairs(dump.constants) do
        if env[key] == nil then env[key] = value end
    end
    for event in pairs(dump.events) do
        if not world.docs.events[event] then world.undocumentedEvents[event] = true end
    end
end

---creates the GlobalColor objects with Blizzard's CreateColor (Color.lua), as the client has them before its UI runs
function M.InstallColors(world, env)
    if world.colorsInstalled or not env.CreateColor then return end
    world.colorsInstalled = true
    for name, components in pairs(world.dump.colors) do
        if env[name] == nil then env[name] = env.CreateColor(unpack(components)) end
    end
end

return M
