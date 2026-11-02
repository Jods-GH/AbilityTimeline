local appName, app = ...
---@class AbilityTimeline
local private = app
local ThemeApply = private.ThemeApply
local ThemedWidgets = private.ThemedWidgets

-- AceGUI's ColorPicker in the theme: a round swatch in a ring
local Type = "AtColorPicker"
local Version = 1
local variables = {
    swatch = 16,
    ring = 22,
    textGap = 8,
}

---@param self AtColorPicker
local function ApplySettings(self)
    ThemeApply.FontRole(self.text, "Control")
    self.frame.AtDraw()
    self.frame:SetAlpha(self.disabled and 0.5 or 1)
end

---@param widget AtColorPicker
local function Skin(widget)
    local frame, swatch = widget.frame, widget.colorSwatch
    swatch:SetTexture(ThemeApply.File("circle"))
    swatch:SetSize(variables.swatch, variables.swatch)
    swatch:ClearAllPoints()
    swatch:SetPoint("LEFT", frame, "LEFT", (variables.ring - variables.swatch) / 2, 0)
    ThemedWidgets.DiscardTextures(frame, swatch)
    swatch:SetTexCoord(0, 1, 0, 1)
    widget.text:SetPoint("LEFT", swatch, "RIGHT", variables.textGap, 0)

    frame.AtRing = frame:CreateTexture(nil, "ARTWORK")
    frame.AtRing:SetTexture(ThemeApply.File("ring"))
    frame.AtRing:SetSize(variables.ring, variables.ring)
    frame.AtRing:SetPoint("CENTER", swatch)
    local state = {}
    local draw = function(progress)
        frame.AtRing:SetVertexColor(ThemeApply.MixColor("Muted", "Accent", progress))
    end
    ThemedWidgets.HookHover(frame, state, draw)
    frame.AtDraw = function()
        draw(state.hover or 0)
    end
end

ThemedWidgets.Register(Type, "ColorPicker", Version, Skin, ApplySettings, { "OnAcquire", "SetDisabled" })
