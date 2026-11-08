local appName, app = ...
---@class AbilityTimeline
local private = app
local ThemeApply = private.ThemeApply

do
    local behavior = {}
    local setMask = ThemeApply.SetTransitionMask

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
        local time = progress * (host.ghostDuration or 0)
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
        host.WindowGroups, host.ghostDuration = groups, cursor
        stepWindowSketch(host, sketch, 0)
        host.windowSource, host.windowAlpha = window, window:GetAlpha()
        window:SetAlpha(0)
    end

    behavior.SetupGhost = function(host, ghost, icon, iconFile, frame)
        local texture, sketch = host.Ghost, ghost.Sketch
        if not host.GhostBack then
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
        end
        if ghost.Source == "Window" then
            texture:SetTexture(nil)
            texture:ClearTextureSlice()
            host:SetFrameLevel(math.min((frame.GetHighestFrameLevel and frame:GetHighestFrameLevel(true) or frame:GetFrameLevel() + 50) + 10, 9000))
        elseif ghost.Source == "Icon" and icon then
            texture:SetVertexColor(ThemeApply.Color(sketch.Color))
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
        local shaped = texture.atMasks[host.GhostShape] or false
        setMask(host.GhostBack, host.GhostShape, shaped)
        setMask(host.GhostOutline, host.GhostShape, shaped)
        setMask(texture, host.GhostDissolve, true)
        host.WindowParts, host.WindowLabels = {}, {}
        if ghost.Source == "Window" then setupWindowGhost(host, frame, sketch) end
    end

    behavior.StepGhost = function(host, ghost, progress)
        if ghost.Source == "Window" then stepWindowSketch(host, ghost.Sketch, progress)
        else stepSketch(host, ghost.Sketch, progress) end
    end

    behavior.ResetGhost = function(host)
        if host.windowSource then
            host.windowSource:SetAlpha(host.windowAlpha)
            host.windowSource, host.windowAlpha = nil, nil
        end
        for _, art in ipairs(host.WindowFrames or {}) do art:Hide() end
        host.WindowGroups, host.WindowParts, host.WindowLabels = nil, nil, nil
        if host.GhostBack then
            host.GhostBack:Hide()
            host.GhostOutline:Hide()
            host.Ghost:SetDesaturated(false)
            setMask(host.Ghost, host.GhostHatch, false)
            for _, layer in ipairs({ host.Ghost, host.GhostBack, host.GhostOutline }) do setMask(layer, host.GhostFill, false) end
        end
    end

    behavior.SkipWindowAnimation = function(frame, enter)
        return enter.Ghost.Source == "Window" and private.AmbientEffectsEnabled()
    end

    behavior.StopWindowEnter = function(frame)
        local pending = frame.atWindowSketch
        if not pending then return end
        private.StopTween(pending)
        frame:SetAlpha(pending.alpha)
        frame.atWindowSketch = nil
    end

    behavior.PlayWindowEnter = function(frame)
        local enter = frame.atWindowStyle.Enter
        local ghost = enter and enter.Ghost
        if not ghost or ghost.Source ~= "Window" or not private.AmbientEffectsEnabled() then return false end
        local pending = { alpha = frame:GetAlpha() }
        frame.atWindowSketch = pending
        frame:SetAlpha(0)
        -- Settings creates its page after Show. Copy its artwork after that layout completes.
        private.Tween(pending, 0, 1, 0.001, "linear", function() end, function()
            frame:SetAlpha(pending.alpha)
            frame.atWindowSketch = nil
            ThemeApply.PlayEnterEffects(frame, enter)
        end)
        return true
    end

    -- the texture coordinates that lay a mark's left end at the end icons arrive at, its top towards the frame's top or left
    local MARK_COORDS = {
        LEFT = { 0, 0, 0, 1, 1, 0, 1, 1 },
        RIGHT = { 1, 0, 1, 1, 0, 0, 0, 1 },
        BOTTOM = { 1, 0, 0, 0, 1, 1, 0, 1 },
        TOP = { 0, 0, 1, 0, 0, 1, 1, 1 },
    }

    ---keeps a mark Length times the timeline's thickness long
    ---@param frame Frame
    local function UpdateMarkSize(frame)
        if not frame.mark then return end
        if frame.isHorizontal then
            frame.Mark:SetWidth(frame:GetHeight() * (frame.mark.Length or 2))
        else
            frame.Mark:SetHeight(frame:GetWidth() * (frame.mark.Length or 2))
        end
    end

    ---a still texture across the timeline at the end icons arrive at, Length times its thickness long, e.g. a stroke of
    ---highlighter
    ---@param frame Frame
    ---@param mark table|nil
    ---@param arrival string
    ---@param isHorizontal boolean
    local function ApplyMark(frame, mark, arrival, isHorizontal)
        frame.mark = mark
        if not (mark and private.ThemeApply.Texture(frame.Mark, mark)) then
            frame.Mark:Hide()
            return
        end
        frame.Mark:ClearAllPoints()
        if isHorizontal then
            frame.Mark:SetPoint("TOP" .. arrival, frame, "TOP" .. arrival)
            frame.Mark:SetPoint("BOTTOM" .. arrival, frame, "BOTTOM" .. arrival)
        else
            frame.Mark:SetPoint(arrival .. "LEFT", frame, arrival .. "LEFT")
            frame.Mark:SetPoint(arrival .. "RIGHT", frame, arrival .. "RIGHT")
        end
        frame.Mark:SetTexCoord(unpack(MARK_COORDS[arrival]))
        frame.Mark:Show()
        UpdateMarkSize(frame)
    end

    behavior.ConfigureTimelineArt = function(frame, style, arrival, horizontal)
        if not frame.Mark then
            frame.Mark = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
            frame.Mark:Hide()
            frame:HookScript("OnSizeChanged", UpdateMarkSize)
        end
        ApplyMark(frame, style.Mark, arrival, horizontal)
    end

    behavior.ResetTimelineArt = function(frame)
        frame.mark = nil
        if frame.Mark then frame.Mark:Hide() end
    end

    ThemeApply.RegisterBehavior("Papercraft", behavior)
