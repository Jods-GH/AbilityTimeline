-- Manager.lua: the registry of timer events, their time, state and colors, and the per-frame display rules.
-- Manager.lua is loaded with Data/constants.lua and doubles of the two addon modules it reads at runtime:
-- ThemeApply (Util/ThemeApply.lua: AtlasInfo, DispelColor, File) and CooldownText (Util/CooldownText.lua: HasShown,
-- Shown, Required); CooldownText's own behaviour is covered by its spec.
local Addon = require("spec.helpers.addon_loader")
local World = require("spec.helpers.world")

local EVENTS = { "EVENT_ADDED", "EVENT_REMOVED", "EVENT_STATE_CHANGED", "EVENT_DISPLAY_START", "EVENT_DISPLAY_STOP",
    "EVENT_TICK", "EVENT_DISPLAYS_UPDATED" }

local world, private, manager, fired, shownByDisplay

local function load()
    world = World.Build()
    shownByDisplay = {}
    private = {
        db = {
            profile = {
                useTimelineModule = true, useAudioCountdowns = true, audioCountdownTime = 3,
                showRemindersInDisabledDisplays = false,
                big_icon_settings = { threshold_time = 5, merge_timers = false },
                highlight_text_settings = { threshold_time = 5, merge_timers = false },
                timeline_settings = { merge_window = 1 },
            },
            global = {
                timeline_frame = { Modern = { enabled = true } },
                bigicon_enabled = { Modern = true },
                text_highlight_enabled = { Modern = true },
            },
        },
        ACTIVE_EDITMODE_LAYOUT = "Modern",
        ThemeApply = {
            AtlasInfo = function(atlas) return C_Texture.GetAtlasInfo(atlas) end,
            DispelColor = function(dispel) return dispel.color.r, dispel.color.g, dispel.color.b, 1 end,
            File = function(name) return "file:" .. name end,
        },
        CooldownText = {
            HasShown = function() return next(shownByDisplay) ~= nil end,
            Shown = function(display) return shownByDisplay[display] end,
            Required = function() return {} end,
        },
    }
    Addon.Load({ "Data/constants.lua", "Manager.lua" }, private)
    manager = private.manager
    fired = {}
    for _, event in ipairs(EVENTS) do
        manager.RegisterCallback(fired, event, function(name, ...)
            fired[#fired + 1] = { name, ... }
        end)
    end
end

local function firedNames(filter)
    local names = {}
    for _, call in ipairs(fired) do
        if not filter or call[1] == filter then names[#names + 1] = call[1] .. ":" .. tostring(call[2]) .. (call[3] ~= nil and (":" .. tostring(call[3])) or "") end
    end
    return names
end

local function add(info)
    info.source = info.source or manager.SOURCES.Addon
    info.duration = info.duration or 10
    return manager.addEvent(info)
end

describe("manager events", function()
    before_each(load)

    it("fills an event's defaults and gives each a new id", function()
        local first = add({})
        local second = add({ spellName = "Second", spellID = 5, iconFileID = 7, severity = 2 })
        assert.is_true(second > first)
        local info = manager.getEventInfo(first)
        assert.same({ "", 0, 134400, 0, 1 }, { info.spellName, info.spellID, info.iconFileID, info.maxQueueDuration, info.severity })
        assert.equals("Second", manager.getEventInfo(second).spellName)
        assert.same({ "EVENT_ADDED:" .. first, "EVENT_ADDED:" .. second }, firedNames())
        assert.is_true(manager.hasEvents())
        assert.equals(2, #manager.getEventList())
    end)

    it("counts down on the clock, scaled by timeScale and clamped", function()
        local id = add({ duration = 10 })
        local fast = add({ duration = 10, timeScale = 2 })
        world.clock.Advance(4, 1)
        assert.equals(6, manager.getEventRemainingTime(id))
        assert.equals(4, manager.getEventTimeElapsed(id))
        assert.equals(2, manager.getEventRemainingTime(fast))
        world.clock.Advance(1, 1)
        assert.equals(0, manager.getEventRemainingTime(fast))
        assert.equals(10, manager.getEventTimeElapsed(fast))
        assert.is_nil(manager.getEventRemainingTime(9999))
        assert.is_nil(manager.getEventTimeElapsed(9999))
    end)

    it("freezes a paused event and continues where it stopped", function()
        local id = add({ duration = 10, timeScale = 2 })
        world.clock.Advance(1, 1)
        manager.pauseEvent(id)
        manager.pauseEvent(id)
        assert.equals(manager.STATES.Paused, manager.getEventState(id))
        assert.is_true(manager.hasPausedEvents())
        world.clock.Advance(3, 1)
        assert.equals(8, manager.getEventRemainingTime(id))
        manager.resumeEvent(id)
        assert.equals(8, manager.getEventRemainingTime(id))
        world.clock.Advance(1, 1)
        assert.equals(6, manager.getEventRemainingTime(id))
        assert.is_false(manager.hasPausedEvents())
    end)

    it("starts paused at zero when added paused", function()
        local id = add({ duration = 10, paused = true })
        world.clock.Advance(2, 1)
        assert.equals(10, manager.getEventRemainingTime(id))
        assert.equals(manager.STATES.Paused, manager.getEventState(id))
    end)

    it("is queued at zero and finished once its queue time passed", function()
        local id = add({ duration = 2, maxQueueDuration = 3 })
        assert.equals(manager.STATES.Active, manager.getEventState(id))
        world.clock.now = world.clock.now + 2
        assert.equals(manager.STATES.Queued, manager.getEventState(id))
        world.game.cvars.encounterTimelineHideQueuedCountdowns = "1"
        assert.equals(manager.STATES.Active, manager.getEventState(id))
        world.clock.now = world.clock.now + 3
        assert.equals(manager.STATES.Finished, manager.getEventState(id))
        assert.is_nil(manager.getEventState(9999))
    end)

    it("passes a provider's time, state, track and block through, queued at zero", function()
        local remaining = 5
        local provider = {
            getRemaining = function() return remaining end, getElapsed = function() return 3 end,
            getState = function() return manager.STATES.Active end, getTrack = function(id) return "track" .. id end,
            isBlocked = function() return true end,
        }
        local id = add({ sourceID = 42, provider = provider })
        assert.same({ 5, 3, "track42", true }, { manager.getEventRemainingTime(id), manager.getEventTimeElapsed(id),
            manager.getEventTrack(id), manager.IsEventBlocked(id) })
        remaining = 0
        assert.equals(manager.STATES.Queued, manager.getEventState(id))
        manager.pauseEvent(id)
        assert.equals(manager.STATES.Queued, manager.getEventState(id))
        local plain = add({})
        assert.is_false(manager.IsEventBlocked(plain))
        assert.is_nil(manager.getEventTrack(plain))
    end)

    it("replaces the event of the same source and source id", function()
        local first = add({ sourceID = "pull" })
        local second = add({ sourceID = "pull" })
        assert.is_nil(manager.getEventInfo(first))
        assert.equals(second, manager.getEventIDFromSource(manager.SOURCES.Addon, "pull"))
        assert.same({ "EVENT_ADDED:" .. first, "EVENT_REMOVED:" .. first, "EVENT_ADDED:" .. second }, firedNames())
        assert.is_nil(manager.getEventIDFromSource(manager.SOURCES.DBM, "pull"))
        assert.is_nil(manager.getEventIDFromSource(manager.SOURCES.Addon, nil))
    end)

    it("never indexes or looks up a secret source id", function()
        local secret = world.secrets.Secret("bar")
        local first = add({ sourceID = secret })
        local second = add({ sourceID = secret })
        assert.is_table(manager.getEventInfo(first))
        assert.is_table(manager.getEventInfo(second))
        assert.is_nil(manager.getEventIDFromSource(manager.SOURCES.Addon, secret))
    end)

    it("stops displays, then removes an event and frees its source id", function()
        local id = add({ sourceID = "x", duration = 3 })
        world.clock.Advance(1 / 60)
        fired = setmetatable({}, { __index = fired })
        manager.removeEvent(id)
        local names = firedNames()
        assert.same("EVENT_REMOVED:" .. id, names[#names])
        assert.is_true(#names > 1)
        for i = 1, #names - 1 do assert.truthy(names[i]:find("^EVENT_DISPLAY_STOP:" .. id)) end
        assert.is_nil(manager.getEventIDFromSource(manager.SOURCES.Addon, "x"))
        assert.is_false(manager.hasEvents())
        manager.removeEvent(id)
    end)

    it("removes all events of one source or every event, announcing the displays once", function()
        local addonEvent = add({})
        add({ source = manager.SOURCES.Reminder })
        add({ source = manager.SOURCES.Reminder })
        fired = {}
        manager.removeAllEvents(manager.SOURCES.Reminder)
        assert.same({ addonEvent }, manager.getEventList())
        assert.equals(1, #firedNames("EVENT_DISPLAYS_UPDATED"))
        manager.isUpdatingDisplays = true
        fired = {}
        manager.removeAllEvents()
        assert.is_false(manager.hasEvents())
        assert.equals(0, #firedNames("EVENT_DISPLAYS_UPDATED"))
        assert.is_true(manager.isUpdatingDisplays)
    end)

    it("stops the displays of a hidden event and shows it again on the next frame", function()
        local id = add({ duration = 3 })
        world.clock.Advance(1 / 60)
        assert.is_true(manager.hasVisibleEvents())
        manager.setEventHidden(id, true)
        assert.is_false(manager.hasVisibleEvents())
        world.clock.Advance(1 / 60)
        assert.is_false(manager.hasVisibleEvents())
        manager.setEventHidden(id, false)
        world.clock.Advance(1 / 60)
        assert.is_true(manager.hasVisibleEvents())
    end)

    it("applies only the overrides given", function()
        local color = CreateColor(1, 0, 0)
        local id = add({ spellName = "Old", countdown = 3, customColor = color, borderColor = color })
        manager.setEventOverrides(id, { spellName = "New", countdown = false, glow = "pixel" })
        local info = manager.getEventInfo(id)
        assert.same({ "New", false, "pixel" }, { info.spellName, info.countdown, info.glow })
        manager.setEventOverrides(id, {})
        assert.equals(color, manager.getEventColor(id, {}))
        assert.equals(color, manager.getEventBorderColor(id))
        manager.setEventOverrides(9999, { spellName = "x" })
    end)
end)

describe("manager colors and boss mods", function()
    before_each(load)

    it("colors by the first source of the order that gives a color, a custom color first", function()
        local red = CreateColor(1, 0, 0)
        manager.registerColorSource("bossmodText", { getColor = function(event) return event.textColor end })
        local plain = add({ textColor = red })
        assert.equals(red, manager.getEventColor(plain, { "dispel", "bossmodText" }))
        assert.is_nil(manager.getEventColor(plain, { "default", "bossmodText" }))
        assert.is_nil(manager.getEventColor(plain, { "unregistered" }))
        local custom = CreateColor(0, 0, 1)
        assert.equals(custom, manager.getEventColor(add({ customColor = custom, textColor = red }), { "bossmodText" }))
        assert.is_nil(manager.getEventColor(9999, { "dispel" }))
    end)

    it("colors by the first dispel type of the event's icons", function()
        -- Data/constants.lua: Magic is mask 8, Curse 32
        local color = manager.getEventColor(add({ icons = 8 + 32 }), { "dispel" })
        assert.same({ 0, 0.5019607843137255, 1 }, { color:GetRGB() })
    end)

    it("leaves secret icons to the provider's color", function()
        local providerColor = CreateColor(0, 1, 0)
        local id = add({ sourceID = 7, icons = world.secrets.Secret(8), provider = { getColor = function() return providerColor end } })
        assert.equals(providerColor, manager.getEventColor(id, { "dispel" }))
    end)

    it("answers for a source's key with a fallback while that source is missing", function()
        local fallback = { fallbackFor = { bossmodBar = true }, getColor = function() end }
        manager.registerColorSource("dbm", fallback)
        assert.equals(fallback, manager.getColorSource("bossmodBar"))
        local own = { getColor = function() end }
        manager.registerColorSource("bossmodBar", own)
        assert.equals(own, manager.getColorSource("bossmodBar"))
        assert.is_nil(manager.getColorSource("missing"))
    end)

    it("knows the boss mods, refreshes their bars and asks whether one hides Blizzard's timers", function()
        assert.is_false(manager.hasBossMod())
        assert.is_false(manager.bossModHidesBlizzTimers())
        local refreshed = 0
        manager.registerBossMod("DBM", { refreshBars = function() refreshed = refreshed + 1 end, hidesBlizzTimers = function() return false end })
        manager.registerBossMod("BigWigs", { hidesBlizzTimers = function() return true end })
        manager.refreshBossModBars()
        assert.is_true(manager.hasBossMod())
        assert.equals(1, refreshed)
        assert.is_true(manager.bossModHidesBlizzTimers())
    end)

    it("names the countdown source of the addon's own timers", function()
        local id = add({ sourceID = "pull", duration = 10 })
        local context = manager.GetCountdownContext(id, 4, manager.getEventInfo(id), nil, {}, { elapsed = true })
        assert.same({ "PullTimer", 4, 10, manager.STATES.Active, 0 },
            { context.source, context.remaining, context.duration, context.state, context.elapsed })
        local reminder = add({ source = manager.SOURCES.Reminder })
        assert.equals("Reminder", manager.GetCountdownContext(reminder, 1, manager.getEventInfo(reminder), nil, {}, {}).source)
        assert.equals("DBM", manager.GetCountdownContext(nil, 1, { source = "DBM" }, 0, {}, {}).source)
    end)
end)

describe("manager clusters", function()
    before_each(load)

    local function widget(id, remaining, state)
        return { frame = { positionRemaining = remaining, currentState = state or 0, eventInfo = { id = id } } }
    end

    local function members(clusters, count)
        local result = {}
        for i = 1, count do
            result[i] = {}
            for _, w in ipairs(clusters[i].members) do table.insert(result[i], w.frame.eventInfo.id) end
        end
        return result
    end

    it("groups timers within the window of each cluster's first timer, sorted by time then id", function()
        local clusters = {}
        local widgets = { widget(3, 1.5), widget(1, 1), widget(2, 1), widget(4, 2.1) }
        local count = manager.clusterTimers(widgets, clusters, { merge_timers = true, merge_window = 1 })
        assert.same({ { 1, 2, 3 }, { 4 } }, members(clusters, count))
    end)

    it("keeps at most four timers in a cluster and never mixes states", function()
        local clusters = {}
        local widgets = { widget(1, 1), widget(2, 1), widget(3, 1), widget(4, 1), widget(5, 1), widget(6, 1, 1) }
        local count = manager.clusterTimers(widgets, clusters, { merge_timers = true, merge_window = 1 })
        assert.same({ { 1, 2, 3, 4 }, { 5 }, { 6 } }, members(clusters, count))
    end)

    it("gives every timer its own cluster while merging is off", function()
        local clusters = {}
        assert.equals(2, manager.clusterTimers({ widget(1, 1), widget(2, 1) }, clusters, { merge_timers = false, merge_window = 5 }))
    end)
end)

describe("manager displays", function()
    before_each(load)

    local function displays(id)
        local shown = {}
        for _, call in ipairs(fired) do
            if call[2] == id and call[1] == "EVENT_DISPLAY_START" then shown[call[3]] = true end
            if call[2] == id and call[1] == "EVENT_DISPLAY_STOP" then shown[call[3]] = nil end
        end
        return shown
    end

    it("shows an event on the timeline, then the big icon, text and audio once it is close", function()
        local id = add({ duration = 8 })
        world.clock.Advance(1 / 60)
        assert.same({ timeline = true }, displays(id))
        world.clock.Advance(3.5, 0.5)
        assert.same({ timeline = true, bigIcon = true, textHighlight = true }, displays(id))
        world.clock.Advance(2, 0.5)
        assert.same({ timeline = true, bigIcon = true, textHighlight = true, audio = true }, displays(id))
    end)

    it("announces the state on the first frame and each change", function()
        local id = add({ duration = 8 })
        world.clock.Advance(1 / 60)
        manager.pauseEvent(id)
        world.clock.Advance(1 / 60)
        assert.same({ "EVENT_STATE_CHANGED:" .. id .. ":0", "EVENT_STATE_CHANGED:" .. id .. ":1" }, firedNames("EVENT_STATE_CHANGED"))
    end)

    it("ticks once when the remaining time passes five seconds", function()
        local id = add({ duration = 7 })
        world.clock.Advance(3, 0.5)
        assert.same({ "EVENT_TICK:" .. id .. ":5" }, firedNames("EVENT_TICK"))
    end)

    it("removes a finished event on the next frame", function()
        local id = add({ duration = 1 })
        world.clock.Advance(1.1, 0.1)
        assert.is_nil(manager.getEventInfo(id))
        assert.is_false(manager.hasEvents())
    end)

    it("leaves out the displays an event does not allow and the ones turned off", function()
        private.db.profile.useAudioCountdowns = false
        private.db.global.bigicon_enabled.Modern = false
        local id = add({ duration = 4, allowedDisplays = { audio = false } })
        world.clock.Advance(1, 0.5)
        assert.same({ timeline = true, textHighlight = true }, displays(id))
    end)

    it("plays an event's own audio countdown, none for zero", function()
        private.db.profile.useAudioCountdowns = false
        local own = add({ duration = 4, countdown = 5 })
        local none = add({ duration = 4, countdown = 0 })
        world.clock.Advance(0.5, 0.5)
        assert.is_true(displays(own).audio)
        assert.is_nil(displays(none).audio)
    end)

    it("shows reminders on a display turned off when the profile asks to", function()
        private.db.global.timeline_frame.Modern.enabled = false
        private.db.profile.showRemindersInDisabledDisplays = true
        local reminder = add({ source = manager.SOURCES.Reminder, duration = 8 })
        local other = add({ duration = 8 })
        world.clock.Advance(1 / 60)
        assert.is_true(displays(reminder).timeline)
        assert.is_nil(displays(other).timeline)
    end)

    it("lets a shown section turn the countdown displays on and off", function()
        shownByDisplay.BigIcon = true
        shownByDisplay.SpellIcon = false
        local id = add({ duration = 30 })
        world.clock.Advance(1 / 60)
        assert.same({ bigIcon = true }, displays(id))
    end)

    it("keeps merged followers' big icon off once their first timer ended, until their time is extended", function()
        private.db.profile.big_icon_settings.merge_timers = true
        local first = add({ duration = 3 })
        world.clock.Advance(0.5, 0.5)
        local second = add({ duration = 3 })
        world.clock.Advance(0.5, 0.5)
        assert.is_true(displays(second).bigIcon)
        world.clock.Advance(2.1, 0.1)
        assert.is_nil(manager.getEventInfo(first))
        assert.is_nil(displays(second).bigIcon)
        world.clock.Advance(0.2, 0.1)
        assert.is_nil(displays(second).bigIcon)
    end)
end)

describe("manager icons", function()
    before_each(load)

    local function texture()
        return CreateFrame("Frame"):CreateTexture()
    end

    it("uses the client's atlas when it has one, else Blizzard's sheet", function()
        world.game.atlases.icons_16x16_magic = { width = 16, height = 16 }
        assert.same({ Atlas = "icons_16x16_magic" }, manager.getEventIconArt(8))
        local fallback = manager.getEventIconArt(4)
        if world.game.atlases.icons_16x16_blood then
            assert.same({ Atlas = "icons_16x16_blood" }, fallback)
        else
            assert.equals("blizzard_ej_icons", fallback.File)
            assert.same({ 1 / 512, 33 / 512, 199 / 256, 231 / 256 }, fallback.Coords)
        end
        assert.is_nil(manager.getEventIconArt(3))
    end)

    it("fills one texture per icon of the mask and clears the rest", function()
        local textures = { texture(), texture(), texture() }
        local id = add({ icons = 2 + 8 + 128 })
        manager.SetEventIconTextures(id, 2 + 8, textures)
        assert.same({ 1, 1, 0 }, { textures[1]:GetAlpha(), textures[2]:GetAlpha(), textures[3]:GetAlpha() })
    end)

    it("hands a provider's icons to it and follows another event's icons", function()
        local handed
        local source = add({ sourceID = 9, provider = { setIconTextures = function(sourceID, mask) handed = { sourceID, mask } end } })
        local follower = add({ iconEventID = source })
        manager.SetEventIconTextures(follower, 6, {})
        assert.same({ 9, 6 }, handed)
        manager.SetEventIconTextures(9999, 6, {})
    end)
end)

describe("manager debug output", function()
    before_each(load)

    it("writes one line per event and a footer to the debug log", function()
        local lines = {}
        private.openDebugLog = function() end
        private.DebugLog = function(line) lines[#lines + 1] = line end
        add({ spellName = "Logged", duration = 5 })
        manager.printDebugInfo()
        assert.equals(2, #lines)
        assert.truthy(lines[1]:find("name=Logged", 1, true))
        assert.truthy(lines[2]:find("manager events at", 1, true))
    end)
end)
