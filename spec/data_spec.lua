-- The data under Data/: each client's generated cooldown and encounter tables (written by .github/Scripts from
-- wago.tools) checked against that client's own class and specialization tables, and the hand-kept constants.
local Docs = require("spec.helpers.api_docs")
local Toc = require("spec.helpers.toc")
local World = require("spec.helpers.world")
local Addon = require("spec.helpers.addon_loader")

-- the data file of a kind the TOC loads on a client
local function dataFile(client, kind)
    local files = Toc.Files(World.ROOT .. "/AbilityTimeline.toc", Docs.CLIENTS[client].gameType, function(path)
        path = path:gsub("^%./", "")
        if path:find("^Data/" .. kind .. "/") then return path end
        return nil
    end)
    return assert(files[1], "no " .. kind .. " data on " .. client).path
end

-- keys a table constructor in the source text lists more than once (Lua keeps the last silently)
local function duplicateKeys(content, tableName)
    local body = content:match("private%." .. tableName .. " = (%b{})")
    local seen, duplicates = {}, {}
    for key in body:gmatch("\n%s*%[(%-?%d+)%]%s*=") do
        if seen[key] then duplicates[#duplicates + 1] = key end
        seen[key] = true
    end
    return duplicates
end

describe("cooldown data", function()
    for _, client in ipairs(Docs.CLIENT_ORDER) do
        it("names the classes and specializations of " .. client, function()
            local world = World.Build({ client = client, libraries = false })
            local path = dataFile(client, "Cooldowns")
            local private = Addon.Load(path)
            local classes, specs = world.dump.classes, world.dump.specs
            local hasSpecs = next(specs) ~= nil
            local count = 0
            for spellID, cooldown in pairs(private.Cooldowns) do
                count = count + 1
                local label = ("%s spell %d"):format(path, spellID)
                assert.is_number(spellID, label)
                assert.is_table(classes[cooldown.class], label .. ": unknown class " .. tostring(cooldown.class))
                assert.is_true(type(cooldown.cooldown) == "number" and cooldown.cooldown > 0, label .. ": cooldown")
                local seen = {}
                for _, specID in ipairs(cooldown.specs) do
                    assert.is_nil(seen[specID], label .. ": spec listed twice")
                    seen[specID] = true
                    if hasSpecs then
                        assert.is_table(specs[specID], label .. ": unknown spec " .. specID)
                        assert.equals(cooldown.class, specs[specID].class, label .. ": spec of another class")
                    end
                end
                if not hasSpecs then assert.same({}, cooldown.specs, label .. ": specs on a client without them") end
            end
            assert.is_true(count > 0)
            assert.same({}, duplicateKeys(Toc.Read(path), "Cooldowns"))
        end)
    end
end)

describe("encounter data", function()
    for _, client in ipairs(Docs.CLIENT_ORDER) do
        it("links the encounters and instances of " .. client, function()
            World.Build({ client = client, libraries = false })
            local path = dataFile(client, "Encounters")
            local private = Addon.Load(path)
            for map, instance in pairs(private.EncounterInstances) do
                assert.is_string(instance.name, path .. " instance " .. map)
                assert.is_true(instance.journalInstanceID == nil or type(instance.journalInstanceID) == "number")
            end
            for id, encounter in pairs(private.Encounters) do
                local label = ("%s encounter %d"):format(path, id)
                assert.is_string(encounter.name, label)
                assert.is_number(encounter.order, label)
                assert.is_table(private.EncounterInstances[encounter.map], label .. ": unknown map " .. tostring(encounter.map))
                assert.is_true(encounter.journalEncounterID == nil or type(encounter.journalEncounterID) == "number", label)
            end
            for _, current in ipairs(private.CurrentInstances) do
                assert.is_table(private.EncounterInstances[current.map], path .. ": current map " .. tostring(current.map))
                for _, id in ipairs(current.encounters) do
                    assert.is_table(private.Encounters[id], path .. ": current encounter " .. id)
                    assert.equals(current.map, private.Encounters[id].map, path .. ": current encounter " .. id .. " of another map")
                end
            end
            local content = Toc.Read(path)
            assert.same({}, duplicateKeys(content, "EncounterInstances"))
            assert.same({}, duplicateKeys(content, "Encounters"))
        end)
    end
end)

describe("constants", function()
    it("sorts every Retail damage and tank specialization into melee or ranged once", function()
        local world = World.Build({ client = "retail", libraries = false })
        local private = Addon.Load("Data/specPosition.lua")
        local seen = {}
        for _, position in ipairs({ "melee", "ranged" }) do
            for _, specID in ipairs(private.SpecPosition[position]) do
                assert.is_nil(seen[specID], specID .. " is listed twice")
                seen[specID] = position
                assert.is_table(world.dump.specs[specID], "unknown spec " .. specID)
            end
        end
    end)

    it("gives each dispel type its own bit and a color in range", function()
        World.Build({ libraries = false })
        local private = Addon.Load("Data/constants.lua")
        local masks = {}
        for _, dispel in ipairs(private.dispellTypeList) do
            local mask = dispel.mask
            assert.is_true(mask > 0 and bit.band(mask, mask - 1) == 0, dispel.name .. ": mask is not one bit")
            assert.is_nil(masks[mask], dispel.name .. ": mask shared")
            masks[mask] = true
            for _, channel in ipairs({ "r", "g", "b", "a" }) do
                assert.is_true(dispel.color[channel] >= 0 and dispel.color[channel] <= 1, dispel.name .. "." .. channel)
            end
        end
    end)
end)
