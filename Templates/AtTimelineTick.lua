local addonName, private = ...
local AceGUI = LibStub("AceGUI-3.0")

local Type = "AtTimelineTicks"
local Version = 1
local variables = {
    color = {
        r = 1,
        g = 1,
        b = 1,
        a = 1,
    },
    height = 1,
    width = 10,
    textOffset = {
        x = 5,
        y = 0,
    }
}

---@param self AtTimelineTicks
local function OnAcquire(self)
end

---@param self AtTimelineTicks
local function OnRelease(self)
    self.frame.tickText:SetText("")
    self.frame:ClearAllPoints()
end

local function SetTick(self, relativeTo, tick)
    local moveHeight = relativeTo:GetHeight()  
    self.frame.tickText:SetText(tick .. "s")
    local tickPosition = (tick / private.AT_THRESHHOLD_TIME) * moveHeight
    self.frame:SetPoint("LEFT", relativeTo, "BOTTOMLEFT", 0, tickPosition)
    self.frame:SetPoint("RIGHT", relativeTo, "BOTTOMRIGHT", 0, tickPosition)
    self.frame:SetParent(relativeTo)
end

local function Constructor()
	local count = AceGUI:GetNextWidgetNum(Type)

	local frame = CreateFrame("Frame", Type .. count, UIParent )
	
    frame:SetHeight(variables.height)
    frame:SetWidth(variables.width)
    frame.tickLine = frame:CreateTexture(nil, "ARTWORK")
    frame.tickLine:SetColorTexture(variables.color.r, variables.color.g, variables.color.b, variables.color.a)
    frame.tickLine:SetPoint("LEFT", frame, "LEFT", 0, 0)
    frame.tickLine:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
    frame.tickText =  frame:CreateFontString(nil, "OVERLAY", "SystemFont_Shadow_Med3")
    frame.tickText:SetPoint("LEFT", frame.tickLine, "RIGHT", variables.textOffset.x, variables.textOffset.y)
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
	}

	return AceGUI:RegisterAsWidget(widget)
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)