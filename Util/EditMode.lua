local appName, app = ...
---@class AbilityTimeline
local private = app
local LibEditMode = LibStub("LibEditMode")

LibEditMode:RegisterCallback('layout', function(layoutName)
    private.ACTIVE_EDITMODE_LAYOUT = layoutName
    private.modernize() --modernize any old settings to new ones
end)


LibEditMode:RegisterCallback('rename', function(oldLayoutName, newLayoutName)
    -- this will be called every time an Edit Mode layout is renamed
    if private.db.global.timeline_frame and private.db.global.timeline_frame[oldLayoutName] then
        local layout = CopyTable(private.db.global.timeline_frame[oldLayoutName])
        private.db.global.timeline_frame[newLayoutName] = layout
        private.db.global.timeline_frame[oldLayoutName] = nil
    end

    if private.db.global.text_highlight_frame and private.db.global.text_highlight_frame[oldLayoutName] then
        local layout = CopyTable(private.db.global.text_highlight_frame[oldLayoutName])
        private.db.global.text_highlight_frame[newLayoutName] = layout
        private.db.global.text_highlight_frame[oldLayoutName] = nil
    end

    if private.db.global.bigicon_frame and private.db.global.bigicon_frame[oldLayoutName] then
        local layout = CopyTable(private.db.global.bigicon_frame[oldLayoutName])
        private.db.global.bigicon_frame[newLayoutName] = layout
        private.db.global.bigicon_frame[oldLayoutName] = nil
    end
end)

LibEditMode:RegisterCallback('create', function(layoutName, layoutIndex, sourceLayoutName)
    if not private.db.global.timeline_frame then
        private.db.global.timeline_frame = {}
    end

    if not private.db.global.text_highlight_frame then
        private.db.global.text_highlight_frame = {}
    end
    if not private.db.global.bigicon_frame then
        private.db.global.bigicon_frame = {}
    end

    if sourceLayoutName then
        if private.db.global.timeline_frame[sourceLayoutName] then
            local layout = CopyTable(private.db.global.timeline_frame[sourceLayoutName])
            private.db.global.timeline_frame[layoutName] = layout
        end

        if private.db.global.text_highlight_frame[sourceLayoutName] then
            local layout = CopyTable(private.db.global.text_highlight_frame[sourceLayoutName])
            private.db.global.text_highlight_frame[layoutName] = layout
        end

        if private.db.global.bigicon_frame[sourceLayoutName] then
            local layout = CopyTable(private.db.global.bigicon_frame[sourceLayoutName])
            private.db.global.bigicon_frame[layoutName] = layout
        end
    end
end)

LibEditMode:RegisterCallback('delete', function(layoutName)
    if private.db.global.timeline_frame and private.db.global.timeline_frame[layoutName] then
        private.db.global.timeline_frame[layoutName] = nil
    end

    if private.db.global.text_highlight_frame and private.db.global.text_highlight_frame[layoutName] then
        private.db.global.text_highlight_frame[layoutName] = nil
    end

    if private.db.global.bigicon_frame and private.db.global.bigicon_frame[layoutName] then
        private.db.global.bigicon_frame[layoutName] = nil
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
    -- on retail the blizzard edit mode events show the timeline
    if not private.isRetail then
        private.handleFrame(true)
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
    if not private.manager.hasEvents() then
        private.handleFrame(false)
    end
end)
