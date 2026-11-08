local appName, app = ...
---@class AbilityTimeline
local private = app
local ThemeApply = private.ThemeApply

-- suggestions below an AtEditBox while typing: clicked, or chosen with the arrow keys and taken with enter or tab.
-- One list serves every box, getSuggestions(text) returns { text, value, detail, icon, color } and onPick(suggestion)
-- puts the choice into the box
local variables = {
    itemHeight = 22,
    visibleItems = 8,
    padding = 4,
    icon = 16,
    -- the box loses focus before a click on a suggestion arrives
    hideDelay = 0.2,
}

local popup

---@param item Button
local drawItem = function(item)
    local r, g, b, a = ThemeApply.Color("Highlight")
    ThemeApply.Solid(item.Fill, r, g, b, item.selected and a * 3 or 0)
    ThemeApply.FontRole(item.Text, "Control")
    ThemeApply.FontRole(item.Detail, "Muted")
    local color = item.suggestion and item.suggestion.color
    if color then
        item.Text:SetTextColor(color.r, color.g, color.b)
    end
end

---the spell of the selected suggestion beside the list, so spells of one name can be told apart
---@param item Button
local showTooltip = function(item)
    local spellId = item.suggestion and item.suggestion.spellId
    if not spellId then
        if popup.tooltipShown then
            GameTooltip:Hide()
            popup.tooltipShown = false
        end
        return
    end
    GameTooltip:SetOwner(popup, "ANCHOR_NONE")
    GameTooltip:SetPoint("TOPLEFT", popup, "TOPRIGHT", 4, 0)
    GameTooltip:SetSpellByID(spellId)
    GameTooltip:AddLine(private.getLocalisation("AutoCompleteSpellId"):format(spellId), 0.6, 0.6, 0.6)
    GameTooltip:Show()
    popup.tooltipShown = true
end

local hide = function()
    if popup then
        if popup.tooltipShown then
            GameTooltip:Hide()
            popup.tooltipShown = false
        end
        popup:Hide()
        popup.owner = nil
    end
end

---@param index number
local selectItem = function(index)
    popup.index = index
    for i, item in ipairs(popup.Items) do
        item.selected = i == index
        drawItem(item)
    end
    if popup.Items[index] then
        showTooltip(popup.Items[index])
    end
end

---@param index number
local pick = function(index)
    local owner = popup.owner
    local suggestion = popup.suggestions[index]
    hide()
    if owner and owner.atAutoComplete and suggestion then
        owner.atAutoComplete.pick(suggestion)
    end
end

local createPopup = function()
    popup = CreateFrame("Frame", nil, UIParent)
    -- above every window it suggests for, dialogs of the FULLSCREEN_DIALOG strata and their buttons included
    popup:SetFrameStrata("TOOLTIP")
    popup:SetClampedToScreen(true)
    popup:Hide()
    ThemeApply.CreatePanel(popup)
    popup.Items = {}
    for i = 1, variables.visibleItems do
        local item = CreateFrame("Button", nil, popup)
        item:SetHeight(variables.itemHeight)
        item:SetPoint("TOPLEFT", popup, "TOPLEFT", variables.padding, -variables.padding - (i - 1) * variables.itemHeight)
        item:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -variables.padding, -variables.padding - (i - 1) * variables.itemHeight)
        item.Fill = item:CreateTexture(nil, "BACKGROUND")
        item.Fill:SetAllPoints(item)
        item.Icon = item:CreateTexture(nil, "ARTWORK")
        item.Icon:SetSize(variables.icon, variables.icon)
        item.Icon:SetPoint("LEFT", item, "LEFT", 4, 0)
        item.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        item.Detail = item:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        item.Detail:SetPoint("RIGHT", item, "RIGHT", -6, 0)
        item.Detail:SetJustifyH("RIGHT")
        item.Text = item:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        item.Text:SetPoint("RIGHT", item.Detail, "LEFT", -6, 0)
        item.Text:SetJustifyH("LEFT")
        item.Text:SetWordWrap(false)
        item:SetScript("OnEnter", function() selectItem(i) end)
        item:SetScript("OnClick", function() pick(i) end)
        popup.Items[i] = item
    end
    popup:SetScript("OnUpdate", function(self, elapsed)
        local owner = self.owner
        if owner and owner.editbox:HasFocus() then
            self.lost = 0
            return
        end
        self.lost = (self.lost or 0) + elapsed
        if self.lost > variables.hideDelay then
            hide()
        end
    end)
end

---shows the suggestions for the box's text, nothing to suggest hides the list
---@param widget AtEditBox
private.RefreshAutoComplete = function(widget)
    if not widget.atAutoComplete then return end
    if not popup then
        createPopup()
    end
    local suggestions = widget.atAutoComplete.get(widget:GetText() or "")
    if #suggestions == 0 then
        if popup.owner == widget then
            hide()
        end
        return
    end
    popup.owner = widget
    popup.suggestions = suggestions
    popup.lost = 0
    local shown = math.min(#suggestions, variables.visibleItems)
    for i, item in ipairs(popup.Items) do
        local suggestion = suggestions[i]
        item.suggestion = suggestion
        item:SetShown(suggestion ~= nil)
        if suggestion then
            item.Icon:SetShown(suggestion.icon ~= nil)
            item.Icon:SetTexture(suggestion.icon)
            item.Text:SetPoint("LEFT", item, "LEFT", suggestion.icon and variables.icon + 10 or 6, 0)
            item.Text:SetText(suggestion.text)
            item.Detail:SetText(suggestion.detail or "")
        end
    end
    popup.AtFill:SetVertexColor(ThemeApply.Color("Body"))
    popup.AtEdge:SetVertexColor(ThemeApply.Color("Edge"))
    popup:ClearAllPoints()
    popup:SetPoint("TOPLEFT", widget.editbox, "BOTTOMLEFT", -6, -2)
    popup:SetWidth(math.max(widget.frame:GetWidth(), 220))
    popup:SetHeight(shown * variables.itemHeight + variables.padding * 2)
    popup:Show()
    selectItem(1)
end

---gives an AtEditBox suggestions, they go again when the widget is released
---@param widget AtEditBox
---@param getSuggestions fun(text: string): table[]
---@param onPick fun(suggestion: table)
private.AttachAutoComplete = function(widget, getSuggestions, onPick)
    widget.atAutoComplete = { get = getSuggestions, pick = onPick }
    local editbox = widget.editbox
    -- AceGUI's edit box has no handlers of its own for these keys
    editbox:SetScript("OnArrowPressed", function(_, key)
        if not popup or popup.owner ~= widget or not popup:IsShown() then return end
        local count = math.min(#popup.suggestions, variables.visibleItems)
        if key == "UP" then
            selectItem(popup.index > 1 and popup.index - 1 or count)
        elseif key == "DOWN" then
            selectItem(popup.index < count and popup.index + 1 or 1)
        end
    end)
    editbox:SetScript("OnTabPressed", function()
        if popup and popup.owner == widget and popup:IsShown() then
            pick(popup.index)
        end
    end)
    widget:SetCallback("OnEnterPressed", function()
        if popup and popup.owner == widget and popup:IsShown() then
            pick(popup.index)
        end
    end)
    widget:SetCallback("OnRelease", function()
        widget.atAutoComplete = nil
        editbox:SetScript("OnArrowPressed", nil)
        editbox:SetScript("OnTabPressed", nil)
        if popup and popup.owner == widget then
            hide()
        end
    end)
end

private.HideAutoComplete = hide
