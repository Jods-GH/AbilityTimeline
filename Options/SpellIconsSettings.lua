local appName, private = ...
local AceGUI = LibStub("AceGUI-3.0")
local SharedMedia = LibStub("LibSharedMedia-3.0")


local createGeneralSettings = function(widget)
    local scrollContainer = AceGUI:Create("SimpleGroup")
    local group = AceGUI:Create("ScrollFrame")
    scrollContainer:SetLayout("Fill") -- important!
    scrollContainer:SetFullWidth(true)
    scrollContainer:SetHeight(private.SPELL_ICON_SETTINGS_WINDOW.frame:GetHeight() - 100)
    group:SetLayout("Flow")
    group:SetFullWidth(true)
    scrollContainer:AddChild(group)

    local sizeSetting = AceGUI:Create("Slider")
    private.Debug(sizeSetting, "AT_SPELL_ICON_SETTINGS_SIZE_SETTING")
    sizeSetting:SetLabel(private.getLocalisation("IconSize"))
    private.AddFrameTooltip(sizeSetting.frame, "IconSizeDescription")
    sizeSetting:SetSliderValues(1, 100, 1)
    sizeSetting:SetValue(private.db.profile.icon_settings.size)

    sizeSetting:SetCallback("OnValueChanged", function(_, _, value)
        private.db.profile.icon_settings.size = value
        widget:ApplySettings()
    end)
    group:AddChild(sizeSetting)

    return group
end

local createTextSettings = function(widget)
    local scrollContainer = AceGUI:Create("SimpleGroup")
    local group = AceGUI:Create("ScrollFrame")
    scrollContainer:SetLayout("Fill") -- important!
    scrollContainer:SetFullWidth(true)
    scrollContainer:SetHeight(private.SPELL_ICON_SETTINGS_WINDOW.frame:GetHeight() - 100)
    group:SetLayout("Flow")
    group:SetFullWidth(true)
    scrollContainer:AddChild(group)

    local textOffsetSettingX = AceGUI:Create("Slider")
    textOffsetSettingX:SetLabel(private.getLocalisation("TextOffsetX"))
    private.AddFrameTooltip(textOffsetSettingX.frame, "TextOffsetXDescription")
    textOffsetSettingX:SetSliderValues(-50, 50, 1)
    textOffsetSettingX:SetValue(private.db.profile.icon_settings.TextOffset.x)
    textOffsetSettingX:SetCallback("OnValueChanged", function(_, _, value)
        private.db.profile.icon_settings.TextOffset.x = value
        widget:ApplySettings()
    end)
    textOffsetSettingX:SetRelativeWidth(0.5)
    group:AddChild(textOffsetSettingX)


    local textOffsetSettingY = AceGUI:Create("Slider")
    textOffsetSettingY:SetLabel(private.getLocalisation("TextOffsetY"))
    private.AddFrameTooltip(textOffsetSettingY.frame, "TextOffsetYDescription")
    textOffsetSettingY:SetSliderValues(-50, 50, 1)
    textOffsetSettingY:SetValue(private.db.profile.icon_settings.TextOffset.y)
    textOffsetSettingY:SetCallback("OnValueChanged", function(_, _, value)
        private.db.profile.icon_settings.TextOffset.y = value
        widget:ApplySettings()
    end)
    textOffsetSettingY:SetRelativeWidth(0.5)
    group:AddChild(textOffsetSettingY)

    local fontSizeSetting = AceGUI:Create("Slider")
    fontSizeSetting:SetLabel(private.getLocalisation("SpellnameFontSize"))
    private.AddFrameTooltip(fontSizeSetting.frame, "SpellnameFontSizeDescription")
    fontSizeSetting:SetSliderValues(1, 64, 1)
    fontSizeSetting:SetValue(private.db.profile.text_settings.fontSize)
    fontSizeSetting:SetCallback("OnValueChanged", function(_, _, value)
        private.db.profile.text_settings.fontSize = value
        widget:ApplySettings()
    end)
    fontSizeSetting:SetRelativeWidth(0.5)
    group:AddChild(fontSizeSetting)

    local fontSetting = AceGUI:Create("Dropdown")
    fontSetting:SetText(private.db.profile.text_settings.font)
    fontSetting:SetLabel(private.getLocalisation("SpellnameFont"))
    private.AddFrameTooltip(fontSetting.frame, "SpellnameFontDescription")
    for _, texName in ipairs(SharedMedia:List("font")) do
        fontSetting:AddItem(texName, texName)
    end
    fontSetting:SetCallback("OnValueChanged", function(_, _, value)
        private.db.profile.text_settings.font = value
        widget:ApplySettings()
    end)
    fontSetting:SetRelativeWidth(0.5)
    group:AddChild(fontSetting)

    local textDefaultColorSetting = AceGUI:Create("ColorPicker")
    textDefaultColorSetting:SetLabel(private.getLocalisation("SpellnameDefaultColor"))
    private.AddFrameTooltip(textDefaultColorSetting.frame, "SpellnameDefaultColorDescription")
    textDefaultColorSetting:SetColor(private.db.profile.text_settings.defaultColor.r,
        private.db.profile.text_settings.defaultColor.g,
        private.db.profile.text_settings.defaultColor.b
    )
    textDefaultColorSetting:SetCallback("OnValueChanged", function(_, _, r, g, b)
        private.db.profile.text_settings.defaultColor.r = r
        private.db.profile.text_settings.defaultColor.g = g
        private.db.profile.text_settings.defaultColor.b = b
        widget:ApplySettings()
    end)
    group:AddChild(textDefaultColorSetting)

    return group
