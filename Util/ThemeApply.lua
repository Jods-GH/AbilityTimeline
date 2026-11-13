local appName, app = ...
---@class AbilityTimeline
local private = app
local SharedMedia = LibStub("LibSharedMedia-3.0")

-- turns the specs themes are written in into widget calls
private.ThemeApply = {}
local ThemeApply = private.ThemeApply

local behaviors = {}
local iconFrames = setmetatable({}, { __mode = "k" })

---Theme-owned implementations selected by a spec's Behavior key.
ThemeApply.RegisterBehavior = function(name, behavior)
    behaviors[name] = behavior
end

ThemeApply.GetBehavior = function(spec)
    return spec and behaviors[spec.Behavior] or nil
end

local callBehavior = function(behavior, method, ...)
    if behavior and behavior[method] then return behavior[method](...) end
end

ThemeApply.GetTransitionEffect = function(spec)
    return spec and (spec.Effect or callBehavior(ThemeApply.GetBehavior(spec), "GetEffectSpec", spec)) or nil
end

ThemeApply.ConfigureIconBehavior = function(frame, style)
    callBehavior(frame.atIconBehavior, "ResetIcon", frame)
    frame.atIconBehavior = not frame.atIconSkinned and ThemeApply.GetBehavior(style) or nil
    callBehavior(frame.atIconBehavior, "ConfigureIcon", frame, style)
end

ThemeApply.IconState = function(frame, ...)
    return callBehavior(frame.atIconBehavior, "IconState", frame, ...)
end

ThemeApply.ConfigureTimelineMotion = function(frame, ...)
    return callBehavior(frame.atIconBehavior, "ConfigureTimelineMotion", frame, ...)
end

ThemeApply.StopTimelineMotion = function(frame, ...)
    return callBehavior(frame.atIconBehavior, "StopTimelineMotion", frame, ...)
end

ThemeApply.EnterTimelineMotion = function(frame, ...)
    return callBehavior(frame.atIconBehavior, "EnterTimelineMotion", frame, ...)
end

ThemeApply.UpdateTimelineMotion = function(frame, ...)
    return callBehavior(frame.atIconBehavior, "UpdateTimelineMotion", frame, ...)
end

ThemeApply.UpdateIconTrail = function(frame, ...)
    return callBehavior(frame.atIconBehavior, "UpdateIconTrail", frame, ...)
end

ThemeApply.ConfigureTrack = function(frame, track)
    callBehavior(frame.atTrackBehavior, "ResetTrack", frame)
    frame.atTrackBehavior = ThemeApply.GetBehavior(track)
    callBehavior(frame.atTrackBehavior, "ConfigureTrack", frame, track)
end

ThemeApply.ConfigureTimelineArt = function(frame, style, arrival, horizontal)
    callBehavior(frame.atTimelineArtBehavior, "ResetTimelineArt", frame)
    frame.atTimelineArtBehavior = ThemeApply.GetBehavior(style)
    callBehavior(frame.atTimelineArtBehavior, "ConfigureTimelineArt", frame, style, arrival, horizontal)
end

ThemeApply.UpdateTrack = function(frame)
    callBehavior(frame.atTrackBehavior, "UpdateTrack", frame)
end

local stopWindowEnter = function(frame)
    callBehavior(frame.atWindowEnterBehavior, "StopWindowEnter", frame)
    frame.atWindowEnterBehavior = nil
end

local playWindowEnter = function(frame)
    local enter = frame.atWindowStyle.Enter
    local behavior = enter and ThemeApply.GetBehavior(enter.Ghost)
    frame.atWindowEnterBehavior = behavior
    return callBehavior(behavior, "PlayWindowEnter", frame)
end

---the path of a texture of Media/Textures/Theme, fetched from SharedMedia
---@param name string
---@return string
ThemeApply.File = function(name)
    return SharedMedia:Fetch(private.ThemeMediaType, private.MediaName(name))
end

---reads a palette name, { r =, g =, b =, a = } or { r, g, b, a }, alpha replaces the color's alpha
---@param color string|table|nil
---@param alpha number|nil
---@return number, number, number, number
ThemeApply.Color = function(color, alpha)
    if type(color) == "string" then
        local palette = private.GetCurrentTheme().Palette
        color = palette and palette[color]
    end
    if not color then
        return 1, 1, 1, alpha or 1
    end
    if color.r then
        return color.r, color.g, color.b, alpha or color.a or 1
    end
    return color[1], color[2], color[3], alpha or color[4] or 1
end

---mixes two colors, progress 0 is from and 1 is to
---@return number, number, number, number
ThemeApply.MixColor = function(from, to, progress, fromAlpha, toAlpha)
    local r1, g1, b1, a1 = ThemeApply.Color(from, fromAlpha)
    local r2, g2, b2, a2 = ThemeApply.Color(to, toAlpha)
    return r1 + (r2 - r1) * progress, g1 + (g2 - g1) * progress, b1 + (b2 - b1) * progress, a1 + (a2 - a1) * progress
end

---turns { OUTLINE = true, MONOCHROME = false } into "OUTLINE"
---@param flags table|nil
---@return string
ThemeApply.FontFlags = function(flags)
    local result = ""
    for flag, isEnabled in pairs(flags or {}) do
        if isEnabled then
            result = result == "" and flag or result .. "," .. flag
        end
    end
    return result
end

---whether a font spec's own font draws the client's locale, Locales lists them and all do without it
---@param spec table
---@return boolean
local hasLocale = function(spec)
    if not spec.Locales then
        return true
    end
    return tContains(spec.Locales, GetLocale())
end