end
private.RegisterThemeTextures("Papercraft", { "confetti", "confetti_dot", "deckle", "doodle_heart", "doodle_plane",
    "doodle_sun", "hatch", "hatch_dense", "highlight", "paper_grain", "paper_strip", "sketch_box", "tape" },
    { "outline", "scribble", "tear", "wash" })

-- cream paper, ink, red and blue pencil, washi tape and a highlighter, after BetterBags' Papercraft (Sonata, Cidan):
-- a strip of torn paper with a stroke of highlighter where icons arrive, icons drawn and shaded in pencil, then
-- painted in, and torn off when they leave. Picked in tools/sim/scenarios/papercraft.js
local FONTS = "Interface\\AddOns\\AbilityTimeline\\Media\\Fonts\\"
local CAVEAT, PATRICK = "Caveat", "Patrick Hand"
-- the locales the fonts draw, the others keep the client's font
local LATIN = { "enUS", "enGB", "deDE", "frFR", "esES", "esMX", "itIT", "ptBR" }
local LATIN_CYRILLIC = { "enUS", "enGB", "deDE", "frFR", "esES", "esMX", "itIT", "ptBR", "ruRU" }

---a text role in handwriting: Caveat for titles and headings, Patrick Hand for the rest
local script = function(size, color)
    return { Object = "GameFontHighlight", Media = CAVEAT, Locales = LATIN_CYRILLIC, Size = size, Color = color, Shadow = false }
end
local hand = function(size, color)
    return { Object = "GameFontHighlight", Media = PATRICK, Locales = LATIN, Size = size, Color = color, Shadow = false }
end
-- names and numbers drawn over the game world stay white and outlined
local OUTLINED = function(size)
    return { Media = PATRICK, Locales = LATIN, Size = size, Flags = { OUTLINE = true }, Color = "White", Shadow = true }
end

local CONFETTI_TEXTURES = { private.ThemeApply.File("confetti"), private.ThemeApply.File("confetti"),
    private.ThemeApply.File("confetti_dot") }
local TAPE_COLORS = { "TapeTan", "TapeBlue", "TapePink", "Accent" }
-- bits of paper drifting down over the bar, drawn as they are, not as light
local CONFETTI = {
    Texture = CONFETTI_TEXTURES,
    Colors = TAPE_COLORS,
    Area = "All",
    Rate = 0.5,
    Max = 3,
    Size = { 7, 11 },
    Life = { 2.6, 4 },
    Speed = { { -6, 6 }, { -14, -6 } },
    Sway = { 6, 1.6 },
    Spin = 1.5,
    Alpha = 0.9,
    BlendMode = "BLEND",
    Steady = true,
}
local confettiBurst = function(count)
    return {
        Texture = CONFETTI_TEXTURES,
        Colors = TAPE_COLORS,
        Count = count,
        Size = { 7, 10 },
        Life = { 0.5, 0.9 },
        Speed = { { -90, 90 }, { 30, 120 } },
        Gravity = -320,
        Spin = 4,
        Alpha = 1,
        BlendMode = "BLEND",
        Steady = true,
    }
