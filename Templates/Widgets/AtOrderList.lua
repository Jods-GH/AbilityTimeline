local appName, app = ...
---@class AbilityTimeline
local private = app
local AceGUI = LibStub("AceGUI-3.0")
local ThemeApply = private.ThemeApply
local ThemedWidgets = private.ThemedWidgets

-- a list of rows dragged into an order, the first is tried first. Rows can't be added or removed: keys of the order
-- without a label are not shown and keep their place
local Type = "AtOrderList"
local Version = 1
local variables = {
    rowHeight = 24,
    gap = 4,
}
local step = variables.rowHeight + variables.gap

---@param self AtOrderList
local function Refresh(self)
    for index, row in ipairs(self.rows) do
        local key = self.shown[index]
        row:SetShown(key ~= nil)
        if key then
            row.Index:SetText(index)
            row.Text:SetText(self.values[key])
            row.AtField.focus = key == self.dragKey and 1 or 0
            ThemedWidgets.DrawField(row.AtField)
            ThemeApply.FontRole(row.Index, "Muted")
            ThemeApply.FontRole(row.Text, "Control")
        end
    end
    self:SetHeight(math.max(#self.shown, 1) * step - variables.gap)
end

---moves the dragged row to the place under the pointer, the new order is fired once the button is let go
local function OnUpdate(frame)
    local self = frame.obj
    if not IsMouseButtonDown("LeftButton") then
        frame:SetScript("OnUpdate", nil)
        self.dragKey = nil
        Refresh(self)
        if self.moved then
            self.moved = nil
            local order, shownIndex = {}, 1
            for index, key in ipairs(self.order) do
                if self.values[key] then
                    order[index] = self.shown[shownIndex]
                    shownIndex = shownIndex + 1
                else
                    order[index] = key
                end
            end
            self.order = order
            self:Fire("OnValueChanged", order)
        end
        return
    end
    local _, y = GetCursorPosition()
    local index = math.floor((frame:GetTop() - y / frame:GetEffectiveScale()) / step) + 1
    index = math.max(1, math.min(#self.shown, index))
    if self.shown[index] ~= self.dragKey then
        for from, key in ipairs(self.shown) do
            if key == self.dragKey then
                table.remove(self.shown, from)
                break
            end
        end
        table.insert(self.shown, index, self.dragKey)
        self.moved = true
        Refresh(self)
    end
end

---@param self AtOrderList
---@param index number
local function CreateRow(self, index)
    local row = CreateFrame("Frame", nil, self.frame)
    row:SetHeight(variables.rowHeight)
    row:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, -(index - 1) * step)
    row:SetPoint("RIGHT", self.frame, "RIGHT")
    row:EnableMouse(true)
    row.AtField = ThemedWidgets.CreateField(row, row)
    row.Index = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.Index:SetPoint("LEFT", row, "LEFT", 10, 0)
    row.Text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.Text:SetPoint("LEFT", row, "LEFT", 28, 0)
    row.Text:SetPoint("RIGHT", row, "RIGHT", -10, 0)
    row.Text:SetJustifyH("LEFT")
    row.Text:SetWordWrap(false)
    ThemedWidgets.HookHover(row, row.AtField, function()
        ThemedWidgets.DrawField(row.AtField)
    end)
    row:HookScript("OnEnter", function()
        self:Fire("OnEnter")
    end)
    row:HookScript("OnLeave", function()
        self:Fire("OnLeave")
    end)
    row:SetScript("OnMouseDown", function(_, button)
        if button ~= "LeftButton" or self.disabled then return end
        self.dragKey = self.shown[index]
        Refresh(self)
        self.frame:SetScript("OnUpdate", OnUpdate)
    end)
    self.rows[index] = row
end

---@param self AtOrderList
local function ApplySettings(self)
    self.frame:SetAlpha(self.disabled and 0.5 or 1)
    Refresh(self)
end

---@param self AtOrderList
local function OnAcquire(self)
    self.values, self.order, self.shown = {}, {}, {}
    self.disabled = false
    ApplySettings(self)
end

---@param self AtOrderList
local function OnRelease(self)
    self.frame:SetScript("OnUpdate", nil)
    self.dragKey = nil
    self.moved = nil
end

---@param self AtOrderList
---@param values table<string, string> -- the label of every key shown
---@param order string[]
local function SetList(self, values, order)
    self.values, self.order, self.shown = values, order, {}
    for _, key in ipairs(order) do
        if values[key] then
            table.insert(self.shown, key)
        end
    end
    for index = #self.rows + 1, #self.shown do
        CreateRow(self, index)
    end
    Refresh(self)
end

---@param self AtOrderList
---@param disabled boolean
local function SetDisabled(self, disabled)
    self.disabled = disabled
    ApplySettings(self)
end

local function Constructor()
    local frame = CreateFrame("Frame", nil, UIParent)
    frame:Hide()

    ---@class AtOrderList : AceGUIWidget
    local widget = {
        OnAcquire = OnAcquire,
        OnRelease = OnRelease,
        ApplySettings = ApplySettings,
        SetList = SetList,
        SetDisabled = SetDisabled,
        type = Type,
        frame = frame,
        rows = {},
        values = {},
        order = {},
        shown = {},
    }
    private.RegisterThemed(widget)

    return AceGUI:RegisterAsWidget(widget)
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)