---applies a font spec: Object (font object name), Media (SharedMedia font) or Path only for the Locales it lists,
---Size, Flags, Color, Shadow
---@param fontString FontString|Font
---@param spec table|nil
ThemeApply.Font = function(fontString, spec)
    if not spec then return end
    local base = spec.Object and _G[spec.Object]
    if base then
        fontString:SetFontObject(base)
    end
    local ownFont = (spec.Media or spec.Path) and hasLocale(spec)
    -- a font set before (another theme's) stays over the font object, so the object's own font is set again
    if ownFont or spec.Size or spec.Flags or base then
        local path, size, flags = (base or fontString):GetFont()
        if ownFont then
            path = spec.Media and SharedMedia:Fetch("font", spec.Media) or spec.Path
        end
        if spec.Flags then
            flags = ThemeApply.FontFlags(spec.Flags)
        end
        fontString:SetFont(path, spec.Size or size, flags or "")
    end
    if spec.Color then
        fontString:SetTextColor(ThemeApply.Color(spec.Color))
    end
    if spec.Shadow ~= nil then
        fontString:SetShadowColor(0, 0, 0, spec.Shadow and 1 or 0)
    end
end

local fontObjects = {}

---returns the font object of a text role of the theme's Fonts, made the first time it is asked for
---@param role string
---@return Font
ThemeApply.FontObject = function(role)
    if not fontObjects[role] then
        fontObjects[role] = CreateFont("AbilityTimelineFont" .. role)
        fontObjects[role]:SetFontObject(GameFontHighlight)
        ThemeApply.Font(fontObjects[role], private.GetCurrentTheme().Fonts[role])
    end
    return fontObjects[role]
end

---styles every role font object again after a theme change
ThemeApply.RefreshFonts = function()
    local fonts = private.GetCurrentTheme().Fonts
    for role, font in pairs(fontObjects) do
        ThemeApply.Font(font, fonts[role])
    end
end

---draws a font string with a text role
---@param fontString FontString
---@param role string
ThemeApply.FontRole = function(fontString, role)
    local font = ThemeApply.FontObject(role)
    fontString:SetFontObject(font)
    -- a color set on the font string before would win over the font object's
    fontString:SetTextColor(font:GetTextColor())
end

---keeps solid colors readable by window animations that copy GetTexture and GetVertexColor
ThemeApply.Solid = function(texture, r, g, b, a)
    texture:ClearTextureSlice()
    texture:SetTexture("Interface\\Buttons\\WHITE8X8")
    texture:SetVertexColor(r, g, b, a or 1)
end

---applies a texture spec: Atlas, Media (SharedMedia background), File (a texture of Media/Textures/Theme), Texture
---or only a Color, tinted by Color and Alpha, Slice nine-slices it with that margin
---@param texture Texture
---@param spec table|nil
---@return boolean -- whether the spec draws anything
ThemeApply.Texture = function(texture, spec)
    if not spec then
        texture:SetTexture(nil)
        return false
    end
    -- SetAtlas applies native slice data; clear the previous texture's slicing first.
    texture:ClearTextureSlice()
    if spec.Atlas and ThemeApply.AtlasInfo(spec.Atlas) then
        texture:SetTexCoord(0, 1, 0, 1)
        texture:SetAtlas(spec.Atlas)
    elseif spec.Media then
        texture:SetTexture(SharedMedia:Fetch("background", spec.Media))
        texture:SetTexCoord(0, 1, 0, 1)
    elseif spec.File then
        texture:SetTexture(ThemeApply.File(spec.File))
        texture:SetTexCoord(unpack(spec.Coords or { 0, 1, 0, 1 }))
    elseif spec.Texture then
        texture:SetTexture(spec.Texture)
        texture:SetTexCoord(unpack(spec.Coords or { 0, 1, 0, 1 }))
    elseif spec.Color then
        ThemeApply.Solid(texture, ThemeApply.Color(spec.Color, spec.Alpha))
        return true
    else
        texture:SetTexture(nil)
        return false
    end
    if spec.Slice then
        texture:SetTextureSliceMargins(spec.Slice, spec.Slice, spec.Slice, spec.Slice)
        texture:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched)
    end
    texture:SetBlendMode(spec.BlendMode or "BLEND")
    texture:SetVertexColor(ThemeApply.Color(spec.Color, spec.Alpha))
    return true
end

---returns native atlas metadata when the client supports it
ThemeApply.AtlasInfo = function(atlas)
    return C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas)
end

---creates a nine-sliced texture of Media/Textures/Theme
---@param parent Frame
---@param file string
---@param layer string
---@param subLevel number|nil
---@param margin number|nil
---@return Texture
ThemeApply.CreateSliced = function(parent, file, layer, subLevel, margin)
    local texture = parent:CreateTexture(nil, layer, nil, subLevel)
    texture:SetTexture(ThemeApply.File(file))
    margin = margin or 8
    texture:SetTextureSliceMargins(margin, margin, margin, margin)
    texture:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched)
    return texture
end

---optional control specifications; themes without these retain the standard widgets
ThemeApply.ControlStyle = function(name)
    local controls = private.GetCurrentTheme().Controls
    return controls and controls[name]
end

ThemeApply.PanelStyle = function(fill, edge)
    local style = ThemeApply.ControlStyle("Panel")
    for i, texture in ipairs({ fill, edge }) do
        texture:SetTexture(ThemeApply.File(style and (i == 1 and style.Fill or style.Edge) or
            (i == 1 and "panel" or "panel_edge")))
        local margin = style and style.Slice or 8
        texture:SetTextureSliceMargins(margin, margin, margin, margin)
        texture:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched)
    end
end