end


local createCooldownSubSettings
---handles the cooldown color change options
---@param parentGroup AceGUIWidget
---@param scrollContainer AceGUIWidget scroll container to do layout on after changes
---@param cooldownColorChanges table table of cooldown color changes expected to include time and color = {r,g,b}
local handleCooldownColorChangeOptions = function(parentGroup, scrollContainer, widget, cooldownColorChanges) end -- this weird syntax is needed to allow recursion
handleCooldownColorChangeOptions = function(parentGroup, scrollContainer, widget, cooldownColorChanges)
    parentGroup:ReleaseChildren()
    for i, value in pairs(cooldownColorChanges) do
        local time, color = value.time, value.color
        local group = AceGUI:Create("InlineGroup")
        group:SetLayout("Flow")
        group:SetFullWidth(true)

        local removeChangeButton = AceGUI:Create("Icon")
        removeChangeButton:SetImage("Interface\\AddOns\\AbilityTimeline\\Media\\Textures\\minus.tga")
        private.AddFrameTooltip(removeChangeButton.frame, "RemoveCooldownColorChangeTooltip")
        removeChangeButton:SetImageSize(24, 24)
        removeChangeButton:SetRelativeWidth(0.1)

        removeChangeButton:SetCallback("OnClick", function()
            table.remove(private.db.profile.cooldown_settings.color_highlight.highlights, i)
            table.sort(private.db.profile.cooldown_settings.color_highlight.highlights,
                function(a, b) return a.time < b.time end)
            createCooldownSubSettings(scrollContainer, widget)
        end)

        group:AddChild(removeChangeButton)

        local timeSetting = AceGUI:Create("EditBox")
        timeSetting:SetLabel(private.getLocalisation("CooldownColorChangeTiming"))
        private.AddFrameTooltip(timeSetting.frame, "CooldownColorChangeTimingDescription")
        timeSetting:SetMaxLetters(2)
        timeSetting:SetText(time)
        timeSetting:SetRelativeWidth(0.4)
        timeSetting:SetCallback("OnEnterPressed", function(_, _, valueStr)
            local valueNum = tonumber(valueStr)
            if valueNum then
                value.time = valueNum
                table.sort(private.db.profile.cooldown_settings.color_highlight.highlights,
                    function(a, b) return a.time < b.time end)
            else
                timeSetting:SetText(time)
            end
        end)
        group:AddChild(timeSetting)

        local colorPicker = AceGUI:Create("ColorPicker")
        private.AddFrameTooltip(colorPicker.frame, "CooldownColorChangeColorDescription")
        colorPicker:SetLabel(private.getLocalisation("CooldownColorChangeColor"))
        colorPicker:SetColor(color.r, color.g, color.b)
        colorPicker:SetRelativeWidth(0.4)
        group:AddChild(colorPicker)

        colorPicker:SetCallback("OnValueChanged", function(_, _, r, g, b)
            value.color = { r = r, g = g, b = b }
        end)
        parentGroup:AddChild(group)
    end
    scrollContainer:DoLayout()
end

