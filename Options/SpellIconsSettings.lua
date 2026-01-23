local appName, private = ...
local AceGUI = LibStub("AceGUI-3.0")
local SharedMedia = LibStub("LibSharedMedia-3.0")


local createGeneralSettings = function(widget, parentWindow, iconSettings, maxIconSize)
    local scrollContainer = AceGUI:Create("SimpleGroup")
    local scroll = AceGUI:Create("ScrollFrame")
    scrollContainer:SetLayout("Fill") -- important!
    scrollContainer:SetFullWidth(true)
    scrollContainer:SetHeight(parentWindow.frame:GetHeight() - 115)
    scroll:SetLayout("Flow")
    scroll:SetFullWidth(true)
    scrollContainer:AddChild(scroll)

    local sizeSetting = AceGUI:Create("Slider")
    private.Debug(sizeSetting, "AT_SPELL_ICON_SETTINGS_SIZE_SETTING")
    sizeSetting:SetLabel(private.getLocalisation("IconSize"))
    private.AddFrameTooltip(sizeSetting.frame, "IconSizeDescription")
    sizeSetting:SetSliderValues(1, maxIconSize, 1)
    sizeSetting:SetValue(iconSettings.size)

    sizeSetting:SetCallback("OnValueChanged", function(_, _, value)
        iconSettings.size = value
        widget:ApplySettings()
    end)
    scroll:AddChild(sizeSetting)

    local zoomSetting = AceGUI:Create("Slider")
    zoomSetting:SetLabel(private.getLocalisation("IconZoom"))
    private.AddFrameTooltip(zoomSetting.frame, "IconZoomDescription")
    zoomSetting:SetSliderValues(0, 1, 0.01)
    zoomSetting:SetIsPercent(true)
    zoomSetting:SetValue(iconSettings.zoom)

    zoomSetting:SetCallback("OnValueChanged", function(_, _, value)
        iconSettings.zoom = value
        widget:ApplySettings()
    end)
    scroll:AddChild(zoomSetting)

    local dispellIconSetting = AceGUI:Create("CheckBox")
    dispellIconSetting:SetLabel(private.getLocalisation("IconDispellIcon"))
    private.AddFrameTooltip(dispellIconSetting.frame, "IconDispellIconDescription")
    dispellIconSetting:SetValue(iconSettings.dispellIcons)
    dispellIconSetting:SetCallback("OnValueChanged", function(_, _, value)
        iconSettings.dispellIcons = value
        widget:ApplySettings()
    end)
    scroll:AddChild(dispellIconSetting)

    local dispellBorderSetting = AceGUI:Create("CheckBox")
    dispellBorderSetting:SetLabel(private.getLocalisation("IconDispellBorder"))
    private.AddFrameTooltip(dispellBorderSetting.frame, "IconDispellBorderDescription")
    dispellBorderSetting:SetValue(iconSettings.dispellBorders)
    dispellBorderSetting:SetCallback("OnValueChanged", function(_, _, value)
        iconSettings.dispellBorders = value
        widget:ApplySettings()
    end)
    scroll:AddChild(dispellBorderSetting)

    local dangerIconSetting = AceGUI:Create("CheckBox")
    dangerIconSetting:SetLabel(private.getLocalisation("IconDangerIcon"))
    private.AddFrameTooltip(dangerIconSetting.frame, "IconDangerIconDescription")
    dangerIconSetting:SetValue(iconSettings.dangerIcon)
    dangerIconSetting:SetCallback("OnValueChanged", function(_, _, value)
        iconSettings.dangerIcon = value
        widget:ApplySettings()
    end)
    scroll:AddChild(dangerIconSetting)
    

    return scrollContainer
end

