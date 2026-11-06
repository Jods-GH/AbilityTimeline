local appName, app = ...
---@class AbilityTimeline
local private = app
local AceGUI = LibStub("AceGUI-3.0")
local ThemeApply = private.ThemeApply

-- a theme in the theme selection: its name, description, palette and whether it animates
local Type = "AtThemeCard"
local Version = 2
local variables = {
    gap = 3,
    -- the height of a line of text to its font size
    lineHeight = 1.25,
    descriptionLines = 2,
    padding = 15,
    swatch = 14,
    swatchGap = 4,
    swatchColors = { "Body", "Field", "Accent2", "Accent", "Text" },
}

---@param self AtThemeCard
local updateSwatches = function(self)
    if not self.theme then return end
    local key = private.IsThemeAvailable(self.theme.Name) and self.theme.Name or private.DEFAULT_THEME
    private.DrawInTheme(key, function()
        for i, swatch in ipairs(self.frame.Swatches) do
            swatch:SetVertexColor(ThemeApply.Color(variables.swatchColors[i], 1))
        end
    end)
end

---@param frame Button
local draw = function(frame)
    local hover, selected = frame.atHover or 0, frame.atSelected or 0
    frame.AtFill:SetVertexColor(ThemeApply.MixColor("Field", "FieldHover", hover))
    frame.AtEdge:SetVertexColor(ThemeApply.MixColor("Edge", "Accent", math.max(selected, hover * 0.4), nil, 1))
    frame.Glow:SetAlpha(selected * 0.35)
end

---a card is as high as its title and two lines of description in the fonts of the theme, the list it is in is laid
---out again once all its cards changed their height
---@param self AtThemeCard
local updateHeight = function(self)
    local frame = self.frame
    local _, titleSize = frame.Title:GetFont()
    local _, textSize = frame.Description:GetFont()
    local height = math.ceil(variables.padding * 2 + variables.gap * 2 + 4 +
        (titleSize + textSize * variables.descriptionLines) * variables.lineHeight)
    if height == self.atHeight then return end
    self.atHeight = height
    self:SetHeight(height)
    local list = self.parent
    if list and not list.atLayoutQueued then
        list.atLayoutQueued = true
        C_Timer.After(0, function()
            list.atLayoutQueued = nil
            list:DoLayout()
        end)
    end
end

---@param self AtThemeCard
local function ApplySettings(self)
    local frame = self.frame
    ThemeApply.FontRole(frame.Title, "CardTitle")
    ThemeApply.FontRole(frame.Description, "CardText")
    ThemeApply.FontRole(frame.Badge, "CardText")
    frame.Glow:SetVertexColor(ThemeApply.Color("Accent"))
    -- a ring around every swatch, the theme's own colors can be the color of the card
    for _, ring in ipairs(frame.SwatchRings) do
        ring:SetVertexColor(ThemeApply.Color("Muted", 0.8))
    end
    draw(frame)
    frame:SetAlpha(self.disabled and 0.5 or 1)
    updateSwatches(self)
    updateHeight(self)
end

---@param self AtThemeCard
local function OnAcquire(self)
    self.atHeight = nil
    self:SetFullWidth(true)
    self:SetDisabled(false)
    self.frame.atSelected = 0
    ApplySettings(self)
end

---@param self AtThemeCard
local function OnRelease(self)
    self.theme = nil
    self.frame:ClearAllPoints()
    self.frame:Hide()
end

---@param self AtThemeCard
---@param theme table
local function SetTheme(self, theme)
    self.theme = theme
    local frame = self.frame
    frame.Title:SetText(theme.DisplayName or theme.Name)
    frame.Description:SetText(private.IsThemeAvailable(theme.Name) and theme.Description or
        private.getLocalisation("ThemeUnavailable"))
    frame.Badge:SetText(private.getLocalisation(theme.Effects and "ThemeAnimated" or "ThemeStatic"))
    updateSwatches(self)
end

