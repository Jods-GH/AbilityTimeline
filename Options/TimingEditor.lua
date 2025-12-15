local appName, private = ...

local AceGUI = LibStub("AceGUI-3.0")

local updateTimelineEditorFrame = function(dungeonId, encounterNumber)
    local frame = private.getTimingsEditorFrame()
    frame:SetEncounter(dungeonId, encounterNumber)
    private.Debug(frame, "AT_TIMINGS_EDITOR_FRAME")
    -- for key, value in pairs(private.Instances[dungeonId].encounters[encounterNumber].spells) do
    --     local spellInfo = C_Spell.GetSpellInfo(value.spellID);
    --     frame:AddItem({
    --         spellname = spellInfo.name,
    --         spellicon = spellInfo.iconID,
    --         timings = value.timings,
    --         rowText = "Spell: " .. spellInfo.name .. " (ID: " .. value.spellID .. ")",
    --         type = value.type,
    --     })
    -- end
    return frame
end

private.openTimingsEditor = function(dungeonId, encounterNumber)
    -- Open the timing editor for the specified dungeon and encounter
    private.Debug("Opening timing editor for dungeon " .. dungeonId .. ", encounter " .. encounterNumber)
    local frame = updateTimelineEditorFrame(dungeonId, encounterNumber)
    frame.frame:Show()
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
