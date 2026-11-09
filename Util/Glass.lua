local appName, app = ...
---@class AbilityTimeline
local private = app

-- a pane of glass behind the timeline, after BetterBags' Rainy Window (Sonata, next/glass.lua): a tint that darkens the
-- world behind it (MOD) under a veil, fog in the glass, bands of reflected light, a lamp, a lit rim, lightning flashes,
-- and drops on the glass: scattered ones, beads left where particles land (Land) and runners sliding down it
private.Glass = {}
local Glass = private.Glass

local WHITE = "Interface\\Buttons\\WHITE8X8"
-- a bead grows to its size in this long
local BEAD_TIME = 0.3
-- the player's tint at which a theme's Tint.Strength is drawn as it is
local TINT_DEFAULT = 60

local sets = {}

local between = function(range)
    return range[1] + math.random() * (range[2] - range[1])
end

local clamp = function(value, low, high)
    return math.max(low, math.min(high, value))
end

---Drops.Intensity = { at 0, at 1 }: how many drops and runners there are at the weather's intensity, as particles
---@param range table|nil
---@return number
local intensityScale = function(range)
    if not range then return 1 end
    return range[1] + (range[2] - range[1]) * private.GetWeatherIntensity()
end

---the player's glass tint, 0 (clear) to 100 (dark)
---@return number
private.GetGlassTint = function()
    return private.GetThemeSettings().glassTint or TINT_DEFAULT
end

---@param value number
private.SetGlassTint = function(value)
    private.GetThemeSettings().glassTint = value
    for set in pairs(sets) do
        set:PaintTint()
    end
end

local setMethods = {}

---lays every glass out again, for the intensity the player set
Glass.Refresh = function()
    for set in pairs(sets) do
        if set.spec then
            set:Layout()
            set:PaintOverlay()
            set.driver:SetShown(set:Moves())
        end
    end
end

local layer = function(frame, drawLayer, subLevel)
    local texture = frame:CreateTexture(nil, drawLayer, nil, subLevel)
    texture:Hide()
    return texture
end

---creates a frame's glass, nothing shown until applied
---@param frame Frame
---@return table
Glass.Create = function(frame)
    local set = { frame = frame, pool = {}, drops = {}, beads = {}, runners = {}, nextBead = 1, bright = 0 }
    for name, method in pairs(setMethods) do
        set[name] = method
    end
    set.tint = layer(frame, "BACKGROUND", -6)
    set.veil = layer(frame, "BACKGROUND", -5)
    set.grain = layer(frame, "BACKGROUND", -4)
    set.overlay = layer(frame, "BACKGROUND", -3)
    set.reflections = layer(frame, "BORDER", -2)
    set.lamp = layer(frame, "BORDER", -2)
    set.rims = {}
    for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
        set.rims[side] = layer(frame, "BORDER", -1)
    end
    set.flash = layer(frame, "BORDER", 5)
    set.tint:SetAllPoints(frame)
    set.veil:SetAllPoints(frame)
    set.grain:SetAllPoints(frame)
    set.overlay:SetAllPoints(frame)
    set.reflections:SetAllPoints(frame)
    set.flash:SetAllPoints(frame)
    local rims = set.rims
    rims.TOP:SetPoint("TOPLEFT")
    rims.TOP:SetPoint("TOPRIGHT")
    rims.TOP:SetHeight(1)
    rims.BOTTOM:SetPoint("BOTTOMLEFT")
    rims.BOTTOM:SetPoint("BOTTOMRIGHT")
    rims.BOTTOM:SetHeight(1)
    rims.LEFT:SetPoint("TOPLEFT", 0, -1)
    rims.LEFT:SetPoint("BOTTOMLEFT", 0, 1)
    rims.LEFT:SetWidth(1)
    rims.RIGHT:SetPoint("TOPRIGHT", 0, -1)
    rims.RIGHT:SetPoint("BOTTOMRIGHT", 0, 1)
    rims.RIGHT:SetWidth(1)
    set.driver = CreateFrame("Frame", nil, frame)
    set.driver:Hide()
    set.driver:SetScript("OnUpdate", function(_, elapsed)
        set:Step(elapsed)
    end)
    frame:HookScript("OnSizeChanged", function()
        if set.spec then set:Layout() end
    end)
    sets[set] = true
    return set
