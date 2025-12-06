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
    L["IconSize"] = "Icon Size"
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

    -- errors
    L["InvalidTextPosition"] = "Invalid text anchor position please alert the author."
    L["WrongWoWVersionMessage"] = "AbilityTimeline requires WoW version 12.0.0 (Midnight) or higher to run."


    private.localisation = L
end