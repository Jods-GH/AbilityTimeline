local appName, app = ...
---@class AbilityTimeline
local private = app
local AceGUI = LibStub("AceGUI-3.0")
local ThemeApply = private.ThemeApply
local ThemedWidgets = private.ThemedWidgets

-- AceGUI's Dropdown in the theme: a rounded field with a chevron, opening a rounded menu. The menu is a pullout of
-- its own type: its items are AceGUI's shared item widgets, so they get their stock look back when released.
local Type = "AtDropdown"
local PulloutType = "AtDropdownPullout"
local Version = 1
local variables = {
    chevron = 12,
    itemHighlight = 136810, -- Interface\\QuestFrame\\UI-QuestTitleHighlight
    itemCheck = 130751,     -- Interface\\Buttons\\UI-CheckBox-Check
}

---@param item table -- a Dropdown-Item widget
local skinItem = function(item)
    item.highlight:SetColorTexture(ThemeApply.Color("Highlight"))
    item.check:SetTexture(ThemeApply.File("check"))
    item.check:SetVertexColor(ThemeApply.Color("Accent"))
    ThemeApply.FontRole(item.text, "MenuItem")
end

---@param item table
local unskinItem = function(item)
    item.highlight:SetTexture(variables.itemHighlight)
    item.check:SetTexture(variables.itemCheck)
    item.check:SetVertexColor(1, 1, 1, 1)
    item.text:SetFontObject(GameFontNormalSmall)
end

---@param self AtDropdownPullout
local function ApplyPulloutSettings(self)
    self.frame.AtFill:SetVertexColor(ThemeApply.Color("Body"))
    self.frame.AtEdge:SetVertexColor(ThemeApply.Color("Edge"))
    self.slider.AtDraw()
    for _, item in ipairs(self.items) do
        skinItem(item)
    end
end

---@param widget AtDropdownPullout
local function SkinPullout(widget)
    widget.frame:SetBackdrop(nil)
    ThemedWidgets.DiscardTextures(widget.frame)
    ThemeApply.CreatePanel(widget.frame)
    widget.slider:SetBackdrop(nil)
    ThemedWidgets.SkinScrollBar(widget.slider)
    local stockAddItem, stockClear = widget.AddItem, widget.Clear
    widget.AddItem = function(self, item)
        stockAddItem(self, item)
        skinItem(item)
    end
    widget.Clear = function(self)
        for _, item in ipairs(self.items) do
            unskinItem(item)
        end
        stockClear(self)
    end
end

ThemedWidgets.Register(PulloutType, "Dropdown-Pullout", Version, SkinPullout, ApplyPulloutSettings)

---@param self AtDropdown
local function ApplySettings(self)
    ThemeApply.FontRole(self.label, "Label")
    ThemeApply.FontRole(self.text, "Control")
    self.frame.AtDraw()
    self.frame:SetAlpha(self.disabled and 0.5 or 1)
end

---@param widget AtDropdown
local function Skin(widget)
    local frame, dropdown = widget.frame, widget.dropdown
    ThemedWidgets.DiscardTextures(dropdown)
    ThemedWidgets.DiscardTextures(widget.button)

    local field = ThemedWidgets.CreateField(frame, widget.button_cover, 0, 0, 0, 0)
    frame.AtChevron = frame:CreateTexture(nil, "ARTWORK")
    frame.AtChevron:SetTexture(ThemeApply.File("chevron"))
    frame.AtChevron:SetSize(variables.chevron, variables.chevron)
    frame.AtChevron:SetPoint("RIGHT", widget.button_cover, "RIGHT", -8, 0)
    widget.text:ClearAllPoints()
    widget.text:SetPoint("LEFT", widget.button_cover, "LEFT", 10, 0)
    widget.text:SetPoint("RIGHT", frame.AtChevron, "LEFT", -6, 0)
    widget.text:SetJustifyH("LEFT")
    frame.AtDraw = function()
        ThemedWidgets.DrawField(field)
        frame.AtChevron:SetVertexColor(ThemeApply.MixColor("Muted", "Text", field.hover or 0))
    end
    for _, hoverFrame in ipairs({ widget.button, widget.button_cover }) do
        ThemedWidgets.HookHover(hoverFrame, field, frame.AtDraw)
    end

    -- swaps the stock pullout for a themed one with the same callbacks
    local stockAcquire = widget.OnAcquire
    widget.OnAcquire = function(self)
        stockAcquire(self)
        local stockPullout = self.pullout
        local pullout = AceGUI:Create(PulloutType)
        pullout.userdata.obj = self
        pullout:SetCallback("OnClose", stockPullout.events.OnClose)
        pullout:SetCallback("OnOpen", stockPullout.events.OnOpen)
        pullout.frame:SetFrameLevel(self.frame:GetFrameLevel() + 1)
        AceGUI:Release(stockPullout)
        self.pullout = pullout
    end
end

ThemedWidgets.Register(Type, "Dropdown", Version, Skin, ApplySettings, { "OnAcquire", "SetDisabled", "SetLabel" })
