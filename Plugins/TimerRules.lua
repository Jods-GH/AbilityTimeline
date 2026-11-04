local appName, app = ...
---@class AbilityTimeline
local private = app
local issecretvalue = issecretvalue or function() return false end

-- boss timer rules: a BigWigs or DBM bar of the running encounter matched by its spell ID or a part of its text gets
-- another name, color, glow, displays, countdown, speech or sound. Saved per encounter in
-- private.db.profile.timerRules, edited on the Boss timers tab of the timings editor

---the rule of the running encounter that matches a bar
---@param spellId number|string|nil -- BigWigs gives option keys that are no spell ID as well
---@param text string|nil
---@return table|nil
private.GetTimerRule = function(spellId, text)
    local encounterID = private.activeEncounterID
    local rules = encounterID and private.db.profile.timerRules and private.db.profile.timerRules[encounterID]
    if not rules then return end
    spellId = not issecretvalue(spellId) and tonumber(spellId) or nil
    text = not issecretvalue(text) and type(text) == "string" and text:lower() or nil
    for _, rule in ipairs(rules) do
        local value = rule.value or ""
        if rule.match == "text" then
            if text and value ~= "" and text:find(value:lower(), 1, true) then
                return rule
            end
        elseif spellId and tonumber(value) == spellId then
            return rule
        end
    end
end

---how an event of a bar the rule matches differs, the keys of manager.addEvent's event info
---@param rule table
---@return table
private.GetTimerRuleOverrides = function(rule)
    local ownColor = private.GetUsedColor(rule)
    local color = ownColor and CreateColor(ownColor.r, ownColor.g, ownColor.b)
    return {
        spellName = rule.name ~= "" and rule.name or nil,
        textColor = color,
        borderColor = color,
        allowedDisplays = rule.displays,
        countdown = rule.countdown,
        glow = rule.glow,
        glowColor = ownColor and { r = ownColor.r, g = ownColor.g, b = ownColor.b, a = 1 },
        -- glowWhen "close" glows only below the big icon's threshold
        glowAlways = rule.glow ~= nil and rule.glowWhen ~= "close" or nil,
    }
end

---plays the rule's speech and sound before the bar ends, unless the bar is gone by then
---@param rule table
---@param duration number
---@param eventID number
---@param text string|nil -- the bar's text, spoken when the rule speaks without its own text or name
private.ScheduleTimerRuleSound = function(rule, duration, eventID, text)
    local tts = private.GetUsedTTS(rule)
    if not (tts or rule.sound) or issecretvalue(duration) then return end
    local lead = tonumber(rule.TTSTimer) or 5
    local spoken = tts == true and (rule.name ~= "" and rule.name or text) or tts
    C_Timer.After(math.max(duration - lead, 0), function()
        if private.manager.getEventInfo(eventID) then
            private.PlayReminderSound({ TTS = spoken, sound = rule.sound })
        end
    end)
end
