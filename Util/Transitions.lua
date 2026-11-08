local appName, app = ...
---@class AbilityTimeline
local private = app
local ThemeApply = private.ThemeApply

-- the effects of Enter and Exit specs, they only play while ambient effects are enabled.
-- every texture spec may have a Mask (a texture of Media/Textures/Theme), e.g. the shape of a masked icon
-- Enter: Cover (a texture spec over the frame that grows onto it from Grow, then fades out in Cover.Time),
-- Burst (a particle spec with Count), Ghost, Flare and Vortex as in Exit, following the frame (a Ghost of the theme's color
-- dissolving away reveals the frame below it)
-- Exit: Crack (a texture spec shown for Crack.Time), Shards (Source = "Icon" or a texture spec, Edge: a texture spec
-- drawn over every shard, Speed, Gravity, Time), Burst (flung once the crack breaks, or after BurstDelay seconds), Ghost
-- and Flare. Exits draw on their own frame so the frame they leave can be hidden right away
-- Ghost: an image of the leaving frame (Source = "Icon" or a texture spec) playing over Time: Scale = { from, to },
-- Rise (pixels it moves up, or { from, to } to come down into place), Fade = { from, to } (it fades out unless it
-- dissolves), Flash (a texture spec flaring up
-- over it and fading), Dissolve = { Frames, Count, Edge } eats it away along the masks <Frames>1..<Count> while Edge
-- (a texture spec) glows along <Frames>_edge1..<Count>, Sketch = { Back, Color, Hatch, Frames, Count, From, Draw,
-- Outline, Fill } draws it in pencil instead: over a sheet of Back (a color), Outline (a texture spec) is drawn in along
-- the masks <Outline.Frames><Count>..1 until Outline.Until of Time, the icon desaturated in Color (or the spec's
-- texture) masked by Hatch is drawn in along <Frames><Count>..1 from From to Draw, then it all fades with its sheet,
-- or with a Fill = { Frames, Count } goes along <Fill.Frames>1..<Count> so the frame below comes in patch by patch
-- Flare: a texture spec over the middle growing from Size[1] to Size[2] times the frame's smaller side, turning by
-- Spin per second, flaring up and fading over Time
-- Beam: a texture spec coming straight down onto the frame from Height times its height above it (2.4), Width times
-- its width wide (0.6), reaching it in the first 35% of Time and narrowing as it fades in the rest
-- Vortex: Count pieces of Texture (or a list) in Colors (palette names) spiralling in from Radius times the frame's
-- larger side onto its middle over Time, turning Turns times on the way, Size = { min, max } in pixels, Angle = { min,
-- max } in degrees counterclockwise from the right where they start (anywhere without it), Align turns them towards
-- the middle

-- the points the shards (Media/Textures/Theme/shard<n>) are cut around, in 0..1 from the top left, the first is the
-- middle they fly away from. the same as SHARD_SEEDS of tools/textures/generate.py
local SHARD_SEEDS = {
    { 0.48, 0.52 }, { 0.67, 0.6 }, { 0.4, 0.71 }, { 0.29, 0.44 }, { 0.56, 0.33 }, { 0.9, 0.38 }, { 0.76, 0.86 },
    { 0.3, 0.92 }, { 0.08, 0.6 }, { 0.4, 0.08 },
}

---places burst particles anywhere over host, or with Spot = { left, right, bottom, top } (fractions of it) only there,
---e.g. a splash bursting out of the middle
local spawnInside = function(host)
    return function(particle, spec)
        local spot = spec.Spot
        local x, y = math.random(), math.random()
        if spot then
            x, y = spot[1] + (spot[2] - spot[1]) * x, spot[3] + (spot[4] - spot[3]) * y
        end
        particle.x = x * host:GetWidth()
        particle.y = y * host:GetHeight()
    end
end

local between = function(range)
    return range[1] + math.random() * (range[2] - range[1])
end

