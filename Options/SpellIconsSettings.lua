local appName, app = ...
---@class AbilityTimeline
local private = app
local AceGUI = LibStub("AceGUI-3.0")
local SharedMedia = LibStub("LibSharedMedia-3.0")


local getScrollHeight = function(parentWindow, tabRows)
    return parentWindow.frame:GetHeight() - 115 - (((tabRows or 1) - 1) * 20)
end

local themeValue = private.GetThemeValue
local setThemeValue = private.SetThemeModification

---adds a button below the preview that removes the player's modifications of the given theme paths
---@param window AtSpellIconSettingsFrame
---@param paths string[]
---@param onReset function
local addResetButton = function(window, paths, onReset)
    local button = CreateFrame("Button", nil, window.rightContent, "UIPanelButtonTemplate")
    private.ThemedWidgets.SkinButton(button)
    -- the controls show the values of the theme they were created in, so they are created again for another theme
    local themeKey = private.GetCurrentThemeKey()
    button.AtThemed = {
        ApplySettings = function()
            private.ThemedWidgets.DrawButton(button)
            if themeKey ~= private.GetCurrentThemeKey() then
                themeKey = private.GetCurrentThemeKey()
                C_Timer.After(0, onReset)
            end
        end
    }
    private.RegisterThemed(button.AtThemed)
    button:SetSize(160, 24)
    button:SetPoint("BOTTOM", window.rightContent, "BOTTOM", 0, 40)
    button:SetText(private.getLocalisation("ResetToTheme"))
    private.AddFrameTooltip(button, "ResetToThemeDescription")
    button:SetScript("OnClick", function()
        for _, path in ipairs(paths) do
            private.ResetThemeModifications(path)
        end
        onReset()
    end)
end

local addAdditionalInformationControls = function(scroll, widget, iconSettings, kind, extended)
    local style = "Elements." .. kind
    local dispellIconSetting = AceGUI:Create("AtCheckBox")
    dispellIconSetting:SetLabel(private.getLocalisation("IconDispellIcon"))
    private.AddFrameTooltip(dispellIconSetting.frame, "IconDispellIconDescription")
    dispellIconSetting:SetValue(iconSettings.dispellIcons)
    dispellIconSetting:SetCallback("OnValueChanged", function(_, _, value)
        iconSettings.dispellIcons = value
        widget:ApplySettings()
    end)
    scroll:AddChild(dispellIconSetting)

    if extended then
        local dispellIconSizeSetting = AceGUI:Create("AtSlider")
        dispellIconSizeSetting:SetLabel(private.getLocalisation("DispellIconSize"))
        private.AddFrameTooltip(dispellIconSizeSetting.frame, "DispellIconSizeDescription")
        dispellIconSizeSetting:SetSliderValues(1, 64, 1)
        dispellIconSizeSetting:SetValue(themeValue(style .. ".DispelIcon.Size"))
        dispellIconSizeSetting:SetCallback("OnValueChanged", function(_, _, value)
            setThemeValue(style .. ".DispelIcon.Size", value)
        end)
        dispellIconSizeSetting:SetRelativeWidth(0.5)
        scroll:AddChild(dispellIconSizeSetting)

        local dispellIconAnchorSetting = AceGUI:Create("AtDropdown")
        dispellIconAnchorSetting:SetLabel(private.getLocalisation("DispellIconAnchor"))
        private.AddFrameTooltip(dispellIconAnchorSetting.frame, "DispellIconAnchorDescription")
        for _, value in ipairs(private.AnchorPointOrder) do
            dispellIconAnchorSetting:AddItem(value, value)
        end
        dispellIconAnchorSetting:SetValue(themeValue(style .. ".DispelIcon.Anchor"))
        dispellIconAnchorSetting:SetCallback("OnValueChanged", function(_, _, value)
            setThemeValue(style .. ".DispelIcon.Anchor", value)
        end)
        dispellIconAnchorSetting:SetRelativeWidth(0.5)
        scroll:AddChild(dispellIconAnchorSetting)

        local dispellIconOffsetX = AceGUI:Create("AtSlider")
        dispellIconOffsetX:SetLabel(private.getLocalisation("DispellIconOffsetX"))
        private.AddFrameTooltip(dispellIconOffsetX.frame, "DispellIconOffsetXDescription")
        dispellIconOffsetX:SetSliderValues(-100, 100, 1)
        dispellIconOffsetX:SetValue(themeValue(style .. ".DispelIcon.Offset.x"))
        dispellIconOffsetX:SetCallback("OnValueChanged", function(_, _, value)
            setThemeValue(style .. ".DispelIcon.Offset.x", value)
        end)
        dispellIconOffsetX:SetRelativeWidth(0.5)
        scroll:AddChild(dispellIconOffsetX)

        local dispellIconOffsetY = AceGUI:Create("AtSlider")
        dispellIconOffsetY:SetLabel(private.getLocalisation("DispellIconOffsetY"))
        private.AddFrameTooltip(dispellIconOffsetY.frame, "DispellIconOffsetYDescription")
        dispellIconOffsetY:SetSliderValues(-100, 100, 1)
        dispellIconOffsetY:SetValue(themeValue(style .. ".DispelIcon.Offset.y"))
        dispellIconOffsetY:SetCallback("OnValueChanged", function(_, _, value)
            setThemeValue(style .. ".DispelIcon.Offset.y", value)
        end)
        dispellIconOffsetY:SetRelativeWidth(0.5)
        scroll:AddChild(dispellIconOffsetY)
    end

    local borderSetting = AceGUI:Create("AtDropdown")
    borderSetting:SetLabel(private.getLocalisation("IconBorder"))
    private.AddFrameTooltip(borderSetting.frame, "IconBorderDescription")

    borderSetting:AddItem(private.IconBorderSettings.dispell, private.getLocalisation("IconDispellBorder"))
    borderSetting:AddItem(private.IconBorderSettings.bossmods, private.getLocalisation("IconBossModsBorder"))
    borderSetting:AddItem(private.IconBorderSettings.none, private.getLocalisation("IconNoneBorder"))

    borderSetting:SetValue(iconSettings.border)
    borderSetting:SetCallback("OnValueChanged", function(_, _, value)
        iconSettings.border = value
        if value == private.IconBorderSettings.bossmods then
            private.ThemeApply.BossModsBorder(widget.frame, themeValue(style .. ".Border"), { r = 1, g = 0, b = 1, a = 1 })
        end
        -- shows the dispel borders and hides the boss mod border as the setting says
        widget:ApplySettings()
    end)
    scroll:AddChild(borderSetting)

    if extended then
        local borderWidthSetting = AceGUI:Create("AtSlider")
        borderWidthSetting:SetLabel(private.getLocalisation("IconBorderWidth"))
        private.AddFrameTooltip(borderWidthSetting.frame, "IconBorderWidthDescription")
        borderWidthSetting:SetSliderValues(1, 20, 1)
        borderWidthSetting:SetValue(themeValue(style .. ".BorderWidth"))
        borderWidthSetting:SetCallback("OnValueChanged", function(_, _, value)
            setThemeValue(style .. ".BorderWidth", value)
        end)
        borderWidthSetting:SetRelativeWidth(0.5)
        scroll:AddChild(borderWidthSetting)
    end

    local dispellTextColorSetting = AceGUI:Create("AtCheckBox")
    dispellTextColorSetting:SetLabel(private.getLocalisation("DispellTextColor"))
    private.AddFrameTooltip(dispellTextColorSetting.frame, "DispellTextColorDescription")
    dispellTextColorSetting:SetValue(private.db.profile.dispellTextColor)
    dispellTextColorSetting:SetCallback("OnValueChanged", function(_, _, value)
        private.db.profile.dispellTextColor = value
        if value then
            widget.frame.SpellName:SetTextColor(0, 0.5019607843137255, 1)
        else
            widget.frame.SpellName:SetTextColor(1, 1, 1)
        end
        private.ToggleEventColorisation(value)
    end)
    scroll:AddChild(dispellTextColorSetting)

    local dangerIconSetting = AceGUI:Create("AtCheckBox")
    dangerIconSetting:SetLabel(private.getLocalisation("IconDangerIcon"))
    private.AddFrameTooltip(dangerIconSetting.frame, "IconDangerIconDescription")
    dangerIconSetting:SetValue(iconSettings.dangerIcon)
    dangerIconSetting:SetCallback("OnValueChanged", function(_, _, value)
        iconSettings.dangerIcon = value
        widget:ApplySettings()
    end)
    scroll:AddChild(dangerIconSetting)

    local roleIconSetting = AceGUI:Create("AtCheckBox")
    roleIconSetting:SetLabel(private.getLocalisation("IconRoleIcons"))
    private.AddFrameTooltip(roleIconSetting.frame, "IconRoleIconsDescription")
    roleIconSetting:SetValue(iconSettings.roleIcons)
    roleIconSetting:SetCallback("OnValueChanged", function(_, _, value)
        iconSettings.roleIcons = value
        widget:ApplySettings()
    end)
    scroll:AddChild(roleIconSetting)

    if extended then
        local roleIconSizeSetting = AceGUI:Create("AtSlider")
        roleIconSizeSetting:SetLabel(private.getLocalisation("RoleIconSize"))
        private.AddFrameTooltip(roleIconSizeSetting.frame, "RoleIconSizeDescription")
        roleIconSizeSetting:SetSliderValues(1, 64, 1)
        roleIconSizeSetting:SetValue(themeValue(style .. ".RoleIcons.Size"))
        roleIconSizeSetting:SetCallback("OnValueChanged", function(_, _, value)
            setThemeValue(style .. ".RoleIcons.Size", value)
        end)
        roleIconSizeSetting:SetRelativeWidth(0.5)
        scroll:AddChild(roleIconSizeSetting)

        local roleIconAnchorSetting = AceGUI:Create("AtDropdown")
        roleIconAnchorSetting:SetLabel(private.getLocalisation("RoleIconAnchor"))
        private.AddFrameTooltip(roleIconAnchorSetting.frame, "RoleIconAnchorDescription")
        for _, value in ipairs(private.AnchorPointOrder) do
            roleIconAnchorSetting:AddItem(value, value)
        end
        roleIconAnchorSetting:SetValue(themeValue(style .. ".RoleIcons.Anchor"))
        roleIconAnchorSetting:SetCallback("OnValueChanged", function(_, _, value)
            setThemeValue(style .. ".RoleIcons.Anchor", value)
        end)
        roleIconAnchorSetting:SetRelativeWidth(0.5)
        scroll:AddChild(roleIconAnchorSetting)

        local roleIconOffsetX = AceGUI:Create("AtSlider")
        roleIconOffsetX:SetLabel(private.getLocalisation("RoleIconOffsetX"))
        private.AddFrameTooltip(roleIconOffsetX.frame, "RoleIconOffsetXDescription")
        roleIconOffsetX:SetSliderValues(-100, 100, 1)
        roleIconOffsetX:SetValue(themeValue(style .. ".RoleIcons.Offset.x"))
        roleIconOffsetX:SetCallback("OnValueChanged", function(_, _, value)
            setThemeValue(style .. ".RoleIcons.Offset.x", value)
        end)
        roleIconOffsetX:SetRelativeWidth(0.5)
        scroll:AddChild(roleIconOffsetX)

        local roleIconOffsetY = AceGUI:Create("AtSlider")
        roleIconOffsetY:SetLabel(private.getLocalisation("RoleIconOffsetY"))
        private.AddFrameTooltip(roleIconOffsetY.frame, "RoleIconOffsetYDescription")
        roleIconOffsetY:SetSliderValues(-100, 100, 1)
        roleIconOffsetY:SetValue(themeValue(style .. ".RoleIcons.Offset.y"))
        roleIconOffsetY:SetCallback("OnValueChanged", function(_, _, value)
            setThemeValue(style .. ".RoleIcons.Offset.y", value)
        end)
        roleIconOffsetY:SetRelativeWidth(0.5)
        scroll:AddChild(roleIconOffsetY)
    end
