local appName, app = ...
---@class AbilityTimeline
local private = app
local CustomGlow = LibStub("LibCustomGlow-1.0")

---@class GlowType
private.GlowTypes = {
    PROC = "PROC",
    PIXEL = "PIXEL",
    AUTOCAST = "AUTOCAST",
    BUTTON = "BUTTON",
}
local optionKeys = { "lines", "frequency", "length", "thickness", "scale", "xOffset", "yOffset", "border", "startAnim", "duration" }
local noOptions = {}

local function sameOptions(a, b)
    a, b = a or noOptions, b or noOptions
    for _, key in ipairs(optionKeys) do if a[key] ~= b[key] then return false end end
    return true
end

---Enables a glow on a frame for a given duration
---@param frame frame
---@param glowType GlowType
---@param duration number|nil -- nil keeps a paused timer's glow until it changes or is released
---@param glowColor colorRGBA?
---@param options table? LibCustomGlow parameters of the glow type, see optionKeys; missing ones use the library defaults
private.EnableGlow = function(frame, glowType, duration, glowColor, options)
    if frame.isGlowing and (frame.glowType ~= glowType or not sameOptions(frame.glowOptions, options) or glowColor and not frame.glowColor or frame.glowColor and not glowColor or
            (frame.glowColor and glowColor and
                (frame.glowColor.r ~= glowColor.r or
                    frame.glowColor.g ~= glowColor.g or
                    frame.glowColor.b ~= glowColor.b or
                    frame.glowColor.a ~= glowColor.a))) then
        private.StopGlow(frame)
    elseif frame.isGlowing then
        local expires = duration and GetTime() + duration or nil
        if expires ~= frame.glowExpires and (not expires or not frame.glowExpires or math.abs(expires - frame.glowExpires) > 0.1) then
            if frame.glowTimer then frame.glowTimer:Cancel() end
            frame.glowExpires = expires
            frame.glowTimer = duration and C_Timer.NewTimer(duration, function() private.StopGlow(frame) end) or nil
        end
        return
    end
    local modifiedGlowColor = nil
    frame.glowColor = glowColor
    if glowColor then
        modifiedGlowColor = { glowColor.r, glowColor.g, glowColor.b, glowColor.a }
    end
    local o = options or noOptions
    frame.glowOptions = options and CopyTable(options) or nil
    if glowType == private.GlowTypes.PROC then
        CustomGlow.ProcGlow_Start(frame, { color = modifiedGlowColor, startAnim = o.startAnim, duration = o.duration, xOffset = o.xOffset, yOffset = o.yOffset })
    elseif glowType == private.GlowTypes.PIXEL then
        CustomGlow.PixelGlow_Start(frame, modifiedGlowColor, o.lines, o.frequency, o.length, o.thickness, o.xOffset, o.yOffset, o.border)
    elseif glowType == private.GlowTypes.AUTOCAST then
        CustomGlow.AutoCastGlow_Start(frame, modifiedGlowColor, o.lines, o.frequency, o.scale, o.xOffset, o.yOffset)
    elseif glowType == private.GlowTypes.BUTTON then
        CustomGlow.ButtonGlow_Start(frame, modifiedGlowColor, o.frequency)
    end
    frame.isGlowing = true
    frame.glowType = glowType
    frame.glowExpires = duration and GetTime() + duration or nil
    frame.glowTimer = duration and C_Timer.NewTimer(duration, function() private.StopGlow(frame) end) or nil
end

---Stops a glow (if present) on a frame
---@param frame frame
private.StopGlow = function(frame)
    if frame.glowTimer then frame.glowTimer:Cancel(); frame.glowTimer = nil end
    frame.glowExpires = nil
    if not frame.isGlowing then
        return
    end
    if frame.glowType == private.GlowTypes.PROC then
        CustomGlow.ProcGlow_Stop(frame)
    elseif frame.glowType == private.GlowTypes.PIXEL then
        CustomGlow.PixelGlow_Stop(frame)
    elseif frame.glowType == private.GlowTypes.AUTOCAST then
        CustomGlow.AutoCastGlow_Stop(frame)
    elseif frame.glowType == private.GlowTypes.BUTTON then
        CustomGlow.ButtonGlow_Stop(frame)
    end
    frame.isGlowing = false
    frame.glowType = nil
    frame.glowColor = nil
    frame.glowOptions = nil
end
