local appName, app = ...
---@class AbilityTimeline
local private = app
local ThemeApply = private.ThemeApply
local TRACK_BACKGROUND = "Blizzard Timeline"

do
    local behavior = {}
    local setMask = ThemeApply.SetTransitionMask

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

    behavior.StopTimelineMotion = function(frame)
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
        motion.introUntil, motion.introRemaining = nil, nil
        if frame.Cooldown then frame.Cooldown:SetAlpha(1) end
    end

    behavior.ConfigureTimelineMotion = function(frame, style)
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
            -- above the dispel and boss mod borders, which take OVERLAY 6 and below
            motion.Glow = motion.Container:CreateTexture(nil, "OVERLAY", nil, 7)
            motion.Swirl = motion.Container:CreateTexture(nil, "OVERLAY", nil, 3)
            motion.Swirl:SetPoint("CENTER", frame.SpellIcon, "CENTER")
            motion.Mask = motion.Container:CreateMaskTexture()
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
            frame:HookScript("OnHide", function()
                for _, group in ipairs(motion.groups) do group:Stop() end
                motion.Container:SetScale(1)
                motion.Glow:SetAlpha(0)
                motion.Swirl:SetAlpha(0)
                motion.urgent, motion.lastRemaining = nil, nil
                motion.pauseVisible, motion.pauseHiding = nil, nil
                frame.StateBadge:Hide()
            end)
        end
        motion.spec = spec
        behavior.TimelineMotionLayers(frame)
        local move = function(region, parent)
            if region then
                motion.parents[region] = region:GetParent()
                region:SetParent(parent)
            end
        end
        for _, key in ipairs({ "SpellIcon", "AtIconMask", "IconOverlay", "IconShade", "IconGlow",
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
        move(frame.DurationLayer, motion.Labels)
        for _, key in ipairs({ "RoleIcons", "dispellTypeIcons", "DangerIcon" }) do
            for _, region in ipairs(frame[key] or {}) do move(region, motion.Labels) end
        end
        ThemeApply.Texture(motion.Glow, spec.Highlight.Glow)
        ThemeApply.Texture(motion.Swirl, spec.Highlight.Swirl)
        ThemeApply.Mask(motion.Mask, spec.Highlight.Mask)
        motion.Glow:SetAlpha(0)
        motion.Swirl:SetAlpha(0)
        behavior.LayoutIconArt(frame)
        motion.Container:Show()
        motion.Labels:Show()
        motion.Markers:Show()
    end

    ---state markers draw over type badges, while both remain inside the icon's level range
    behavior.TimelineMotionLayers = function(frame)
        local motion = frame.timelineMotion
        local level = frame:GetFrameLevel()
        if motion.layerLevel == level then return end
        motion.Container:SetFrameLevel(level + 1)
        motion.Labels:SetFrameLevel(level + 2)
        motion.Markers:SetFrameLevel(level + 3)
        motion.layerLevel = level
    end

    behavior.EnterTimelineMotion = function(frame, previewRemaining)
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

    behavior.UpdateTimelineMotion = function(frame, state, remaining, positionRemaining, zone)
        local motion = frame.timelineMotion
        if not motion or not motion.spec then return end
        local full = private.AmbientEffectsEnabled()
        local track = private.GetElementStyle("Timeline").Track
        local pipTime = track and track.PipTime or 5
        local moving = zone == private.TIMELINE_ZONES.MOVING
        behavior.TimelineMotionLayers(frame)
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
        local paused = state == private.manager.STATES.Paused
        if paused then
            if not motion.pauseVisible or motion.pauseHiding then
                motion.PauseHide:Stop()
                motion.PauseShow:Play()
            end
            motion.pauseVisible, motion.pauseHiding = true, false
        elseif motion.pauseVisible and not motion.pauseHiding then
            motion.PauseShow:Stop()
            motion.PauseHide:Play()
            motion.pauseHiding = true
        end
        if not full then
            motion.pauseVisible, motion.pauseHiding = paused, false
            motion.PauseShow:Stop(); motion.PauseHide:Stop()
        end
        frame.StateBadge:SetShown(motion.pauseVisible and true or false)
        if motion.pauseVisible then ThemeApply.Texture(frame.StateBadge, frame.atStateArt.PausedIcon) end
        local overlay = motion.pauseVisible and frame.atStateArt.Paused
        frame.StateOverlay:SetShown(ThemeApply.Texture(frame.StateOverlay, overlay))
        return positionRemaining
    end

    ---orients artwork using Blizzard's track orientation (arrival is its END point)
    behavior.OrientedTexture = function(texture, spec, arrival)
        if not ThemeApply.Texture(texture, spec) then return false end
        local left, right, top, bottom = 0, 1, 0, 1
        if spec.Coords and not (spec.Atlas and ThemeApply.AtlasInfo(spec.Atlas)) then
            left, right, top, bottom = unpack(spec.Coords)
        end
        if arrival == "LEFT" then
            texture:SetTexCoord(right, top, right, bottom, left, top, left, bottom)
        elseif arrival == "BOTTOM" then
            texture:SetTexCoord(left, top, right, top, left, bottom, right, bottom)
        elseif arrival == "TOP" then
            texture:SetTexCoord(right, top, left, top, right, bottom, left, bottom)
        else
            texture:SetTexCoord(left, right, top, bottom)
        end
        return true
    end

    behavior.ConfigureIconTrail = function(frame, spec)
        frame.iconTrailSpec, frame.iconTrailArrival = spec, nil
        if not spec and not frame.IconTrail then return end
        if not frame.IconTrail then
            frame.IconTrail = frame:CreateTexture(nil, "OVERLAY", nil, -1)
            frame:HookScript("OnHide", function() frame.IconTrail:Hide() end)
        end
        frame.IconTrail:Hide()
    end

    ---the trail follows the icon's anchors; only a direction change needs layout work
    behavior.UpdateIconTrail = function(frame, moving)
        local spec = frame.iconTrailSpec
        if not frame.IconTrail then return end
        if not spec or not moving or not frame:IsShown() or not private.AmbientEffectsEnabled() then
            frame.IconTrail:Hide()
            return
        end
        local arrival, horizontal = private.TimelineFrame.GetArrivalPoint()
        if arrival ~= frame.iconTrailArrival then
            local start = ({ LEFT = "RIGHT", RIGHT = "LEFT", TOP = "BOTTOM", BOTTOM = "TOP" })[arrival]
            local offset = (arrival == "RIGHT" or arrival == "TOP") and (spec.Offset or 10) or -(spec.Offset or 10)
            frame.IconTrail:ClearAllPoints()
            frame.IconTrail:SetPoint(arrival, frame.SpellIcon, start, horizontal and offset or 0, horizontal and 0 or offset)
            local length, thickness = spec.Length or 32, spec.Thickness or 2
            frame.IconTrail:SetSize(horizontal and length or thickness, horizontal and thickness or length)
            behavior.OrientedTexture(frame.IconTrail, spec, arrival)
            frame.iconTrailArrival = arrival
        end
        frame.IconTrail:Show()
    end


    ---updates optional state art without changing the manager's timer state or badge alpha
    behavior.IconState = function(frame, state)
        local style = frame.atStateArt
        if not style and not frame.StateOverlay then return end
        if not frame.StateOverlay then
            local parent = frame.TextureHolder or frame
            frame.StateOverlay = parent:CreateTexture(nil, "OVERLAY", nil, -7)
            frame.StateOverlay:SetPoint("TOPLEFT", frame.SpellIcon, "TOPLEFT", -7, 6)
            frame.StateOverlay:SetPoint("BOTTOMRIGHT", frame.SpellIcon, "BOTTOMRIGHT", 7, -7)
            frame.StateBadge = parent:CreateTexture(nil, "OVERLAY", nil, 7)
            frame.StateBadge:SetSize(16, 16)
            frame.StateBadge:SetPoint("BOTTOMRIGHT", frame.SpellIcon, "BOTTOMRIGHT", -4, 4)
        end
        if frame.atStateValue == state and frame.atStateStyle == style then return end
        frame.atStateValue, frame.atStateStyle = state, style
        local overlay, badge
        if style then
            if state == private.manager.STATES.Paused then
                overlay, badge = style.Paused, style.PausedIcon
            elseif state == private.manager.STATES.Queued then
                badge = style.QueuedIcon
            end
        end
        frame.StateOverlay:SetShown(ThemeApply.Texture(frame.StateOverlay, overlay))
        frame.StateBadge:SetShown(ThemeApply.Texture(frame.StateBadge, badge))
    end

    behavior.LayoutIconArt = function(frame)
        local stateArt = frame.atIconStyle.StateArt
        if stateArt and frame.StateOverlay then
            local offsets = stateArt.Offsets or { left = -7, top = 6, right = 7, bottom = -7 }
            ThemeApply.PlaceIconArt(frame, frame.StateOverlay, offsets, stateArt.ReferenceSize)
        end
        -- the highlight is drawn for 35px icons, it grows with the icon like the overlay
        local motion = frame.timelineMotion
        if motion and motion.spec then
            local highlight = motion.spec.Highlight
            ThemeApply.PlaceIconArt(frame, motion.Glow, highlight.Glow.Offsets, highlight.Glow.ReferenceSize)
            ThemeApply.PlaceIconArt(frame, motion.Mask, highlight.Mask.Offsets, highlight.Mask.ReferenceSize)
            local size = highlight.Swirl.Size * frame:GetWidth() / highlight.Swirl.ReferenceSize
            motion.Swirl:SetSize(size, size)
        end
    end

    behavior.ConfigureIcon = function(frame, style)
        behavior.ConfigureIconTrail(frame, not frame.atIconSkinned and style.Trail or nil)
        frame.atStateArt = not frame.atIconSkinned and style.StateArt or nil
        frame.atStateValue = nil
    end

    behavior.ResetIcon = function(frame)
        behavior.StopTimelineMotion(frame)
        behavior.ConfigureIconTrail(frame, nil)
        frame.atStateArt, frame.atStateValue = nil, nil
        behavior.IconState(frame, frame.state)
    end

    behavior.SelectExit = function(exit, state)
        return (state == nil or state == private.manager.STATES.Finished) and exit.Finished or exit.Canceled
    end

    behavior.SetupGhost = function(host, ghost, icon, iconFile, frame)
        local scale = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
        local left, bottom = frame:GetRect()
        host.exitX, host.exitY = left and left * scale, bottom and bottom * scale
        host.exitHorizontal = frame.timelineMotion and select(2, private.TimelineFrame.GetArrivalPoint())
        if ghost.Overlay and not host.GhostOverlay then
            host.GhostOverlay = host:CreateTexture(nil, "OVERLAY")
        end
        if host.GhostOverlay then
            host.GhostOverlay:SetShown(ThemeApply.Texture(host.GhostOverlay, ghost.Overlay))
        end
        if host.GhostScale then host.GhostScale:Stop() end
        if ghost.NativeScale and not host.GhostArt then
            host.GhostArt = CreateFrame("Frame", nil, host)
            host.GhostArt:SetAllPoints(host)
            host.GhostScale = host.GhostArt:CreateAnimationGroup()
            host.GhostScale.Grow = host.GhostScale:CreateAnimation("Scale")
            host.GhostScale.Grow:SetOrigin("CENTER", 0, 0)
            host.GhostScale.Grow:SetSmoothing("OUT")
        end
        for _, key in ipairs({ "Ghost", "GhostFlash", "GhostEdge", "GhostShape", "GhostDissolve", "GhostOverlay" }) do
            if host[key] then host[key]:SetParent(ghost.NativeScale and host.GhostArt or host) end
        end
        if host.GhostArt then
            host.GhostArt:SetFrameLevel(host:GetFrameLevel() + 1)
            host.GhostArt:SetShown(ghost.NativeScale and true or false)
        end
        if ghost.NativeScale then
            host.GhostScale.Grow:SetDuration(ghost.Time)
            host.GhostScale.Grow:SetScaleFrom(ghost.Scale[1], ghost.Scale[1])
            host.GhostScale.Grow:SetScaleTo(ghost.Scale[2], ghost.Scale[2])
            host.GhostScale:Play()
        end
        host.ExitLabels = host.ExitLabels or {}
        for _, label in ipairs(host.ExitLabels) do label:Hide() end
        if ghost.Labels then
            if not host.ExitLabelLayer then
                host.ExitLabelLayer = CreateFrame("Frame", nil, host)
                host.ExitLabelLayer:SetAllPoints(host)
            end
            host.ExitLabelLayer:SetFrameLevel(host:GetFrameLevel() + 2)
            local scale = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
            for index, source in ipairs({ frame.SpellName, frame.Cooldown }) do
                local label = host.ExitLabels[index]
                if not label then
                    label = host.ExitLabelLayer:CreateFontString(nil, "OVERLAY")
                    host.ExitLabels[index] = label
                end
                local anchor = index == 1 and frame.atSpellNameAnchor or { "CENTER", "CENTER", 0, 0 }
                if anchor then
                    label:SetFont(source:GetFont())
                    if index == 1 then
                        label:SetText(frame.atNameText or "")
                        label:SetTextColor(unpack(frame.atNameColor or { 1, 1, 1 }))
                    else
                        label:SetText(source.atCountdownText or "")
                        label:SetTextColor(source:GetTextColor())
                    end
                    label:SetScale(scale)
                    label:ClearAllPoints()
                    label:SetPoint(anchor[1], host, anchor[2], anchor[3], anchor[4])
                    label:Show()
                end
            end
        end
        if ghost.FlashMask == false then setMask(host.GhostFlash, host.GhostShape, false) end
    end

    behavior.GetGhostScale = function(ghost)
        if ghost.NativeScale then return 1 end
    end

    behavior.StepGhost = function(host, ghost, progress)
        local scale = 1
        if ghost.FlashAlpha then host.GhostFlash:SetAlpha(ghost.FlashAlpha * (1 - progress)) end
        if ghost.Flash and ghost.Flash.Offsets then
            local offsets = ghost.Flash.Offsets
            local factor = scale * (ghost.Flash.ReferenceSize and host:GetWidth() / ghost.Flash.ReferenceSize or 1)
            host.GhostFlash:ClearAllPoints()
            host.GhostFlash:SetPoint("TOPLEFT", host.Ghost, "TOPLEFT", offsets.left * factor, offsets.top * factor)
            host.GhostFlash:SetPoint("BOTTOMRIGHT", host.Ghost, "BOTTOMRIGHT", offsets.right * factor, offsets.bottom * factor)
        end
        if host.GhostOverlay then
            local offsets = ghost.Overlay and ghost.Overlay.Offsets or {}
            local reference = ghost.Overlay and ghost.Overlay.ReferenceSize
            local factor = scale * (reference and host:GetWidth() / reference or 1)
            host.GhostOverlay:ClearAllPoints()
            host.GhostOverlay:SetPoint("TOPLEFT", host.Ghost, "TOPLEFT", (offsets.left or 0) * factor, (offsets.top or 0) * factor)
            host.GhostOverlay:SetPoint("BOTTOMRIGHT", host.Ghost, "BOTTOMRIGHT", (offsets.right or 0) * factor, (offsets.bottom or 0) * factor)
            host.GhostOverlay:SetAlpha(1 - progress)
        end
        if ghost.CrossAxis and host.exitX then
            local offset = ghost.CrossAxis.Distance * math.min(progress * ghost.Time / ghost.CrossAxis.Time, 1)
            host:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", host.exitX + (host.exitHorizontal and 0 or offset),
                host.exitY + (host.exitHorizontal and offset or 0))
        end
        for _, label in ipairs(host.ExitLabels or {}) do label:SetAlpha(1 - progress) end
    end

    behavior.ResetGhost = function(host)
        if host.GhostScale then host.GhostScale:Stop() end
        for _, key in ipairs({ "Ghost", "GhostFlash", "GhostEdge", "GhostShape", "GhostDissolve", "GhostOverlay" }) do
            if host[key] then host[key]:SetParent(host) end
        end
        host.GhostFlash:ClearAllPoints()
        host.GhostFlash:SetAllPoints(host.Ghost)
        if host.GhostArt then host.GhostArt:Hide() end
        if host.GhostOverlay then host.GhostOverlay:Hide() end
        for _, label in ipairs(host.ExitLabels or {}) do label:Hide() end
        host.exitX, host.exitY, host.exitHorizontal = nil, nil, nil
    end

    local OPPOSITE = { LEFT = "RIGHT", RIGHT = "LEFT", TOP = "BOTTOM", BOTTOM = "TOP" }

    ---lays optional track artwork along the same axis and time range as the event icons
    behavior.UpdateTrack = function(frame)
        local track = frame.track
        if not frame.TrackArt then return end
        for _, texture in pairs(frame.TrackArt) do texture:Hide() end
        for _, mask in pairs(frame.TrackBreakMasks or {}) do
            frame.TrackArt.Start:RemoveMaskTexture(mask)
            frame.TrackArt.End:RemoveMaskTexture(mask)
        end
        if not track then return end
        local art, horizontal, arrival = frame.TrackArt, frame.isHorizontal, frame.arrival
        local length = horizontal and frame:GetWidth() or frame:GetHeight()
        local thickness = track.Thickness or 14
        local place = function(texture, distance, along, across)
            texture:ClearAllPoints()
            local offset = (arrival == "RIGHT" or arrival == "TOP") and -distance or distance
            texture:SetPoint("CENTER", frame, arrival, horizontal and offset or 0, horizontal and 0 or offset)
            texture:SetSize(horizontal and along or across, horizontal and across or along)
        end
        local shadow = not horizontal and track.ShadowVertical or track.Shadow
        local nativeVertical = not horizontal and shadow == track.ShadowVertical
        art.Shadow:SetShown(behavior.OrientedTexture(art.Shadow, shadow,
            nativeVertical and "RIGHT" or arrival))
        place(art.Shadow, length / 2, length, track.ShadowThickness or 57)
        for index, spec in ipairs({ track.End, track.Start }) do
            local texture = index == 1 and art.End or art.Start
            texture:SetShown(behavior.OrientedTexture(texture, spec, arrival))
            texture:SetVertexColor(ThemeApply.Color(private.GetElementStyle("Timeline").Backdrop.Color))
            place(texture, length * (index == 1 and 0.25 or 0.75), length / 2, thickness)
        end
        local total = private.db.profile.timeline_settings.threshold_time
        local time = track.PipTime or 5
        local maskCounts = { Start = 0, End = 0 }
        for index = 1, 6 do
            local duration = 1 + (index - 1) * 2
            local key = duration <= total / 2 and "End" or "Start"
            if track.BreakMask and maskCounts[key] < 3 then
                local mask = frame.TrackBreakMasks[index]
                if not mask then
                    mask = frame:CreateMaskTexture()
                    frame.TrackBreakMasks[index] = mask
                end
                if private.ThemeApply.Mask(mask, track.BreakMask) then
                    mask:ClearAllPoints()
                    local distance = duration / total * length
                    local offset = (arrival == "LEFT" or arrival == "BOTTOM") and distance or -distance
                    mask:SetPoint("CENTER", frame, arrival, horizontal and offset or 0, horizontal and 0 or offset)
                    mask:SetSize(16, 16)
                    mask:SetRotation(horizontal and 0 or 90)
                    art[key]:AddMaskTexture(mask)
                    maskCounts[key] = maskCounts[key] + 1
                end
            end
        end
        art.Pip:SetShown(time <= total and private.ThemeApply.Texture(art.Pip, track.Pip) or false)
        place(art.Pip, math.min(time / total, 1) * length, track.PipSize or 16, track.PipSize or 16)
        art.Divider:SetShown(behavior.OrientedTexture(art.Divider, track.Divider, arrival))
        art.Divider:SetVertexColor(ThemeApply.Color(private.GetElementStyle("Timeline").Backdrop.Color))
        art.Divider:ClearAllPoints()
        local offset = (arrival == "LEFT" or arrival == "BOTTOM") and -(track.DividerOffset or 0) or (track.DividerOffset or 0)
        art.Divider:SetPoint(arrival, frame, OPPOSITE[arrival], horizontal and offset or 0, horizontal and 0 or offset)
        art.Divider:SetSize(horizontal and (track.DividerWidth or 56) or (track.DividerHeight or 46),
            horizontal and (track.DividerHeight or 46) or (track.DividerWidth or 56))
        art.PipText:SetShown(track.PipText and private.db.profile.timeline_settings.ticks_enabled ~= false and time <= total or false)
        if track.PipText then
            private.ThemeApply.Font(art.PipText, track.PipFont)
            art.PipText:SetText(string.format("%d", time))
            art.PipText:ClearAllPoints()
            if horizontal then
                art.PipText:SetPoint("TOP", art.Pip, "BOTTOM", 0, -19)
            elseif private.GetElementStyle("SpellIcon").Text.Anchor == "RIGHT" then
                art.PipText:SetPoint("RIGHT", art.Pip, "LEFT", -20, 0)
            else
                art.PipText:SetPoint("LEFT", art.Pip, "RIGHT", 20, 0)
            end
        end
    end

    behavior.ConfigureTrack = function(frame, track)
        frame.track = private.GetElementStyle("Timeline").Backdrop.Background == TRACK_BACKGROUND and track or nil
        if not frame.TrackArt then
            frame.TrackBreakMasks = {}
            frame.TrackArt = {
                Shadow = frame:CreateTexture(nil, "BACKGROUND", nil, -1),
                Start = frame:CreateTexture(nil, "ARTWORK"),
                End = frame:CreateTexture(nil, "ARTWORK"),
                Pip = frame:CreateTexture(nil, "OVERLAY"),
                Divider = frame:CreateTexture(nil, "ARTWORK"),
                PipText = frame:CreateFontString(nil, "OVERLAY", "SystemFont_Shadow_Large"),
            }
            for _, texture in pairs(frame.TrackArt) do texture:Hide() end
            frame:HookScript("OnSizeChanged", ThemeApply.UpdateTrack)
        end
        behavior.UpdateTrack(frame)
    end

    behavior.ResetTrack = function(frame)
        frame.track = nil
        behavior.UpdateTrack(frame)
    end

    behavior.ConfigureTimelineArt = function(frame, style)
        if style.Backdrop.Background ~= TRACK_BACKGROUND then return end
        local backdrop = {}
        for key, value in pairs(style.Backdrop) do backdrop[key] = value end
        backdrop.Background = false
        ThemeApply.Backdrop(frame, backdrop)
    end

    ThemeApply.RegisterBehavior("Blizzard", behavior)
end

private.RegisterThemeTextures("Blizzard", {
    "blizzard_timeline", "blizzard_cooldown", "blizzard_icon_mask", "blizzard_break_mask", "blizzard_highlight_mask", "blizzard_ej_icons",
    "blizzard_border",
})

local ATLAS_ART = {
    ["ui-hud-cooldownmanager-iconoverlay"] = { File = "blizzard_cooldown", Coords = { 0.00390625, 0.33984375, 0.0078125, 0.6796875 } },
    ["ui-hud-cooldownmanager-mask"] = { File = "blizzard_icon_mask" },
    ["combattimeline-cooldown-divider"] = { File = "blizzard_timeline", Coords = { 0.0009765625, 0.0556640625, 0.751953125, 0.796875 } },
    ["combattimeline-fx-highlight"] = { File = "blizzard_timeline", Coords = { 0.337890625, 0.421875, 0.05859375, 0.142578125 } },
    ["combattimeline-fx-highlight-fx"] = { File = "blizzard_timeline", Coords = { 0.05859375, 0.1640625, 0.05859375, 0.1640625 } },
    ["combattimeline-fx-highlight-mask"] = { File = "blizzard_highlight_mask" },
    ["combattimeline-fx-pause"] = { File = "blizzard_timeline", Coords = { 0.423828125, 0.5078125, 0.05859375, 0.142578125 } },
    ["combattimeline-fx-pause-icon"] = { File = "blizzard_timeline", Coords = { 0.0009765625, 0.0244140625, 0.798828125, 0.82421875 } },
    ["combattimeline-fx-queued-icon"] = { File = "blizzard_timeline", Coords = { 0.6943359375, 0.7109375, 0.0322265625, 0.048828125 } },
    ["combattimeline-line-break-mask"] = { File = "blizzard_break_mask" },
    ["combattimeline-line-icontrail"] = { File = "blizzard_timeline", Coords = { 0.884765625, 0.916015625, 0.0009765625, 0.0029296875 } },
    ["combattimeline-line-left"] = { File = "blizzard_timeline", Coords = { 0.6943359375, 0.8828125, 0.0009765625, 0.0146484375 } },
    ["combattimeline-line-right"] = { File = "blizzard_timeline", Coords = { 0.6943359375, 0.8828125, 0.0166015625, 0.0302734375 } },
    ["combattimeline-line-shadow"] = { File = "blizzard_timeline", Coords = { 0.0009765625, 0.6923828125, 0.0009765625, 0.056640625 } },
    ["combattimeline-line-shadow-vertical"] = { File = "blizzard_timeline", Coords = { 0.0009765625, 0.056640625, 0.05859375, 0.75 } },
    ["combattimeline-pip"] = { File = "blizzard_timeline", Coords = { 0.712890625, 0.728515625, 0.0322265625, 0.0478515625 } },
}

local component = function(atlas, extra)
    local spec = extra or {}
    local art = ATLAS_ART[atlas:lower()]
    spec.Atlas, spec.File, spec.Coords = atlas, art.File, art.Coords
    return spec
end

local MASK = component("UI-HUD-CoolDownManager-Mask")
local OVERLAY = component("UI-HUD-CoolDownManager-IconOverlay", {
    ReferenceSize = 35,
    Offsets = { left = -7, top = 6, right = 7, bottom = -7 },
})
local STATES = {
    ReferenceSize = 35,
    Paused = component("combattimeline-fx-pause"),
    PausedIcon = component("combattimeline-fx-pause-icon"),
    QueuedIcon = component("combattimeline-fx-queued-icon"),
}
local HIGHLIGHT = component("combattimeline-fx-highlight", {
    ReferenceSize = 35,
    Fade = { 1, 0 }, Time = 0.2,
    Offsets = { left = -8, top = 7, right = 8, bottom = -8 },
})
local TIMELINE_MOTION = {
    SlideTime = 0.35, SlideDistance = 25,
    Pulse = { Grow = 1.1, Shrink = 0.9, Time = 0.2, Delay = 0.6 },
    Highlight = {
        Glow = HIGHLIGHT,
        Swirl = component("combattimeline-fx-highlight-fx", { BlendMode = "ADD", Size = 108, ReferenceSize = 35 }),
        Mask = component("combattimeline-fx-highlight-mask", {
            ReferenceSize = 35, Offsets = { left = -1, top = 1, right = 1, bottom = -1 },
        }),
    },
}

local icon = function(pulse)
    return {
        Behavior = "Blizzard",
        Zoom = 0, Mask = MASK, Overlay = OVERLAY, StateArt = STATES,
        Border = { File = "blizzard_border", Alpha = 1, Glow = false },
        Enter = { Ease = "linear" },
        Exit = { Ghost = { Source = "Icon", Mask = MASK, Fade = { 1, 0 }, Time = 0.2 } },
        Pulse = false,
        TimelineMotion = pulse and TIMELINE_MOTION or false,
        Text = { Font = { Media = false, Object = "SystemFont_Shadow_Med3", Flags = {} } },
    }
end
local spellIcon = icon(true)
spellIcon.QueuedMarkers = {
    Art = component("combattimeline-fx-queued-icon"), Colors = { "White", "White", "White" },
    Size = 10, Spacing = 10, Offset = 4, ReferenceSize = 35,
    Enter = { Time = 0.5, Stagger = 0.2, Hop = 10, Fade = false },
}
spellIcon.Size = 35
spellIcon.DispelIcon = { Size = 12 }
spellIcon.Trail = component("combattimeline-line-icontrail", { BlendMode = "ADD" })
spellIcon.Exit = {
    Behavior = "Blizzard",
    Finished = { Ghost = { Behavior = "Blizzard",
        Source = "Icon", Mask = MASK, Fade = { 1, 0 }, Time = 0.2,
        Scale = { 1, 1.35 }, NativeScale = true, Overlay = OVERLAY, Labels = true,
        Flash = HIGHLIGHT, FlashAlpha = 1, FlashMask = false,
    } },
    Canceled = { Ghost = { Behavior = "Blizzard",
        Source = "Icon", Mask = MASK, Fade = { 1, 0 }, Time = 0.2, Overlay = OVERLAY, Labels = true,
        CrossAxis = { Distance = 25, Time = 0.35 },
    } },
}


local settingsMedia = LibStub("LibSharedMedia-3.0")
settingsMedia:Register("background", TRACK_BACKGROUND, ThemeApply.File("blizzard_timeline"))

do
    local start = component("combattimeline-line-left")
    local finish = component("combattimeline-line-right")
    local behavior = ThemeApply.GetBehavior({ Behavior = "Blizzard" })
    private.RegisterMediaPreview("background", TRACK_BACKGROUND, function(frame)
        frame.Texture:Hide()
        if not frame.BlizzardTrackPreview then
            local left = frame:CreateTexture(nil, "ARTWORK")
            left:SetPoint("TOPLEFT", frame, "TOPLEFT")
            left:SetPoint("BOTTOMRIGHT", frame, "BOTTOM")
            local right = frame:CreateTexture(nil, "ARTWORK")
            right:SetPoint("TOPLEFT", frame, "TOP")
            right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT")
            frame.BlizzardTrackPreview = { left, right }
        end
        behavior.OrientedTexture(frame.BlizzardTrackPreview[1], finish, "LEFT")
        behavior.OrientedTexture(frame.BlizzardTrackPreview[2], start, "LEFT")
        for _, texture in ipairs(frame.BlizzardTrackPreview) do texture:Show() end
    end, function(frame)
        for _, texture in ipairs(frame.BlizzardTrackPreview or {}) do texture:Hide() end
    end)
end
for name, path in pairs({
    blizzard_settings_check_box = "Interface\\Buttons\\UI-CheckBox-Up",
    blizzard_settings_check = "Interface\\Buttons\\UI-CheckBox-Check",
    blizzard_settings_slider = "Interface\\Buttons\\UI-SliderBar-Background",
    blizzard_settings_thumb = "Interface\\Buttons\\UI-SliderBar-Button-Horizontal",
}) do
    settingsMedia:Register(private.ThemeMediaType, private.MediaName(name), path)
end

do
    local behavior = {}
    local frameAtlases = {
        "UI-Frame-Metal-CornerTopLeft", "UI-Frame-Metal-CornerTopRight",
        "UI-Frame-Metal-CornerBottomLeft", "UI-Frame-Metal-CornerBottomRight",
        "_UI-Frame-Metal-EdgeTop", "_UI-Frame-Metal-EdgeBottom",
        "!UI-Frame-Metal-EdgeLeft", "!UI-Frame-Metal-EdgeRight",
    }
    behavior.ConfigureWindow = function(frame)
        if not NineSliceUtil or not NineSliceUtil.ApplyLayoutByName or not NineSliceUtil.GetLayout or
            not NineSliceUtil.GetLayout("ButtonFrameTemplateNoPortrait") then return end
        for _, atlas in ipairs(frameAtlases) do
            if not ThemeApply.AtlasInfo(atlas) then return end
        end
        local shell = frame.AtShell
        if not shell.BlizzardFrame then
            shell.BlizzardFrame = CreateFrame("Frame", nil, shell)
            shell.BlizzardFrame:SetPoint("TOPLEFT", shell, "TOPLEFT", -2, 0)
            shell.BlizzardFrame:SetPoint("BOTTOMRIGHT", shell, "BOTTOMRIGHT", -4, 3)
            NineSliceUtil.ApplyLayoutByName(shell.BlizzardFrame, "ButtonFrameTemplateNoPortrait")
            for _, key in ipairs({ "TopLeftCorner", "TopEdge", "TopRightCorner" }) do
                local piece = shell.BlizzardFrame[key]
                piece:SetHeight(piece:GetHeight() + 16)
            end
        end
        shell.atBlizzardFrameLevel = shell:GetFrameLevel()
        shell:SetFrameLevel(math.max(frame:GetFrameLevel() - 1, 0))
        shell.BlizzardFrame:SetFrameLevel(shell:GetFrameLevel())
        shell.BlizzardFrame:Show()
        shell:SetBackdropBorderColor(0, 0, 0, 0)
    end
    behavior.ConfigureSettingsWindow = function(widget)
        local frame = widget.frame
        local shell = frame.AtShell
        frame.atBlizzardNavWidth = frame.Nav:GetWidth()
        frame.Nav:SetWidth(199)
        if ThemeApply.AtlasInfo("Options_InnerFrame") then
            if not shell.BlizzardInset then
                shell.BlizzardInset = shell:CreateTexture(nil, "BORDER", nil, 2)
                shell.BlizzardInset:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -34)
                shell.BlizzardInset:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 34)
                shell.BlizzardInset:SetAtlas("Options_InnerFrame")
            end
            shell.BlizzardInset:Show()
        end
        for _, panel in ipairs({ frame.Nav, frame.Details }) do
            panel.AtFill:Hide(); panel.AtEdge:Hide()
        end
        ThemeApply.FontRole(frame.Details.Text, "CardText")
        frame.atBlizzardSettings = widget
    end
    behavior.ResetWindow = function(frame)
        local shell = frame.AtShell
        if shell and shell.BlizzardFrame then shell.BlizzardFrame:Hide() end
        if shell and shell.BlizzardInset then shell.BlizzardInset:Hide() end
        if shell and shell.atBlizzardFrameLevel ~= nil then
            shell:SetFrameLevel(shell.atBlizzardFrameLevel)
            shell.atBlizzardFrameLevel = nil
        end
        if frame.atBlizzardSettings then
            frame.Nav:SetWidth(frame.atBlizzardNavWidth)
            frame.atBlizzardNavWidth = nil
            for _, panel in ipairs({ frame.Nav, frame.Details }) do
                panel.AtFill:Show(); panel.AtEdge:Show()
            end
            frame.atBlizzardSettings = nil
        end
    end
    ThemeApply.RegisterBehavior("BlizzardSettings", behavior)
