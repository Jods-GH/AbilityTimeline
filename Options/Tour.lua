local appName, app = ...
---@class AbilityTimeline
local private = app
local LibEditMode = LibStub("LibEditMode")
local L = private.getLocalisation

-- the welcome tour: a callout walks through the settings window, Edit Mode, the Adventure Guide and the timings editor.
-- Steps are { key, context (settings, editmode, journal or editor), page, prepare, target, targetOptional, anchor, side,
-- box, waitFor, advanceOn, isDone, skip, skipsAhead, onShow, onLeave, onNext }, their texts the localisations Tour<key>Title
-- and Tour<key>Text. target returns a frame or a list of them. A step out of its context or with none of its targets
-- shown is passed over, unless targetOptional. A step with waitFor goes on once the player did what it asks and its Next
-- skips it, advanceOn (an event or a list of them) goes on as Next does. Next reads "Skip Step" where it skips what the
-- step asks for: a waitFor without an onNext doing it, or skipsAhead when the following steps need it done
local active = false
local paused = false
-- the tour opens pages itself, those aren't the player's doing
local showing = false
local index = 1
local shownStep
local hookedWindow = false
local hookedDialog = false
local hookedFrames = false
local exampleID = 0
local tourExamples = {}
local examplesUnlocked = false
local examplesConfirmed = false

private.MarkTourReminder = function(reminder)
    if not active or examplesConfirmed then return end
    exampleID = exampleID + 1
    reminder.atTourExample = exampleID
    tourExamples[exampleID] = true
end

private.IsTourExample = function(reminder)
    return active and tourExamples[reminder.atTourExample] == true
end

private.IsTourReminderProtected = function(reminder)
    return not examplesUnlocked and private.IsTourExample(reminder)
end

---@return Frame|nil
local getWindowFrame = function()
    local window = private.GetSettingsWindow()
    return window and window.frame
end

---@param key string
---@return function
local windowPart = function(key)
    return function()
        local frame = getWindowFrame()
        return frame and frame[key]
    end
end

---@param ... string -- page keys
---@return function
local navButtons = function(...)
    local keys = { ... }
    return function()
        local frame = getWindowFrame()
        local buttons = {}
        for _, button in ipairs(frame and frame.Nav.Buttons or {}) do
            if button:IsShown() and tContains(keys, button.key) then
                table.insert(buttons, button)
            end
        end
        return buttons
    end
end

local getContent = function()
    local window = private.GetSettingsWindow()
    return window and window.content
end

---@param key string
---@return function
local detailsPart = function(key)
    return function()
        local frame = getWindowFrame()
        return frame and frame.Details[key]
    end
end

---whether the Adventure Guide is there to open a boss's reminders from
---@return boolean
local hasJournal = function()
    return private.isRetail and EncounterJournal ~= nil and EncounterJournal_OpenJournal ~= nil
end

---@return boolean
local isEditorShown = function()
    local editor = private.TIMINGS_EDITOR_WINDOW
    return editor ~= nil and editor.frame:IsShown()
end

---@param key string
---@return function
local editorPart = function(key)
    return function()
        local editor = private.TIMINGS_EDITOR_WINDOW
        return editor and editor[key]
    end
end

---@param window string -- IMPORT_DIALOG_WINDOW or EXPORT_DIALOG_WINDOW
---@return function
local dialogFrame = function(window)
    return function()
        return private[window] and private[window].frame
    end
end

---the window of the Timer Rules page while it edits a rule, view is what it shows: the rule, its timer selection or
---one kind of timer of that
---@param view string -- rule, timers or kind
---@return function
local ruleWindow = function(view)
    return function()
        local editor, rule, chooser = private.GetTimerRuleEditor()
        local shown = rule and (not chooser and "rule" or chooser.editing and "kind" or "timers")
        return editor and shown == view and editor.frame
    end
end

---a section of the rule window while it shows view, the rule's own sections or those of its timer selection
---@param view string -- rule, timers or kind
---@param key string
---@return function
local rulePart = function(view, key)
    return function()
        if not ruleWindow(view)() then return end
        local _, _, chooser, parts = private.GetTimerRuleEditor()
        return (view == "rule" and parts or chooser.parts or {})[key]
    end
end