end

---@param texture Texture
---@param spec table|nil
---@param alpha number|nil
local paint = function(texture, spec, alpha)
    local r, g, b, a = private.ThemeApply.Color(spec.Color, alpha or spec.Alpha)
    texture:SetBlendMode(spec.BlendMode or "ADD")
    texture:SetVertexColor(r, g, b, a)
end

---draws the tint and veil at the theme's strength times the player's tint
function setMethods:PaintTint()
    local tint = self.spec and self.spec.Tint
    if not tint then
        self.tint:Hide()
        self.veil:Hide()
        return
    end
    local strength = clamp((tint.Strength or 0.6) * private.GetGlassTint() / TINT_DEFAULT, 0, 1)
    local r, g, b = private.ThemeApply.Color(tint.Color)
    self.tint:SetTexture(WHITE)
    self.tint:SetBlendMode("MOD")
    self.tint:SetVertexColor(1 - strength * (1 - r), 1 - strength * (1 - g), 1 - strength * (1 - b), 1)
    self.tint:Show()
    local veil = tint.Veil
    if veil then
        self.veil:SetTexture(WHITE)
        paint(self.veil, { Color = veil.Color, BlendMode = "BLEND" }, (veil.Alpha or 0.15) * strength)
    end
    self.veil:SetShown(veil ~= nil)
end

---lays the reflected bands over the pane at their angle, moved along by offset
function setMethods:PlaceReflections()
    local spec = self.spec.Reflections
    local w, h = self.frame:GetWidth(), self.frame:GetHeight()
    local angle = math.rad(spec.Angle or 60)
    local period = spec.Period or 600
    local length = spec.Length or period * 2
    local nx, ny = math.cos(angle) / period, math.sin(angle) / period
    local mx, my = -math.sin(angle) / length, math.cos(angle) / length
    local o = self.drift or 0
    -- u runs across the bands and v along them, from the top left corner with y downwards
    self.reflections:SetTexCoord(o, 0, h * ny + o, h * my, w * nx + o, w * mx, w * nx + h * ny + o, w * mx + h * my)
end

---draws the rim lit by the light of a flash
function setMethods:PaintRim()
    local spec = self.spec.Rim
    local top, bottom = unpack(spec.Alpha or { 0.4, 0.1 })
    local lift = 1 + self.bright * 2
    local r, g, b = private.ThemeApply.Color(spec.Color)
    local strong, faint = CreateColor(r, g, b, math.min(1, top * lift)), CreateColor(r, g, b, math.min(1, bottom * lift))
    self.rims.TOP:SetVertexColor(r, g, b, strong.a)
    self.rims.BOTTOM:SetVertexColor(r, g, b, faint.a)
    self.rims.LEFT:SetGradient("VERTICAL", faint, strong)
    self.rims.RIGHT:SetGradient("VERTICAL", faint, strong)
end

---gets a drop's two textures: its body (BLEND, dark at its rim) and its light (ADD)
---@return table
function setMethods:NewDrop()
    local drop = table.remove(self.pool)
    if not drop then
        drop = { body = layer(self.frame, "BORDER", 3), shine = layer(self.frame, "BORDER", 4) }
        for _, texture in ipairs({ drop.body, drop.shine }) do
            if texture.SetSnapToPixelGrid then
                texture:SetSnapToPixelGrid(false)
                texture:SetTexelSnappingBias(0)
            end
        end
    end
    local spec = self.spec.Drops
    drop.body:SetTexture(private.ThemeApply.File(spec.File or "glassdrop"))
    drop.shine:SetTexture(private.ThemeApply.File(spec.Shine and spec.Shine.File or "glassshine"))
    drop.fade, drop.grow, drop.scale = 1, nil, 1
    self:PaintDrop(drop)
    return drop
