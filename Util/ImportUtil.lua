local appName, app = ...
---@class AbilityTimeline
local private = app
local CustomNames = C_AddOns.IsAddOnLoaded("CustomNames") and LibStub("CustomNames")
private.ImportUtil = private.ImportUtil or {}
local ImportUtil = private.ImportUtil
-- the version of the !AT exports and the JSON's exportVersion: strings of a newer version are refused, older ones
-- are read the way their version wrote them. 1 had no version (!AT:), 2 added the boss timer rules
local EXPORT_VERSION = 2
local IMPORT_PREFIX = "!AT" .. EXPORT_VERSION .. ":"
-- the keys of a boss timer rule (Plugins/TimerRules.lua) in the !AT exports
local RULE_KEYS = {
    "match", "value", "name", "color", "useColor", "glow", "glowWhen", "glowSelection", "displays", "countdown", "TTS", "useTTS",
    "TTSTimer", "sound", "changes",
}
-- the reminder keys the !AT: strings carry
local ENCODED_KEYS = {
    "name", "spellId", "CombatTime", "CombatTimeDelay", "StartTimerAfter", "severity", "effectTypes", "tag", "phase",
    "text", "TTS", "useTTS", "TTSTimer", "dur", "countdown", "sound", "glowunit", "displays", "color", "useColor", "glow",
    "glowWhen", "glowSelection", "changes",
}

-- Parse time string in mm:ss or seconds format
---@param timeStr string Time as "mm:ss" or "seconds"
---@return number|nil parsed time in seconds
local function parseTime(timeStr)
    if not timeStr then return nil end

    -- Remove leading/trailing whitespace
    timeStr = timeStr:gsub("^%s+", ""):gsub("%s+$", "")

    -- Try to match mm:ss or mm:ss.s (seconds may contain fraction)
    local minutes, seconds = string.match(timeStr, "^(%d+):(%d+%.?%d*)$")
    if minutes and seconds then
        return tonumber(minutes) * 60 + tonumber(seconds)
    end

    -- Try as plain seconds
    local secs = tonumber(timeStr)
    if secs then
        return secs
    end

    return nil
end

---@param spellId number|nil
---@param text string|nil
---@param time number
---@param phase number
---@return table reminder with the spell's name and icon
local function newReminder(spellId, text, time, phase)
    local spellInfo = spellId and spellId > 0 and C_Spell.GetSpellInfo(spellId)
    return {
        name = text or spellInfo and spellInfo.name or (spellId and "Spell " .. spellId) or "Unknown",
        text = text,
        spellId = spellId or 0,
        spellName = spellInfo and spellInfo.name,
        iconId = spellInfo and spellInfo.iconID or 134400,
        CombatTime = time,
        CombatTimeDelay = 0,
        StartTimerAfter = 0,
        severity = 1,
        effectTypes = 0,
        phase = phase,
    }
end

-- Parse single MRT note line: {time:1:30,p2} Name {spell:123} Name2 {spell:456} or {time:0:25} text
---@param line string MRT note line
---@return table|nil parsed reminders of the line
local function parseMRTLine(line)
    local timeStr = line and string.match(line, "{time:([^}]+)}")
    if not timeStr then return nil end

    local timeText, options = strsplit(",", timeStr, 2)
    local time = parseTime(timeText)
    if not time then return nil end

    local phase = 1
    for option in (options or ""):gmatch("[^,]+") do
        local phaseText = option:match("^p:?(.+)$")
        if phaseText then
            -- named and global (p:g2) phases can't be followed
            phase = tonumber(phaseText)
            if not phase then return nil end
        elseif option:find("^%u%u%u:") or option == "e" then
            -- timers started by combat log or custom events
            return nil
        end
    end

    local rest = line:gsub("{time:[^}]+}", ""):gsub("|+c%x%x%x%x%x%x%x%x", ""):gsub("|+r", "")
    local reminders = {}
    for name, spellId in rest:gmatch("([^%s{}]*)%s*{spell:(%d+)}") do
        local reminder = newReminder(tonumber(spellId), nil, time, phase)
        reminder.tag = name ~= "" and name or nil
        table.insert(reminders, reminder)
    end
    if #reminders == 0 then
        local text = strtrim((rest:gsub("{[^}]*}", "")))
        if text == "" then return nil end
        -- "Name text" when the name is someone of the group
        local name, nameText = text:match("^(%S+)%s+(.+)$")
        local isMember = name and (name:lower() == UnitName("player"):lower() or UnitInRaid(name) or UnitInParty(name))
        local reminder = newReminder(nil, isMember and nameText or text, time, phase)
        reminder.tag = isMember and name or nil
        table.insert(reminders, reminder)
    end
    return reminders