local createTextSettings = function(widget, parentWindow, iconSettings, textSettings, isVerticalEnabled)
    local scrollContainer = AceGUI:Create("SimpleGroup")
    local scroll = AceGUI:Create("ScrollFrame")
    scrollContainer:SetLayout("Fill") -- important!
    scrollContainer:SetFullWidth(true)
    scrollContainer:SetHeight(parentWindow.frame:GetHeight() - 115)
    scroll:SetLayout("Flow")
    scroll:SetFullWidth(true)
    scrollContainer:AddChild(scroll)

    local textAnchor = AceGUI:Create("Dropdown")
    textAnchor:SetLabel(private.getLocalisation("TextAnchor"))
    private.AddFrameTooltip(textAnchor.frame, "TextAnchorDescription")
    if isVerticalEnabled then
        textAnchor:AddItem("TOP", private.getLocalisation("TextAnchorTop"))
        textAnchor:AddItem("BOTTOM", private.getLocalisation("TextAnchorBottom"))
    else
        textAnchor:AddItem("RIGHT", private.getLocalisation("TextAnchorRight"))
        textAnchor:AddItem("LEFT", private.getLocalisation("TextAnchorLeft"))
    end
    textAnchor:SetCallback("OnValueChanged", function(_, _, value)
        textSettings.text_anchor = value
        widget:ApplySettings()
    end)
    textAnchor:SetRelativeWidth(0.5)
    local activeAnchor = textSettings.text_anchor
    if not isVerticalEnabled and (activeAnchor == "TOP" or activeAnchor == "BOTTOM") then
        if activeAnchor == "TOP" then
            textSettings.text_anchor = "RIGHT"
        elseif activeAnchor == "BOTTOM" then
            textSettings.text_anchor = "LEFT"
        end
    elseif isVerticalEnabled then 
        if activeAnchor == "RIGHT" then
            textSettings.text_anchor = "TOP"
        elseif activeAnchor == "LEFT" then
            textSettings.text_anchor = "BOTTOM"
        end
    end
    textAnchor:SetValue(textSettings.text_anchor)
    scroll:AddChild(textAnchor)

    local textOffsetSettingX = AceGUI:Create("Slider")
    textOffsetSettingX:SetLabel(private.getLocalisation("TextOffsetX"))
    private.AddFrameTooltip(textOffsetSettingX.frame, "TextOffsetXDescription")
    textOffsetSettingX:SetSliderValues(-50, 50, 1)
    textOffsetSettingX:SetValue(iconSettings.TextOffset.x)
    textOffsetSettingX:SetCallback("OnValueChanged", function(_, _, value)
        iconSettings.TextOffset.x = value
        widget:ApplySettings()
    end)
    textOffsetSettingX:SetRelativeWidth(0.5)
    scroll:AddChild(textOffsetSettingX)


    local textOffsetSettingY = AceGUI:Create("Slider")
    textOffsetSettingY:SetLabel(private.getLocalisation("TextOffsetY"))
    private.AddFrameTooltip(textOffsetSettingY.frame, "TextOffsetYDescription")
    textOffsetSettingY:SetSliderValues(-50, 50, 1)
    textOffsetSettingY:SetValue(iconSettings.TextOffset.y)
    textOffsetSettingY:SetCallback("OnValueChanged", function(_, _, value)
        iconSettings.TextOffset.y = value
        widget:ApplySettings()
    end)
    textOffsetSettingY:SetRelativeWidth(0.5)
    scroll:AddChild(textOffsetSettingY)

    local fontSizeSetting = AceGUI:Create("Slider")
    fontSizeSetting:SetLabel(private.getLocalisation("SpellnameFontSize"))
    private.AddFrameTooltip(fontSizeSetting.frame, "SpellnameFontSizeDescription")
    fontSizeSetting:SetSliderValues(1, 64, 1)
    fontSizeSetting:SetValue(textSettings.fontSize)
    fontSizeSetting:SetCallback("OnValueChanged", function(_, _, value)
        textSettings.fontSize = value
        widget:ApplySettings()
    end)
    fontSizeSetting:SetRelativeWidth(0.5)
    scroll:AddChild(fontSizeSetting)

    local fontSetting = AceGUI:Create("Dropdown")
    fontSetting:SetText(textSettings.font)
    fontSetting:SetLabel(private.getLocalisation("SpellnameFont"))
    private.AddFrameTooltip(fontSetting.frame, "SpellnameFontDescription")
    for _, texName in ipairs(SharedMedia:List("font")) do
        fontSetting:AddItem(texName, texName)
    end
    fontSetting:SetCallback("OnValueChanged", function(_, _, value)
        textSettings.font = value
        widget:ApplySettings()
    end)
    fontSetting:SetRelativeWidth(0.5)
    scroll:AddChild(fontSetting)

    local textDefaultColorSetting = AceGUI:Create("ColorPicker")
    textDefaultColorSetting:SetLabel(private.getLocalisation("SpellnameDefaultColor"))
    private.AddFrameTooltip(textDefaultColorSetting.frame, "SpellnameDefaultColorDescription")
    textDefaultColorSetting:SetColor(textSettings.defaultColor.r,
        textSettings.defaultColor.g,
        textSettings.defaultColor.b
    )
    textDefaultColorSetting:SetCallback("OnValueChanged", function(_, _, r, g, b)
        textSettings.defaultColor.r = r
        textSettings.defaultColor.g = g
        textSettings.defaultColor.b = b
        widget:ApplySettings()
    end)
    scroll:AddChild(textDefaultColorSetting)

    local textBackgroundToggle = AceGUI:Create("CheckBox")
    textBackgroundToggle:SetValue(textSettings.useBackground)
    textBackgroundToggle:SetLabel(private.getLocalisation("SpellnameBackground"))
    private.AddFrameTooltip(textBackgroundToggle.frame, "SpellnameBackgroundDescription")
    textBackgroundToggle:SetCallback("OnValueChanged", function(_, _, value)
        textSettings.useBackground = value
        widget:ApplySettings()
    end)
    scroll:AddChild(textBackgroundToggle)

    local TextureSettings = {
    }
    for _, texName in ipairs(SharedMedia:List("background")) do
        local texPath = SharedMedia:Fetch("background", texName) or ""
        local display = ("|T%s:16:128|t %s"):format(tostring(texPath), texName)
        table.insert(TextureSettings, {
            text = display,
            value = texName,
            isRadio = false,
        })
    end
    local textBackgroundTextureSetting = AceGUI:Create("Dropdown")
    textBackgroundTextureSetting:SetText(textSettings.backgroundTexture)
    textBackgroundTextureSetting:SetLabel(private.getLocalisation("SpellnameBackgroundTexture"))
    private.AddFrameTooltip(textBackgroundTextureSetting.frame, "SpellnameBackgroundTextureDescription")
    for _, setting in ipairs(TextureSettings) do
        textBackgroundTextureSetting:AddItem(setting.value, setting.text)
    end
    textBackgroundTextureSetting:SetCallback("OnValueChanged", function(_, _, value)
        textSettings.backgroundTexture = value
        widget:ApplySettings()
    end)
    textBackgroundTextureSetting:SetRelativeWidth(1.0)
    scroll:AddChild(textBackgroundTextureSetting)

    local textBackgroundTextureOffsetX = AceGUI:Create("Slider")
    textBackgroundTextureOffsetX:SetLabel(private.getLocalisation("TextBackgroundOffsetX"))
    private.AddFrameTooltip(textBackgroundTextureOffsetX.frame, "TextBackgroundOffsetXDescription")
    textBackgroundTextureOffsetX:SetSliderValues(-50, 50, 1)
    textBackgroundTextureOffsetX:SetValue(textSettings.backgroundTextureOffset.x)
    textBackgroundTextureOffsetX:SetCallback("OnValueChanged", function(_, _, value)
        textSettings.backgroundTextureOffset.x = value
        widget:ApplySettings()
    end)
    textBackgroundTextureOffsetX:SetRelativeWidth(0.5)
    scroll:AddChild(textBackgroundTextureOffsetX)

    local textBackgroundTextureOffsetX = AceGUI:Create("Slider")
    textBackgroundTextureOffsetX:SetLabel(private.getLocalisation("TextBackgroundOffsetY"))
    private.AddFrameTooltip(textBackgroundTextureOffsetX.frame, "TextBackgroundOffsetYDescription")
    textBackgroundTextureOffsetX:SetSliderValues(-50, 50, 1)
    textBackgroundTextureOffsetX:SetValue(textSettings.backgroundTextureOffset.y)
    textBackgroundTextureOffsetX:SetCallback("OnValueChanged", function(_, _, value)
        textSettings.backgroundTextureOffset.y = value
        widget:ApplySettings()
    end)
    textBackgroundTextureOffsetX:SetRelativeWidth(0.5)
    scroll:AddChild(textBackgroundTextureOffsetX)

    return scrollContainer
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
        local time, color, useGlow, glowType, glowColor = value.time, value.color, value.useGlow, value.glowType,
        value.glowColor
        local group = AceGUI:Create("InlineGroup")
        group:SetLayout("Flow")
        group:SetFullWidth(true)

        local removeChangeButton = AceGUI:Create("Icon")
        removeChangeButton:SetImage("Interface\\AddOns\\AbilityTimeline\\Media\\Textures\\minus.tga")
        private.AddFrameTooltip(removeChangeButton.frame, "RemoveCooldownColorChangeTooltip")
        removeChangeButton:SetImageSize(24, 24)
        removeChangeButton:SetRelativeWidth(0.1)

        removeChangeButton:SetCallback("OnClick", function()
            table.remove(private.db.profile.cooldown_settings.cooldown_highlight.highlights, i)
            table.sort(private.db.profile.cooldown_settings.cooldown_highlight.highlights,
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
                table.sort(private.db.profile.cooldown_settings.cooldown_highlight.highlights,
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

        local isGlowEnabled = AceGUI:Create("CheckBox")
        isGlowEnabled:SetValue(useGlow)
        isGlowEnabled:SetLabel(private.getLocalisation("EnableCooldownGlowChange"))
        private.AddFrameTooltip(isGlowEnabled.frame, "EnableCooldownGlowChangeDescription")
        isGlowEnabled:SetCallback("OnValueChanged", function(_, _, enabled)
            value.useGlow = enabled
        end)
        group:AddChild(isGlowEnabled)

        local glowTypeSetting = AceGUI:Create("Dropdown")
        glowTypeSetting:SetLabel(private.getLocalisation("CooldownGlowType"))
        private.AddFrameTooltip(glowTypeSetting.frame, "CooldownGlowTypeDescription")
        glowTypeSetting:SetList(private.GlowTypes)
        glowTypeSetting:SetValue(glowType)
        glowTypeSetting:SetCallback("OnValueChanged", function(_, _, type)
            value.glowType = type
        end)
        glowTypeSetting:SetRelativeWidth(0.5)
        group:AddChild(glowTypeSetting)

        local glowColorPicker = AceGUI:Create("ColorPicker")
        private.AddFrameTooltip(glowColorPicker.frame, "CooldownGlowColorDescription")
        glowColorPicker:SetLabel(private.getLocalisation("CooldownGlowColor"))
        glowColorPicker:SetColor(glowColor.r, glowColor.g, glowColor.b, glowColor.a)
        glowColorPicker:SetHasAlpha(true)
        glowColorPicker:SetRelativeWidth(0.5)
        glowColorPicker:SetCallback("OnValueChanged", function(_, _, r, g, b, a)
            value.glowColor = { r = r, g = g, b = b, a = a }
        end)
        group:AddChild(glowColorPicker)



        -- add all settings to container
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
        private.db.profile.cooldown_settings.cooldown_highlight.highlights)

    addChangeButton:SetCallback("OnClick", function()
        table.insert(private.db.profile.cooldown_settings.cooldown_highlight.highlights, {
            time = 10,
            color = private.db.profile.cooldown_settings.cooldown_color
        })
        table.sort(private.db.profile.cooldown_settings.cooldown_highlight.highlights,
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
    cooldownColorChangeToggle:SetValue(private.db.profile.cooldown_settings.cooldown_highlight.enabled)
    cooldownColorChangeToggle:SetLabel(private.getLocalisation("EnableCooldownHighlight"))
    private.AddFrameTooltip(cooldownColorChangeToggle.frame, "EnableCooldownHighlightDescription")
    cooldownColorChangeToggle:SetCallback("OnValueChanged", function(_, _, value)
        private.db.profile.cooldown_settings.cooldown_highlight.enabled = value
        createCooldownSubSettings(scroll, widget)
    end)
    cooldownColorChangeToggle:SetRelativeWidth(0.5)
    scroll:AddChild(cooldownColorChangeToggle)
    if private.db.profile.cooldown_settings.cooldown_highlight.enabled then
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
local createCooldownSettings = function(widget, parentWindow)
    local scrollContainer = AceGUI:Create("SimpleGroup")
    local scroll = AceGUI:Create("ScrollFrame")
    scrollContainer:SetLayout("Fill")
    scrollContainer:SetFullWidth(true)
    scrollContainer:SetHeight(parentWindow.frame:GetHeight() - 115)
    scroll:SetLayout("Flow")
    scroll:SetFullWidth(true)
    scrollContainer:AddChild(scroll)
    -- TODO template this nonsense we should be getting arrested for this
    createCooldownSubSettings(scroll, widget)

    return scrollContainer
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
        iconFileID = 237538,
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
            tabGroup:AddChild(createTextSettings(widget, private.SPELL_ICON_SETTINGS_WINDOW, private.db.profile.icon_settings, private.db.profile.text_settings, false))
        elseif value == "CooldownSettings" then
            tabGroup:AddChild(createCooldownSettings(widget, private.SPELL_ICON_SETTINGS_WINDOW))
        else
            tabGroup:AddChild(createGeneralSettings(widget, private.SPELL_ICON_SETTINGS_WINDOW, private.db.profile.icon_settings, 100))
        end
    end)
    tabGroup:SetFullWidth(true)
    tabGroup:SelectTab("GeneralSettings")
    private.SPELL_ICON_SETTINGS_WINDOW:AddChild(tabGroup)


    return private.SPELL_ICON_SETTINGS_WINDOW
end

local createBigIconSettingsFrame = function()
    private.Debug("Creating Big Icon Settings Frame")
    private.BIG_ICON_SETTINGS_WINDOW = AceGUI:Create("AtSpellIconSettingsFrame")
    private.Debug(private.BIG_ICON_SETTINGS_WINDOW, "AT_BIG_ICON_SETTINGS_WINDOW")

    local widget = AceGUI:Create("AtBigIcon")
    local eventInfo = {
        duration = 15,
        maxQueueDuration = 0,
        spellName = private.getLocalisation("TestIcon"),
        spellID = 0,
        iconFileID = 237538,
        severity = 1,
        paused = false
    }
    widget:SetEventInfo(eventInfo, true)
    widget.startTime = GetTime()
    widget.duration = 5
    widget.frame.Cooldown:SetCooldown(widget.startTime, widget.duration)
    widget.frame:SetScript("OnUpdate", function()
        if widget.startTime + widget.duration < GetTime() then
            widget.startTime = GetTime()
            widget.frame.Cooldown:SetCooldown(widget.startTime, widget.duration)
        end
        widget.HandleCooldown(widget.frame, math.ceil((widget.startTime + widget.duration) - GetTime()))
    end) -- loop cooldown display
    widget.frame:Show()
    private.BIG_ICON_SETTINGS_WINDOW.frame.CloseButton:SetScript("OnClick", function() private.closeBigIconSettings() end)
    widget:ClearAllPoints()
    widget.frame:SetFrameStrata("DIALOG")
    widget.frame:SetPoint("CENTER", private.BIG_ICON_SETTINGS_WINDOW.rightContent, "CENTER", 0, 0)
    widget.frame:SetFrameLevel(private.BIG_ICON_SETTINGS_WINDOW.rightContent:GetFrameLevel() + 1)
    widget:SetParent(private.BIG_ICON_SETTINGS_WINDOW)

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
            local isVerticalEnabled = (private.db.global.bigicon[private.ACTIVE_EDITMODE_LAYOUT].grow_direction == "RIGHT") or
            (private.db.global.bigicon[private.ACTIVE_EDITMODE_LAYOUT].grow_direction == "LEFT")
            tabGroup:AddChild(createTextSettings(widget, private.BIG_ICON_SETTINGS_WINDOW, private.db.profile.big_icon_settings, private.db.profile.big_icon_text_settings, isVerticalEnabled))
        elseif value == "CooldownSettings" then
            tabGroup:AddChild(createCooldownSettings(widget, private.BIG_ICON_SETTINGS_WINDOW))
        else
            tabGroup:AddChild(createGeneralSettings(widget, private.BIG_ICON_SETTINGS_WINDOW, private.db.profile.big_icon_settings, 150))
        end
    end)
    tabGroup:SetFullWidth(true)
    tabGroup:SelectTab("GeneralSettings")
    private.BIG_ICON_SETTINGS_WINDOW:AddChild(tabGroup)


    return private.BIG_ICON_SETTINGS_WINDOW
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

private.openBigIconSettings = function()
    if not private.BIG_ICON_SETTINGS_WINDOW then
        createBigIconSettingsFrame()
    else
        private.BIG_ICON_SETTINGS_WINDOW.frame:Show()
    end

    if EditModeManagerFrame:IsShown() then
        private.wasEditModeOpen = true
        HideUIPanel(EditModeManagerFrame)
    end
end

private.closeBigIconSettings = function()
    private.Debug("Closing spell icon settings")
    private.BIG_ICON_SETTINGS_WINDOW.frame:Hide()
    private.BIGICON_FRAME:SetWidth(private.db.profile.big_icon_settings.size)
    private.BIGICON_FRAME:SetHeight(private.db.profile.big_icon_settings.size)

    if not EditModeManagerFrame:IsShown() and private.wasEditModeOpen then
        private.wasEditModeOpen = false
        ShowUIPanel(EditModeManagerFrame)
    end
end