-- widgets.lua: the Widget API (warcraft.wiki.gg/wiki/Widget_API) of the world's client.
-- Generated: each widget type's methods are the documented functions of its ScriptObject tables in
-- Blizzard_APIDocumentationGenerated (SimpleFrameAPI, SimpleTextureAPI, ...), up its inheritance chain. A method the
-- client does not document does not exist, so calling it fails as in the client. Generated methods check their
-- arguments like documented functions (spec/helpers/api_mocks.lua); a SetX stores its arguments for the matching GetX
-- or IsX, anything else returns values shaped by its documented returns.
-- Hand-written (the engine core): object identity and hierarchy, show/hide and visibility, scripts, events, anchors
-- and sizes with a computed layout, regions, fonts and text, and animation groups played by the world's clock.
-- XML templates the addon inherits are applied from world.templates (spec/helpers/ui_frames.lua).
local Mocks = require("spec.helpers.api_mocks")

local M = {}

-- Widget_API inheritance: type -> parent type and its documentation tables.
M.HIERARCHY = {
    FrameScriptObject = { docs = { "SimpleFrameScriptObjectAPI" } },
    Object = { parent = "FrameScriptObject", docs = { "SimpleObjectAPI" } },
    ScriptRegion = { parent = "Object", docs = { "SimpleScriptRegionAPI", "SimpleScriptRegionResizingAPI", "SimpleAnimatableObjectAPI" } },
    Region = { parent = "ScriptRegion", docs = { "SimpleRegionAPI" } },
    TextureBase = { parent = "Region", docs = { "SimpleTextureBaseAPI" } },
    Texture = { parent = "TextureBase", docs = { "SimpleTextureAPI" } },
    MaskTexture = { parent = "TextureBase", docs = { "SimpleMaskTextureAPI" } },
    Line = { parent = "TextureBase", docs = { "SimpleLineAPI" } },
    FontString = { parent = "Region", docs = { "SimpleFontStringAPI" } },
    Frame = { parent = "ScriptRegion", docs = { "SimpleFrameAPI" } },
    Button = { parent = "Frame", docs = { "SimpleButtonAPI" } },
    CheckButton = { parent = "Button", docs = { "SimpleCheckboxAPI" } },
    EditBox = { parent = "Frame", docs = { "SimpleEditBoxAPI" } },
    Slider = { parent = "Frame", docs = { "SimpleSliderAPI" } },
    StatusBar = { parent = "Frame", docs = { "SimpleStatusBarAPI" } },
    ScrollFrame = { parent = "Frame", docs = { "SimpleScrollFrameAPI" } },
    MessageFrame = { parent = "Frame", docs = { "SimpleMessageFrameAPI" } },
    ColorSelect = { parent = "Frame", docs = { "SimpleColorSelectAPI" } },
    Cooldown = { parent = "Frame", docs = { "FrameAPICooldown" } },
    GameTooltip = { parent = "Frame", docs = { "FrameAPITooltip" } },
    Model = { parent = "Frame", docs = { "SimpleModelAPI" } },
    ModelScene = { parent = "Frame", docs = { "FrameAPIModelSceneFrame" } },
    Font = { parent = "FrameScriptObject", docs = { "SimpleFontAPI" } },
    AnimationGroup = { parent = "Object", docs = { "SimpleAnimGroupAPI" } },
    Animation = { parent = "Object", docs = { "SimpleAnimAPI" } },
    Alpha = { parent = "Animation", docs = { "SimpleAnimAlphaAPI" } },
    Rotation = { parent = "Animation", docs = { "SimpleAnimRotationAPI" } },
    Scale = { parent = "Animation", docs = { "SimpleAnimScaleAPI" } },
    LineScale = { parent = "Scale", docs = { "SimpleAnimScaleLineAPI" } },
    Translation = { parent = "Animation", docs = { "SimpleAnimTranslationAPI" } },
    LineTranslation = { parent = "Translation", docs = { "SimpleAnimTranslationLineAPI" } },
    TextureCoordTranslation = { parent = "Animation", docs = { "SimpleAnimTextureCoordTranslationAPI" } },
    FlipBook = { parent = "Animation", docs = { "SimpleAnimFlipBookAPI" } },
    Path = { parent = "Animation", docs = { "SimpleAnimPathAPI" } },
    VertexColor = { parent = "Animation", docs = { "SimpleAnimVertexColorAPI" } },
}