---gives a frame a fill and edge (frame.AtFill, frame.AtEdge) behind its content
---@param frame Frame
---@return Texture fill, Texture edge
ThemeApply.CreatePanel = function(frame)
    if not frame.AtFill then
        frame.AtFill = ThemeApply.CreateSliced(frame, "panel", "BACKGROUND", 1)
        frame.AtFill:SetAllPoints(frame)
        frame.AtEdge = ThemeApply.CreateSliced(frame, "panel_edge", "BORDER", 1)
        frame.AtEdge:SetAllPoints(frame)
    end
    ThemeApply.PanelStyle(frame.AtFill, frame.AtEdge)
    return frame.AtFill, frame.AtEdge
end

ThemeApply.ConfigureSettingsWindow = function(widget, style)
    callBehavior(ThemeApply.GetBehavior(style), "ConfigureSettingsWindow", widget, style)
end

---applies a backdrop spec: Background and Border (SharedMedia names) or BgFile and EdgeFile, EdgeSize,
---TileSize, Insets, Color, BorderColor
---@param frame Frame a BackdropTemplate frame
---@param spec table
ThemeApply.Backdrop = function(frame, spec)
    local bgFile, edgeFile = spec.BgFile, spec.EdgeFile
    if spec.Background then
        bgFile = SharedMedia:Fetch("background", spec.Background)
    end
    if spec.Border then
        edgeFile = SharedMedia:Fetch("border", spec.Border)
    end
    frame:SetBackdrop({
        bgFile = bgFile,
        edgeFile = edgeFile,
        tile = true,
        tileSize = spec.TileSize or 32,
        edgeSize = spec.EdgeSize or 1,
        insets = spec.Insets or { left = 0, right = 0, top = 0, bottom = 0 },
    })
    frame:SetBackdropColor(ThemeApply.Color(spec.Color))
    frame:SetBackdropBorderColor(ThemeApply.Color(spec.BorderColor))
end

---plays a fade and scale in on a frame when it is shown, the client runs it without any Lua
---@param frame Frame
---@param scale number|nil -- the scale it grows from
ThemeApply.AddShowAnimation = function(frame, scale)
    if frame.AtShowAnimation then return end
    local group = frame:CreateAnimationGroup()
    local fade = group:CreateAnimation("Alpha")
    fade:SetFromAlpha(0)
    fade:SetToAlpha(1)
    local grow = group:CreateAnimation("Scale")
    grow:SetScaleFrom(scale or 0.96, scale or 0.96)
    grow:SetScaleTo(1, 1)
    grow:SetOrigin("CENTER", 0, 0)
    frame.AtShowAnimation = group
    frame:HookScript("OnShow", function()
        if private.GetAnimationLevel() == private.ANIMATION_LEVELS.OFF then return end
        local enter = frame.atWindowStyle and frame.atWindowStyle.Enter
        if callBehavior(ThemeApply.GetBehavior(enter and enter.Ghost), "SkipWindowAnimation", frame, enter) then return end
        local time = private.GetMotion("Open")
        fade:SetDuration(time)
        grow:SetDuration(time)
        local showScale = frame.atWindowStyle and frame.atWindowStyle.ShowScale or scale or 0.96
        grow:SetScaleFrom(showScale, showScale)
        group:Play()
    end)
end

---applies Zoom, Mask, Overlay and Glow of an icon style, icons skinned by Masque keep their skin
---@param maskTexture MaskTexture
---@param mask table|false
---@return boolean -- whether the mask has a shape
ThemeApply.Mask = function(maskTexture, mask)
    if not mask then
        return false
    elseif mask.Atlas and ThemeApply.AtlasInfo(mask.Atlas) then
        maskTexture:SetTexCoord(0, 1, 0, 1)
        maskTexture:SetAtlas(mask.Atlas)
        return true
    elseif mask.File or mask.Texture then
        local wrap = mask.WrapMode or "CLAMPTOBLACKADDITIVE"
        maskTexture:SetTexture(mask.File and ThemeApply.File(mask.File) or mask.Texture, wrap, wrap)
        maskTexture:SetTexCoord(unpack(mask.Coords or { 0, 1, 0, 1 }))
        return true
    end
    return false
end

-- the points of the top, bottom, left and right border edge
local EDGE_POINTS = {
    { "TOPLEFT", "TOPRIGHT" },
    { "BOTTOMLEFT", "BOTTOMRIGHT" },
    { "TOPLEFT", "BOTTOMLEFT" },
    { "TOPRIGHT", "BOTTOMRIGHT" },
}

---lays the dispel and boss mod border edges out as four bars along the icon's sides, or with a Border.File (e.g. a
---ring in the shape of a masked icon) each edge covers the whole icon so whichever is shown draws the border, over
---the icon's overlay and under its badges. an event with several dispel types shows all their borders, the first type
---is drawn on top like its dispel icon
---@param frame Frame
---@param border table
local layoutBorderEdges = function(frame, border)
    local source = border.Source
    local whole = (source or border.File) and true or false
    if frame.edgesWhole == whole and frame.atBorderSource == source then return end
    for group, edges in ipairs({ frame.BossModsBorderEdges or {}, unpack(frame.DispellTypeBorderEdges or {}) }) do
        for index, edge in ipairs(edges) do
            edge.atLayer = edge.atLayer or edge:GetDrawLayer()
            edge.atBorderDuplicate = whole and index > 1
            edge:ClearAllPoints()
            if whole then
                edge:SetAllPoints(source or frame.SpellIcon)
                edge:SetDrawLayer("OVERLAY", 7 - group)
            else
                for _, point in ipairs(EDGE_POINTS[index]) do
                    edge:SetPoint(point, frame.SpellIcon, point)
                end
                edge:SetDrawLayer(edge.atLayer, 8 - group)
            end
        end
    end
    frame.edgesWhole = whole
    frame.atBorderSource = source
end

