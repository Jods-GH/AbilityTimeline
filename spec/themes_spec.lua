-- The themes (Themes/, registered through private.RegisterTheme in Util/Theme.lua) and the media they ship, checked
-- in the whole addon on a Retail and a Classic client.
local Docs = require("spec.helpers.api_docs")
local Toc = require("spec.helpers.toc")
local World = require("spec.helpers.world")
local WholeAddon = require("spec.helpers.whole_addon")

local CLIENTS = { "retail", "vanilla" }

local function themeScripts()
    local count = 0
    for _, entry in ipairs(Toc.XmlEntries(World.ROOT .. "/Themes/Themes.xml")) do
        if entry.tag == "Script" then count = count + 1 end
    end
    return count
end

local function isColor(value)
    if type(value) ~= "table" then return false end
    local r, g, b, a = value.r or value[1], value.g or value[2], value.b or value[3], value.a or value[4] or 1
    for _, channel in ipairs({ r, g, b, a }) do
        if type(channel) ~= "number" or channel < 0 or channel > 1 then return false end
    end
    return true
end

-- string values of keys named Color or ...Color anywhere in a resolved style
local function colorNames(style, found, path)
    found, path = found or {}, path or ""
    for key, value in pairs(style) do
        local here = path .. "." .. tostring(key)
        if type(value) == "table" then
            colorNames(value, found, here)
        elseif type(value) == "string" and type(key) == "string" and key:find("Color$") then
            found[#found + 1] = { name = value, path = here }
        end
    end
    return found
end

for _, client in ipairs(CLIENTS) do
    describe("themes on " .. client, function()
        local handle, private
        before_each(function()
            handle = WholeAddon.Load({ client = client }):Start()
            private = handle.private
        end)

        it("registers one theme per Themes.xml script, Classic among them", function()
            local count = 0
            for _ in pairs(private.Themes) do count = count + 1 end
            assert.equals(themeScripts(), count)
            assert.is_table(private.Themes[private.DEFAULT_THEME])
        end)

        it("describes every theme with the keys the engine reads", function()
            local weather, periods, classSpecs = {}, {}, {}
            for _, name in ipairs(private.WEATHER_TYPES) do weather[name] = true end
            for _, period in ipairs(private.TIME_PERIODS) do periods[period.Name] = true end
            for key, theme in pairs(private.Themes) do
                assert.equals(key, theme.Name)
                assert.is_string(theme.DisplayName, key)
                local parent, depth = theme.Parent, 0
                while parent do
                    assert.is_table(private.Themes[parent], key .. ": unknown parent " .. parent)
                    depth = depth + 1
                    assert.is_true(depth < 10, key .. " inherits from itself")
                    parent = private.Themes[parent].Parent
                end
                if theme.Weather then assert.is_true(weather[theme.Weather], key .. ": weather " .. theme.Weather) end
                for period in pairs(theme.TimeOfDay or {}) do
                    assert.is_true(periods[period] == true, key .. ": period " .. period)
                end
                local from = -math.huge
                for _, level in ipairs(theme.ByIntensity or {}) do
                    assert.is_true((level.From or 0) >= from, key .. ": ByIntensity is not ordered by From")
                    from = level.From or 0
                end
                if theme.Spec ~= nil then
                    assert.is_string(theme.Class, key .. ": Spec without Class")
                    assert.is_true(theme.Spec == false or (type(theme.Spec) == "number" and theme.Spec >= 1), key .. ": Spec")
                end
                if theme.Class then
                    -- class themes cover Retail's classes; Classic clients lack some and show those themes by name
                    if Docs.CLIENTS[client].retail then
                        assert.is_table(handle.world.dump.classes[theme.Class], key .. ": unknown class " .. theme.Class)
                    end
                    local classSpec = theme.Class .. ":" .. tostring(theme.Spec)
                    assert.is_nil(classSpecs[classSpec], key .. ": another theme has " .. classSpec)
                    classSpecs[classSpec] = key
                end
                -- a palette entry is a color or a "$Variable" the engine substitutes while resolving
                for name, color in pairs(theme.Palette or {}) do
                    local variable = type(color) == "string" and color:match("^%$(.+)$")
                    assert.is_true(isColor(color) or variable ~= nil, key .. ": Palette." .. name .. " is not a color")
                end
            end
        end)

        it("resolves and applies every available theme without errors or unknown colors and textures", function()
            local ThemeApply = private.ThemeApply
            local color, file = ThemeApply.Color, ThemeApply.File
            local unknown = {}
            ThemeApply.Color = function(value, ...)
                if type(value) == "string" then
                    local palette = private.GetCurrentTheme().Palette
                    if not (palette and palette[value]) then unknown[#unknown + 1] = private.GetCurrentThemeKey() .. ": color " .. value end
                end
                return color(value, ...)
            end
            ThemeApply.File = function(name, ...)
                local path = file(name, ...)
                if path == nil then unknown[#unknown + 1] = private.GetCurrentThemeKey() .. ": texture " .. tostring(name) end
                return path
            end
            local applied = 0
            for key in pairs(private.Themes) do
                if private.IsThemeAvailable(key) then
                    applied = applied + 1
                    private.ApplyTheme(key, true)
                    local style = private.GetCurrentTheme()
                    assert.equals(key, private.GetCurrentThemeKey())
                    for name, value in pairs(style.Palette) do
                        if not isColor(value) then unknown[#unknown + 1] = key .. ": resolved Palette." .. name .. " is not a color" end
                    end
                    for _, reference in ipairs(colorNames(style)) do
                        if not style.Palette[reference.name] then
                            unknown[#unknown + 1] = key .. ": " .. reference.path .. " names color " .. reference.name
                        end
                    end
                    handle.world.clock.Advance(0.1)
                end
            end
            ThemeApply.Color, ThemeApply.File = color, file
            assert.is_true(applied > 10)
            assert.same({}, unknown)
            assert.same({}, handle.errors)
        end)

        it("ships every media file it registers", function()
            local SharedMedia = LibStub("LibSharedMedia-3.0")
            local prefix = "interface/addons/abilitytimeline/"
            local checked, missing = 0, {}
            for _, mediaType in ipairs({ "font", "background", "border", "statusbar", "sound", private.ThemeMediaType }) do
                for name, path in pairs(SharedMedia:HashTable(mediaType) or {}) do
                    if type(path) == "string" and path:gsub("\\", "/"):lower():sub(1, #prefix) == prefix then
                        checked = checked + 1
                        if not World.FileExists(path:gsub("\\", "/"):sub(#prefix + 1)) then
                            missing[#missing + 1] = mediaType .. " " .. name .. ": " .. path
                        end
                    end
                end
            end
            assert.is_true(checked > 100)
            assert.same({}, missing)
        end)
    end)
end
