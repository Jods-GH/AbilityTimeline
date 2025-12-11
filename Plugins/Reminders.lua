local addonName, private = ...


private.createReminders = function(encounterID)
    local reminders = private.db.profile.reminders and private.db.profile.reminders[encounterID] or {}
    for _, reminder in ipairs(reminders) do

        local eventinfo = {
            duration = reminder.CombatTime,
            maxQueueDuration = reminder.CombatTime + reminder.CombatTimeDelay,
            overrideName = reminder.spellName,
            spellID = reminder.spellId,
            iconFileID = reminder.iconId,
            severity = reminder.severity,
            paused = false,
            icons = reminder.icons
        }


        local eventId = C_EncounterTimeline.AddScriptEvent(eventinfo)
    end
end