-- Regions and anchors: point name -> fraction of the width and height from the bottom left.
local POINTS = {
    TOPLEFT = { 0, 1 }, TOP = { 0.5, 1 }, TOPRIGHT = { 1, 1 },
    LEFT = { 0, 0.5 }, CENTER = { 0.5, 0.5 }, RIGHT = { 1, 0.5 },
    BOTTOMLEFT = { 0, 0 }, BOTTOM = { 0.5, 0 }, BOTTOMRIGHT = { 1, 0 },
}

local function isA(widgetType, ancestor)
    while widgetType do
        if widgetType == ancestor then return true end
        widgetType = M.HIERARCHY[widgetType] and M.HIERARCHY[widgetType].parent
    end
    return false
end
M.IsA = isA

function M.New(world)
    local widgets = { all = {}, eventFrames = {}, created = 0 }
    local docs = world.docs
    local methodTables = {}
    local core = {}

    local function state(self) return rawget(self, "__state") end

    -- Generated methods ---------------------------------------------------------------------------------------------

    local function generated(doc, typeName)
        local name = typeName .. ":" .. doc.Name
        local suffix = doc.Name:match("^Set(.+)$")
        local getter = doc.Name:match("^Get(.+)$") or doc.Name:match("^Is(.+)$")
        return function(self, ...)
            Mocks.CheckArguments(world, doc, name, ...)
            if suffix then
                state(self).values[suffix] = { n = select("#", ...), ... }
                return
            end
            local stored = getter and state(self).values[getter]
            if stored then return unpack(stored, 1, stored.n) end
            if doc.MayReturnNothing or not doc.Returns then return end
            local values = {}
            for i, field in ipairs(doc.Returns) do values[i] = Mocks.DefaultValue(docs, field) end
            return unpack(values, 1, #doc.Returns)
        end
    end

    local function methodsOf(typeName)
        if methodTables[typeName] then return methodTables[typeName] end
        local info = assert(M.HIERARCHY[typeName], "CreateFrame: unknown frame type " .. tostring(typeName))
        local methods = info.parent and setmetatable({}, { __index = methodsOf(info.parent) }) or {}
        for _, docName in ipairs(info.docs) do
            for methodName, doc in pairs(docs.scriptObjects[docName] or {}) do
                methods[methodName] = generated(doc, typeName)
            end
        end
        for methodName, implementation in pairs(core[typeName] or {}) do
            -- Only what the client documents exists: the core gives behaviour, never new methods.
            if methods[methodName] then methods[methodName] = implementation end
        end
        methodTables[typeName] = methods
        return methods
    end
    widgets.MethodsOf = methodsOf

    local function documents(typeName, methodName)
        return methodsOf(typeName)[methodName] ~= nil
    end
    widgets.Documents = documents

    local function new(typeName, name, parent)
        widgets.created = widgets.created + 1
        local object = setmetatable({}, { __index = methodsOf(typeName), __tostring = function() return typeName .. ":" .. tostring(name) end })
        rawset(object, "__state", {
            type = typeName, name = name, parent = parent, shown = true, scripts = {}, values = {},
            points = {}, children = {}, regions = {}, events = {}, animationGroups = {},
            alpha = 1, scale = 1, id = widgets.created,
        })
        widgets.all[#widgets.all + 1] = object
        if parent and state(parent) then
            local list = isA(typeName, "Frame") and state(parent).children or state(parent).regions
            list[#list + 1] = object
        end
        if name then world.env[name] = object end
        return object
    end
    widgets.New = new

    -- Core: FrameScriptObject and Object -----------------------------------------------------------------------------

    core.FrameScriptObject = {
        GetName = function(self) return state(self).name end,
        GetObjectType = function(self) return state(self).type end,
        IsObjectType = function(self, objectType) return isA(state(self).type, objectType) end,
        IsForbidden = function() return false end,
        GetDebugName = function(self) return tostring(state(self).name or state(self).type) end,
    }
    core.Object = {
        GetParent = function(self) return state(self).parent end,
    }

    -- Core: visibility, scripts, geometry ---------------------------------------------------------------------------

    local function isVisible(self)
        local current = self
        while current do
            local s = state(current)
            if not s or not s.shown then return false end
            current = s.parent
        end
        return true
    end

    local function fire(self, script, ...)
        local handler = state(self).scripts[script]
        if handler then return world.call(handler, self, ...) end
    end
    widgets.Fire = fire

    local function setShown(self, shown)
        local s = state(self)
        shown = not not shown
        if s.shown == shown then return end
        local wasVisible = isVisible(self)
        s.shown = shown
        local nowVisible = isVisible(self)
        if wasVisible ~= nowVisible then fire(self, nowVisible and "OnShow" or "OnHide") end
    end

    local function resolveRelative(self, relativeTo)
        if type(relativeTo) == "string" then relativeTo = world.env[relativeTo] end
        if relativeTo == nil then relativeTo = state(self).parent or world.env.UIParent end
        return relativeTo
    end

    local rect
    -- the screen position of a point of a region, or nil while it has no rect
    local function pointPosition(region, point)
        local left, bottom, width, height = rect(region)
        if not left then return nil end
        local fraction = POINTS[point]
        return left + fraction[1] * width, bottom + fraction[2] * height
    end

    function rect(self, depth)
        depth = (depth or 0) + 1
        if depth > 50 then error("anchor family connected in a loop") end
        local s = state(self)
        if s.screen then return 0, 0, s.screen.width, s.screen.height end
        local width, height = s.width, s.height
        local left, right, top, bottom
        for _, anchor in ipairs(s.points) do
            local x, y = pointPosition(anchor.relativeTo, anchor.relativePoint)
            if x then
                x, y = x + anchor.x, y + anchor.y
                local fraction = POINTS[anchor.point]
                if fraction[1] == 0 then left = x elseif fraction[1] == 1 then right = x else s.centerX = x end
                if fraction[2] == 0 then bottom = y elseif fraction[2] == 1 then top = y else s.centerY = y end
                if fraction[1] == 0.5 then left = left or (width and x - width / 2) end
                if fraction[2] == 0.5 then bottom = bottom or (height and y - height / 2) end
            end
        end
        if left and right then width = right - left end
        if top and bottom then height = top - bottom end
        if not width or not height then return nil end
        left = left or (right and right - width)
        bottom = bottom or (top and top - height)
        if not left or not bottom then return nil end
        return left, bottom, width, height
    end
    widgets.Rect = rect

    local function setPoint(self, point, relativeTo, relativePoint, x, y)
        local s = state(self)
        point = point:upper()
        if type(relativeTo) == "number" then
            relativeTo, relativePoint, x, y = nil, nil, relativeTo, relativePoint
        elseif type(relativeTo) == "string" and POINTS[relativeTo:upper()] and relativePoint == nil then
            relativeTo, relativePoint = nil, relativeTo
        elseif type(relativePoint) == "number" then
            relativePoint, x, y = nil, relativePoint, x
        end
        assert(POINTS[point], "SetPoint: invalid point " .. tostring(point))
        relativeTo = resolveRelative(self, relativeTo)
        if relativeTo == self then error("Cannot anchor to itself", 2) end
        relativePoint = relativePoint and relativePoint:upper() or point
        for i, anchor in ipairs(s.points) do
            if anchor.point == point then table.remove(s.points, i) break end
        end
        s.points[#s.points + 1] = { point = point, relativeTo = relativeTo, relativePoint = relativePoint, x = x or 0, y = y or 0 }
    end

    core.ScriptRegion = {
        Show = function(self) setShown(self, true) end,
        Hide = function(self) setShown(self, false) end,
        SetShown = function(self, shown) setShown(self, shown) end,
        IsShown = function(self) return state(self).shown end,
        IsVisible = isVisible,
        SetParent = function(self, parent)
            local s = state(self)
            if s.parent and state(s.parent) then
                for _, list in ipairs({ state(s.parent).children, state(s.parent).regions }) do
                    for i, child in ipairs(list) do
                        if child == self then table.remove(list, i) break end
                    end
                end
            end
            s.parent = parent
            if parent then
                local list = isA(s.type, "Frame") and state(parent).children or state(parent).regions
                list[#list + 1] = self
            end
        end,
        SetScript = function(self, script, handler)
            if not self:HasScript(script) then error(("%s:SetScript(): doesn't have a \"%s\" script"):format(state(self).type, script), 2) end
            state(self).scripts[script] = handler
        end,
        GetScript = function(self, script) return state(self).scripts[script] end,
        HookScript = function(self, script, handler)
            local original = state(self).scripts[script]
            state(self).scripts[script] = original and function(...) original(...) handler(...) end or handler
        end,
        HasScript = function(self, script)
            return world.scriptsOf(state(self).type)[script] == true
        end,
        SetPoint = setPoint,
        ClearAllPoints = function(self) state(self).points = {} end,
        ClearPoint = function(self, point)
            for i, anchor in ipairs(state(self).points) do
                if anchor.point == point then table.remove(state(self).points, i) return end
            end
        end,
        SetAllPoints = function(self, relativeTo)
            local s = state(self)
            s.points = {}
            setPoint(self, "TOPLEFT", relativeTo, "TOPLEFT", 0, 0)
            setPoint(self, "BOTTOMRIGHT", relativeTo, "BOTTOMRIGHT", 0, 0)
        end,
        GetNumPoints = function(self) return #state(self).points end,
        GetPoint = function(self, index)
            local anchor = state(self).points[index or 1]
            if anchor then return anchor.point, anchor.relativeTo, anchor.relativePoint, anchor.x, anchor.y end
        end,
        GetPointByName = function(self, point)
            for _, anchor in ipairs(state(self).points) do
                if anchor.point == point then return anchor.point, anchor.relativeTo, anchor.relativePoint, anchor.x, anchor.y end
            end
        end,
        AdjustPointsOffset = function(self, x, y)
            for _, anchor in ipairs(state(self).points) do anchor.x, anchor.y = anchor.x + x, anchor.y + y end
        end,
        SetSize = function(self, width, height) state(self).width, state(self).height = width, height or width end,
        SetWidth = function(self, width) state(self).width = width end,
        SetHeight = function(self, height) state(self).height = height end,
        GetWidth = function(self)
            local _, _, width = rect(self)
            return width or state(self).width or 0
        end,
        GetHeight = function(self)
            local _, _, _, height = rect(self)
            return height or state(self).height or 0
        end,
        GetSize = function(self) return self:GetWidth(), self:GetHeight() end,
        GetRect = function(self) return rect(self) end,
        GetScaledRect = function(self) return rect(self) end,
        IsRectValid = function(self) return rect(self) ~= nil end,
        GetLeft = function(self) local left = rect(self) return left end,
        GetBottom = function(self) local _, bottom = rect(self) return bottom end,
        GetRight = function(self) local left, _, width = rect(self) return left and left + width end,
        GetTop = function(self) local _, bottom, _, height = rect(self) return bottom and bottom + height end,
        GetCenter = function(self)
            local left, bottom, width, height = rect(self)
            if left then return left + width / 2, bottom + height / 2 end
        end,
        IsMouseOver = function() return false end,
        EnableMouse = function(self, enable) state(self).values.MouseEnabled = { n = 1, not not enable } end,
        IsMouseEnabled = function(self) local v = state(self).values.MouseEnabled return v and v[1] or false end,
        CreateAnimationGroup = function(self, name, template)
            local group = new("AnimationGroup", name, self)
            state(group).animations = {}
            local groups = state(self).animationGroups
            groups[#groups + 1] = group
            if template then world.applyTemplate(group, template) end
            return group
        end,
        GetAnimationGroups = function(self) return unpack(state(self).animationGroups) end,
        StopAnimating = function(self)
            for _, group in ipairs(state(self).animationGroups) do group:Stop() end
        end,
    }

    core.Region = {
        SetAlpha = function(self, alpha) state(self).alpha = alpha end,
        GetAlpha = function(self) return state(self).alpha end,
        SetScale = function(self, scale) state(self).scale = scale end,
        GetScale = function(self) return state(self).scale end,
        GetEffectiveScale = function(self)
            local scale, current = 1, self
            while current and state(current) do
                scale = scale * (state(current).scale or 1)
                current = state(current).parent
            end
            return scale
        end,
    }

    -- Core: frames --------------------------------------------------------------------------------------------------

    local function createRegion(typeName)
        return function(self, name, layer, template, subLayer)
            if type(name) == "string" then name = name:gsub("%$parent", self:GetName() or "") end
            local region = new(typeName, name, self)
            state(region).values.DrawLayer = { n = 2, layer or "ARTWORK", subLayer or 0 }
            if template then world.applyTemplate(region, template) end
            return region
        end
    end

    core.Frame = {
        SetAlpha = core.Region.SetAlpha,
        GetAlpha = core.Region.GetAlpha,
        SetScale = core.Region.SetScale,
        GetScale = core.Region.GetScale,
        GetEffectiveScale = core.Region.GetEffectiveScale,
        GetEffectiveAlpha = function(self)
            local alpha, current = 1, self
            while current and state(current) do
                alpha = alpha * (state(current).alpha or 1)
                current = state(current).parent
            end
            return alpha
        end,
        CreateTexture = createRegion("Texture"),
        CreateMaskTexture = createRegion("MaskTexture"),
        CreateLine = createRegion("Line"),
        CreateFontString = function(self, name, layer, fontObject)
            local region = createRegion("FontString")(self, name, layer)
            if fontObject then
                if type(fontObject) == "string" then fontObject = world.env[fontObject] end
                region:SetFontObject(fontObject)
            end
            return region
        end,
        GetChildren = function(self) return unpack(state(self).children) end,
        GetNumChildren = function(self) return #state(self).children end,
        GetRegions = function(self) return unpack(state(self).regions) end,
        GetNumRegions = function(self) return #state(self).regions end,
        RegisterEvent = function(self, event)
            if not docs.events[event] and not world.undocumentedEvents[event] then
                error(("Frame:RegisterEvent(): Attempt to register unknown event \"%s\""):format(tostring(event)), 2)
            end
            if not state(self).events[event] then
                state(self).events[event] = true
                widgets.eventFrames[#widgets.eventFrames + 1] = self
            end
            return true
        end,
        RegisterUnitEvent = function(self, event) return self:RegisterEvent(event) end,
        UnregisterEvent = function(self, event) state(self).events[event] = nil end,
        UnregisterAllEvents = function(self) state(self).events = {} end,
        IsEventRegistered = function(self, event) return state(self).events[event] == true end,
        RegisterAllEvents = function(self) state(self).allEvents = true end,
        SetFrameLevel = function(self, level) state(self).level = level end,
        GetFrameLevel = function(self)
            local s = state(self)
            if s.level then return s.level end
            return s.parent and state(s.parent) and state(s.parent).level and state(s.parent).level + 1 or 1
        end,
        GetID = function(self) return state(self).frameID or 0 end,
        SetID = function(self, id) state(self).frameID = id end,
    }

    -- Core: text ----------------------------------------------------------------------------------------------------

    local function setFont(self, path, height, flags)
        state(self).font = { path = path, height = height, flags = flags or "" }
        return true
    end
    local function getFont(self)
        local font = state(self).font or (state(self).fontObject and state(state(self).fontObject).font)
        if font then return font.path, font.height, font.flags end
    end
    local function setFontObject(self, fontObject)
        if type(fontObject) == "string" then fontObject = world.env[fontObject] end
        state(self).fontObject = fontObject
        state(self).font = nil
    end
    local function textWidth(self)
        local text = state(self).text
        local _, height = getFont(self)
        if text == nil then return 0 end
        return #tostring(text) * (height or 12) * 0.5
    end
    local text = {
        SetFont = setFont,
        GetFont = getFont,
        SetFontObject = setFontObject,
        GetFontObject = function(self) return state(self).fontObject end,
        SetText = function(self, value) state(self).text = value end,
        GetText = function(self) return state(self).text end,
        SetFormattedText = function(self, format, ...) state(self).text = format:format(...) end,
        GetStringWidth = textWidth,
        GetUnboundedStringWidth = textWidth,
        GetStringHeight = function(self)
            local _, height = getFont(self)
            return state(self).text and (height or 12) or 0
        end,
    }
    core.FontString = text
    core.Font = { SetFont = setFont, GetFont = getFont, SetFontObject = setFontObject, CopyFontObject = function(self, other)
        if type(other) == "string" then other = world.env[other] end
        state(self).font = other and state(other).font
    end }
    core.EditBox = {
        SetText = text.SetText, GetText = function(self) return state(self).text or "" end,
        SetFont = setFont, GetFont = getFont, SetFontObject = setFontObject,
        HasFocus = function(self) return state(self).focus == true end,
        SetFocus = function(self) state(self).focus = true end,
        ClearFocus = function(self) state(self).focus = false end,
        GetNumber = function(self) return tonumber(state(self).text) or 0 end,
    }
    core.Button = {
        SetText = function(self, value)
            local s = state(self)
            if not s.fontString then
                s.fontString = createRegion("FontString")(self)
            end
            s.fontString:SetText(value)
        end,
        GetText = function(self) return state(self).fontString and state(self).fontString:GetText() end,
        GetFontString = function(self) return state(self).fontString end,
        SetFontString = function(self, fontString) state(self).fontString = fontString end,
        Enable = function(self) state(self).disabled = false end,
        Disable = function(self) state(self).disabled = true end,
        SetEnabled = function(self, enabled) state(self).disabled = not enabled end,
        IsEnabled = function(self) return not state(self).disabled end,
        Click = function(self, button) fire(self, "OnClick", button or "LeftButton", false) end,
    }
    core.CheckButton = {
        SetChecked = function(self, checked) state(self).checked = not not checked end,
        GetChecked = function(self) return state(self).checked == true end,
    }
    core.Slider = {
        SetValue = function(self, value)
            local s = state(self)
            local low, high = s.min or 0, s.max or 0
            value = math.max(low, math.min(high, value))
            if s.value ~= value then
                s.value = value
                fire(self, "OnValueChanged", value, false)
            end
        end,
        GetValue = function(self) return state(self).value or 0 end,
        SetMinMaxValues = function(self, low, high) state(self).min, state(self).max = low, high end,
        GetMinMaxValues = function(self) return state(self).min or 0, state(self).max or 0 end,
    }
    core.StatusBar = core.Slider

    -- Core: animations ----------------------------------------------------------------------------------------------

    local function groupDuration(group)
        local s, byOrder = state(group), {}
        for _, animation in ipairs(s.animations) do
            local a = state(animation)
            local order = a.order or 1
            local length = (a.startDelay or 0) + (a.duration or 0) + (a.endDelay or 0)
            byOrder[order] = math.max(byOrder[order] or 0, length)
        end
        local total = 0
        for _, length in pairs(byOrder) do total = total + length end
        return total
    end

    core.AnimationGroup = {
        CreateAnimation = function(self, animationType, name, template)
            animationType = animationType or "Animation"
            local animation = new(animationType, name, self)
            local animations = state(self).animations
            animations[#animations + 1] = animation
            if template then world.applyTemplate(animation, template) end
            return animation
        end,
        GetAnimations = function(self) return unpack(state(self).animations) end,
        Play = function(self, reverse)
            local s = state(self)
            s.playing, s.elapsed, s.reverse, s.paused = true, 0, reverse or false, false
            widgets.playing[self] = true
            fire(self, "OnPlay")
        end,
        Restart = function(self) self:Stop() self:Play() end,
        Stop = function(self)
            local s = state(self)
            if s.playing then
                s.playing = false
                widgets.playing[self] = nil
                fire(self, "OnStop", false)
            end
        end,
        Finish = function(self)
            local s = state(self)
            if s.playing then
                s.playing = false
                widgets.playing[self] = nil
                fire(self, "OnFinished", false)
            end
        end,
        Pause = function(self) state(self).paused = true end,
        IsPlaying = function(self) return state(self).playing == true and not state(self).paused end,
        IsPaused = function(self) return state(self).paused == true end,
        IsDone = function(self) return not state(self).playing end,
        GetDuration = function(self) return groupDuration(self) end,
        GetElapsed = function(self) return state(self).elapsed or 0 end,
        GetProgress = function(self)
            local duration = groupDuration(self)
            return duration > 0 and math.min((state(self).elapsed or 0) / duration, 1) or 0
        end,
        SetLooping = function(self, looping) state(self).looping = looping end,
        GetLooping = function(self) return state(self).looping or "NONE" end,
        SetToFinalAlpha = function(self, final) state(self).finalAlpha = final end,
        IsSetToFinalAlpha = function(self) return state(self).finalAlpha == true end,
    }
    core.Animation = {
        SetDuration = function(self, duration) state(self).duration = duration end,
        GetDuration = function(self) return state(self).duration or 0 end,
        SetStartDelay = function(self, delay) state(self).startDelay = delay end,
        GetStartDelay = function(self) return state(self).startDelay or 0 end,
        SetEndDelay = function(self, delay) state(self).endDelay = delay end,
        GetEndDelay = function(self) return state(self).endDelay or 0 end,
        SetOrder = function(self, order) state(self).order = order end,
        GetOrder = function(self) return state(self).order or 1 end,
        IsPlaying = function(self) return state(state(self).parent).playing == true end,
        Play = function(self) state(self).parent:Play() end,
        Stop = function(self) state(self).parent:Stop() end,
        SetTarget = function(self, target) state(self).target = target end,
        GetTarget = function(self) return state(self).target or state(state(self).parent).parent end,
        GetRegionParent = function(self) return state(state(self).parent).parent end,
    }

    widgets.playing = {}

    ---runs one frame of every shown frame's OnUpdate and advances playing animation groups
    function widgets.RunOnUpdate(delta)
        for group in pairs(widgets.playing) do
            local s = state(group)
            if s.playing and not s.paused then
                s.elapsed = s.elapsed + delta
                local duration = groupDuration(group)
                if s.elapsed >= duration then
                    if s.looping == "REPEAT" or s.looping == "BOUNCE" then
                        s.elapsed = 0
                        fire(group, "OnLoop", "FORWARD")
                    else
                        s.playing = false
                        widgets.playing[group] = nil
                        fire(group, "OnFinished", false)
                    end
                elseif s.scripts.OnUpdate then
                    fire(group, "OnUpdate", delta)
                end
            end
        end
        local frames = {}
        for _, object in ipairs(widgets.all) do
            local s = state(object)
            if s.scripts.OnUpdate and isA(s.type, "ScriptRegion") then frames[#frames + 1] = object end
        end
        for _, object in ipairs(frames) do
            if state(object).scripts.OnUpdate and isVisible(object) then fire(object, "OnUpdate", delta) end
        end
    end

    ---delivers an event to every frame that registered it, in registration order
    function widgets.FireEvent(event, ...)
        local frames = {}
        for _, object in ipairs(widgets.eventFrames) do
            local s = state(object)
            if s.events[event] or s.allEvents then frames[#frames + 1] = object end
        end
        for _, object in ipairs(frames) do
            if state(object).events[event] or state(object).allEvents then fire(object, "OnEvent", event, ...) end
        end
    end

    ---CreateFrame (API_CreateFrame): frameType, name, parent, templates (comma separated), id
    function widgets.CreateFrame(frameType, name, parent, templates, id)
        local typeName
        for knownType in pairs(M.HIERARCHY) do
            if knownType:lower() == tostring(frameType):lower() then typeName = knownType end
        end
        if not typeName or not isA(typeName, "Frame") then
            error(("CreateFrame: Unknown frame type '%s'"):format(tostring(frameType)), 2)
        end
        if parent ~= nil and (type(parent) ~= "table" or not state(parent)) then
            error("CreateFrame: parent is not a frame", 2)
        end
        if type(name) == "string" and parent then name = name:gsub("%$parent", parent:GetName() or "") end
        local frame = new(typeName, name, parent)
        if id then state(frame).frameID = id end
        if templates then
            for template in templates:gmatch("[^,%s]+") do world.applyTemplate(frame, template) end
        end
        fire(frame, "OnLoad")
        return frame
    end

    ---CreateFont (API_CreateFont): a font object, also set as the global of its name
    function widgets.CreateFont(name)
        return new("Font", name)
    end

    widgets.State = state
    return widgets
end

return M
