local appName, app = ...
---@class AbilityTimeline
local private = app
local ThemeApply = private.ThemeApply

-- the effects of Enter and Exit specs, they only play while ambient effects are enabled.
-- every texture spec may have a Mask (a texture of Media/Textures/Theme), e.g. the shape of a masked icon
-- Enter: Burst (a particle spec with Count), Ghost, Flare and Vortex as in Exit, following the frame (a Ghost of the theme's color
-- dissolving away reveals the frame below it)
-- Exit: Crack (a texture spec shown for Crack.Time), Shards (Source = "Icon" or a texture spec, Edge: a texture spec
-- drawn over every shard, Speed, Gravity, Time), Burst (flung once the crack breaks, or after BurstDelay seconds), Ghost
-- and Flare. Exits draw on their own frame so the frame they leave can be hidden right away
-- Ghost: an image of the leaving frame (Source = "Icon" or a texture spec) playing over Time: Scale = { from, to },
-- Rise (pixels it moves up, or { from, to } to come down into place), Fade = { from, to } (it fades out unless it
-- dissolves), Flash (a texture spec flaring up
-- over it and fading), Dissolve = { Frames, Count, Edge } eats it away along the masks <Frames>1..<Count> while Edge
-- (a texture spec) glows along <Frames>_edge1..<Count>. Theme-specific ghost behavior is registered by its theme.
-- Flare: a texture spec over the middle growing from Size[1] to Size[2] times the frame's smaller side, turning by
-- Spin per second, flaring up and fading over Time
-- Effect: a theme-owned implementation with Behavior and Time, set up and stepped on the pooled host
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

---plays the effects of an Enter spec on frame
---@param frame Frame
---@param enter table|nil
---@param icon Texture|nil -- the texture a Ghost with Source "Icon" shows
---@param iconFile any -- the file icon shows
ThemeApply.PlayEnterEffects = function(frame, enter, icon, iconFile)
    ThemeApply.StopEnterEffects(frame)
    if not enter or not private.AmbientEffectsEnabled() then return end
    local effect = ThemeApply.GetTransitionEffect(enter)
    local ghost = enter.Ghost
    if ghost or enter.Flare or enter.Vortex or effect then
        local _, host = ThemeApply.PlayExit(frame, { Ghost = ghost, Flare = enter.Flare, Vortex = enter.Vortex, Effect = effect },
            icon, iconFile, true)
        if host then
            frame.AtEnterHost = host
            host.enterFrame = frame
        end
    end
    if not enter.Burst then return end
    local layer = frame.AtEnterLayer
    if not layer then
        layer = CreateFrame("Frame", nil, frame)
        layer:SetAllPoints(frame)
        layer.Burst = private.CreateParticles(layer, spawnInside(layer))
        frame.AtEnterLayer = layer
    end
    layer:SetFrameLevel(math.min(frame:GetFrameLevel() + 50, 9000))
    layer.Burst:Burst(enter.Burst)
end

ThemeApply.SetTransitionShape = setShape

local hosts = {}

local hideComposite = function(textures)
    for _, texture in ipairs(textures or {}) do texture:Hide() end
end

local releaseHost = function(host)
    if host.ghostBehavior and host.ghostBehavior.ResetGhost then host.ghostBehavior.ResetGhost(host) end
    if host.effectBehavior and host.effectBehavior.ResetEffect then host.effectBehavior.ResetEffect(host) end
    if host.enterFrame then
        host.enterFrame.AtEnterHost = nil
        host.enterFrame = nil
    end
    host.Burst:Stop()
    hideComposite(host.GhostSlices)
    for _, piece in ipairs(host.Shards) do
        hideComposite(piece.IconSlices)
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

ThemeApply.SetTransitionMask = setMask

-- Snapshot the image before its widgets return to the pool. Merge slices divide the icon horizontally. Nothing is read
-- back from them, an encounter's textures and their geometry can be secret: the files and crops set on them are kept.
local snapshotIcon = function(frame)
    local count = frame.mergeKey and frame.atMergeCount
    if not count or not frame.MergeSlices then return end
    local slices = {}
    for i = 1, count do
        local source = frame.MergeSlices[i]
        table.insert(slices, { file = source.atFile, coords = source.atCoords, x = (i - 1) / count, width = 1 / count })
    end
    -- the separators are the theme's, centred on the cuts like on the icon
    local spec = private.GetElementStyle("SpellIcon").MergeSeparator
    local share = spec.Width / ThemeApply.IconSize(frame)
    for i = 1, count - 1 do
        table.insert(slices, { spec = spec, x = i / count - share / 2, width = share, separator = true })
    end
    return slices