---styles only addon-owned cooldowns; Masque owns every part of a skinned cooldown
ThemeApply.CooldownArt = function(frame, style, skinned)
    frame.CooldownClip:SetClipsChildren(not skinned)
    if skinned then return end
    local cooldown = frame.Cooldown
    cooldown:ClearAllPoints()
    cooldown:SetAllPoints(frame)
    local swipe = style.Swipe or (frame.iconMasked and style.Mask)
    local atlas = swipe and swipe.Atlas and ThemeApply.AtlasInfo(swipe.Atlas)
    -- Prefer the standalone replacement when one exists, rather than the entire atlas sheet.
    local texture = swipe and (swipe.File and ThemeApply.File(swipe.File) or swipe.Texture) or
        atlas and (atlas.file or atlas.filename) or "Interface\\Buttons\\WHITE8X8"
    cooldown:SetSwipeTexture(texture, 0, 0, 0, 0.64)
    if cooldown.SetTexCoordRange then
        local coords = swipe and swipe.Coords
        local left, right, top, bottom = 0, 1, 0, 1
        if coords then
            left, right, top, bottom = unpack(coords)
        elseif atlas and not (swipe.File or swipe.Texture) then
            left, right, top, bottom = atlas.leftTexCoord, atlas.rightTexCoord, atlas.topTexCoord, atlas.bottomTexCoord
        end
        cooldown:SetTexCoordRange(CreateVector2D(left, top), CreateVector2D(right, bottom))
    end
    cooldown:SetDrawEdge(not frame.iconMasked)
    cooldown:SetUseCircularEdge(false)
    cooldown:SetEdgeScale(1)
    cooldown:SetEdgeTexture("Interface\\Cooldown\\UI-HUD-ActionBar-SecondaryCooldown", 1, 1, 1, 1)
    cooldown:SetDrawBling(false)
end

local FULL_CROP = { 0, 1, 0, 1 }

---cuts a merged image from the icon's own crop (atCrop), never read back from the image; the slice keeps its crop
---(atCoords) for the exits that copy it
ThemeApply.LayoutIconSlice = function(slice, icon, index, count, width, height)
    slice:ClearAllPoints()
    slice:SetPoint("TOPLEFT", icon, "TOPLEFT", (index - 1) * width / count, 0)
    slice:SetSize(width / count, height)
    local crop = icon.atCrop or FULL_CROP
    local span = crop[2] - crop[1]
    slice.atCoords = { crop[1] + span * (index - 1) / count, crop[1] + span * index / count, crop[3], crop[4] }
    slice:SetTexCoord(unpack(slice.atCoords))
end

---the size the icon was set to: an icon showing an encounter's texture is never measured, its size can be secret
ThemeApply.IconSize = function(frame)
    return frame.atIconSize, frame.atIconSize
end

---places a texture around the icon image, offsets scale per axis with the icon against referenceSize
ThemeApply.PlaceIconArt = function(frame, texture, offsets, referenceSize)
    local width, height = frame:GetSize()
    local x = referenceSize and width / referenceSize or 1
    local y = referenceSize and height / referenceSize or 1
    texture:ClearAllPoints()
    texture:SetPoint("TOPLEFT", frame.SpellIcon, "TOPLEFT", (offsets.left or 0) * x, (offsets.top or 0) * y)
    texture:SetPoint("BOTTOMRIGHT", frame.SpellIcon, "BOTTOMRIGHT", (offsets.right or 0) * x, (offsets.bottom or 0) * y)
end

---keeps native overlay padding proportional to the icon, including big/group icon resizes
ThemeApply.LayoutIconArt = function(frame)
    local style = frame.atIconStyle
    if not style or frame.atIconSkinned then return end
    local overlay = style.Overlay
    if overlay and frame.IconOverlay then
        ThemeApply.PlaceIconArt(frame, frame.IconOverlay, overlay.Offsets or {}, overlay.ReferenceSize)
    end
    callBehavior(frame.atIconBehavior, "LayoutIconArt", frame)
end

---raise the entire moving icon above queued/paused icons, including their child frames
ThemeApply.IconPriority = function(frame, moving)
    if frame.atIconMoving == moving then return end
    frame.atIconBaseLevel = frame.atIconBaseLevel or frame:GetFrameLevel()
    frame:SetFrameLevel(frame.atIconBaseLevel + (moving and 10 or 0))
    frame.atIconMoving = moving
end

