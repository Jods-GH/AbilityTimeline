local appName, app = ...
---@class AbilityTimeline
local private = app
local L = private.getLocalisation

-- the reminders page: the encounters with saved reminders or boss timer changes, the encounters of the current content
-- (Data/Encounters) and any other encounter through the encounter picker, each opening the timings editor

---opens the timings editor in place of the settings window, which comes back on this page when the editor closes
---@param params table
local openEditor = function(params)
    private.closeSettings()
    private.openTimingsEditor(params)
    local frame = private.TIMINGS_EDITOR_WINDOW.frame
    -- the editor's frame is reused, it is hooked once
    if not frame.atHooked then
        frame.atHooked = true
        frame:HookScript("OnHide", function()
            if frame.atReturnToSettings then
                frame.atReturnToSettings = false
                private.openSettings("Reminders")
            end
        end)
    end
    frame.atReturnToSettings = true
end

local variables = {
    -- the width of the settings window's preview area
    model = { width = 256, height = 260 },
}

local model

---the boss's model as the Adventure Guide shows it (its first creature), nil where there is no Adventure Guide or the
---encounter has no journal entry
---@param journalEncounterID number|nil
---@return Frame|nil
local getModel = function(journalEncounterID)
    if not (journalEncounterID and EJ_GetCreatureInfo) then return end
    local _, _, _, displayInfo, _, uiModelSceneID = EJ_GetCreatureInfo(1, journalEncounterID)
    if not (displayInfo and uiModelSceneID) then return end
    if not model then
        model = CreateFrame("ModelScene", nil, UIParent, "ModelSceneMixinTemplate")
        model:SetSize(variables.model.width, variables.model.height)
        model:Hide()
        -- no field and border behind the model, a model scene's lighting looks out of place on one
        model.atNoField = true
    end
    model:SetFromModelSceneID(uiModelSceneID)
    local creature = model:GetActorByTag("creature")
    if creature then
        creature:SetModelByCreatureDisplayID(displayInfo)
    end
    return model
end

---opens the editor of an encounter of the data or of an id it doesn't have
---@param dungeonEncounterID number
local openEncounter = function(dungeonEncounterID)
    local info = private.GetEncounterInfo(dungeonEncounterID) or {}
    private.RegisterEncounter(dungeonEncounterID)
    openEditor({
        journalEncounterID = info.journalEncounterID,
        journalInstanceID = info.journalInstanceID,
        dungeonEncounterID = dungeonEncounterID,
        name = info.name,
        instanceName = info.instanceName,
    })
end

---@param key number|string -- the key the encounter is saved under
---@param name string
local askToDelete = function(key, name)
    private.AskQuestion({
        title = L("SettingsDeleteEncounterTitle"),
        text = L("SettingsDeleteEncounterText"):format(name),
        accept = L("SettingsDeleteEncounter"),
        acceptStyle = "Danger",
        back = L("ReminderCancelButton"),
        onAccept = function()
            private.DeleteEncounterChanges(key)
            private.RefreshSettingsPage()
        end,
    })
end

---the encounters with saved reminders or boss timer changes, named after their instance and encounter where the
---reminders saved those, else from the encounter data
---@return table[]
local getSavedRows = function()
    local keys = {}
    for key, stored in pairs(private.db.profile.reminders) do
        if #stored > 0 then
            keys[key] = true
        end
    end
    for key in pairs(private.db.profile.timerRules or {}) do
        keys[key] = true
    end
    local rows = {}
    for key in pairs(keys) do
        local id = tonumber(key) or 0
        local stored = private.db.profile.reminders[key]
        local first = stored and stored[1] or {}
        local info = private.GetEncounterInfo(id) or {}
        local encounterName = first.encounterName or info.name
        local instanceName = first.instanceName or info.instanceName
        local journalEncounterID = first.journalEncounterID or info.journalEncounterID
        -- the row shows the boss, the details its instance
        local name = encounterName or instanceName or L("EncounterFallbackName"):format(id)
        table.insert(rows, {
            kind = "Button",
            name = name,
            desc = encounterName and instanceName,
            instanceName = instanceName or "",
            preview = function()
                return getModel(journalEncounterID)
            end,
            buttonText = L("SettingsEditTimings"),
            func = function()
                private.RegisterEncounter(id)
                openEditor({
                    journalEncounterID = journalEncounterID,
                    journalInstanceID = first.journalInstanceID or info.journalInstanceID,
                    dungeonEncounterID = id,
                    name = encounterName,
                    instanceName = instanceName,
                })
            end,
            secondaryText = L("SettingsDeleteEncounter"),
            secondaryFunc = function()
                askToDelete(key, name)
            end,
        })
    end
    -- the bosses of an instance next to each other
    table.sort(rows, function(a, b)
        if a.instanceName ~= b.instanceName then
            return a.instanceName < b.instanceName
        end
        return a.name < b.name
    end)
    return rows
end

---a heading per instance of the current content with a row per encounter
---@return table[]
local getEncounterRows = function()
    local rows = {}
    for _, instance in ipairs(private.CurrentInstances or {}) do
        table.insert(rows, { kind = "Heading", name = private.GetEncounterInstanceName(instance.map) })
        for _, id in ipairs(instance.encounters) do
            local info = private.GetEncounterInfo(id)
            table.insert(rows, {
                kind = "Button",
                name = info.name,
                desc = info.instanceName,
                preview = function()
                    return getModel(info.journalEncounterID)
                end,
                buttonText = L("SettingsEditTimings"),
                func = function()
                    openEncounter(id)
                end,
            })
        end
    end
    return rows
end

private.RegisterSettingsPage({
    key = "Reminders",
    order = 60,
    name = L("SettingsPageReminders"),
    desc = L(private.isRetail and "SettingsPageRemindersDescription" or "SettingsPageRemindersDescriptionClassic"),
    rows = function()
        local rows = {
            {
                kind = "Button",
                name = L("SettingsOpenEncounter"),
                desc = L("SettingsOpenEncounterDescription"),
                buttonText = L("SettingsOpenEncounterButton"),
                -- the tour points at the Edit Timings of an encounter
                skipTour = true,
                func = function()
                    private.ShowEncounterPicker(openEncounter)
                end,
            },
        }
        local saved = getSavedRows()
        if #saved > 0 then
            table.insert(rows, { kind = "Heading", name = L("CreatedReminders") })
            for _, savedRow in ipairs(saved) do
                table.insert(rows, savedRow)
            end
        end
        for _, encounterRow in ipairs(getEncounterRows()) do
            table.insert(rows, encounterRow)
        end
        return rows
    end,
})

private.RegisterWindowState("picker", function()
    return private.IsEncounterPickerShown() and {} or nil
end, function()
    private.ShowEncounterPicker(openEncounter)
end)
