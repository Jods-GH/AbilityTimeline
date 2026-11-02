local appName, app = ...
---@class AbilityTimeline
local private = app
local ThemeApply = private.ThemeApply
local ThemedWidgets = private.ThemedWidgets

-- AceGUI's TabGroup, InlineGroup and ScrollFrame in the theme: rounded cards, tabs underlined by the accent
-- and thin scroll bars
local variables = {
    tabMarker = 2,
    tabMarkerInset = 10,
}

---draws a tab's fill and marker from its selected and hover progress
---@param tab Button
local drawTabState = function(tab)
    local selected, hover = tab.atSelectedProgress or 0, tab.atHover or 0
    -- a texture's alpha and the alpha of its vertex color are one value, so both go into the color
    local r, g, b, a = ThemeApply.Color("Highlight")
    tab.AtFill:SetVertexColor(r, g, b, a * math.max(selected * 0.6, hover))
    r, g, b = ThemeApply.Color("Accent")
    tab.AtMarker:SetVertexColor(r, g, b, selected)
end

---@param tab Button
---@param selected boolean
local drawTab = function(tab, selected)
    tab:SetNormalFontObject(ThemeApply.FontObject("Tab"))
    tab:SetHighlightFontObject(ThemeApply.FontObject("TabSelected"))
    tab:SetDisabledFontObject(ThemeApply.FontObject("TabSelected"))
    local to = selected and 1 or 0
    if tab.atSelected ~= to then
        private.TweenMotion(tab.AtMarker, "Select", tab.atSelected or to, to, function(progress)
            tab.atSelectedProgress = progress
            drawTabState(tab)
        end)
        tab.atSelected = to
    else
        drawTabState(tab)
    end
end

---@param self AtTabGroup
local function ApplyTabSettings(self)
    self.border.AtFill:SetVertexColor(ThemeApply.Color("Card"))
    self.border.AtEdge:SetVertexColor(ThemeApply.Color("Edge"))
    ThemeApply.FontRole(self.titletext, "Heading")
    for _, tab in ipairs(self.tabs) do
        drawTab(tab, tab.selected)
    end
end

---@param widget AtTabGroup
local function SkinTabGroup(widget)
    widget.border:SetBackdrop(nil)
    ThemedWidgets.DiscardTextures(widget.border)
    ThemeApply.CreatePanel(widget.border)
    local stockCreateTab = widget.CreateTab
    widget.CreateTab = function(self, id)
        local tab = stockCreateTab(self, id)
        -- the stock tab art is shown and hidden as tabs are selected
        ThemedWidgets.DiscardTextures(tab)
        tab.AtFill = ThemeApply.CreateSliced(tab, "panel", "BACKGROUND", 1)
        tab.AtFill:SetPoint("TOPLEFT", 4, -2)
        tab.AtFill:SetPoint("BOTTOMRIGHT", -4, 2)
        ThemedWidgets.HookHover(tab, tab, function(progress)
            tab.atHover = progress
            drawTabState(tab)
        end)
        tab.AtMarker = tab:CreateTexture(nil, "ARTWORK")
        tab.AtMarker:SetTexture("Interface\\Buttons\\WHITE8X8")
        tab.AtMarker:SetHeight(variables.tabMarker)
        tab.AtMarker:SetPoint("BOTTOMLEFT", variables.tabMarkerInset, 0)
        tab.AtMarker:SetPoint("BOTTOMRIGHT", -variables.tabMarkerInset, 0)
        local stockSetSelected = tab.SetSelected
        tab.SetSelected = function(frame, selected)
            stockSetSelected(frame, selected)
            frame.selected = selected
            drawTab(frame, selected)
        end
        drawTab(tab, false)
        return tab
    end
end

ThemedWidgets.Register("AtTabGroup", "TabGroup", 1, SkinTabGroup, ApplyTabSettings, { "OnAcquire" })

---@param self AtInlineGroup
local function ApplyInlineSettings(self)
    local border = self.content:GetParent()
    border.AtFill:SetVertexColor(ThemeApply.Color("Card"))
    border.AtEdge:SetVertexColor(ThemeApply.Color("Edge"))
    ThemeApply.FontRole(self.titletext, "Heading")
end

---@param widget AtInlineGroup
local function SkinInlineGroup(widget)
    local border = widget.content:GetParent()
    border:SetBackdrop(nil)
    ThemedWidgets.DiscardTextures(border)
    ThemeApply.CreatePanel(border)
end

ThemedWidgets.Register("AtInlineGroup", "InlineGroup", 1, SkinInlineGroup, ApplyInlineSettings, { "OnAcquire" })

---@param self AtScrollFrame
local function ApplyScrollSettings(self)
    self.scrollbar.AtDraw()
end

---@param widget AtScrollFrame
local function SkinScrollFrame(widget)
    ThemedWidgets.SkinScrollBar(widget.scrollbar)
end

ThemedWidgets.Register("AtScrollFrame", "ScrollFrame", 1, SkinScrollFrame, ApplyScrollSettings, { "OnAcquire" })
