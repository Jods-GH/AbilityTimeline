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
    preview = {
        width = 240,
        inset = 12,
        -- room for the big icon's name below it
        nameHeight = 24,
        iconSize = 64,
        -- seconds into the loop the icon appears, the icon leaves, the bar leaves, and the loop starts again
        iconIn = 0.6,
        iconOut = 3.6,
        barOut = 4.4,
        loop = 5.6,
        icon = 237538,
    },
    dialog = {
        width = 380,
        offsetY = 120,
        padding = 16,
        headerHeight = 34,
        buttonHeight = 24,
    },
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

---a question in the theme's dialog style: a text, an optional check box and two buttons; escape or closing it
---answers with the back button
local createDialog = function()
    local frame = CreateFrame("Frame", "AbilityTimelineThemeDialog", UIParent)
    frame:Hide()
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetWidth(variables.dialog.width)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, variables.dialog.offsetY)
    frame:EnableMouse(true)
    -- closes with escape
    table.insert(UISpecialFrames, frame:GetName())
    local padding = variables.dialog.padding

    frame.Title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.Title:SetPoint("TOPLEFT", frame, "TOPLEFT", padding, -10)
    frame.Text = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.Text:SetPoint("TOPLEFT", frame, "TOPLEFT", padding, -variables.dialog.headerHeight - padding)
    frame.Text:SetWidth(variables.dialog.width - padding * 2)
    frame.Text:SetJustifyH("LEFT")
    frame.Text:SetWordWrap(true)
    frame.Text:SetSpacing(3)

    local check = AceGUI:Create("AtCheckBox")
    check.frame:SetParent(frame)
    check:SetWidth(variables.dialog.width - padding * 2)
    check.frame:SetPoint("TOPLEFT", frame.Text, "BOTTOMLEFT", 0, -padding)

    local createButton = function(anchor)
        local button = AceGUI:Create("AtButton")
        button:SetWidth((variables.dialog.width - padding * 3) / 2)
        button.frame:SetParent(frame)
        button.frame:SetPoint(anchor, frame, anchor, anchor == "BOTTOMLEFT" and padding or -padding, padding)
        button.frame:Show()
        return button
    end
    local back = createButton("BOTTOMLEFT")
    back:SetCallback("OnClick", function()
        frame:Hide()
    end)
    local accept = createButton("BOTTOMRIGHT")
    accept:SetCallback("OnClick", function()
        local onAccept = frame.question.onAccept
        frame.answered = true
        frame:Hide()
        onAccept(check.frame:IsShown() and check:GetValue())
    end)

    -- set before the window style hooks its own OnHide, setting a script drops the hooks
    frame:SetScript("OnHide", function()
        if not frame.answered and frame.question.onBack then
            frame.question.onBack()
        end
    end)
    dialog = {
        frame = frame,
        check = check,
        back = back,
        accept = accept,
        ApplySettings = function()
            private.ThemeApply.Window(frame, private.GetWindowStyle("Dialog"), nil, frame.Title)
            private.ThemeApply.FontRole(frame.Text, "Control")
        end,
    }
    dialog:ApplySettings()
    private.RegisterThemed(dialog)
end

---the frame of the question asked, nil until one was
---@return Frame|nil
private.GetThemeDialog = function()
    return dialog and dialog.frame
end

---asks question: { title, text, accept, acceptStyle (Primary or Danger), back, check (the check box's label, none
---without), onAccept(checked), onBack }
---@param question table
local ask = function(question)
    if not dialog then
        createDialog()
    end
    local frame = dialog.frame
    -- a question still open is answered with its back button
    if frame:IsShown() then
        frame:Hide()
    end
    frame.question = question
    frame.answered = false
    frame.Title:SetText(question.title)
    frame.Text:SetText(question.text)
    dialog.check:SetLabel(question.check or "")
    dialog.check:SetValue(false)
    dialog.check.frame:SetShown(question.check ~= nil)
    dialog.accept:SetText(question.accept)
    dialog.accept:SetStyle(question.acceptStyle or "Primary")
    dialog.back:SetText(question.back)
    -- the window grows with its text
    local padding = variables.dialog.padding
    frame:SetHeight(variables.dialog.headerHeight + padding * 3 + frame.Text:GetStringHeight() +
        (question.check and dialog.check.frame:GetHeight() + padding or 0) + variables.dialog.buttonHeight + padding)
    frame:Show()
end

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
        if #groups == 1 or group.Class ~= theme.Class or group.Weather ~= weather then
            local name = L("ThemeGroupGeneral")
            if theme.Class then
                name = private.GetClassName(theme.Class)
            elseif weather then
                name = L("ThemeGroupWeather")
            end
            group = { Name = name, Class = theme.Class, Weather = weather, Themes = {} }
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

---@param widget table
---@param kind string -- Timeline or BigIcon
local showPiece = function(widget, kind)
    local frame = widget.frame
    frame:Show()
    if kind == "Timeline" then
        private.ThemeApply.PlayEnter(frame, private.GetElementStyle(kind).Enter)
    else
        -- the countdown and its swipe start over with every entry
        widget.startTime = GetTime()
        frame.Cooldown:SetCooldown(widget.startTime, widget.duration)
        private.ThemeApply.PlayEnter(frame, private.GetElementStyle(kind).Enter, true, frame.SpellIcon,
            variables.preview.icon)
    end