end

---draws a drop: its body as it is (BLEND, or the Drops' BlendMode), its light added over it unless Shine is false (dust
---catches no light)
---@param drop table
function setMethods:PaintDrop(drop)
    local spec = self.spec.Drops
    paint(drop.body, { Color = spec.Color or "Shadow", BlendMode = spec.BlendMode or "BLEND" }, (spec.Alpha or 0.8) * drop.fade)
    local shine = spec.Shine or {}
    local light = spec.Shine == false and 0 or math.min(1, (shine.Alpha or 0.6) * (1 + self.bright * 1.5))
    paint(drop.shine, { Color = shine.Color or "White" }, light * drop.fade)
end

---draws the Overlay, a texture across the whole pane (frost thick at its edges, a film of dust), its alpha following
---the weather's intensity with Overlay.Intensity = { at 0, at 1 }
function setMethods:PaintOverlay()
    local spec = self.spec and self.spec.Overlay
    if spec then
        paint(self.overlay, spec, clamp((spec.Alpha or 0.5) * intensityScale(spec.Intensity), 0, 1))
    end
end

---lays the grain's tiles, moved along by its drift
function setMethods:PlaceGrain()
    local spec = self.spec.Grain
    local w, h = self.frame:GetWidth(), self.frame:GetHeight()
    local size = spec.Size or 256
    local x, y = self.grainX or 0, self.grainY or 0
    self.grain:SetTexCoord(x, x + w / size, y, y + h / size)
end

---places a drop's center at x, y from the pane's bottom left
---@param drop table
function setMethods:PlaceDrop(drop)
    local size = drop.size * drop.scale
    for _, texture in ipairs({ drop.body, drop.shine }) do
        texture:SetSize(size, size)
        texture:SetPoint("CENTER", self.frame, "BOTTOMLEFT", drop.x, drop.y)
        texture:Show()
    end
end

---@param drop table
function setMethods:Release(drop)
    drop.body:Hide()
    drop.body:ClearAllPoints()
    drop.shine:Hide()
    drop.shine:ClearAllPoints()
    table.insert(self.pool, drop)
end

function setMethods:Clear()
    for _, list in ipairs({ self.drops, self.beads, self.runners }) do
        for _, drop in ipairs(list) do
            self:Release(drop)
        end
    end
    self.drops, self.beads, self.runners, self.nextBead = {}, {}, {}, 1
end

---the pane's drops that stay: Drops.Density of them per 100 by 100 pixels, scattered anew, or only those now off it
---@param scatter boolean|nil
function setMethods:LayoutDrops(scatter)
    local spec = self.spec.Drops
    local w, h = self.frame:GetWidth(), self.frame:GetHeight()
    self.intensity = private.GetWeatherIntensity()
    local count = math.floor((spec.Density or 0) * intensityScale(spec.Intensity) * w * h / 10000 + 0.5)
    local size = spec.Size or { 3, 8 }
    while #self.drops > count do
        self:Release(table.remove(self.drops))
    end
    while #self.drops < count do
        local drop = self:NewDrop()
        drop.x = -1
        table.insert(self.drops, drop)
    end
    for _, drop in ipairs(self.drops) do
        if scatter or drop.x < 0 or drop.x > w or drop.y > h then
            -- small drops are the most
            drop.size = size[1] + (size[2] - size[1]) * math.random() ^ 2
            drop.x, drop.y = math.random() * w, math.random() * h
        end
        self:PlaceDrop(drop)
    end
end

---lays the glass out for the frame's size
function setMethods:Layout()
    local spec = self.spec
    local w, h = self.frame:GetWidth(), self.frame:GetHeight()
    if w <= 0 or h <= 0 then return end
    if spec.Grain then
        self:PlaceGrain()
    end
    if spec.Reflections then
        self:PlaceReflections()
    end
    if spec.Lamp then
        local at = spec.Lamp.At or { 0.5, 0.5 }
        self.lamp:ClearAllPoints()
        self.lamp:SetPoint("CENTER", self.frame, "BOTTOMLEFT", at[1] * w, at[2] * h)
        self.lamp:SetSize(spec.Lamp.Size or 120, spec.Lamp.Size or 120)
    end
    if spec.Drops then
        self:LayoutDrops(self.scatter)
        self.scatter = false
    end
