-- xml_templates.lua: Blizzard's virtual XML templates from the client's UI source, applied by CreateFrame and
-- CreateTexture/CreateFontString/CreateAnimationGroup the way the client applies them (warcraft.wiki.gg/wiki/XML_UI):
-- inherited templates first, then the template's mixins (mixin="A, B"), its KeyValues, size and anchors, its regions
-- (Layers), child frames and animation groups (each with its parentKey), and its scripts (method= calls the mixin
-- method of that name, function= the global function, a body is compiled with the handler's arguments). OnLoad runs
-- after everything is in place. The templates are read from the XML files of the addons fetch_deps.sh fetches.
local Toc = require("spec.helpers.toc")

local M = {}

---a small XML reader: elements with attributes and children; text content kept for script bodies
function M.Parse(content)
    content = content:gsub("<!%-%-.-%-%->", ""):gsub("<%?.-%?>", "")
    local root = { tag = "#root", children = {}, attributes = {} }
    local stack = { root }
    local position = 1
    while true do
        local start, finish, closing, tag, attributes, selfClosing = content:find("<(/?)([%w_:]+)(.-)(/?)>", position)
        if not start then break end
        local text = content:sub(position, start - 1)
        local current = stack[#stack]
        if text:find("%S") then current.text = (current.text or "") .. text end
        if closing == "/" then
            table.remove(stack)
        else
            local element = { tag = tag, attributes = {}, children = {} }
            for key, _, value in attributes:gmatch("([%w_:]+)%s*=%s*([\"'])(.-)%2") do
                element.attributes[key] = value
            end
            current.children[#current.children + 1] = element
            if selfClosing ~= "/" then stack[#stack + 1] = element end
        end
        position = finish + 1
    end
    return root
end

local REGION_TAGS = { Texture = "Texture", FontString = "FontString", MaskTexture = "MaskTexture", Line = "Line" }
local ANIMATION_TAGS = {
    Alpha = true, Scale = true, Translation = true, Rotation = true, Path = true, FlipBook = true,
    TextureCoordTranslation = true, VertexColor = true, LineScale = true, LineTranslation = true, Animation = true,
}

local registries = {}

---every virtual template (and named frame definition) of a client's fetched Blizzard XML, by name
function M.Registry(client)
    if registries[client] then return registries[client] end
    local registry = {}
    for _, file in ipairs(require("spec.helpers.blizzard_lua").AddonFiles(client)) do
        local path = file.path
        local parsed = path:find("%.xml$") and M.Parse(assert(Toc.Read(path))) or { children = {} }
        local function visit(element, depth)
            for _, child in ipairs(element.children) do
                local name = child.attributes.name
                -- Font and FontFamily elements at the top level are font objects whether virtual or not
                local isFont = depth == 0 and (child.tag == "Font" or child.tag == "FontFamily")
                -- a named top-level frame the client creates when its addon loads
                if depth == 0 and name and child.attributes.virtual ~= "true" and not isFont
                    and child.tag ~= "Script" and child.tag ~= "Include" then
                    registry.__frames = registry.__frames or {}
                    if not registry.__frames[name] then
                        registry.__frameCount = (registry.__frameCount or 0) + 1
                        registry.__frames[name] = { element = child, addon = file.addon, onDemand = file.onDemand, order = registry.__frameCount }
                    end
                end
                if name and (child.attributes.virtual == "true" or isFont) then
                    child.source = path
                    registry[name] = registry[name] or child
                    if isFont then
                        registry.__fonts = registry.__fonts or {}
                        table.insert(registry.__fonts, child)
                    end
                end
                visit(child, depth + 1)
            end
        end
        local ui = parsed.children[1] or parsed
        visit(ui, 0)
    end
    registries[client] = registry
    return registry
end

local function list(value)
    local items = {}
    for item in (value or ""):gmatch("[^,%s]+") do items[#items + 1] = item end
    return items
end

function M.Install(world, env)
    local registry = M.Registry(world.client)
    world.templateRegistry = registry
    local state = world.widgets.State

    -- Font objects from the client's font XML (Blizzard_Fonts_Shared): font file, height and outline, inherited
    -- through inherits=; a FontFamily takes its roman alphabet member.
    local function fontSpec(element, seen)
        seen = seen or {}
        if seen[element] then return {} end
        seen[element] = true
        if element.tag == "FontFamily" then
            for _, member in ipairs(element.children) do
                if member.tag == "Member" and (member.attributes.alphabet or "roman") == "roman" then
                    for _, font in ipairs(member.children) do
                        if font.tag == "Font" then return fontSpec(font, seen) end
                    end
                end
            end
            return {}
        end
        local spec = {}
        local parent = element.attributes.inherits and registry[element.attributes.inherits]
        if parent then spec = fontSpec(parent, seen) end
        local a = element.attributes
        spec.font = a.font or spec.font
        spec.height = tonumber(a.height) or spec.height
        spec.outline = a.outline or spec.outline
        for _, child in ipairs(element.children) do
            if child.tag == "FontHeight" then
                for _, absolute in ipairs(child.children) do
                    if absolute.tag == "AbsValue" then spec.height = tonumber(absolute.attributes.val) or spec.height end
                end
            end
        end
        return spec
    end
    for _, element in ipairs(registry.__fonts or {}) do
        local name = element.attributes.name
        if not env[name] then
            local spec = fontSpec(element)
            local font = world.widgets.CreateFont(name)
            local flags = spec.outline == "NORMAL" and "OUTLINE" or spec.outline == "THICK" and "THICKOUTLINE" or ""
            font:SetFont(spec.font or "Fonts\\FRIZQT__.TTF", spec.height or 12, flags)
        end
    end

    local function value(raw, valueType)
        if valueType == "number" then return tonumber(raw) end
        if valueType == "boolean" then return raw == "true" end
        if valueType == "global" then return env[raw] end
        return raw
    end

    local apply

    local function scriptHandler(element)
        local method, func = element.attributes.method, element.attributes["function"]
        if method then
            return function(self, ...)
                local handler = self[method]
                if not handler then error(("%s: no method %s"):format(element.tag, method)) end
                return handler(self, ...)
            end
        elseif func then
            return function(...) return env[func](...) end
        elseif element.text then
            local chunk = assert(loadstring("local self, arg1, arg2, arg3, arg4 = ...\n" .. element.text, element.tag))
            setfenv(chunk, env)
            return chunk
        end
    end

    local function applyAnchors(object, element)
        for _, child in ipairs(element.children) do
            if child.tag == "Size" then
                local x, y = tonumber(child.attributes.x), tonumber(child.attributes.y)
                for _, dimension in ipairs(child.children) do
                    if dimension.tag == "AbsDimension" then x, y = tonumber(dimension.attributes.x), tonumber(dimension.attributes.y) end
                end
                if x then object:SetWidth(x) end
                if y then object:SetHeight(y) end
            elseif child.tag == "Anchors" then
                for _, anchor in ipairs(child.children) do
                    local a = anchor.attributes
                    local relativeTo = a.relativeKey and a.relativeKey:gsub("%$parent", "__parent") or a.relativeTo
                    local target
                    if a.relativeKey then
                        target = object
                        for part in a.relativeKey:gmatch("[^%.]+") do
                            if part == "$parent" then target = target:GetParent() else target = target and target[part] end
                        end
                    elseif relativeTo then
                        target = env[(relativeTo:gsub("%$parent", object:GetParent() and object:GetParent():GetName() or ""))]
                    end
                    local x, y = tonumber(a.x) or 0, tonumber(a.y) or 0
                    for _, offset in ipairs(anchor.children) do
                        if offset.tag == "Offset" then
                            x, y = tonumber(offset.attributes.x) or x, tonumber(offset.attributes.y) or y
                            for _, dimension in ipairs(offset.children) do
                                if dimension.tag == "AbsDimension" then x, y = tonumber(dimension.attributes.x) or x, tonumber(dimension.attributes.y) or y end
                            end
                        end
                    end
                    object:SetPoint(a.point, target, a.relativePoint or a.point, x, y)
                end
            end
        end
    end

    local function nameOf(element, parent)
        local name = element.attributes.name
        if name and parent then name = name:gsub("%$parent", parent:GetName() or "") end
        if name and name:find("%$parent") then name = nil end
        return name
    end

    -- applies a template element's content to object; OnLoad is fired by the caller once
    function apply(object, element, onLoads)
        for _, inherited in ipairs(list(element.attributes.inherits)) do
            local template = registry[inherited] or world.templates[inherited]
            if not template then error(("Couldn't find inherited node \"%s\""):format(inherited), 0) end
            if type(template) == "function" then
                template(object)
            elseif template.tag == "Font" or template.tag == "FontFamily" then
                if object.SetFontObject then object:SetFontObject(env[inherited]) end
            else
                apply(object, template, onLoads)
            end
        end
        for _, mixin in ipairs(list(element.attributes.mixin)) do
            local source = env[mixin]
            if type(source) ~= "table" then
                error(("template %s: mixin %s is not loaded (%s)"):format(element.attributes.name or element.tag, mixin, type(source)), 0)
            end
            env.Mixin(object, source)
        end
        for _, mixin in ipairs(list(element.attributes.secureMixin)) do
            env.Mixin(object, (assert(env[mixin], "mixin " .. mixin)))
        end
        if element.attributes.parentArray and false then return end
        applyAnchors(object, element)
        if element.attributes.setAllPoints == "true" then object:SetAllPoints() end
        if element.attributes.hidden == "true" and object.Hide then object:Hide() end
        if element.attributes.alpha and object.SetAlpha then object:SetAlpha(tonumber(element.attributes.alpha)) end
        for _, child in ipairs(element.children) do
            if child.tag == "KeyValues" then
                for _, keyValue in ipairs(child.children) do
                    object[keyValue.attributes.key] = value(keyValue.attributes.value, keyValue.attributes.type)
                end
            elseif child.tag == "Layers" then
                for _, layer in ipairs(child.children) do
                    for _, regionElement in ipairs(layer.children) do
                        local regionType = REGION_TAGS[regionElement.tag]
                        if regionType then
                            local region = world.widgets.New(regionType, nameOf(regionElement, object), object)
                            state(region).values.DrawLayer = { n = 2, layer.attributes.level or "ARTWORK", tonumber(regionElement.attributes.textureSubLevel) or 0 }
                            apply(region, regionElement, onLoads)
                            local a = regionElement.attributes
                            if a.parentKey then object[a.parentKey] = region end
                            if a.parentArray then
                                object[a.parentArray] = object[a.parentArray] or {}
                                table.insert(object[a.parentArray], region)
                            end
                            if a.file and region.SetTexture then region:SetTexture(a.file) end
                            if a.atlas and region.SetAtlas then region:SetAtlas(a.atlas) end
                            if a.text and region.SetText then region:SetText(env[a.text] or a.text) end
                            if a.inherits and regionType == "FontString" and env[a.inherits] and region.SetFontObject then
                                region:SetFontObject(env[a.inherits])
                            end
                        end
                    end
                end
            elseif child.tag == "Frames" then
                for _, frameElement in ipairs(child.children) do
                    local frame = world.widgets.CreateFrame(frameElement.tag, nameOf(frameElement, object), object, nil)
                    local childLoads = {}
                    apply(frame, frameElement, childLoads)
                    local a = frameElement.attributes
                    if a.parentKey then object[a.parentKey] = frame end
                    if a.parentArray then
                        object[a.parentArray] = object[a.parentArray] or {}
                        table.insert(object[a.parentArray], frame)
                    end
                    for _, onLoad in ipairs(childLoads) do onLoad() end
                end
            elseif child.tag == "Animations" then
                for _, groupElement in ipairs(child.children) do
                    if groupElement.tag == "AnimationGroup" then
                        local group = object:CreateAnimationGroup(nameOf(groupElement, object))
                        apply(group, groupElement, onLoads)
                        if groupElement.attributes.parentKey then object[groupElement.attributes.parentKey] = group end
                        if groupElement.attributes.looping then group:SetLooping(groupElement.attributes.looping) end
                        for _, animationElement in ipairs(groupElement.children) do
                            if ANIMATION_TAGS[animationElement.tag] then
                                local animation = group:CreateAnimation(animationElement.tag, nameOf(animationElement, object))
                                local a = animationElement.attributes
                                if a.duration then animation:SetDuration(tonumber(a.duration)) end
                                if a.order then animation:SetOrder(tonumber(a.order)) end
                                if a.startDelay then animation:SetStartDelay(tonumber(a.startDelay)) end
                                if a.parentKey then group[a.parentKey] = animation end
                                apply(animation, animationElement, onLoads)
                            end
                        end
                    end
                end
            elseif child.tag == "Scripts" then
                for _, scriptElement in ipairs(child.children) do
                    local handler = scriptHandler(scriptElement)
                    if handler and scriptElement.tag == "OnLoad" then
                        onLoads[#onLoads + 1] = function() world.call(handler, object) end
                    elseif handler then
                        local intrinsic = scriptElement.attributes.intrinsicOrder
                        local existing = object:GetScript(scriptElement.tag)
                        if existing and (intrinsic == "postcall" or scriptElement.attributes.inherit == "append") then
                            object:SetScript(scriptElement.tag, function(...) existing(...) handler(...) end)
                        elseif existing and (intrinsic == "precall" or scriptElement.attributes.inherit == "prepend") then
                            object:SetScript(scriptElement.tag, function(...) handler(...) existing(...) end)
                        else
                            object:SetScript(scriptElement.tag, handler)
                        end
                    end
                end
            end
        end
    end

    ---applies a named template to object, running its OnLoad handlers
    function world.applyTemplate(object, template)
        local custom = world.templates[template]
        if custom then return custom(object) end
        local element = registry[template]
        if not element then error(("Couldn't find inherited node \"%s\""):format(template), 3) end
        local onLoads = {}
        apply(object, element, onLoads)
        for _, onLoad in ipairs(onLoads) do onLoad() end
    end

    ---creates a named frame of the client's XML (the way the client creates it when its addon loads)
    function world.createNamedFrame(name)
        local info = registry.__frames and registry.__frames[name]
        if not info or env[name] then return env[name] end
        local element = info.element
        local parent = element.attributes.parent and env[element.attributes.parent] or nil
        local frameType = element.tag == "Frame" and "Frame" or element.tag
        local frame = world.widgets.CreateFrame(frameType, name, parent)
        local onLoads = {}
        apply(frame, element, onLoads)
        for _, onLoad in ipairs(onLoads) do onLoad() end
        return frame
    end

    ---the mixins the templates the addon inherits need, so blizzard_lua.lua loads the files defining them
    function world.templateMixins(names)
        local mixins, seen = {}, {}
        local function visit(name)
            local element = registry[name] or (registry.__frames and registry.__frames[name] and registry.__frames[name].element)
            if not element or seen[name] then return end
            seen[name] = true
            local function walk(node)
                for _, attribute in ipairs({ "mixin", "secureMixin" }) do
                    for _, mixin in ipairs(list(node.attributes[attribute])) do mixins[#mixins + 1] = mixin end
                end
                for _, inherited in ipairs(list(node.attributes.inherits)) do visit(inherited) end
                for _, child in ipairs(node.children) do walk(child) end
            end
            walk(element)
        end
        for _, name in ipairs(names) do visit(name) end
        return mixins
    end
end

return M