end

local SETTINGS_WINDOW = {
    Behavior = "BlizzardSettings",
    Backdrop = {
        BgFile = "Interface\\Buttons\\WHITE8X8",
        EdgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        EdgeSize = 16, Insets = { left = 4, right = 4, top = 4, bottom = 4 },
        Color = "Body", BorderColor = "Edge",
    },
    Fill = "Body", Edge = "Edge", Wash = { 0, 0, 0, 0 },
    HeaderLine = { 0, 0, 0, 0 }, HeaderHeight = 34, Footer = "FooterFill",
    CloseArt = { Atlas = "RedButton-Exit", Texture = "Interface\\Buttons\\UI-Panel-MinimizeButton-Up" },
    ShowScale = 1, Sparkles = false,
}

local settingsFonts = {}
for role, font in pairs(private.Themes.Classic.Fonts) do
    settingsFonts[role] = {
        Object = "GameFontHighlight", Size = font.Size, Color = font.Color,
        Shadow = true, Flags = {},
    }
end
for _, role in ipairs({ "Title", "DialogTitle", "Heading", "CardTitle", "Button", "ButtonPrimary", "TabSelected" }) do
    settingsFonts[role].Object = "GameFontNormal"
    settingsFonts[role].Color = "Accent"
end
settingsFonts.Control.Color = "Accent"
settingsFonts.Label.Color = "Accent"
settingsFonts.Tab.Color = "Accent"
settingsFonts.Heading.Color = "Text"
settingsFonts.Heading.Size = 18
settingsFonts.Title.Size = 14
settingsFonts.TabSelected.Color = "Text"
settingsFonts.CardText.Color = "Text"
settingsFonts.CardText.Size = 12

