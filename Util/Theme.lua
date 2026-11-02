local appName, app = ...
---@class AbilityTimeline
local private = app
local SharedMedia = LibStub("LibSharedMedia-3.0")

-- Theme engine inspired by BetterBags' Sonata (https://github.com/Cidan/BetterBags), used with permission.
-- A theme is data: Windows and Elements styles, inherited from its Parent (Classic when unset), with
-- per client overrides (Clients.Retail / Clients.Classic) and "$Name" values taken from its Variables.
-- The player's modifications of a theme are stored per theme in the profile and merged on top.
-- Besides a theme, the player can choose an automatic selection (AUTO_THEMES) that picks a theme for the character.
-- Weather themes are made for an Enum.WeatherType name; only clients with C_Weather can pick them automatically.
-- TimeOfDay overrides a theme per period of the realm's day (GetGameTime), faded in as the period changes.

private.DEFAULT_THEME = "Classic"
private.THEME_PROMPT_VERSION = 6
private.Themes = {}

local META_KEYS = {
    Name = true,
    DisplayName = true,
    Description = true,
    Parent = true,
    Available = true,
    Hidden = true,
    Clients = true,
    SharedMedia = true,
    Class = true,
    Spec = true,
    Weather = true,
    TimeOfDay = true,
}

local EMPTY = {}
local themedWidgets = setmetatable({}, { __mode = "k" })
local currentKey
local resolved
local resolvedPeriod
local paletteFade

local isList = function(value)
    return type(value) == "table" and value[1] ~= nil
end

local function deepCopy(value)
    if type(value) ~= "table" then
        return value
    end
    local copy = {}
    for k, v in pairs(value) do
        copy[k] = deepCopy(v)
    end
    return copy
end
private.DeepCopy = deepCopy

---merges from into into, tables merge key by key while lists and values replace
---@param into table
---@param from table
local function merge(into, from)
    for k, v in pairs(from) do
        local existing = into[k]
        if type(v) == "table" and not isList(v) and type(existing) == "table" and not isList(existing) then
            merge(existing, v)
        else
            into[k] = deepCopy(v)
        end
    end
end
private.MergeTables = merge

local function substitute(value, variables)
    if type(value) == "string" then
        local name = value:match("^%$([%a_][%w_]*)$")
        if not name then
            return value
        end
        if variables[name] == nil then
            error("AbilityTimeline: theme variable $" .. name .. " is not defined")
        end
        return deepCopy(variables[name])
    end
    if type(value) == "table" then
        for k, v in pairs(value) do
            value[k] = substitute(v, variables)
        end
    end
    return value
end

local styleOf = function(theme)
    local style = {}
    for k, v in pairs(theme) do
        if not META_KEYS[k] then
            style[k] = v
        end
    end
    return style
end

---returns the themes key inherits from, the root (Classic) first
---@param key string
---@return table[]
local getChain = function(key)
    local chain = {}
    local name = key
    while name do
        local theme = private.Themes[name]
        if not theme then
            error("AbilityTimeline: theme " .. tostring(name) .. " is not registered")
        end
        if #chain > 10 then
            error("AbilityTimeline: theme " .. key .. " inherits from itself")
        end
        table.insert(chain, 1, theme)
        if name == private.DEFAULT_THEME then
            name = nil
        else
            name = theme.Parent or private.DEFAULT_THEME
        end
    end
    return chain
end

