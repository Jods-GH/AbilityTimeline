local appName, private = ...
local AceLocale = LibStub ('AceLocale-3.0')
local L = AceLocale:NewLocale(appName, "enUS", true)

if L then
    L["AccessOptionsMessage"] = "Access the options via /at"
    L["TimelineNotEnabledMessage"] = "The timeline feature is not enabled."
    L["TimelineNotSupportedMessage"] = "The timeline feature is not supported on this version."
    L["ReadyCheckBy"] = "Ready Check by"
    L["PullTimerBy"] = "Pull Timer by"

    --options
    L['addonOptions'] = "Ability Timeline Options"
    L['encounterOptions'] = "Encounter Options"
    L['EditTimingsForEncounter'] = "Edit Timings for Encounter"
    L['TimingsEditorTitle'] = "Timings Editor for: "
    L['debugMode'] = "Debug Mode"
    L['debugModeDescription'] = "Enables debug mode, which outputs additional information to the chat window."
    L['useAudioCountdowns'] = "Use Audio Countdowns"
    L['useAudioCountdownsDescription'] = "Enables audio countdowns of the last 5 seconds for upcoming events."
    L['enableKeyRerollTimer'] = "Enable Key Reroll Timer"
    L['enableKeyRerollTimerDescription'] = "Enables a timer for you to reroll your Mythic+ key after completing a dungeon."
    L['TestIcon'] = "Test Icon"


    --spell icon editor
    L["GeneralSettings"] = "General Settings"
    L["IconSize"] = "Icon Size"
    L["IconSizeDescription"] = "Sets the size of the spell icon."
    L["IconZoom"] = "Icon Zoom"
    L["IconZoomDescription"] = "Sets the zoom level of the spell icon."

    L['TextSettings'] = "Text Settings"
    L["IconSizeDescription"] = "Sets the size of the spell icon."
    L["TextOffsetX"] = "Text Offset X"
    L["TextOffsetXDescription"] = "Sets the X offset of the text relative to the icon."
    L["TextOffsetY"] = "Text Offset Y"
    L["TextOffsetYDescription"] = "Sets the Y offset of the text relative to the icon."
    L["SpellIconSettings"] = "Spell Icon Settings"
    L["IconPreview"] = "Icon Preview"
    L["SpellnameFontSize"] = "Font Size"
    L["SpellnameFontSizeDescription"] = "Sets the font size of the text besides the icon."
    L["SpellnameFont"] = "Font"
    L["SpellnameFontDescription"] = "Sets the font of the text besides the icon."
    L["SpellnameDefaultColor"] = "Default Text Color"
    L["SpellnameDefaultColorDescription"] = "Sets the default color of the text besides the icon when not impacted by specific information like the type of debuff e.G. Poison."

    L["CooldownSettings"] = "Cooldown Settings"
    L["CooldownFont"] = "Cooldown Font"
    L["CooldownFontDescription"] = "Sets the font of the cooldown text on the icon."
    L["CooldownFontSize"] = "Cooldown Font Size"
    L["CooldownFontSizeDescription"] = "Sets the font size of the cooldown text on the icon."
    L["EnableCooldownHighlight"] = "Cooldown Changes"
    L["EnableCooldownHighlightDescription"] = "Enables changes of the cooldown display based on remaining time."
    L["CooldownColorChangeColor"] = "Color"
    L["CooldownColorChangeColorDescription"] = "Sets the color of the cooldown text when this timing is reached."
    L["CooldownColorChangesDescription"] = "Sets the color changes of the cooldown text based on remaining time."
    L["CooldownColorChangeTiming"] = "Timing"
    L["CooldownColorChangeTimingDescription"] = "Sets the timing (in seconds) when this color change should occur."
    L["CooldownColorChanges"] = "Cooldown Color Changes"
    L["DefaultCooldownColor"] = "Cooldown Color"
    L["RemoveCooldownColorChangeTooltip"] = "Removes this cooldown color change."
    L["AddCooldownColorChangeTooltip"] = "Adds a new cooldown color change."
    L['CooldownGlowColorDescription'] = "Sets the glow color for this cooldown timing."
    L['CooldownGlowColor'] = "Glow Color"
    L['EnableCooldownGlowChange'] = "Enable Glow"
    L['EnableCooldownGlowChangeDescription'] = "Enables glow effect for this cooldown timing."
    L['CooldownGlowType'] = "Glow Type"
    L['CooldownGlowTypeDescription'] = "Sets the glow type for this cooldown timing."



    --edit mode
    L["EnableBigIcon"] = "Enable Big Icon"
    L["EnableBigIconDescription"] = "Toggles the visibility of the big icon frame."
    L["EnableTicks"] = "Enable Ticks"
    L["EnableTicksDescription"] = "Toggles the visibility of the timeline ticks."
    L["EnableTextHighlight"] = "Enable Text Highlight"
    L["EnableTextHighlightDescription"] = "Toggles the visibility of the text highlight frame."
    L["TravelDirectionHorizontal"] = "Horizontal"
    L["TravelDirectionVertical"] = "Vertical"
    L["TravelDirection"] = "Travel Direction"
    L["TravelDirectionDescription"] = "Travel Direction of the timeline."
    L["TimelineOtherSize"] = "Timeline Other Size"
    L["TimelineOtherSizeDescription"] = "Sets the other Size of the timeline. (Width on Horizontal, Height on Vertical)"
    L["TimelineTravelSize"] = "Timeline Travel Size"
    L["TimelineTravelSizeDescription"] = "Sets the travel Size of the timeline. (Height on Horizontal, Width on Vertical)"
    L["InverseTravelDirection"] = "Inverse Travel Direction"
    L["InverseTravelDirectionDescription"] = "Inverts the travel direction of the timeline."
    L["TextAnchor"] = "Text Anchor"
    L["TextAnchorDescription"] = "Sets the anchor position of the text relative to the icons."
    L["TextAnchorLeft"] = "Left"
    L["TextAnchorRight"] = "Right"
    L["TimelineTexture"] = "Timeline Texture"
    L["TimelineTextureDescription"] = "Sets the texture of the timeline background."
    L["OpenIconEditor"] = "Edit Icons"

    -- errors
    L["InvalidTextPosition"] = "Invalid text anchor position please alert the author."
    L["WrongWoWVersionMessage"] = "AbilityTimeline requires WoW version 12.0.0 (Midnight) or higher to run."


    private.localisation = L
end