local appName, app = ...
---@class AbilityTimeline
local private = app
local SharedMedia = LibStub("LibSharedMedia-3.0")
private.sheduledReminders = {}
-- the reminders of the running encounter meant for the player and the boss mod stage they are at
local encounterReminders = {}
local currentStage

local schedule = function(delay, func)
    if delay <= 0 then
        func()
        return
    end
    table.insert(private.sheduledReminders, C_Timer.NewTimer(delay, func))
end

---@param reminder table
---@return string|nil
private.GetReminderName = function(reminder)
    local spellInfo = reminder.spellId and reminder.spellId > 0 and C_Spell.GetSpellInfo(reminder.spellId)
    return reminder.text or reminder.name or reminder.spellName or spellInfo and spellInfo.name
end

---a reminder's or boss timer rule's own color, kept unused while useColor is false
---@param item table
---@return table|nil
private.GetUsedColor = function(item)
    return item.useColor ~= false and item.color or nil
end

---a reminder's or boss timer rule's speech (true for its text or a text to speak), kept unused while useTTS is false
---@param item table
---@return boolean|string|nil
private.GetUsedTTS = function(item)
    return item.useTTS ~= false and item.TTS or nil
end

---plays a reminder's TTS and sound
---@param reminder table
local playReminderSound = function(reminder)
    local tts = private.GetUsedTTS(reminder)
    if tts then
        local text = tts == true and private.GetReminderName(reminder) or tts
        local voice, rate, volume = C_TTSSettings.GetVoiceOptionID(Enum.TtsVoiceType.Standard),
            C_TTSSettings.GetSpeechRate(), C_TTSSettings.GetSpeechVolume()
        -- the clients before 11.0 still take where the speech plays
        if Enum.VoiceTtsDestination then
            C_VoiceChat.SpeakText(voice, text, Enum.VoiceTtsDestination.LocalPlayback, rate, volume)
        else
            C_VoiceChat.SpeakText(voice, text, rate, volume, true)
        end
    end
    if reminder.sound then
        local soundFile = SharedMedia:Fetch("sound", reminder.sound, true)
        if soundFile or reminder.sound:find("[\\/]") then
            PlaySoundFile(soundFile or reminder.sound, "Master")
        end
    end
end

---adds a reminder to the timeline, its time counted from now
---@param reminder table
local addReminder = function(reminder)
    local time = tonumber(reminder.CombatTime) or 0
    local startAfter = tonumber(reminder.StartTimerAfter) or 0
    local spellId = reminder.spellId or 0
    local spellInfo = spellId > 0 and C_Spell.GetSpellInfo(spellId)
    local glowSelection
    if reminder.glowWhen == "custom" then glowSelection = reminder.glowSelection or false end
    local ownColor = private.GetUsedColor(reminder)
    local color = ownColor and CreateColor(ownColor.r, ownColor.g, ownColor.b)
    local eventinfo = {
        source = private.manager.SOURCES.Reminder,
        duration = time - startAfter,
        maxQueueDuration = tonumber(reminder.CombatTimeDelay) or 0,
        spellName = private.GetReminderName(reminder),
        spellID = spellId,
        iconFileID = reminder.iconId or spellInfo and spellInfo.iconID or 134400,
        severity = reminder.severity or 1,
        paused = false,
        icons = reminder.effectTypes,
        customColor = color,
        borderColor = color,
        allowedDisplays = reminder.displays,
        countdown = reminder.countdown,
        glow = reminder.glow,
        -- glowWhen "close" glows only below the big icon's threshold, "custom" while its timer selection matches
        glowAlways = reminder.glow ~= nil and reminder.glowWhen ~= "close" and reminder.glowWhen ~= "custom" or nil,
        glowSelection = glowSelection,
        glowColor = ownColor and { r = ownColor.r, g = ownColor.g, b = ownColor.b, a = 1 },
        countdownChanges = reminder.changes,
    }
    schedule(startAfter, function()
        private.manager.addEvent(eventinfo)
    end)
    if private.GetUsedTTS(reminder) or reminder.sound then
        local lead = tonumber(reminder.TTSTimer) or tonumber(reminder.dur) or 5
        schedule(time - lead, function()
            playReminderSound(reminder)
        end)
    end
end

local cancelTimers = function()
    for _, timerObject in ipairs(private.sheduledReminders) do
        timerObject:Cancel()
    end
    private.sheduledReminders = {}
end

---@param stage number
local addStageReminders = function(stage)
    for _, reminder in ipairs(encounterReminders) do
        if (tonumber(reminder.phase) or 1) == stage then
            addReminder(reminder)
        end
    end
end

private.createReminders = function(encounterID)
    -- the boss timer rules of Plugins/TimerRules.lua follow the same encounter
    private.activeEncounterID = encounterID
    wipe(encounterReminders)
    local reminders = private.db.profile.reminders and private.db.profile.reminders[encounterID] or {}
    for _, reminder in ipairs(reminders) do
        if private.ImportUtil:DoesTagApplyToPlayer(reminder.tag) then
            table.insert(encounterReminders, reminder)
        end
    end
    currentStage = 1
    addStageReminders(currentStage)
end

---starts the reminders of a boss mod stage, the ones of the stage before are removed
---@param stage number|nil
private.SetReminderStage = function(stage)
    stage = tonumber(stage)
    if not currentStage or not stage or stage == currentStage then return end
    currentStage = stage
    cancelTimers()
    private.manager.removeAllEvents(private.manager.SOURCES.Reminder)
    addStageReminders(stage)
end

private.PlayReminderSound = playReminderSound

private.cancelSheduledReminders = function()
    private.activeEncounterID = nil
    cancelTimers()
    currentStage = nil
end
