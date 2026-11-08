local appName, app = ...
---@class AbilityTimeline
local private = app
local ThemeApply = private.ThemeApply
local ThemedWidgets = private.ThemedWidgets

-- AceGUI's Slider in the theme: a thin track filled up to a round thumb, and a rounded value box
local Type = "AtSlider"
local Version = 1
local variables = {
    track = 4,
    thumb = 14,
}

---@param self AtSlider
local function ApplySettings(self)
    local style = ThemeApply.ControlStyle("Slider")
    local thumb = self.slider:GetThumbTexture()
    local thumbArt = style and style.Thumb or "circle"
    ThemeApply.Texture(thumb, type(thumbArt) == "table" and thumbArt or { File = thumbArt })
    thumb:SetSize(style and style.Size or variables.thumb, style and style.Size or variables.thumb)
    local trackArt = style and style.Track
    ThemeApply.Texture(self.slider.AtTrack, type(trackArt) == "table" and trackArt or
        (trackArt and { File = trackArt } or { Texture = "Interface\\Buttons\\WHITE8X8" }))
    local caps = style and style.Caps
    self.slider.AtTrack:ClearAllPoints()
    self.slider.AtTrack:SetPoint("LEFT", self.slider, "LEFT", caps and caps.Width or 0, 0)
    self.slider.AtTrack:SetPoint("RIGHT", self.slider, "RIGHT", caps and -caps.Width or 0, 0)
    if caps and not self.slider.AtCaps then
        self.slider.AtCaps = { self.slider:CreateTexture(nil, "BACKGROUND"), self.slider:CreateTexture(nil, "BACKGROUND") }
        self.slider.AtCaps[1]:SetPoint("RIGHT", self.slider.AtTrack, "LEFT")
        self.slider.AtCaps[2]:SetPoint("LEFT", self.slider.AtTrack, "RIGHT")
    end
    for i, texture in ipairs(self.slider.AtCaps or {}) do
        texture:SetShown(caps and ThemeApply.Texture(texture, i == 1 and caps.Left or caps.Right) or false)
        if caps then texture:SetSize(caps.Width, style.Height) end
    end
    self.slider.AtTrack:SetHeight(style and style.Height or variables.track)
    self.slider.AtFillBar:SetShown(not style or style.Fill ~= false)
    ThemeApply.FontRole(self.label, "Label")
    ThemeApply.FontRole(self.lowtext, "Muted")
    ThemeApply.FontRole(self.hightext, "Muted")
    self.editbox:SetFontObject(ThemeApply.FontObject("Control"))
    self.editbox:SetTextColor(ThemeApply.FontObject("Control"):GetTextColor())
    self.slider.AtTrack:SetVertexColor(ThemeApply.Color(style and "White" or "Track"))
    self.slider.AtFillBar:SetVertexColor(ThemeApply.Color("Accent"))
    self.slider.AtDraw()
    ThemedWidgets.DrawField(self.editbox.AtField)
    self.frame:SetAlpha(self.disabled and 0.5 or 1)
end

---@param widget AtSlider
local function Skin(widget)
    local slider, editbox = widget.slider, widget.editbox
    slider:SetBackdrop(nil)
    slider:SetThumbTexture(ThemeApply.File("circle"))
    local thumb = slider:GetThumbTexture()
    ThemedWidgets.DiscardTextures(slider, thumb)
    thumb:SetSize(variables.thumb, variables.thumb)

    slider.AtTrack = slider:CreateTexture(nil, "BACKGROUND")
    slider.AtTrack:SetTexture("Interface\\Buttons\\WHITE8X8")
    slider.AtTrack:SetHeight(variables.track)
    slider.AtTrack:SetPoint("LEFT")
    slider.AtTrack:SetPoint("RIGHT")
    slider.AtFillBar = slider:CreateTexture(nil, "BACKGROUND", nil, 1)
    slider.AtFillBar:SetTexture("Interface\\Buttons\\WHITE8X8")
    slider.AtFillBar:SetHeight(variables.track)
    slider.AtFillBar:SetPoint("LEFT")
    slider.AtFillBar:SetPoint("RIGHT", thumb, "CENTER")

    local state = {}
    local draw = function(progress)
        local style = ThemeApply.ControlStyle("Slider")
        if style then
            thumb:SetVertexColor(ThemeApply.Color(style.Color))
        else
            thumb:SetVertexColor(ThemeApply.MixColor("Text", "Accent", progress))
        end
    end
    ThemedWidgets.HookHover(slider, state, draw)
    slider.AtDraw = function()
        draw(state.hover or 0)
    end

    editbox:SetBackdrop(nil)
    ThemedWidgets.DiscardTextures(editbox)
    editbox:SetHeight(18)
    editbox.AtField = ThemedWidgets.CreateField(editbox, editbox, 0, 0, 0, 0)
    ThemedWidgets.HookHover(editbox, editbox.AtField, function()
        ThemedWidgets.DrawField(editbox.AtField)
    end)
    editbox:HookScript("OnEditFocusGained", function()
        editbox.AtField.focus = 1
        ThemedWidgets.DrawField(editbox.AtField)
    end)
    editbox:HookScript("OnEditFocusLost", function()
        editbox.AtField.focus = 0
        ThemedWidgets.DrawField(editbox.AtField)
    end)
end

ThemedWidgets.Register(Type, "Slider", Version, Skin, ApplySettings, { "OnAcquire", "SetDisabled" })
