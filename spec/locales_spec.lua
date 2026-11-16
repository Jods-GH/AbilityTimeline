-- Localisation (Locales/): enUS is the default locale every key the addon asks for must exist in; the other locale
-- files are filled by the packager (--@localization@) and register as non-default locales. AceLocale-3.0 reports a
-- missing entry of the default locale to the error handler, so keys built at runtime are caught by the whole-addon
-- specs; this spec checks the keys the source names literally.
local Toc = require("spec.helpers.toc")
local World = require("spec.helpers.world")
local Addon = require("spec.helpers.addon_loader")

local LOCALES = { "deDE", "esES", "esMX", "frFR", "itIT", "koKR", "ptBR", "ruRU", "zhCN", "zhTW" }

local function enUSKeys()
    local keys, duplicates = {}, {}
    for key in Toc.Read(World.ROOT .. "/Locales/enUS.lua"):gmatch("L%[%s*[\"']([^\"']+)[\"']%s*%]%s*=") do
        if keys[key] then duplicates[#duplicates + 1] = key end
        keys[key] = true
    end
    return keys, duplicates
end

-- literal keys: private.getLocalisation("Key"), and L("Key") in files that alias L to it
local function literalKeys()
    local keys = {}
    for gameType in pairs(Toc.GAME_TYPES) do
        for _, file in ipairs(Toc.Files(World.ROOT .. "/AbilityTimeline.toc", gameType, function(path)
            path = path:gsub("^%./", "")
            if path:find("^Libs/") or path == "embeds.xml" or path:find("^Locales/") then return nil end
            return path
        end)) do
            if file.path:find("%.lua$") then
                local content = Toc.Read(file.path)
                local function add(key) keys[key] = keys[key] or file.path end
                for key in content:gmatch("getLocalisation%(%s*[\"']([^\"']+)[\"']%s*%)") do add(key) end
                if content:find("local%s+L%s*=%s*private%.getLocalisation") then
                    for key in content:gmatch("[^%w_]L%(%s*[\"']([^\"']+)[\"']%s*%)") do add(key) end
                end
            end
        end
    end
    return keys
end

describe("localisation", function()
    it("has every literally named key in enUS", function()
        local keys = enUSKeys()
        local found = 0
        for key, path in pairs(literalKeys()) do
            found = found + 1
            assert.is_true(keys[key] == true, ("%s (used in %s) is missing from Locales/enUS.lua"):format(key, path))
        end
        assert.is_true(found > 100)
    end)

    it("defines each enUS key once", function()
        local _, duplicates = enUSKeys()
        assert.same({}, duplicates)
    end)

    it("serves enUS as the default locale", function()
        World.Build()
        local private = Addon.Load({ "Locales/enUS.lua", "Locales/Locales.lua" })
        assert.equals("Edit Reminders for Encounter", private.getLocalisation("EditRemindersForEncounter"))
    end)

    for _, locale in ipairs(LOCALES) do
        it("registers " .. locale .. " as a non-default locale that loads on its client", function()
            local content = Toc.Read(World.ROOT .. "/Locales/" .. locale .. ".lua")
            assert.truthy(content:find(('NewLocale%%(appName, "%s"%%)'):format(locale)))
            local world = World.Build({ locale = locale })
            local private = Addon.Load({ "Locales/enUS.lua", "Locales/" .. locale .. ".lua" })
            assert.is_table(private.localisation)
            assert.same({}, world.errors)
        end)
    end
end)
