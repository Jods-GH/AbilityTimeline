local appName, app = ...
---@class AbilityTimeline
local private = app
local L = private.getLocalisation

---a checkbox row of a db.profile value, named by the localisation of its key
---@param key string
---@param onChange function|nil
---@return table
local toggle = function(key, onChange)
    return {
        kind = "Checkbox",
        name = L(key),
        desc = L(key .. "Description"),
        profileKey = key,
        onChange = onChange,
    }
end

local refreshBossMods = function()
    if private.initDbmSkin then
        private.initDbmSkin()
    end
end

local useTimelineModule = toggle("useTimelineModule", private.showReloadPopup)
useTimelineModule.hidden = function() return not private.isRetail end
useTimelineModule.image = "Interface\\AddOns\\AbilityTimeline\\Media\\Textures\\Settings\\useTimelineModule.tga"

local timelineHeading = { kind = "Heading", name = L("SettingsSectionTimeline") }
timelineHeading.hidden = useTimelineModule.hidden

private.RegisterSettingsPage({
    key = "General",
    order = 10,
    name = L("SettingsPageGeneral"),
    desc = L("SettingsPageGeneralDescription"),
    rows = {
        timelineHeading,
        useTimelineModule,
        { kind = "Heading", name = L("SettingsSectionCountdowns") },
        toggle("useAudioCountdowns"),
        {
            kind = "Slider",
            name = L("audioCountdownTime"),
            desc = L("audioCountdownTimeDescription"),
            profileKey = "audioCountdownTime",
            minValue = 1,
            maxValue = 5,
            valueStep = 1,
            hidden = function() return not private.db.profile.useAudioCountdowns end,
        },
        { kind = "Heading", name = L("SettingsSectionOtherTimers") },
        toggle("disableAllBlizzTimers", function()
            if private.refreshEncounterTimelineVisibility then
                private.refreshEncounterTimelineVisibility()
            end
        end),
        toggle("disableBossModsBars", refreshBossMods),
        toggle("disableBossModsEmphasisedBars", refreshBossMods),
        toggle("disableAllOnEncounterEnd"),
        { kind = "Heading", name = L("SettingsSectionGroup") },
        toggle("enableKeyRerollTimer"),
        toggle("enableDNDMessage"),
        toggle("disableReadyCheck"),
        { kind = "Heading", name = L("SettingsSectionAddon") },
        {
            kind = "Button",
            name = L("TourStartRow"),
            desc = L("TourStartRowDescription"),
            buttonText = L("TourStart"),
            -- after the button's own callback, the tour renders the window again
            func = function() C_Timer.After(0, private.StartTour) end,
        },
        toggle("disableLoginMessage"),
        toggle("debugMode"),
    },
})
