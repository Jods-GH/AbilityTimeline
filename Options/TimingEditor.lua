local appName, private = ...

local AceGUI = LibStub("AceGUI-3.0")

local updateTimelineEditorFrame = function(a, encounterNumber, encounterID)
    local frame = private.getTimingsEditorFrame()
    if type(a) == "table" then
        -- new API: pass a table containing EJ ids: { journalEncounterID=, journalInstanceID=, dungeonEncounterID=, duration= }
        frame:SetEncounter(a)
    else
        -- legacy API: (dungeonId, encounterNumber, encounterID)
        frame:SetEncounter(a, encounterNumber, nil, encounterID)
    end
    private.Debug(frame, "AT_TIMINGS_EDITOR_FRAME")
    return frame
end

private.openTimingsEditor = function(a, encounterNumber, encounterID)
    -- Open the timing editor. Supports new table form or legacy args.
    if type(a) == "table" then
        private.Debug("Opening timing editor (table) for encounter: " .. tostring(a.dungeonEncounterID or a.journalEncounterID or "nil"))
        -- Persist lightweight reminderMeta immediately so UI lists can use it even before saving reminders
        local key = tonumber(a.dungeonEncounterID) or tonumber(a.journalEncounterID)
        if key then
            if a.journalEncounterID then private.db.profile.reminderMeta[key].journalEncounterID = a.journalEncounterID end
            if a.journalInstanceID then private.db.profile.reminderMeta[key].journalInstanceID = a.journalInstanceID end
            if a.name then private.db.profile.reminderMeta[key].name = a.name end
        end
        local frame = updateTimelineEditorFrame(a)
        frame.frame:Show()
    else
        private.Debug("Opening timing editor for dungeon " .. tostring(a) .. ", encounter " .. tostring(encounterNumber or "nil") .. ", encounterID " .. tostring(encounterID or "nil"))
        -- If called with legacy args (instanceID, encounterIndex), persist reminderMeta so Options can display instance/encounter names
        if type(a) == "number" and (encounterNumber ~= nil) then
            local inst = tonumber(a)
            local idx = tonumber(encounterNumber) or 1
            if inst and idx and EJ_GetEncounterInfoByIndex then
                local EncounterName, _, journalEncounterID, _, _, journalInstanceID, dungeonEncounterID = EJ_GetEncounterInfoByIndex(idx, inst)
                local key = tonumber(dungeonEncounterID) or tonumber(journalEncounterID) or tonumber(encounterID)
                if key then
                    private.db.profile.reminderMeta[key] = private.db.profile.reminderMeta[key] or {}
                    if journalEncounterID then private.db.profile.reminderMeta[key].journalEncounterID = journalEncounterID end
                    if journalInstanceID then private.db.profile.reminderMeta[key].journalInstanceID = journalInstanceID end
                    if EncounterName then private.db.profile.reminderMeta[key].name = EncounterName end
                end
            end
        end

        local frame = updateTimelineEditorFrame(a, encounterNumber, encounterID)
        frame.frame:Show()
    end
end


private.closeTimingsEditor = function()
    -- Close the timing editor
    private.Debug("Closing timing editor in function")
    local frame = private.TIMINGS_EDITOR_WINDOW
    if not frame then private.Debug('frame notfound') private.Debug(private.TIMINGS_EDITOR_WINDOW, "AT_TIMINGS_EDITOR_WINDOW") return end
    frame:Release()
    private.TIMINGS_EDITOR_WINDOW = nil
end

local createTimingsEditorFrame = function()
    private.Debug("Creating Timings Editor Frame")
    private.TIMINGS_EDITOR_WINDOW = AceGUI:Create("AtTimingsEditorDataFrame")
    private.Debug(private.TIMINGS_EDITOR_WINDOW, "AT_TIMINGS_EDITOR_WINDOW")
    return private.TIMINGS_EDITOR_WINDOW
end

private.getTimingsEditorFrame = function()
    if not private.TIMINGS_EDITOR_WINDOW then
        private.Debug("Timings Editor Frame does not exist, creating new one")
        local frame = createTimingsEditorFrame()
        return frame
    end
    private.Debug("Returning existing Timings Editor Frame")
    return private.TIMINGS_EDITOR_WINDOW
end
