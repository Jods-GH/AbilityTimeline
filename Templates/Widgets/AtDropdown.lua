local appName, app = ...
---@class AbilityTimeline
local private = app
local AceGUI = LibStub("AceGUI-3.0")
local ThemeApply = private.ThemeApply
local ThemedWidgets = private.ThemedWidgets

-- AceGUI's Dropdown in the theme: a rounded field with a chevron, opening a rounded menu. The menu is a pullout of
-- its own type, its items are item types of our own as well: AceGUI's item pools are shared by every addon, an item
-- drawn in the theme would go back to them with our fonts and one taken from them could carry another addon's
local Type = "AtDropdown"
local PulloutType = "AtDropdownPullout"
local Version = 2
local variables = {
    chevron = 12,
}
-- the stock items the stock dropdown makes and the types they are swapped for
local ITEM_TYPES = {
    ["Dropdown-Item-Toggle"] = "AtDropdownItemToggle",
    ["Dropdown-Item-Execute"] = "AtDropdownItemExecute",
}

---@param self table -- an AtDropdownItem widget
local function ApplyItemSettings(self)
    self.highlight:SetColorTexture(ThemeApply.Color("Highlight"))
    self.check:SetTexture(ThemeApply.File("check"))
    self.check:SetVertexColor(ThemeApply.Color("Accent"))
    ThemeApply.FontRole(self.text, "MenuItem")
    self.text:SetAlpha(self.disabled and 0.5 or 1)
end

for stockType, itemType in pairs(ITEM_TYPES) do
    ThemedWidgets.Register(itemType, stockType, Version, function() end, ApplyItemSettings,
        { "OnAcquire", "SetDisabled" })
end

---an item of our own in place of a stock one, with its text, data and callbacks; the stock one goes back untouched
---@param item table
---@return table
local ownItem = function(item)
    local itemType = ITEM_TYPES[item.type]
    if not itemType then
        return item
    end
    local own = AceGUI:Create(itemType)
    own:SetText(item:GetText())
    for key, value in pairs(item.userdata) do
        own.userdata[key] = value
    end
    for name, func in pairs(item.events) do
        own:SetCallback(name, func)
    end
    AceGUI:Release(item)
    return own
end

---@param self AtDropdownPullout
local function ApplyPulloutSettings(self)
    self.frame.AtFill:SetVertexColor(ThemeApply.Color("Body"))
    self.frame.AtEdge:SetVertexColor(ThemeApply.Color("Edge"))
    self.slider.AtDraw()
end

---@param widget AtDropdownPullout
local function SkinPullout(widget)
    widget.frame:SetBackdrop(nil)
    ThemedWidgets.DiscardTextures(widget.frame)
    ThemeApply.CreatePanel(widget.frame)
    widget.slider:SetBackdrop(nil)
    ThemedWidgets.SkinScrollBar(widget.slider)
    local stockAddItem = widget.AddItem
    widget.AddItem = function(self, item)
        stockAddItem(self, ownItem(item))
    end
end

ThemedWidgets.Register(PulloutType, "Dropdown-Pullout", Version, SkinPullout, ApplyPulloutSettings)

---@param self AtDropdown
local function UpdateMultiText(self)
    if not self.multiselect or not self.pullout then
        return
    end
    local selected = {}
    for _, item in self.pullout:IterateItems() do
        if item.type == "AtDropdownItemToggle" and item:GetValue() then
            selected[#selected + 1] = item:GetText()
        end
    end
    self.text:SetText(table.concat(selected, ", "))
    if #selected > 1 and self.text:GetStringWidth() > self.text:GetWidth() then
        self.text:SetText(private.getLocalisation("DropdownMultiple"))
    end
end

---@param self AtDropdown
local function ApplySettings(self)
    ThemeApply.FontRole(self.label, "Label")
    ThemeApply.FontRole(self.text, "Control")
    UpdateMultiText(self)
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
    local stockSetText = widget.SetText
    widget.SetText = function(self, text)
        if self.multiselect and self.pullout then
            UpdateMultiText(self)
        else
            stockSetText(self, text)
        end
    end
    widget.button_cover:HookScript("OnSizeChanged", function()
        UpdateMultiText(widget)
    end)
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
