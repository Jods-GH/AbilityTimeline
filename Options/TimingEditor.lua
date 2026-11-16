local appName, app = ...
---@class AbilityTimeline
local private = app
local AceGUI = LibStub("AceGUI-3.0")

local updateTimelineEditorFrame = function(encounterParams)
    local frame = private.getTimingsEditorFrame()
    frame:SetEncounter(encounterParams)
    private.Debug(frame, "AT_TIMINGS_EDITOR_FRAME")
    return frame
end

private.UpdateTimingsEditorGamePad = function()
    local frame = private.TIMINGS_EDITOR_WINDOW
    if not (frame and C_GamePad and frame.frame.EnableGamePadButton) then return end
    local gamePad = C_GamePad.IsEnabled()
    frame.frame:EnableGamePadButton(gamePad and not private.IMPORT_DIALOG_WINDOW)
    frame.frame:SetScript("OnGamePadButtonDown", function(_, button)
        if private.OnTourGamePadButton(button) then
            return
        elseif button == "PAD4" and frame.encounterID then
            private.showImportDialog(frame.encounterID, frame, nil, frame.difficulty)
        elseif button == "PAD2" then
            private.closeTimingsEditor()
        end
    end)
    frame.container:SetGamePadHint(gamePad and ("%s   %s %s   %s %s"):format(
        private.getLocalisation("GamePadEditorHint"), GetBindingText("PAD4", 1), private.getLocalisation("EditorImport"),
        GetBindingText("PAD2", 1), private.getLocalisation("GamePadClose")) or "")
end

private.openTimingsEditor = function(encounterParams)
    private.Debug("Opening timing editor (table) for encounter: " ..
    tostring(encounterParams.dungeonEncounterID or encounterParams.journalEncounterID or "nil"))
    local frame = updateTimelineEditorFrame(encounterParams)
    frame.frame:Show()
    private.UpdateTimingsEditorGamePad()
    -- the editor's frame is reused, it is hooked once
    if not frame.frame.atTourHooked then
        frame.frame.atTourHooked = true
        frame.frame:HookScript("OnHide", function()
            private.OnTourEvent("editorClosed")
        end)
    end
    private.OnTourEvent("editorOpen")
end


private.closeTimingsEditor = function()
    -- Close the timing editor
    private.Debug("Closing timing editor in function")
    local frame = private.TIMINGS_EDITOR_WINDOW
    if not frame then
        private.Debug('frame notfound')
        private.Debug(private.TIMINGS_EDITOR_WINDOW, "AT_TIMINGS_EDITOR_WINDOW")
        return
    end
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

private.RegisterWindowState("editor", function()
    local frame = private.TIMINGS_EDITOR_WINDOW
    if not (frame and frame.frame:IsShown()) then return end
    return {
        dungeonEncounterID = frame.encounterID,
        journalEncounterID = frame.journalEncounterID,
        journalInstanceID = frame.journalInstanceID,
        instanceName = frame.instanceName,
        name = frame.encounterName,
        mode = frame.mode,
        stage = frame.stage,
        difficulty = frame.difficulty,
    }
end, function(state)
    private.openTimingsEditor(state)
    local frame = private.TIMINGS_EDITOR_WINDOW
    frame.mode = state.mode or "stages"
    frame.stage = state.stage or 1
    frame:RefreshReminders()
end)
