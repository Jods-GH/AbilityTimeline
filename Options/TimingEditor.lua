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

private.openTimingsEditor = function(encounterParams)
    private.Debug("Opening timing editor (table) for encounter: " ..
    tostring(encounterParams.dungeonEncounterID or encounterParams.journalEncounterID or "nil"))
    local frame = updateTimelineEditorFrame(encounterParams)
    frame.frame:Show()
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
