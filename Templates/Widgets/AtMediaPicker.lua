local appName, app = ...
---@class AbilityTimeline
local private = app
local AceGUI = LibStub("AceGUI-3.0")
local SharedMedia = LibStub("LibSharedMedia-3.0")
local ThemeApply = private.ThemeApply
local ThemedWidgets = private.ThemedWidgets

-- a dropdown of SharedMedia: the field shows the name, its list a search and a preview of every texture, border or
-- font, drawn on a neutral gray so light and dark textures can be seen in every theme
local Type = "AtMediaPicker"
local Version = 1
local variables = {
    height = 26,
    chevron = 12,
    listWidth = 300,
    searchHeight = 22,
    itemHeight = 28,
    visibleItems = 9,
    padding = 8,
    previewWidth = 110,
    previewBack = { 0.3, 0.3, 0.3, 1 },
    fontSize = 14,
    borderSize = 12,
    scrollBarWidth = 10,
}

local popup

local getMediaName = function(widget)
    return widget.value or "None"
end

---@param item Button
local drawItem = function(item)
    local r, g, b, a = ThemeApply.Color(item.selected and "Accent" or "Highlight")
    ThemeApply.Solid(item.Fill, r, g, b, item.selected and 0.25 or a * (item.hover and 1 or 0))
end