end

---whether anything on the glass moves
---@return boolean
function setMethods:Moves()
    local spec = self.spec
    if not spec or not private.AmbientEffectsEnabled() then return false end
    local reflections = spec.Reflections
    return spec.Flash ~= nil or (reflections and reflections.Drift ~= nil) or (spec.Drops and spec.Drops.Runners ~= nil)
        or (spec.Grain and spec.Grain.Drift ~= nil) or #self.beads > 0
end

---draws the glass of a theme's spec (Elements.Timeline.Glass), or none. The same spec again, as every step of a
---palette fade applies it, only paints its colors again so nothing on the glass jumps
---@param spec table|nil
function setMethods:Apply(spec)
    local new = spec ~= self.spec
    self.spec = spec
    if not spec then
        self:Stop()
        self:Clear()
        for _, texture in ipairs({ self.tint, self.veil, self.grain, self.overlay, self.reflections, self.lamp, self.flash }) do
            texture:Hide()
        end
        for _, rim in pairs(self.rims) do
            rim:Hide()
        end
        return
    end
    if new then
        self:Clear()
        self.scatter = true
        self.drift = 0
        self.bright = 0
        self.untilFlash = spec.Flash and between(spec.Flash.Every)
        self.flashing = nil
    end
    self:PaintTint()
    if spec.Grain then
        self.grain:SetTexture(private.ThemeApply.File(spec.Grain.File or "glassfog"), "REPEAT", "REPEAT")
        paint(self.grain, spec.Grain)
    end
    self.grain:SetShown(spec.Grain ~= nil)
    if spec.Overlay then
        self.overlay:SetTexture(private.ThemeApply.File(spec.Overlay.File))
        -- Slice: nine-sliced with that margin and tiled, so frost along the edges keeps its size on a long timeline
        -- instead of stretching into streaks
        local slice = spec.Overlay.Slice
        if slice then
            self.overlay:SetTextureSliceMargins(slice, slice, slice, slice)
            self.overlay:SetTextureSliceMode(Enum.UITextureSliceMode.Tiled)
        else
            self.overlay:ClearTextureSlice()
        end
        self:PaintOverlay()
    end
    self.overlay:SetShown(spec.Overlay ~= nil)
    if spec.Reflections then
        self.reflections:SetTexture(private.ThemeApply.File(spec.Reflections.File or "glassreflect"), "REPEAT", "REPEAT")
        paint(self.reflections, spec.Reflections)
    end
    self.reflections:SetShown(spec.Reflections ~= nil)
    if spec.Lamp then
        self.lamp:SetTexture(private.ThemeApply.File(spec.Lamp.File or "glow"))
        paint(self.lamp, spec.Lamp)
    end
    self.lamp:SetShown(spec.Lamp ~= nil)
    for _, rim in pairs(self.rims) do
        rim:SetTexture(WHITE)
        rim:SetBlendMode("ADD")
        rim:SetShown(spec.Rim ~= nil)
    end
    if spec.Rim then
        self:PaintRim()
    end
    if spec.Flash then
        self.flash:SetTexture(WHITE)
        paint(self.flash, spec.Flash, 0)
    end
    self.flash:SetShown(spec.Flash ~= nil)
    for _, list in ipairs({ self.drops, self.beads, self.runners }) do
        for _, drop in ipairs(list) do
            self:PaintDrop(drop)
        end
    end
    -- runners need ambient effects, beads left by particles go with them
    if not private.AmbientEffectsEnabled() then
        for _, list in ipairs({ self.beads, self.runners }) do
            for _, drop in ipairs(list) do
                self:Release(drop)
            end
        end
        self.beads, self.runners, self.nextBead = {}, {}, 1
    elseif new and spec.Drops and spec.Drops.Runners then
        -- enough for the strongest weather, the ones the weather doesn't need now rest
        local range = spec.Drops.Intensity
        local most = (spec.Drops.Runners.Count or 2) * (range and math.max(range[1], range[2]) or 1)
        for _ = 1, math.ceil(most) do
            local runner = self:NewDrop()
            self:Launch(runner)
            table.insert(self.runners, runner)
        end
    end
    self:Layout()
    self.driver:SetShown(self:Moves())
