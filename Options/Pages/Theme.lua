local appName, app = ...
---@class AbilityTimeline
local private = app
local AceGUI = LibStub("AceGUI-3.0")
local L = private.getLocalisation

-- the theme page: every theme as a card, picking one previews it on the timeline, leaving the page asks whether to
-- use it
local variables = {
    -- typing filters the cards once it paused this long
    searchDelay = 0.25,
}

---@param key string
---@return string
local getDisplayName = function(key)
    local theme = private.Themes[key]
    return theme and theme.DisplayName or key
end

---the name of a theme or an automatic selection with the theme it currently picks, e.g. "Spec theme (Fire Mage)"
---@param key string
---@return string
private.GetThemeSelectionName = function(key)
    if private.IsAutoTheme(key) then
        return L("Theme" .. key):format(getDisplayName(private.ResolveThemeKey(key)))
    end
    return getDisplayName(key)
end

local dialog

---the frame of the question asked, nil until one was
---@return Frame|nil
private.GetThemeDialog = function()
    return dialog and dialog.frame
end

---asks question: { title, text, accept, acceptStyle (Primary or Danger), back, check (the check box's label, none
---without), onAccept(checked), onBack }
---@param question table
local ask = function(question)
    if dialog then dialog.frame:Hide() end
    dialog = AceGUI:Create("AtDialogFrame")
    dialog:SetCallback("OnClose", function(widget)
        if dialog == widget then dialog = nil end
        widget:Release()
    end)
    dialog:SetQuestion(question)
end
private.AskQuestion = ask

---asks whether to keep key, tried on the theme page, and whether the changes made to the theme in use come along
---@param key string
local askToKeepTheme = function(key)
    local fromKey = private.GetSavedThemeKey()
    local fromName = getDisplayName(fromKey)
    local hasChanges = private.ResolveThemeKey(key) ~= fromKey and private.HasThemeModifications(fromKey)
    ask({
        title = L("SettingsKeepThemeTitle"),
        text = L("SettingsKeepThemeText"):format(private.GetThemeSelectionName(key), fromName),
        accept = L("ThemeSelectorConfirm"),
        back = L("SettingsKeepThemeBack"),
        check = hasChanges and L("SettingsKeepThemeChanges"):format(fromName) or nil,
        onAccept = function(keepChanges)
            private.SwitchTheme(key, keepChanges)
        end,
        onBack = function()
            private.RestoreSavedTheme()
        end,
    })
end

local isShown = false
local selectedKey
-- the search, kept when the page renders again as rows show or hide with the theme tried on
local query = ""
local cards = {}

---whether the theme page is shown, automatic selections don't switch the theme while it previews one
---@return boolean
private.isThemePageShown = function()
    return isShown
end

---@return string
local getSavedSelection = function()
    local selection = private.GetThemeSelection()
    return private.IsAutoTheme(selection) and selection or private.GetSavedThemeKey()
end