---opens a part of the kind of timer being edited, and one of its times
---@param section string -- source, state or timing
---@param time string|nil -- duration, elapsed or remaining
---@return function
local openKindSection = function(section, time)
    return function()
        local _, _, chooser = private.GetTimerRuleEditor()
        local editing = chooser and chooser.editing
        if not editing or editing.section == section and (not time or editing.timing == time) then return end
        editing.section = section
        if time then editing.timing = time end
        private.RefreshSettingsPage()
    end
end

---whether the kind of timer being edited limits the time already passed to a range
---@return boolean
local limitsElapsed = function()
    local _, _, chooser = private.GetTimerRuleEditor()
    local editing = chooser and chooser.editing
    local kind = editing and chooser[editing.list][editing.index]
    for _, test in ipairs(kind and kind.children or {}) do
        if test.field == "elapsed" and not test.any and test.op == "between" then return true end
    end
    return false
end

---@return Frame|nil
local getRuleWindow = function()
    local editor = private.GetTimerRuleEditor()
    return editor and editor.frame
end

---shows the first boss of the season's first instance in the Adventure Guide
local openSeasonEncounter = function()
    for _, instance in ipairs(private.CurrentInstances or {}) do
        local info = private.GetEncounterInfo(instance.encounters[1])
        if info and info.journalInstanceID then
            EncounterJournal_OpenJournal(nil, info.journalInstanceID, info.journalEncounterID)
            return
        end
    end
end

