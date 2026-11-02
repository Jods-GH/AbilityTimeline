local appName, app = ...
---@class AbilityTimeline
local private = app
local AceGUI = LibStub("AceGUI-3.0")
local ThemeApply = private.ThemeApply

-- the themed widgets are the stock AceGUI widgets, built by their own constructor so they keep every method
-- and callback, registered under their own type (and pool) and drawn in the theme instead of Blizzard's art
private.ThemedWidgets = {}
local ThemedWidgets = private.ThemedWidgets

local keepHidden = function(region)
    region:Hide()
end

---hides the stock art of a frame for good, the stock code shows it again as its state changes
---@param frame Frame
---@param keep Region|nil
ThemedWidgets.DiscardTextures = function(frame, keep)
    for _, region in ipairs({ frame:GetRegions() }) do
        if region ~= keep and region:IsObjectType("Texture") and not region.atDiscarded then
            region.atDiscarded = true
            -- a button shows its highlight texture by itself, so it is made clear as well
            region:SetAlpha(0)
            region:Hide()
            hooksecurefunc(region, "Show", keepHidden)
            hooksecurefunc(region, "SetShown", keepHidden)
        end
    end
end

---registers Type as the stock widget stockType drawn in the theme
---@param Type string
---@param stockType string
---@param version number
---@param skin fun(widget: table) -- builds the art once
---@param applySettings fun(widget: table) -- draws the widget in the current theme
---@param refreshAfter string[]|nil -- stock methods after which the widget is drawn again
ThemedWidgets.Register = function(Type, stockType, version, skin, applySettings, refreshAfter)
    AceGUI:RegisterWidgetType(Type, function()
        -- ElvUI skins AceGUI widgets by their type as they register, which is still the stock type here, so its
        -- Ace3 skin is paused while the stock widget is built
        local elvSkins = ElvUI and ElvUI[1] and ElvUI[1].private and ElvUI[1].private.skins
        local elvSkinsAce3 = elvSkins and elvSkins.ace3Enable
        if elvSkins then
            elvSkins.ace3Enable = false
        end
        local widget = AceGUI.WidgetRegistry[stockType]()
        if elvSkins then
            elvSkins.ace3Enable = elvSkinsAce3
        end
        widget.type = Type
        widget.ApplySettings = applySettings
        skin(widget)
        for _, name in ipairs(refreshAfter or {}) do
            local stockMethod = widget[name]
            widget[name] = function(self, ...)
                stockMethod(self, ...)
                self:ApplySettings()
            end
        end
        widget:ApplySettings()
        private.RegisterThemed(widget)
        return widget
    end, version)
end

---tweens a hover state from 0 to 1 while the pointer is over frame, draw(progress) draws it
---@param frame Frame
---@param state table -- keeps the hover progress (state.hover)
---@param draw fun(progress: number)
ThemedWidgets.HookHover = function(frame, state, draw)
    frame:HookScript("OnEnter", function()
        private.TweenMotion(state, "Hover", state.hover or 0, 1, function(progress)
            state.hover = progress
            draw(progress)
        end)
    end)
    frame:HookScript("OnLeave", function()
        private.TweenMotion(state, "Hover", state.hover or 1, 0, function(progress)
            state.hover = progress
            draw(progress)
        end)
    end)
end

---creates a rounded field (fill and edge) around anchor, extended by the insets
---@param parent Frame
---@param anchor Region
---@return table field -- field.Fill, field.Edge
ThemedWidgets.CreateField = function(parent, anchor, left, top, right, bottom)
    local field = {}
    field.Fill = ThemeApply.CreateSliced(parent, "panel", "BACKGROUND", 1)
    field.Edge = ThemeApply.CreateSliced(parent, "panel_edge", "BORDER", 1)
    for _, texture in ipairs({ field.Fill, field.Edge }) do
        texture:SetPoint("TOPLEFT", anchor, "TOPLEFT", -(left or 0), top or 0)
        texture:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", right or 0, -(bottom or 0))
    end
    return field
end

---draws a field idle (0) to hovered (1), focused fields get the accent edge
---@param field table
ThemedWidgets.DrawField = function(field)
    field.Fill:SetVertexColor(ThemeApply.MixColor("Field", "FieldHover", field.hover or 0))
    local focus = math.max(field.focus or 0, (field.hover or 0) * 0.3)
    field.Edge:SetVertexColor(ThemeApply.MixColor("Edge", "Accent", focus, nil, 0.8))
end

local BUTTON_FONTS = {
    Plain = "Button",
    Primary = "ButtonPrimary",
    Danger = "ButtonDanger",
}

---draws a UIPanelButtonTemplate button in its style (button.atStyle: Plain, Primary or Danger)
---@param button Button
ThemedWidgets.DrawButton = function(button)
    local hover = button.atHover or 0
    if button.atStyle == "Primary" then
        button.AtFill:SetVertexColor(ThemeApply.Color("Accent", 0.85 + 0.15 * hover))
        button.AtEdge:SetVertexColor(ThemeApply.Color("Accent"))
    else
        button.AtFill:SetVertexColor(ThemeApply.MixColor("Field", "FieldHover", hover))
        button.AtEdge:SetVertexColor(ThemeApply.MixColor("Edge", button.atStyle == "Danger" and "Danger" or "Accent",
            hover, nil, 0.6))
    end
    local font = ThemeApply.FontObject(BUTTON_FONTS[button.atStyle or "Plain"])
    button:SetNormalFontObject(font)
    button:SetHighlightFontObject(font)
    button:SetDisabledFontObject(ThemeApply.FontObject("Muted"))
end

---hides the art of a UIPanelButtonTemplate button and gives it a rounded fill and edge
---@param button Button
ThemedWidgets.SkinButton = function(button)
    ThemedWidgets.DiscardTextures(button)
    ThemeApply.CreatePanel(button)
    local state = {}
    ThemedWidgets.HookHover(button, state, function(progress)
        button.atHover = progress
        ThemedWidgets.DrawButton(button)
    end)
    ThemedWidgets.DrawButton(button)
end

---draws a scroll bar slider as a thin rounded bar following its thumb, without its arrow buttons or track
---@param scrollBar Slider
ThemedWidgets.SkinScrollBar = function(scrollBar)
    for _, child in ipairs({ scrollBar:GetChildren() }) do
        child:SetAlpha(0)
        child:EnableMouse(false)
    end
    -- the slider's thumb stays its full width to be easy to grab, the bar drawn is a thin one in its middle
    scrollBar:SetThumbTexture("Interface\\Buttons\\WHITE8X8")
    local thumb = scrollBar:GetThumbTexture()
    ThemedWidgets.DiscardTextures(scrollBar, thumb)
    thumb:SetSize(scrollBar:GetWidth(), 40)
    thumb:SetVertexColor(0, 0, 0, 0)
    local bar = ThemeApply.CreateSliced(scrollBar, "thumb", "OVERLAY", nil, 2)
    bar:SetWidth(4)
    bar:SetPoint("TOP", thumb, "TOP")
    bar:SetPoint("BOTTOM", thumb, "BOTTOM")
    local state = {}
    local draw = function(progress)
        bar:SetVertexColor(ThemeApply.MixColor("Accent2", "Accent", progress, 0.35, 0.8))
    end
    ThemedWidgets.HookHover(scrollBar, state, draw)
    scrollBar.AtDraw = function()
        draw(state.hover or 0)
    end
    scrollBar.AtDraw()
end
