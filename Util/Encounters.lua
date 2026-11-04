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

---removes the reminders and boss timer changes of an encounter
---@param dungeonEncounterID number
private.DeleteEncounterChanges = function(dungeonEncounterID)
    private.db.profile.reminders[dungeonEncounterID] = nil
    if private.db.profile.timerRules then
        private.db.profile.timerRules[dungeonEncounterID] = nil
    end
end