end

-- All image pieces follow one full-icon control texture and its full-icon masks, rather than separate effects. The
-- control's size and alpha are passed in as they were set, it may have shown an encounter's texture. Its draw layer
-- is the ARTWORK it was created on for the same reason.
local drawComposite = function(holder, key, control, slices, shardMask, width, height, alpha)
    if not slices then hideComposite(holder[key]); return end
    holder[key] = holder[key] or {}
    local shape = control.atShaped and holder.AtShape
    for i, slice in ipairs(slices) do
        local texture = holder[key][i]
        if not texture then
            texture = control:GetParent():CreateTexture()
            holder[key][i] = texture
        end
        if texture.source ~= slice then
            for mask in pairs(texture.atMasks or {}) do setMask(texture, mask, false) end
            texture:SetParent(control:GetParent())
            if slice.spec then
                ThemeApply.Texture(texture, slice.spec)
            else
                texture:SetTexture(slice.file)
                texture:SetTexCoord(unpack(slice.coords or { 0, 1, 0, 1 }))
                texture:ClearTextureSlice()
                texture:SetVertexColor(1, 1, 1, 1)
                texture:SetBlendMode("BLEND")
            end
            texture:SetDesaturated(false)
            texture:ClearAllPoints()
            texture.source = slice
        end
        texture:SetDrawLayer("ARTWORK", slice.separator and 1 or 0)
        texture:SetPoint("TOPLEFT", control, "TOPLEFT", width * slice.x, 0)
        texture:SetSize(width * slice.width, height)
        texture:SetAlpha(alpha)
        for mask in pairs(texture.atMasks or {}) do
            if mask ~= shardMask and mask ~= shape and not (control.atMasks and control.atMasks[mask]) then
                setMask(texture, mask, false)
            end
        end
        for mask, enabled in pairs(control.atMasks or {}) do setMask(texture, mask, enabled) end
        if shardMask then setMask(texture, shardMask, true) end
        if shape then setMask(texture, shape, true) end
        texture:Show()
    end
    for i = #slices + 1, #holder[key] do holder[key][i]:Hide() end
end

