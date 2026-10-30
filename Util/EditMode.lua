local appName, app = ...
---@class AbilityTimeline
local private = app
local LibEditMode = LibStub("LibEditMode")

LibEditMode:RegisterCallback('layout', function(layoutName)
    private.ACTIVE_EDITMODE_LAYOUT = layoutName
    private.modernize() --modernize any old settings to new ones
end)


-- every saved variable in db.global that is stored per edit mode layout
local PER_LAYOUT_KEYS = {
    "timeline_frame",
    "bigicon_frame",
    "text_highlight_frame",
    "bigicon",
    "bigicon_enabled",
    "text_highlight",
    "text_highlight_enabled",
    "waiting_group",
    "queued_group",
    "paused_group",
}

local copyValue = function(value)
    if type(value) == "table" then
        return CopyTable(value)
    end
    return value
end

LibEditMode:RegisterCallback('rename', function(oldLayoutName, newLayoutName)
    -- this will be called every time an Edit Mode layout is renamed
    for _, key in ipairs(PER_LAYOUT_KEYS) do
        local layouts = private.db.global[key]
        if layouts and layouts[oldLayoutName] ~= nil then
            layouts[newLayoutName] = copyValue(layouts[oldLayoutName])
            layouts[oldLayoutName] = nil
        end
    end
end)

LibEditMode:RegisterCallback('create', function(layoutName, layoutIndex, sourceLayoutName)
    for _, key in ipairs(PER_LAYOUT_KEYS) do
        if not private.db.global[key] then
            private.db.global[key] = {}
        end
        local layouts = private.db.global[key]
        if sourceLayoutName and layouts[sourceLayoutName] ~= nil then
            layouts[layoutName] = copyValue(layouts[sourceLayoutName])
        end
    end
end)

LibEditMode:RegisterCallback('delete', function(layoutName)
    for _, key in ipairs(PER_LAYOUT_KEYS) do
        if private.db.global[key] then
            private.db.global[key][layoutName] = nil
        end
    end
end)

local TEST_EVENT_DURATIONS = { 8, 15, 25 }
local testEventTicker

---adds our own test events where blizzard has no edit mode events
private.addTestEvents = function()
    for index, duration in ipairs(TEST_EVENT_DURATIONS) do
        private.manager.addEvent({
            source = private.manager.SOURCES.Addon,
            sourceID = "test" .. index,
            duration = duration,
            spellName = "Test Spell",
            spellID = 376864,
            iconFileID = 135127,
        })
    end
end

local removeTestEvents = function()
    for index in ipairs(TEST_EVENT_DURATIONS) do
        local eventID = private.manager.getEventIDFromSource(private.manager.SOURCES.Addon, "test" .. index)
        if eventID then
            private.manager.removeEvent(eventID)
        end
    end
end

LibEditMode:RegisterCallback('enter', function()
    if private.db.profile.useTimelineModule then
        private.handleFrame(true)
    end
    -- on retail the blizzard edit mode events are used instead
    if not private.isRetail then
        private.addTestEvents()
        testEventTicker = C_Timer.NewTicker(TEST_EVENT_DURATIONS[#TEST_EVENT_DURATIONS], private.addTestEvents)
    end
end)

LibEditMode:RegisterCallback('exit', function()
    if private.isRetail then
        C_EncounterTimeline.CancelEditModeEvents()
    elseif testEventTicker then
        testEventTicker:Cancel()
        testEventTicker = nil
        removeTestEvents()
    end
    if not private.manager.hasVisibleEvents() then
        private.handleFrame(false)
    end
end)