---@param self AtThemeCard
---@param selected boolean
local function SetSelected(self, selected)
    local frame = self.frame
    private.TweenMotion(frame.Glow, "Select", frame.atSelected or 0, selected and 1 or 0, function(progress)
        frame.atSelected = progress
        draw(frame)
    end)
end

---@param self AtThemeCard
---@param disabled boolean
local function SetDisabled(self, disabled)
    self.disabled = disabled
    self.frame:EnableMouse(not disabled)
    self.frame:SetAlpha(disabled and 0.5 or 1)
end

local function Constructor()
    local count = AceGUI:GetNextWidgetNum(Type)
    local frame = CreateFrame("Button", Type .. count, UIParent)
    frame:Hide()
    -- the art is inset so cards stacked by the List layout get a gap between them
    ThemeApply.CreatePanel(frame)
    for _, texture in ipairs({ frame.AtFill, frame.AtEdge }) do
        texture:ClearAllPoints()
        texture:SetPoint("TOPLEFT", 0, -variables.gap)
        texture:SetPoint("BOTTOMRIGHT", 0, variables.gap)
    end
    frame.Glow = ThemeApply.CreateSliced(frame, "shadow", "BACKGROUND", 0, 24)
    frame.Glow:SetPoint("TOPLEFT", -14, 14 - variables.gap)
    frame.Glow:SetPoint("BOTTOMRIGHT", 14, -14 + variables.gap)
    frame.Glow:SetBlendMode("ADD")

    frame.Swatches = {}
    frame.SwatchRings = {}
    for i = #variables.swatchColors, 1, -1 do
        local swatch = frame:CreateTexture(nil, "ARTWORK")
        swatch:SetTexture(ThemeApply.File("circle"))
        swatch:SetSize(variables.swatch, variables.swatch)
        local offset = -variables.padding - (#variables.swatchColors - i) * (variables.swatch + variables.swatchGap)
        swatch:SetPoint("TOPRIGHT", frame, "TOPRIGHT", offset, -variables.padding)
        frame.Swatches[i] = swatch
        local ring = frame:CreateTexture(nil, "ARTWORK", nil, 1)
        ring:SetTexture(ThemeApply.File("ring"))
        ring:SetSize(variables.swatch + 2, variables.swatch + 2)
        ring:SetPoint("CENTER", swatch, "CENTER")
        table.insert(frame.SwatchRings, ring)
    end

    frame.Title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.Title:SetPoint("TOPLEFT", variables.padding, -variables.padding)
    frame.Title:SetJustifyH("LEFT")
    frame.Badge = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.Badge:SetPoint("BOTTOMRIGHT", -variables.padding, variables.padding)
    frame.Description = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.Description:SetPoint("TOPLEFT", frame.Title, "BOTTOMLEFT", 0, -4)
    frame.Description:SetPoint("RIGHT", frame.Badge, "LEFT", -8, 0)
    frame.Description:SetJustifyH("LEFT")
    frame.Description:SetWordWrap(true)
    frame.Description:SetMaxLines(variables.descriptionLines)

    ---@class AtThemeCard : AceGUIWidget
    local widget = {
        OnAcquire = OnAcquire,
        OnRelease = OnRelease,
        ApplySettings = ApplySettings,
        SetTheme = SetTheme,
        SetSelected = SetSelected,
        SetDisabled = SetDisabled,
        type = Type,
        count = count,
        frame = frame,
    }
    frame:SetScript("OnClick", function()
        widget:Fire("OnClick")
    end)
    frame:SetScript("OnEnter", function()
        widget:Fire("OnEnter")
        private.TweenMotion(frame, "Hover", frame.atHover or 0, 1, function(progress)
            frame.atHover = progress
            draw(frame)
        end)
    end)
    frame:SetScript("OnLeave", function()
        private.TweenMotion(frame, "Hover", frame.atHover or 1, 0, function(progress)
            frame.atHover = progress
            draw(frame)
        end)
    end)
    private.RegisterThemed(widget)

    return AceGUI:RegisterAsWidget(widget)
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)
