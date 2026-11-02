local appName, app = ...
---@class AbilityTimeline
local private = app
local AceGUI = LibStub("AceGUI-3.0")

local Type = "AtThemeSelector"
local Version = 1
local variables = {
    width = 460,
    headerHeight = 34,
    contentPadding = { x = 16, y = 16 },
    -- the theme list scrolls, the rest of the window (description, search, animations, buttons) takes about this much
    listHeight = 440,
    minListHeight = 160,
    chromeHeight = 360,
}

---@param self AtThemeSelector
local function OnAcquire(self)
    self.frame:SetPoint("TOP", UIParent, "TOP", 0, -120)
    self:SetLayout("List")
    self.frame:Show()
end

---@param self AtThemeSelector
local function OnRelease(self)
    self.frame:Hide()
end

---@param self AtThemeSelector
local function ApplySettings(self)
    private.ThemeApply.Window(self.frame, private.GetWindowStyle("Dialog"), self.closeButton, self.frame.titleBar)
end

---grows the window with its content
---@param self AtThemeSelector
---@param width number|nil
---@param height number
local function LayoutFinished(self, width, height)
    self.frame:SetHeight(height + variables.headerHeight + variables.contentPadding.y * 2)
end

local function Constructor()
    local count = AceGUI:GetNextWidgetNum(Type)
    local frame = CreateFrame("Frame", Type .. count, UIParent)
    frame:SetFrameStrata("DIALOG")
    frame:SetWidth(variables.width)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

    frame.titleBar = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.titleBar:SetPoint("TOPLEFT", frame, "TOPLEFT", variables.contentPadding.x, -10)
    frame.titleBar:SetText(private.getLocalisation("ThemeSelectorTitle"))

    local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")

    local contentFrame = CreateFrame("Frame", Type .. "ContentFrame" .. count, frame)
    contentFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", variables.contentPadding.x,
        -variables.headerHeight - variables.contentPadding.y)
    contentFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -variables.contentPadding.x,
        variables.contentPadding.y)

    ---@class AtThemeSelector : AceGUIContainer
    local widget = {
        OnAcquire = OnAcquire,
        OnRelease = OnRelease,
        ApplySettings = ApplySettings,
        LayoutFinished = LayoutFinished,
        type = Type,
        count = count,
        frame = frame,
        content = contentFrame,
        closeButton = closeButton,
    }
    ApplySettings(widget)
    private.RegisterThemed(widget)

    return AceGUI:RegisterAsContainer(widget)
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)

