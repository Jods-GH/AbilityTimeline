-- AbilityTimeline.toc and the XML files it includes: what each client loads (spec/helpers/toc.lua follows
-- warcraft.wiki.gg/wiki/TOC_format).
local Docs = require("spec.helpers.api_docs")
local Toc = require("spec.helpers.toc")
local World = require("spec.helpers.world")

local TOC = World.ROOT .. "/AbilityTimeline.toc"
-- folders whose Lua the client never loads from this addon: libraries, tests, tooling, docs and reference trees
local NOT_ADDON = { "Libs", "spec", "tools", ".git", ".github", ".claude", ".codex", ".vscode", "openwiki", "wow ui source", "Media" }

local function maintainedLuaFiles()
    local files = {}
    local prune = {}
    for _, folder in ipairs(NOT_ADDON) do prune[#prune + 1] = ('-path "./%s" -prune'):format(folder) end
    local listing = io.popen('cd "' .. World.ROOT .. '" && find . \\( ' .. table.concat(prune, " -o ") .. ' \\) -o -name "*.lua" -print')
    for path in listing:lines() do files[#files + 1] = path:gsub("^%./", "") end
    listing:close()
    return files
end

-- every file the TOC lists for a game type, the addon's own (Libs/ is the packager's), as repository paths
local function addonFiles(gameType)
    local files = {}
    for _, file in ipairs(Toc.Files(TOC, gameType, function(path)
        path = path:gsub("^%./", "")
        if path:find("^Libs/") or path == "embeds.xml" then return nil end
        return path
    end)) do
        files[#files + 1] = file.path
    end
    return files
end

describe("AbilityTimeline.toc", function()
    it("lists only files that exist, with their exact case", function()
        for gameType in pairs(Toc.GAME_TYPES) do
            for _, path in ipairs(addonFiles(gameType)) do
                assert.is_true(Toc.Exists(path), path .. " (" .. gameType .. ")")
            end
        end
    end)

    it("loads every maintained Lua file, each once", function()
        local listed = {}
        for gameType in pairs(Toc.GAME_TYPES) do
            local seen = {}
            for _, path in ipairs(addonFiles(gameType)) do
                assert.is_nil(seen[path], path .. " is listed twice for " .. gameType)
                seen[path] = true
                listed[path] = true
            end
        end
        for _, path in ipairs(maintainedLuaFiles()) do
            assert.is_true(listed[path] == true, path .. " is not loaded by the TOC")
        end
    end)

    it("never allows and excludes the same game type on one line", function()
        for _, entry in ipairs(Toc.Parse(TOC).entries) do
            local allow, exclude = {}, entry.directives.ExcludeLoadGameType or {}
            for _, gameType in ipairs(entry.directives.AllowLoadGameType or {}) do allow[gameType] = true end
            for _, gameType in ipairs(exclude) do
                assert.is_nil(allow[gameType], entry.path .. " both allows and excludes " .. gameType)
            end
        end
    end)

    for _, client in ipairs(Docs.CLIENT_ORDER) do
        it("loads exactly one cooldown and one encounter data file on " .. client, function()
            local cooldowns, encounters = 0, 0
            for _, path in ipairs(addonFiles(Docs.CLIENTS[client].gameType)) do
                if path:find("^Data/Cooldowns/") then cooldowns = cooldowns + 1 end
                if path:find("^Data/Encounters/") then encounters = encounters + 1 end
            end
            assert.equals(1, cooldowns)
            assert.equals(1, encounters)
        end)
    end

    it("finds every library embeds.xml includes in the packaged externals", function()
        local depsPattern = "^" .. Docs.DEPS:gsub("%p", "%%%0") .. "/"
        local libraries = 0
        for _, file in ipairs(World.TocFiles("standard", function(path)
            return path:find("embeds%.xml$") or path:find(depsPattern)
        end)) do
            if file.path:find(depsPattern) then
                libraries = libraries + 1
                assert.is_true(Toc.Exists(file.path), file.path)
            end
        end
        assert.is_true(libraries > 0)
    end)
end)