local addCooldownColorHighlightSettings = function(cooldownColorChangeGroup, scroll, widget)
    local cooldownColorChangeLabel = AceGUI:Create("Label")
    cooldownColorChangeLabel:SetText(private.getLocalisation("CooldownColorChanges"))
    cooldownColorChangeLabel:SetRelativeWidth(0.5)
    cooldownColorChangeGroup:AddChild(cooldownColorChangeLabel)

    local addChangeButton = AceGUI:Create("Icon")
    addChangeButton:SetImage("Interface\\AddOns\\AbilityTimeline\\Media\\Textures\\plus.tga")
    private.AddFrameTooltip(addChangeButton.frame, "AddCooldownColorChangeTooltip")
    addChangeButton:SetImageSize(24, 24)
    addChangeButton:SetRelativeWidth(0.5)
    cooldownColorChangeGroup:AddChild(addChangeButton)

    local cooldownColorChangeCreator = AceGUI:Create("SimpleGroup")
    cooldownColorChangeCreator:SetFullWidth(true)
    cooldownColorChangeCreator:SetLayout("Flow")

    handleCooldownColorChangeOptions(cooldownColorChangeCreator, scroll, widget,
        private.db.profile.cooldown_settings.color_highlight.highlights)

    addChangeButton:SetCallback("OnClick", function()
        table.insert(private.db.profile.cooldown_settings.color_highlight.highlights, {
            time = 10,
            color = { r = 1, g = 0, b = 0 }
        })
        table.sort(private.db.profile.cooldown_settings.color_highlight.highlights,
            function(a, b) return a.time < b.time end)
        createCooldownSubSettings(scroll, widget)
    end)

    cooldownColorChangeGroup:AddChild(cooldownColorChangeCreator)
end

createCooldownSubSettings = function(scroll, widget)
    scroll:ReleaseChildren()
    local fontSizeSetting = AceGUI:Create("Slider")
    fontSizeSetting:SetLabel(private.getLocalisation("CooldownFontSize"))
    private.AddFrameTooltip(fontSizeSetting.frame, "CooldownFontSizeDescription")
    fontSizeSetting:SetSliderValues(1, 64, 1)
    fontSizeSetting:SetValue(private.db.profile.cooldown_settings.fontSize)
    fontSizeSetting:SetRelativeWidth(0.5)
    fontSizeSetting:SetCallback("OnValueChanged", function(_, _, value)
        private.db.profile.cooldown_settings.fontSize = value
        widget:ApplySettings()
    end)
    scroll:AddChild(fontSizeSetting)

    local fontSetting = AceGUI:Create("Dropdown")
    fontSetting:SetText(private.db.profile.cooldown_settings.font)
    fontSetting:SetLabel(private.getLocalisation("CooldownFont"))
    private.AddFrameTooltip(fontSetting.frame, "CooldownFontDescription")
    for _, texName in ipairs(SharedMedia:List("font")) do
        fontSetting:AddItem(texName, texName)
    end
    fontSetting:SetCallback("OnValueChanged", function(_, _, value)
        private.db.profile.cooldown_settings.font = value
        widget:ApplySettings()
    end)
    fontSetting:SetRelativeWidth(0.5)
    scroll:AddChild(fontSetting)

    local defaultCooldownColorPicker = AceGUI:Create("ColorPicker")
    defaultCooldownColorPicker:SetLabel(private.getLocalisation("DefaultCooldownColor"))
    defaultCooldownColorPicker:SetColor(private.db.profile.cooldown_settings.cooldown_color.r,
        private.db.profile.cooldown_settings.cooldown_color.g,
        private.db.profile.cooldown_settings.cooldown_color.b
    )

    defaultCooldownColorPicker:SetCallback("OnValueChanged", function(_, _, r, g, b)
        private.db.profile.cooldown_settings.cooldown_color = { r = r, g = g, b = b }
    end)
    defaultCooldownColorPicker:SetRelativeWidth(0.5)
    scroll:AddChild(defaultCooldownColorPicker)


    local cooldownColorChangeToggle = AceGUI:Create("CheckBox")
    cooldownColorChangeToggle:SetValue(private.db.profile.cooldown_settings.color_highlight.enabled)
    cooldownColorChangeToggle:SetLabel(private.getLocalisation("EnableCooldownColorChanges"))
    cooldownColorChangeToggle:SetCallback("OnValueChanged", function(_, _, value)
        private.db.profile.cooldown_settings.color_highlight.enabled = value
        scroll:ReleaseChildren()
        createCooldownSubSettings(scroll, widget)
    end)
    cooldownColorChangeToggle:SetRelativeWidth(0.5)
    scroll:AddChild(cooldownColorChangeToggle)
    if private.db.profile.cooldown_settings.color_highlight.enabled then
        local cooldownColorChangeGroup = AceGUI:Create("InlineGroup")
        cooldownColorChangeGroup:SetLayout("Flow")
        cooldownColorChangeGroup:SetFullWidth(true)
        addCooldownColorHighlightSettings(cooldownColorChangeGroup, scroll)
        scroll:AddChild(cooldownColorChangeGroup)
    end