---shows the media of the owner's type whose name contains the search, from popup.offset on
local refreshPopup = function()
    local owner = popup.owner
    local query = popup.Search:GetText():lower()
    local names = {}
    for _, name in ipairs(SharedMedia:List(owner.mediaType)) do
        if query == "" or name:lower():find(query, 1, true) then
            table.insert(names, name)
        end
    end
    popup.offset = math.max(0, math.min(popup.offset, #names - variables.visibleItems))
    popup.SearchHint:SetShown(query == "")
    for i, item in ipairs(popup.Items) do
        local name = names[i + popup.offset]
        item:SetShown(name ~= nil)
        if name then
            local path = SharedMedia:Fetch(owner.mediaType, name)
            item.name = name
            item.selected = name == getMediaName(owner)
            ThemeApply.FontRole(item.Text, "Control")
            -- a font previewed in the row before stays over the font object, so the role's own font is set again
            item.Text:SetFont(ThemeApply.FontObject("Control"):GetFont())
            item.Text:SetText(name)
            item.Preview:SetShown(owner.mediaType ~= "font")
            item.Preview.Texture:SetShown(owner.mediaType ~= "border")
            item.Preview:SetBackdrop(nil)
            if item.Preview.atMediaPreview then item.Preview.atMediaPreview.Reset(item.Preview) end
            item.Preview.atMediaPreview = private.GetMediaPreview(owner.mediaType, name)
            if item.Preview.atMediaPreview then
                item.Preview.atMediaPreview.Draw(item.Preview)
            elseif owner.mediaType == "font" then
                item.Text:SetFont(path, variables.fontSize, "")
            elseif owner.mediaType == "border" then
                if path and path ~= "" then
                    item.Preview:SetBackdrop({ edgeFile = path, edgeSize = variables.borderSize })
                end
            else
                item.Preview.Texture:SetTexture(path)
            end
            drawItem(item)
        end
    end
    -- the scroll bar follows without scrolling the list again
    local maxOffset = math.max(0, #names - variables.visibleItems)
    popup.updatingScrollBar = true
    popup.ScrollBar:SetMinMaxValues(0, maxOffset)
    popup.ScrollBar:SetValue(popup.offset)
    popup.updatingScrollBar = false
    popup.ScrollBar:SetShown(maxOffset > 0)
end

local applyPopupSettings = function()
    popup.AtFill:SetVertexColor(ThemeApply.Color("Body"))
    popup.AtEdge:SetVertexColor(ThemeApply.Color("Edge"))
    popup.Search:SetFontObject(ThemeApply.FontObject("Control"))
    popup.Search:SetTextColor(ThemeApply.FontObject("Control"):GetTextColor())
    ThemeApply.FontRole(popup.SearchHint, "Muted")
    ThemedWidgets.DrawField(popup.Search.AtField)
    popup.ScrollBar.AtDraw()
    if popup:IsShown() then
        refreshPopup()
    end
end

local createPopup = function()
    popup = CreateFrame("Frame", nil, UIParent)
    popup:Hide()
    popup:SetFrameStrata("FULLSCREEN_DIALOG")
    popup:SetClampedToScreen(true)
    popup:EnableMouse(true)
    popup:SetSize(variables.listWidth, variables.padding * 3 + variables.searchHeight +
        variables.visibleItems * variables.itemHeight)
    ThemeApply.CreatePanel(popup)
    popup.offset = 0

    local search = CreateFrame("EditBox", nil, popup)
    search:SetAutoFocus(false)
    search:SetHeight(variables.searchHeight)
    search:SetPoint("TOPLEFT", popup, "TOPLEFT", variables.padding, -variables.padding)
    search:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -variables.padding, -variables.padding)
    search:SetTextInsets(6, 6, 0, 0)
    search:SetFontObject(ThemeApply.FontObject("Control"))
    search.AtField = ThemedWidgets.CreateField(search, search, 0, 0, 0, 0)
    search:SetScript("OnTextChanged", function()
        popup.offset = 0
        refreshPopup()
    end)
    search:SetScript("OnEscapePressed", function()
        popup:Hide()
    end)
    popup.Search = search
    popup.SearchHint = search:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    popup.SearchHint:SetPoint("LEFT", search, "LEFT", 6, 0)
    popup.SearchHint:SetText(private.getLocalisation("SettingsSearch"))

    popup.Items = {}
    for i = 1, variables.visibleItems do
        local item = CreateFrame("Button", nil, popup)
        item:SetHeight(variables.itemHeight)
        item:SetPoint("TOPLEFT", search, "BOTTOMLEFT", 0, -variables.padding - (i - 1) * variables.itemHeight)
        item:SetPoint("TOPRIGHT", search, "BOTTOMRIGHT", -variables.scrollBarWidth - 4,
            -variables.padding - (i - 1) * variables.itemHeight)
        item.Fill = item:CreateTexture(nil, "BACKGROUND")
        item.Fill:SetAllPoints(item)
        item.Preview = CreateFrame("Frame", nil, item, "BackdropTemplate")
        item.Preview:SetSize(variables.previewWidth, variables.itemHeight - 8)
        item.Preview:SetPoint("RIGHT", item, "RIGHT", -4, 0)
        item.Preview.Back = item.Preview:CreateTexture(nil, "BACKGROUND")
        item.Preview.Back:SetAllPoints(item.Preview)
        ThemeApply.Solid(item.Preview.Back, unpack(variables.previewBack))
        item.Preview.Texture = item.Preview:CreateTexture(nil, "ARTWORK")
        item.Preview.Texture:SetAllPoints(item.Preview)
        item.Text = item:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        item.Text:SetPoint("LEFT", item, "LEFT", 6, 0)
        item.Text:SetPoint("RIGHT", item.Preview, "LEFT", -6, 0)
        item.Text:SetJustifyH("LEFT")
        item.Text:SetWordWrap(false)
        item:SetScript("OnEnter", function()
            item.hover = true
            drawItem(item)
        end)
        item:SetScript("OnLeave", function()
            item.hover = false
            drawItem(item)
        end)
        item:SetScript("OnClick", function()
            popup.owner:SetValue(item.name)
            popup.owner:Fire("OnValueChanged", item.name)
            popup:Hide()
        end)
        popup.Items[i] = item
    end
    local scrollBar = CreateFrame("Slider", nil, popup)
    scrollBar:SetOrientation("VERTICAL")
    scrollBar:SetWidth(variables.scrollBarWidth)
    scrollBar:SetPoint("TOPLEFT", popup.Items[1], "TOPRIGHT", 4, 0)
    scrollBar:SetPoint("BOTTOMLEFT", popup.Items[#popup.Items], "BOTTOMRIGHT", 4, 0)
    scrollBar:SetValueStep(1)
    scrollBar:SetObeyStepOnDrag(true)
    scrollBar:SetScript("OnValueChanged", function(_, value)
        if popup.updatingScrollBar then return end
        popup.offset = math.floor(value + 0.5)
        refreshPopup()
    end)
    ThemedWidgets.SkinScrollBar(scrollBar)
    popup.ScrollBar = scrollBar

    popup:EnableMouseWheel(true)
    popup:SetScript("OnMouseWheel", function(_, delta)
        popup.offset = popup.offset - delta
        refreshPopup()
    end)
    -- a click anywhere else closes it
    popup:SetScript("OnUpdate", function()
        if (IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton")) and not popup:IsMouseOver() and
            not popup.owner.frame:IsMouseOver() then
            popup:Hide()
        end
    end)
    popup:SetScript("OnHide", function()
        popup.Search:ClearFocus()
        local owner = popup.owner
        popup.owner = nil
        if owner then owner.frame.AtDraw() end
    end)
    -- the themed are held weakly, the popup holds it
    popup.AtThemed = { ApplySettings = applyPopupSettings }
    private.RegisterThemed(popup.AtThemed)
    applyPopupSettings()
end

---@param widget AtMediaPicker
local openPopup = function(widget)
    if not popup then
        createPopup()
    end
    popup.owner = widget
    popup:ClearAllPoints()
    popup:SetPoint("TOPRIGHT", widget.frame, "BOTTOMRIGHT", 0, -2)
    popup.Search:SetText("")
    -- the selected one is in the middle of the list
    local index = tIndexOf(SharedMedia:List(widget.mediaType), getMediaName(widget)) or 1
    popup.offset = index - math.ceil(variables.visibleItems / 2)
    popup:Show()
    refreshPopup()
    popup.Search:SetFocus()
    widget.frame.AtDraw()
end

---@param self AtMediaPicker
local function ApplySettings(self)
    local frame = self.frame
    ThemeApply.FontRole(frame.Text, "Control")
    frame.atDisabled = self.disabled
    frame.AtDraw()
    frame:SetAlpha(self.disabled and 0.5 or 1)
end

---@param self AtMediaPicker
local function OnAcquire(self)
    self:SetHeight(variables.height)
    self:SetWidth(200)
    self:SetDisabled(false)
    self.value = nil
    self.frame.Text:SetText("")
end

---@param self AtMediaPicker
local function OnRelease(self)
    if popup and popup.owner == self then
        popup:Hide()
    end
    self.frame:ClearAllPoints()
    self.frame:Hide()
end

---@param self AtMediaPicker
---@param mediaType string -- a SharedMedia type: background, border, statusbar or font
local function SetMediaType(self, mediaType)
    self.mediaType = mediaType
end

---@param self AtMediaPicker
---@param value string|nil
local function SetValue(self, value)
    self.value = value
    local name = getMediaName(self)
    self.frame.Text:SetText(name == "None" and private.getLocalisation("EditorNone") or name or "")
end

---@param self AtMediaPicker
---@param disabled boolean
local function SetDisabled(self, disabled)
    self.disabled = disabled
    self.frame:EnableMouse(not disabled)
    ApplySettings(self)
end

local function Constructor()
    local frame = CreateFrame("Button", nil, UIParent)
    frame:Hide()
    local field = ThemedWidgets.CreateField(frame, frame, 0, 0, 0, 0)
    frame.Chevron = frame:CreateTexture(nil, "ARTWORK")
    frame.Chevron:SetTexture(ThemeApply.File("chevron"))
    frame.Chevron:SetSize(variables.chevron, variables.chevron)
    frame.Chevron:SetPoint("RIGHT", frame, "RIGHT", -8, 0)
    frame.Text = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.Text:SetPoint("LEFT", frame, "LEFT", 10, 0)
    frame.Text:SetPoint("RIGHT", frame.Chevron, "LEFT", -6, 0)
    frame.Text:SetJustifyH("LEFT")
    frame.Text:SetWordWrap(false)
    frame.AtDraw = function()
        ThemedWidgets.DrawDropdown(field, frame, frame.Text, frame.Chevron, frame.atDisabled,
            popup and popup.owner and popup.owner.frame == frame and popup:IsShown())
    end

    ---@class AtMediaPicker : AceGUIWidget
    local widget = {
        OnAcquire = OnAcquire,
        OnRelease = OnRelease,
        ApplySettings = ApplySettings,
        SetMediaType = SetMediaType,
        SetValue = SetValue,
        SetDisabled = SetDisabled,
        type = Type,
        frame = frame,
    }
    frame:SetScript("OnClick", function()
        if popup and popup:IsShown() and popup.owner == widget then
            popup:Hide()
        else
            openPopup(widget)
        end
    end)
    frame:SetScript("OnEnter", function()
        widget:Fire("OnEnter")
    end)
    frame:SetScript("OnLeave", function()
        widget:Fire("OnLeave")
    end)
    frame:SetScript("OnHide", function()
        if popup and popup.owner == widget then
            popup:Hide()
        end
    end)
    -- hooked after the scripts above, setting a script drops the hooks
    ThemedWidgets.HookHover(frame, field, frame.AtDraw)
    ApplySettings(widget)
    private.RegisterThemed(widget)

    return AceGUI:RegisterAsWidget(widget)
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)
