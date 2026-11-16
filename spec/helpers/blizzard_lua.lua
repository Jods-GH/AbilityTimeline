-- blizzard_lua.lua: Blizzard's own Lua from the client's UI source, loaded into the world instead of stand-ins.
-- The addons searched are the ones fetch_deps.sh fetches (SharedXMLBase, SharedXML, FrameXMLBase and every
-- Blizzard_Deprecated* addon that loads with the client); each addon's TOC is resolved for the client's game type
-- (spec/helpers/toc.lua). A file is loaded when it defines a global the addon reads (the read_globals of .luacheckrc)
-- or a global one of the loaded files reads, and files load in their addons' order. Which files that are follows the
-- UI source, so a definition Blizzard moves to another file is found there on the next fetch.
local Docs = require("spec.helpers.api_docs")
local Toc = require("spec.helpers.toc")

local M = {}

-- Load order of the fetched addons (their TOC dependencies); any other fetched addon follows alphabetically.
M.ORDER = { "Blizzard_SharedXMLBase", "Blizzard_Fonts_Shared", "Blizzard_SharedXML", "Blizzard_SharedXMLGame", "Blizzard_ChatFrameBase", "Blizzard_FrameXMLBase", "Blizzard_FrameXMLUtil",
    "Blizzard_GameTooltip", "Blizzard_FrameXML", "Blizzard_EditMode" }

local function fetchedAddons(root)
    local rank, addons = {}, {}
    for index, name in ipairs(M.ORDER) do rank[name] = index end
    local listing = io.popen('ls -1 "' .. root .. '/Interface/AddOns" 2>/dev/null')
    for name in listing:lines() do
        if name ~= "Blizzard_APIDocumentationGenerated" then addons[#addons + 1] = name end
    end
    listing:close()
    table.sort(addons, function(a, b)
        local rankA, rankB = rank[a] or #M.ORDER + 1, rank[b] or #M.ORDER + 1
        if rankA ~= rankB then return rankA < rankB end
        return a < b
    end)
    return addons
end

local addonFiles = {}
---every file of the fetched Blizzard addons a client loads, in load order: { addon, path, onDemand }
function M.AddonFiles(client)
    if addonFiles[client] then return addonFiles[client] end
    local root = Docs.Root(client)
    local gameType = Docs.CLIENTS[client].gameType
    local files = {}
    for _, addon in ipairs(fetchedAddons(root)) do
        local folder = root .. "/Interface/AddOns/" .. addon
        local tocPath = Toc.Pick(folder, addon, gameType)
        if Toc.Exists(tocPath) then
            local toc = Toc.Parse(tocPath)
            local allowed = toc.metadata.AllowLoadGameType
            if not allowed or Toc.Allows({ AllowLoadGameType = { allowed:lower() } }, gameType) then
                for _, file in ipairs((Toc.Files(tocPath, gameType, function(path)
                    return Toc.Exists(path) and path or nil
                end))) do
                    files[#files + 1] = { addon = addon, path = file.path, onDemand = toc.metadata.LoadOnDemand == "1" }
                end
            end
        end
    end
    addonFiles[client] = files
    return files
end

---the globals a Lua file defines at its top level, and the identifiers it reads
local function scan(content)
    local defines, reads = {}, {}
    local lines = "\n" .. content
    for name in lines:gmatch("\nfunction ([%a_][%w_]*)%s*%(") do defines[name] = true end
    for name in lines:gmatch("\n([%a_][%w_]*)%s*=[^=]") do defines[name] = true end
    -- members a file adds to a table another file creates: function T.m(, function T:m(, T.m =
    for table, member in lines:gmatch("\nfunction ([%a_][%w_]*)[%.:]([%a_][%w_]*)%s*%(") do defines[table .. "." .. member] = true end
    for table, member in lines:gmatch("\n([%a_][%w_]*)%.([%a_][%w_]*)%s*=[^=]") do defines[table .. "." .. member] = true end
    local code = content:gsub("%-%-%[(=*)%[.-%]%1%]", ""):gsub("%-%-[^\n]*", "")
    for name in code:gmatch("[%a_][%w_]*") do reads[name] = true end
    for table, member in code:gmatch("([%a_][%w_]*)[%.:]([%a_][%w_]*)") do reads[table .. "." .. member] = true end
    return defines, reads
end

local plans = {}

---the Blizzard Lua files the world loads for a client, in load order, and which globals each defines
---@param client string
---@param wanted string[] globals the addon reads
function M.Plan(client, wanted)
    if plans[client] then return plans[client] end
    local files, byGlobal, byMember = {}, {}, {}
    for _, file in ipairs(M.AddonFiles(client)) do
        if not file.onDemand and file.path:find("%.lua$") then
            local content = assert(Toc.Read(file.path))
            local defines, reads = scan(content)
            local entry = { path = file.path, defines = defines, reads = reads, index = #files + 1 }
            files[#files + 1] = entry
            for name in pairs(defines) do
                byGlobal[name] = byGlobal[name] or entry
                -- a table's members may be defined in several files
                if name:find("%.") then
                    byMember[name] = byMember[name] or {}
                    table.insert(byMember[name], entry)
                end
            end
        end
    end
    local selected, queue = {}, {}
    local function select(entry)
        if entry and not selected[entry] then
            selected[entry] = true
            queue[#queue + 1] = entry
        end
    end
    local function want(name)
        select(byGlobal[name])
        for _, entry in ipairs(byMember[name] or {}) do select(entry) end
    end
    for _, name in ipairs(wanted) do want(name) end
    while #queue > 0 do
        local entry = table.remove(queue)
        for name in pairs(entry.reads) do want(name) end
    end
    local plan = { files = {}, byGlobal = byGlobal }
    for _, entry in ipairs(files) do
        if selected[entry] then plan.files[#plan.files + 1] = entry end
    end
    plans[client] = plan
    return plan
end

---loads the planned files into the world; returns the failures as { path = message }
function M.Load(world, plan)
    local failures = {}
    -- every file of an addon gets the addon's name and the one namespace table of that addon
    local namespaces = {}
    for _, entry in ipairs(plan.files) do
        -- the client's color objects exist once CreateColor does (client_dump.lua)
        require("spec.helpers.client_dump").InstallColors(world, world.env)
        local chunk, message = Toc.LoadLua(entry.path)
        if chunk then
            setfenv(chunk, world.env)
            local addon = entry.path:match("AddOns/([^/]+)")
            namespaces[addon] = namespaces[addon] or {}
            local ok, err = pcall(chunk, addon, namespaces[addon])
            if not ok then failures[entry.path] = err end
        else
            failures[entry.path] = message
        end
    end
    return failures
end

---the globals .luacheckrc declares the addon reads
function M.AddonGlobals(rcPath)
    local rc = assert(Toc.Read(rcPath or ".luacheckrc"))
    local names = {}
    for name in rc:match("read_globals = (%b{})"):gmatch('"([%w_]+)"') do names[#names + 1] = name end
    return names
end

return M
