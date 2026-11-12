local appName, app = ...
---@class AbilityTimeline
local private = app

-- one tween per key, all driven by a single OnUpdate that only runs while something tweens
local EASES = {
    linear = function(t) return t end,
    outCubic = function(t) return 1 - (1 - t) ^ 3 end,
    inCubic = function(t) return t ^ 3 end,
    inOutSine = function(t) return -(math.cos(math.pi * t) - 1) / 2 end,
    outBack = function(t)
        local s = 1.70158
        return 1 + (s + 1) * (t - 1) ^ 3 + s * (t - 1) ^ 2
    end,
}

private.ANIMATION_LEVELS = {
    FULL = "FULL",
    DIMMED = "DIMMED",
    OFF = "OFF",
}

local tweens = {}
local finished = {}
local driver = CreateFrame("Frame")
driver:Hide()
driver:SetScript("OnUpdate", function(_, elapsed)
    for key, tween in pairs(tweens) do
        tween.elapsed = tween.elapsed + elapsed
        local progress = math.min(tween.elapsed / tween.time, 1)
        tween.onUpdate(tween.from + (tween.to - tween.from) * tween.ease(progress))
        if progress >= 1 and tweens[key] == tween then
            tweens[key] = nil
            table.insert(finished, tween)
        end
    end
    for i, tween in ipairs(finished) do
        finished[i] = nil
        if tween.onDone then
            tween.onDone()
        end
    end
    if not next(tweens) then
        driver:Hide()
    end
end)

---@return string
private.GetAnimationLevel = function()
    return private.GetThemeSettings().animations or private.ANIMATION_LEVELS.FULL
end

---@param level string -- one of private.ANIMATION_LEVELS
private.SetAnimationLevel = function(level)
    private.GetThemeSettings().animations = level
    private.RefreshTheme()
end

---whether ambient effects (particles, breathing glows) run: the theme has them and the animation level is full
---@return boolean
private.AmbientEffectsEnabled = function()
    return private.GetCurrentTheme().Effects and private.GetAnimationLevel() == private.ANIMATION_LEVELS.FULL or false
end

---reads a duration and an ease of the current theme's Motion
---@param name string
---@return number, string
private.GetMotion = function(name)
    local motion = private.GetCurrentTheme().Motion or {}
    return motion.Time and motion.Time[name] or 0.2, motion.Ease and motion.Ease[name] or "outCubic"
end

---tweens a value from from to to, replacing the running tween of key, without animations it jumps to the end
---@param key any
---@param from number
---@param to number
---@param time number
---@param ease string
---@param onUpdate fun(value: number)
---@param onDone function|nil
private.Tween = function(key, from, to, time, ease, onUpdate, onDone)
    tweens[key] = nil
    if time <= 0 or private.GetAnimationLevel() == private.ANIMATION_LEVELS.OFF then
        onUpdate(to)
        if onDone then
            onDone()
        end
        return
    end
    tweens[key] = {
        from = from,
        to = to,
        time = time,
        elapsed = 0,
        ease = EASES[ease] or EASES.outCubic,
        onUpdate = onUpdate,
        onDone = onDone,
    }
    onUpdate(from)
    driver:Show()
end

---tweens a theme Motion value by name, see private.Tween
---@param key any
---@param motion string
---@param from number
---@param to number
---@param onUpdate fun(value: number)
---@param onDone function|nil
private.TweenMotion = function(key, motion, from, to, onUpdate, onDone)
    local time, ease = private.GetMotion(motion)
    private.Tween(key, from, to, time, ease, onUpdate, onDone)
end

---@param key any
private.StopTween = function(key)
    tweens[key] = nil
end
