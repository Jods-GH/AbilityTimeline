local appName, private = ...

local AceGUI = LibStub("AceGUI-3.0")

local updateTimelineEditorFrame = function(dungeonId, encounterNumber)
    local Instancename, Instancedescription, _, InstanceImage, _, _, _, _, _ = EJ_GetInstanceInfo(dungeonId)
    local EncounterName, Encounterdescription, journalEncounterID, rootSectionID, link, journalInstanceID, dungeonEncounterID, instanceID =
    EJ_GetEncounterInfoByIndex(encounterNumber, dungeonId)
    local frame = private.getTimingsEditorFrame()
    frame.container:SetTitle(private.getLocalisation("TimingsEditorTitle") .. ": " .. Instancename .. " - " .. EncounterName)
    DevTool:AddData(frame, "AT_TIMINGS_EDITOR_FRAME")
    for key, value in pairs(private.encounterTable[dungeonId][encounterNumber].spells) do
        local spellInfo = C_Spell.GetSpellInfo(value.spellID);
        frame:AddItem({
            spellname = spellInfo.name,
            spellicon = spellInfo.iconID,
            timings = value.timings,
            rowText = "Spell: " .. spellInfo.name .. " (ID: " .. value.spellID .. ")",
            type = value.type,
        })
    end
    return frame
end

private.openTimingsEditor = function(dungeonId, encounterNumber)
    -- Open the timing editor for the specified dungeon and encounter
    print("Opening timing editor for dungeon " .. dungeonId .. ", encounter " .. encounterNumber)
    local frame = updateTimelineEditorFrame(dungeonId, encounterNumber)
end


private.closeTimingsEditor = function()
    -- Close the timing editor
    print("Closing timing editor")
    local frame = private.getTimingsEditorFrame()
    frame:Release()
    private.TIMINGS_EDITOR_WINDOW = nil
end

local createTimelineDataFrame = function(frame)
    print("Creating Timeline Data Frame inside Timings Editor Frame")
    local dataFrame = AceGUI:Create("AtTimingsEditorScrollContainer")
    dataFrame.frame:SetWidth(frame.content:GetWidth())
    dataFrame.frame:SetHeight(frame.content:GetHeight())
    frame:AddChild(dataFrame)
    DevTool:AddData(dataFrame, "AT_TIMELINE_DATA_FRAME")
    return dataFrame
end

local createTimingsEditorFrame = function()
    print("Creating Timings Editor Frame")
    private.TIMINGS_EDITOR_WINDOW = AceGUI:Create("AtTimingsEditorDataFrame")
    DevTool:AddData(private.TIMINGS_EDITOR_WINDOW, "AT_TIMINGS_EDITOR_WINDOW")
    return private.TIMINGS_EDITOR_WINDOW
end

private.getTimingsEditorFrame = function()
    if not private.TIMINGS_EDITOR_WINDOW then
        local frame = createTimingsEditorFrame()
        return frame
    end
    print("Returning existing Timings Editor Frame")
    DevTools_Dump(private.TIMINGS_EDITOR_WINDOW)
    return private.TIMINGS_EDITOR_WINDOW
end
