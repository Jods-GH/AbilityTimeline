local appName, app = ...
---@class AbilityTimeline
local private = app
local AceGUI = LibStub("AceGUI-3.0")

local Type = "AtTimelineTicks"
local Version = 1
local variables = {
    width = 10,
}

---@param self AtTimelineTicks
local function OnAcquire(self)
end

---@param self AtTimelineTicks
local function OnRelease(self)
    self.frame.tickText:SetText("")
    self.frame:ClearAllPoints()
    self.relativeTo = nil
end

local function SetTick(self, relativeTo, tick, totalSize, threshhold, isHorizontal)
    self.relativeTo, self.totalSize, self.threshhold, self.isHorizontal = relativeTo, totalSize, threshhold, isHorizontal
    local style = private.GetElementStyle("Tick")
    local textOffset = style.Text.Offset
    self.frame.tickText:SetText(tick .. "s")
    local tickPosition = (tick / threshhold) * totalSize
    self.frame:ClearAllPoints()
    self.frame.tickLine:ClearAllPoints()
    self.frame.tickText:ClearAllPoints()
    self.tick = tick
    if isHorizontal then
        self.frame:SetPoint("TOPLEFT", relativeTo, "TOPLEFT", tickPosition, 0)
        self.frame:SetPoint("BOTTOMLEFT", relativeTo, "BOTTOMLEFT", tickPosition, 0)
        self.frame.tickLine:SetPoint("TOP", self.frame, "TOP", 0, 0)
        self.frame.tickLine:SetPoint("BOTTOM", self.frame, "BOTTOM", 0, 0)
        self.frame.tickText:SetPoint("BOTTOM", self.frame.tickLine, "TOP", textOffset.y, textOffset.x)
    else
        self.frame:SetPoint("LEFT", relativeTo, "BOTTOMLEFT", 0, tickPosition)
        self.frame:SetPoint("RIGHT", relativeTo, "BOTTOMRIGHT", 0, tickPosition)
        self.frame.tickLine:SetPoint("LEFT", self.frame, "LEFT", 0, 0)
        self.frame.tickLine:SetPoint("RIGHT", self.frame, "RIGHT", 0, 0)
        self.frame.tickText:SetPoint("LEFT", self.frame.tickLine, "RIGHT", textOffset.x, textOffset.y)
    end
    self.frame:SetParent(relativeTo)
end

---@param self AtTimelineTicks
local function ApplySettings(self)
    local style = private.GetElementStyle("Tick")
    private.ThemeApply.Texture(self.frame.tickLine, style.Line)
    self.frame:SetHeight(style.Line.Thickness)
    private.ThemeApply.Font(self.frame.tickText, style.Text.Font)
    if self.relativeTo then
        SetTick(self, self.relativeTo, self.tick, self.totalSize, self.threshhold, self.isHorizontal)
    end
end


local function Constructor()
    local count = AceGUI:GetNextWidgetNum(Type)

    local frame = CreateFrame("Frame", Type .. count, UIParent)

    frame:SetWidth(variables.width)
    frame.tickLine = frame:CreateTexture(nil, "ARTWORK")
    frame.tickLine:SetPoint("LEFT", frame, "LEFT", 0, 0)
    frame.tickLine:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
    frame.tickText = frame:CreateFontString(nil, "OVERLAY", "SystemFont_Shadow_Med3")
    frame.tickText:SetJustifyH("CENTER")
    frame:Hide()

    ---@class AtTimelineTicks : AceGUIWidget
    local widget = {
        OnAcquire = OnAcquire,
        OnRelease = OnRelease,
        frame = frame,
        type = Type,
        count = count,
        SetTick = SetTick,
        ApplySettings = ApplySettings,
        tick = 0,
    }
    ApplySettings(widget)
    private.RegisterThemed(widget)

    return AceGUI:RegisterAsWidget(widget)
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)
