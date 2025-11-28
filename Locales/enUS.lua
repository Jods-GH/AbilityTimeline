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
    private.localisation = L
end