end


local createAdditionalInformationSettings = function(widget, parentWindow, iconSettings, kind, tabRows)
    local scrollContainer = AceGUI:Create("SimpleGroup")
    local scroll = AceGUI:Create("AtScrollFrame")
    scrollContainer:SetLayout("Fill") -- important!
    scrollContainer:SetFullWidth(true)
    scrollContainer:SetHeight(getScrollHeight(parentWindow, tabRows))
    scroll:SetLayout("Flow")
    scroll:SetFullWidth(true)
    scrollContainer:AddChild(scroll)

    addAdditionalInformationControls(scroll, widget, iconSettings, kind, true)

    return scrollContainer
end


local createGeneralSettings = function(widget, parentWindow, iconSettings, kind, maxIconSize, includeAdditional, tabRows)
    local style = "Elements." .. kind
    if includeAdditional == nil then includeAdditional = true end
    local scrollContainer = AceGUI:Create("SimpleGroup")
    local scroll = AceGUI:Create("AtScrollFrame")
    scrollContainer:SetLayout("Fill") -- important!
    scrollContainer:SetFullWidth(true)
    scrollContainer:SetHeight(getScrollHeight(parentWindow, tabRows))
    scroll:SetLayout("Flow")
    scroll:SetFullWidth(true)
    scrollContainer:AddChild(scroll)

    local sizeSetting = AceGUI:Create("AtSlider")
    private.Debug(sizeSetting, "AT_SPELL_ICON_SETTINGS_SIZE_SETTING")
    sizeSetting:SetLabel(private.getLocalisation("IconSize"))
    private.AddFrameTooltip(sizeSetting.frame, "IconSizeDescription")
    sizeSetting:SetSliderValues(1, maxIconSize, 1)
    -- big icons have their size per edit mode layout
    sizeSetting:SetValue(kind == "BigIcon" and private.GetBigIconSize() or themeValue(style .. ".Size"))

    sizeSetting:SetCallback("OnValueChanged", function(_, _, value)
        if kind == "BigIcon" then
            private.SetBigIconSize(value)
        else
            setThemeValue(style .. ".Size", value)
        end
    end)
    scroll:AddChild(sizeSetting)

    local zoomSetting = AceGUI:Create("AtSlider")
    zoomSetting:SetLabel(private.getLocalisation("IconZoom"))
    private.AddFrameTooltip(zoomSetting.frame, "IconZoomDescription")
    zoomSetting:SetSliderValues(0, 1, 0.01)
    zoomSetting:SetIsPercent(true)
    zoomSetting:SetValue(themeValue(style .. ".Zoom"))

    zoomSetting:SetCallback("OnValueChanged", function(_, _, value)
        setThemeValue(style .. ".Zoom", value)
    end)
    scroll:AddChild(zoomSetting)

    local strataSetting = AceGUI:Create("AtDropdown")
    strataSetting:SetLabel(private.getLocalisation("Strata"))
    for key, value in ipairs(private.FrameStrataOrder) do
        strataSetting:AddItem(value, value)
    end
    strataSetting:SetCallback("OnValueChanged", function(_, _, value)
        iconSettings.strata = value
        widget:ApplySettings()
    end)
    strataSetting:SetValue(iconSettings.strata)
    strataSetting:SetRelativeWidth(0.5)
    scroll:AddChild(strataSetting)

    local useTooltipSetting = AceGUI:Create("AtDropdown")
    useTooltipSetting:SetLabel(private.getLocalisation("UseTooltip"))
    private.AddFrameTooltip(useTooltipSetting.frame, "UseTooltipDescription")
    for key, value in pairs(Enum.EncounterEventsTooltipAnchor) do
        useTooltipSetting:AddItem(value, key)
    end
    useTooltipSetting:SetValue(iconSettings.useTooltip)
    useTooltipSetting:SetCallback("OnValueChanged", function(_, _, value)
        iconSettings.useTooltip = value
    end)
    useTooltipSetting:SetRelativeWidth(0.5)
    scroll:AddChild(useTooltipSetting)

    if includeAdditional then
        addAdditionalInformationControls(scroll, widget, iconSettings, kind, false)
    end

    return scrollContainer