local steps = {
    { key = "Pages", context = "settings", target = windowPart("Nav") },
    { key = "Rows", context = "settings", page = "Timeline", target = getContent, anchor = getWindowFrame, side = "TOP" },
    {
        key = "Dot",
        context = "settings",
        page = "Timeline",
        target = function() return private.GetChangedSettingDot() end,
        -- the dot shown for the tour goes again
        onLeave = function() private.RefreshSettingRows() end,
    },
    {
        key = "Reset",
        context = "settings",
        page = "Timeline",
        target = function() return { detailsPart("Reset")(), detailsPart("ResetPage")() } end,
    },
    { key = "Preview", context = "settings", page = "Timeline", target = detailsPart("Preview") },
    {
        key = "Test",
        context = "settings",
        target = windowPart("TestButton"),
        waitFor = "test",
        isDone = function() return private.IsSettingsTestRunning() end,
    },
    -- only after the test timers were started
    {
        key = "TestOff",
        context = "settings",
        target = function() return private.IsSettingsTestRunning() and windowPart("TestButton")() end,
        advanceOn = "testStop",
        onNext = function() private.StopSettingsTest() end,
    },
    {
        key = "Themes",
        context = "settings",
        page = "Theme",
        target = getContent,
        anchor = getWindowFrame,
        side = "TOP",
        advanceOn = "themeTried",
    },
    -- leaving the theme page asks whether to keep a theme tried on it
    {
        key = "KeepTheme",
        context = "settings",
        page = "SpellIcons",
        target = private.GetThemeDialog,
        waitFor = "themeDialog",
        onShow = function()
            if hookedDialog then return end
            hookedDialog = true
            private.GetThemeDialog():HookScript("OnHide", function()
                private.OnTourEvent("themeDialog")
            end)
        end,
    },
    { key = "Elements", context = "settings", target = navButtons("SpellIcons", "BigIcon", "TextHighlight") },
    { key = "Rules", context = "settings", target = navButtons("CooldownChanges"), advanceOn = "pageCooldownChanges" },
    -- the steps of the Timer Rules page glow around all of a step's parts together
    {
        key = "RulesLanes",
        context = "settings",
        page = "CooldownChanges",
        target = function()
            local lanes = private.GetTimerRulesPage()
            if not lanes then return end
            local parts = {}
            for _, list in ipairs({ lanes.ticks, lanes.labels, lanes.buttons }) do
                for _, part in ipairs(list) do table.insert(parts, part) end
            end
            return parts
        end,
        box = true,
    },
    {
        key = "RulesDisplay",
        context = "settings",
        page = "CooldownChanges",
        target = function() return select(2, private.GetTimerRulesPage()) end,
        box = true,
    },
    {
        key = "RulesZoom",
        context = "settings",
        page = "CooldownChanges",
        target = function()
            local lanes = private.GetTimerRulesPage()
            local bar = lanes and lanes.zoomBar
            return bar and { bar.label, bar.track, bar.caption, bar.edit }
        end,
        box = true,
    },
    {
        key = "RulesUndo",
        context = "settings",
        page = "CooldownChanges",
        target = function() return { detailsPart("Undo")(), detailsPart("Redo")(), detailsPart("ResetPage")() } end,
        box = true,
    },
    {
        key = "RulesAdd",
        context = "settings",
        page = "CooldownChanges",
        target = getContent,
        anchor = getWindowFrame,
        side = "TOP",
        waitFor = "ruleOpen",
        isDone = ruleWindow("rule"),
    },
    -- only while a rule is open, the callouts beside its window
    { key = "RulesLook", context = "settings", target = rulePart("rule", "look"), anchor = getRuleWindow, box = true },
    { key = "RulesShowOn", context = "settings", target = rulePart("rule", "showOn"), anchor = getRuleWindow, box = true },
    { key = "RulesWhen", context = "settings", target = rulePart("rule", "when"), anchor = getRuleWindow, box = true },
    {
        key = "RulesAdvanced",
        context = "settings",
        target = rulePart("rule", "advanced"),
        anchor = getRuleWindow,
        box = true,
        waitFor = "ruleAdvanced",
        isDone = function()
            local _, rule = private.GetTimerRuleEditor()
            return rule ~= nil and rule.advanced == true
        end,
    },
    -- only once Advanced is on
    {
        key = "RulesChoose",
        context = "settings",
        target = rulePart("rule", "choose"),
        anchor = getRuleWindow,
        box = true,
        advanceOn = "ruleTimers",
        skipsAhead = true,
    },
    -- the selection going away, cancelled or applied, goes on with the steps of the rule
    { key = "RulesUseFor", context = "settings", target = rulePart("timers", "include"), anchor = getRuleWindow, box = true,
        advanceOn = { "ruleKind", "ruleShown" } },
    { key = "RulesButNotFor", context = "settings", target = rulePart("timers", "except"), anchor = getRuleWindow,
        box = true, advanceOn = { "ruleKind", "ruleShown" } },
    {
        key = "RulesAddKind",
        context = "settings",
        target = rulePart("timers", "add"),
        anchor = getRuleWindow,
        box = true,
        waitFor = "ruleKind",
        advanceOn = "ruleShown",
    },
    -- each opens its part of the kind of timer, closing the kind goes on with the selection
    { key = "RulesFrom", context = "settings", prepare = openKindSection("source"), target = rulePart("kind", "source"),
        anchor = getRuleWindow, box = true, advanceOn = "ruleKindClosed" },
    { key = "RulesWhile", context = "settings", prepare = openKindSection("state"), target = rulePart("kind", "state"),
        anchor = getRuleWindow, box = true, advanceOn = "ruleKindClosed" },
    { key = "RulesTiming", context = "settings", prepare = openKindSection("timing"), target = rulePart("kind", "timing"),
        anchor = getRuleWindow, box = true, advanceOn = "ruleKindClosed" },
    -- until the time already passed is drawn, the steps point at all times
    {
        key = "RulesRange",
        context = "settings",
        prepare = openKindSection("timing", "elapsed"),
        target = function() return rulePart("kind", "range")() or rulePart("kind", "timing")() end,
        anchor = getRuleWindow,
        box = true,
        advanceOn = "ruleKindClosed",
    },
    {
        key = "RulesBetween",
        context = "settings",
        prepare = openKindSection("timing", "elapsed"),
        target = function() return rulePart("kind", "between")() or rulePart("kind", "timing")() end,
        anchor = getRuleWindow,
        box = true,
        waitFor = "ruleBetween",
        isDone = limitsElapsed,
        advanceOn = "ruleKindClosed",
    },
    { key = "RulesKindClose", context = "settings", target = rulePart("kind", "close"), anchor = getRuleWindow,
        box = true, waitFor = "ruleKindClosed" },
    {
        key = "RulesApply",
        context = "settings",
        target = rulePart("timers", "apply"),
        anchor = getRuleWindow,
        box = true,
        waitFor = "ruleShown",
        isDone = function() return select(3, private.GetTimerRuleEditor()) == nil end,
    },
    { key = "RulesEnabled", context = "settings", target = rulePart("rule", "enabled"), anchor = getRuleWindow, box = true },
    { key = "RulesCopy", context = "settings", target = rulePart("rule", "copy"), anchor = getRuleWindow, box = true },
    -- removing the rule closes its window
    { key = "RulesRemove", context = "settings", target = rulePart("rule", "remove"), anchor = getRuleWindow, box = true,
        advanceOn = "ruleClosed" },
    {
        key = "RulesClose",
        context = "settings",
        target = getRuleWindow,
        waitFor = "ruleClosed",
        onNext = function() getRuleWindow():Hide() end,
    },
    { key = "Move", context = "settings", target = windowPart("MoveButton"), waitFor = "editModeEnter" },
    -- our frames only show in Edit Mode while its Boss Warnings are checked, the check box is in its collapsed options
    {
        key = "BossWarnings",
        context = "editmode",
        target = function()
            local settings = EditModeManagerFrame.AccountSettings
            local check = settings and settings.settingsCheckButtons and settings.settingsCheckButtons.EncounterEvents
            if not check then return end
            return check:IsVisible() and check or settings
        end,
        waitFor = "bossWarnings",
        isDone = function() return private.ShowsEncounterEvents() end,
        -- only retail has Boss Warnings; classic has the check box of the shared Edit Mode code, but nothing behind it
        skip = function() return not private.isRetail end,
    },
    {
        key = "TimelineFrame",
        context = "editmode",
        target = function() return private.TIMELINE_FRAME and private.TIMELINE_FRAME.frame end,
        advanceOn = "timelineMoved",
    },
    {
        key = "Anchors",
        context = "editmode",
        target = function()
            return {
                private.BIGICON_FRAME and private.BIGICON_FRAME.frame,
                private.TEXT_HIGHLIGHT_FRAME and private.TEXT_HIGHLIGHT_FRAME.frame,
            }
        end,
        advanceOn = "anchorMoved",
    },
    {
        key = "ExitEditMode",
        context = "editmode",
        target = function() return EditModeManagerFrame end,
        waitFor = "editModeExit",
        -- closing Edit Mode goes on
        onNext = function() HideUIPanel(EditModeManagerFrame) end,
    },
    {
        key = "Reminders",
        context = "settings",
        target = navButtons("Reminders"),
        advanceOn = "pageReminders",
        skip = function() return not hasJournal() end,
    },
    -- the Adventure Guide has a button of ours on every boss, Next opens it on a boss of the season
    {
        key = "Journal",
        context = "settings",
        target = function() return EJMicroButton end,
        targetOptional = true,
        advanceOn = "journalOpen",
        onNext = openSeasonEncounter,
        skip = function() return not hasJournal() end,
    },
    {
        key = "JournalButton",
        context = "journal",
        -- the settings window would cover the Adventure Guide
        prepare = function()
            private.closeSettings()
            if not (AbilityTimelineEJAddButton and AbilityTimelineEJAddButton:IsVisible()) then
                openSeasonEncounter()
            end
        end,
        target = function() return AbilityTimelineEJAddButton end,
        advanceOn = { "editorOpen", "journalClosed" },
        skipsAhead = true,
        onNext = function() HideUIPanel(EncounterJournal) end,
    },
    -- without the Adventure Guide the reminders are opened from their page
    {
        key = "EditTimings",
        context = "settings",
        page = "Reminders",
        target = function()
            return private.GetShownSettingsPage() == "Reminders" and private.GetFirstSettingButton()
        end,
        advanceOn = "editorOpen",
        skipsAhead = true,
        skip = hasJournal,
    },
    -- only when the editor was opened: from what it shows to sharing reminders
    { key = "Editor", context = "editor", target = editorPart("frame") },
    {
        key = "EditorStages",
        context = "editor",
        target = function() return { editorPart("tabStrip")(), editorPart("addStageButton")() } end,
        anchor = editorPart("tabStrip"),
        side = "BOTTOM",
    },
    { key = "EditorAdd", context = "editor", target = editorPart("addButton"), waitFor = "reminderAdded",
        isDone = function()
            for _, reminder in ipairs(private.TIMINGS_EDITOR_WINDOW.reminders) do
                if private.IsTourExample(reminder) then return true end
            end
            return false
        end,
        onNext = function() end },
    { key = "EditorPanel", context = "editor", target = editorPart("inspectorPanel") },
    { key = "EditorTimeline", context = "editor", target = editorPart("board"), advanceOn = "reminderMoved" },
    {
        key = "EditorUndo",
        context = "editor",
        target = function() return { editorPart("undoButton")(), editorPart("redoButton")() } end,
        anchor = editorPart("undoButton"),
        side = "BOTTOM",
    },
    { key = "EditorBossTimers", context = "editor", target = editorPart("rulesButton"), advanceOn = "bossTimersOpen",
        skipsAhead = true },
    -- only when the boss timers were opened
    {
        key = "EditorBackToStages",
        context = "editor",
        target = editorPart("tabStrip"),
        anchor = editorPart("tabStrip"),
        side = "BOTTOM",
        advanceOn = "stageOpen",
        skip = function() return private.TIMINGS_EDITOR_WINDOW.mode ~= "rules" end,
    },
    { key = "EditorExport", context = "editor", target = editorPart("exportButton"), advanceOn = "exportOpen",
        waitFor = "exportOpen", onNext = function() end },
    -- only once the dialog is open, closing it goes on
    {
        key = "EditorExportDialog",
        context = "editor",
        target = dialogFrame("EXPORT_DIALOG_WINDOW"),
        advanceOn = "exportClosed",
        onNext = function() private.EXPORT_DIALOG_WINDOW.closeButton:Click() end,
    },
    { key = "EditorImport", context = "editor", target = editorPart("importButton"),
        waitFor = "importOpen", onNext = function() end },
    {
        key = "EditorImportDialog",
        context = "editor",
        target = dialogFrame("IMPORT_DIALOG_WINDOW"),
        advanceOn = "importClosed",
        onNext = function() private.IMPORT_DIALOG_WINDOW.closeButton:Click() end,
    },
    {
        key = "EditorCleanup",
        context = "editor",
        target = editorPart("frame"),
        onShow = function() examplesUnlocked = true end,
    },
    {
        key = "EditorClose",
        context = "editor",
        target = editorPart("frame"),
        waitFor = "editorClosed",
        onNext = function() private.closeTimingsEditor() end,
    },
    {
        key = "Search",
        context = "settings",
        target = function()
            local window = private.GetSettingsWindow()
            return window and window.search.frame
        end,
        advanceOn = "search",
    },
    { key = "Profiles", context = "settings", target = navButtons("Profiles"), advanceOn = "pageProfiles" },
    { key = "Done", context = "settings", anchor = getWindowFrame, side = "TOP" },
}

