local addonName, private = ...


private.createReminders = function(encounterID)
    local reminders = private.db.profile.reminders and private.db.profile.reminders[encounterID] or {}
    table.sort(reminders, function(a, b)
        return (a.CombatTime or 0) < (b.CombatTime or 0)
    end)

    for _, reminder in ipairs(reminders) do
        local duration = tonumber(reminder.CombatTime) or 0
        local delay = tonumber(reminder.CombatTimeDelay) or 0
        local spellId = reminder.spellId or 0
        local spellName, _, icon = C_Spell.GetSpellInfo(spellId)
        local eventinfo = {
            duration = duration,
            maxQueueDuration = duration + delay,
            overrideName = reminder.name or reminder.spellName or spellName,
            spellID = spellId,
            iconFileID = reminder.iconId or icon or 134400,
            severity = reminder.severity or 1,
            paused = false,
            icons = reminder.icons,
        }

        C_EncounterTimeline.AddScriptEvent(eventinfo)
    end
end