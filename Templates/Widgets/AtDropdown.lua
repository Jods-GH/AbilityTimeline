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
local Version = 4
local variables = {
    chevron = 12,
    searchThreshold = 12,
    searchHeight = 32,
    searchMaxHeight = 320,
}
-- the stock items the stock dropdown makes and the types they are swapped for
local ITEM_TYPES = {
    ["Dropdown-Item-Toggle"] = "AtDropdownItemToggle",
    ["Dropdown-Item-Execute"] = "AtDropdownItemExecute",
}

local function UpdateItemPreview(self)
    if not self.previewButton then
        return
    end
    local enabled = self.userdata.atPreview ~= nil
    self.previewButton:SetShown(enabled)
    self.previewButton:SetEnabled(not self.disabled)
    self.text:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", enabled and -28 or -8, 0)
end

---@param self table -- an AtDropdownItem widget
local function ApplyItemSettings(self)
    self.highlight:SetColorTexture(ThemeApply.Color("Highlight"))
    self.check:SetTexture(ThemeApply.File("check"))
    self.check:SetVertexColor(ThemeApply.Color("Accent"))
    ThemeApply.FontRole(self.text, "MenuItem")
    self.text:SetAlpha(self.disabled and 0.5 or 1)
    UpdateItemPreview(self)
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
    self.search:SetFontObject(ThemeApply.FontObject("Control"))
    self.search:SetTextColor(ThemeApply.FontObject("Control"):GetTextColor())
    ThemeApply.FontRole(self.searchHint, "Muted")
    ThemeApply.FontRole(self.noResults, "Muted")
    ThemedWidgets.DrawField(self.search.AtField)
end

local function FilterItems(self)
    if not self.searchEnabled then
        return
    end
    local query = self.search:GetText():lower()
    self.searchHint:SetShown(query == "")
    local visible = 0
    for _, item in self:IterateItems() do
        local matches = item.type == "AtDropdownItemExecute" or
            item:GetText():lower():find(query, 1, true) ~= nil
        item.frame:SetShown(matches)
        if matches then
            item:SetPoint("TOP", self.itemFrame, "TOP", 0, -2 - visible * 16)
            visible = visible + 1
        end
    end
    self.noResults:SetShown(visible == 0)
    local height = math.max(visible, 1) * 16 + 8
    self.itemFrame:SetHeight(height)
    self.frame:SetHeight(math.min(height + 34 + variables.searchHeight,
        self.maxHeight, variables.searchMaxHeight))
    self.slider:SetValue(0)
    self:SetScroll(0)
    self:FixScroll()
end

---@param widget AtDropdownPullout
local function SkinPullout(widget)
    widget.frame:SetBackdrop(nil)
    ThemedWidgets.DiscardTextures(widget.frame)
    ThemeApply.CreatePanel(widget.frame)
    widget.slider:SetBackdrop(nil)
    ThemedWidgets.SkinScrollBar(widget.slider)

    local search = CreateFrame("EditBox", nil, widget.frame)
    widget.search = search
    search:SetAutoFocus(false)
    search:SetHeight(24)
    search:SetPoint("TOPLEFT", widget.frame, "TOPLEFT", 8, -8)
    search:SetPoint("TOPRIGHT", widget.frame, "TOPRIGHT", -8, -8)
    search:SetTextInsets(6, 6, 0, 0)
    search.AtField = ThemedWidgets.CreateField(search, search, 0, 0, 0, 0)
    widget.searchHint = search:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    widget.searchHint:SetPoint("LEFT", search, "LEFT", 6, 0)
    widget.searchHint:SetText(private.getLocalisation("DropdownSearch"))
    widget.noResults = widget.scrollFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    widget.noResults:SetPoint("TOPLEFT", widget.scrollFrame, "TOPLEFT", 6, -2)
    widget.noResults:SetPoint("RIGHT", widget.scrollFrame, "RIGHT", -6, 0)
    widget.noResults:SetText(private.getLocalisation("DropdownNoResults"))
    widget.noResults:Hide()
    search:SetScript("OnTextChanged", function()
        FilterItems(widget)
    end)
    search:SetScript("OnEscapePressed", function()
        widget:Close()
    end)
    search:SetScript("OnEnterPressed", function()
        search:ClearFocus()
    end)
    widget.frame:HookScript("OnHide", function()
        search:ClearFocus()
    end)

    local stockOpen = widget.Open
    widget.Open = function(self, ...)
        self.searchEnabled = #self.items > variables.searchThreshold
        search:SetShown(self.searchEnabled)
        self.noResults:Hide()
        self.scrollFrame:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 6,
            -12 - (self.searchEnabled and variables.searchHeight or 0))
        search:SetText("")
        stockOpen(self, ...)
        FilterItems(self)
        if self.searchEnabled then
            search:SetFocus()
        end
    end
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
    widget.SetItemPreview = function(self, callback, excludedValue)
        for _, item in self.pullout:IterateItems() do
            local enabled = callback and item.userdata.value ~= excludedValue and
                item.type == "AtDropdownItemToggle"
            item.userdata.atPreview = enabled and callback or nil
            if enabled and not item.previewButton then
                local button = CreateFrame("Button", nil, item.frame)
                item.previewButton = button
                button:SetSize(18, 16)
                button:SetPoint("RIGHT", item.frame, "RIGHT", -6, 0)
                button:SetNormalTexture("Interface\\Common\\VoiceChat-Speaker")
                button:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
                button:SetScript("OnClick", function()
                    local preview = item.userdata.atPreview
                    if preview then
                        preview(item.userdata.value)
                    end
                end)
                button:SetScript("OnEnter", function()
                    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
                    GameTooltip:SetText(private.getLocalisation("DropdownPreviewSound"))
                    GameTooltip:Show()
                    GameTooltip:SetFrameLevel(math.max(GameTooltip:GetFrameLevel(), button:GetFrameLevel() + 1))
                end)
                button:SetScript("OnLeave", function()
                    GameTooltip:Hide()
                end)
                button:SetScript("OnHide", function()
                    if GameTooltip:IsOwned(button) then
                        GameTooltip:Hide()
                    end
                end)
            end
            UpdateItemPreview(item)
        end
    end
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
