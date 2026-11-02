local appName, app = ...
---@class AbilityTimeline
local private = app

-- a pooled sprite emitter, its driver is a child of the host so it stops while the host is hidden
local emitterMethods = {}

local between = function(range)
    return range[1] + math.random() * (range[2] - range[1])
end

---creates an emitter on host, spawn(particle, spec) places a new particle: particle.x, particle.y relative to host's
---BOTTOMLEFT
---@param host Frame
---@param spawn fun(particle: table, spec: table)
---@return table
private.CreateParticles = function(host, spawn)
    local emitter = {
        host = host,
        spawn = spawn,
        particles = {},
        pool = {},
        owed = {},
        emitting = false,
    }
    for name, method in pairs(emitterMethods) do
        emitter[name] = method
    end
    emitter.driver = CreateFrame("Frame", nil, host)
    emitter.driver:SetAllPoints(host)
    emitter.driver:Hide()
    emitter.driver:SetScript("OnUpdate", function(_, elapsed)
        emitter:Step(elapsed)
    end)
    return emitter
end

---starts with spec (Texture, Colors, Rate, Max, Size, Life, Speed, Alpha, Spin, Gravity: added to the vertical
---speed every second, Sway: { amplitude, speed } of a sideways wobble, Area: where the host's spawn places them, Align:
---turned along their path instead of spinning, Flipbook: { columns, rows, frames } for a texture holding its frames in
---a grid, stepped through over the particle's life, frames 1 holds the first, Aspect: drawn that many times wider than
---tall, Tall: that many times taller than wide, Mirror: drawn mirrored left to right, Intensity: { at 0, at 1 }
---multiplies Rate and Max by the weather's intensity, BlendMode: "BLEND" draws them as they are instead of as light,
---Steady: no twinkle, whole until the last 30% of their life, as drops of water), or a list of such specs emitting
---side by side, only while
---ambient effects are enabled. Particles of the specs before live out their life, so a new theme takes over softly
---@param spec table|nil
function emitterMethods:Start(spec)
    self.specs = spec and (spec[1] and spec or { spec })
    if not spec or not private.AmbientEffectsEnabled() then
        self:Stop()
        return
    end
    -- the same spec again, as every step of a palette fade applies it, keeps what it owes so slow emitters still emit
    if spec ~= self.started then
        self.owed = {}
    end
    self.started = spec
    self.emitting = true
    self.driver:Show()
end

function emitterMethods:Stop()
    self.started = nil
    self.pending = nil
    self.emitting = false
    self.driver:Hide()
    for i = #self.particles, 1, -1 do
        self:Recycle(i)
    end
end

---spawns count (defaults to spec.Count) particles of spec at once, besides any running emission
---@param spec table
---@param count number|nil
function emitterMethods:Burst(spec, count)
    -- an icon's enter layer has no size in the frame it appears, spawned now everything would start at its bottom left
    -- corner, so the burst waits until it has one
    if self.host:GetWidth() == 0 then
        self.pending = { spec = spec, count = count }
        self.driver:Show()
        return
    end
    for _ = 1, count or spec.Count do
        self:Spawn(spec)
    end
    self.driver:Show()
end

function emitterMethods:Recycle(index)
    local particle = table.remove(self.particles, index)
    particle.texture:Hide()
    table.insert(self.pool, particle)
end

---shows the frame of a Flipbook particle at progress
---@param particle table
---@param progress number
local setFlipbookFrame = function(particle, progress)
    local columns, rows, frames = unpack(particle.spec.Flipbook)
    frames = frames or columns * rows
    local frame = math.min(math.floor(progress * frames), frames - 1)
    if frame ~= particle.frame then
        particle.frame = frame
        local column, row = frame % columns, math.floor(frame / columns)
        local left, right = column / columns, (column + 1) / columns
        if particle.spec.Mirror then
            left, right = right, left
        end
        particle.texture:SetTexCoord(left, right, row / rows, (row + 1) / rows)
    end
