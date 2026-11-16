-- toc.lua: the files a client loads from a TOC, by warcraft.wiki.gg/wiki/TOC_format:
-- - a TOC with a client suffix (Name_Vanilla.toc, Name_Mainline.toc) is used instead of the plain one
-- - "[AllowLoadGameType a, b]" and "[ExcludeLoadGameType a, b]" after a file limit it to (or exclude it from) the
--   named game types; a family name (mainline, classic) stands for every game type of the family
-- - [Family] and [Game] in a path are replaced by the client's family and game names
-- - XML files load their <Script file> and <Include file> entries in order, relative to the XML file
-- Used for the addon's TOC and for Blizzard's own addons in the UI source.
local M = {}

-- Game type (as the TOC directives name it) -> family, [Game] name and TOC suffixes, most specific first.
M.GAME_TYPES = {
    standard = { family = "Mainline", game = "Standard", suffixes = { "Standard", "Mainline" } },
    forever = { family = "Mainline", game = "Forever", suffixes = { "Forever", "Mainline" } },
    mists = { family = "Classic", game = "Mists", suffixes = { "Mists", "Classic" } },
    cata = { family = "Classic", game = "Cata", suffixes = { "Cata", "Classic" } },
    wrath = { family = "Classic", game = "Wrath", suffixes = { "Wrath", "Classic" } },
    tbc = { family = "Classic", game = "TBC", suffixes = { "TBC", "Classic" } },
    vanilla = { family = "Classic", game = "Vanilla", suffixes = { "Vanilla", "Classic" } },
}

local function read(path)
    local file = io.open(path, "rb")
    if not file then return nil end
    local content = file:read("*a")
    file:close()
    return content
end
M.Read = read

local function exists(path)
    local file = io.open(path, "rb")
    if file then file:close() end
    return file ~= nil
end
M.Exists = exists

local function directory(path)
    return path:match("^(.*)/[^/]*$") or "."
end

local function list(value)
    local items = {}
    for item in value:gmatch("[^,%s]+") do items[#items + 1] = item:lower() end
    return items
end

---whether a list of game types or families names gameType
local function names(items, gameType)
    local family = M.GAME_TYPES[gameType].family:lower()
    for _, item in ipairs(items) do
        if item == gameType or item == family then return true end
    end
    return false
end

---whether "[AllowLoadGameType ...]"/"[ExcludeLoadGameType ...]" directives let gameType load
function M.Allows(directives, gameType)
    if directives.AllowLoadGameType and not names(directives.AllowLoadGameType, gameType) then return false end
    if directives.ExcludeLoadGameType and names(directives.ExcludeLoadGameType, gameType) then return false end
    return true
end

---the TOC a client uses from an addon folder: the most specific suffixed TOC, else the plain one
function M.Pick(folder, addonName, gameType)
    for _, suffix in ipairs(M.GAME_TYPES[gameType].suffixes) do
        local path = folder .. "/" .. addonName .. "_" .. suffix .. ".toc"
        if exists(path) then return path end
    end
    return folder .. "/" .. addonName .. ".toc"
end

---the lines of a TOC: { metadata = { [name] = value }, entries = { { path, directives, line } } }
function M.Parse(path)
    local content = assert(read(path), "missing TOC " .. path)
    local parsed = { metadata = {}, entries = {} }
    local number = 0
    for line in (content .. "\n"):gmatch("([^\n]*)\n") do
        number = number + 1
        line = line:gsub("\r$", ""):gsub("^\239\187\191", "")
        local key, value = line:match("^##%s*([^:]+):%s*(.-)%s*$")
        if key then
            parsed.metadata[key] = value
        elseif not line:find("^%s*#") and line:find("%S") then
            local directives = {}
            local entry = line:gsub("%s*%[(%a+)%s+([^%]]*)%]", function(name, value)
                directives[name] = list(value)
                return ""
            end)
            entry = entry:gsub("^%s+", ""):gsub("%s+$", "")
            parsed.entries[#parsed.entries + 1] = { path = entry, directives = directives, line = number }
        end
    end
    return parsed
end

---the <Script file> and <Include file> entries of an XML file, in order
function M.XmlEntries(path)
    local content = assert(read(path), "missing XML " .. path)
    local entries = {}
    content = content:gsub("<!%-%-.-%-%->", "")
    for tag, file in content:gmatch("<(%a+)%s+file%s*=%s*\"([^\"]+)\"") do
        if tag == "Script" or tag == "Include" then
            entries[#entries + 1] = { tag = tag, file = file:gsub("\\", "/") }
        end
    end
    return entries
end

---every file a client loads from a TOC, in order: { path, from }, Lua files and XML files, with XML expanded
---@param tocPath string
---@param gameType string
---@param resolve fun(path: string): string|nil maps a TOC-relative path to the file to read (default: as is)
---@return table[] files, table toc
function M.Files(tocPath, gameType, resolve)
    resolve = resolve or function(path) return path end
    local info = M.GAME_TYPES[gameType]
    local toc = M.Parse(tocPath)
    local files = {}
    local function add(path, from)
        local resolved = resolve(path)
        if not resolved then return end
        files[#files + 1] = { path = resolved, from = from, listed = path }
        if resolved:lower():find("%.xml$") then
            local base = directory(path)
            for _, entry in ipairs(M.XmlEntries(resolved)) do
                add(base .. "/" .. entry.file, resolved)
            end
        end
    end
    local base = directory(tocPath)
    for _, entry in ipairs(toc.entries) do
        if M.Allows(entry.directives, gameType) then
            local path = entry.path:gsub("\\", "/"):gsub("%[Family%]", info.family):gsub("%[Game%]", info.game)
            add(base .. "/" .. path, tocPath)
        end
    end
    return files, toc
end

return M
