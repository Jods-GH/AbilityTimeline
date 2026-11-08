local appName, app = ...
---@class AbilityTimeline
local private = app
local ThemeApply = private.ThemeApply

local layoutHop = function(frame)
    local markers = frame.queuedMarkers
    local spec = markers.spec
    local height = (spec.Enter.Hop or 10) * frame:GetWidth() / (spec.ReferenceSize or 44)
    for _, dot in ipairs(markers.Dots) do
        for _, group in ipairs({ dot.ShowMotion, dot.HideMotion }) do
            group.Up:SetOffset(0, height)
            group.Down:SetOffset(0, -height)
        end
    end
end

-- Theme-owned sprites and motion, shared lifetime for pooled timeline icons.
local layout = function(frame, progress, entering, full)
    local markers = frame.queuedMarkers
    local spec = markers.spec
    if not spec then return end
    local motion = spec.Enter
    local factor = frame:GetWidth() / (spec.ReferenceSize or 44)
    local duration = full and motion.Time or 0.12
    local stagger = full and motion.Stagger or 0
    local elapsed = progress * (duration + stagger * 2)
    for index, dot in ipairs(markers.Dots) do
        local phase = progress >= 1 and 1 or math.max(0, math.min(1, (elapsed - (index - 1) * stagger) / duration))
        local visible = entering and phase or 1 - phase
        local offset = full and (1 - visible) or 0
        local size = spec.Size * factor * (1 - (full and motion.Grow or 0) * (1 - visible))
        dot:ClearAllPoints()
        dot:SetPoint("BOTTOM", frame.SpellIcon, "BOTTOM",
            ((index - 2) * spec.Spacing + offset * (motion.X or 0)) * factor,
            (spec.Offset + offset * (motion.Y or 0)) * factor)
        dot:SetSize(size, size)
        dot:SetRotation((spec.Rotation or 0) + (full and (motion.Rotation or 0) * (1 - visible) or 0))
        dot:SetAlpha(full and motion.Fade == false and 1 or visible)
    end
    markers.progress, markers.entering, markers.full = progress, entering, full
end

ThemeApply.ResetQueuedMarkers = function(frame)
    local markers = frame.queuedMarkers
    if not markers then return end
    private.StopTween(markers)
    for _, dot in ipairs(markers.Dots) do
        dot.ShowMotion:Stop()
        dot.HideMotion:Stop()
    end
    markers.queued = false
    markers:Hide()
end

ThemeApply.ConfigureQueuedMarkers = function(frame, spec)
    ThemeApply.ResetQueuedMarkers(frame)
    local markers = frame.queuedMarkers
    if not markers and not spec then return end
    if not markers then
        markers = CreateFrame("Frame", nil, frame)
        frame.queuedMarkers = markers
        markers:SetAllPoints(frame)
        markers.Dots = {}
        for index = 1, 3 do
            local dot = markers:CreateTexture(nil, "OVERLAY", nil, 7)
            markers.Dots[index] = dot
            for _, key in ipairs({ "ShowMotion", "HideMotion" }) do
                local group = dot:CreateAnimationGroup()
                local delay = (index - 1) * 0.2
                local up = group:CreateAnimation("Translation")
                up:SetTarget(dot)
                up:SetDuration(0.2)
                up:SetOrder(1)
                up:SetSmoothing("OUT")
                up:SetStartDelay(delay)
                local down = group:CreateAnimation("Translation")
                down:SetTarget(dot)
                down:SetDuration(0.3)
                down:SetOrder(1)
                down:SetStartDelay(delay + 0.2)
                group.Up, group.Down = up, down
                dot[key] = group
            end
        end
        frame:HookScript("OnHide", ThemeApply.ResetQueuedMarkers)
        frame:HookScript("OnSizeChanged", function()
            if markers.spec then
                layout(frame, markers.progress or 1, markers.entering, markers.full)
                layoutHop(frame)
            end
        end)
    end
    markers.spec = spec
    if not spec then return end
    for index, dot in ipairs(markers.Dots) do
        ThemeApply.Texture(dot, spec.Art)
        dot:SetBlendMode(spec.Art.BlendMode or "BLEND")
        dot:SetVertexColor(ThemeApply.Color(spec.Colors[index]))
    end
end

ThemeApply.UpdateQueuedMarkers = function(frame, state, blocked)
    local markers = frame.queuedMarkers
    if not markers or not markers.spec then return end
    markers:SetFrameLevel(frame:GetFrameLevel() + 3)
    if blocked or not frame:IsShown() or state == private.manager.STATES.Paused or
        (state ~= private.manager.STATES.Queued and state ~= private.manager.STATES.Active) then
        ThemeApply.ResetQueuedMarkers(frame)
        return
    end
    local queued = state == private.manager.STATES.Queued
    if markers.queued == queued then return end
    markers.queued = queued
    markers:Show()
    local full = private.GetAnimationLevel() == private.ANIMATION_LEVELS.FULL
    local motion = markers.spec.Enter
    local duration = full and motion.Time + motion.Stagger * 2 or 0.12
    layoutHop(frame)
    for _, dot in ipairs(markers.Dots) do
        dot.ShowMotion:Stop()
        dot.HideMotion:Stop()
        if full then
            local group = queued and dot.ShowMotion or dot.HideMotion
            group:Play()
        end
    end
    if full then duration = math.max(duration, 0.9) end
    private.Tween(markers, 0, 1, duration, "linear", function(progress)
        layout(frame, progress, queued, full)
    end, function()
        if not queued then markers:Hide() end
    end)
end
