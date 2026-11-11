local appName, app = ...
---@class AbilityTimeline
local private = app

-- easy lookup table
local dispellTypeColors = {}
for _, dispellTypeInfo in pairs(private.dispellTypeList) do
   dispellTypeColors[dispellTypeInfo.mask] = CreateColor(
      dispellTypeInfo.color.r,
      dispellTypeInfo.color.g,
      dispellTypeInfo.color.b,
      dispellTypeInfo.color.a
   )
end

private.spellIDColors = {}

local EventColors = {}
local SetupEventColorisation = function()
    if EventColors and next(EventColors) then return end -- already setup
    for eventID in pairs(C_EncounterEvents.GetEventList()) do
        local eventInfo = C_EncounterEvents.GetEventInfo(eventID)
        local icons = eventInfo and eventInfo.icons
        if icons then
            for mask, color in pairs(dispellTypeColors) do
                if bit.band(icons, mask) ~= 0 then
                    local originalColor = C_EncounterEvents.GetEventColor(eventID, Enum.EncounterEventColorTrigger.TimelineEvent)
                    EventColors[eventID] = originalColor or false
                    private.spellIDColors[eventInfo.spellID] = color
                    C_EncounterEvents.SetEventColor(eventID, Enum.EncounterEventColorTrigger.TimelineEvent,  color)
                    break -- Only set the first matching color
                end
            end
        end
    end
end

local RemoveEventColorisation = function()
    for eventID, color in pairs(EventColors) do
        C_EncounterEvents.SetEventColor(eventID, Enum.EncounterEventColorTrigger.TimelineEvent, color or nil)
    end
    wipe(EventColors)
    wipe(private.spellIDColors)
end

private.ToggleEventColorisation = function(enable)
    if not private.isRetail then return end
    if enable then
        SetupEventColorisation()
    else
        RemoveEventColorisation()
    end
end

---the timeline's events are colored by dispel type while any element colors its spell names by it
private.RefreshEventColorisation = function()
    for _, key in ipairs({ "text_settings", "big_icon_text_settings", "highlight_text_settings" }) do
        for _, source in ipairs(private.db.profile[key].colorOrder) do
            if source == "dispel" then
                private.ToggleEventColorisation(true)
                return
            elseif source == "default" then
                break
            end
        end
    end
    private.ToggleEventColorisation(false)
end