end

function emitterMethods:Spawn(spec)
    local particle = table.remove(self.pool) or { texture = self.driver:CreateTexture(nil, "OVERLAY") }
    local texture = particle.texture
    local textures = spec.Texture
    texture:SetTexture(type(textures) == "table" and textures[math.random(#textures)] or textures)
    texture:SetBlendMode(spec.BlendMode or "ADD")
    local colors = spec.Colors
    particle.spec = spec
    particle.r, particle.g, particle.b = private.ThemeApply.Color(colors[math.random(#colors)])
    particle.size = between(spec.Size)
    particle.life = between(spec.Life)
    particle.age = 0
    particle.vx = between(spec.Speed[1])
    particle.vy = between(spec.Speed[2])
    particle.spin = math.random() * math.pi * 2
    particle.frame = nil
    if spec.Flipbook then
        setFlipbookFrame(particle, 0)
    elseif spec.Mirror then
        texture:SetTexCoord(1, 0, 0, 1)
    else
        texture:SetTexCoord(0, 1, 0, 1)
    end
    self.spawn(particle, spec)
    texture:SetSize(particle.size * (spec.Aspect or 1), particle.size * (spec.Tall or 1))
    texture:Show()
    table.insert(self.particles, particle)
end

function emitterMethods:Step(elapsed)
    local pending = self.pending
    if pending and self.host:GetWidth() > 0 then
        self.pending = nil
        self:Burst(pending.spec, pending.count)
    end
    if self.emitting then
        for i, spec in ipairs(self.specs) do
            local scale = 1
            if spec.Intensity then
                scale = spec.Intensity[1] + (spec.Intensity[2] - spec.Intensity[1]) * private.GetWeatherIntensity()
            end
            self.owed[i] = (self.owed[i] or 0) + elapsed * spec.Rate * scale
            while self.owed[i] >= 1 do
                self.owed[i] = self.owed[i] - 1
                local count = 0
                for _, particle in ipairs(self.particles) do
                    if particle.spec == spec then
                        count = count + 1
                    end
                end
                if count < spec.Max * scale then
                    self:Spawn(spec)
                end
            end
        end
    end
    for i = #self.particles, 1, -1 do
        local particle = self.particles[i]
        local spec = particle.spec
        particle.age = particle.age + elapsed
        if particle.age >= particle.life then
            self:Recycle(i)
        else
            particle.vy = particle.vy + (spec.Gravity or 0) * elapsed
            particle.x = particle.x + particle.vx * elapsed
            particle.y = particle.y + particle.vy * elapsed
            local x = particle.x
            if spec.Sway then
                x = x + spec.Sway[1] * math.sin(particle.age * spec.Sway[2] + particle.spin)
            end
            local progress = particle.age / particle.life
            if spec.Flipbook then
                setFlipbookFrame(particle, progress)
            end
            -- fade in quickly, twinkle, fade out; steady ones stay whole and fade at the end
            local alpha
            if spec.Steady then
                alpha = math.min(progress * 12, 1) * (progress < 0.7 and 1 or (1 - progress) / 0.3)
            else
                alpha = math.min(progress * 6, 1) * (1 - progress) * (0.7 + 0.3 * math.sin(particle.age * 8 + particle.spin))
            end
            particle.texture:SetVertexColor(particle.r, particle.g, particle.b, alpha * (spec.Alpha or 1))
            if spec.Align then
                particle.texture:SetRotation(math.atan2(particle.vy, particle.vx))
            else
                particle.texture:SetRotation(particle.spin + particle.age * (spec.Spin or 0))
            end
            particle.texture:SetPoint("CENTER", self.driver, "BOTTOMLEFT", x, particle.y)
        end
    end
    if not self.emitting and #self.particles == 0 and not self.pending then
        self.driver:Hide()
    end
end
