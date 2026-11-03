local appName, app = ...
---@class AbilityTimeline
local private = app
local ThemeApply = private.ThemeApply
local ThemedWidgets = private.ThemedWidgets

-- AceGUI's CheckBox in the theme, drawn as BetterBags Next's square switch: a track that fills with the accent as
-- it turns on, a one pixel edge and a square knob sliding to the end it is at; a ring with a dot for
-- SetType("radio")
local Type = "AtCheckBox"
local Version = 1
local variables = {
    switch = { width = 36, height = 18, knob = 12, inset = 3 },
    radio = { size = 16, dot = 8 },
    textGap = 8,
    -- the middle of the first line of a check box
    top = -12,
}

---@param frame Frame
local drawState = function(frame)
    local switch = variables.switch
    local progress, hover = frame.atProgress or 0, frame.atHover or 0
    frame.AtOff:SetColorTexture(ThemeApply.Color("Track"))
    local r, g, b = ThemeApply.Color("Accent")
    frame.AtOn:SetColorTexture(r, g, b, 0.9 * progress)
    r, g, b = ThemeApply.Color("White")
    frame.AtHover:SetColorTexture(r, g, b, 0.08 * hover)
    for _, line in ipairs(frame.AtEdges) do
        line:SetColorTexture(ThemeApply.Color("Edge"))
    end
    frame.AtKnob:SetColorTexture(ThemeApply.Color(progress >= 0.5 and "White" or "Accent2"))
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
