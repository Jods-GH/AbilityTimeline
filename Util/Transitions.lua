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
    if not enter or not private.AmbientEffectsEnabled() then return end
    if enter.Ghost or enter.Flare or enter.Vortex or enter.Beam then
        ThemeApply.PlayExit(frame, { Ghost = enter.Ghost, Flare = enter.Flare, Vortex = enter.Vortex, Beam = enter.Beam },
            icon, iconFile, true)
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
    if host.GhostScale then host.GhostScale:Stop() end
    host.Burst:Stop()
    for _, piece in ipairs(host.Shards) do
        piece:Hide()
    end
    host:Hide()
    table.insert(hosts, host)
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
    if sketch then
        -- drawn in stroke by stroke, the dissolve's masks backwards, then the drawing and its sheet fade together or
        -- go along the fill's masks
        local draw, from = sketch.Draw or 0.6, sketch.From or 0
        local count = sketch.Count or 12
        host.dissolveFrame = stepMask(host.GhostDissolve, sketch.Frames,
            count - math.min(math.floor(math.max(progress - from, 0) / (draw - from) * count), count - 1), host.dissolveFrame)
        local outline = sketch.Outline
        if outline then
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
        for _, layer in ipairs({ host.Ghost, host.GhostBack, host.GhostOutline }) do
            layer:SetAlpha(alpha)
        end
    end
    local dissolve = ghost.Dissolve
    if dissolve then
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
        local progress = math.min(host.elapsed / exit.Ghost.Time, 1)
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

---sets up the Ghost of an exit on the host, an image of the icon or the spec's texture
---@param host Frame
---@param ghost table
---@param icon Texture|nil
---@param iconFile any
local setupGhost = function(host, ghost, icon, iconFile, frame)
    local texture = host.Ghost
    local sketch = ghost.Sketch
    if ghost.Source == "Icon" and icon then
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
    host.GhostEdge:SetShown(dissolve and dissolve.Edge and ThemeApply.Texture(host.GhostEdge, dissolve.Edge) or false)
    for _, layer in ipairs({ texture, host.GhostFlash, host.GhostEdge, host.GhostBack, host.GhostOutline }) do
        setMask(layer, host.GhostShape, shaped and (layer ~= host.GhostFlash or ghost.FlashMask ~= false))
    end
    setMask(texture, host.GhostDissolve, dissolve ~= nil or sketch ~= nil)
    setMask(host.GhostFlash, host.GhostDissolve, dissolve ~= nil)
    stepGhost(host, ghost, 0)
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
        exit.Burst and (exit.BurstDelay or crackTime) + exit.Burst.Life[2] or 0, exit.Ghost and exit.Ghost.Time or 0,
        exit.Flare and exit.Flare.Time or 0, exit.Beam and exit.Beam.Time or 0, exit.Vortex and exit.Vortex.Time or 0)
end