end

-- Parse MRT note format (plain text with {time:} and {spell:} markers)
---@param mrtText string Complete MRT note text
---@return table array of parsed reminders
function ImportUtil:ParseMRTFormat(mrtText)
    local reminders = {}

    -- Split by lines
    local lines = {}
    for line in mrtText:gmatch("[^\n\r]+") do
        table.insert(lines, line)
    end

    private.Debug("Split into " .. #lines .. " lines")

    for i, line in ipairs(lines) do
        local lineReminders = parseMRTLine(line)
        if lineReminders then
            for _, reminder in ipairs(lineReminders) do
                table.insert(reminders, reminder)
            end
        else
            private.Debug("Failed to parse line " .. i)
        end
    end

    private.Debug("ParseMRTFormat returning " .. #reminders .. " reminders")
    return reminders
end

-- Parse Viserio format
---@param viserioText string Viserio format text
---@return table array of parsed reminders
---@return number|nil encounterID from first line
---@return string|nil encounterName from first line
function ImportUtil:ParseViserioFormat(viserioText)
    local reminders = {}
    local encounterID = nil
    local encounterName = nil

    -- Split by lines
    local lines = {}
    for line in viserioText:gmatch("[^\n\r]+") do
        table.insert(lines, line)
    end

    if #lines == 0 then
        return reminders, encounterID, encounterName
    end

    -- the first line can be "EncounterID:number;Name:string", notes copied without it start with the reminders
    encounterID = tonumber(lines[1]:match("^EncounterID:(%d+)"))
    encounterName = encounterID and lines[1]:match("Name:([^;]+)")

    for i = encounterID and 2 or 1, #lines do
        local params = {}
        for param in lines[i]:gmatch("([^;]+)") do
            local key, value = param:match("^%s*([%w]+)%s*:%s*(.-)%s*$")
            if key and value ~= "" then
                params[key:lower()] = value
            end
        end

        local time = parseTime(params.time)
        if time then
            local TTS = params.tts
            if TTS == "true" then
                TTS = true
            elseif TTS == "false" then
                TTS = nil
            end
            local reminder = newReminder(tonumber(params.spellid), params.text, time, tonumber(params.ph) or 1)
            reminder.tag = params.tag
            reminder.dur = tonumber(params.dur)
            reminder.TTS = TTS
            reminder.TTSTimer = tonumber(params.ttstimer)
            reminder.countdown = tonumber(params.countdown)
            reminder.sound = params.sound
            reminder.glowunit = params.glowunit
            table.insert(reminders, reminder)
        end
    end

    return reminders, encounterID, encounterName
end

-- Parse JSON format
---@param jsonText string JSON text containing reminder data
---@return table array of parsed reminders
function ImportUtil:ParseJSONFormat(jsonText)
    local reminders = {}
    local rules = {}
    local encounterID = nil
    local version = tonumber(jsonText:match('"exportVersion"%s*:%s*(%d+)')) or 1
    if version > EXPORT_VERSION then
        return reminders, nil, rules, private.getLocalisation("ImportNewerVersion")
    end

    -- Extract encounterID from top-level JSON
    local encounterId = tonumber(jsonText:match('"encounterId"%s*:%s*(%d+)')) or
    tonumber(jsonText:match('encounterId%s*:%s*(%d+)'))
    if encounterId then
        encounterID = encounterId
    end

    -- the parsed reminders and rules by their position in the export, for the lanes listed beside them
    local reminderAt, ruleAt = {}, {}
    local function findRemindersInJSON(text)
        local results = {}

        -- Look for array elements: {time:X,spellId:X,...} or {"time":X,"spellId":X,...}
        -- Pattern matches JSON objects with curly braces, handling nested structures
        local pattern = "{[^{}]*}"

        for match in text:gmatch(pattern) do
            local ruleMatch = match:match('"match"%s*:%s*"([^"]*)"')
            if ruleMatch then
                table.insert(rules, ImportUtil.ParseJSONRule(match, ruleMatch))
                table.insert(ruleAt, rules[#rules])
            end
            local time = tonumber(match:match('"time"%s*:%s*([%d%.]+)'))
            if match:match('"time"%s*:') then table.insert(reminderAt, false) end
            local spellId = tonumber(match:match('"spellId"%s*:%s*(%d+)'))
            local name = match:match('"name"%s*:%s*"([^"]*)"')
            local text = match:match('"text"%s*:%s*"([^"]*)"')
            local iconId = tonumber(match:match('"iconId"%s*:%s*(%d+)'))

            if time and (spellId or text) then
                local reminder = newReminder(spellId, text, time, tonumber(match:match('"phase"%s*:%s*([%d%.]+)')) or 1)
                reminder.name = name or reminder.name
                reminder.iconId = iconId or reminder.iconId
                reminder.CombatTimeDelay = tonumber(match:match('"duration"%s*:%s*([%d%.]+)')) or 0
                reminder.severity = tonumber(match:match('"severity"%s*:%s*(%d+)')) or 1
                reminder.effectTypes = tonumber(match:match('"effectTypes"%s*:%s*(%d+)')) or 0
                reminder.tag = match:match('"tag"%s*:%s*"([^"]*)"')
                table.insert(results, reminder)
                reminderAt[#reminderAt] = reminder
            end
        end

        return results
    end

    local parsed = findRemindersInJSON(jsonText)
    -- the nested lanes need a full JSON decode, without one the reminders and rules come without their lanes
    if C_EncodingUtil and C_EncodingUtil.DeserializeJSON and
        (jsonText:find('"reminderLanes"') or jsonText:find('"ruleLanes"')) then
        local decoded, data = pcall(C_EncodingUtil.DeserializeJSON, jsonText)
        if decoded and type(data) == "table" then
            for key, items in pairs({ reminder = { data.reminderLanes, reminderAt }, rule = { data.ruleLanes, ruleAt } }) do
                for _, lanes in ipairs(type(items[1]) == "table" and items[1] or {}) do
                    local target = type(lanes) == "table" and items[2][tonumber(lanes[key])]
                    if target then
                        target.changes = private.CooldownText.CleanChanges(lanes.changes)
                        if key == "rule" then target.glowSelection = private.CooldownText.CleanSelection(lanes.glowSelection) end
                    end
                end
            end
        end
    end
    return parsed, encounterID, rules
end

---a boss timer rule of the JSON export, its color and displays are flat keys there
---@param object string -- the rule's JSON object
---@param match string
---@return table
ImportUtil.ParseJSONRule = function(object, match)
    local stringOf = function(key) return object:match('"' .. key .. '"%s*:%s*"([^"]*)"') end
    local numberOf = function(key) return tonumber(object:match('"' .. key .. '"%s*:%s*(%-?[%d%.]+)')) end
    local boolOf = function(key) return object:match('"' .. key .. '"%s*:%s*(%a+)') end
    local rule = {
        match = match,
        value = stringOf("value") or tostring(numberOf("value") or ""),
        name = stringOf("name"),
        glow = stringOf("glow"),
        glowWhen = stringOf("glowWhen"),
        countdown = numberOf("countdown"),
        TTS = stringOf("TTS") or (boolOf("TTS") == "true" or nil),
        TTSTimer = numberOf("TTSTimer"),
        sound = stringOf("sound"),
    }
    if numberOf("colorR") then
        rule.color = { r = numberOf("colorR"), g = numberOf("colorG") or 1, b = numberOf("colorB") or 1 }
    end
    if boolOf("useColor") == "false" then
        rule.useColor = false
    end
    if boolOf("useTTS") == "false" then
        rule.useTTS = false
    end
    for _, display in ipairs({ "timeline", "bigIcon", "textHighlight" }) do
        if boolOf("show_" .. display) == "false" then
            rule.displays = rule.displays or { timeline = true, bigIcon = true, textHighlight = true }
            rule.displays[display] = false
        end
    end
    return rule
end

-- Auto-detect format and parse
---@param importText string Raw import text
---@return table parsed reminders
---@return string|nil error message if parsing failed
function ImportUtil:ParseImportText(importText)
    if not importText or importText == "" then
        return {}, "Empty import text"
    end

    -- Trim whitespace
    importText = importText:gsub("^%s+", ""):gsub("%s+$", "")
    self.lastParsedEncounterID = nil
    self.lastParsedEncounterName = nil
    self.lastParsedRules = {}
    -- the format found: encoded, viserio, json or mrt
    self.lastParsedFormat = nil

    -- Try encoded format first: !AT: (version 1) or !AT<version>:
    if importText:match("^!AT%d*:[A-Za-z0-9+/=]+$") and #importText > 50 then
        private.Debug("Detected encoded format")
        local reminders, rules, errorMsg = self:ParseEncodedFormat(importText)
        if errorMsg then
            return {}, errorMsg
        end
        self.lastParsedRules = rules
        if #reminders > 0 or #rules > 0 then
            self.lastParsedFormat = "encoded"
            return reminders
        end
    end

    -- Try Viserio format (starts with "EncounterID:" or directly with the reminders)
    if importText:match("^EncounterID:%d+") or importText:match("^ph:") or importText:match("^time:") then
        private.Debug("Detected Viserio format")
        local reminders, encounterID, encounterName = self:ParseViserioFormat(importText)
        if #reminders > 0 then
            -- Store encounter info for later use
            self.lastParsedEncounterID = encounterID
            self.lastParsedEncounterName = encounterName
            self.lastParsedFormat = "viserio"
            return reminders
        end
    end

    -- Try JSON format (starts with { and contains quoted keys or unquoted keys with colons)
    if importText:sub(1, 1) == "{" and (importText:match('"[%w_]+"%s*:') or importText:match('[%w_]+%s*:')) then
        private.Debug("Detected JSON format")
        local reminders, encounterID, rules, errorMsg = self:ParseJSONFormat(importText)
        if errorMsg then
            return {}, errorMsg
        end
        self.lastParsedRules = rules
        if #reminders > 0 or #rules > 0 then
            self.lastParsedFormat = "json"
            -- Store encounter ID if found in JSON
            if encounterID then
                self.lastParsedEncounterID = encounterID
            end
            return reminders
        end
    end

    -- Try MRT format (contains {time:} markers)
    if string.find(importText, "{time:") then
        private.Debug("Detected MRT format")
        local reminders = self:ParseMRTFormat(importText)
        if #reminders > 0 then
            self.lastParsedFormat = "mrt"
            return reminders
        end
    end

    return {}, private.getLocalisation("ImportParseError")
end

-- Check if a tag applies to the current player
---@param tag string Tag string (can contain multiple values separated by space)
---@return boolean True if tag applies to player
function ImportUtil:DoesTagApplyToPlayer(tag)
    if not tag or tag == "" or tag == "everyone" then
        return true
    end

    -- Get player info
    local playerName = UnitName("player")
    local playerClass, classFile = UnitClass("player")
    local playerSpecID, playerSpec, playerRole, _
    local specIndex = C_SpecializationInfo.GetSpecialization and C_SpecializationInfo.GetSpecialization()
    if specIndex then
        playerSpecID, playerSpec, _, _, playerRole = C_SpecializationInfo.GetSpecializationInfo(specIndex)
    end
    local _, subgroup
    if UnitInRaid("player") then
        _, _, subgroup, _, _, _, _, _, _, _, _, _ = GetRaidRosterInfo(UnitInRaid("player"))
    end
    local playerNickname = nil
    if CustomNames then
        playerNickname = CustomNames.Get("self")
    end

    -- Normalize role name to lowercase
    if playerRole == "TANK" then playerRole = "tank" end
    if playerRole == "HEALER" then playerRole = "healer" end
    if playerRole == "DAMAGER" then playerRole = "damager" end

    -- Split tag by spaces to allow multiple conditions
    for tagValue in tag:gmatch("[^%s]+") do
        tagValue = tagValue:gsub("^%s+", ""):gsub("%s+$", "") -- trim

        -- Check various tag types
        -- characters of other realms are saved as Name-Realm
        local fullName = playerName .. "-" .. (GetNormalizedRealmName() or "")
        if tagValue:lower() == playerName:lower() or tagValue:lower() == fullName:lower() or tagValue == "everyone" then
            return true
        end

        if playerNickname and tagValue == playerNickname then
            return true
        end

        if tagValue == playerRole then
            return true
        end

        if tagValue:lower() == classFile:lower() then
            return true
        end

        local groupTag = tonumber(tagValue:lower():match("^group(%d)$"))
        if groupTag and groupTag == subgroup then
            return true
        end

        if tagValue == "melee" and private.SpecPosition.melee and tContains(private.SpecPosition.melee, playerSpecID) then
            return true
        end

        if tagValue == "ranged" and private.SpecPosition.ranged and tContains(private.SpecPosition.ranged, playerSpecID) then
            return true
        end

        if playerSpec and tagValue:lower() == playerSpec:lower() then
            return true
        end
    end

    return false
end


-- Parse encoded format (CBOR + compression + base64)
---@param encodedText string Encoded string
---@return table array of parsed reminders
function ImportUtil:ParseEncodedFormat(text)
    local reminders, rules = {}, {}

    local prefixVersion, encodedText = text:match("^!AT(%d*):(.+)$")
    prefixVersion = tonumber(prefixVersion) or 1
    if prefixVersion > EXPORT_VERSION then
        return reminders, rules, private.getLocalisation("ImportNewerVersion")
    end

    -- Decode from base64
    local success, compressed = pcall(C_EncodingUtil.DecodeBase64, encodedText)
    if not success then
        private.Debug("Failed to decode base64")
        return reminders, rules
    end

    -- Decompress
    local success, serialized = pcall(C_EncodingUtil.DecompressString, compressed)
    if not success then
        private.Debug("Failed to decompress data")
        return reminders, rules
    end

    -- Deserialize CBOR
    local success, data = pcall(C_EncodingUtil.DeserializeCBOR, serialized)
    if not success or type(data) ~= "table" then
        private.Debug("Failed to deserialize CBOR data")
        return reminders, rules
    end
    if (tonumber(data.version) or prefixVersion) > EXPORT_VERSION then
        return reminders, rules, private.getLocalisation("ImportNewerVersion")
    end

    self.lastParsedEncounterID = data.encounterID
    for _, item in ipairs(data.rules or {}) do
        if type(item) == "table" and item.match then
            local rule = {}
            for _, key in ipairs(RULE_KEYS) do
                rule[key] = item[key]
            end
            rule.changes = private.CooldownText.CleanChanges(rule.changes)
            rule.glowSelection = private.CooldownText.CleanSelection(rule.glowSelection)
            table.insert(rules, rule)
        end
    end
    local reminderData = data.reminders or {}

    -- Convert to reminder format
    for _, item in ipairs(reminderData) do
        if type(item) == "table" and item.CombatTime and (item.spellId or item.text) then
            local reminder = newReminder(item.spellId, item.text, item.CombatTime, item.phase or 1)
            for _, key in ipairs(ENCODED_KEYS) do
                if item[key] ~= nil then
                    reminder[key] = item[key]
                end
            end
            reminder.changes = private.CooldownText.CleanChanges(reminder.changes)
            reminder.glowSelection = private.CooldownText.CleanSelection(reminder.glowSelection)
            table.insert(reminders, reminder)
        end
    end

    return reminders, rules
end

---@param reminders table array of reminder tables
---@return boolean valid
---@return string|nil validation message
function ImportUtil:ValidateReminders(reminders)
    if type(reminders) ~= "table" then
        return false, "Invalid reminders format"
    end

    if #reminders == 0 then
        return false, "No valid reminders found in import"
    end

    for i, reminder in ipairs(reminders) do
        if not reminder.CombatTime or type(reminder.CombatTime) ~= "number" then
            return false, string.format("Reminder %d: Invalid or missing combat time", i)
        end

        if reminder.CombatTime < 0 then
            return false, string.format("Reminder %d: Combat time cannot be negative", i)
        end

        if type(reminder.spellId) ~= "number" and not reminder.text then
            return false, string.format("Reminder %d: Invalid or missing spell ID", i)
        end
    end

    return true
end

---what makes two reminders the same one: stage, time, spell or text and who it is for
---@param reminder table
---@return string
ImportUtil.GetReminderKey = function(reminder)
    local spellId = reminder.spellId or 0
    local text = spellId > 0 and "" or reminder.text or reminder.name or ""
    return string.format("%s;%s;%d;%s;%s", tostring(tonumber(reminder.phase) or 1), tostring(reminder.CombatTime),
        spellId, text:lower(), (reminder.tag or "everyone"):lower())
end

-- Apply imported reminders to an encounter
---@param encounterID number encounter ID
---@param reminders table array of reminder tables
---@param mergeMode boolean if true, merge with existing; if false, replace
---@return boolean success
function ImportUtil:ApplyReminders(encounterID, reminders, mergeMode, rules)
    if not private.db or not private.db.profile or not private.db.profile.reminders then
        return false
    end

    -- Validate before applying, an import can be boss timer rules only
    local valid, msg = self:ValidateReminders(reminders)
    if not valid and not (rules and #rules > 0 and #reminders == 0) then
        private.Debug("Validation failed: " .. tostring(msg))
        return false
    end
    if rules and #rules > 0 then
        self:ApplyTimerRules(encounterID, rules, mergeMode)
    end

    if not mergeMode then
        -- Replace mode
        private.db.profile.reminders[encounterID] = {}
    else
        -- Merge mode
        if not private.db.profile.reminders[encounterID] then
            private.db.profile.reminders[encounterID] = {}
        end
    end

    -- an imported reminder replaces the one with the same stage, time, spell or text and tag instead of doubling it
    -- doubles left by earlier imports go as well
    local stored, index = {}, {}
    for _, reminder in ipairs(private.db.profile.reminders[encounterID]) do
        local key = ImportUtil.GetReminderKey(reminder)
        if not index[key] then
            table.insert(stored, reminder)
            index[key] = #stored
        end
    end
    private.db.profile.reminders[encounterID] = stored
    for _, reminder in ipairs(reminders) do
        local key = ImportUtil.GetReminderKey(reminder)
        if index[key] then
            stored[index[key]] = reminder
        else
            table.insert(stored, reminder)
            index[key] = #stored
        end
    end

    -- Sort reminders by time
    table.sort(private.db.profile.reminders[encounterID], function(a, b)
        return (a.CombatTime or 0) < (b.CombatTime or 0)
    end)

    return true
end

---a rule replaces the one that finds the same bars, all go when not merging
---@param encounterID number
---@param rules table[]
---@param mergeMode boolean
function ImportUtil:ApplyTimerRules(encounterID, rules, mergeMode)
    private.db.profile.timerRules = private.db.profile.timerRules or {}
    local stored = mergeMode and private.db.profile.timerRules[encounterID] or {}
    local keyOf = function(rule)
        return (rule.match or "spell") .. ";" .. tostring(rule.value or ""):lower()
    end
    local index = {}
    for i, rule in ipairs(stored) do
        index[keyOf(rule)] = i
    end
    for _, rule in ipairs(rules) do
        local key = keyOf(rule)
        if index[key] then
            stored[index[key]] = rule
        else
            table.insert(stored, rule)
            index[key] = #stored
        end
    end
    private.db.profile.timerRules[encounterID] = #stored > 0 and stored or nil
end

---the boss timer rules of an encounter for the exports
---@param encounterID number|nil
---@return table[]
local getRules = function(encounterID)
    return encounterID and private.db.profile.timerRules and private.db.profile.timerRules[encounterID] or {}
end

-- Format reminders for export
---@param reminders table array of reminder tables
---@param format string "encoded", "viserio", "json", or "mrt"
---@param encounterID number|nil Required for viserio format
---@param encounterName string|nil Optional for viserio format
---@return string formatted export text
function ImportUtil:ExportReminders(reminders, format, encounterID, encounterName)
    format = format or "encoded"

    if format == "encoded" then
        return self:ExportAsEncoded(reminders, encounterID)
    elseif format == "viserio" then
        if not encounterID then
            private.Debug("EncounterID required for Viserio export")
            return ""
        end
        return self:ExportAsViserio(reminders, encounterID, encounterName)
    elseif format == "json" then
        return self:ExportAsJSON(reminders, encounterID)
    elseif format == "mrt" then
        return self:ExportAsMRT(reminders)
    end

    return ""
end

-- Export as JSON
---@param reminders table
---@param encounterID number|nil
---@return string
function ImportUtil:ExportAsJSON(reminders, encounterID)
    local export = { exportVersion = EXPORT_VERSION }

    if encounterID then
        export.encounterId = encounterID
    end
    local rules = getRules(encounterID)
    if #rules > 0 then
        -- flat objects: the import reads objects without anything nested
        export.rules = {}
        for _, rule in ipairs(rules) do
            local item = {
                match = rule.match or "spell",
                value = rule.value or "",
                name = rule.name,
                glow = rule.glow,
                glowWhen = rule.glowWhen,
                countdown = rule.countdown,
                TTS = rule.TTS,
                useTTS = rule.useTTS,
                useColor = rule.useColor,
                TTSTimer = rule.TTSTimer,
                sound = rule.sound,
            }
            if rule.color then
                item.colorR, item.colorG, item.colorB = rule.color.r, rule.color.g, rule.color.b
            end
            for display, shown in pairs(rule.displays or {}) do
                item["show_" .. display] = shown
            end
            table.insert(export.rules, item)
            -- own lanes are nested, they travel beside the flat objects with the position of their rule
            if rule.changes or rule.glowSelection then
                export.ruleLanes = export.ruleLanes or {}
                table.insert(export.ruleLanes, { rule = #export.rules, changes = rule.changes, glowSelection = rule.glowSelection })
            end
        end
    end

    export.reminders = {}

    for index, reminder in ipairs(reminders) do
        if reminder.changes then
            export.reminderLanes = export.reminderLanes or {}
            table.insert(export.reminderLanes, { reminder = index, changes = reminder.changes })
        end
        table.insert(export.reminders, {
            time = reminder.CombatTime,
            spellId = reminder.spellId,
            name = reminder.name,
            text = reminder.text,
            tag = reminder.tag,
            phase = reminder.phase,
            duration = reminder.CombatTimeDelay,
            severity = reminder.severity,
            effectTypes = reminder.effectTypes,
        })
    end

    local function tableToJson(tbl, indent, isArray)
        indent = indent or 0
        local indentStr = string.rep("  ", indent)
        local nextIndentStr = string.rep("  ", indent + 1)

        -- Detect if this should be an array (check if all keys are numeric and sequential)
        local isArrayTable = false
        if not isArray then
            isArrayTable = true
            local maxKey = 0
            for k, v in pairs(tbl) do
                if type(k) ~= "number" or k < 1 or k % 1 ~= 0 then
                    isArrayTable = false
                    break
                end
                maxKey = math.max(maxKey, k)
            end
            if isArrayTable and maxKey > 0 then
                for i = 1, maxKey do
                    if tbl[i] == nil then
                        isArrayTable = false
                        break
                    end
                end
            end
        end

        if isArrayTable then
            -- Encode as JSON array
            local result = "[\n"
            for i, v in ipairs(tbl) do
                if i > 1 then result = result .. ",\n" end
                result = result .. nextIndentStr

                if type(v) == "table" then
                    result = result .. tableToJson(v, indent + 1, false)
                elseif type(v) == "string" then
                    result = result .. '"' .. v:gsub('"', '\\"') .. '"'
                elseif type(v) == "number" then
                    result = result .. tostring(v)
                elseif type(v) == "boolean" then
                    result = result .. (v and "true" or "false")
                else
                    result = result .. "null"
                end
            end
            result = result .. "\n" .. indentStr .. "]"
            return result
        else
            -- Encode as JSON object
            local result = "{\n"
            local first = true

            for k, v in pairs(tbl) do
                if not first then result = result .. ",\n" end
                first = false

                result = result .. nextIndentStr .. '"' .. k .. '"'
                result = result .. ": "

                if type(v) == "table" then
                    result = result .. tableToJson(v, indent + 1, false)
                elseif type(v) == "string" then
                    result = result .. '"' .. v:gsub('"', '\\"') .. '"'
                elseif type(v) == "number" then
                    result = result .. tostring(v)
                elseif type(v) == "boolean" then
                    result = result .. (v and "true" or "false")
                else
                    result = result .. "null"
                end
            end

            result = result .. "\n" .. indentStr .. "}"
            return result
        end
    end

    return tableToJson(export)
end

-- Export as MRT format
---@param reminders table
---@return string
function ImportUtil:ExportAsMRT(reminders)
    local result = ""

    for _, reminder in ipairs(reminders) do
        local timeStr = string.format("%d:%02d", math.floor(reminder.CombatTime / 60), reminder.CombatTime % 60)
        local phase = tonumber(reminder.phase) or 1
        if phase ~= 1 then
            timeStr = timeStr .. ",p" .. phase
        end
        local who = reminder.tag and reminder.tag ~= "everyone" and reminder.tag .. " " or ""
        if reminder.spellId and reminder.spellId > 0 then
            result = result .. string.format("{time:%s} %s{spell:%d}\n", timeStr, who, reminder.spellId)
        else
            result = result .. string.format("{time:%s} %s%s\n", timeStr, who, reminder.text or reminder.name or "")
        end
    end

    return result
end

-- Export as Viserio format
---@param reminders table
---@param encounterID number
---@param encounterName string|nil
---@return string
function ImportUtil:ExportAsViserio(reminders, encounterID, encounterName)
    local result = "EncounterID:" .. tostring(encounterID)

    if encounterName and encounterName ~= "" then
        result = result .. ";Name:" .. encounterName
    end

    result = result .. "\n"

    for _, reminder in ipairs(reminders) do
        local line = ""

        local phase = reminder.phase or 1
        line = line .. "ph:" .. tostring(phase) .. ";"

        line = line .. "time:" .. tostring(reminder.CombatTime) .. ";"

        if reminder.tag and reminder.tag ~= "" then
            line = line .. "tag:" .. reminder.tag .. ";"
        else
            line = line .. "tag:everyone;"
        end

        if reminder.spellId and reminder.spellId > 0 then
            line = line .. "spellid:" .. tostring(reminder.spellId) .. ";"
        end

        if reminder.text and reminder.text ~= "" then
            line = line .. "text:" .. reminder.text .. ";"
        elseif reminder.name and reminder.name ~= "" and reminder.name ~= "Unknown" and reminder.name ~= reminder.spellName then
            line = line .. "text:" .. reminder.name .. ";"
        end

        if reminder.TTS and reminder.useTTS ~= false then
            line = line .. "TTS:" .. tostring(reminder.TTS) .. ";"
        end

        if reminder.TTSTimer then
            line = line .. "TTSTimer:" .. tostring(reminder.TTSTimer) .. ";"
        end

        if reminder.countdown then
            line = line .. "countdown:" .. tostring(reminder.countdown) .. ";"
        end

        if reminder.dur then
            line = line .. "dur:" .. tostring(reminder.dur) .. ";"
        end

        if reminder.sound then
            line = line .. "sound:" .. reminder.sound .. ";"
        end

        if reminder.glowunit then
            line = line .. "glowunit:" .. reminder.glowunit .. ";"
        end

        result = result .. line .. "\n"
    end

    return result
end

-- Export as encoded format (CBOR + compression + base64)
---@param reminders table
---@param encounterID number|nil
---@return string
function ImportUtil:ExportAsEncoded(reminders, encounterID)
    local data = {
        version = EXPORT_VERSION,
        encounterID = encounterID,
        reminders = {},
        rules = {},
    }
    for _, rule in ipairs(getRules(encounterID)) do
        local item = {}
        for _, key in ipairs(RULE_KEYS) do
            item[key] = rule[key]
        end
        table.insert(data.rules, item)
    end

    for _, reminder in ipairs(reminders) do
        local item = {}
        for _, key in ipairs(ENCODED_KEYS) do
            item[key] = reminder[key]
        end
        table.insert(data.reminders, item)
    end

    local serialized = C_EncodingUtil.SerializeCBOR(data)
    if not serialized then
        private.Debug("Failed to serialize data")
        return ""
    end

    local compressed = C_EncodingUtil.CompressString(serialized)
    if not compressed then
        private.Debug("Failed to compress data")
        return ""
    end

    local encoded = C_EncodingUtil.EncodeBase64(compressed)
    return encoded and IMPORT_PREFIX .. encoded or ""
end