end

---@param widget table
---@param kind string -- Timeline or BigIcon
local hidePiece = function(widget, kind)
    local frame = widget.frame
    if kind == "Timeline" then
        private.ThemeApply.PlayExit(frame, private.GetElementStyle(kind).Exit)
    else
        private.ThemeApply.PlayExit(frame, private.GetElementStyle(kind).Exit, frame.SpellIcon, variables.preview.icon)
    end
    frame:Hide()
end

---starts the preview's loop from the beginning, with both pieces gone
local restartPreview = function()
    themePreview.time = 0
    themePreview.step = 1
    themePreview.bar.frame:Hide()
    themePreview.icon.frame:Hide()
end

---the timeline bar and a big icon below it in the hovered theme: the bar appears, then the icon, the icon leaves, then
---the bar, and it starts again
---@return Frame
local getThemePreview = function()
    if themePreview then
        return themePreview.frame
    end
    local frame = CreateFrame("Frame", nil, UIParent)
    frame:Hide()
    frame:SetWidth(variables.preview.width)
    local bar = private.CreateSettingsPreview("Timeline", getPreviewKey)
    local icon = private.CreateSettingsPreview("BigIcon", getPreviewKey)
    for _, widget in ipairs({ bar, icon }) do
        widget.frame:SetParent(frame)
        widget.frame:ClearAllPoints()
    end
    bar.frame:SetPoint("TOP", frame, "TOP", 0, -variables.preview.inset)
    icon.frame:SetPoint("TOP", bar.frame, "BOTTOM", 0, -variables.preview.inset)
    -- the icon has a size of its own, big icons can be too small or too large to show a theme
    local applySettings = icon.ApplySettings
    icon.ApplySettings = function(self)
        applySettings(self)
        self.frame:SetSize(variables.preview.iconSize, variables.preview.iconSize)
    end
    icon:ApplySettings()
    themePreview = { frame = frame, bar = bar, icon = icon }
    local steps = {
        { at = 0, play = function() showPiece(bar, "Timeline") end },
        { at = variables.preview.iconIn, play = function() showPiece(icon, "BigIcon") end },
        { at = variables.preview.iconOut, play = function() hidePiece(icon, "BigIcon") end },
        { at = variables.preview.barOut, play = function() hidePiece(bar, "Timeline") end },
    }
    -- the settings window puts the preview above its panel, its pieces go above it
    frame:SetScript("OnShow", function()
        for _, widget in ipairs({ bar, icon }) do
            widget.frame:SetFrameLevel(frame:GetFrameLevel() + 1)
        end
        restartPreview()
    end)
    frame:SetScript("OnUpdate", function(_, elapsed)
        themePreview.time = themePreview.time + elapsed
        local step = steps[themePreview.step]
        if themePreview.time >= step.at then
            private.DrawInTheme(getPreviewKey(), step.play)
            themePreview.step = themePreview.step % #steps + 1
            if themePreview.step == 1 then
                themePreview.time = themePreview.time - variables.preview.loop
            end
        end
    end)
    restartPreview()
    return frame
end

---shows key in the preview from the start of its loop, the preview grows with the theme's big icon
---@param key string
local setPreviewTheme = function(key)
    getThemePreview()
    if key == previewKey then return end
    previewKey = key
    themePreview.bar:ApplySettings()
    themePreview.icon:ApplySettings()
    themePreview.frame:SetHeight(variables.preview.inset * 3 + themePreview.bar.frame:GetHeight() +
        variables.preview.iconSize + variables.preview.nameHeight)
    restartPreview()
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
    searchRow:AddChild(search)
    header:AddChild(searchRow)
    local searchTimer
    search:SetCallback("OnTextChanged", function(_, _, text)
        if searchTimer then
            searchTimer:Cancel()
        end
        searchTimer = C_Timer.NewTimer(variables.searchDelay, function()
            if isShown then
                fillList(scroll, text)
            end
        end)
    end)
    fillList(scroll, "")
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
        -- the prompt after an update shows this page once
        private.GetThemeSettings().promptVersion = private.THEME_PROMPT_VERSION
    end,
    -- a theme still previewed is used or reverted as the player answers
    OnHide = function()
        isShown = false
        cards = {}
        if selectedKey and selectedKey ~= getSavedSelection() then
            askToKeepTheme(selectedKey)
        end
        selectedKey = nil
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

---opens the theme page once per profile (again whenever THEME_PROMPT_VERSION is raised), not during combat or
---encounters, call it again once they ended. The welcome tour goes first, it shows the theme page itself
local promptedThisSession = false

private.checkThemePrompt = function()
    if promptedThisSession then return end
    local tourDue = private.IsTourDue()
    -- in debug mode it opens once after every reload, to test it
    if not tourDue and private.GetThemeSettings().promptVersion >= private.THEME_PROMPT_VERSION and
        not private.db.profile.debugMode then
        return
    end
    if not private.ACTIVE_EDITMODE_LAYOUT then
        C_Timer.After(3, private.checkThemePrompt)
        return
    end
    if InCombatLockdown() or IsEncounterInProgress() then return end
    promptedThisSession = true
    if tourDue then
        private.ShowTourWelcome()
    else
        private.openSettings("Theme")
    end
end