---@return boolean
private.IsTourDue = function()
    return not private.db.global.hasDoneTour
end

local leaveStep = function()
    if shownStep and shownStep.onLeave then
        shownStep.onLeave()
    end
    shownStep = nil
end

local finish = function()
    active = false
    leaveStep()
    private.db.global.hasDoneTour = true
    private.GetTourCallout():Hide()
end

local contexts = {
    settings = function() return not LibEditMode:IsInEditMode() end,
    editmode = function() return LibEditMode:IsInEditMode() end,
    journal = function() return EncounterJournal ~= nil and EncounterJournal:IsShown() end,
    editor = isEditorShown,
}

---whether the player is somewhere the settings window makes way for
---@return boolean
local isElsewhere = function()
    return contexts.editmode() or contexts.journal() or contexts.editor()
end

---@param step table
---@return boolean
local isWaiting = function(step)
    return step.waitFor ~= nil and not (step.isDone and step.isDone())
end

---@param step table
---@param event string
---@return boolean
local advancesOn = function(step, event)
    if step.waitFor == event then
        return true
    end
    if type(step.advanceOn) == "table" then
        return tContains(step.advanceOn, event)
    end
    return step.advanceOn == event
end

---the shown targets of step
---@param step table
---@return Frame[]
local getTargets = function(step)
    local result = step.target and step.target()
    if result and result.IsVisible then
        result = { result }
    end
    local targets = {}
    -- a list can have holes where a frame doesn't exist
    for i = 1, table.maxn(result or {}) do
        if result[i] and result[i]:IsVisible() then
            table.insert(targets, result[i])
        end
    end
    return targets