end

-- ripped away along a ragged line, white fibres along the tear
local TEARING = {
    Frames = "tear",
    Count = 12,
    Edge = { File = "tear_edge1", Color = "White", Alpha = 1 },
}
-- pencil hatching scribbled over it before the paper shows through, torn away when it hides
local SKETCH_IN = {
    Ghost = { Behavior = "Papercraft", File = "hatch", Color = "Muted", Time = 0.7, Sketch = { Back = "PaperLight", Frames = "scribble", Count = 12, Draw = 0.6 } },
}
local PENCIL_SKETCH = {
    Back = "PaperLight",
    Color = "Graphite",
    Hatch = "hatch_dense",
    Frames = "scribble",
    Count = 12,
    From = 0.12,
    Draw = 0.5,
    Outline = { File = "sketch_box", Color = "Ink", Frames = "outline", Until = 0.25 },
    Fill = { Frames = "wash", Count = 12 },
}
local WINDOW_SKETCH_IN = {
    Ghost = { Behavior = "Papercraft", Source = "Window", Time = 1.2,
        Sketch = { Color = "Graphite", Frames = "scribble", Hatch = "hatch", Count = 12,
            Loose = true, Trace = true, OutlineFrames = "outline", Retrace = 0.28, Overlap = 0.35,
            Blank = 0.08, Draw = 0.1, Ink = 0.04, Gap = 0.005, MaxTime = 1.2 },
    },
}
local TEAR_AWAY = {
    Ghost = { File = "panel", Slice = 8, Color = "Body", Dissolve = TEARING, Time = 0.5 },
    Burst = confettiBurst(6),
}

---a strip of washi tape over a corner of a window
local tape = function(point, x, rotation, color)
    return { File = "tape", Color = color, Alpha = 0.85, Point = point, X = x, Y = -2, Size = { 64, 16 }, Rotation = rotation }
end

---a sheet of paper with a torn edge, taped on and doodled on
local window = function(decor)
    return {
        Fill = "Body",
        Grain = { File = "paper_grain", Color = "Muted", Alpha = 0.16 },
        EdgeArt = { File = "deckle", Slice = 12, Color = "Ink", Alpha = 0.45 },
        WashHeight = 90,
        HeaderLine = "Line",
        Decor = decor,
        ShowScale = 1,
        Enter = WINDOW_SKETCH_IN,
        Exit = TEAR_AWAY,
    }
end

---the style of spell and big icons: a pencil square drawn round them, shaded in their own greys through close hatching,
---then colour soaking in like watercolour, torn off as they leave, a few bits of paper
---hopping off as they pass a tick (timeline icons only, big icons are already in sight)
local iconStyle = function(pulse, size)
    return {
        -- Three pencil dots draw on one after another without additive light.
        QueuedMarkers = pulse and {
            Art = { File = "confetti_dot", BlendMode = "BLEND" }, Colors = { "Accent", "Accent2", "Accent" },
            Size = 12, Spacing = 12, Offset = 5,
            Enter = { Time = 0.2, Stagger = 0.09, Grow = 0.4 },
        } or false,
        Enter = {
            Ghost = { Behavior = "Papercraft", Source = "Icon", Time = 0.9, Sketch = PENCIL_SKETCH },
        },
        Exit = {
            Ghost = { Source = "Icon", Dissolve = TEARING, Time = 0.4 },
            Burst = confettiBurst(2),
        },
        Pulse = pulse and { Glow = false, Burst = confettiBurst(3) } or false,
        Text = {
            Font = OUTLINED(size),
            Background = { Show = false, Media = false, File = "pill", Slice = 8, Color = "Body", Alpha = 0.85, Offset = { x = 8, y = 4 } },
        },
    }
end

