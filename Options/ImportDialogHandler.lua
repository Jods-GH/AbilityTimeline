local appName, app = ...
---@class AbilityTimeline
local private = app
local AceGUI = LibStub("AceGUI-3.0")
local ThemeApply = private.ThemeApply
local L = private.getLocalisation

-- the import and export dialogs of the timings editor. Import shows what a pasted text holds per stage and how much of
-- it is for the player, export the reminders and boss timers of an encounter in each format
local variables = {
    importLines = 10,
    exportLines = 12,
}
-- the export formats in the order of their buttons, Better Timeline's own first
local EXPORT_FORMATS = { "encoded", "viserio", "mrt", "json" }
-- the formats that can hold boss timer rules
local RULE_FORMATS = { encoded = true, json = true }

---@param text string
---@param color string -- a palette color
---@return string
local colored = function(text, color)
    local r, g, b = ThemeApply.Color(color)
    return string.format("|cff%02x%02x%02x%s|r", r * 255, g * 255, b * 255, text)
end

---a label in a text role of the theme
---@param role string
---@return table
local createLabel = function(role)
    local label = AceGUI:Create("Label")
    label:SetFullWidth(true)
    label:SetFontObject(ThemeApply.FontObject(role))
    return label
end

---a row of the dialog like the settings window's: label left, control right
---@param dialog AtImportDialog
---@param key string
---@param control table
---@param tooltip string|nil
local addRow = function(dialog, key, control, tooltip)
    local row = AceGUI:Create("AtSettingRow")
    row:SetLabel(L(key))
    row:AddChild(control)
    if tooltip then
        control:SetCallback("OnEnter", function()
            GameTooltip:SetOwner(control.frame, "ANCHOR_TOPLEFT")
            GameTooltip:AddLine(L(tooltip), 1, 1, 1, true)
            GameTooltip:Show()
        end)
        control:SetCallback("OnLeave", function() GameTooltip:Hide() end)
    end
    dialog:AddChild(row)
end

---two buttons side by side at the bottom of a dialog
---@param dialog AtImportDialog
---@return AtButton left, AtButton right
local addButtons = function(dialog, leftText, rightText)
    local group = AceGUI:Create("SimpleGroup")
    group:SetLayout("Flow")
    group:SetFullWidth(true)
    local left = AceGUI:Create("AtButton")
    left:SetText(leftText)
    left:SetRelativeWidth(0.5)
    group:AddChild(left)
    local right = AceGUI:Create("AtButton")
    right:SetText(rightText)
    right:SetRelativeWidth(0.5)
    group:AddChild(right)
    dialog:AddChild(group)
    return left, right
end