---masks texture with file, a texture of Media/Textures/Theme over all of holder, or takes the mask away without one
---@param holder Frame
---@param texture Texture
---@param file string|table|nil
local setShape = function(holder, texture, file)
    if file then
        if not holder.AtShape then
            holder.AtShape = holder:CreateMaskTexture()
            holder.AtShape:SetAllPoints(holder)
        end
        if type(file) == "table" then
            ThemeApply.Mask(holder.AtShape, file)
        else
            holder.AtShape:SetTexture(ThemeApply.File(file), "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        end
    end
    if (file ~= nil) ~= (texture.atShaped or false) then
        if file then
            texture:AddMaskTexture(holder.AtShape)
        else
            texture:RemoveMaskTexture(holder.AtShape)
        end
        texture.atShaped = file ~= nil
    end
end

---plays Cover and Burst of an Enter spec on frame
---@param frame Frame
---@param enter table|nil
---@param icon Texture|nil -- the texture a Ghost with Source "Icon" shows
---@param iconFile any -- the file icon shows
ThemeApply.PlayEnterEffects = function(frame, enter, icon, iconFile)
    ThemeApply.StopEnterEffects(frame)
    if not enter or not private.AmbientEffectsEnabled() then return end
    if enter.Ghost or enter.Flare or enter.Vortex or enter.Beam then
        local _, host = ThemeApply.PlayExit(frame, { Ghost = enter.Ghost, Flare = enter.Flare, Vortex = enter.Vortex, Beam = enter.Beam },
            icon, iconFile, true)
        if host then
            frame.AtEnterHost = host
            host.enterFrame = frame
        end
    end
    if not (enter.Cover or enter.Burst) then return end
    local layer = frame.AtEnterLayer
    if not layer then
        -- a child above the frame's content
        layer = CreateFrame("Frame", nil, frame)
        layer:SetAllPoints(frame)
        layer.Cover = layer:CreateTexture(nil, "OVERLAY")
        layer.Cover:SetAllPoints(layer)
        layer.Freeze = layer.Cover:CreateAnimationGroup()
        layer.Freeze:SetToFinalAlpha(true)
        layer.Appear = layer.Freeze:CreateAnimation("Alpha")
        layer.Appear:SetFromAlpha(0)
        layer.Appear:SetToAlpha(1)
        layer.Appear:SetOrder(1)
        layer.Grow = layer.Freeze:CreateAnimation("Scale")
        layer.Grow:SetScaleTo(1, 1)
        layer.Grow:SetOrigin("CENTER", 0, 0)
        layer.Grow:SetSmoothing("OUT")
        layer.Grow:SetOrder(1)
        layer.Melt = layer.Freeze:CreateAnimation("Alpha")
        layer.Melt:SetFromAlpha(1)
        layer.Melt:SetToAlpha(0)
        layer.Melt:SetSmoothing("IN")
        layer.Melt:SetOrder(2)
        layer.Burst = private.CreateParticles(layer, spawnInside(layer))
        frame.AtEnterLayer = layer
    end
    layer:SetFrameLevel(math.min(frame:GetFrameLevel() + 50, 9000))
    layer.Freeze:Stop()
    local cover = enter.Cover
    if cover and ThemeApply.Texture(layer.Cover, cover) then
        setShape(layer, layer.Cover, cover.Mask)
        local time = cover.Time or 0.5
        -- the frost grows onto the frame in the first third and melts away in the rest
        layer.Appear:SetDuration(time * 0.3)
        layer.Grow:SetDuration(time * 0.3)
        layer.Grow:SetScaleFrom(cover.Grow or 1, cover.Grow or 1)
        layer.Melt:SetDuration(time * 0.7)
        layer.Cover:Show()
        layer.Freeze:Play()
    else
        layer.Cover:Hide()
    end
    if enter.Burst then
        layer.Burst:Burst(enter.Burst)
    end
end

local hosts = {}

local releaseHost = function(host)
    if host.windowSource then
        host.windowSource:SetAlpha(host.windowAlpha)
        host.windowSource, host.windowAlpha = nil, nil
    end
    if host.enterFrame then
        host.enterFrame.AtEnterHost = nil
        host.enterFrame = nil
    end
    if host.GhostScale then host.GhostScale:Stop() end
    host.Burst:Stop()
    for _, piece in ipairs(host.Shards) do
        piece:Hide()
    end
    host:Hide()
    table.insert(hosts, host)
end

ThemeApply.StopEnterEffects = function(frame)
    if frame.AtEnterHost then releaseHost(frame.AtEnterHost) end
end

---adds mask to texture or takes it away
---@param texture Texture
---@param mask MaskTexture
---@param on boolean
local setMask = function(texture, mask, on)
    texture.atMasks = texture.atMasks or {}
    if (texture.atMasks[mask] or false) ~= on then
        if on then
            texture:AddMaskTexture(mask)
        else
            texture:RemoveMaskTexture(mask)
        end
        texture.atMasks[mask] = on
    end
end

local lerp = function(range, progress, default)
    if not range then return default end
    return range[1] + (range[2] - range[1]) * progress
end

---shows the mask <frames><index> in mask, unless it shows it already (shown)
---@param mask MaskTexture
---@param frames string
---@param index number
---@param shown number|nil
---@return number
local stepMask = function(mask, frames, index, shown)
    if index ~= shown then
        mask:SetTexture(ThemeApply.File(frames .. index), "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    end
    return index
end

local stepSketch = function(host, sketch, progress)
    -- drawn in stroke by stroke, the dissolve's masks backwards, then the drawing and its sheet fade together or
    -- go along the fill's masks
    local draw, from = sketch.Draw or 0.6, sketch.From or 0
    local count = sketch.Count or 12
    host.dissolveFrame = stepMask(host.GhostDissolve, sketch.Frames,
        count - math.min(math.floor(math.max(progress - from, 0) / (draw - from) * count), count - 1), host.dissolveFrame)
    local outline = sketch.Outline
    if outline and host.GhostOutlineMask then
        host.outlineFrame = stepMask(host.GhostOutlineMask, outline.Frames,
            count - math.min(math.floor(progress / outline.Until * count), count - 1), host.outlineFrame)
    end
    local fill = sketch.Fill
    local alpha = 1
    if fill then
        local fillCount = fill.Count or count
        local filled = math.max(progress - draw, 0) / (1 - draw)
        host.fillFrame = stepMask(host.GhostFill, fill.Frames, math.min(math.floor(filled * fillCount) + 1, fillCount),
            host.fillFrame)
    elseif progress > draw then
        alpha = 1 - (progress - draw) / (1 - draw)
    end
    for _, key in ipairs({ "Ghost", "GhostBack", "GhostOutline" }) do
        if host[key] then host[key]:SetAlpha(alpha * (key == "Ghost" and (host.GhostAlpha or 1) or 1)) end
    end
end

local prepareWindowStroke = function(item, sketch, count)
    item.drawTime = sketch.Draw * (0.75 + math.random() * 0.25)
    item.inkTime = sketch.Ink * (0.8 + math.random() * 0.2)
    item.pressure = 0.88 + math.random() * 0.12
    item.strokeTimes = { 0 }
    local total = 0
    for i = 1, count do
        total = total + 0.3 + math.random() ^ 2 * 1.7
        item.strokeTimes[i + 1] = total
    end
    for i = 2, #item.strokeTimes do item.strokeTimes[i] = item.strokeTimes[i] / total end
end

-- A stroke accelerates after a brief hesitation; only its unfinished edge moves.
local windowStrokeProgress = function(item, progress)
    if progress <= 0 then return 0 end
    if progress >= 1 then return 1 end
    local times = item.strokeTimes
    for i = 2, #times do
        if progress <= times[i] then
            local stroke = math.max(0, math.min(((progress - times[i - 1]) / (times[i] - times[i - 1]) - 0.18) / 0.82, 1))
            return (i - 2 + 1 - (1 - stroke) ^ 1.6) / (#times - 1)
        end
    end
    return 1
end

local stepWindowOutline = function(part, drawn, alpha)
    local trace = part.Trace
    if trace.drawn == drawn and trace.alpha == alpha then return end
    trace.drawn, trace.alpha = drawn, alpha
    local remaining = drawn * trace.length
    local tipX, tipY = trace.points[1][1], trace.points[1][2]
    for i, line in ipairs(trace.lines) do
        local a, b = trace.points[i], trace.points[i + 1]
        local length = trace.lengths[i]
        local fraction = math.min(math.max(remaining / length, 0), 1)
        if fraction > 0 and alpha > 0 then
            tipX, tipY = a[1] + (b[1] - a[1]) * fraction, a[2] + (b[2] - a[2]) * fraction
            line:SetStartPoint("TOPLEFT", part.Color, a[1], -a[2])
            line:SetEndPoint("TOPLEFT", part.Color, tipX, -tipY)
            line:SetAlpha(alpha)
            line:Show()
        else
            line:Hide()
        end
        remaining = remaining - length
    end
    trace.tip:SetShown(drawn > 0 and drawn < 1 and alpha > 0)
    if drawn > 0 and drawn < 1 then
        trace.tip:ClearAllPoints()
        trace.tip:SetPoint("CENTER", part.Color, "TOPLEFT", tipX, -tipY)
        trace.tip:SetAlpha(alpha)
    end
end

local stepWindowSketch = function(host, sketch, progress)
    local time = progress * (host.windowDuration or 0)
    for _, part in ipairs(host.WindowParts or {}) do
        if part.paper then
            part.Ghost:SetAlpha(part.GhostAlpha * math.min(time / (sketch.Blank * 0.6), 1))
        else
            local elapsed = time - part.startTime
            local stroke = elapsed / part.drawTime
            if part.sliderPart == "rail" then stroke = stroke / 0.58
            elseif part.sliderPart == "fill" or part.sliderPart == "thumb" then stroke = (stroke - 0.44) / 0.56
            elseif part.fieldFill and sketch.Trace then stroke = (stroke - 0.25) / 0.75 end
            local drawn = windowStrokeProgress(part, stroke)
            local ink = math.max(0, math.min((elapsed - part.drawTime * (sketch.Loose and 0.82 or 1)) / part.inkTime, 1))
            local pencilAlpha = stroke > 0 and part.GhostAlpha * part.pressure * (1 - ink) or 0
            part.Ghost:SetAlpha(part.traceOutline and 0 or pencilAlpha)
            if sketch.Trace then
                part.Color:SetAlpha(ink > 0 and part.GhostAlpha or 0)
                if part.sliderPart == "rail" or part.sliderPart == "fill" then
                    part.Color:SetWidth(math.max(part.width * ink, 0.01))
                elseif part.ColorMask then
                    setMask(part.Color, part.ColorMask, ink < 1)
                    part.colorFrame = stepMask(part.ColorMask, part.sliderPart == "thumb" and sketch.OutlineFrames or sketch.Frames,
                        sketch.Count - math.min(math.floor(ink * sketch.Count), sketch.Count - 1), part.colorFrame)
                end
            else
                part.Color:SetAlpha(part.GhostAlpha * ink)
            end
            local frames = part.sliderPart == "thumb" and sketch.OutlineFrames or sketch.Frames
            if part.traceOutline then
                stepWindowOutline(part, drawn, pencilAlpha)
            elseif part.sliderPart == "rail" or part.sliderPart == "fill" then
                part.Ghost:SetWidth(math.max(part.width * drawn, 0.01))
            else
                part.dissolveFrame = stepMask(part.GhostDissolve, frames,
                    sketch.Count - math.min(math.floor(drawn * sketch.Count), sketch.Count - 1), part.dissolveFrame)
            end
            if part.Retrace then
                local retrace = windowStrokeProgress(part, (stroke - 0.6) / 0.4)
                part.Retrace:SetAlpha(not part.traceOutline and stroke > 0.6 and part.GhostAlpha * (sketch.Retrace or 0) * (1 - ink) or 0)
                if part.sliderPart == "rail" or part.sliderPart == "fill" then
                    part.Retrace:SetWidth(math.max(part.width * retrace, 0.01))
                else
                    part.retraceFrame = stepMask(part.RetraceMask, frames,
                        sketch.Count - math.min(math.floor(retrace * sketch.Count), sketch.Count - 1), part.retraceFrame)
                end
            end
        end
    end
    for _, label in ipairs(host.WindowLabels or {}) do
        local elapsed = time - label.startTime
        local drawn = windowStrokeProgress(label, elapsed / label.drawTime)
        label.clip:SetWidth(math.max(label.width * drawn, 0.01))
        label.clip:SetAlpha(elapsed > 0 and label.alpha or 0)
    end
end

-- Each window dissolve frame owns its bound mask. SetTexture on a visible mask can unload it for a frame.
local setupWindowDissolve = function(host, ghost, shaped)
    host.WindowDissolveFrames = host.WindowDissolveFrames or {}
    local parent = host.Ghost:GetParent()
    local dissolve = ghost.Dissolve
    for index = 1, dissolve.Count do
        local art = host.WindowDissolveFrames[index]
        if not art then
            art = {
                Color = parent:CreateTexture(nil, "ARTWORK"),
                Mask = parent:CreateMaskTexture(),
                Edge = parent:CreateTexture(nil, "OVERLAY", nil, 2),
            }
            art.Color:SetAllPoints(host.Ghost)
            art.Mask:SetAllPoints(art.Color)
            art.Edge:SetAllPoints(host.Ghost)
            art.Color:AddMaskTexture(art.Mask)
            host.WindowDissolveFrames[index] = art
        end
        for _, region in pairs(art) do region:SetParent(parent) end
        ThemeApply.Texture(art.Color, ghost)
        art.Mask:SetTexture(ThemeApply.File(dissolve.Frames .. index), "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        if dissolve.Edge then
            ThemeApply.Texture(art.Edge, dissolve.Edge)
            art.Edge:SetTexture(ThemeApply.File(dissolve.Frames .. "_edge" .. index))
        end
        setMask(art.Color, host.GhostShape, shaped)
        setMask(art.Edge, host.GhostShape, shaped)
        -- Keep these regions shown so their actual texture/mask bindings can load, without drawing them yet.
        art.Color:SetAlpha(0)
        art.Color:Show()
        art.Edge:SetAlpha(0)
        art.Edge:SetShown(dissolve.Edge ~= nil)
    end
    host.windowDissolve = true
end

local stepWindowDissolve = function(host, dissolve, progress)
    local index = math.min(math.floor(progress * dissolve.Count) + 1, dissolve.Count)
    local nextArt = host.WindowDissolveFrames[index]
    local function ready(region)
        return not region.IsObjectLoaded or region:IsObjectLoaded()
    end
    -- Check after Show has submitted the bindings to the client, rather than trusting hidden preload regions.
    if host.elapsed > 0 and ready(nextArt.Color) and ready(nextArt.Mask)
        and (not dissolve.Edge or ready(nextArt.Edge)) and index ~= host.dissolveFrame then
        local previous = host.windowDissolveActive
        if previous then
            previous.Color:SetAlpha(0)
            previous.Edge:SetAlpha(0)
        end
        host.windowDissolveActive = nextArt
        host.dissolveFrame = index
    end
    local active = host.windowDissolveActive
    if active then
        active.Color:SetAlpha(host.Ghost:GetAlpha())
        active.Edge:SetAlpha(dissolve.Edge and 1 - progress * progress or 0)
        host.Ghost:SetAlpha(0)
    end
end

---@param host Frame
---@param ghost table
---@param progress number
local stepGhost = function(host, ghost, progress)
    local scale = ghost.NativeScale and 1 or lerp(ghost.Scale, progress * progress, 1)
    host.Ghost:SetSize(math.max(host:GetWidth() * scale, 0.01), math.max(host:GetHeight() * scale, 0.01))
    local rise = ghost.Rise
    host.Ghost:SetPoint("CENTER", host, "CENTER", 0, type(rise) == "table" and lerp(rise, progress) or (rise or 0) * progress)
    host.Ghost:SetAlpha(lerp(ghost.Fade, progress, ghost.Dissolve and 1 or 1 - progress))
    host.GhostFlash:SetAlpha(ghost.FlashAlpha and ghost.FlashAlpha * (1 - progress) or math.sin(math.pi * progress))
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
    local sketch = ghost.Sketch
    if sketch and ghost.Source == "Window" then
        stepWindowSketch(host, sketch, progress)
    elseif sketch then
        stepSketch(host, sketch, progress)
    end
    local dissolve = ghost.Dissolve
    if dissolve and host.windowDissolve then
        stepWindowDissolve(host, dissolve, progress)
    elseif dissolve then
        local index = math.min(math.floor(progress * dissolve.Count) + 1, dissolve.Count)
        if index ~= host.dissolveFrame then
            host.dissolveFrame = index
            host.GhostDissolve:SetTexture(ThemeApply.File(dissolve.Frames .. index), "CLAMPTOBLACKADDITIVE",
                "CLAMPTOBLACKADDITIVE")
            host.GhostEdge:SetTexture(ThemeApply.File(dissolve.Frames .. "_edge" .. index))
        end
        host.GhostEdge:SetAlpha(1 - progress * progress)
    end
end

---@param host Frame
---@param flare table
---@param progress number
local stepFlare = function(host, flare, progress)
    local size = math.min(host:GetWidth(), host:GetHeight()) * lerp(flare.Size, 1 - (1 - progress) ^ 2, 1)
    host.Flare:SetSize(math.max(size, 0.01), math.max(size, 0.01))
    host.Flare:SetRotation(progress * flare.Time * (flare.Spin or 0))
    host.Flare:SetAlpha(math.sin(math.pi * progress))
end

---@param host Frame
---@param beam table
---@param progress number
local stepBeam = function(host, beam, progress)
    local width, height = host:GetWidth(), host:GetHeight()
    local above = height * (beam.Height or 2.4)
    local reach = 1 - (1 - math.min(progress / 0.35, 1)) ^ 3
    local fading = math.max((progress - 0.35) / 0.65, 0)
    host.Beam:SetPoint("TOP", host, "TOP", 0, above)
    host.Beam:SetSize(math.max(width * (beam.Width or 0.6) * (1 - fading * 0.6), 0.01),
        math.max((above + height / 2) * reach + height * 0.15, 0.01))
    host.Beam:SetAlpha(progress < 0.35 and math.min(progress / 0.12, 1) or 1 - fading)
end

---moves the pieces of a Vortex along their spirals, true once all of them arrived
---@param host Frame
---@param vortex table
---@return boolean
local stepVortex = function(host, vortex)
    local done = true
    local radius = math.max(host:GetWidth(), host:GetHeight()) * (vortex.Radius or 0.7)
    for _, piece in ipairs(host.Vortex) do
        if piece:IsShown() then
            local progress = (host.elapsed - piece.delay) / piece.time
            if progress >= 1 then
                piece:Hide()
            else
                done = false
                progress = math.max(progress, 0)
                -- slow far out, faster as it closes in
                local closed = progress ^ 1.6
                local distance = radius * piece.reach * (1 - closed)
                local angle = piece.angle + (vortex.Turns or 0.5) * 2 * math.pi * closed
                piece:SetPoint("CENTER", host, "CENTER", math.cos(angle) * distance, math.sin(angle) * distance)
                piece:SetRotation(vortex.Align and angle + math.pi or angle)
                local size = piece.size * (1 - 0.5 * closed)
                piece:SetSize(size, size)
                piece:SetAlpha(math.min(progress * 5, 1) * (1 - progress ^ 4))
            end
        end
    end
    return done
end

local stepHost = function(host, elapsed)
    local exit = host.exit
    host.elapsed = host.elapsed + elapsed
    local ghostDone, flareDone, beamDone = true, true, true
    local vortexDone = not exit.Vortex or stepVortex(host, exit.Vortex)
    if exit.Ghost then
        local progress = math.min(host.elapsed / (host.windowDuration or exit.Ghost.Time), 1)
        ghostDone = progress >= 1
        stepGhost(host, exit.Ghost, progress)
    end
    if exit.Flare then
        local progress = math.min(host.elapsed / exit.Flare.Time, 1)
        flareDone = progress >= 1
        stepFlare(host, exit.Flare, progress)
    end
    if exit.Beam then
        local progress = math.min(host.elapsed / exit.Beam.Time, 1)
        beamDone = progress >= 1
        stepBeam(host, exit.Beam, progress)
    end
    local crackTime = exit.Crack and exit.Crack.Time or 0
    if not host.shattered and host.elapsed >= crackTime then
        host.shattered = true
        host.Crack:Hide()
    end
    if exit.Burst and not host.burst and host.elapsed >= (exit.BurstDelay or crackTime) then
        host.burst = true
        host.Burst:Burst(exit.Burst)
    end
    local shards = exit.Shards
    local shardsDone = true
    if shards and host.shattered then
        local time = host.elapsed - crackTime
        shardsDone = time >= shards.Time
        for _, piece in ipairs(host.Shards) do
            piece.vy = piece.vy + (shards.Gravity or 0) * elapsed
            piece.x = piece.x + piece.vx * elapsed
            piece.y = piece.y + piece.vy * elapsed
            piece:SetPoint("BOTTOMLEFT", host, "BOTTOMLEFT", piece.x, piece.y)
            piece:SetAlpha(math.max(1 - time / shards.Time, 0))
        end
    end
    if host.shattered and (host.burst or not exit.Burst) and shardsDone and ghostDone and flareDone and beamDone and vortexDone
        and #host.Burst.particles == 0 then
        releaseHost(host)
    end
end

---a frame over where frame is drawn, or following frame while attach is set
---@param frame Frame
---@param attach boolean|nil
---@return Frame|nil
local acquireHost = function(frame, attach)
    local left, bottom, width, height = frame:GetRect()
    if not left and not attach then return end
    local host = table.remove(hosts)
    if not host then
        host = CreateFrame("Frame", nil, UIParent)
        host.Shards = {}
        host.Crack = host:CreateTexture(nil, "OVERLAY")
        host.Crack:SetAllPoints(host)
        host.Ghost = host:CreateTexture(nil, "ARTWORK")
        host.GhostBack = host:CreateTexture(nil, "ARTWORK", nil, -1)
        host.GhostBack:SetAllPoints(host.Ghost)
        host.GhostHatch = host:CreateMaskTexture()
        host.GhostHatch:SetAllPoints(host.Ghost)
        host.GhostOutline = host:CreateTexture(nil, "ARTWORK", nil, 1)
        host.GhostOutline:SetAllPoints(host.Ghost)
        host.GhostOutlineMask = host:CreateMaskTexture()
        host.GhostOutlineMask:SetAllPoints(host.Ghost)
        host.GhostOutline:AddMaskTexture(host.GhostOutlineMask)
        host.GhostFill = host:CreateMaskTexture()
        host.GhostFill:SetAllPoints(host.Ghost)
        host.GhostFlash = host:CreateTexture(nil, "OVERLAY", nil, 1)
        host.GhostFlash:SetAllPoints(host.Ghost)
        host.GhostEdge = host:CreateTexture(nil, "OVERLAY", nil, 2)
        host.GhostEdge:SetAllPoints(host.Ghost)
        host.GhostShape = host:CreateMaskTexture()
        host.GhostShape:SetAllPoints(host.Ghost)
        host.GhostDissolve = host:CreateMaskTexture()
        host.GhostDissolve:SetAllPoints(host.Ghost)
        host.Flare = host:CreateTexture(nil, "OVERLAY", nil, 3)
        host.Flare:SetPoint("CENTER")
        host.Beam = host:CreateTexture(nil, "OVERLAY", nil, 5)
        host.Vortex = {}
        host.Burst = private.CreateParticles(host, spawnInside(host))
        host:SetScript("OnUpdate", stepHost)
    end
    host:ClearAllPoints()
    if attach then
        host:SetAllPoints(frame)
    else
        local scale = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
        host:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left * scale, bottom * scale)
        host:SetSize(width * scale, height * scale)
        host.exitX, host.exitY = left * scale, bottom * scale
    end
    host.exitHorizontal = frame.timelineMotion and select(2, private.TimelineFrame.GetArrivalPoint())
    host:SetFrameStrata(frame:GetFrameStrata())
    host:SetFrameLevel(math.min(frame:GetFrameLevel() + 10, 9000))
    return host
end

---a piece of the host in the shape of the index-th shard mask, its Texture and its Edge
---@param host Frame
---@param index number
---@return Frame
local getPiece = function(host, index)
    local piece = host.Shards[index]
    if not piece then
        piece = CreateFrame("Frame", nil, host)
        piece.Texture = piece:CreateTexture(nil, "ARTWORK")
        piece.Texture:SetAllPoints(piece)
        piece.Edge = piece:CreateTexture(nil, "OVERLAY")
        piece.Edge:SetAllPoints(piece)
        piece.Mask = piece:CreateMaskTexture()
        piece.Mask:SetAllPoints(piece)
        piece.Mask:SetTexture(ThemeApply.File("shard" .. index), "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        piece.Texture:AddMaskTexture(piece.Mask)
        piece.Edge:AddMaskTexture(piece.Mask)
        host.Shards[index] = piece
    end
    return piece
end

---puts the shards together over the host, cut from icon's texture or the spec's, each flying away from the middle
---@param host Frame
---@param shards table
---@param icon Texture|nil
---@param iconFile any
local cutShards = function(host, shards, icon, iconFile)
    local left, right, top, bottom = 0, 1, 0, 1
    if shards.Source == "Icon" and icon then
        local ulx, uly, _, _, _, _, lrx, lry = icon:GetTexCoord()
        left, top, right, bottom = ulx, uly, lrx, lry
    end
    local middle = SHARD_SEEDS[1]
    for index, seed in ipairs(SHARD_SEEDS) do
        local piece = getPiece(host, index)
        if shards.Source == "Icon" then
            piece.Texture:SetTexture(iconFile)
            piece.Texture:SetBlendMode("BLEND")
            piece.Texture:SetVertexColor(1, 1, 1, 1)
        else
            ThemeApply.Texture(piece.Texture, shards)
        end
        piece.Texture:SetTexCoord(left, right, top, bottom)
        piece.Edge:SetShown(shards.Edge and ThemeApply.Texture(piece.Edge, shards.Edge) or false)
        setShape(piece, piece.Texture, shards.Mask)
        setShape(piece, piece.Edge, shards.Mask)
        piece:SetSize(host:GetWidth(), host:GetHeight())
        local speed = between(shards.Speed)
        piece.x, piece.y = 0, 0
        piece.vx = ((seed[1] - middle[1]) * 2 + (math.random() - 0.5) * 0.3) * speed
        piece.vy = ((middle[2] - seed[2]) * 2 + (math.random() - 0.5) * 0.3) * speed
        piece:SetAlpha(1)
        piece:ClearAllPoints()
        piece:SetPoint("BOTTOMLEFT", host, "BOTTOMLEFT", 0, 0)
        piece:Show()
    end
end

local isSecret = issecretvalue or function() return false end

local windowSketchRect = function(region)
    local left, bottom, width, height = region:GetRect()
    if isSecret(left) or isSecret(bottom) or isSecret(width) or isSecret(height) or not left then return end
    local scale = region:GetEffectiveScale()
    if isSecret(scale) then return end
    return { left = left * scale, bottom = bottom * scale, right = (left + width) * scale, top = (bottom + height) * scale }
end

local intersectWindowClip = function(rect, clip)
    if not rect then return false end
    if clip then
        rect.left, rect.bottom = math.max(rect.left, clip.left), math.max(rect.bottom, clip.bottom)
        rect.right, rect.top = math.min(rect.right, clip.right), math.min(rect.top, clip.top)
    end
    return rect.right > rect.left and rect.top > rect.bottom and rect or false
end

-- Keep the paper intact while copies of the contents are drawn, then hand back to the live window.
local setupWindowGhost = function(host, window, sketch)
    host.WindowFrames = host.WindowFrames or {}
    local frameIndex = 0
    local pencilR, pencilG, pencilB = ThemeApply.Color(sketch.Color)
    local shell = window.AtShell
    local edgeFile, fillFile = ThemeApply.File("panel_edge"), ThemeApply.File("panel")
    local groups, groupsByFrame = {}, {}
    local function queueStroke(item, source, count)
        local owner, ancestor = source, source
        while ancestor and ancestor ~= window do
            local widget = ancestor.obj
            if widget and widget.slider and widget.frame then owner = widget.frame; break end
            ancestor = ancestor:GetParent()
        end
        if owner == window or owner == shell then owner = item end
        local group = groupsByFrame[owner]
        if not group then
            group = {}
            groupsByFrame[owner] = group
            table.insert(groups, group)
        end
        table.insert(group, item)
        prepareWindowStroke(item, sketch, count)
    end
    local function copyTexture(texture, region, layer, sublevel)
        local file = region:GetTexture()
        if isSecret(file) or file then texture:SetTexture(file)
        else texture:SetColorTexture(1, 1, 1, 1) end
        texture:ClearTextureSlice()
        local l, t, r, b = region:GetTextureSliceMargins()
        if l then
            texture:SetTextureSliceMargins(l, t, r, b)
            texture:SetTextureSliceMode(region:GetTextureSliceMode())
        end
        texture:SetTexCoord(region:GetTexCoord())
        texture:SetRotation(region:GetRotation())
        texture:SetBlendMode(region:GetBlendMode())
        texture:SetDrawLayer(layer, sublevel)
        texture:ClearAllPoints()
        texture:SetAllPoints(region)
    end
    local function prepareOutline(part, region, art, r, g, b, a)
        local width, height = region:GetWidth(), region:GetHeight()
        if not art.CreateLine or isSecret(width) or isSecret(height) or width < 8 or height < 8 then return end
        local trace = part.Trace
        if not trace then
            trace = { lines = {}, tip = art:CreateTexture(nil, "OVERLAY") }
            trace.tip:SetTexture(ThemeApply.File("circle"))
            trace.tip:SetSize(2, 2)
            part.Trace = trace
        end
        local radius = math.min(4, width * 0.2, height * 0.2)
        trace.points = { { radius, 1 }, { width - radius, 1 }, { width - 1, radius },
            { width - 1, height - radius }, { width - radius, height - 1 }, { radius, height - 1 },
            { 1, height - radius }, { 1, radius }, { radius, 1 } }
        trace.lengths, trace.length, trace.drawn, trace.alpha = {}, 0, nil, nil
        for i = 1, #trace.points - 1 do
            local start, finish = trace.points[i], trace.points[i + 1]
            local length = math.sqrt((finish[1] - start[1]) ^ 2 + (finish[2] - start[2]) ^ 2)
            trace.lengths[i], trace.length = length, trace.length + length
            local line = trace.lines[i]
            if not line then line = art:CreateLine(nil, "OVERLAY"); trace.lines[i] = line end
            line:SetColorTexture(r, g, b, a)
            line:SetThickness(1.15 * part.pressure)
            line:Hide()
        end
        trace.tip:SetVertexColor(r, g, b, a)
        trace.tip:Hide()
        part.traceOutline = true
    end
    local function copyFrame(source, parent, clip)
        if not source:IsShown() then return end
        local sourceAlpha = source:GetAlpha()
        if not isSecret(sourceAlpha) and sourceAlpha <= 0 then return end
        local clipsChildren = source:DoesClipChildren()
        if clipsChildren then
            clip = intersectWindowClip(windowSketchRect(source), clip)
            if not clip then return end
        end
        frameIndex = frameIndex + 1
        local art = host.WindowFrames[frameIndex]
        if not art then
            art = CreateFrame("Frame", nil, host)
            art.Textures, art.Labels = {}, {}
            host.WindowFrames[frameIndex] = art
        end
        art:SetParent(parent)
        art:SetScale(source:GetEffectiveScale() / parent:GetEffectiveScale())
        art:ClearAllPoints()
        art:SetAllPoints(source)
        art:SetFrameLevel(math.min(host:GetFrameLevel() + 1 + source:GetFrameLevel() - window:GetFrameLevel(), 9000))
        art:SetAlpha(sourceAlpha)
        art:SetClipsChildren(clipsChildren)
        if art.ScrollClip then art.ScrollClip:Hide() end
        if art.EditText then art.EditText.clip:Hide() end
        local textureIndex, labelIndex, hasTextRegion = 0, 0, false
        for _, region in ipairs({ source:GetRegions() }) do
            local kind = region:GetObjectType()
            if region:IsShown() and (kind == "Texture" or kind == "FontString")
                and (not clip or intersectWindowClip(windowSketchRect(region), clip)) then
                local r, g, b, a
                if kind == "FontString" then r, g, b, a = region:GetTextColor()
                else r, g, b, a = region:GetVertexColor() end
                local regionAlpha = region:GetAlpha()
                local font, fontSize, flags
                if kind == "FontString" then font, fontSize, flags = region:GetFont() end
                if not (isSecret(r) or isSecret(g) or isSecret(b) or isSecret(a) or isSecret(regionAlpha))
                    and r and g and b and a and regionAlpha > 0 and a > 0 and (kind == "Texture" or font) then
                    local layer, sublevel = region:GetDrawLayer()
                    if kind == "Texture" then
                        textureIndex = textureIndex + 1
                        local part = art.Textures[textureIndex]
                        if not part then
                            part = { Color = art:CreateTexture(), Ghost = art:CreateTexture() }
                            part.GhostDissolve = art:CreateMaskTexture()
                            part.GhostHatch = art:CreateMaskTexture()
                            art.Textures[textureIndex] = part
                        end
                        local texture = part.Ghost
                        if part.Trace then
                            for _, line in ipairs(part.Trace.lines) do line:Hide() end
                            part.Trace.tip:Hide()
                        end
                        part.traceOutline = false
                        if part.ColorMask then setMask(part.Color, part.ColorMask, false) end
                        local file = region:GetTexture()
                        local field = source.AtField
                        part.fieldFill = region == source.AtFill or (field and region == field.Fill)
                            or (not isSecret(file) and file == fillFile)
                        local outline = region == source.AtEdge or (field and region == field.Edge)
                            or (not isSecret(file) and file == edgeFile)
                        local slider = source.obj and source.obj.slider == source and source
                        part.sliderPart = sketch.Loose and slider and (region == slider.AtTrack and "rail"
                            or region == slider.AtFillBar and "fill" or region == slider:GetThumbTexture() and "thumb") or nil
                        part.paper = shell and (region == shell.Fill or region == shell.Grain or region == shell.Shadow
                            or region == shell.Edge or region == shell.EdgeArt) or false
                        copyTexture(texture, region, layer, sublevel)
                        part.GhostAlpha, part.dissolveFrame = regionAlpha, nil
                        local linear = part.sliderPart == "rail" or part.sliderPart == "fill"
                        setMask(texture, part.GhostDissolve, not part.paper and not linear)
                        setMask(texture, part.GhostHatch, not part.paper and not part.sliderPart)
                        part.GhostDissolve:SetAllPoints(texture)
                        part.GhostHatch:SetAllPoints(texture)
                        if part.paper then
                            texture:SetVertexColor(r, g, b, a)
                            texture:SetDesaturation(region:GetDesaturation())
                            part.Color:Hide()
                        else
                            queueStroke(part, source, sketch.Count)
                            local flipX, flipY = math.random(0, 1) == 1, math.random(0, 1) == 1
                            part.GhostDissolve:SetTexCoord(flipX and 1 or 0, flipX and 0 or 1, flipY and 1 or 0, flipY and 0 or 1)
                            part.GhostHatch:SetTexCoord(flipX and 1 or 0, flipX and 0 or 1, flipY and 1 or 0, flipY and 0 or 1)
                            local gray = r * 0.2126 + g * 0.7152 + b * 0.0722
                            texture:SetVertexColor(gray * pencilR, gray * pencilG, gray * pencilB, a)
                            texture:SetDesaturated(true)
                            texture:SetBlendMode("BLEND")
                            part.GhostHatch:SetTexture(ThemeApply.File(sketch.Hatch), "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
                            copyTexture(part.Color, region, layer, sublevel)
                            part.Color:SetVertexColor(r, g, b, a)
                            part.Color:SetDesaturation(region:GetDesaturation())
                            part.Color:SetAlpha(0)
                            part.Color:Show()
                            if sketch.Trace then
                                if linear then
                                    part.Color:ClearAllPoints()
                                    part.Color:SetPoint("LEFT", region, "LEFT", 0, 0)
                                    part.Color:SetSize(0.01, region:GetHeight())
                                else
                                    part.ColorMask = part.ColorMask or art:CreateMaskTexture()
                                    part.ColorMask:SetAllPoints(part.Color)
                                    part.ColorMask:SetTexCoord(flipX and 1 or 0, flipX and 0 or 1, flipY and 1 or 0, flipY and 0 or 1)
                                    setMask(part.Color, part.ColorMask, true)
                                    part.colorFrame = nil
                                end
                                if outline and not part.sliderPart then
                                    prepareOutline(part, region, art, gray * pencilR, gray * pencilG, gray * pencilB, a)
                                end
                            end
                            if sketch.Loose then
                                if not part.Retrace then
                                    part.Retrace = art:CreateTexture()
                                    part.RetraceMask = art:CreateMaskTexture()
                                end
                                copyTexture(part.Retrace, region, layer, sublevel)
                                part.Retrace:SetVertexColor(gray * pencilR, gray * pencilG, gray * pencilB, a)
                                part.Retrace:SetDesaturated(true)
                                part.Retrace:SetBlendMode("BLEND")
                                setMask(part.Retrace, part.RetraceMask, not linear)
                                part.RetraceMask:SetAllPoints(part.Retrace)
                                part.RetraceMask:SetTexCoord(flipX and 0 or 1, flipX and 1 or 0, flipY and 0 or 1, flipY and 1 or 0)
                                part.retraceFrame = nil
                                if part.sliderPart == "thumb" then
                                    texture:SetTexture(ThemeApply.File("ring"))
                                    part.Retrace:SetTexture(ThemeApply.File("ring"))
                                elseif linear then
                                    part.width = region:GetWidth()
                                    for _, stroke in ipairs({ texture, part.Retrace }) do
                                        stroke:ClearAllPoints()
                                        stroke:SetPoint("LEFT", region, "LEFT", 0, stroke == texture and 0 or 0.6)
                                        stroke:SetSize(0.01, math.min(region:GetHeight(), stroke == texture and 1.3 or 0.8))
                                    end
                                end
                                part.Retrace:SetAlpha(0)
                                part.Retrace:Show()
                            end
                        end
                        if part.Retrace and (part.paper or not sketch.Loose) then part.Retrace:Hide() end
                        texture:SetAlpha(0)
                        texture:Show()
                        table.insert(host.WindowParts, part)
                    else
                        hasTextRegion = true
                        labelIndex = labelIndex + 1
                        local label = art.Labels[labelIndex]
                        if not label then
                            local clip = CreateFrame("Frame", nil, art)
                            clip:SetClipsChildren(true)
                            label = { clip = clip, texture = clip:CreateFontString() }
                            art.Labels[labelIndex] = label
                        end
                        local text = label.texture
                        text:SetFont(font, fontSize, flags)
                        text:SetText(region:GetText())
                        text:SetTextColor(r, g, b, a)
                        text:SetJustifyH(region:GetJustifyH())
                        text:SetJustifyV(region:GetJustifyV())
                        text:SetSpacing(region:GetSpacing())
                        text:SetShadowColor(region:GetShadowColor())
                        text:SetShadowOffset(region:GetShadowOffset())
                        text:SetDrawLayer(layer, sublevel)
                        text:ClearAllPoints()
                        text:SetAllPoints(region)
                        text:Show()
                        local textWidth = region:GetStringWidth()
                        if isSecret(textWidth) then textWidth = region:GetWidth() end
                        label.width = math.max(0.01, math.min(region:GetWidth(), textWidth + 2))
                        local justify = region:GetJustifyH()
                        local offset = justify == "RIGHT" and region:GetWidth() - label.width
                            or justify == "CENTER" and (region:GetWidth() - label.width) / 2 or 0
                        label.clip:ClearAllPoints()
                        label.clip:SetPoint("TOPLEFT", region, "TOPLEFT", offset, 0)
                        label.clip:SetSize(0.01, math.max(region:GetHeight(), 0.01))
                        label.clip:SetFrameLevel(art:GetFrameLevel() + 1)
                        label.clip:SetAlpha(0)
                        label.clip:Show()
                        label.alpha = regionAlpha
                        queueStroke(label, source, math.max(8, math.min(28, math.ceil(label.width / (fontSize * 0.45)))))
                        table.insert(host.WindowLabels, label)
                    end
                end
            end
        end
        -- EditBox renders its value internally rather than necessarily exposing a FontString region.
        if source:GetObjectType() == "EditBox" and not hasTextRegion
            and (not clip or intersectWindowClip(windowSketchRect(source), clip)) then
            local font, size, flags = source:GetFont()
            local r, g, b, a = source:GetTextColor()
            if font and not (isSecret(r) or isSecret(g) or isSecret(b) or isSecret(a)) then
                local label = art.EditText
                if not label then
                    local clip = CreateFrame("Frame", nil, art)
                    clip:SetClipsChildren(true)
                    label = { clip = clip, texture = clip:CreateFontString(nil, "OVERLAY") }
                    art.EditText = label
                end
                local l, rInset, t, bInset = source:GetTextInsets()
                local text = label.texture
                text:SetFont(font, size, flags)
                text:SetText(source:GetText())
                text:SetTextColor(r, g, b, a)
                text:SetJustifyH(source:GetJustifyH())
                text:SetJustifyV(source:GetJustifyV())
                text:ClearAllPoints()
                text:SetPoint("TOPLEFT", source, "TOPLEFT", l, -t)
                text:SetPoint("BOTTOMRIGHT", source, "BOTTOMRIGHT", -rInset, bInset)
                text:Show()
                label.width, label.alpha = math.max(source:GetWidth() - l - rInset, 0.01), 1
                label.clip:ClearAllPoints()
                label.clip:SetPoint("TOPLEFT", source, "TOPLEFT", l, -t)
                label.clip:SetSize(0.01, math.max(source:GetHeight() - t - bInset, 0.01))
                label.clip:SetFrameLevel(art:GetFrameLevel() + 1)
                label.clip:SetAlpha(0)
                label.clip:Show()
                queueStroke(label, source, math.max(8, math.min(28, math.ceil(label.width / (size * 0.45)))))
                table.insert(host.WindowLabels, label)
            end
        end
        for i = textureIndex + 1, #art.Textures do
            art.Textures[i].Ghost:Hide()
            art.Textures[i].Color:Hide()
            if art.Textures[i].Retrace then art.Textures[i].Retrace:Hide() end
            if art.Textures[i].Trace then
                for _, line in ipairs(art.Textures[i].Trace.lines) do line:Hide() end
                art.Textures[i].Trace.tip:Hide()
            end
        end
        for i = labelIndex + 1, #art.Labels do art.Labels[i].clip:Hide() end
        art:Show()
        local scrollChild = source:GetObjectType() == "ScrollFrame" and source:GetScrollChild()
        for _, child in ipairs({ source:GetChildren() }) do
            if child == scrollChild then
                local viewport = intersectWindowClip(windowSketchRect(source), clip)
                if viewport then
                    local scrollClip = art.ScrollClip
                    if not scrollClip then
                        scrollClip = CreateFrame("Frame", nil, art)
                        scrollClip:SetClipsChildren(true)
                        art.ScrollClip = scrollClip
                    end
                    scrollClip:SetAllPoints(source)
                    scrollClip:SetFrameLevel(art:GetFrameLevel())
                    scrollClip:Show()
                    copyFrame(child, scrollClip, viewport)
                end
            else
                copyFrame(child, art, clip)
            end
        end
    end
    copyFrame(window, host)
    -- Shuffle controls as groups so their borders and lettering stay together while the pen jumps around the sheet.
    for i = #groups, 2, -1 do
        local j = math.random(i)
        groups[i], groups[j] = groups[j], groups[i]
    end
    local cursor, finish = sketch.Blank, sketch.Blank
    for _, group in ipairs(groups) do
        local duration = 0
        for _, item in ipairs(group) do
            item.startTime = cursor
            duration = math.max(duration, item.drawTime + item.inkTime)
        end
        group.startTime, group.duration = cursor, duration
        finish = math.max(finish, cursor + duration + sketch.Gap)
        cursor = cursor + duration * (1 - (sketch.Overlap or 0)) + sketch.Gap
    end
    cursor = finish
    if sketch.MaxTime and cursor > sketch.MaxTime then
        local speed = (sketch.MaxTime - sketch.Blank) / (cursor - sketch.Blank)
        for _, group in ipairs(groups) do
            group.startTime = sketch.Blank + (group.startTime - sketch.Blank) * speed
            group.duration = group.duration * speed
            for _, item in ipairs(group) do
                item.startTime = group.startTime
                item.drawTime, item.inkTime = item.drawTime * speed, item.inkTime * speed
            end
        end
        cursor = sketch.MaxTime
    end
    host.WindowGroups, host.windowDuration = groups, cursor
    stepWindowSketch(host, sketch, 0)
    host.windowSource, host.windowAlpha = window, window:GetAlpha()
    window:SetAlpha(0)
end

---sets up the Ghost of an exit on the host, an image of the icon or the spec's texture
---@param host Frame
---@param ghost table
---@param icon Texture|nil
---@param iconFile any
local setupGhost = function(host, ghost, icon, iconFile, frame)
    local texture = host.Ghost
    local sketch = ghost.Sketch
    if ghost.Source == "Window" then
        texture:SetTexture(nil)
        texture:ClearTextureSlice()
        host:SetFrameLevel(math.min((frame.GetHighestFrameLevel and frame:GetHighestFrameLevel(true) or frame:GetFrameLevel() + 50) + 10, 9000))
    elseif ghost.Source == "Icon" and icon then
        texture:SetTexture(iconFile)
        texture:ClearTextureSlice()
        texture:SetBlendMode("BLEND")
        -- a sketch of the icon: its shading in the pencil's color
        texture:SetVertexColor(ThemeApply.Color(sketch and sketch.Color))
        texture:SetTexCoord(icon:GetTexCoord())
    else
        ThemeApply.Texture(texture, ghost)
    end
    texture:SetDesaturated(sketch ~= nil and ghost.Source == "Icon")
    host.GhostBack:SetShown(sketch and sketch.Back and true or false)
    if sketch and sketch.Back then
        host.GhostBack:SetColorTexture(ThemeApply.Color(sketch.Back))
    end
    if sketch and sketch.Hatch then
        host.GhostHatch:SetTexture(ThemeApply.File(sketch.Hatch), "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    end
    setMask(texture, host.GhostHatch, sketch ~= nil and sketch.Hatch ~= nil)
    host.GhostOutline:SetShown(sketch and sketch.Outline and ThemeApply.Texture(host.GhostOutline, sketch.Outline) or false)
    host.dissolveFrame, host.outlineFrame, host.fillFrame = nil, nil, nil
    local fill = sketch and sketch.Fill ~= nil
    for _, layer in ipairs({ texture, host.GhostBack, host.GhostOutline }) do
        setMask(layer, host.GhostFill, fill)
    end
    texture:ClearAllPoints()
    host.GhostFlash:SetShown(ghost.Flash and ThemeApply.Texture(host.GhostFlash, ghost.Flash) or false)
    local shaped = ghost.Mask and ThemeApply.Mask(host.GhostShape,
        type(ghost.Mask) == "table" and ghost.Mask or { File = ghost.Mask }) or false
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
    for _, key in ipairs({ "Ghost", "GhostFlash", "GhostBack", "GhostOutline", "GhostEdge", "GhostShape",
        "GhostDissolve", "GhostOutlineMask", "GhostFill", "GhostHatch", "GhostOverlay" }) do
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
                label:SetText(source:GetText())
                label:SetTextColor(source:GetTextColor())
                label:SetScale(scale)
                label:ClearAllPoints()
                label:SetPoint(anchor[1], host, anchor[2], anchor[3], anchor[4])
                label:Show()
            end
        end
    end
    local dissolve = ghost.Dissolve
    local windowDissolve = dissolve and frame.atWindowStyle and ghost.Source ~= "Icon" and not ghost.Sketch and not ghost.Flash
    host.GhostEdge:SetShown(not windowDissolve and dissolve and dissolve.Edge and ThemeApply.Texture(host.GhostEdge, dissolve.Edge) or false)
    for _, layer in ipairs({ texture, host.GhostFlash, host.GhostEdge, host.GhostBack, host.GhostOutline }) do
        setMask(layer, host.GhostShape, shaped and (layer ~= host.GhostFlash or ghost.FlashMask ~= false))
    end
    setMask(texture, host.GhostDissolve, not windowDissolve and (dissolve ~= nil or sketch ~= nil))
    setMask(host.GhostFlash, host.GhostDissolve, not windowDissolve and dissolve ~= nil)
    if windowDissolve then setupWindowDissolve(host, ghost, shaped) end
    stepGhost(host, ghost, 0)
    if ghost.Source == "Window" and sketch then setupWindowGhost(host, frame, sketch) end
end

---sets up the pieces of a Vortex on the host, each starting somewhere on the ring at its own time
---@param host Frame
---@param vortex table|nil
local setupVortex = function(host, vortex)
    for _, piece in ipairs(host.Vortex) do
        piece:Hide()
    end
    if not vortex then return end
    local textures = vortex.Texture
    for i = 1, vortex.Count do
        local piece = host.Vortex[i]
        if not piece then
            piece = host:CreateTexture(nil, "OVERLAY", nil, 4)
            host.Vortex[i] = piece
        end
        piece:SetTexture(type(textures) == "table" and textures[math.random(#textures)] or textures)
        piece:SetBlendMode("ADD")
        piece:SetVertexColor(ThemeApply.Color(vortex.Colors[math.random(#vortex.Colors)]))
        piece.delay = math.random() * vortex.Time * 0.3
        piece.time = vortex.Time * (0.75 + math.random() * 0.25)
        piece.reach = 0.85 + math.random() * 0.3
        piece.angle = vortex.Angle and math.rad(between(vortex.Angle)) or math.random() * 2 * math.pi
        piece.size = between(vortex.Size)
        piece:SetAlpha(0)
        piece:Show()
    end
end

---plays an Exit spec where frame is drawn, call it before hiding the frame
---@param frame Frame
---@param exit table|nil
---@param icon Texture|nil -- the texture shards with Source "Icon" are cut from
---@param iconFile any -- the file icon shows
---@param attach boolean|nil -- follows frame, for effects of a frame that stays
---@return number -- how long the exit plays, 0 when it doesn't
---@return Frame|nil -- the pooled effect host
ThemeApply.PlayExit = function(frame, exit, icon, iconFile, attach, state)
    if exit and exit.Finished then
        exit = (state == nil or state == private.manager.STATES.Finished) and exit.Finished or exit.Canceled
    end
    if not exit or not private.AmbientEffectsEnabled() then return 0 end
    local host = acquireHost(frame, attach)
    if not host then return 0 end
    host.exit = exit
    host.elapsed = 0
    host.shattered = false
    host.burst = false
    host.windowDuration, host.WindowGroups = nil, nil
    host.windowDissolve, host.windowDissolveActive = nil, nil
    for _, art in ipairs(host.WindowDissolveFrames or {}) do
        art.Color:Hide()
        art.Edge:Hide()
    end
    for _, art in ipairs(host.WindowFrames or {}) do art:Hide() end
    host.WindowParts, host.WindowLabels = {}, {}
    for _, piece in ipairs(host.Shards) do
        piece:Hide()
    end
    if exit.Shards then
        cutShards(host, exit.Shards, icon, iconFile)
    end
    host.Crack:SetShown(exit.Crack and ThemeApply.Texture(host.Crack, exit.Crack) or false)
    setShape(host, host.Crack, exit.Crack and exit.Crack.Mask)
    host.Ghost:SetShown(exit.Ghost ~= nil)
    if exit.Ghost then
        setupGhost(host, exit.Ghost, icon, iconFile, frame)
    else
        host.GhostFlash:Hide()
        host.GhostEdge:Hide()
        host.GhostBack:Hide()
        host.GhostOutline:Hide()
        if host.GhostOverlay then host.GhostOverlay:Hide() end
        for _, label in ipairs(host.ExitLabels or {}) do label:Hide() end
    end
    host.Flare:SetShown(exit.Flare and ThemeApply.Texture(host.Flare, exit.Flare) or false)
    if exit.Flare then
        stepFlare(host, exit.Flare, 0)
    end
    host.Beam:SetShown(exit.Beam and ThemeApply.Texture(host.Beam, exit.Beam) or false)
    if exit.Beam then
        stepBeam(host, exit.Beam, 0)
    end
    setupVortex(host, exit.Vortex)
    host:Show()
    local crackTime = exit.Crack and exit.Crack.Time or 0
    return math.max(crackTime + (exit.Shards and exit.Shards.Time or 0),
        exit.Burst and (exit.BurstDelay or crackTime) + exit.Burst.Life[2] or 0, host.windowDuration or (exit.Ghost and exit.Ghost.Time or 0),
        exit.Flare and exit.Flare.Time or 0, exit.Beam and exit.Beam.Time or 0, exit.Vortex and exit.Vortex.Time or 0), host
end
