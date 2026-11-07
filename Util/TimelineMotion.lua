local appName, app = ...
---@class AbilityTimeline
local private = app
local ThemeApply = private.ThemeApply

local animation = function(group, kind, target, duration, order, smoothing)
    local anim = group:CreateAnimation(kind)
    anim:SetTarget(target)
    anim:SetDuration(duration)
    anim:SetOrder(order or 1)
    if smoothing then anim:SetSmoothing(smoothing) end
    return anim
end

local scale = function(group, target, duration, from, to, order, smoothing)
    local anim = animation(group, "Scale", target, duration, order, smoothing)
    anim:SetOrigin("CENTER", 0, 0)
    anim:SetScaleFrom(from, from)
    anim:SetScaleTo(to, to)
    return anim
end

local alpha = function(group, target, duration, from, to, order, smoothing)
    local anim = animation(group, "Alpha", target, duration, order, smoothing)
    anim:SetFromAlpha(from)
    anim:SetToAlpha(to)
    return anim
end

ThemeApply.StopTimelineMotion = function(frame)
    local motion = frame.timelineMotion
    if not motion then return end
    for _, group in ipairs(motion.groups) do group:Stop() end
    motion.Container:SetScale(1)
    for region, parent in pairs(motion.parents) do region:SetParent(parent) end
    wipe(motion.parents)
    motion.Container:Hide()
    motion.Labels:Hide()
    motion.Markers:Hide()
    motion.layerLevel = nil
    motion.spec, motion.urgent, motion.lastRemaining = nil, nil, nil
    motion.state, motion.pauseVisible, motion.pauseHiding = nil, nil, nil
    motion.queueVisible, motion.queueHiding = nil, nil
    motion.introUntil, motion.introRemaining = nil, nil
    if frame.Cooldown then frame.Cooldown:SetAlpha(1) end
end

