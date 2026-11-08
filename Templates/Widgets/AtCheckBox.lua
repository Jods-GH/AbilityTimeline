local appName, app = ...
---@class AbilityTimeline
local private = app
local ThemeApply = private.ThemeApply
local ThemedWidgets = private.ThemedWidgets

-- AceGUI's CheckBox in the theme, drawn as BetterBags Next's square switch: a track that fills with the accent as
-- it turns on, a one pixel edge and a square knob sliding to the end it is at; a ring with a dot for
-- SetType("radio")
local Type = "AtCheckBox"
local Version = 2
local variables = {
    switch = { width = 36, height = 18, knob = 12, inset = 3 },
    radio = { size = 16, dot = 8 },
    textGap = 8,
    -- the middle of the first line of a check box
    top = -12,
}

---@param frame Frame
local drawState = function(frame)
    local style = ThemeApply.ControlStyle("CheckBox")
    if style and not frame.atRadio then
        ThemeApply.Texture(frame.AtOff, type(style.Box) == "table" and style.Box or { File = style.Box })
        frame.AtOff:SetVertexColor(1, 1, 1, 1)
        ThemeApply.Texture(frame.AtOn, type(style.Check) == "table" and style.Check or { File = style.Check })
        frame.AtOn:SetVertexColor(1, 1, 1, (frame.atProgress or 0) >= 0.5 and 1 or 0)
        ThemeApply.Solid(frame.AtHover, 1, 1, 1, 0.08 * (frame.atHover or 0))
        frame.AtKnob:Hide()
        for _, line in ipairs(frame.AtEdges) do line:Hide() end
        return
    end
    frame.AtKnob:Show()
    for _, line in ipairs(frame.AtEdges) do line:Show() end
    local switch = variables.switch
    local progress, hover = frame.atProgress or 0, frame.atHover or 0
    ThemeApply.Solid(frame.AtOff, ThemeApply.Color("Track"))
    local r, g, b = ThemeApply.Color("Accent")
    ThemeApply.Solid(frame.AtOn, r, g, b, 0.9 * progress)
    r, g, b = ThemeApply.Color("White")
    ThemeApply.Solid(frame.AtHover, r, g, b, 0.08 * hover)
    for _, line in ipairs(frame.AtEdges) do
        ThemeApply.Solid(line, ThemeApply.Color("Edge"))
    end
    ThemeApply.Solid(frame.AtKnob, ThemeApply.Color(progress >= 0.5 and "White" or "Accent2"))
    frame.AtKnob:SetPoint("LEFT", frame.AtSwitch, "LEFT",
        switch.inset + progress * (switch.width - switch.knob - switch.inset * 2), 0)
    frame.AtRing:SetVertexColor(ThemeApply.MixColor("Muted", "Accent", math.max(progress, hover * 0.5)))
    r, g, b = ThemeApply.Color("Accent")
    frame.AtDot:SetVertexColor(r, g, b, progress)
end

---@param self AtCheckBox
local function ApplySettings(self)
    local frame = self.frame
    local isRadio = self.atRadio
    frame.atRadio = isRadio
    local style = ThemeApply.ControlStyle("CheckBox")
    frame.AtSwitch:SetSize(style and not isRadio and style.Size or variables.switch.width,
        style and not isRadio and style.Size or variables.switch.height)
    frame.AtSwitch:SetShown(not isRadio)
    frame.AtRing:SetShown(isRadio)
    frame.AtDot:SetShown(isRadio)
    -- the stock code puts the label right of the stock check box whenever it is clicked, so that box (hidden)
    -- covers the switch and the gap before the label
    local target = isRadio and frame.AtRing or frame.AtSwitch
    self.checkbg:ClearAllPoints()
    self.checkbg:SetPoint("TOPLEFT", target, "TOPLEFT")
    self.checkbg:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", variables.textGap, 0)
    self.text:SetPoint("LEFT", self.checkbg, "RIGHT")
    ThemeApply.FontRole(self.text, "Control")
    if self.desc then
        ThemeApply.FontRole(self.desc, "Muted")
    end
    frame:SetAlpha(self.disabled and 0.5 or 1)

    local value = self.checked and 1 or 0
    if frame.atValue ~= value then
        -- only a click slides the switch, a value set by code (a pooled check box shown again) jumps to it
        local from = self.atAnimate and frame.atValue or value
        private.TweenMotion(frame, "Toggle", from, value, function(progress)
            frame.atProgress = progress
            drawState(frame)
        end)
        frame.atValue = value
    else
        drawState(frame)
    end
    self.atAnimate = nil
