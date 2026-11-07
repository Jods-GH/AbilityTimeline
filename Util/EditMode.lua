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

local TEST_EVENTS = {
    { spellID = 1265377, iconFileID = 1043573, classicIconFileID = 135846, duration = 6, maxQueueDuration = 0, icons = 0 },
    { spellID = 1265388, iconFileID = 136050, duration = 12, maxQueueDuration = 5, icons = 264 },
    { spellID = 1265390, iconFileID = 135846, duration = 14, maxQueueDuration = 5, icons = 0 },
    { spellID = 1265392, iconFileID = 136051, duration = 18, maxQueueDuration = 0, icons = 1 },
    { spellID = 1265394, iconFileID = 136186, duration = 22, maxQueueDuration = 0, icons = 4 },
    { spellID = 1265396, iconFileID = 319458, duration = 26, maxQueueDuration = 0, icons = 448 },
}
local TEST_LOOP_DURATION = 24
local testEventIDs = {}
local testEventTimer

---adds our own test events where blizzard has no edit mode events
private.addTestEvents = function()
    for eventID in pairs(testEventIDs) do
        if not private.manager.getEventInfo(eventID) then
            testEventIDs[eventID] = nil
        end
    end
    for index, event in ipairs(TEST_EVENTS) do
        local eventID = private.manager.addEvent({
            source = private.manager.SOURCES.Addon,
            duration = event.duration,
            maxQueueDuration = event.maxQueueDuration,
            spellName = string.format(private.getLocalisation("EditModePreviewSpell"), index),
            spellID = event.spellID,
            iconFileID = not private.isRetail and event.classicIconFileID or event.iconFileID,
            icons = event.icons,
            severity = 1,
            isApproximate = false,
            paused = false,
        })
        testEventIDs[eventID] = true
    end
end

local removeTestEvents = function()
    for eventID in pairs(testEventIDs) do
        private.manager.removeEvent(eventID)
    end
    wipe(testEventIDs)
end

---loops the events Edit Mode shows, as Edit Mode does: they have dispel, role and danger markers. Clients without
---them get our own test events. Classic clients have the api too but their events never reach our timeline
local queueTestEvents
queueTestEvents = function()
    local loopDuration
    if private.isRetail then
        loopDuration = C_EncounterTimeline.AddEditModeEvents()
    else
        private.addTestEvents()
        loopDuration = TEST_LOOP_DURATION
    end
    testEventTimer = C_Timer.NewTimer(loopDuration, queueTestEvents)
end

local startTestTicker = function()
    if not testEventTimer then
        queueTestEvents()
    end
end

---shows the timeline with repeating test events, e.g. to preview a theme
private.startTestEvents = function()
    if private.db.profile.useTimelineModule then
        private.handleFrame(true)
    end
    startTestTicker()
end

private.stopTestEvents = function()
    if private.isRetail then
        C_EncounterTimeline.CancelEditModeEvents()
    end
    if testEventTimer then
        testEventTimer:Cancel()
        testEventTimer = nil
    end
    removeTestEvents()
    if not private.manager.hasVisibleEvents() then
        private.handleFrame(false)
    end
end

---Blizzard's "Boss Warnings" checkbox in Edit Mode, clients without it always show our frames; classic has the check
---box of the shared Edit Mode code without the feature
local showsEncounterEvents = function()
    if not private.isRetail then
        return true
    end
    local checkButtons = EditModeManagerFrame.AccountSettings and EditModeManagerFrame.AccountSettings.settingsCheckButtons
    if not checkButtons or not checkButtons.EncounterEvents then
        return true
    end
    return checkButtons.EncounterEvents:IsControlChecked()
end
private.ShowsEncounterEvents = showsEncounterEvents

local setAnchorFramesShown = function(shown)
    for _, widget in ipairs({ private.BIGICON_FRAME, private.TEXT_HIGHLIGHT_FRAME, private.WAITING_FRAME,
        private.QUEUED_FRAME, private.PAUSED_FRAME }) do
        widget.frame:SetShown(shown)
    end
end

local refreshEditModeFrames = function()
    if not private.TIMELINE_FRAME then return end
    if not showsEncounterEvents() then
        EventRegistry:TriggerEvent('EditModeExternal.hideDialog')
        setAnchorFramesShown(false)
        private.handleFrame(false)
        return
    end
    setAnchorFramesShown(true)
    if private.db.profile.useTimelineModule then
        private.handleFrame(true)
    end
    -- on retail the blizzard edit mode events are used instead
    if not private.isRetail then
        startTestTicker()
    end
end

if EditModeManagerFrame.AccountSettings and EditModeManagerFrame.AccountSettings.RefreshEncounterEvents then
    hooksecurefunc(EditModeManagerFrame.AccountSettings, "RefreshEncounterEvents", function()
        -- also runs while Edit Mode opens, before the 'enter' callback
        if LibEditMode:IsInEditMode() then
            refreshEditModeFrames()
        end
    end)
end

LibEditMode:RegisterCallback('enter', refreshEditModeFrames)

LibEditMode:RegisterCallback('exit', function()
    if private.TIMELINE_FRAME then
        setAnchorFramesShown(true)
    end
    private.stopTestEvents()
end)