StaticPopupDialogs["ABILITYTIMELINE_KEEP_THEME_MODIFICATIONS"] = {
    text = private.getLocalisation("ThemeKeepModifications"),
    button1 = private.getLocalisation("ThemeKeepModificationsKeep"),
    button2 = private.getLocalisation("ThemeKeepModificationsDiscard"),
    OnAccept = function(_, key)
        private.SwitchTheme(key, true)
    end,
    OnCancel = function(_, key)
        private.SwitchTheme(key, false)
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = false,
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
        return private.getLocalisation("Theme" .. key):format(getDisplayName(private.ResolveThemeKey(key)))
    end
    return getDisplayName(key)
end

---switches to key and asks first whether the modifications of the current theme should be kept
---@param key string
private.SelectTheme = function(key)
    local fromKey, toKey = private.GetSavedThemeKey(), private.ResolveThemeKey(key)
    if toKey ~= fromKey and private.HasThemeModifications(fromKey) then
        StaticPopup_Show("ABILITYTIMELINE_KEEP_THEME_MODIFICATIONS", getDisplayName(fromKey), getDisplayName(toKey), key)
    else
        private.SwitchTheme(key)
    end
end

local selector

---@return boolean
private.isThemeSelectorOpen = function()
    return selector ~= nil
end

local closeThemeSelector = function()
    private.stopTestEvents()
    private.GetThemeSettings().promptVersion = private.THEME_PROMPT_VERSION
    selector:Release()
    selector = nil
end

---@param text string
---@param role string
---@return table
local createLabel = function(text, role)
    local label = AceGUI:Create("Label")
    label:SetText(text)
    label:SetFullWidth(true)
    label:SetFontObject(private.ThemeApply.FontObject(role))
    label.label:SetTextColor(private.ThemeApply.FontObject(role):GetTextColor())
    return label
end

---@param buttons table[] -- { text, style, onClick }
---@return table
local createButtons = function(buttons)
    local group = AceGUI:Create("SimpleGroup")
    group:SetLayout("Flow")
    group:SetFullWidth(true)
    for _, button in ipairs(buttons) do
        local widget = AceGUI:Create("AtButton")
        widget:SetText(button[1])
        widget:SetStyle(button[2])
        widget:SetRelativeWidth(1 / #buttons)
        widget:SetCallback("OnClick", button[3])
        group:AddChild(widget)
    end
    return group
end

---asks in the window whether the changes made to the current theme should be kept for key
---@param key string
local showKeepModifications = function(key)
    local fromKey = private.GetSavedThemeKey()
    selector:ReleaseChildren()
    selector:AddChild(createLabel(private.getLocalisation("ThemeKeepModifications"):format(getDisplayName(fromKey),
        getDisplayName(private.ResolveThemeKey(key))), "Control"))
    selector:AddChild(createButtons({
        { private.getLocalisation("ThemeKeepModificationsKeep"), "Primary", function()
            closeThemeSelector()
            private.SwitchTheme(key, true)
        end },
        { private.getLocalisation("ThemeKeepModificationsDiscard"), "Plain", function()
            closeThemeSelector()
            private.SwitchTheme(key, false)
        end },
    }))
end

local cancelThemeSelector = function()
    closeThemeSelector()
    private.RestoreSavedTheme()
end

---opens the theme selection, every theme is previewed on the real frames until it is confirmed
private.openThemeSelector = function()
    if selector then return end
    selector = AceGUI:Create("AtThemeSelector")
    selector.closeButton:SetScript("OnClick", cancelThemeSelector)
    local selectedKey = private.GetThemeSelection()
    if not private.IsAutoTheme(selectedKey) then
        selectedKey = private.GetCurrentThemeKey()
    end

    selector:AddChild(createLabel(private.getLocalisation("ThemeSelectorDescription"), "Muted"))

    -- the automatic selections first, shown with the palette of the theme they currently pick, then the themes made
    -- for no class, then a group per class
    local groups = { { Name = private.getLocalisation("ThemeGroupAutomatic"), Themes = {} } }
    for _, key in ipairs(private.AUTO_THEMES) do
        local theme = private.Themes[private.ResolveThemeKey(key)]
        table.insert(groups[1].Themes, {
            Name = key,
            DisplayName = private.GetThemeSelectionName(key),
            Description = private.getLocalisation("Theme" .. key .. "Description"),
            Palette = theme.Palette,
            Effects = theme.Effects,
        })
    end
    for _, theme in ipairs(private.GetSelectableThemes()) do
        local group = groups[#groups]
        if #groups == 1 or group.Class ~= theme.Class then
            group = {
                Name = theme.Class and private.GetClassName(theme.Class) or private.getLocalisation("ThemeGroupGeneral"),
                Class = theme.Class,
                Themes = {},
            }
            table.insert(groups, group)
        end
        table.insert(group.Themes, theme)
    end

    local search = AceGUI:Create("AtEditBox")
    search:SetLabel(private.getLocalisation("ThemeSelectorSearch"))
    search:SetFullWidth(true)
    search:DisableButton(true)
    selector:AddChild(search)

    local listContainer = AceGUI:Create("SimpleGroup")
    listContainer:SetLayout("Fill")
    listContainer:SetFullWidth(true)
    listContainer:SetHeight(math.max(math.min(variables.listHeight, UIParent:GetHeight() - variables.chromeHeight),
        variables.minListHeight))
    local list = AceGUI:Create("AtScrollFrame")
    list:SetLayout("List")
    listContainer:AddChild(list)
    selector:AddChild(listContainer)

    local cards = {}
    ---lists the themes whose name, description or class contain query
    ---@param query string
    local fillList = function(query)
        query = query:lower()
        local matches = function(text)
            return text and text:lower():find(query, 1, true) ~= nil
        end
        list:PauseLayout()
        list:ReleaseChildren()
        cards = {}
        for _, group in ipairs(groups) do
            local heading
            for _, theme in ipairs(group.Themes) do
                if query == "" or matches(theme.DisplayName or theme.Name) or matches(theme.Description) or
                    (group.Class and matches(group.Name)) then
                    if not heading then
                        heading = createLabel(group.Name, "Heading")
                        local color = group.Class and RAID_CLASS_COLORS[group.Class]
                        if color then
                            heading.label:SetTextColor(color.r, color.g, color.b)
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
                    end)
                    cards[theme.Name] = card
                    list:AddChild(card)
                end
            end
        end
        if not next(cards) then
            list:AddChild(createLabel(private.getLocalisation("ThemeSelectorNoResults"), "Muted"))
        end
        list:ResumeLayout()
        list:DoLayout()
        list:SetScroll(0)
    end
    search:SetCallback("OnTextChanged", function(_, _, text)
        fillList(text)
    end)
    fillList("")

    local animations = AceGUI:Create("AtDropdown")
    animations:SetLabel(private.getLocalisation("ThemeAnimations"))
    animations:SetList({
        [private.ANIMATION_LEVELS.FULL] = private.getLocalisation("ThemeAnimationsFull"),
        [private.ANIMATION_LEVELS.DIMMED] = private.getLocalisation("ThemeAnimationsDimmed"),
        [private.ANIMATION_LEVELS.OFF] = private.getLocalisation("ThemeAnimationsOff"),
    }, { private.ANIMATION_LEVELS.FULL, private.ANIMATION_LEVELS.DIMMED, private.ANIMATION_LEVELS.OFF })
    animations:SetValue(private.GetAnimationLevel())
    animations:SetFullWidth(true)
    animations:SetCallback("OnValueChanged", function(_, _, value)
        private.SetAnimationLevel(value)
    end)
    selector:AddChild(animations)

    selector:AddChild(createButtons({
        { private.getLocalisation("ThemeSelectorConfirm"), "Primary", function()
            local fromKey = private.GetSavedThemeKey()
            if private.ResolveThemeKey(selectedKey) ~= fromKey and private.HasThemeModifications(fromKey) then
                showKeepModifications(selectedKey)
            else
                closeThemeSelector()
                private.SwitchTheme(selectedKey)
            end
        end },
        { private.getLocalisation("ThemeSelectorCancel"), "Plain", cancelThemeSelector },
    }))

    private.startTestEvents()
end

---opens the theme selection once per profile (again whenever THEME_PROMPT_VERSION is raised),
---not during combat or encounters, call it again once they ended
local promptedThisSession = false

private.checkThemePrompt = function()
    if promptedThisSession then return end
    -- in debug mode it opens once after every reload, to test it
    if private.GetThemeSettings().promptVersion >= private.THEME_PROMPT_VERSION and not private.db.profile.debugMode then
        return
    end
    if not private.ACTIVE_EDITMODE_LAYOUT then
        C_Timer.After(3, private.checkThemePrompt)
        return
    end
    if InCombatLockdown() or IsEncounterInProgress() then return end
    promptedThisSession = true
    private.openThemeSelector()
end