end

---@param widget AtCheckBox
local function Skin(widget)
    local frame = widget.frame
    local switch, radio = variables.switch, variables.radio
    ThemedWidgets.DiscardTextures(frame)

    local box = CreateFrame("Frame", nil, frame)
    box:SetSize(switch.width, switch.height)
    box:SetPoint("LEFT", frame, "TOPLEFT", 0, variables.top)
    frame.AtSwitch = box
    frame.AtOff = box:CreateTexture(nil, "BACKGROUND", nil, 0)
    frame.AtOff:SetAllPoints(box)
    frame.AtOn = box:CreateTexture(nil, "BACKGROUND", nil, 1)
    frame.AtOn:SetAllPoints(box)
    frame.AtHover = box:CreateTexture(nil, "BACKGROUND", nil, 2)
    frame.AtHover:SetAllPoints(box)
    frame.AtEdges = {}
    -- the one pixel edge: { from, to, is vertical }
    for _, side in ipairs({ { "TOPLEFT", "TOPRIGHT", false }, { "BOTTOMLEFT", "BOTTOMRIGHT", false },
        { "TOPLEFT", "BOTTOMLEFT", true }, { "TOPRIGHT", "BOTTOMRIGHT", true } }) do
        local line = box:CreateTexture(nil, "BORDER")
        line:SetPoint(side[1])
        line:SetPoint(side[2])
        if side[3] then
            line:SetWidth(1)
        else
            line:SetHeight(1)
        end
        table.insert(frame.AtEdges, line)
    end
    frame.AtKnob = box:CreateTexture(nil, "ARTWORK")
    frame.AtKnob:SetSize(switch.knob, switch.knob)

    frame.AtRing = frame:CreateTexture(nil, "ARTWORK", nil, 1)
    frame.AtRing:SetTexture(ThemeApply.File("ring"))
    frame.AtRing:SetSize(radio.size, radio.size)
    frame.AtRing:SetPoint("LEFT", frame, "TOPLEFT", 0, variables.top)
    frame.AtDot = frame:CreateTexture(nil, "ARTWORK", nil, 2)
    frame.AtDot:SetTexture(ThemeApply.File("circle"))
    frame.AtDot:SetSize(radio.dot, radio.dot)
    frame.AtDot:SetPoint("CENTER", frame.AtRing)

    ThemedWidgets.HookHover(frame, {}, function(progress)
        frame.atHover = progress
        drawState(frame)
    end)

    -- Stock setters desaturate the discarded check texture through a legacy global.
    -- Our switch draws its own state, so only retain the value and button interaction.
    widget.SetValue = function(self, value)
        self.checked = value
    end
    widget.SetDisabled = function(self, disabled)
        self.disabled = disabled
        if disabled then
            self.frame:Disable()
        else
            self.frame:Enable()
        end
    end

    local stockToggleChecked = widget.ToggleChecked
    widget.ToggleChecked = function(self)
        self.atAnimate = true
        stockToggleChecked(self)
    end

    local stockSetType = widget.SetType
    widget.SetType = function(self, checkType)
        self.atRadio = checkType == "radio"
        stockSetType(self, checkType)
    end
end

ThemedWidgets.Register(Type, "CheckBox", Version, Skin, ApplySettings,
    { "OnAcquire", "SetType", "SetValue", "SetDisabled", "SetDescription", "ToggleChecked" })