ThemeApply.ConfigureTimelineMotion = function(frame, style)
    local spec = not frame.atIconSkinned and style.TimelineMotion
    if not spec and not frame.timelineMotion then return end
    ThemeApply.StopTimelineMotion(frame)
    local motion = frame.timelineMotion
    if not spec then return end
    if not motion then
        motion = { groups = {}, parents = {} }
        frame.timelineMotion = motion
        motion.Container = CreateFrame("Frame", nil, frame)
        motion.Container:SetAllPoints(frame)
        motion.Labels = CreateFrame("Frame", nil, frame)
        motion.Labels:SetAllPoints(frame)
        motion.Markers = CreateFrame("Frame", nil, motion.Container)
        motion.Markers:SetAllPoints(frame)
        motion.Glow = motion.Container:CreateTexture(nil, "OVERLAY", nil, 2)
        motion.Glow:SetPoint("TOPLEFT", frame.SpellIcon, "TOPLEFT", -8, 7)
        motion.Glow:SetPoint("BOTTOMRIGHT", frame.SpellIcon, "BOTTOMRIGHT", 8, -8)
        motion.Swirl = motion.Container:CreateTexture(nil, "OVERLAY", nil, 3)
        motion.Swirl:SetPoint("CENTER", frame.SpellIcon, "CENTER")
        motion.Swirl:SetSize(108, 108)
        motion.Mask = motion.Container:CreateMaskTexture()
        motion.Mask:SetPoint("TOPLEFT", frame.SpellIcon, "TOPLEFT", -1, 1)
        motion.Mask:SetPoint("BOTTOMRIGHT", frame.SpellIcon, "BOTTOMRIGHT", 1, -1)
        motion.Swirl:AddMaskTexture(motion.Mask)
        local group = motion.Container:CreateAnimationGroup()
        group:SetLooping("REPEAT")
        scale(group, motion.Container, spec.Pulse.Time, 1, spec.Pulse.Grow, 1, "IN")
        scale(group, motion.Container, spec.Pulse.Time, 1, spec.Pulse.Shrink, 2, "OUT"):SetEndDelay(spec.Pulse.Delay)
        motion.Pulse = group
        table.insert(motion.groups, group)
        group = motion.Container:CreateAnimationGroup()
        group:SetToFinalAlpha(true)
        local rotation = animation(group, "Rotation", motion.Swirl, 0.6, 1, "OUT")
        rotation:SetDegrees(-180)
        rotation:SetOrigin("CENTER", 0, 0)
        alpha(group, motion.Swirl, 0.2, 1, 0, 1, "OUT"):SetStartDelay(0.4)
        alpha(group, motion.Glow, 0.2, 0, 0.7, 1, "IN")
        alpha(group, motion.Glow, 0.2, 0.7, 0, 2, "OUT")
        motion.Highlight = group
        table.insert(motion.groups, group)
        motion.Intro = frame:CreateAnimationGroup()
        motion.IntroFrom = animation(motion.Intro, "Translation", frame, 0, 1)
        motion.IntroTo = animation(motion.Intro, "Translation", frame, spec.SlideTime, 2)
        table.insert(motion.groups, motion.Intro)
        for _, key in ipairs({ "PauseShow", "PauseHide" }) do
            group = frame.StateBadge:CreateAnimationGroup()
            scale(group, frame.StateBadge, 0.25, 1, 1.1, 1, "IN_OUT")
            scale(group, frame.StateBadge, 0.25, 1.1, 1, 1, "IN_OUT"):SetStartDelay(0.25)
            motion[key] = group
            table.insert(motion.groups, group)
        end
        motion.PauseHide:SetScript("OnFinished", function()
            motion.pauseVisible, motion.pauseHiding = false, false
        end)
        motion.Dots = {}
        for index = 1, 3 do
            local dot = motion.Markers:CreateTexture(nil, "OVERLAY", nil, 7)
            dot:SetSize(10, 10)
            dot:SetPoint("BOTTOM", frame.SpellIcon, "BOTTOM", (index - 2) * 10, 4)
            motion.Dots[index] = dot
            for _, key in ipairs({ "ShowMotion", "HideMotion" }) do
                group = dot:CreateAnimationGroup()
                local delay = (index - 1) * 0.2
                local up = animation(group, "Translation", dot, 0.2, 1, "OUT")
                up:SetOffset(0, 10)
                up:SetStartDelay(delay)
                local down = animation(group, "Translation", dot, 0.3, 1)
                down:SetOffset(0, -10)
                down:SetStartDelay(delay + 0.2)
                dot[key] = group
                table.insert(motion.groups, group)
            end
        end
        motion.Dots[3].HideMotion:SetScript("OnFinished", function()
            motion.queueVisible, motion.queueHiding = false, false
        end)
        frame:HookScript("OnHide", function()
            for _, group in ipairs(motion.groups) do group:Stop() end
            motion.Container:SetScale(1)
            motion.Glow:SetAlpha(0)
            motion.Swirl:SetAlpha(0)
            motion.urgent, motion.lastRemaining = nil, nil
            motion.pauseVisible, motion.pauseHiding = nil, nil
            motion.queueVisible, motion.queueHiding = nil, nil
            frame.StateBadge:Hide()
            for _, dot in ipairs(motion.Dots) do dot:Hide() end
        end)
    end
    motion.spec = spec
    ThemeApply.TimelineMotionLayers(frame)
    local move = function(region, parent)
        if region then
            motion.parents[region] = region:GetParent()
            region:SetParent(parent)
        end
    end
    for _, key in ipairs({ "SpellIcon", "IconMask", "IconOverlay", "IconShade", "IconGlow",
        "StateOverlay" }) do
        move(frame[key], motion.Container)
    end
    move(frame.StateBadge, motion.Markers)
    for _, key in ipairs({ "MergeSlices", "MergeSeparators", "BossModsBorderEdges", "BorderGlows" }) do
        for _, region in ipairs(frame[key] or {}) do move(region, motion.Container) end
    end
    for _, edges in ipairs(frame.DispellTypeBorderEdges or {}) do
        for _, region in ipairs(edges) do move(region, motion.Container) end
    end
    move(frame.SpellName, motion.Labels)
    move(frame.Cooldown, motion.Labels)
    for _, key in ipairs({ "RoleIcons", "dispellTypeIcons", "DangerIcon" }) do
        for _, region in ipairs(frame[key] or {}) do move(region, motion.Labels) end
    end
    ThemeApply.Texture(motion.Glow, spec.Highlight.Glow)
    ThemeApply.Texture(motion.Swirl, spec.Highlight.Swirl)
    ThemeApply.Mask(motion.Mask, spec.Highlight.Mask)
    motion.Glow:SetAlpha(0)
    motion.Swirl:SetAlpha(0)
    for _, dot in ipairs(motion.Dots) do
        ThemeApply.Texture(dot, spec.QueuedDot)
        dot:Hide()
    end
    motion.Container:Show()
    motion.Labels:Show()
    motion.Markers:Show()
end

---state markers draw over type badges, while both remain inside the icon's level range
ThemeApply.TimelineMotionLayers = function(frame)
    local motion = frame.timelineMotion
    local level = frame:GetFrameLevel()
    if motion.layerLevel == level then return end
    motion.Container:SetFrameLevel(level + 1)
    motion.Labels:SetFrameLevel(level + 2)
    motion.Markers:SetFrameLevel(level + 3)
    motion.layerLevel = level
end

