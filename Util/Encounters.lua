local appName, app = ...
---@class AbilityTimeline
local private = app

-- the encounters of the game type from Data/Encounters, named in the client's language where the Adventure Guide has
-- them (retail and Mists), else in English

---@param dungeonEncounterID number
---@return table|nil -- name, instanceName, journalEncounterID, journalInstanceID; nil for encounters not in the data
private.GetEncounterInfo = function(dungeonEncounterID)
    local encounter = private.Encounters and private.Encounters[tonumber(dungeonEncounterID)]
    if not encounter then return end
    local instance = private.EncounterInstances[encounter.map] or {}
    local name = encounter.journalEncounterID and EJ_GetEncounterInfo and EJ_GetEncounterInfo(encounter.journalEncounterID)
    local instanceName = instance.journalInstanceID and EJ_GetInstanceInfo and EJ_GetInstanceInfo(instance.journalInstanceID)
    return {
        name = name or encounter.name,
        instanceName = instanceName or instance.name,
        journalEncounterID = encounter.journalEncounterID,
        journalInstanceID = encounter.journalEncounterID and instance.journalInstanceID,
    }
end

---@param map number
---@return string|nil
private.GetEncounterInstanceName = function(map)
    local instance = private.EncounterInstances and private.EncounterInstances[map]
    if not instance then return end
    return instance.journalInstanceID and EJ_GetInstanceInfo and EJ_GetInstanceInfo(instance.journalInstanceID)
        or instance.name
end

private.Difficulties = { "normal", "heroic", "mythic" }

---@param difficultyID number
---@return string
private.GetDifficultyKey = function(difficultyID)
    if not GetDifficultyInfo or not difficultyID then return "normal" end
    local _, _, isHeroic, isChallengeMode, displayHeroic, displayMythic = GetDifficultyInfo(difficultyID)
    if displayMythic or isChallengeMode then return "mythic" end
    if isHeroic or displayHeroic then return "heroic" end
    return "normal"
end

---@param text string|nil
---@return string|nil
private.GetDifficultyFromText = function(text)
    if type(text) ~= "string" then return end
    local key = strtrim(text):lower()
    for _, difficulty in ipairs(private.Difficulties) do
        if key == difficulty then return key end
    end
end

---@param encounterID number
---@param difficulty string
---@return table[]
private.GetReminders = function(encounterID, difficulty)
    local stored = private.db.profile.difficultyReminders[encounterID]
    return stored and stored[difficulty] or private.db.profile.reminders[encounterID] or {}
end

---@param encounterID number
---@param difficulty string
---@param reminders table[]
private.SetReminders = function(encounterID, difficulty, reminders)
    local stored = private.db.profile.difficultyReminders
    stored[encounterID] = stored[encounterID] or {}
    stored[encounterID][difficulty] = reminders
end

---@param encounterID number
---@return boolean
---@return table|nil -- first reminder for the encounter's saved name
private.HasReminders = function(encounterID)
    for _, difficulty in ipairs(private.Difficulties) do
        local reminders = private.GetReminders(encounterID, difficulty)
        if #reminders > 0 then return true, reminders[1] end
    end
    return false
end

---removes the reminders and boss timer changes of an encounter
---@param dungeonEncounterID number
private.DeleteEncounterChanges = function(dungeonEncounterID)
    private.db.profile.reminders[dungeonEncounterID] = nil
    private.db.profile.difficultyReminders[dungeonEncounterID] = nil
    if private.db.profile.timerRules then
        private.db.profile.timerRules[dungeonEncounterID] = nil
    end
end