end

local createHighlightTextGeneralSettings = function(widget, parentWindow, Settings, tabRows)
    local scrollContainer = AceGUI:Create("SimpleGroup")
    local scroll = AceGUI:Create("AtScrollFrame")
    scrollContainer:SetLayout("Fill") -- important!
    scrollContainer:SetFullWidth(true)
    scrollContainer:SetHeight(getScrollHeight(parentWindow, tabRows))
    scroll:SetLayout("Flow")
    scroll:SetFullWidth(true)
    scrollContainer:AddChild(scroll)

    local strataSetting = AceGUI:Create("AtDropdown")
    strataSetting:SetLabel(private.getLocalisation("Strata"))
    for key, value in ipairs(private.FrameStrataOrder) do
        strataSetting:AddItem(value, value)
    end
    strataSetting:SetCallback("OnValueChanged", function(_, _, value)
        Settings.strata = value
        widget:ApplySettings()
    end)
    strataSetting:SetValue(Settings.strata)
    strataSetting:SetRelativeWidth(0.5)
    scroll:AddChild(strataSetting)


    local dispellIconSetting = AceGUI:Create("AtCheckBox")
    dispellIconSetting:SetLabel(private.getLocalisation("TextDispellIcon"))
    private.AddFrameTooltip(dispellIconSetting.frame, "TextDispellIconDescription")
    dispellIconSetting:SetValue(Settings.dispellIcons)
    dispellIconSetting:SetCallback("OnValueChanged", function(_, _, value)
        Settings.dispellIcons = value
    end)
    scroll:AddChild(dispellIconSetting)

    local dispellTextColorSetting = AceGUI:Create("AtCheckBox")
    dispellTextColorSetting:SetLabel(private.getLocalisation("DispellTextColor"))
    private.AddFrameTooltip(dispellTextColorSetting.frame, "DispellTextColorDescription")
    dispellTextColorSetting:SetValue(private.db.profile.dispellTextColor)
    dispellTextColorSetting:SetCallback("OnValueChanged", function(_, _, value)
        private.db.profile.dispellTextColor = value
        if value then
            widget.frame.SpellName:SetTextColor(0, 0.5019607843137255, 1)
        else
            widget.frame.SpellName:SetTextColor(1, 1, 1)
        end
        private.ToggleEventColorisation(value)
    end)
    scroll:AddChild(dispellTextColorSetting)

    -- local dangerIconSetting = AceGUI:Create("AtCheckBox")
    -- dangerIconSetting:SetLabel(private.getLocalisation("IconDangerIcon"))
    -- private.AddFrameTooltip(dangerIconSetting.frame, "IconDangerIconDescription")
    -- dangerIconSetting:SetValue(Settings.dangerIcon)
    -- dangerIconSetting:SetCallback("OnValueChanged", function(_, _, value)
    --     Settings.dangerIcon = value
    --     widget:ApplySettings()
    -- end)
    -- scroll:AddChild(dangerIconSetting)

    return scrollContainer
end