---what a parsed import holds: its format and encounter, per stage how many reminders and how many for the player,
---the boss timers. The whole note is kept, the reminders for others are left out at the pull
---@param encounterID number
---@param reminders table[]
---@param rules table[]
---@return string
local describeImport = function(encounterID, reminders, rules)
    local util = private.ImportUtil
    local lines = {}
    local format = util.lastParsedFormat and L("ImportFormat_" .. util.lastParsedFormat)
    table.insert(lines, colored(format or "", "Accent"))
    if util.lastParsedEncounterID and util.lastParsedEncounterID ~= encounterID then
        table.insert(lines, colored(L("ImportEncounterMismatchPlain"), "Danger"))
    end
    local stages, order = {}, {}
    for _, reminder in ipairs(reminders) do
        local stage = tonumber(reminder.phase) or 1
        if not stages[stage] then
            stages[stage] = { all = 0, mine = 0 }
            table.insert(order, stage)
        end
        stages[stage].all = stages[stage].all + 1
        if util:DoesTagApplyToPlayer(reminder.tag) then
            stages[stage].mine = stages[stage].mine + 1
        end
    end
    table.sort(order)
    for _, stage in ipairs(order) do
        table.insert(lines, L("ImportPreviewStage"):format(tostring(stage), stages[stage].all, stages[stage].mine))
    end
    if #rules > 0 then
        table.insert(lines, L("ImportPreviewBossTimers"):format(#rules))
    end
    return table.concat(lines, "\n")
end

local closeImportDialog = function()
    local dialog = private.IMPORT_DIALOG_WINDOW
    if not dialog then return end
    private.IMPORT_DIALOG_WINDOW = nil
    dialog:Release()
    private.OnTourEvent("importClosed")
end

local closeExportDialog = function()
    local dialog = private.EXPORT_DIALOG_WINDOW
    if not dialog then return end
    private.EXPORT_DIALOG_WINDOW = nil
    dialog:Release()
    private.OnTourEvent("exportClosed")
end

private.createImportDialog = function(editorWindow, encounterID, initialImportText)
    if private.IMPORT_DIALOG_WINDOW then return private.IMPORT_DIALOG_WINDOW end
    closeExportDialog()
    local dialog = AceGUI:Create("AtImportDialog")
    dialog:SetTitle(L("ImportDialogTitle"))
    dialog:SetNote(L("ImportDialogFreeOfCharge"))
    dialog:SetAutoAdjustHeight(true)
    private.IMPORT_DIALOG_WINDOW = dialog

    local close = closeImportDialog
    dialog.closeButton:SetScript("OnClick", close)

    local importText = AceGUI:Create("AtMultiLineEditBox")
    dialog.atEncounterID = encounterID
    dialog.atImportText = importText
    importText:SetLabel(L("ImportTextPlaceholder"))
    importText:SetFullWidth(true)
    importText:SetNumLines(variables.importLines)
    importText:DisableButton(true)
    dialog:AddChild(importText)

    local preview = createLabel("Control")
    dialog:AddChild(preview)

    local merge = AceGUI:Create("AtCheckBox")
    merge:SetLabel("")
    merge:SetValue(private.db.profile.importMergeMode)
    addRow(dialog, "ImportMergeMode", merge, "ImportMergeModeDescription")

    local importButton, cancelButton = addButtons(dialog, L("ImportButton"), L("ReminderCancelButton"))
    importButton:SetStyle("Primary")
    cancelButton:SetCallback("OnClick", close)

    ---the reminders and boss timers the text holds; nil and the error when there is nothing to import
    local parse = function()
        local text = importText:GetText()
        if not text or strtrim(text) == "" then
            return nil, nil, L("ImportPreviewEmpty")
        end
        local reminders, errorMsg = private.ImportUtil:ParseImportText(text)
        if errorMsg then
            return nil, nil, L("ImportError"):format(errorMsg)
        end
        return reminders, private.ImportUtil.lastParsedRules or {}
    end

    local updatePreview = function()
        local reminders, rules, problem = parse()
        if problem then
            preview:SetText(colored(problem, problem == L("ImportPreviewEmpty") and "Muted" or "Danger"))
        else
            preview:SetText(describeImport(encounterID, reminders, rules))
        end
        importButton:SetDisabled(reminders == nil)
        dialog:DoLayout()
    end

    importText:SetCallback("OnTextChanged", updatePreview)
    merge:SetCallback("OnValueChanged", function(_, _, value)
        private.db.profile.importMergeMode = value
    end)

    importButton:SetCallback("OnClick", function()
        local kept, rules = parse()
        if not kept then return end
        local importData = importText:GetText()
        close()
        -- a short countdown that can still be cancelled before anything is changed
        local importPopup = AceGUI:Create("AtImportPopup")
        local onComplete = function()
            if not private.ImportUtil:ApplyReminders(encounterID, kept, private.db.profile.importMergeMode, rules) then
                private.Debug("Failed to apply reminders")
                return
            end
            local editor = editorWindow or private.TIMINGS_EDITOR_WINDOW
            if editor then
                -- the editor still has the reminders from before, undo brings them back
                editor:RecordUndo()
                editor:LoadReminders(encounterID)
                editor:RefreshReminders()
            end
        end
        local onCancel = function()
            private.showImportDialog(encounterID, editorWindow, importData)
        end
        importPopup:StartImport(5, onComplete, onCancel)
    end)

    if initialImportText and initialImportText ~= "" then
        importText:SetText(initialImportText)
    end
    updatePreview()
    private.OnTourEvent("importOpen")
    return dialog
end

private.showImportDialog = function(encounterID, editorWindow, initialImportText)
    if not encounterID or private.IMPORT_DIALOG_WINDOW then
        return
    end
    -- the dialog opens above the timings editor, which stays open and shows the imported reminders
    private.createImportDialog(editorWindow, encounterID, initialImportText)
end

private.showExportDialog = function(encounterID)
    if not encounterID or private.EXPORT_DIALOG_WINDOW then return end
    local reminders = private.db.profile.reminders[encounterID] or {}
    local rules = private.db.profile.timerRules and private.db.profile.timerRules[encounterID]
    if #reminders == 0 and (not rules or #rules == 0) then
        return
    end

    closeImportDialog()

    local dialog = AceGUI:Create("AtImportDialog")
    dialog:SetTitle(L("ExportDialogTitle"))
    dialog:SetAutoAdjustHeight(true)
    private.EXPORT_DIALOG_WINDOW = dialog
    dialog.atEncounterID = encounterID
    local close = closeExportDialog
    dialog.closeButton:SetScript("OnClick", close)

    local formatGroup = AceGUI:Create("SimpleGroup")
    formatGroup:SetLayout("Flow")
    formatGroup:SetFullWidth(true)
    dialog:AddChild(formatGroup)
    local note = createLabel("Muted")
    dialog:AddChild(note)
    local exportText = AceGUI:Create("AtMultiLineEditBox")
    exportText:SetLabel("")
    exportText:SetFullWidth(true)
    exportText:SetNumLines(variables.exportLines)
    exportText:DisableButton(true)
    dialog:AddChild(exportText)
    local hint = createLabel("Muted")
    hint:SetText(L("ExportCopyHint"))
    dialog:AddChild(hint)

    local encounterName = EJ_GetEncounterInfo and EJ_GetEncounterInfo(encounterID) or ""
    local buttons = {}
    local show = function(format)
        private.db.profile.exportFormat = format
        for key, button in pairs(buttons) do
            button:SetStyle(key == format and "Primary" or "Plain")
        end
        note:SetText(rules and not RULE_FORMATS[format] and L("ExportRulesLeftOut") or "")
        exportText:SetText(private.ImportUtil:ExportReminders(reminders, format, encounterID, encounterName))
        -- ready to copy
        exportText:SetFocus()
        exportText:HighlightText()
        dialog:DoLayout()
    end
    for _, format in ipairs(EXPORT_FORMATS) do
        local button = AceGUI:Create("AtButton")
        button:SetText(L("ExportFormat_" .. format))
        button:SetRelativeWidth(1 / #EXPORT_FORMATS)
        button:SetCallback("OnClick", function() show(format) end)
        formatGroup:AddChild(button)
        buttons[format] = button
    end

    local sendButton, closeButton = addButtons(dialog, L("ReminderSendToChatButton"), L("DialogClose"))
    sendButton:SetDisabled(not IsInGroup())
    sendButton:SetCallback("OnClick", function()
        private.StartExportingToChat(encounterID)
        close()
    end)
    closeButton:SetCallback("OnClick", close)

    show(tContains(EXPORT_FORMATS, private.db.profile.exportFormat) and private.db.profile.exportFormat or "encoded")
    private.OnTourEvent("exportOpen")
end

private.RegisterWindowState("import", function()
    local dialog = private.IMPORT_DIALOG_WINDOW
    if dialog and dialog.frame:IsShown() then
        return { encounterID = dialog.atEncounterID, text = dialog.atImportText:GetText() }
    end
end, function(state)
    private.showImportDialog(state.encounterID, private.TIMINGS_EDITOR_WINDOW, state.text)
end)

private.RegisterWindowState("export", function()
    local dialog = private.EXPORT_DIALOG_WINDOW
    if dialog and dialog.frame:IsShown() then
        return { encounterID = dialog.atEncounterID }
    end
end, function(state)
    private.showExportDialog(state.encounterID)
end)