-- the periods of the realm's day, from the minute of the day they start at; the game's own day and night switch at
-- 5:30 and 21:00 (Blizzard_Minimap's GAMETIME_DAWN and GAMETIME_DUSK), morning and evening are our own
private.TIME_PERIODS = {
    { Name = "Morning", Start = 5 * 60 + 30 },
    { Name = "Midday", Start = 9 * 60 },
    { Name = "Evening", Start = 17 * 60 },
    { Name = "Night", Start = 21 * 60 },
}
-- seconds a theme fades into another when the weather changes and when the period changes
local WEATHER_FADE = 4
local PERIOD_FADE = 20
private.PERIOD_FADE = PERIOD_FADE
-- the period /at test time pretends, nil for the real one
local testPeriod

---the period of the realm's day it is now, "Morning", "Midday", "Evening" or "Night"
---@return string
private.GetTimePeriod = function()
    if testPeriod then
        return testPeriod
    end
    local hour, minute = GetGameTime()
    local now = hour * 60 + minute
    local period = private.TIME_PERIODS[#private.TIME_PERIODS].Name
    for _, entry in ipairs(private.TIME_PERIODS) do
        if now >= entry.Start then
            period = entry.Name
        end
    end
    return period
end

---@param key string
---@return table
local resolve = function(key)
    local client = private.isRetail and "Retail" or "Classic"
    resolvedPeriod = private.GetTimePeriod()
    local style = {}
    for _, theme in ipairs(getChain(key)) do
        merge(style, styleOf(theme))
        if theme.Clients and theme.Clients[client] then
            merge(style, styleOf(theme.Clients[client]))
        end
        if theme.TimeOfDay and theme.TimeOfDay[resolvedPeriod] then
            merge(style, styleOf(theme.TimeOfDay[resolvedPeriod]))
        end
    end
    local variables = {}
    for name, value in pairs(style.Variables or EMPTY) do
        if type(value) == "function" then
            value = value()
        end
        variables[name] = value
    end
    style.Variables = nil
    substitute(style, variables)
    local modifications = private.GetThemeSettings().modifications[key]
    if modifications then
        merge(style, modifications)
    end
    style.Windows = style.Windows or {}
    style.Elements = style.Elements or {}
    return style
end

---the theme settings of the profile
---@return table
private.GetThemeSettings = function()
    if not private.db.profile.theme then
        private.db.profile.theme = { key = private.DEFAULT_THEME, promptVersion = 0, modifications = {} }
    end
    return private.db.profile.theme
end

---registers a theme and the media it ships, SharedMedia = { font = { [name] = path }, background = { ... } }
---@param theme table
private.RegisterTheme = function(theme)
    private.Themes[theme.Name] = theme
    for mediaType, media in pairs(theme.SharedMedia or EMPTY) do
        for name, path in pairs(media) do
            SharedMedia:Register(mediaType, name, path)
        end
    end
end

---the theme made for class (a class file name such as "MAGE") and its spec index, or for the class alone without spec
---@param class string
---@param spec number|nil
---@return string|nil
local findClassTheme = function(class, spec)
    for key, theme in pairs(private.Themes) do
        if theme.Class == class and theme.Spec == spec and private.IsThemeAvailable(key) then
            return key
        end
    end
end

---@return string
local resolveClassTheme = function()
    local _, class = UnitClass("player")
    return findClassTheme(class) or private.DEFAULT_THEME
end

-- the weather types in the order their themes are listed, as named in Enum.WeatherType
private.WEATHER_TYPES = { "Clear", "Rain", "Snow", "Sandstorm", "Miscellaneous" }

local weatherName, weatherIntensity
-- the weather /at test weather pretends, nil for the real one
local testWeather

---reads the weather around the player, its Enum.WeatherType name and intensity, nil on clients without C_Weather and
---for a type the enum doesn't list (newer clients add some, e.g. Firestorm in Windrunner Spire, and since 12.1 the
---weather can be unknown right after login)
---@return string|nil
private.UpdateWeather = function()
    if testWeather then
        weatherName, weatherIntensity = testWeather, 1
        return testWeather
    end
    if not C_Weather then
        return nil
    end
    local info = C_Weather.GetCurrentWeather()
    local name
    for key, value in pairs(Enum.WeatherType) do
        if value == info.type then
            name = key
        end
    end
    -- intensity isn't documented, the Weather addon (keyboardturner) treats it as 0 to 1, light up to 0.1, medium up
    -- to 0.5; logged to check in game
    local intensity = math.min(math.max(info.intensity or 1, 0), 1)
    if name ~= weatherName or intensity ~= weatherIntensity then
        private.DebugLog(string.format("weather %s (%s) intensity %s", tostring(name), tostring(info.type), tostring(info.intensity)))
    end
    weatherName, weatherIntensity = name, intensity
    return name
end

---how strong the current theme's weather is, 0 to 1: the game's intensity while the weather around the player is the
---theme's, otherwise 1, so a weather theme chosen by hand shows its full weather
---@return number
private.GetWeatherIntensity = function()
    local theme = private.Themes[private.GetCurrentThemeKey()]
    if weatherName and theme and theme.Weather == weatherName then
        return weatherIntensity
    end
    return 1
end

---the theme made for a weather type such as "Rain"
---@param weather string
---@return string|nil
local findWeatherTheme = function(weather)
    for key, theme in pairs(private.Themes) do
        if theme.Weather == weather and private.IsThemeAvailable(key) then
            return key
        end
    end
end

-- the automatic selections in the order they are listed, each picks the theme for the current character
private.AUTO_THEMES = { "Spec", "Class" }
local autoResolvers = {
    Spec = function()
        local _, class = UnitClass("player")
        local spec = C_SpecializationInfo.GetSpecialization()
        return spec and spec > 0 and findClassTheme(class, spec) or resolveClassTheme()
    end,
    Class = resolveClassTheme,
}

-- the weather theme for the weather outside, the clear weather theme for weather without a theme of its own; clients
-- before C_Weather have neither the API nor WEATHER_CHANGED and don't offer it
if C_Weather then
    table.insert(private.AUTO_THEMES, "Weather")
    autoResolvers.Weather = function()
        local weather = private.UpdateWeather()
        return weather and findWeatherTheme(weather) or findWeatherTheme("Clear") or private.DEFAULT_THEME
    end
end

---@param key string
---@return boolean
private.IsAutoTheme = function(key)
    return autoResolvers[key] ~= nil
end

---the theme key behind key, the theme an automatic selection currently picks
---@param key string
---@return string
private.ResolveThemeKey = function(key)
    if autoResolvers[key] then
        return autoResolvers[key]()
    end
    return key
end

---@param key string
---@return boolean
private.IsThemeAvailable = function(key)
    if autoResolvers[key] then
        return true
    end
    local theme = private.Themes[key]
    if not theme or theme.Hidden then
        return false
    end
    if type(theme.Available) == "function" then
        return theme.Available() and true or false
    end
    return theme.Available ~= false
end

---the localized name of a class file name such as "MAGE", the name of its class theme on clients without the class
---@param class string
---@return string
private.GetClassName = function(class)
    if LOCALIZED_CLASS_NAMES_MALE[class] then
        return LOCALIZED_CLASS_NAMES_MALE[class]
    end
    for _, theme in pairs(private.Themes) do
        if theme.Class == class and theme.Spec == nil then
            return theme.DisplayName or class
        end
    end
    return class
end

---the group a theme is listed in: the themes made for no class or weather first, then the weather themes, then the classes
---@param theme table
---@return number
local groupOrder = function(theme)
    if theme.Class then
        return 2
    end
    return theme.Weather and 1 or 0
end

---where a weather theme is listed, in the order of WEATHER_TYPES
---@param theme table
---@return number
local weatherOrder = function(theme)
    for i, weather in ipairs(private.WEATHER_TYPES) do
        if theme.Weather == weather then
            return i
        end
    end
    return #private.WEATHER_TYPES + 1
end

---where a theme is listed within its class: the class theme first, then the specs, specs the client lacks (Spec false) last
---@param theme table
---@return number
local specOrder = function(theme)
    if theme.Spec == nil then
        return 0
    end
    return theme.Spec or 99
end

---returns all themes that can be listed: Classic and the themes made for no class first, then the weather themes, then
---each class with its class theme before its spec themes
---@return table[]
private.GetSelectableThemes = function()
    local themes = {}
    for _, theme in pairs(private.Themes) do
        if not theme.Hidden then
            table.insert(themes, theme)
        end
    end
    table.sort(themes, function(a, b)
        if groupOrder(a) ~= groupOrder(b) then
            return groupOrder(a) < groupOrder(b)
        end
        if a.Class ~= b.Class then
            return private.GetClassName(a.Class) < private.GetClassName(b.Class)
        end
        if a.Weather and weatherOrder(a) ~= weatherOrder(b) then
            return weatherOrder(a) < weatherOrder(b)
        end
        if a.Name == private.DEFAULT_THEME or b.Name == private.DEFAULT_THEME then
            return a.Name == private.DEFAULT_THEME and b.Name ~= private.DEFAULT_THEME
        end
        if a.Class and specOrder(a) ~= specOrder(b) then
            return specOrder(a) < specOrder(b)
        end
        return (a.DisplayName or a.Name) < (b.DisplayName or b.Name)
    end)
    return themes
end

---what the player chose, a theme or an automatic selection
---@return string
private.GetThemeSelection = function()
    return private.GetThemeSettings().key
end

---the saved theme, the one an automatic selection picks, or Classic while it is unavailable (the saved choice is kept)
---@return string
private.GetSavedThemeKey = function()
    local key = private.ResolveThemeKey(private.GetThemeSelection())
    if private.IsThemeAvailable(key) then
        return key
    end
    return private.DEFAULT_THEME
end

---@return string
private.GetCurrentThemeKey = function()
    if not currentKey then
        currentKey = private.GetSavedThemeKey()
    end
    return currentKey
end

---@return table
private.GetCurrentTheme = function()
    if not resolved then
        resolved = resolve(private.GetCurrentThemeKey())
    end
    return resolved
end

---@param kind string
---@return table
private.GetElementStyle = function(kind)
    return private.GetCurrentTheme().Elements[kind] or EMPTY
end

---@param kind string
---@return table
private.GetWindowStyle = function(kind)
    return private.GetCurrentTheme().Windows[kind] or EMPTY
end

---reads a value of the current theme by a dotted path, e.g. "Elements.SpellIcon.Size"
---@param path string
---@return any
private.GetThemeValue = function(path)
    local node = private.GetCurrentTheme()
    for key in path:gmatch("[^%.]+") do
        if type(node) ~= "table" then
            return nil
        end
        node = node[key]
    end
    return node
end

---registers a widget whose ApplySettings is called every time the theme changes
---@param widget table
private.RegisterThemed = function(widget)
    themedWidgets[widget] = true
end

local applyToWidgets = function()
    private.ThemeApply.RefreshFonts()
    for widget in pairs(themedWidgets) do
        widget:ApplySettings()
    end
end

---fades the palette of the current theme in from the colors of from over fade seconds, in steps that only apply
---colors again; particles keep the color they were born with and live out their life
---@param from table
---@param fade number
local fadePalette = function(from, fade)
    local palette = resolved.Palette
    if not palette then
        return
    end
    local target = deepCopy(palette)
    local steps = math.max(math.min(math.floor(fade * 8), 24), 1)
    local step = 0
    paletteFade = C_Timer.NewTicker(fade / steps, function()
        step = step + 1
        local mixed = {}
        for name, color in pairs(target) do
            mixed[name] = from[name] and { private.ThemeApply.MixColor(from[name], color, step / steps) } or color
        end
        resolved.Palette = step < steps and mixed or target
        applyToWidgets()
        if step >= steps then
            paletteFade = nil
        end
    end, steps)
    -- the first frame still shows the old colors
    local first = {}
    for name, color in pairs(target) do
        first[name] = from[name] or color
    end
    resolved.Palette = first
end

---applies the current theme to everything again, fading its colors in over fade seconds when given
---@param fade number|nil
private.RefreshTheme = function(fade)
    if paletteFade then
        paletteFade:Cancel()
        paletteFade = nil
    end
    local from = fade and resolved and resolved.Palette
    resolved = nil
    if from and private.GetAnimationLevel() ~= private.ANIMATION_LEVELS.OFF then
        private.GetCurrentTheme()
        fadePalette(from, fade)
    end
    applyToWidgets()
    if private.refreshTimelineGroups and private.ACTIVE_EDITMODE_LAYOUT then
        private.refreshTimelineGroups()
    end
end

---applies a theme or an automatic selection, save = false only previews it
---@param key string
---@param save boolean|nil
private.ApplyTheme = function(key, save)
    if save ~= false then
        private.GetThemeSettings().key = key
    end
    key = private.ResolveThemeKey(key)
    currentKey = private.IsThemeAvailable(key) and key or private.DEFAULT_THEME
    private.RefreshTheme()
end

---applies the saved theme again, after a preview or a profile change, fading over fade seconds when given
---@param fade number|nil
private.RestoreSavedTheme = function(fade)
    currentKey = nil
    private.RefreshTheme(fade)
end

---switches theme when an automatic selection picks another one now, e.g. after a spec change or as the weather
---changes, fading into it
private.RefreshAutoTheme = function()
    if not private.IsAutoTheme(private.GetThemeSelection()) or private.isThemeSelectorOpen() then
        return
    end
    if private.GetSavedThemeKey() ~= private.GetCurrentThemeKey() then
        private.RestoreSavedTheme(WEATHER_FADE)
    end
end

---pretends weather (a name of WEATHER_TYPES) and fades into its theme, also without the Weather selection and on
---clients without C_Weather; nil fades back to the real weather and the saved theme
---@param weather string|nil
---@return string key the theme shown
private.SetTestWeather = function(weather)
    testWeather = weather
    private.UpdateWeather()
    if testWeather and not private.isThemeSelectorOpen() then
        currentKey = findWeatherTheme(testWeather) or findWeatherTheme("Clear") or private.DEFAULT_THEME
        private.RefreshTheme(WEATHER_FADE)
    else
        private.RestoreSavedTheme(WEATHER_FADE)
    end
    return private.GetCurrentThemeKey()
end

---pretends period (a name of TIME_PERIODS) and fades into it over PERIOD_FADE; nil fades back to the real period
---@param period string|nil
---@return string key the theme shown
private.SetTestPeriod = function(period)
    testPeriod = period
    if not private.isThemeSelectorOpen() then
        private.RefreshTheme(PERIOD_FADE)
    end
    return private.GetCurrentThemeKey()
end

---fades into the next period of the day when it has begun and the current theme changes with it
private.RefreshTimeOfDay = function()
    if not resolved or resolvedPeriod == private.GetTimePeriod() or private.isThemeSelectorOpen() then
        return
    end
    for _, theme in ipairs(getChain(private.GetCurrentThemeKey())) do
        if theme.TimeOfDay then
            private.RefreshTheme(PERIOD_FADE)
            return
        end
    end
    resolvedPeriod = private.GetTimePeriod()
end

---checks what the theme follows that has no event of its own, the time of day and the weather's intensity
private.CheckThemeConditions = function()
    private.UpdateWeather()
    private.RefreshAutoTheme()
    private.RefreshTimeOfDay()
end

---@param key string|nil defaults to the current theme
---@return boolean
private.HasThemeModifications = function(key)
    local modifications = private.GetThemeSettings().modifications[key or private.GetCurrentThemeKey()]
    return modifications ~= nil and next(modifications) ~= nil
end

---stores a modification of the current theme, path is dotted, e.g. "Elements.SpellIcon.Size"
---@param path string
---@param value any
private.SetThemeModification = function(path, value)
    local modifications = private.GetThemeSettings().modifications
    local key = private.GetCurrentThemeKey()
    modifications[key] = modifications[key] or {}
    local node = modifications[key]
    local keys = {}
    for part in path:gmatch("[^%.]+") do
        table.insert(keys, part)
    end
    for i = 1, #keys - 1 do
        if type(node[keys[i]]) ~= "table" then
            node[keys[i]] = {}
        end
        node = node[keys[i]]
    end
    node[keys[#keys]] = deepCopy(value)
    private.RefreshTheme()
end

---removes the modifications of the current theme below path, or all of them without a path
---@param path string|nil
private.ResetThemeModifications = function(path)
    local modifications = private.GetThemeSettings().modifications
    local key = private.GetCurrentThemeKey()
    if not path then
        modifications[key] = nil
    elseif modifications[key] then
        local node = modifications[key]
        local parent, last
        for part in path:gmatch("[^%.]+") do
            if type(node) ~= "table" then
                node = nil
                break
            end
            parent, last = node, part
            node = node[part]
        end
        if parent and node ~= nil then
            parent[last] = nil
        end
    end
    private.RefreshTheme()
end

---switches to key and saves it, keepModifications copies the modifications of the current theme over
---@param key string
---@param keepModifications boolean|nil
private.SwitchTheme = function(key, keepModifications)
    local modifications = private.GetThemeSettings().modifications
    local fromKey, toKey = private.GetSavedThemeKey(), private.ResolveThemeKey(key)
    if keepModifications and fromKey ~= toKey and modifications[fromKey] then
        modifications[toKey] = modifications[toKey] or {}
        merge(modifications[toKey], modifications[fromKey])
    end
    private.ApplyTheme(key, true)
end