local lerp = function(range, progress, default)
    if not range then return default end
    return range[1] + (range[2] - range[1]) * progress
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
    local scale = host.ghostBehavior and host.ghostBehavior.GetGhostScale and host.ghostBehavior.GetGhostScale(ghost, progress)
        or lerp(ghost.Scale, progress * progress, 1)
    local width, height = math.max(host:GetWidth() * scale, 0.01), math.max(host:GetHeight() * scale, 0.01)
    host.Ghost:SetSize(width, height)
    local rise = ghost.Rise
    host.Ghost:SetPoint("CENTER", host, "CENTER", 0, type(rise) == "table" and lerp(rise, progress) or (rise or 0) * progress)
    local alpha = lerp(ghost.Fade, progress, ghost.Dissolve and 1 or 1 - progress)
    host.Ghost:SetAlpha(alpha)
    host.GhostFlash:SetAlpha(math.sin(math.pi * progress))
    if host.ghostBehavior and host.ghostBehavior.StepGhost then
        host.ghostBehavior.StepGhost(host, ghost, progress)
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
    drawComposite(host, "GhostSlices", host.Ghost, ghost.Source == "Icon" and host.iconSlices or nil, nil, width, height, alpha)
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
    local ghostDone, flareDone, effectDone = true, true, true
    local vortexDone = not exit.Vortex or stepVortex(host, exit.Vortex)
    if exit.Ghost then
        local progress = math.min(host.elapsed / (host.ghostDuration or exit.Ghost.Time), 1)
        ghostDone = progress >= 1
        stepGhost(host, exit.Ghost, progress)
    end
    if exit.Flare then
        local progress = math.min(host.elapsed / exit.Flare.Time, 1)
        flareDone = progress >= 1
        stepFlare(host, exit.Flare, progress)
    end
    if host.effectBehavior then
        local progress = math.min(host.elapsed / host.effectSpec.Time, 1)
        effectDone = progress >= 1
        host.effectBehavior.StepEffect(host, host.effectSpec, progress)
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
    if host.shattered and (host.burst or not exit.Burst) and shardsDone and ghostDone and flareDone and effectDone and vortexDone
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
    end
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
    -- the crop set on the icon, never read back from an image that may show an encounter's texture
    if shards.Source == "Icon" and icon and icon.atCrop then
        left, right, top, bottom = unpack(icon.atCrop)
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
        if shards.Source == "Icon" and host.iconSlices then
            piece.Texture:SetTexture(nil)
            drawComposite(piece, "IconSlices", piece.Texture, host.iconSlices, piece.Mask, host:GetWidth(), host:GetHeight(), 1)
        end
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
    if ghost.Source == "Icon" and icon then
        texture:SetTexture(iconFile)
        texture:ClearTextureSlice()
        texture:SetBlendMode("BLEND")
        texture:SetVertexColor(ThemeApply.Color())
        texture:SetTexCoord(unpack(icon.atCrop or { 0, 1, 0, 1 }))
    else
        ThemeApply.Texture(texture, ghost)
    end
    texture:SetDesaturated(false)
    host.dissolveFrame = nil
    texture:ClearAllPoints()
    host.GhostFlash:SetShown(ghost.Flash and ThemeApply.Texture(host.GhostFlash, ghost.Flash) or false)
    local shaped = ghost.Mask and ThemeApply.Mask(host.GhostShape,
        type(ghost.Mask) == "table" and ghost.Mask or { File = ghost.Mask }) or false
    local dissolve = ghost.Dissolve
    local windowDissolve = dissolve and frame.atWindowStyle and ghost.Source ~= "Icon" and not ghost.Flash
    host.GhostEdge:SetShown(not windowDissolve and dissolve and dissolve.Edge and ThemeApply.Texture(host.GhostEdge, dissolve.Edge) or false)
    for _, layer in ipairs({ texture, host.GhostFlash, host.GhostEdge }) do
        setMask(layer, host.GhostShape, shaped)
    end
    setMask(texture, host.GhostDissolve, not windowDissolve and dissolve ~= nil)
    setMask(host.GhostFlash, host.GhostDissolve, not windowDissolve and dissolve ~= nil)
    if windowDissolve then setupWindowDissolve(host, ghost, shaped) end
    if host.ghostBehavior and host.ghostBehavior.SetupGhost then
        host.ghostBehavior.SetupGhost(host, ghost, icon, iconFile, frame)
    end
    if ghost.Source == "Icon" and host.iconSlices then texture:SetTexture(nil) end
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
---@return Frame|nil -- the pooled effect host
ThemeApply.PlayExit = function(frame, exit, icon, iconFile, attach, state)
    local behavior = ThemeApply.GetBehavior(exit)
    if behavior and behavior.SelectExit then exit = behavior.SelectExit(exit, state) end
    if not exit or not private.AmbientEffectsEnabled() then return 0 end
    local host = acquireHost(frame, attach)
    if not host then return 0 end
    host.exit = exit
    host.elapsed = 0
    host.shattered = false
    host.burst = false
    if host.ghostBehavior and host.ghostBehavior.ResetGhost then host.ghostBehavior.ResetGhost(host) end
    host.ghostBehavior = ThemeApply.GetBehavior(exit.Ghost)
    host.ghostDuration = nil
    host.iconSlices = snapshotIcon(frame)
    hideComposite(host.GhostSlices)
    host.windowDissolve, host.windowDissolveActive = nil, nil
    for _, art in ipairs(host.WindowDissolveFrames or {}) do
        art.Color:Hide()
        art.Edge:Hide()
    end
    for _, piece in ipairs(host.Shards) do
        hideComposite(piece.IconSlices)
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
    end
    host.Flare:SetShown(exit.Flare and ThemeApply.Texture(host.Flare, exit.Flare) or false)
    if exit.Flare then
        stepFlare(host, exit.Flare, 0)
    end
    if host.effectBehavior and host.effectBehavior.ResetEffect then host.effectBehavior.ResetEffect(host) end
    host.effectSpec = ThemeApply.GetTransitionEffect(exit)
    host.effectBehavior = ThemeApply.GetBehavior(host.effectSpec)
    if host.effectBehavior then
        host.effectBehavior.SetupEffect(host, host.effectSpec, frame)
        host.effectBehavior.StepEffect(host, host.effectSpec, 0)
    end
    setupVortex(host, exit.Vortex)
    host:Show()
    local crackTime = exit.Crack and exit.Crack.Time or 0
    return math.max(crackTime + (exit.Shards and exit.Shards.Time or 0),
        exit.Burst and (exit.BurstDelay or crackTime) + exit.Burst.Life[2] or 0, host.ghostDuration or (exit.Ghost and exit.Ghost.Time or 0),
        exit.Flare and exit.Flare.Time or 0, host.effectBehavior and host.effectSpec.Time or 0, exit.Vortex and exit.Vortex.Time or 0), host
end

ThemeApply.PlayIconExit = function(frame, exit, icon, iconFile, attach, state)
    return ThemeApply.PlayExit(frame, exit, icon, iconFile, attach, state)
end
