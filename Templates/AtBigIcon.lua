local addonName, private = ...
local AceGUI = LibStub("AceGUI-3.0")
local Type = "AtBigIcon"
local Version = 1
local variables = {
    zoom = 0.7,
    cooldown_scale = 2,
    icon_text_width = 95,
    icon_text_offset_x = 0,
    icon_text_offset_y = -10,
}

private.BIG_ICON_SIZE = 100
private.BIG_ICON_MARGIN = 10


---@param self AtBigIcon
local function OnAcquire(self)
end

---@param self AtBigIcon
local function OnRelease(self)
    self.frame.icon:SetTexture(nil)
    self.frame.iconText:SetText("")
end

local SetEventInfo = function(widget, eventInfo)
    widget.eventInfo = eventInfo
    widget.frame.Cooldown:SetCooldown(GetTime(), eventInfo.duration - C_EncounterTimeline.GetEventTimeElapsed(eventInfo.id))
    widget.frame.Cooldown:SetScript("OnCooldownDone", function(self)
        private.HIGHLIGHT_EVENTS.BigIcons[eventInfo.id] = nil
        for i, f in ipairs(private.BIG_ICONS) do
            if f == widget then
                table.remove(private.BIG_ICONS, i)
                break
            end
        end
        widget:Release()
        private.evaluateBigIconPositions()
    end)
    local xOffset = (private.BIG_ICON_SIZE + private.BIG_ICON_MARGIN) * (#private.BIG_ICONS)
    widget.frame:SetPoint("LEFT", private.BIGICON_FRAME.frame, "LEFT", xOffset, 0)
    widget.frame.xOffset = xOffset
    widget.frame.icon:SetAllPoints(widget.frame)
    widget.frame.icon:SetTexture(eventInfo.iconFileID)
    widget.frame.iconText:SetText(eventInfo.spellName)
    widget.frame:Show()
end
local function Constructor()
    local count = AceGUI:GetNextWidgetNum(Type)
    local frame = CreateFrame("Frame", "BIGICON"..count, private.BIGICON_FRAME.frame)
    frame.Cooldown = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
    frame.Cooldown:SetDrawSwipe(true)
    frame.Cooldown:SetDrawEdge(true)
    frame.Cooldown:SetAllPoints(frame)
    frame.Cooldown:SetScale(variables.cooldown_scale)
    
    frame:SetSize(private.BIG_ICON_SIZE, private.BIG_ICON_SIZE)

    frame.icon = frame:CreateTexture(nil, "OVERLAY")
    private.SetZoom(frame.icon, variables.zoom)
    frame.iconText = frame:CreateFontString(nil, "OVERLAY", "SystemFont_Shadow_Med3")
    frame.iconText:SetWidth(variables.icon_text_width)
    frame.iconText:SetWordWrap(true)
    frame.iconText:SetPoint("TOP", frame, "BOTTOM",variables.icon_text_offset_x, variables.icon_text_offset_y)
    frame:Show()


    ---@class AtBigIcon : AceGUIWidget
    local widget = {
        OnAcquire = OnAcquire,
        OnRelease = OnRelease,
        type = Type,
        count = count,
        frame = frame,
        SetEventInfo = SetEventInfo,
    }

    return AceGUI:RegisterAsWidget(widget)
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)