ThemeApply.EnterTimelineMotion = function(frame, previewRemaining)
    local motion = frame.timelineMotion
    if not motion or not motion.spec or not private.AmbientEffectsEnabled() then return end
    local info = frame.eventInfo
    local remaining = previewRemaining or (info and info.id and private.manager.getEventRemainingTime(info.id))
    if not remaining or remaining >= private.db.profile.timeline_settings.threshold_time or
        (not previewRemaining and private.manager.getEventState(info.id) ~= private.manager.STATES.Active) then return end
    local _, horizontal = private.TimelineFrame.GetArrivalPoint()
    local distance = motion.spec.SlideDistance
    local x, y = horizontal and 0 or distance, horizontal and distance or 0
    motion.Intro:Stop()
    motion.IntroFrom:SetOffset(x, y)
    motion.IntroTo:SetOffset(-x, -y)
    motion.introUntil = GetTime() + motion.spec.SlideTime
    motion.introRemaining = math.max(remaining - motion.spec.SlideTime, 0)
    motion.Intro:Play()
end

ThemeApply.UpdateTimelineMotion = function(frame, state, remaining, positionRemaining, zone)
    local motion = frame.timelineMotion
    if not motion or not motion.spec then return end
    local full = private.AmbientEffectsEnabled()
    local track = private.GetElementStyle("Timeline").Track
    local pipTime = track and track.PipTime or 5
    local moving = zone == private.TIMELINE_ZONES.MOVING
    ThemeApply.TimelineMotionLayers(frame)
    if moving and motion.introUntil and GetTime() < motion.introUntil then
        positionRemaining = math.min(positionRemaining, motion.introRemaining)
    end
    local waiting = zone == private.TIMELINE_ZONES.WAITING
    motion.Container:SetAlpha(waiting and 0.6 or 1)
    frame.Cooldown:SetAlpha(waiting and 0.6 or 1)
    local urgent = full and frame:IsShown() and moving and state == private.manager.STATES.Active and remaining > 0 and remaining <= pipTime
    if urgent ~= motion.urgent then
        motion.Pulse:Stop()
        if urgent then motion.Pulse:Play() end
        motion.urgent = urgent
    end
    if urgent and (not motion.lastRemaining or motion.lastRemaining > pipTime) then
        motion.Highlight:Stop()
        motion.Swirl:SetAlpha(1)
        motion.Highlight:Play()
    end
    motion.lastRemaining = remaining
    if not full then
        motion.Highlight:Stop()
        motion.Intro:Stop()
        motion.Glow:SetAlpha(0)
        motion.Swirl:SetAlpha(0)
    end
    local paused, queued = state == private.manager.STATES.Paused, state == private.manager.STATES.Queued
    if paused then
        if not motion.pauseVisible or motion.pauseHiding then
            motion.PauseHide:Stop()
            motion.PauseShow:Play()
        end
        motion.pauseVisible, motion.pauseHiding = true, false
        motion.queueVisible, motion.queueHiding = false, false
        for _, dot in ipairs(motion.Dots) do dot.ShowMotion:Stop(); dot.HideMotion:Stop() end
    elseif motion.pauseVisible and not motion.pauseHiding then
        motion.PauseShow:Stop()
        motion.PauseHide:Play()
        motion.pauseHiding = true
    end
    if not paused and not motion.pauseVisible then
        if queued and (not motion.queueVisible or motion.queueHiding) then
            for _, dot in ipairs(motion.Dots) do dot.HideMotion:Stop(); dot.ShowMotion:Play() end
            motion.queueVisible, motion.queueHiding = true, false
        elseif not queued and motion.queueVisible and not motion.queueHiding then
            for _, dot in ipairs(motion.Dots) do dot.ShowMotion:Stop(); dot.HideMotion:Play() end
            motion.queueHiding = true
        end
    end
    if not full then
        motion.pauseVisible, motion.pauseHiding = paused, false
        motion.queueVisible, motion.queueHiding = queued and not paused, false
        motion.PauseShow:Stop(); motion.PauseHide:Stop()
        for _, dot in ipairs(motion.Dots) do dot.ShowMotion:Stop(); dot.HideMotion:Stop() end
    end
    frame.StateBadge:SetShown(motion.pauseVisible and true or false)
    for _, dot in ipairs(motion.Dots) do dot:SetShown(motion.queueVisible and true or false) end
    if motion.pauseVisible then ThemeApply.Texture(frame.StateBadge, frame.atStateArt.PausedIcon) end
    local overlay = motion.pauseVisible and frame.atStateArt.Paused or
        motion.queueVisible and frame.atStateArt.Queued
    frame.StateOverlay:SetShown(ThemeApply.Texture(frame.StateOverlay, overlay))
    frame.IconOverlay:SetShown(not motion.queueVisible)
    return positionRemaining
end