local createTextSettings = function(widget, parentWindow, kind, textSettings, isVerticalEnabled, tabRows)
    local style = "Elements." .. kind .. ".Text"
    local scrollContainer = AceGUI:Create("SimpleGroup")
    local scroll = AceGUI:Create("AtScrollFrame")
    scrollContainer:SetLayout("Fill") -- important!
    scrollContainer:SetFullWidth(true)
    scrollContainer:SetHeight(getScrollHeight(parentWindow, tabRows))
    scroll:SetLayout("Flow")
    scroll:SetFullWidth(true)
    scrollContainer:AddChild(scroll)

    local textAnchor = AceGUI:Create("AtDropdown")
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
        setThemeValue(style .. ".Anchor", value)
    end)
    textAnchor:SetRelativeWidth(0.5)
    local activeAnchor = themeValue(style .. ".Anchor")
    if not isVerticalEnabled and (activeAnchor == "TOP" or activeAnchor == "BOTTOM") then
        if activeAnchor == "TOP" then
            setThemeValue(style .. ".Anchor", "RIGHT")
        elseif activeAnchor == "BOTTOM" then
            setThemeValue(style .. ".Anchor", "LEFT")
        end
    elseif isVerticalEnabled then
        if activeAnchor == "RIGHT" then
            setThemeValue(style .. ".Anchor", "TOP")
        elseif activeAnchor == "LEFT" then
            setThemeValue(style .. ".Anchor", "BOTTOM")
        end
    end
    textAnchor:SetValue(themeValue(style .. ".Anchor"))
    scroll:AddChild(textAnchor)

    local textOffsetSettingX = AceGUI:Create("AtSlider")
    textOffsetSettingX:SetLabel(private.getLocalisation("TextOffsetX"))
    private.AddFrameTooltip(textOffsetSettingX.frame, "TextOffsetXDescription")
    textOffsetSettingX:SetSliderValues(-50, 50, 1)
    textOffsetSettingX:SetValue(themeValue(style .. ".Offset.x"))
    textOffsetSettingX:SetCallback("OnValueChanged", function(_, _, value)
        setThemeValue(style .. ".Offset.x", value)
    end)
    textOffsetSettingX:SetRelativeWidth(0.5)
    scroll:AddChild(textOffsetSettingX)


    local textOffsetSettingY = AceGUI:Create("AtSlider")
    textOffsetSettingY:SetLabel(private.getLocalisation("TextOffsetY"))
    private.AddFrameTooltip(textOffsetSettingY.frame, "TextOffsetYDescription")
    textOffsetSettingY:SetSliderValues(-50, 50, 1)
    textOffsetSettingY:SetValue(themeValue(style .. ".Offset.y"))
    textOffsetSettingY:SetCallback("OnValueChanged", function(_, _, value)
        setThemeValue(style .. ".Offset.y", value)
    end)
    textOffsetSettingY:SetRelativeWidth(0.5)
    scroll:AddChild(textOffsetSettingY)

    local fontSizeSetting = AceGUI:Create("AtSlider")
    fontSizeSetting:SetLabel(private.getLocalisation("SpellnameFontSize"))
    private.AddFrameTooltip(fontSizeSetting.frame, "SpellnameFontSizeDescription")
    fontSizeSetting:SetSliderValues(1, 64, 1)
    fontSizeSetting:SetValue(themeValue(style .. ".Font.Size"))
    fontSizeSetting:SetCallback("OnValueChanged", function(_, _, value)
        setThemeValue(style .. ".Font.Size", value)
    end)
    fontSizeSetting:SetRelativeWidth(0.5)
    scroll:AddChild(fontSizeSetting)

    local fontSetting = AceGUI:Create("AtDropdown")
    fontSetting:SetValue(themeValue(style .. ".Font.Media"))
    fontSetting:SetText(themeValue(style .. ".Font.Media"))
    fontSetting:SetLabel(private.getLocalisation("SpellnameFont"))
    private.AddFrameTooltip(fontSetting.frame, "SpellnameFontDescription")
    for _, texName in ipairs(SharedMedia:List("font")) do
        fontSetting:AddItem(texName, texName)
    end
    fontSetting:SetCallback("OnValueChanged", function(_, _, value)
        setThemeValue(style .. ".Font.Media", value)
    end)
    fontSetting:SetRelativeWidth(0.5)
    scroll:AddChild(fontSetting)

    local fontFlagSetting = AceGUI:Create("AtDropdown")
    fontFlagSetting:SetLabel(private.getLocalisation("SpellnameFontFlag"))
    private.AddFrameTooltip(fontFlagSetting.frame, "SpellnameFontFlagDescription")
    fontFlagSetting:AddItem("MONOCHROME", "MONOCHROME")
    fontFlagSetting:AddItem("OUTLINE", "OUTLINE")
    fontFlagSetting:AddItem("THICKOUTLINE", "THICKOUTLINE")
    fontFlagSetting:AddItem("SLUG", "SLUG")
    fontFlagSetting:SetMultiselect(true)
    fontFlagSetting:SetCallback("OnValueChanged", function(_, _, key, value)
        setThemeValue(style .. ".Font.Flags." .. key, value)
    end)
    for key, value in pairs(themeValue(style .. ".Font.Flags") or {}) do
        fontFlagSetting:SetItemValue(key, value)
    end
    fontFlagSetting:SetRelativeWidth(0.5)
    scroll:AddChild(fontFlagSetting)

    local textUseEventColorToggle = AceGUI:Create("AtCheckBox")
    textUseEventColorToggle:SetValue(textSettings.useEventColor)
    textUseEventColorToggle:SetRelativeWidth(0.5)
    textUseEventColorToggle:SetLabel(private.getLocalisation("SpellnameUseEventColor"))
    private.AddFrameTooltip(textUseEventColorToggle.frame, "SpellnameUseEventColorDescription")
    scroll:AddChild(textUseEventColorToggle)

    local textDefaultColorSetting = AceGUI:Create("AtColorPicker") -- forward declaration so we can use it in event callback
    textUseEventColorToggle:SetCallback("OnValueChanged", function(_, _, value)
        textSettings.useEventColor = value
        widget:ApplySettings()
        textDefaultColorSetting:SetDisabled(value)
    end)
    textDefaultColorSetting:SetDisabled(textSettings.useEventColor)



    textDefaultColorSetting:SetRelativeWidth(0.5)
    textDefaultColorSetting:SetLabel(private.getLocalisation("SpellnameDefaultColor"))
    private.AddFrameTooltip(textDefaultColorSetting.frame, "SpellnameDefaultColorDescription")
    textDefaultColorSetting:SetColor(private.ThemeApply.Color(themeValue(style .. ".Font.Color")))
    textDefaultColorSetting:SetCallback("OnValueChanged", function(_, _, r, g, b)
        setThemeValue(style .. ".Font.Color", { r = r, g = g, b = b })
    end)
    scroll:AddChild(textDefaultColorSetting)

    local textShadowToggle = AceGUI:Create("AtCheckBox")
    textShadowToggle:SetValue(themeValue(style .. ".Font.Shadow"))
    textShadowToggle:SetLabel(private.getLocalisation("SpellnameEnableShadow"))
    private.AddFrameTooltip(textShadowToggle.frame, "SpellnameEnableShadowDescription")
    textShadowToggle:SetCallback("OnValueChanged", function(_, _, value)
        setThemeValue(style .. ".Font.Shadow", value)
    end)
    scroll:AddChild(textShadowToggle)

    local textBackgroundToggle = AceGUI:Create("AtCheckBox")
    textBackgroundToggle:SetValue(themeValue(style .. ".Background.Show"))
    textBackgroundToggle:SetLabel(private.getLocalisation("SpellnameBackground"))
    private.AddFrameTooltip(textBackgroundToggle.frame, "SpellnameBackgroundDescription")
    textBackgroundToggle:SetCallback("OnValueChanged", function(_, _, value)
        setThemeValue(style .. ".Background.Show", value)
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
    local textBackgroundTextureSetting = AceGUI:Create("AtDropdown")
    textBackgroundTextureSetting:SetText(themeValue(style .. ".Background.Media"))
    textBackgroundTextureSetting:SetLabel(private.getLocalisation("SpellnameBackgroundTexture"))
    private.AddFrameTooltip(textBackgroundTextureSetting.frame, "SpellnameBackgroundTextureDescription")
    for _, setting in ipairs(TextureSettings) do
        textBackgroundTextureSetting:AddItem(setting.value, setting.text)
    end
    textBackgroundTextureSetting:SetCallback("OnValueChanged", function(_, _, value)
        setThemeValue(style .. ".Background.Media", value)
    end)
    textBackgroundTextureSetting:SetRelativeWidth(1.0)
    scroll:AddChild(textBackgroundTextureSetting)

    local textBackgroundTextureOffsetX = AceGUI:Create("AtSlider")
    textBackgroundTextureOffsetX:SetLabel(private.getLocalisation("TextBackgroundOffsetX"))
    private.AddFrameTooltip(textBackgroundTextureOffsetX.frame, "TextBackgroundOffsetXDescription")
    textBackgroundTextureOffsetX:SetSliderValues(-50, 50, 1)
    textBackgroundTextureOffsetX:SetValue(themeValue(style .. ".Background.Offset.x"))
    textBackgroundTextureOffsetX:SetCallback("OnValueChanged", function(_, _, value)
        setThemeValue(style .. ".Background.Offset.x", value)
    end)
    textBackgroundTextureOffsetX:SetRelativeWidth(0.5)
    scroll:AddChild(textBackgroundTextureOffsetX)

    local textBackgroundTextureOffsetX = AceGUI:Create("AtSlider")
    textBackgroundTextureOffsetX:SetLabel(private.getLocalisation("TextBackgroundOffsetY"))
    private.AddFrameTooltip(textBackgroundTextureOffsetX.frame, "TextBackgroundOffsetYDescription")
    textBackgroundTextureOffsetX:SetSliderValues(-50, 50, 1)
    textBackgroundTextureOffsetX:SetValue(themeValue(style .. ".Background.Offset.y"))
    textBackgroundTextureOffsetX:SetCallback("OnValueChanged", function(_, _, value)
        setThemeValue(style .. ".Background.Offset.y", value)
    end)
    textBackgroundTextureOffsetX:SetRelativeWidth(0.5)
    scroll:AddChild(textBackgroundTextureOffsetX)

    return scrollContainer
end

local createHighlightTextTextSettings = function(widget, parentWindow, tabRows)
    local style = "Elements.TextHighlight.Text"
    local scrollContainer = AceGUI:Create("SimpleGroup")
    local scroll = AceGUI:Create("AtScrollFrame")
    scrollContainer:SetLayout("Fill") -- important!
    scrollContainer:SetFullWidth(true)
    scrollContainer:SetHeight(getScrollHeight(parentWindow, tabRows))
    scroll:SetLayout("Flow")
    scroll:SetFullWidth(true)
    scrollContainer:AddChild(scroll)

    local fontSizeSetting = AceGUI:Create("AtSlider")
    fontSizeSetting:SetLabel(private.getLocalisation("SpellnameFontSize"))
    private.AddFrameTooltip(fontSizeSetting.frame, "SpellnameFontSizeDescription")
    fontSizeSetting:SetSliderValues(1, 64, 1)
    fontSizeSetting:SetValue(themeValue(style .. ".Font.Size"))
    fontSizeSetting:SetCallback("OnValueChanged", function(_, _, value)
        setThemeValue(style .. ".Font.Size", value)
    end)
    fontSizeSetting:SetRelativeWidth(0.5)
    scroll:AddChild(fontSizeSetting)

    local fontSetting = AceGUI:Create("AtDropdown")
    fontSetting:SetText(themeValue(style .. ".Font.Media"))
    fontSetting:SetLabel(private.getLocalisation("SpellnameFont"))
    private.AddFrameTooltip(fontSetting.frame, "SpellnameFontDescription")
    for _, texName in ipairs(SharedMedia:List("font")) do
        fontSetting:AddItem(texName, texName)
    end
    fontSetting:SetCallback("OnValueChanged", function(_, _, value)
        setThemeValue(style .. ".Font.Media", value)
    end)
    fontSetting:SetRelativeWidth(0.5)
    scroll:AddChild(fontSetting)

    local textDefaultColorSetting = AceGUI:Create("AtColorPicker")
    textDefaultColorSetting:SetLabel(private.getLocalisation("SpellnameDefaultColor"))
    private.AddFrameTooltip(textDefaultColorSetting.frame, "SpellnameDefaultColorDescription")
    textDefaultColorSetting:SetColor(private.ThemeApply.Color(themeValue(style .. ".Font.Color")))
    textDefaultColorSetting:SetCallback("OnValueChanged", function(_, _, r, g, b)
        setThemeValue(style .. ".Font.Color", { r = r, g = g, b = b })
    end)
    scroll:AddChild(textDefaultColorSetting)

    local textShadowToggle = AceGUI:Create("AtCheckBox")
    textShadowToggle:SetValue(themeValue(style .. ".Font.Shadow"))
    textShadowToggle:SetLabel(private.getLocalisation("SpellnameEnableShadow"))
    private.AddFrameTooltip(textShadowToggle.frame, "SpellnameEnableShadowDescription")
    textShadowToggle:SetCallback("OnValueChanged", function(_, _, value)
        setThemeValue(style .. ".Font.Shadow", value)
    end)
    scroll:AddChild(textShadowToggle)

    local textBackgroundToggle = AceGUI:Create("AtCheckBox")
    textBackgroundToggle:SetValue(themeValue(style .. ".Background.Show"))
    textBackgroundToggle:SetLabel(private.getLocalisation("SpellnameBackground"))
    private.AddFrameTooltip(textBackgroundToggle.frame, "SpellnameBackgroundDescription")
    textBackgroundToggle:SetCallback("OnValueChanged", function(_, _, value)
        setThemeValue(style .. ".Background.Show", value)
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
    local textBackgroundTextureSetting = AceGUI:Create("AtDropdown")
    textBackgroundTextureSetting:SetText(themeValue(style .. ".Background.Media"))
    textBackgroundTextureSetting:SetLabel(private.getLocalisation("SpellnameBackgroundTexture"))
    private.AddFrameTooltip(textBackgroundTextureSetting.frame, "SpellnameBackgroundTextureDescription")
    for _, setting in ipairs(TextureSettings) do
        textBackgroundTextureSetting:AddItem(setting.value, setting.text)
    end
    textBackgroundTextureSetting:SetCallback("OnValueChanged", function(_, _, value)
        setThemeValue(style .. ".Background.Media", value)
    end)
    textBackgroundTextureSetting:SetRelativeWidth(1.0)
    scroll:AddChild(textBackgroundTextureSetting)

    local textBackgroundTextureOffsetX = AceGUI:Create("AtSlider")
    textBackgroundTextureOffsetX:SetLabel(private.getLocalisation("TextBackgroundOffsetX"))
    private.AddFrameTooltip(textBackgroundTextureOffsetX.frame, "TextBackgroundOffsetXDescription")
    textBackgroundTextureOffsetX:SetSliderValues(-50, 50, 1)
    textBackgroundTextureOffsetX:SetValue(themeValue(style .. ".Background.Offset.x"))
    textBackgroundTextureOffsetX:SetCallback("OnValueChanged", function(_, _, value)
        setThemeValue(style .. ".Background.Offset.x", value)
    end)
    textBackgroundTextureOffsetX:SetRelativeWidth(0.5)
    scroll:AddChild(textBackgroundTextureOffsetX)

    local textBackgroundTextureOffsetX = AceGUI:Create("AtSlider")
    textBackgroundTextureOffsetX:SetLabel(private.getLocalisation("TextBackgroundOffsetY"))
    private.AddFrameTooltip(textBackgroundTextureOffsetX.frame, "TextBackgroundOffsetYDescription")
    textBackgroundTextureOffsetX:SetSliderValues(-50, 50, 1)
    textBackgroundTextureOffsetX:SetValue(themeValue(style .. ".Background.Offset.y"))
    textBackgroundTextureOffsetX:SetCallback("OnValueChanged", function(_, _, value)
        setThemeValue(style .. ".Background.Offset.y", value)
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
local handleCooldownColorChangeOptions = function(parentGroup, scrollContainer, widget, cooldownColorChanges,
                                                  disableGlowSettings, disableFontSettings)
end                                                                                             -- this weird syntax is needed to allow recursion
handleCooldownColorChangeOptions = function(parentGroup, scrollContainer, widget, cooldownColorChanges,
                                            disableGlowSettings, disableFontSettings)
    parentGroup:ReleaseChildren()
    for i, value in pairs(cooldownColorChanges) do
        local time, color, useGlow, glowType, glowColor = value.time, value.color, value.useGlow, value.glowType,
            value.glowColor
        local group = AceGUI:Create("AtInlineGroup")
        group:SetLayout("Flow")
        group:SetFullWidth(true)

        local removeChangeButton = AceGUI:Create("Icon")
        removeChangeButton:SetImage(private.ThemeApply.File("minus"))
        removeChangeButton.image:SetVertexColor(private.ThemeApply.Color("Danger"))
        private.AddFrameTooltip(removeChangeButton.frame, "RemoveCooldownColorChangeTooltip")
        removeChangeButton:SetImageSize(24, 24)
        removeChangeButton:SetRelativeWidth(0.1)

        removeChangeButton:SetCallback("OnClick", function()
            table.remove(private.db.profile.cooldown_settings.cooldown_highlight.highlights, i)
            table.sort(private.db.profile.cooldown_settings.cooldown_highlight.highlights,
                function(a, b) return a.time < b.time end)
            createCooldownSubSettings(scrollContainer, widget, disableGlowSettings, disableFontSettings)
        end)

        group:AddChild(removeChangeButton)

        local timeSetting = AceGUI:Create("AtEditBox")
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

        local colorPicker = AceGUI:Create("AtColorPicker")
        private.AddFrameTooltip(colorPicker.frame, "CooldownColorChangeColorDescription")
        colorPicker:SetLabel(private.getLocalisation("CooldownColorChangeColor"))
        colorPicker:SetColor(color.r, color.g, color.b)
        colorPicker:SetRelativeWidth(0.4)
        group:AddChild(colorPicker)

        colorPicker:SetCallback("OnValueChanged", function(_, _, r, g, b)
            value.color = { r = r, g = g, b = b }
        end)
        if not disableGlowSettings then
            local isGlowEnabled = AceGUI:Create("AtCheckBox")
            isGlowEnabled:SetValue(useGlow)
            isGlowEnabled:SetLabel(private.getLocalisation("EnableCooldownGlowChange"))
            private.AddFrameTooltip(isGlowEnabled.frame, "EnableCooldownGlowChangeDescription")
            isGlowEnabled:SetCallback("OnValueChanged", function(_, _, enabled)
                value.useGlow = enabled
            end)
            group:AddChild(isGlowEnabled)

            local glowTypeSetting = AceGUI:Create("AtDropdown")
            glowTypeSetting:SetLabel(private.getLocalisation("CooldownGlowType"))
            private.AddFrameTooltip(glowTypeSetting.frame, "CooldownGlowTypeDescription")
            glowTypeSetting:SetList(private.GlowTypes)
            glowTypeSetting:SetValue(glowType)
            glowTypeSetting:SetCallback("OnValueChanged", function(_, _, type)
                value.glowType = type
            end)
            glowTypeSetting:SetRelativeWidth(0.5)
            group:AddChild(glowTypeSetting)

            local glowColorPicker = AceGUI:Create("AtColorPicker")
            private.AddFrameTooltip(glowColorPicker.frame, "CooldownGlowColorDescription")
            glowColorPicker:SetLabel(private.getLocalisation("CooldownGlowColor"))
            glowColorPicker:SetColor(glowColor.r, glowColor.g, glowColor.b, glowColor.a)
            glowColorPicker:SetHasAlpha(true)
            glowColorPicker:SetRelativeWidth(0.5)
            glowColorPicker:SetCallback("OnValueChanged", function(_, _, r, g, b, a)
                value.glowColor = { r = r, g = g, b = b, a = a }
            end)
            group:AddChild(glowColorPicker)
        end


        -- add all settings to container
        parentGroup:AddChild(group)
    end
    scrollContainer:DoLayout()
end

local addCooldownColorHighlightSettings = function(cooldownColorChangeGroup, scroll, widget, disableGlowSettings,
                                                   disableFontSettings)
    local cooldownColorChangeLabel = AceGUI:Create("Label")
    cooldownColorChangeLabel:SetText(private.getLocalisation("CooldownColorChanges"))
    cooldownColorChangeLabel:SetRelativeWidth(0.5)
    cooldownColorChangeGroup:AddChild(cooldownColorChangeLabel)

    local addChangeButton = AceGUI:Create("Icon")
    addChangeButton:SetImage(private.ThemeApply.File("plus"))
    addChangeButton.image:SetVertexColor(private.ThemeApply.Color("Accent"))
    private.AddFrameTooltip(addChangeButton.frame, "AddCooldownColorChangeTooltip")
    addChangeButton:SetImageSize(24, 24)
    addChangeButton:SetRelativeWidth(0.5)
    cooldownColorChangeGroup:AddChild(addChangeButton)

    local cooldownColorChangeCreator = AceGUI:Create("SimpleGroup")
    cooldownColorChangeCreator:SetFullWidth(true)
    cooldownColorChangeCreator:SetLayout("Flow")

    handleCooldownColorChangeOptions(cooldownColorChangeCreator, scroll, widget,
        private.db.profile.cooldown_settings.cooldown_highlight.highlights, disableGlowSettings, disableFontSettings)

    addChangeButton:SetCallback("OnClick", function()
        table.insert(private.db.profile.cooldown_settings.cooldown_highlight.highlights, {
            time = 10,
            color = private.DeepCopy(themeValue("Elements.Cooldown.Font.Color")),
            useGlow = false,
            glowType = private.GlowTypes.PROC,
            glowColor = { r = 1, g = 1, b = 1, a = 1 },
        })
        table.sort(private.db.profile.cooldown_settings.cooldown_highlight.highlights,
            function(a, b) return a.time < b.time end)
        createCooldownSubSettings(scroll, widget, disableGlowSettings, disableFontSettings)
    end)

    cooldownColorChangeGroup:AddChild(cooldownColorChangeCreator)
end

createCooldownSubSettings = function(scroll, widget, disableGlowSettings, disableFontSettings)
    scroll:ReleaseChildren()
    if not disableFontSettings then
        local fontSizeSetting = AceGUI:Create("AtSlider")
        fontSizeSetting:SetLabel(private.getLocalisation("CooldownFontSize"))
        private.AddFrameTooltip(fontSizeSetting.frame, "CooldownFontSizeDescription")
        fontSizeSetting:SetSliderValues(1, 64, 1)
        fontSizeSetting:SetValue(themeValue("Elements.Cooldown.Font.Size"))
        fontSizeSetting:SetRelativeWidth(0.5)
        fontSizeSetting:SetCallback("OnValueChanged", function(_, _, value)
            setThemeValue("Elements.Cooldown.Font.Size", value)
        end)
        scroll:AddChild(fontSizeSetting)

        local fontSetting = AceGUI:Create("AtDropdown")
        fontSetting:SetText(themeValue("Elements.Cooldown.Font.Media"))
        fontSetting:SetLabel(private.getLocalisation("CooldownFont"))
        private.AddFrameTooltip(fontSetting.frame, "CooldownFontDescription")
        for _, texName in ipairs(SharedMedia:List("font")) do
            fontSetting:AddItem(texName, texName)
        end
        fontSetting:SetCallback("OnValueChanged", function(_, _, value)
            setThemeValue("Elements.Cooldown.Font.Media", value)
        end)
        fontSetting:SetRelativeWidth(0.5)
        scroll:AddChild(fontSetting)
    end

    local defaultCooldownColorPicker = AceGUI:Create("AtColorPicker")
    defaultCooldownColorPicker:SetLabel(private.getLocalisation("DefaultCooldownColor"))
    defaultCooldownColorPicker:SetColor(private.ThemeApply.Color(themeValue("Elements.Cooldown.Font.Color")))

    defaultCooldownColorPicker:SetCallback("OnValueChanged", function(_, _, r, g, b)
        setThemeValue("Elements.Cooldown.Font.Color", { r = r, g = g, b = b })
    end)
    defaultCooldownColorPicker:SetRelativeWidth(0.5)
    scroll:AddChild(defaultCooldownColorPicker)


    local cooldownColorChangeToggle = AceGUI:Create("AtCheckBox")
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
        local cooldownColorChangeGroup = AceGUI:Create("AtInlineGroup")
        cooldownColorChangeGroup:SetLayout("Flow")
        cooldownColorChangeGroup:SetFullWidth(true)
        addCooldownColorHighlightSettings(cooldownColorChangeGroup, scroll, disableGlowSettings, disableFontSettings)
        scroll:AddChild(cooldownColorChangeGroup)
    end
end
---Creates the cooldown settings tab content
---@param widget AceGUIWidget
---@return AceGUIWidget
local createCooldownSettings = function(widget, parentWindow, disableGlowSettings, disableFontSettings, tabRows)
    local scrollContainer = AceGUI:Create("SimpleGroup")
    local scroll = AceGUI:Create("AtScrollFrame")
    scrollContainer:SetLayout("Fill")
    scrollContainer:SetFullWidth(true)
    scrollContainer:SetHeight(getScrollHeight(parentWindow, tabRows))
    scroll:SetLayout("Flow")
    scroll:SetFullWidth(true)
    scrollContainer:AddChild(scroll)
    -- TODO template this nonsense we should be getting arrested for this
    createCooldownSubSettings(scroll, widget, disableGlowSettings, disableFontSettings)

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
        paused = false,
        color = { r = 1, g = 1, b = 1, a = 1 },
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

    widget.frame.dispellTypeIcons[1]:SetAtlas('icons_16x16_magic')
    widget:ApplySettings()
    local border = private.GetElementStyle("SpellIcon").Border
    private.ThemeApply.DispelBorder(widget.frame, 3, border)
    widget.frame.RoleIcons[1]:SetAtlas('icons_16x16_heal')
    widget.frame.DangerIcon[1]:SetAtlas('icons_16x16_deadly')
    if private.db.profile.icon_settings.border == private.IconBorderSettings.bossmods then
        private.ThemeApply.BossModsBorder(widget.frame, border, { r = 1, g = 20 / 255, b = 147 / 255, a = 1 })
    end
    widget.frame:Show()
    widget.frame:SetFrameStrata("DIALOG")
    widget.frame:SetPoint("CENTER", private.SPELL_ICON_SETTINGS_WINDOW.rightContent, "CENTER", 0, 0)
    widget.frame:SetFrameLevel(private.SPELL_ICON_SETTINGS_WINDOW.rightContent:GetFrameLevel() + 1)
    widget:SetParent(private.SPELL_ICON_SETTINGS_WINDOW)

    if private.db.profile.dispellTextColor then
        widget.frame.SpellName:SetTextColor(0, 0.5019607843137255, 1)
    end

    local tabGroup = AceGUI:Create("AtTabGroup")
    tabGroup:SetTabs({
        {
            text = private.getLocalisation("GeneralSettings"),
            value = "GeneralSettings"
        },
        {
            text = private.getLocalisation("AdditionalSettings"),
            value = "AdditionalSettings"
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
    local selectedTab = "GeneralSettings"
    tabGroup:SetCallback("OnGroupSelected", function(_, _, value)
        private.Debug("Selected tab: " .. value)
        selectedTab = value
        tabGroup:ReleaseChildren()
        if value == "TextSettings" then
            tabGroup:AddChild(createTextSettings(widget, private.SPELL_ICON_SETTINGS_WINDOW,
                "SpellIcon", private.db.profile.text_settings, false, 2))
        elseif value == "CooldownSettings" then
            tabGroup:AddChild(createCooldownSettings(widget, private.SPELL_ICON_SETTINGS_WINDOW, nil, nil, 2))
        elseif value == "AdditionalSettings" then
            tabGroup:AddChild(createAdditionalInformationSettings(widget, private.SPELL_ICON_SETTINGS_WINDOW,
                private.db.profile.icon_settings, "SpellIcon", 2))
        else
            tabGroup:AddChild(createGeneralSettings(widget, private.SPELL_ICON_SETTINGS_WINDOW,
                private.db.profile.icon_settings, "SpellIcon", 100, false, 2))
        end
    end)
    tabGroup:SetFullWidth(true)
    tabGroup:SelectTab("GeneralSettings")
    private.SPELL_ICON_SETTINGS_WINDOW:AddChild(tabGroup)
    addResetButton(private.SPELL_ICON_SETTINGS_WINDOW, { "Elements.SpellIcon", "Elements.Cooldown" }, function()
        tabGroup:SelectTab(selectedTab)
    end)


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
        paused = false,
        color = { r = 1, g = 1, b = 1, a = 1 },
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
    widget.frame.DispellTypeIcons[1]:SetAtlas('icons_16x16_magic')
    widget:ApplySettings()
    local border = private.GetElementStyle("BigIcon").Border
    private.ThemeApply.DispelBorder(widget.frame, 3, border)
    widget.frame.RoleIcons[1]:SetAtlas('icons_16x16_heal')
    widget.frame.DangerIcon[1]:SetAtlas('icons_16x16_deadly')
    if private.db.profile.big_icon_settings.border == private.IconBorderSettings.bossmods then
        private.ThemeApply.BossModsBorder(widget.frame, border, { r = 1, g = 20 / 255, b = 147 / 255, a = 1 })
    end
    widget.frame:Show()
    private.BIG_ICON_SETTINGS_WINDOW.frame.CloseButton:SetScript("OnClick", function() private.closeBigIconSettings() end)
    widget:ClearAllPoints()
    widget.frame:SetFrameStrata("DIALOG")
    widget.frame:SetPoint("CENTER", private.BIG_ICON_SETTINGS_WINDOW.rightContent, "CENTER", 0, 0)
    widget.frame:SetFrameLevel(private.BIG_ICON_SETTINGS_WINDOW.rightContent:GetFrameLevel() + 1)
    widget:SetParent(private.BIG_ICON_SETTINGS_WINDOW)

    local tabGroup = AceGUI:Create("AtTabGroup")
    tabGroup:SetTabs({
        {
            text = private.getLocalisation("GeneralSettings"),
            value = "GeneralSettings"
        },
        {
            text = private.getLocalisation("AdditionalSettings"),
            value = "AdditionalSettings"
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
    local selectedTab = "GeneralSettings"
    tabGroup:SetCallback("OnGroupSelected", function(_, _, value)
        private.Debug("Selected tab: " .. value)
        selectedTab = value
        tabGroup:ReleaseChildren()
        if value == "TextSettings" then
            local growDirection = private.db.global.bigicon[private.ACTIVE_EDITMODE_LAYOUT].grow_direction
            local isVerticalEnabled = growDirection == "RIGHT" or growDirection == "LEFT" or growDirection == "HORIZONTAL"
            tabGroup:AddChild(createTextSettings(widget, private.BIG_ICON_SETTINGS_WINDOW,
                "BigIcon", private.db.profile.big_icon_text_settings, isVerticalEnabled, 2))
        elseif value == "CooldownSettings" then
            tabGroup:AddChild(createCooldownSettings(widget, private.BIG_ICON_SETTINGS_WINDOW, nil, nil, 2))
        elseif value == "AdditionalSettings" then
            tabGroup:AddChild(createAdditionalInformationSettings(widget, private.BIG_ICON_SETTINGS_WINDOW,
                private.db.profile.big_icon_settings, "BigIcon", 2))
        else
            tabGroup:AddChild(createGeneralSettings(widget, private.BIG_ICON_SETTINGS_WINDOW,
                private.db.profile.big_icon_settings, "BigIcon", 150, false, 2))
        end
    end)
    tabGroup:SetFullWidth(true)
    tabGroup:SelectTab("GeneralSettings")
    private.BIG_ICON_SETTINGS_WINDOW:AddChild(tabGroup)
    addResetButton(private.BIG_ICON_SETTINGS_WINDOW, { "Elements.BigIcon", "Elements.Cooldown" }, function()
        tabGroup:SelectTab(selectedTab)
    end)


    return private.BIG_ICON_SETTINGS_WINDOW
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
    private.BIGICON_FRAME:SetWidth(private.GetElementStyle("BigIcon").Size)
    private.BIGICON_FRAME:SetHeight(private.GetElementStyle("BigIcon").Size)

    if not EditModeManagerFrame:IsShown() and private.wasEditModeOpen then
        private.wasEditModeOpen = false
        ShowUIPanel(EditModeManagerFrame)
    end
end

local createHighlightTextSettingsFrame = function()
    private.Debug("Creating Highlight Text Settings Frame")
    private.HIGHLIGHT_TEXT_SETTINGS_WINDOW = AceGUI:Create("AtSpellIconSettingsFrame")
    private.Debug(private.HIGHLIGHT_TEXT_SETTINGS_WINDOW, "AT_HIGHLIGHT_TEXT_SETTINGS_WINDOW")

    local widget = AceGUI:Create("AtTextHighlight")
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
    if private.db.profile.dispellTextColor then
        widget.frame.SpellName:SetTextColor(0, 0.5019607843137255, 1)
    else
        widget.frame.SpellName:SetTextColor(1, 1, 1)
    end
    widget.frame:SetScript("OnUpdate", function(self)
        if widget.startTime + widget.duration < GetTime() then
            widget.startTime = GetTime()
        end
        local remainingDuration = (widget.startTime + widget.duration) - GetTime()
        local textColor = widget:GetTextColor(remainingDuration)
        if private.db.profile.highlight_text_settings.dispellIcons then
            self.SpellName:SetFormattedText("|A:%s:20:20|a %s in |c%s%i|r", 'icons_16x16_magic', eventInfo.spellName,
                textColor, math.ceil(remainingDuration))
        else
            self.SpellName:SetFormattedText("%s in |c%s%i|r", eventInfo.spellName, textColor,
                math.ceil(remainingDuration))
        end
    end)
    widget.frame:Show()
    private.HIGHLIGHT_TEXT_SETTINGS_WINDOW.frame.CloseButton:SetScript("OnClick",
        function() private.closeHighlightTextSettings() end)
    widget:ClearAllPoints()
    widget.frame:SetFrameStrata("DIALOG")
    widget.frame:SetPoint("CENTER", private.HIGHLIGHT_TEXT_SETTINGS_WINDOW.rightContent, "CENTER", 0, 0)
    widget.frame:SetFrameLevel(private.HIGHLIGHT_TEXT_SETTINGS_WINDOW.rightContent:GetFrameLevel() + 1)
    widget:SetParent(private.HIGHLIGHT_TEXT_SETTINGS_WINDOW)

    local tabGroup = AceGUI:Create("AtTabGroup")
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
    local selectedTab = "GeneralSettings"
    tabGroup:SetCallback("OnGroupSelected", function(_, _, value)
        private.Debug("Selected tab: " .. value)
        selectedTab = value
        tabGroup:ReleaseChildren()
        if value == "TextSettings" then
            tabGroup:AddChild(createHighlightTextTextSettings(widget, private.HIGHLIGHT_TEXT_SETTINGS_WINDOW))
        elseif value == "CooldownSettings" then
            tabGroup:AddChild(createCooldownSettings(widget, private.HIGHLIGHT_TEXT_SETTINGS_WINDOW, true, true))
        else
            tabGroup:AddChild(createHighlightTextGeneralSettings(widget, private.HIGHLIGHT_TEXT_SETTINGS_WINDOW,
                private.db.profile.highlight_text_settings))
        end
    end)
    tabGroup:SetFullWidth(true)
    tabGroup:SelectTab("GeneralSettings")
    private.HIGHLIGHT_TEXT_SETTINGS_WINDOW:AddChild(tabGroup)
    addResetButton(private.HIGHLIGHT_TEXT_SETTINGS_WINDOW, { "Elements.TextHighlight", "Elements.Cooldown" }, function()
        tabGroup:SelectTab(selectedTab)
    end)


    return private.HIGHLIGHT_TEXT_SETTINGS_WINDOW
end

private.openHighlightTextSettings = function()
    if not private.HIGHLIGHT_TEXT_SETTINGS_WINDOW then
        createHighlightTextSettingsFrame()
    else
        private.HIGHLIGHT_TEXT_SETTINGS_WINDOW.frame:Show()
    end

    if EditModeManagerFrame:IsShown() then
        private.wasEditModeOpen = true
        HideUIPanel(EditModeManagerFrame)
    end
end

private.closeHighlightTextSettings = function()
    private.HIGHLIGHT_TEXT_SETTINGS_WINDOW.frame:Hide()

    if not EditModeManagerFrame:IsShown() and private.wasEditModeOpen then
        private.wasEditModeOpen = false
        ShowUIPanel(EditModeManagerFrame)
    end
end
