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

local useTimelineModule = toggle("useTimelineModule", private.showReloadPopup)
useTimelineModule.hidden = function() return not private.isRetail end
useTimelineModule.image = "Interface\\AddOns\\AbilityTimeline\\Media\\Textures\\Settings\\useTimelineModule.tga"

local disableBreakTimer = toggle("disableBreakTimer")
disableBreakTimer.hidden = private.manager.hasBossMod

local timelineHeading ={ kind = "Heading", name = L("SettingsSectionTimeline") }
timelineHeading.hidden = useTimelineModule.hidden

local mergeSettings = {
    timeline = "timeline_settings",
    waiting = "waiting_group",
    queued = "queued_group",
    paused = "paused_group",
    bigIcon = "big_icon_settings",
    textHighlight = "highlight_text_settings",
}

local refreshMergedDisplays = function()
    private.evaluateBigIconPositions()
    private.evaluateTextPositions()
end

private.RegisterSettingsPage({
    key = "General",
    order = 10,
    name = L("SettingsPageGeneral"),
    desc = L("SettingsPageGeneralDescription"),
    rows = {
        timelineHeading,
        useTimelineModule,
        { kind = "Heading", name = L("SettingsSectionMerging") },
        {
            kind = "Dropdown",
            name = L("MergeTimers"),
            desc = L("MergeTimersDescription"),
            multiselect = true,
            values = {
                timeline = L("SettingsPageTimeline"),
                waiting = L("MergeWaitingTimers"),
                queued = L("MergeQueuedTimers"),
                paused = L("MergePausedTimers"),
                bigIcon = L("SettingsPageBigIcon"),
                textHighlight = L("SettingsPageTextHighlight"),
            },
            sorting = { "timeline", "waiting", "queued", "paused", "bigIcon", "textHighlight" },
            get = function()
                local selected = {}
                for key, settings in pairs(mergeSettings) do
                    selected[key] = private.db.profile[settings].merge_timers
                end
                return selected
            end,
            set = function(value, key)
                private.db.profile[mergeSettings[key]].merge_timers = value
            end,
            onChange = refreshMergedDisplays,
        },
        {
            kind = "Slider",
            name = L("MergeWindow"),
            desc = L("MergeWindowDescription"),
            profileKey = "timeline_settings.merge_window",
            minValue = 0,
            maxValue = 2,
            valueStep = 0.1,
            hidden = function()
                for _, settings in pairs(mergeSettings) do
                    if private.db.profile[settings].merge_timers then return false end
                end
                return true
            end,
            onChange = refreshMergedDisplays,
        },
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
        toggle("disableBossModsBars", private.manager.refreshBossModBars),
        toggle("disableBossModsEmphasisedBars", private.manager.refreshBossModBars),
        toggle("disableAllOnEncounterEnd"),
        toggle("showRemindersInDisabledDisplays"),
        { kind = "Heading", name = L("SettingsSectionGroup") },
        toggle("enableKeyRerollTimer"),
        toggle("enableDNDMessage"),
        toggle("disableReadyCheck"),
        disableBreakTimer,
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