end

function setMethods:Stop()
    self.driver:Hide()
end

---a bead of water left on the glass at x, y from its bottom left (where a particle landed or a runner passed), growing
---in and drying away over its life; with Drops.Max beads on the glass the oldest makes room
---@param x number
---@param y number
---@param size number|nil
function setMethods:Bead(x, y, size)
    local spec = self.spec and self.spec.Drops
    if not spec or not private.AmbientEffectsEnabled() then return end
    local w, h = self.frame:GetWidth(), self.frame:GetHeight()
    if x < 0 or x > w or y < 0 or y > h then return end
    local bead
    if #self.beads < (spec.Max or 24) then
        bead = self:NewDrop()
        table.insert(self.beads, bead)
    else
        bead = self.beads[self.nextBead]
        self.nextBead = self.nextBead % #self.beads + 1
    end
    bead.x, bead.y = x, y
    bead.size = size or between(spec.BeadSize or { 2, 4 })
    bead.max = between(spec.Life or { 8, 14 })
    bead.life = bead.max
    bead.grow, bead.scale, bead.fade = 0, 0.3, 1
    self:PaintDrop(bead)
    self:PlaceDrop(bead)
    self.driver:Show()
end

---starts a runner again high on the glass, waiting to swell before it slides
---@param runner table
function setMethods:Launch(runner)
    local spec = self.spec.Drops.Runners
    local w, h = self.frame:GetWidth(), self.frame:GetHeight()
    runner.x = math.random() * w
    runner.y = h * (0.5 + 0.45 * math.random())
    runner.size = between(spec.Size or { 6, 10 })
    runner.wait = between(spec.Wait or { 1.5, 5 })
    runner.swell, runner.speed, runner.run, runner.travel = 0, 0, 0, 0
    runner.fade, runner.scale = 0, 0.6
end

---@param runner table
---@param elapsed number
function setMethods:StepRunner(runner, elapsed)
    local spec = self.spec.Drops.Runners
    runner.swell = math.min(1, runner.swell + elapsed * 1.5)
    runner.scale = 0.6 + 0.4 * runner.swell
    if runner.wait > 0 then
        runner.wait = runner.wait - elapsed
        runner.fade = runner.swell
        if runner.wait <= 0 then
            runner.speed, runner.run = between(spec.Speed or { 30, 80 }), between(spec.Slide or { 0.25, 1.1 })
        end
    elseif runner.run > 0 then
        -- slides down, then catches on the glass a moment
        runner.run = runner.run - elapsed
        local fall = runner.speed * elapsed
        runner.y = runner.y - fall
        runner.x = runner.x + (math.random() - 0.5) * 0.15 * fall
        runner.travel = runner.travel + fall
        if runner.travel >= (spec.Every or 7) then
            runner.travel = 0
            self:Bead(runner.x, runner.y + runner.size * runner.scale * 0.45)
        end
        if runner.run <= 0 then
            runner.catch = between(spec.Catch or { 0.15, 0.9 })
        end
    else
        runner.catch = (runner.catch or 0) - elapsed
        if runner.catch <= 0 then
            runner.speed, runner.run = between(spec.Speed or { 30, 80 }), between(spec.Slide or { 0.25, 1.1 })
        end
    end
    local foot = runner.y - runner.size * runner.scale / 2
    if foot <= 0 then
        self:Launch(runner)
    elseif runner.wait <= 0 then
        runner.fade = runner.swell * clamp(foot / runner.size, 0, 1)
    end
    self:PaintDrop(runner)
    self:PlaceDrop(runner)
