local appName, private = ...
local AceGUI = LibStub("AceGUI-3.0")
local SharedMedia = LibStub("LibSharedMedia-3.0")


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
    widget.frame:SetScript("OnUpdate", nil) -- remove move code
    widget.frame.Cooldown:SetScript("OnCooldownDone", function()
        widget.frame.Cooldown:SetCooldown(GetTime(), eventInfo.duration)
    end) -- loop cooldown display
    widget.frame:Show()
    widget.frame:SetFrameStrata("DIALOG")
    widget.frame:SetPoint("CENTER", private.SPELL_ICON_SETTINGS_WINDOW.rightContent, "CENTER", 0, 0)
    widget.frame:SetFrameLevel(private.SPELL_ICON_SETTINGS_WINDOW.rightContent:GetFrameLevel() + 1)
    widget:SetParent(private.SPELL_ICON_SETTINGS_WINDOW)

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
    private.SPELL_ICON_SETTINGS_WINDOW:AddChild(sizeSetting)

    local textOffsetSettingX = AceGUI:Create("Slider")
    textOffsetSettingX:SetLabel(private.getLocalisation("TextOffsetX"))
    private.AddFrameTooltip(textOffsetSettingX.frame, "TextOffsetXDescription")
    textOffsetSettingX:SetSliderValues(-50, 50, 1)
    textOffsetSettingX:SetValue(private.db.profile.icon_settings.TextOffset.x)

    textOffsetSettingX:SetCallback("OnValueChanged", function(_, _, value)
        private.db.profile.icon_settings.TextOffset.x = value
        widget:ApplySettings()
    end)
    private.SPELL_ICON_SETTINGS_WINDOW:AddChild(textOffsetSettingX)


    local textOffsetSettingY = AceGUI:Create("Slider")
    textOffsetSettingY:SetLabel(private.getLocalisation("TextOffsetY"))
    private.AddFrameTooltip(textOffsetSettingY.frame, "TextOffsetYDescription")
    textOffsetSettingY:SetSliderValues(-50, 50, 1)
    textOffsetSettingY:SetValue(private.db.profile.icon_settings.TextOffset.y)

    textOffsetSettingY:SetCallback("OnValueChanged", function(_, _, value)
        private.db.profile.icon_settings.TextOffset.y = value
        widget:ApplySettings()
    end)
    private.SPELL_ICON_SETTINGS_WINDOW:AddChild(textOffsetSettingY)

    local fontSizeSetting = AceGUI:Create("Slider")
    fontSizeSetting:SetLabel(private.getLocalisation("SpellnameFontSize"))
    private.AddFrameTooltip(fontSizeSetting.frame, "SpellnameFontSizeDescription")
    fontSizeSetting:SetSliderValues(1, 64, 1)
    fontSizeSetting:SetValue(private.db.profile.text_settings.fontSize)

    fontSizeSetting:SetCallback("OnValueChanged", function(_, _, value)
        private.db.profile.text_settings.fontSize = value
        widget:ApplySettings()
    end)
    private.SPELL_ICON_SETTINGS_WINDOW:AddChild(fontSizeSetting)

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
    private.SPELL_ICON_SETTINGS_WINDOW:AddChild(fontSetting)

    return private.SPELL_ICON_SETTINGS_WINDOW
end

private.openSpellIconSettings = function()
    if not private.SPELL_ICON_SETTINGS_WINDOW then
        createSpellIconSettingsFrame()
    else
        private.SPELL_ICON_SETTINGS_WINDOW.frame:Show()
    end
end


private.closeSpellIconSettings = function()
    -- Close the spell icon settings
    private.Debug("Closing spell icon settings")
    private.SPELL_ICON_SETTINGS_WINDOW.frame:Hide()
end