---@param frame Frame
---@param icon Texture
---@param style table
---@param overlayParent Frame
---@param skinned boolean
ThemeApply.IconArt = function(frame, icon, style, overlayParent, skinned)
    iconFrames[frame] = true
    frame.atIconStyle = style
    frame.atIconSkinned = skinned
    frame.atIconBorder = skinned and frame.MasqueBorderStyle or style.Border
    if not frame.atIconLayoutHook then
        frame:HookScript("OnSizeChanged", ThemeApply.LayoutIconArt)
        frame.atIconLayoutHook = true
    end
    if skinned then
        icon.zoomApplied = nil
        -- Masque crops the image itself, merged images and exits use the theme's crop as it can't be read back
        icon.atCrop = { private.ZoomCrop(1 - style.Zoom) }
    else
        icon:ClearAllPoints()
        icon:SetAllPoints(frame)
        if icon.zoomApplied ~= 1 - style.Zoom then
            private.ResetZoom(icon)
            private.SetZoom(icon, 1 - style.Zoom)
            icon.zoomApplied = 1 - style.Zoom
        end
    end

    if not frame.AtIconMask then
        frame.AtIconMask = frame:CreateMaskTexture()
        frame.AtIconMask:SetAllPoints(icon)
    end
    local masked = ThemeApply.Mask(frame.AtIconMask, style.Mask)
    local iconMasked = not skinned and masked
    if iconMasked ~= (frame.iconMasked or false) then
        if iconMasked then icon:AddMaskTexture(frame.AtIconMask)
        else icon:RemoveMaskTexture(frame.AtIconMask) end
        frame.iconMasked = iconMasked
    end
    if masked ~= (frame.mergedMasked or false) then
        local textures = { unpack(frame.MergeSlices or {}) }
        for _, texture in ipairs(frame.MergeSeparators or {}) do textures[#textures + 1] = texture end
        for _, texture in ipairs(textures) do
            if masked then
                texture:AddMaskTexture(frame.AtIconMask)
            else
                texture:RemoveMaskTexture(frame.AtIconMask)
            end
        end
        frame.mergedMasked = masked
    end
    layoutBorderEdges(frame, frame.atIconBorder)

    if not frame.IconOverlay then
        frame.IconOverlay = overlayParent:CreateTexture(nil, "OVERLAY", nil, -8)
        frame.IconShade = overlayParent:CreateTexture(nil, "BORDER", nil, 7)
        frame.IconShade:SetAllPoints(icon)
        frame.IconGlow = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
    end
    -- a shade over the icon under the overlay, such as an inner shadow that gives a lit border its depth
    frame.IconShade:SetShown(not skinned and ThemeApply.Texture(frame.IconShade, style.Shade) or false)
    local overlay = style.Overlay
    if overlay and not skinned and ThemeApply.Texture(frame.IconOverlay, overlay) then
        local offsets = overlay.Offsets or { left = 0, top = 0, right = 0, bottom = 0 }
        frame.IconOverlay:ClearAllPoints()
        frame.IconOverlay:SetPoint("TOPLEFT", icon, "TOPLEFT", offsets.left, offsets.top)
        frame.IconOverlay:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", offsets.right, offsets.bottom)
        frame.IconOverlay:Show()
    else
        frame.IconOverlay:Hide()
    end
    local glow = style.Glow
    if not skinned and glow and ThemeApply.Texture(frame.IconGlow, glow) then
        frame.IconGlow:ClearAllPoints()
        frame.IconGlow:SetPoint("TOPLEFT", icon, "TOPLEFT", -glow.Spread, glow.Spread)
        frame.IconGlow:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", glow.Spread, -glow.Spread)
        frame.IconGlow:Show()
    else
        frame.IconGlow:Hide()
    end

    -- the glows of the boss mod border and of every dispel type border, colored with their border
    if not frame.BorderGlows then
        frame.BorderGlows = {}
        for i = 1, #private.dispellTypeList + 1 do
            frame.BorderGlows[i] = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
        end
    end
    local borderGlow = frame.atIconBorder.Glow
    for _, texture in ipairs(frame.BorderGlows) do
        texture:ClearAllPoints()
        if borderGlow then
            texture:SetPoint("TOPLEFT", icon, "TOPLEFT", -borderGlow.Spread, borderGlow.Spread)
            texture:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", borderGlow.Spread, -borderGlow.Spread)
        end
    end
    ThemeApply.ConfigureIconBehavior(frame, style)
    ThemeApply.IconState(frame, frame.state, frame.eventInfo or
        (frame.eventID and private.manager.getEventInfo(frame.eventID)))
    ThemeApply.LayoutIconArt(frame)
end

---reports only addon/skin geometry and artwork, never event textures or secret visibility
ThemeApply.DebugIconGeometry = function(print)
    for frame in pairs(iconFrames) do
        if frame:IsShown() then
            local width, height = frame:GetSize()
            print("icon:", frame:GetName(), "frame:", width, height, "image:", ThemeApply.IconSize(frame),
                "scale:", frame:GetScale(), "Masque:", frame.atIconSkinned, "masked:", frame.iconMasked)
            local source = frame.atBorderSource
            print("border:", source and (source:GetAtlas() or source:GetTexture()) or frame.atIconBorder.File,
                "whole:", frame.edgesWhole)
            if frame.CooldownText then
                local cooldown = frame.Cooldown
                print("swipe:", cooldown:GetWidth(), cooldown:GetHeight(), "scale:", cooldown:GetScale(),
                    "edge:", cooldown:GetDrawEdge(), "edge scale:", cooldown:GetEdgeScale())
            end
        end
    end
end

---the color of a dispel type of private.dispellTypeList in the theme's palette
---@param dispelType table
---@return number, number, number, number
ThemeApply.DispelColor = function(dispelType)
    return ThemeApply.Color("Dispel" .. dispelType.name)
end

---tints a border edge or glow of a spec (File, BlendMode, Alpha), call it before SetEventIconTextures
---@param texture Texture
---@param spec table|false|nil
local tintBorder = function(texture, spec, r, g, b, a)
    if not spec then return end
    if spec.File or spec.Source then
        texture:SetVertexColor(r, g, b, (a or 1) * (spec.Alpha or 1))
    else
        texture:SetVertexColor(1, 1, 1, 1)
    end
    texture:SetBlendMode(spec.BlendMode or "BLEND")
end

---puts a border edge or glow's art in place, a plain color without a File, nothing without a spec. it only replaces
---the atlas SetEventIconTextures set, the alpha it shows or hides the texture with is kept
---@param texture Texture
---@param spec table|false|nil
local paintBorder = function(texture, spec, r, g, b, a)
    if not spec or texture.atBorderDuplicate then
        texture:SetTexture(nil)
    elseif spec.Source then
        local source = spec.Source
        texture:ClearTextureSlice()
        local atlas = source:GetAtlas()
        if atlas then
            texture:SetAtlas(atlas)
        else
            texture:SetTexture(source:GetTexture())
        end
        texture:SetTexCoord(source:GetTexCoord())
        texture:SetBlendMode(source:GetBlendMode())
    elseif spec.File then
        texture:SetTexture(ThemeApply.File(spec.File))
        texture:SetTexCoord(0, 1, 0, 1)
    else
        texture:SetColorTexture(r, g, b, (a or 1) * (spec.Alpha or 1))
    end
end

---@param texture Texture
---@param spec table|false|nil
local borderTexture = function(texture, spec, r, g, b, a)
    tintBorder(texture, spec, r, g, b, a)
    paintBorder(texture, spec, r, g, b, a)
end

---draws the border edges and glow of the index-th dispel type in the Border style, with an eventID only where the event
---has that type
---@param frame Frame
---@param index number
---@param border table
---@param eventID number|nil
ThemeApply.DispelBorder = function(frame, index, border, eventID)
    border = frame.atIconBorder or border
    local dispelType = private.dispellTypeList[index]
    local r, g, b, a = ThemeApply.DispelColor(dispelType)
    local apply = function(texture, spec)
        tintBorder(texture, spec, r, g, b, a)
        if eventID then
            private.manager.SetEventIconTextures(eventID, dispelType.mask, { texture })
        end
        paintBorder(texture, spec, r, g, b, a)
    end
    for _, edge in ipairs(frame.DispellTypeBorderEdges[index]) do
        apply(edge, border)
    end
    apply(frame.BorderGlows[index + 1], border.Glow)
end

---draws and shows the boss mod border edges and glow in the Border style, or hides them without a color
---@param frame Frame
---@param border table
---@param color table|nil
ThemeApply.BossModsBorder = function(frame, border, color)
    border = frame.atIconBorder or border
    for _, edge in ipairs(frame.BossModsBorderEdges) do
        if color then
            borderTexture(edge, border, color.r, color.g, color.b, color.a)
        end
        edge:SetShown(color ~= nil)
    end
    local glow = frame.BorderGlows[1]
    if color then
        borderTexture(glow, border.Glow, color.r, color.g, color.b, color.a)
    end
    glow:SetShown(color ~= nil and border.Glow and true or false)
end

---refreshes geometry and event visibility together, without reading secret dispel values
ThemeApply.IconBorders = function(frame, settings, eventID)
    frame.atIconSettings = settings
    local border = frame.atIconBorder
    local width = frame.atIconStyle.BorderWidth
    for group, edges in ipairs({ frame.BossModsBorderEdges, unpack(frame.DispellTypeBorderEdges) }) do
        if not frame.edgesWhole then
            edges[1]:SetHeight(width)
            edges[2]:SetHeight(width)
            edges[3]:SetWidth(width)
            edges[4]:SetWidth(width)
        end
        if group > 1 then
            ThemeApply.DispelBorder(frame, group - 1, border, eventID)
            for _, edge in ipairs(edges) do
                edge:SetShown(settings.border == private.IconBorderSettings.dispell)
            end
        end
    end
    for i = 2, #frame.BorderGlows do
        frame.BorderGlows[i]:SetShown(settings.border == private.IconBorderSettings.dispell and border.Glow and true or false)
    end
    ThemeApply.BossModsBorder(frame, border,
        settings.border == private.IconBorderSettings.bossmods and private.manager.getEventBorderColor(eventID) or nil)
end

---hides a button's normal, pushed, highlight and disabled textures
---@param button Button
ThemeApply.HideButtonTextures = function(button)
    for _, getter in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture", "GetDisabledTexture" }) do
        local texture = button[getter](button)
        if texture then
            texture:SetAlpha(0)
        end
    end
end

---plays an Enter animation when an icon or text appears: a fade in, growing from Scale when it has one (texts
---shimmer while scaled, so they leave it out); icons pass keepSize, their borders and badges don't grow with them
---@param frame Frame
---@param enter table|nil
---@param keepSize boolean|nil
---@param icon Texture|nil -- the texture a Ghost with Source "Icon" shows
---@param iconFile any -- the file icon shows
ThemeApply.PlayEnter = function(frame, enter, keepSize, icon, iconFile)
    if not enter or private.GetAnimationLevel() == private.ANIMATION_LEVELS.OFF then return end
    if not frame.AtEnterAnimation then
        local group = frame:CreateAnimationGroup()
        group.Grow = group:CreateAnimation("Scale")
        group.Grow:SetOrigin("CENTER", 0, 0)
        group.Grow:SetScaleTo(1, 1)
        frame.AtEnterAnimation = group
    end
    local group = frame.AtEnterAnimation
    local time = private.GetMotion("Enter")
    group:Stop()
    if enter.Scale and not keepSize then
        group.Grow:SetDuration(time)
        group.Grow:SetScaleFrom(enter.Scale, enter.Scale)
        group.Grow:SetSmoothing("OUT")
        group:Play()
    end
    -- an Alpha animation on the icon resets the alpha SetEventIconTextures hides its dispel borders with, so the
    -- fade only changes the frame's alpha
    private.Tween(group, 0, 1, time, enter.Ease or "outCubic", function(alpha)
        frame:SetAlpha(alpha)
    end)
    ThemeApply.PlayEnterEffects(frame, enter, icon, iconFile)
end

---plays an icon style's Pulse once, when the icon passes a tick of the timeline: Glow flares up behind it, and Ghost,
---Flare, Effect, Vortex and Burst play over it as in an Exit; the icon keeps its size, its borders and badges wouldn't
---grow with it
---@param frame Frame
---@param pulse table|nil
---@param icon Texture|nil -- the texture a Ghost with Source "Icon" shows
---@param iconFile any -- the file icon shows
ThemeApply.PlayPulse = function(frame, pulse, icon, iconFile)
    if not pulse or private.GetAnimationLevel() == private.ANIMATION_LEVELS.OFF then return end
    if not frame.AtPulse then
        frame.AtPulse = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
        frame.AtPulse:Hide()
        local glow = frame.AtPulse:CreateAnimationGroup()
        glow:SetToFinalAlpha(true)
        glow.Appear = glow:CreateAnimation("Alpha")
        glow.Appear:SetFromAlpha(0)
        glow.Appear:SetToAlpha(1)
        glow.Appear:SetSmoothing("OUT")
        glow.Appear:SetOrder(1)
        glow.Fade = glow:CreateAnimation("Alpha")
        glow.Fade:SetFromAlpha(1)
        glow.Fade:SetToAlpha(0)
        glow.Fade:SetSmoothing("IN")
        glow.Fade:SetOrder(2)
        glow:SetScript("OnFinished", function() frame.AtPulse:Hide() end)
        frame.AtPulseGlow = glow
    end
    local time = pulse.Time or 0.5
    local glow = pulse.Glow
    frame.AtPulseGlow:Stop()
    if glow then
        local spread = glow.Spread or 18
        frame.AtPulse:ClearAllPoints()
        frame.AtPulse:SetPoint("TOPLEFT", -spread, spread)
        frame.AtPulse:SetPoint("BOTTOMRIGHT", spread, -spread)
        -- a texture spec of its own, or the round glow
        if glow.File then
            ThemeApply.Texture(frame.AtPulse, glow)
        else
            frame.AtPulse:ClearTextureSlice()
            frame.AtPulse:SetTexture(ThemeApply.File("glow"))
            frame.AtPulse:SetBlendMode("ADD")
            frame.AtPulse:SetVertexColor(ThemeApply.Color(glow.Color, glow.Alpha))
        end
        frame.AtPulseGlow.Appear:SetDuration(time * 0.3)
        frame.AtPulseGlow.Fade:SetDuration(time * 0.7)
        frame.AtPulse:Show()
        frame.AtPulseGlow:Play()
    else
        frame.AtPulse:Hide()
    end
    local effect = ThemeApply.GetTransitionEffect(pulse)
    if pulse.Ghost or pulse.Flare or effect or pulse.Vortex or pulse.Burst then
        ThemeApply.PlayExit(frame, { Ghost = pulse.Ghost, Flare = pulse.Flare, Effect = effect, Vortex = pulse.Vortex,
            Burst = pulse.Burst }, icon, iconFile, true)
    end
end

---stops a Pulse playing on frame
---@param frame Frame
ThemeApply.StopPulse = function(frame)
    if not frame.AtPulse then return end
    frame.AtPulseGlow:Stop()
    frame.AtPulse:Hide()
end

---gives a UIPanelCloseButton the theme's close glyph
---@param button Button
ThemeApply.SkinCloseButton = function(button, art)
    if not button.AtIcon then
        ThemeApply.HideButtonTextures(button)
        button:SetSize(24, 24)
        button.AtIcon = button:CreateTexture(nil, "ARTWORK")
        button.AtIcon:SetTexture(ThemeApply.File("close"))
        button.AtIcon:SetPoint("CENTER")
        button.AtIcon:SetSize(14, 14)
        button:HookScript("OnEnter", function()
            private.TweenMotion(button.AtIcon, "Hover", 0, 1, function(progress)
                button.AtIcon:SetVertexColor(ThemeApply.MixColor(button.atCloseArt and "White" or "Muted", "Text", progress))
            end)
        end)
        button:HookScript("OnLeave", function()
            private.TweenMotion(button.AtIcon, "Hover", 1, 0, function(progress)
                button.AtIcon:SetVertexColor(ThemeApply.MixColor(button.atCloseArt and "White" or "Muted", "Text", progress))
            end)
        end)
    end
    button.atCloseArt = art
    if art then
        ThemeApply.Texture(button.AtIcon, art)
        button.AtIcon:SetSize(24, 24)
    else
        button.AtIcon:SetTexture(ThemeApply.File("close"))
        button.AtIcon:SetTexCoord(0, 1, 0, 1)
        button.AtIcon:SetSize(14, 14)
        button.AtIcon:SetVertexColor(ThemeApply.Color("Muted"))
    end
end

---lays out a window's Decor: textures at points of the window (tape on its corners, doodles in its margins), each
---{ File, Color, Alpha, BlendMode, Point, X, Y, Size = { width, height }, Rotation (degrees), Layer, SubLevel }
---@param shell Frame
---@param decor table[]|nil
local applyDecor = function(shell, decor)
    decor = decor or {}
    for i, spec in ipairs(decor) do
        local texture = shell.Decor[i]
        if not texture then
            texture = shell:CreateTexture()
            shell.Decor[i] = texture
        end
        texture:SetDrawLayer(spec.Layer or "OVERLAY", spec.SubLevel or 0)
        ThemeApply.Texture(texture, spec)
        texture:ClearAllPoints()
        texture:SetPoint("CENTER", shell, spec.Point or "CENTER", spec.X or 0, spec.Y or 0)
        texture:SetSize(spec.Size[1], spec.Size[2])
        texture:SetRotation(math.rad(spec.Rotation or 0))
        texture:Show()
    end
    for i = #decor + 1, #shell.Decor do
        shell.Decor[i]:Hide()
    end
end

---draws a window in the theme's window style: shadow, rounded body, wash, edge, a line under its header,
---a fade in when shown and sparkles along the header when the theme has them; Grain (a texture spec over the body),
---EdgeArt (a texture spec in place of the edge) and Decor dress it up further; Glass (as the timeline's,
---Util/Glass.lua) makes the body a pane of glass over the world instead
---@param frame Frame
---@param style table -- a Windows style of the theme
---@param closeButton Button|nil
---@param title FontString|nil -- defaults to the title of a PortraitFrameTemplate
ThemeApply.Window = function(frame, style, closeButton, title)
    callBehavior(frame.atWindowBehavior, "ResetWindow", frame)
    frame.atWindowBehavior = ThemeApply.GetBehavior(style)
    stopWindowEnter(frame)
    ThemeApply.StopEnterEffects(frame)
    for _, key in ipairs({ "NineSlice", "Bg", "TopTileStreaks", "PortraitContainer" }) do
        if frame[key] then
            frame[key]:Hide()
        end
    end
    if frame.SetBackdrop then
        frame:SetBackdrop(nil)
    end
    frame.atWindowStyle = style
    local shell = frame.AtShell
    if not shell then
        shell = CreateFrame("Frame", nil, frame, "BackdropTemplate")
        shell:SetAllPoints(frame)
        shell:SetFrameLevel(frame:GetFrameLevel())
        shell.Shadow = ThemeApply.CreateSliced(shell, "shadow", "BACKGROUND", -8, 24)
        shell.Shadow:SetPoint("TOPLEFT", -16, 16)
        shell.Shadow:SetPoint("BOTTOMRIGHT", 16, -16)
        shell.Fill = ThemeApply.CreateSliced(shell, "panel", "BACKGROUND", -7)
        shell.Fill:SetAllPoints(shell)
        shell.Grain = shell:CreateTexture(nil, "BACKGROUND", nil, -6)
        shell.Grain:SetAllPoints(shell)
        shell.HeaderArt = shell:CreateTexture(nil, "BACKGROUND", nil, -5)
        shell.HeaderArt:SetPoint("TOPLEFT")
        shell.HeaderArt:SetPoint("TOPRIGHT")
        shell.Wash = shell:CreateTexture(nil, "BACKGROUND", nil, -5)
        shell.Wash:SetTexture(ThemeApply.File("gradient"))
        shell.Wash:SetPoint("TOPLEFT", 1, -1)
        shell.Wash:SetPoint("TOPRIGHT", -1, -1)
        shell.Edge = ThemeApply.CreateSliced(shell, "panel_edge", "BORDER", -8)
        shell.Edge:SetAllPoints(shell)
        shell.HeaderLine = shell:CreateTexture(nil, "BORDER")
        shell.HeaderLine:SetHeight(1)
        shell.EdgeArt = shell:CreateTexture(nil, "BORDER", nil, -7)
        shell.EdgeArt:SetAllPoints(shell)
        shell.Decor = {}
        shell.Glass = private.Glass.Create(shell)
        frame.AtShell = shell
        ThemeApply.AddShowAnimation(frame)
        frame:HookScript("OnShow", function()
            stopWindowEnter(frame)
            if not playWindowEnter(frame) then
                ThemeApply.PlayEnterEffects(frame, frame.atWindowStyle.Enter)
            end
        end)
        -- not when only a parent hid it, like UIParent while the interface is hidden
        frame:HookScript("OnHide", function()
            stopWindowEnter(frame)
            ThemeApply.StopEnterEffects(frame)
            if not frame:IsShown() and not frame.atWindowFadeComplete then
                ThemeApply.PlayExit(frame, frame.atWindowStyle.Exit)
            end
        end)
        shell.Sparkles = private.CreateParticles(shell, function(particle, spec)
            particle.x = math.random() * shell:GetWidth()
            if spec.Area == "All" then
                particle.y = math.random() * shell:GetHeight()
            else
                particle.y = shell:GetHeight() - math.random() * (frame.atWindowStyle.HeaderHeight or 34)
            end
        end)
    end
    shell.Shadow:SetVertexColor(ThemeApply.Color("Shadow"))
    if style.Backdrop then
        ThemeApply.Backdrop(shell, style.Backdrop)
    else
        shell:SetBackdrop(nil)
    end
    -- a glass body shows the world through it, its rim is its edge
    shell.Fill:SetShown(not style.Backdrop and not style.Glass)
    shell.Fill:SetVertexColor(ThemeApply.Color(style.Fill))
    shell.Edge:SetVertexColor(ThemeApply.Color(style.Edge))
    shell.Grain:SetShown(ThemeApply.Texture(shell.Grain, style.Grain))
    shell.HeaderArt:SetShown(ThemeApply.Texture(shell.HeaderArt, style.HeaderArt))
    if style.HeaderArt then shell.HeaderArt:SetHeight(style.HeaderArt.Height or 40) end
    shell.EdgeArt:SetShown(ThemeApply.Texture(shell.EdgeArt, style.EdgeArt))
    shell.Edge:SetShown(not style.EdgeArt and not style.Backdrop and not style.Glass)
    shell.Glass:Apply(style.Glass)
    applyDecor(shell, style.Decor)
    shell.Wash:SetHeight(style.WashHeight or 120)
    shell.Wash:SetVertexColor(ThemeApply.Color(style.Wash))
    shell.Wash:SetBlendMode("ADD")
    shell.HeaderLine:ClearAllPoints()
    shell.HeaderLine:SetPoint("TOPLEFT", 12, -(style.HeaderHeight or 34))
    shell.HeaderLine:SetPoint("TOPRIGHT", -12, -(style.HeaderHeight or 34))
    ThemeApply.Solid(shell.HeaderLine, ThemeApply.Color(style.HeaderLine))
    shell.Sparkles:Start(style.Sparkles)

    title = title or frame.TitleContainer and frame.TitleContainer.TitleText
    if title then
        ThemeApply.FontRole(title, "Title")
    end
    if frame.TitleContainer then
        frame.TitleContainer:ClearAllPoints()
        frame.TitleContainer:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -8)
        frame.TitleContainer:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -40, -8)
        frame.TitleContainer.TitleText:SetJustifyH("LEFT")
    end
    if closeButton then
        ThemeApply.SkinCloseButton(closeButton, style.CloseArt)
        closeButton:ClearAllPoints()
        closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -6)
    end
    if frame.Footer then
        ThemeApply.Solid(frame.Footer.Background, ThemeApply.Color(style.Footer))
        ThemeApply.FontRole(frame.Footer.AddonName, "Footer")
    end
    callBehavior(frame.atWindowBehavior, "ConfigureWindow", frame, style)
end