end

---two bumps of light, the second fainter: lightning's flash and its echo
---@param p number
---@return number
local envelope = function(p)
    local bump = function(from, to)
        if p < from or p > to then return 0 end
        return math.sin(math.pi * (p - from) / (to - from))
    end
    return math.max(bump(0, 0.35), 0.6 * bump(0.5, 0.9))
end

function setMethods:Step(elapsed)
    local spec = self.spec
    if not spec then
        self.driver:Hide()
        return
    end
    local flash = spec.Flash
    if flash then
        local bright = 0
        if self.flashing then
            self.flashing = self.flashing + elapsed
            local p = self.flashing / (flash.Time or 0.5)
            if p >= 1 then
                self.flashing = nil
            else
                bright = envelope(p)
            end
        else
            self.untilFlash = self.untilFlash - elapsed
            if self.untilFlash <= 0 then
                self.untilFlash = between(flash.Every)
                self.flashing = 0
            end
        end
        if bright ~= self.bright then
            self.bright = bright
            paint(self.flash, flash, (flash.Alpha or 0.2) * bright)
            if spec.Rim then self:PaintRim() end
            for _, drop in ipairs(self.drops) do
                self:PaintDrop(drop)
            end
        end
    end
    local reflections = spec.Reflections
    if reflections and reflections.Drift then
        self.drift = (self.drift + reflections.Drift * elapsed / (reflections.Period or 600)) % 1
        self:PlaceReflections()
    end
    local drops = spec.Drops
    if private.GetWeatherIntensity() ~= self.intensity then
        if drops then
            self:LayoutDrops(false)
        end
        self.intensity = private.GetWeatherIntensity()
        self:PaintOverlay()
    end
    -- Grain.Drift = { x, y }: the fog in the glass drifting that many pixels a second
    local grain = spec.Grain
    if grain and grain.Drift then
        local size = grain.Size or 256
        self.grainX = ((self.grainX or 0) - grain.Drift[1] * elapsed / size) % 1
        self.grainY = ((self.grainY or 0) + grain.Drift[2] * elapsed / size) % 1
        self:PlaceGrain()
    end
    local active = drops and drops.Runners
        and math.floor((drops.Runners.Count or 2) * intensityScale(drops.Intensity) + 0.5) or 0
    for i, runner in ipairs(self.runners) do
        if i > active and (runner.resting or runner.wait > 0) then
            -- not needed at this intensity: rests unseen, a sliding one runs off first
            if not runner.resting then
                runner.resting = true
                runner.body:Hide()
                runner.shine:Hide()
            end
        else
            if runner.resting then
                runner.resting = nil
                self:Launch(runner)
            end
            self:StepRunner(runner, elapsed)
        end
    end
    for i = #self.beads, 1, -1 do
        local bead = self.beads[i]
        bead.life = bead.life - elapsed
        if bead.life <= 0 then
            self:Release(table.remove(self.beads, i))
            self.nextBead = 1
        else
            if bead.grow then
                bead.grow = bead.grow + elapsed
                local k = math.min(1, bead.grow / BEAD_TIME)
                bead.scale = 0.3 + 0.7 * k
                if k >= 1 then bead.grow = nil end
                self:PlaceDrop(bead)
            end
            -- dries away over the last 40% of its life
            bead.fade = math.min(1, bead.life / (0.4 * bead.max))
            self:PaintDrop(bead)
        end
    end
    if not self:Moves() then
        self.driver:Hide()
    end
end

-- a particle landing on the glass leaves a bead there, Land = { Behavior = "GlassBead", Chance, Size }
private.ThemeApply.RegisterBehavior("GlassBead", {
    LandParticle = function(host, x, y, particle, land)
        if host.Glass and math.random() < (land.Chance or 1) then
            host.Glass:Bead(x, y, land.Size and between(land.Size))
        end
    end,
})