end

local showStep

local back = function()
    showStep(index - 1, -1)
end

local nextStep = function()
    local step = steps[index]
    local before = index
    if step.key == "EditorAdd" and isWaiting(step) then
        examplesConfirmed = true
        showing = true
        private.closeTimingsEditor()
        showing = false
        for nextIndex = index + 1, #steps do
            if steps[nextIndex].key == "Search" then
                showStep(nextIndex, 1)
                return
            end
        end
    end
    if step.key == "EditorCleanup" then
        examplesConfirmed = true
    end
    if step.onNext then
        step.onNext()
    end
    -- what onNext did may have gone on already
    if active and index == before and not (isWaiting(step) and step.onNext) then
        showStep(index + 1, 1)
    end
end

---@param step table
---@param targets Frame[]
local highlight = function(step, targets)
    local callout = private.GetTourCallout()
    -- Edit Mode's own windows and the settings of a selected frame stay above the dark
    callout:Highlight(targets, step.context == "editmode" and "HIGH" or nil, step.box)
    if targets[1] then
        callout:Place(step.anchor and step.anchor() or step.box and callout.box or targets[1], step.anchor and step.side)
    else
        callout:Place(step.anchor and step.anchor() or getWindowFrame(), step.side or "TOP")
    end
end

---@param step table
---@param targets Frame[]
local present = function(step, targets)
    if shownStep ~= step then
        leaveStep()
    end
    shownStep = step
    if step.onShow then
        step.onShow()
    end
    local callout = private.GetTourCallout()
    local last = index == #steps
    -- Next skips what the step asks for: the steps after it that need it done, or a wait Next doesn't do itself
    local skips = step.skipsAhead or (isWaiting(step) and not step.onNext)
    callout:SetContent({
        title = L("Tour" .. step.key .. "Title"),
        text = L("Tour" .. step.key .. "Text"),
        counter = ("%d / %d"):format(index, #steps),
        back = step.key == "EditorCleanup" and L("TourDeleteExamples") or L("TourBack"),
        -- going back into or out of Edit Mode is left to the player
        backDisabled = index == 1 or steps[index - 1].context ~= step.context,
        next = step.key == "EditorAdd" and isWaiting(step) and L("TourSkipReminders") or
            step.key == "EditorCleanup" and L("TourKeepExamples") or
            last and L("TourFinish") or skips and L("TourSkipStep") or L("TourNext"),
        nextDisabled = (step.key == "EditorExport" or step.key == "EditorImport" or step.key == "RulesBetween") and
            isWaiting(step),
        nextStyle = skips and "Plain" or "Primary",
        onBack = step.key == "EditorCleanup" and function()
            private.TIMINGS_EDITOR_WINDOW:DeleteTourExamples()
            examplesConfirmed = true
            showStep(index + 1, 1)
        end or back,
        onNext = last and finish or nextStep,
        onClose = finish,
    })
    highlight(step, targets)
end

local refreshQueued = false

---the page drew the parts of the shown step again, they glow instead of the released ones once they are laid out
private.RefreshTourStep = function()
    if refreshQueued then return end
    refreshQueued = true
    C_Timer.After(0, function()
        refreshQueued = false
        if not active or paused or shownStep ~= steps[index] then return end
        local targets = getTargets(shownStep)
        if #targets > 0 then
            highlight(shownStep, targets)
        end
    end)
end

local hookWindow = function()
    local frame = getWindowFrame()
    if hookedWindow or not frame then return end
    hookedWindow = true
    -- closing the window ends the tour, making way for Edit Mode, the Adventure Guide or the editor doesn't
    frame:HookScript("OnHide", function()
        C_Timer.After(0, function()
            if active and not isElsewhere() and not frame:IsShown() then
                finish()
            end
        end)
    end)
end

---shows the step of newIndex, or the next one in direction that can be shown, the end of the tour finishes it
---@param newIndex number
---@param direction number -- 1 or -1
showStep = function(newIndex, direction)
    if newIndex < 1 then
        newIndex, direction = 1, 1
    end
    local step = steps[newIndex]
    if not step then
        finish()
        return
    end
    if contexts[step.context]() and not (step.skip and step.skip()) then
        showing = true
        if step.context == "settings" then
            local frame = getWindowFrame()
            if not (frame and frame:IsShown()) or (step.page and private.GetShownSettingsPage() ~= step.page) then
                private.openSettings(step.page)
                hookWindow()
            end
        end
        if step.prepare then
            step.prepare()
        end
        showing = false
        local targets = getTargets(step)
        if not step.target or step.targetOptional or #targets > 0 then
            index = newIndex
            present(step, targets)
            return
        end
    end
    showStep(newIndex + direction, direction)
end

---@param event string -- test, testStop, search, page<key>, themeTried, themeDialog, bossWarnings, editModeEnter,
---editModeExit, timelineMoved, anchorMoved, journalOpen, journalClosed, editorOpen, editorClosed, reminderAdded,
---reminderMoved, bossTimersOpen, stageOpen, exportOpen, exportClosed, importOpen, importClosed, ruleOpen, ruleShown,
---ruleAdvanced, ruleTimers, ruleKind, ruleBetween, ruleKindClosed or ruleClosed
private.OnTourEvent = function(event)
    if not active or paused or showing then return end
    if event == "editorClosed" and not examplesConfirmed then
        finish()
        return
    end
    if advancesOn(steps[index], event) then
        showStep(index + 1, 1)
    end
end

---entering or leaving Edit Mode goes on with the step after the one waiting for it, or the next step of the new
---context, after the frames and windows made way for each other
---@param event string
local onEditMode = function(event)
    if not active or paused then return end
    private.GetTourCallout():Hide()
    C_Timer.After(0, function()
        if not active or paused then return end
        showStep(steps[index].waitFor == event and index + 1 or index, 1)
    end)
end

LibEditMode:RegisterCallback('enter', function()
    onEditMode("editModeEnter")
end)

LibEditMode:RegisterCallback('exit', function()
    onEditMode("editModeExit")
end)

if EditModeManagerFrame.AccountSettings and EditModeManagerFrame.AccountSettings.RefreshEncounterEvents then
    hooksecurefunc(EditModeManagerFrame.AccountSettings, "RefreshEncounterEvents", function()
        -- after Edit Mode showed our frames for them
        C_Timer.After(0, function()
            if private.ShowsEncounterEvents() then
                private.OnTourEvent("bossWarnings")
            end
        end)
    end)
end

---the frames the tour waits on, they exist once the addon and the Adventure Guide are loaded
local hookFrames = function()
    if hookedFrames then return end
    hookedFrames = true
    local onDragStop = function(widget, event)
        local selection = widget and LibEditMode.frameSelections[widget.frame]
        if selection then
            selection:HookScript("OnDragStop", function()
                private.OnTourEvent(event)
            end)
        end
    end
    onDragStop(private.TIMELINE_FRAME, "timelineMoved")
    onDragStop(private.BIGICON_FRAME, "anchorMoved")
    onDragStop(private.TEXT_HIGHLIGHT_FRAME, "anchorMoved")
    if EncounterJournal then
        EncounterJournal:HookScript("OnShow", function()
            private.OnTourEvent("journalOpen")
        end)
        EncounterJournal:HookScript("OnHide", function()
            private.OnTourEvent("journalClosed")
        end)
    end
end

-- combat hides the tour, it comes back after
local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function(_, event)
    if not active then return end
    paused = event == "PLAYER_REGEN_DISABLED"
    if paused then
        private.GetTourCallout():Hide()
    else
        showStep(index, 1)
    end
end)

private.StartTour = function()
    if InCombatLockdown() then
        private.Print(L("TourCombat"))
        return
    end
    if LibEditMode:IsInEditMode() then
        HideUIPanel(EditModeManagerFrame)
    end
    hookFrames()
    tourExamples = {}
    examplesUnlocked, examplesConfirmed = false, false
    active, paused = true, false
    showStep(1, 1)
end

---offers the tour until it was done or put off
private.ShowTourWelcome = function()
    local callout = private.GetTourCallout()
    local later = function()
        finish()
        private.Print(L("TourLater"))
    end
    callout:SetContent({
        title = L("TourWelcomeTitle"),
        text = L("TourWelcomeText"),
        back = L("TourNotNow"),
        next = L("TourStart"),
        onBack = later,
        onNext = private.StartTour,
        onClose = later,
    })
    callout:Highlight(nil)
    callout:Place(nil)
end
