local appName, app = ...
---@class AbilityTimeline
local private = app
local AceGUI = LibStub("AceGUI-3.0")
local L = private.getLocalisation

-- a dialog in the theme's dialog style to choose any encounter of the game type by its name, its instance or its id,
-- suggested from Data/Encounters while typing
local variables = {
    width = 420,
    offsetY = 120,
    padding = 16,
    headerHeight = 34,
    buttonHeight = 24,
    maxSuggestions = 8,
}

local picker
local entries

---every encounter once with its names to search, the current content first
---@return table[]
local getEntries = function()
    if entries then return entries end
    entries = {}
    local current = {}
    for _, instance in ipairs(private.CurrentInstances or {}) do
        for _, id in ipairs(instance.encounters) do
            current[id] = true
        end
    end
    for id, encounter in pairs(private.Encounters or {}) do
        local info = private.GetEncounterInfo(id)
        table.insert(entries, {
            id = id,
            name = info.name,
            instanceName = info.instanceName or "",
            search = (info.name .. "\n" .. encounter.name .. "\n" .. (info.instanceName or "")):lower(),
            current = current[id] or false,
        })
    end
    table.sort(entries, function(a, b)
        if a.current ~= b.current then
            return a.current
        end
        if a.name ~= b.name then
            return a.name < b.name
        end
        return a.id < b.id
    end)
    return entries
end

---@param text string
---@return table[]
local getSuggestions = function(text)
    text = strtrim(text):lower()
    if text == "" then return {} end
    local suggestions = {}
    local typedID = tonumber(text)
    for _, entry in ipairs(getEntries()) do
        if entry.search:find(text, 1, true) or (typedID and tostring(entry.id):sub(1, #text) == text) then
            table.insert(suggestions, {
                text = entry.name,
                detail = L("EncounterPickerDetail"):format(entry.instanceName, entry.id),
                value = entry.id,
            })
            if #suggestions == variables.maxSuggestions then break end
        end
    end
    -- an id the data doesn't have can still be opened
    if typedID and #suggestions == 0 then
        table.insert(suggestions, {
            text = L("EncounterFallbackName"):format(typedID),
            detail = tostring(typedID),
            value = typedID,
        })
    end
    return suggestions
end

---@param id number
local choose = function(id)
    local onPick = picker.onPick
    picker.frame:Hide()
    onPick(id)
end

---the encounter of the text typed: an id, else the first suggestion
---@return number|nil
local resolve = function()
    local text = picker.box:GetText() or ""
    local id = tonumber(strtrim(text))
    if id then return id end
    local suggestion = getSuggestions(text)[1]
    return suggestion and suggestion.value
end

local createPicker = function()
    local frame = CreateFrame("Frame", "AbilityTimelineEncounterPicker", UIParent)
    frame:Hide()
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetWidth(variables.width)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, variables.offsetY)
    frame:EnableMouse(true)
    -- closes with escape
    table.insert(UISpecialFrames, frame:GetName())
    local padding = variables.padding

    frame.Title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.Title:SetPoint("TOPLEFT", frame, "TOPLEFT", padding, -10)
    frame.Title:SetText(L("EncounterPickerTitle"))
    frame.Text = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.Text:SetPoint("TOPLEFT", frame, "TOPLEFT", padding, -variables.headerHeight - padding)
    frame.Text:SetWidth(variables.width - padding * 2)
    frame.Text:SetJustifyH("LEFT")
    frame.Text:SetWordWrap(true)
    frame.Text:SetText(L("EncounterPickerText"))

    local box = AceGUI:Create("AtEditBox")
    box.frame:SetParent(frame)
    box:SetLabel("")
    box:DisableButton(true)
    box:SetWidth(variables.width - padding * 2)
    box.frame:SetPoint("TOPLEFT", frame.Text, "BOTTOMLEFT", 0, -padding / 2)
    box.frame:Show()
    box:SetCallback("OnTextChanged", function()
        private.RefreshAutoComplete(box)
    end)
    private.AttachAutoComplete(box, getSuggestions, function(suggestion)
        choose(suggestion.value)
    end)

    local createButton = function(anchor)
        local button = AceGUI:Create("AtButton")
        button:SetWidth((variables.width - padding * 3) / 2)
        button.frame:SetParent(frame)
        button.frame:SetPoint(anchor, frame, anchor, anchor == "BOTTOMLEFT" and padding or -padding, padding)
        button.frame:Show()
        return button
    end
    local cancel = createButton("BOTTOMLEFT")
    cancel:SetText(L("ReminderCancelButton"))
    cancel:SetCallback("OnClick", function()
        frame:Hide()
    end)
    local open = createButton("BOTTOMRIGHT")
    open:SetText(L("EncounterPickerOpen"))
    open:SetStyle("Primary")
    open:SetCallback("OnClick", function()
        local id = resolve()
        if id then
            choose(id)
        end
    end)

    frame:SetScript("OnHide", function()
        private.HideAutoComplete()
    end)
    picker = {
        frame = frame,
        box = box,
        ApplySettings = function()
            private.ThemeApply.Window(frame, private.GetWindowStyle("Dialog"), nil, frame.Title)
            private.ThemeApply.FontRole(frame.Text, "Control")
        end,
    }
    picker:ApplySettings()
    private.RegisterThemed(picker)
    frame:SetHeight(variables.headerHeight + padding * 3 + frame.Text:GetStringHeight() + box.frame:GetHeight() +
        variables.buttonHeight + padding)
end

---asks for an encounter of the game type, onPick gets its dungeon encounter id
---@param onPick fun(dungeonEncounterID: number)
private.ShowEncounterPicker = function(onPick)
    if not picker then
        createPicker()
    end
    picker.onPick = onPick
    picker.box:SetText("")
    picker.frame:Show()
    picker.box:SetFocus()
end

private.IsEncounterPickerShown = function()
    return picker and picker.frame:IsShown()
end