private.RegisterTheme({
    Name = "Blizzard",
    DisplayName = private.getLocalisation("ThemeBlizzard"),
    Description = private.getLocalisation("ThemeBlizzardDescription"),
    Effects = true,
    Motion = { Time = { Enter = 0.2, Exit = 0.2 } },
    Variables = {
        BlizzardPanelColor = function()
            if PANEL_BACKGROUND_COLOR then return { PANEL_BACKGROUND_COLOR:GetRGBA() } end
            return { 0.055, 0.055, 0.055, 0.78 }
        end,
    },
    Palette = {
        Body = "$BlizzardPanelColor",
        Card = { 0, 0, 0, 0 },
        Field = { 0.06, 0.06, 0.06, 0.75 },
        FieldHover = { 0.11, 0.105, 0.09, 1 },
        FieldPressed = { 0.02, 0.02, 0.02, 1 },
        Track = { 0.2, 0.18, 0.14, 1 },
        Edge = { 0.45, 0.4, 0.3, 1 },
        Line = { 0.55, 0.45, 0.23, 0.65 },
        Accent = { 1, 0.82, 0, 1 }, Accent2 = { 0.8, 0.7, 0.45, 1 },
        Text = { 1, 1, 1, 1 }, Muted = { 0.65, 0.62, 0.56, 1 },
        Highlight = { 1, 1, 1, 0.025 },
        FooterFill = { 0.025, 0.025, 0.025, 0.25 },
    },
    Fonts = settingsFonts,
    Windows = { Window = SETTINGS_WINDOW, Dialog = SETTINGS_WINDOW },
    Controls = {
        Dropdown = {
            Normal = "common-dropdown-c-button",
            Hover = "common-dropdown-c-button-hover-1",
            Open = "common-dropdown-c-button-open",
            Disabled = "common-dropdown-c-button-disabled",
            Arrow = "common-dropdown-c-button-hover-arrow",
        },
        Button = { Fill = "White", Edge = "Edge", Parts = {
            { Texture = "Interface\\Buttons\\UI-Panel-Button-Up", Coords = { 0, 0.09375, 0, 0.6875 } },
            { Texture = "Interface\\Buttons\\UI-Panel-Button-Up", Coords = { 0.09375, 0.53125, 0, 0.6875 } },
            { Texture = "Interface\\Buttons\\UI-Panel-Button-Up", Coords = { 0.53125, 0.625, 0, 0.6875 } },
        } },
        CheckBox = { Box = { Atlas = "checkbox-minimal", File = "blizzard_settings_check_box" },
            Check = { Atlas = "checkmark-minimal", File = "blizzard_settings_check" }, Size = 32 },
        Slider = {
            Track = { Atlas = "_Minimal_SliderBar_Middle", File = "blizzard_settings_slider" },
            Thumb = { Atlas = "Minimal_SliderBar_Button", File = "blizzard_settings_thumb" },
            Height = 16, Size = 20, Fill = false,
            Caps = { Width = 8,
                Left = { Atlas = "Minimal_SliderBar_Left", File = "blizzard_settings_slider" },
                Right = { Atlas = "Minimal_SliderBar_Right", File = "blizzard_settings_slider" },
            },
        },
    },
    Elements = {
        Timeline = {
            Behavior = "Blizzard",
            Backdrop = { Background = TRACK_BACKGROUND, Border = false }, Background = false,
            Track = {
                Behavior = "Blizzard",
                Start = component("combattimeline-line-left"),
                End = component("combattimeline-line-right"),
                Divider = component("combattimeline-cooldown-divider"),
                DividerWidth = 56, DividerHeight = 46, DividerOffset = -22,
                BreakMask = component("combattimeline-line-break-mask", { WrapMode = "CLAMP" }),
                Shadow = component("combattimeline-line-shadow", { Alpha = 0 }),
                ShadowVertical = component("combattimeline-line-shadow-vertical", { Alpha = 0 }),
                Pip = component("combattimeline-pip"),
                Thickness = 14, ShadowThickness = 57, PipSize = 16, PipTime = 5, PipText = true,
                PipFont = { Object = "SystemFont_Shadow_Large" },
            },
        },
        Tick = {
            Line = { Alpha = 0, Thickness = 1 },
            Text = { Show = false, Font = { Object = "SystemFont_Shadow_Med3", Flags = {} } },
        },
        Cooldown = { Font = { Media = false, Object = "SystemFont_Shadow_Med3", Size = 16 } },
        SpellIcon = spellIcon,
        BigIcon = icon(false),
    },
})