end
---Creates the cooldown settings tab content
---@param widget AceGUIWidget
---@return AceGUIWidget
local createCooldownSettings = function(widget)
    local scrollContainer = AceGUI:Create("SimpleGroup")
    local scroll = AceGUI:Create("ScrollFrame")
    scrollContainer:SetLayout("Fill")
    scrollContainer:SetFullWidth(true)
    scrollContainer:SetHeight(private.SPELL_ICON_SETTINGS_WINDOW.frame:GetHeight() - 100)
    scroll:SetLayout("Flow")
    scroll:SetFullWidth(true)
    scrollContainer:AddChild(scroll)
    -- TODO template this nonsense we should be getting arrested for this
    createCooldownSubSettings(scroll, widget)

    return scroll
end

local createSpellIconSettingsFrame = function()
    private.Debug("Creating Spell Icon Settings Frame")
    private.SPELL_ICON_SETTINGS_WINDOW = AceGUI:Create("AtSpellIconSettingsFrame")
    private.Debug(private.SPELL_ICON_SETTINGS_WINDOW, "AT_SPELL_ICON_SETTINGS_WINDOW")

    local widget = AceGUI:Create("AtAbilitySpellIcon")
    local eventInfo = {
        duration = 15,
        maxQueueDuration = 0,
        spellName = private.getLocalisation("TestIcon"),
        spellID = 0,
        iconFileID = 135808,
        severity = 1,
        paused = false
    }
    widget:SetEventInfo(eventInfo, true)
    widget.startTime = GetTime()
    widget.duration = 15
    widget.frame:SetScript("OnUpdate", function()
        if widget.startTime + widget.duration < GetTime() then
            widget.startTime = GetTime()
        end
        widget.HandleCooldown(widget.frame, math.ceil((widget.startTime + widget.duration) - GetTime()))
    end) -- loop cooldown display
    widget.frame:Show()
    widget.frame:SetFrameStrata("DIALOG")
    widget.frame:SetPoint("CENTER", private.SPELL_ICON_SETTINGS_WINDOW.rightContent, "CENTER", 0, 0)
    widget.frame:SetFrameLevel(private.SPELL_ICON_SETTINGS_WINDOW.rightContent:GetFrameLevel() + 1)
    widget:SetParent(private.SPELL_ICON_SETTINGS_WINDOW)

    local tabGroup = AceGUI:Create("TabGroup")
    tabGroup:SetTabs({
        {
            text = private.getLocalisation("GeneralSettings"),
            value = "GeneralSettings"
        },
        {
            text = private.getLocalisation("TextSettings"),
            value = "TextSettings"
        },
        {
            text = private.getLocalisation("CooldownSettings"),
            value = "CooldownSettings"
        }
    })
    tabGroup:SetCallback("OnGroupSelected", function(_, _, value)
        private.Debug("Selected tab: " .. value)
        tabGroup:ReleaseChildren()
        if value == "TextSettings" then
            tabGroup:AddChild(createTextSettings(widget))
        elseif value == "CooldownSettings" then
            tabGroup:AddChild(createCooldownSettings(widget))
        else
            tabGroup:AddChild(createGeneralSettings(widget))
        end
    end)
    tabGroup:SetFullWidth(true)
    tabGroup:SelectTab("GeneralSettings")
    private.SPELL_ICON_SETTINGS_WINDOW:AddChild(tabGroup)


    return private.SPELL_ICON_SETTINGS_WINDOW
end

private.openSpellIconSettings = function()
    if not private.SPELL_ICON_SETTINGS_WINDOW then
        createSpellIconSettingsFrame()
    else
        private.SPELL_ICON_SETTINGS_WINDOW.frame:Show()
    end

    if EditModeManagerFrame:IsShown() then
        private.wasEditModeOpen = true
        HideUIPanel(EditModeManagerFrame)
    end
end


private.closeSpellIconSettings = function()
    -- Close the spell icon settings
    private.Debug("Closing spell icon settings")
    private.SPELL_ICON_SETTINGS_WINDOW.frame:Hide()

    if not EditModeManagerFrame:IsShown() and private.wasEditModeOpen then
        private.wasEditModeOpen = false
        ShowUIPanel(EditModeManagerFrame)
    end
end
