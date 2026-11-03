local appName, app = ...
---@class AbilityTimeline
local private = app
local L = private.getLocalisation

-- the reminders page: the encounters with saved reminders and every encounter of the season, each opening the
-- timings editor

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

---@param dungeonEncounterID number
local openSavedEncounter = function(dungeonEncounterID)
    private.RegisterEncounter(dungeonEncounterID, nil, false)
    local stored = private.db.profile.reminders[dungeonEncounterID]
    local first = stored and stored[1]
    if first then
        openEditor({
            journalEncounterID = first.journalEncounterID,
            journalInstanceID = first.journalInstanceID,
            dungeonEncounterID = dungeonEncounterID,
        })
    end
end

---the encounters with saved reminders, only those that carry a saved name
---@return table[]
local getSavedRows = function()
    local rows = {}
    for id, stored in pairs(private.db.profile.reminders) do
        local first = stored and stored[1]
        if first and (first.instanceName or first.encounterName) then
            local name = first.encounterName or first.instanceName
            if first.instanceName and first.encounterName then
                name = string.format("%s — %s", first.instanceName, first.encounterName)
            end
            table.insert(rows, {
                kind = "Button",
                name = name,
                desc = L("CreatedRemindersDescription"),
                buttonText = L("SettingsEditTimings"),
                func = function()
                    openSavedEncounter(tonumber(id))
                end,
            })
        end
    end
    table.sort(rows, function(a, b) return a.name < b.name end)
    return rows
end

local encounterRows

---a heading per instance of the season with a row per encounter, read once from the Encounter Journal
---@return table[]
local getEncounterRows = function()
    if encounterRows then
        return encounterRows
    end
    local instanceIDs = {}
    for instanceID in pairs(private.Instances) do
        table.insert(instanceIDs, instanceID)
    end
    table.sort(instanceIDs)
    local rows = {}
    for _, instanceID in ipairs(instanceIDs) do
        EJ_SelectInstance(instanceID)
        local instanceName = EJ_GetInstanceInfo()
        -- the journal is not loaded yet, try again the next time
        if not instanceName then
            return rows
        end
        table.insert(rows, { kind = "Heading", name = instanceName })
        for encounterNumber in ipairs(private.Instances[instanceID].encounters) do
            local name, _, journalEncounterID, _, _, journalInstanceID, dungeonEncounterID =
                EJ_GetEncounterInfoByIndex(encounterNumber, instanceID)
            if name then
                table.insert(rows, {
                    kind = "Button",
                    name = name,
                    desc = L("EditTimingsForEncounter"),
                    buttonText = L("SettingsEditTimings"),
                    func = function()
                        openEditor({
                            journalEncounterID = journalEncounterID,
                            journalInstanceID = journalInstanceID,
                            dungeonEncounterID = dungeonEncounterID,
                            name = name,
                        })
                    end,
                })
            end
        end
    end
    encounterRows = rows
    return rows
end

private.RegisterSettingsPage({
    key = "Reminders",
    order = 60,
    name = L("SettingsPageReminders"),
    desc = L("SettingsPageRemindersDescription"),
    hidden = function()
        return not private.isRetail
    end,
    rows = function()
        local rows = {}
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
