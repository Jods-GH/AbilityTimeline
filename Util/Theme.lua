local appName, app = ...
---@class AbilityTimeline
local private = app
local SharedMedia = LibStub("LibSharedMedia-3.0")

-- Theme engine inspired by BetterBags' Sonata (https://github.com/Cidan/BetterBags), used with permission.
-- A theme is data: Windows and Elements styles, inherited from its Parent (Classic when unset), with
-- per client overrides (Clients.Retail / Clients.Classic) and "$Name" values taken from its Variables.
-- The player's modifications of a theme are stored per theme in the profile and merged on top.
-- Besides a theme, the player can choose an automatic selection (AUTO_THEMES) that picks a theme for the character.

private.DEFAULT_THEME = "Classic"
private.THEME_PROMPT_VERSION = 5
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
}

local EMPTY = {}
local themedWidgets = setmetatable({}, { __mode = "k" })
local currentKey
local resolved

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

---@param key string
---@return table
local resolve = function(key)
    local client = private.isRetail and "Retail" or "Classic"
    local style = {}
    for _, theme in ipairs(getChain(key)) do
        merge(style, styleOf(theme))
        if theme.Clients and theme.Clients[client] then
            merge(style, styleOf(theme.Clients[client]))
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

---where a theme is listed within its class: the class theme first, then the specs, specs the client lacks (Spec false) last
---@param theme table
---@return number
local specOrder = function(theme)
    if theme.Spec == nil then
        return 0
    end
    return theme.Spec or 99
end

---returns all themes that can be listed: Classic and the themes made for no class first, then each class with its
---class theme before its spec themes
---@return table[]
private.GetSelectableThemes = function()
    local themes = {}
    for _, theme in pairs(private.Themes) do
        if not theme.Hidden then
            table.insert(themes, theme)
        end
    end
    table.sort(themes, function(a, b)
        if a.Class ~= b.Class then
            if not a.Class or not b.Class then
                return not a.Class
            end
            return private.GetClassName(a.Class) < private.GetClassName(b.Class)
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

---applies the current theme to everything again
private.RefreshTheme = function()
    resolved = nil
    private.ThemeApply.RefreshFonts()
    for widget in pairs(themedWidgets) do
        widget:ApplySettings()
    end
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

---applies the saved theme again, after a preview or a profile change
private.RestoreSavedTheme = function()
    currentKey = nil
    private.RefreshTheme()
end

---switches theme when an automatic selection picks another one now, e.g. after a spec change
private.RefreshAutoTheme = function()
    if not private.IsAutoTheme(private.GetThemeSelection()) or private.isThemeSelectorOpen() then
        return
    end
    if private.GetSavedThemeKey() ~= private.GetCurrentThemeKey() then
        private.RestoreSavedTheme()
    end
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
