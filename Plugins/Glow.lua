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
---Enables a glow on a frame for a given duration
---@param frame frame
---@param glowType GlowType
---@param duration number
---@param glowColor colorRGBA?
private.EnableGlow = function(frame, glowType, duration, glowColor)
    if frame.isGlowing and (frame.glowType ~= glowType or glowColor and not frame.glowColor or
            (frame.glowColor and glowColor and
                (frame.glowColor.r ~= glowColor.r or
                    frame.glowColor.g ~= glowColor.g or
                    frame.glowColor.b ~= glowColor.b or
                    frame.glowColor.a ~= glowColor.a))) then
        private.StopGlow(frame)
    elseif frame.isGlowing then
        return
    end
    local modifiedGlowColor = nil
    frame.glowColor = glowColor
    if glowColor then
        modifiedGlowColor = { glowColor.r, glowColor.g, glowColor.b, glowColor.a }
    end
    if glowType == private.GlowTypes.PROC then
        CustomGlow.ProcGlow_Start(frame, { color = modifiedGlowColor })
    elseif glowType == private.GlowTypes.PIXEL then
        CustomGlow.PixelGlow_Start(frame, modifiedGlowColor)
    elseif glowType == private.GlowTypes.AUTOCAST then
        CustomGlow.AutoCastGlow_Start(frame, modifiedGlowColor)
    elseif glowType == private.GlowTypes.BUTTON then
        CustomGlow.ButtonGlow_Start(frame, modifiedGlowColor)
    end
    frame.isGlowing = true
    frame.glowType = glowType
    C_Timer.After(duration, function()
        private.StopGlow(frame)
    end)
end

---Stops a glow (if present) on a frame
---@param frame frame
private.StopGlow = function(frame)
    if frame.isGlowing == private.GlowTypes.PROC then
        CustomGlow.ProcGlow_Stop(frame)
    elseif frame.isGlowing == private.GlowTypes.PIXEL then
        CustomGlow.PixelGlow_Stop(frame)
    elseif frame.isGlowing == private.GlowTypes.AUTOCAST then
        CustomGlow.AutoCastGlow_Stop(frame)
    elseif frame.isGlowing == private.GlowTypes.BUTTON then
        CustomGlow.ButtonGlow_Stop(frame)
    end
    frame.isGlowing = false
    frame.glowType = nil
    frame.glowColor = nil
end