private.RegisterTheme({
    Name = "Papercraft",
    DisplayName = "Papercraft",
    Description = private.getLocalisation("ThemePapercraftDescription"),
    SharedMedia = {
        font = {
            [CAVEAT] = FONTS .. "Caveat-Bold.ttf",
            [PATRICK] = FONTS .. "PatrickHand-Regular.ttf",
        },
    },
    Effects = true,
    Palette = {
        Body = { 0.925, 0.885, 0.805, 0.97 },
        Card = { 0.18, 0.16, 0.14, 0.045 },
        Field = { 0.975, 0.955, 0.895, 1 },
        FieldHover = { 1, 0.985, 0.94, 1 },
        FieldPressed = { 0.9, 0.86, 0.78, 1 },
        Track = { 0.48, 0.43, 0.36, 1 },
        Edge = { 0.18, 0.16, 0.14, 0.55 },
        Line = { 0.77, 0.27, 0.23, 0.9 },
        Accent = { 0.77, 0.27, 0.23, 1 },
        Accent2 = { 0.3, 0.48, 0.71, 1 },
        Highlight = { 0.3, 0.48, 0.71, 0.14 },
        Text = { 0.18, 0.16, 0.14, 1 },
        Muted = { 0.48, 0.43, 0.36, 1 },
        Danger = { 0.72, 0.2, 0.18, 1 },
        Wash = { 0.96, 0.86, 0.47, 0.12 },
        FooterFill = { 0.862, 0.815, 0.725, 1 },
        Shadow = { 0, 0, 0, 0.34 },
        PaperLight = { 0.975, 0.955, 0.895, 1 },
        Ink = { 0.18, 0.16, 0.14, 1 },
        Highlighter = { 0.96, 0.86, 0.47, 1 },
        TapeTan = { 0.8, 0.7, 0.52, 1 },
        TapeBlue = { 0.56, 0.71, 0.86, 1 },
        TapePink = { 0.9, 0.63, 0.6, 1 },
        Heart = { 0.85, 0.42, 0.47, 1 },
        Graphite = { 0.82, 0.79, 0.75, 1 },
    },
    Fonts = {
        Title = script(24, "Text"),
        DialogTitle = script(22, "Text"),
        Heading = script(19, "Accent"),
        CardTitle = script(20, "Text"),
        Footer = hand(13, "Muted"),
        Label = hand(14, "Muted"),
        Control = hand(14, "Text"),
        Muted = hand(13, "Muted"),
        Button = hand(14, "Text"),
        ButtonPrimary = hand(14, "PaperLight"),
        ButtonDanger = hand(14, "Danger"),
        Tab = hand(14, "Muted"),
        TabSelected = hand(14, "Text"),
        CardText = hand(13, "Muted"),
        MenuItem = hand(14, "Text"),
    },
    Windows = {
        Window = window({
            tape("TOPLEFT", 6, 35, "TapeTan"),
            tape("TOPRIGHT", -6, -35, "TapeBlue"),
            { File = "doodle_plane", Color = "Ink", Alpha = 0.35, Point = "BOTTOMRIGHT", X = -70, Y = 18, Size = { 28, 28 } },
            { File = "doodle_heart", Color = "Heart", Alpha = 0.6, Point = "BOTTOMRIGHT", X = -38, Y = 16, Size = { 18, 18 } },
            { File = "doodle_sun", Color = "Ink", Alpha = 0.3, Point = "BOTTOMLEFT", X = 30, Y = 52, Size = { 30, 30 } },
        }),
        Dialog = window({
            tape("TOPLEFT", 6, 35, "TapePink"),
            tape("TOPRIGHT", -6, -35, "TapeTan"),
        }),
    },
    Elements = {
        Timeline = {
            Behavior = "Papercraft",
            Backdrop = { Background = "None", Border = "None" },
            Background = { File = "paper_strip", Slice = 12, Color = "Body" },
            Edge = { File = "deckle", Slice = 12, Color = "Ink", Alpha = 0.5 },
            -- a stroke of highlighter where icons arrive, bits of paper drifting over the bar
            Mark = { File = "highlight", Color = "Highlighter", Alpha = 0.55, Length = 2.2 },
            Sparkles = CONFETTI,
            Enter = SKETCH_IN,
            Exit = TEAR_AWAY,
        },
        Tick = {
            Line = { Color = "Ink", Alpha = 0.3 },
            Text = { Font = hand(12, "Muted") },
        },
        Cooldown = {
            Font = OUTLINED(24),
        },
        SpellIcon = iconStyle(true, 15),
        BigIcon = iconStyle(false, 20),
        TextHighlight = {
            Text = {
                Font = OUTLINED(16),
                Background = { Show = false, Media = false, File = "pill", Slice = 8, Color = "Body", Alpha = 0.85, Offset = { x = 12, y = 6 } },
            },
        },
    },
})
