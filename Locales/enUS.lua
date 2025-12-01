local appName, private = ...
local AceLocale = LibStub ('AceLocale-3.0')
local L = AceLocale:NewLocale(appName, "enUS", true)

if L then
    L["AccessOptionsMessage"] = "Access the options via /at"
    L["TimelineNotEnabledMessage"] = "The timeline feature is not enabled."
    L["TimelineNotSupportedMessage"] = "The timeline feature is not supported on this version."

    --options
    L['addonOptions'] = "Ability Timeline Options"
    L['encounterOptions'] = "Encounter Options"
    L['EditTimingsForEncounter'] = "Edit Timings for Encounter"
    L['TimingsEditorTitle'] = "Timings Editor for: "
    L['debugMode'] = "Debug Mode"
    L['debugModeDescription'] = "Enables debug mode, which outputs additional information to the chat window."
    L['useAudioCountdowns'] = "Use Audio Countdowns"
    L['useAudioCountdownsDescription'] = "Enables audio countdowns of the last 5 seconds for upcoming events."

    --edit mode
    L["EnableBigIcon"] = "Enable Big Icon"
    L["EnableBigIconDescription"] = "Toggles the visibility of the big icon frame."
    L["EnableTicks"] = "Enable Ticks"
    L["EnableTicksDescription"] = "Toggles the visibility of the timeline ticks."
    L["EnableTextHighlight"] = "Enable Text Highlight"
    L["EnableTextHighlightDescription"] = "Toggles the visibility of the text highlight frame."
    L["TimelineWidth"] = "Timeline Width"
    L["TimelineWidthDescription"] = "Sets the width of the timeline."
    L["TimelineHeight"] = "Timeline Height"
    L["TimelineHeightDescription"] = "Sets the height of the timeline."
    L["InverseTravelDirection"] = "Inverse Travel Direction"
    L["InverseTravelDirectionDescription"] = "Inverts the travel direction of the timeline."


    private.localisation = L
end