---the automatic selections first, shown with the palette of the theme they currently pick, then the themes made
---for no class, the weather themes, then a group per class
---@return table[]
local getGroups = function()
    local groups = { { Name = L("ThemeGroupAutomatic"), Themes = {} } }
    for _, key in ipairs(private.AUTO_THEMES) do
        local theme = private.Themes[private.ResolveThemeKey(key)]
        table.insert(groups[1].Themes, {
            Name = key,
            DisplayName = private.GetThemeSelectionName(key),
            Description = L("Theme" .. key .. "Description"),
            Palette = theme.Palette,
            Effects = theme.Effects,
        })
    end
    for _, theme in ipairs(private.GetSelectableThemes()) do
        local group = groups[#groups]
        local weather = theme.Weather ~= nil
        local addon = theme.Addon ~= nil
        if #groups == 1 or group.Class ~= theme.Class or group.Weather ~= weather or group.Addon ~= addon then
            local name = L("ThemeGroupGeneral")
            if addon then
                name = L("ThemeGroupAddons")
            elseif theme.Class then
                name = private.GetClassName(theme.Class)
            elseif weather then
                name = L("ThemeGroupWeather")
            end
            group = { Name = name, Class = theme.Class, Weather = weather, Addon = addon, Themes = {} }
            table.insert(groups, group)
        end
        table.insert(group.Themes, theme)
    end
    return groups
end

-- the theme the preview shows, the hovered one
local previewKey
local themePreview

---@return string
local getPreviewKey = function()
    return previewKey or getSavedSelection()
end

local getThemePreview = function()
    if not themePreview then
        themePreview = AceGUI:Create("AtThemePreview")
        themePreview:Setup(getPreviewKey)
    end
    return themePreview.frame
end

local setPreviewTheme = function(key)
    getThemePreview()
    if key == previewKey then return end
    previewKey = key
    themePreview:Refresh()
end

---shows a hovered theme in the preview with its name and description
---@param theme table
local showTheme = function(theme)
    local text = theme.Description or ""
    if theme.Name ~= selectedKey then
        text = text .. "\n\n" .. L("SettingsThemeClickToPreview")
    end
    setPreviewTheme(theme.Name)
    private.ShowSettingsDetails(theme.DisplayName or theme.Name, text, getThemePreview())
end

---lists the themes whose name, description or class contain query
---@param list table -- the scroll frame the cards are added to
---@param query string
local fillList = function(list, query)
    query = query:lower()
    local matches = function(text)
        return text and text:lower():find(query, 1, true) ~= nil
    end
    list:PauseLayout()
    list:ReleaseChildren()
    cards = {}
    for _, group in ipairs(getGroups()) do
        local heading
        for _, theme in ipairs(group.Themes) do
            if query == "" or matches(theme.DisplayName or theme.Name) or matches(theme.Description) or
                ((group.Class or group.Weather) and matches(group.Name)) then
                if not heading then
                    heading = AceGUI:Create("AtSettingHeading")
                    heading:SetText(group.Name)
                    local color = group.Class and RAID_CLASS_COLORS[group.Class]
                    if color then
                        heading.frame.Text:SetTextColor(color.r, color.g, color.b)
                    end
                    list:AddChild(heading)
                end
                local card = AceGUI:Create("AtThemeCard")
                card:SetTheme(theme)
                card:SetDisabled(not private.IsThemeAvailable(theme.Name))
                card:SetSelected(theme.Name == selectedKey)
                card:SetCallback("OnClick", function()
                    if not private.IsThemeAvailable(theme.Name) then return end
                    selectedKey = theme.Name
                    for key, other in pairs(cards) do
                        other:SetSelected(key == selectedKey)
                    end
                    private.ApplyTheme(selectedKey, false)
                    showTheme(theme)
                    -- the tour can leave the page, not while the card's own callback runs
                    C_Timer.After(0, function()
                        private.OnTourEvent("themeTried")
                    end)
                end)
                card:SetCallback("OnEnter", function()
                    if not private.IsThemeAvailable(theme.Name) then return end
                    showTheme(theme)
                end)
                cards[theme.Name] = card
                list:AddChild(card)
            end
        end
    end
    if not next(cards) then
        local heading = AceGUI:Create("AtSettingHeading")
        heading:SetText(L("ThemeSelectorNoResults"))
        list:AddChild(heading)
    end
    list:ResumeLayout()
    list:DoLayout()
end

---the theme search stays above the cards, which scroll
---@param scroll table
---@param header table
local render = function(scroll, header)
    selectedKey = selectedKey or getSavedSelection()
    local searchRow = AceGUI:Create("AtSettingRow")
    searchRow:SetLabel(L("SettingsSearchThemes"))
    local search = AceGUI:Create("AtEditBox")
    search:SetLabel("")
    search:DisableButton(true)
    search:SetText(query)
    searchRow:AddChild(search)
    header:AddChild(searchRow)
    local searchTimer
    search:SetCallback("OnTextChanged", function(_, _, text)
        if searchTimer then
            searchTimer:Cancel()
        end
        searchTimer = C_Timer.NewTimer(variables.searchDelay, function()
            query = text
            if isShown then
                fillList(scroll, text)
            end
        end)
    end)
    fillList(scroll, query)
end

-- a weather theme picked by hand lets the player choose its time of day and intensity, the Weather selection follows
-- the realm's time and the weather outside
local isNotWeatherByHand = function()
    local theme = private.Themes[private.GetCurrentThemeKey()]
    return not (theme and theme.Weather) or private.GetShownSelection() == "Weather"
end

private.RegisterSettingsPage({
    key = "Theme",
    order = 15,
    name = L("SettingsPageTheme"),
    desc = L("SettingsPageThemeDescription"),
    pinned = true,
    GetPreview = function()
        setPreviewTheme(selectedKey or getSavedSelection())
        return getThemePreview()
    end,
    Render = render,
    OnShow = function()
        isShown = true
    end,
    -- a theme still previewed is used or reverted as the player answers
    OnHide = function()
        isShown = false
        cards = {}
        query = ""
        if selectedKey and selectedKey ~= getSavedSelection() then
            askToKeepTheme(selectedKey)
        end
        selectedKey = nil
        if themePreview then
            themePreview:Release()
            themePreview = nil
            previewKey = nil
        end
    end,
    rows = {
        {
            kind = "Dropdown",
            name = L("ThemeAnimations"),
            desc = L("ThemeAnimationsDescription"),
            values = {
                [private.ANIMATION_LEVELS.FULL] = L("ThemeAnimationsFull"),
                [private.ANIMATION_LEVELS.DIMMED] = L("ThemeAnimationsDimmed"),
                [private.ANIMATION_LEVELS.OFF] = L("ThemeAnimationsOff"),
            },
            sorting = { private.ANIMATION_LEVELS.FULL, private.ANIMATION_LEVELS.DIMMED, private.ANIMATION_LEVELS.OFF },
            get = private.GetAnimationLevel,
            set = private.SetAnimationLevel,
        },
        {
            kind = "Slider",
            name = L("ThemeGlassTint"),
            desc = L("ThemeGlassTintDescription"),
            minValue = 0,
            maxValue = 100,
            valueStep = 1,
            hidden = function()
                local glass = private.GetElementStyle("Timeline").Glass
                return not (glass and glass.Tint)
            end,
            get = private.GetGlassTint,
            set = private.SetGlassTint,
        },
        {
            kind = "Dropdown",
            name = L("ThemeTimeOfDay"),
            desc = L("ThemeTimeOfDayDescription"),
            values = {
                Realm = L("ThemeTimeOfDayRealm"),
                Morning = L("ThemeTimeOfDayMorning"),
                Midday = L("ThemeTimeOfDayMidday"),
                Evening = L("ThemeTimeOfDayEvening"),
                Night = L("ThemeTimeOfDayNight"),
            },
            sorting = { "Realm", "Morning", "Midday", "Evening", "Night" },
            hidden = isNotWeatherByHand,
            get = function()
                return private.GetThemeSettings().period or "Realm"
            end,
            set = function(value)
                private.SetChosenPeriod(value ~= "Realm" and value or nil)
            end,
        },
        {
            kind = "Slider",
            name = L("ThemeWeatherIntensity"),
            desc = L("ThemeWeatherIntensityDescription"),
            minValue = 0,
            maxValue = 100,
            valueStep = 1,
            hidden = isNotWeatherByHand,
            get = private.GetChosenIntensity,
            set = private.SetChosenIntensity,
        },
        {
            kind = "Button",
            name = L("ResetThemeModifications"),
            desc = L("ResetThemeModificationsDescription"),
            buttonText = L("SettingsReset"),
            hidden = function()
                return not private.HasThemeModifications(private.GetSavedThemeKey())
            end,
            func = function()
                ask({
                    title = L("ResetThemeModifications"),
                    text = L("SettingsResetThemeText"):format(getDisplayName(private.GetSavedThemeKey())),
                    accept = L("SettingsReset"),
                    acceptStyle = "Danger",
                    back = CANCEL,
                    onAccept = function()
                        private.ResetThemeModifications()
                        private.RefreshSettingsPage()
                    end,
                })
            end,
        },
    },
})

---shows the welcome tour when due, not during combat or encounters; call it again once they ended
local promptedThisSession = false

private.checkThemePrompt = function()
    if promptedThisSession then return end
    if not private.IsTourDue() then
        return
    end
    if not private.ACTIVE_EDITMODE_LAYOUT then
        C_Timer.After(3, private.checkThemePrompt)
        return
    end
    if InCombatLockdown() or IsEncounterInProgress() then return end
    promptedThisSession = true
    private.ShowTourWelcome()
end
