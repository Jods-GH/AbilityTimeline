local addonName, private = ...
local AceGUI = LibStub("AceGUI-3.0")
local LibEditMode = LibStub("LibEditMode")
local Type = "AtTimelineFrame"
local Version = 1
local variables = {
}
private.TimelineFrame = {}
private.TimelineFrame.defaultPosition = {
    point = 'CENTER',
    x = 0,
    y = 0,
}

---@param self AtTimelineFrame
local function OnAcquire(self)
end

---@param self AtTimelineFrame
local function OnRelease(self)
end
local function onPositionChanged(frame, layoutName, point, x, y)
    -- from here you can save the position into a savedvariable
    private.db.profile.timeline_frame[layoutName] = private.db.profile.timeline_frame[layoutName] or {}
    private.db.profile.timeline_frame[layoutName].x = x
    private.db.profile.timeline_frame[layoutName].y = y
    private.db.profile.timeline_frame[layoutName].point = point

    private.TIMELINE_FRAME:SetPoint(private.db.profile.timeline_frame[layoutName].point,
        private.db.profile.timeline_frame[layoutName].x, private.db.profile.timeline_frame[layoutName].y)
end

local function HandleTickVisibility(layoutName)
    if private.db.profile.timeline_frame_ticks_enabled[layoutName] then
        for _, tick in ipairs(private.TIMELINE_FRAME.frame.Ticks) do
            tick:Show()
            tick.tickText:Show()
        end
    else
        for _, tick in ipairs(private.TIMELINE_FRAME.frame.Ticks) do
            tick:Hide()
            tick.tickText:Hide()
        end
    end
end

LibEditMode:RegisterCallback('layout', function(layoutName)
    -- this will be called every time the Edit Mode layout is changed (which also happens at login),
    -- use it to load the saved button position from savedvariables and position it
    if not private.db.profile.timeline_frame then
        private.db.profile.timeline_frame = {}
    end
    if not private.db.profile.timeline_frame[layoutName] then
        private.db.profile.timeline_frame[layoutName] = CopyTable(private.TimelineFrame.defaultPosition)
    end
    if not private.db.profile.timeline_frame_ticks_enabled then
        private.db.profile.timeline_frame_ticks_enabled = {}
    end
    if not private.db.profile.timeline_frame_ticks_enabled[layoutName] then
        private.db.profile.timeline_frame_ticks_enabled[layoutName] = true
    end
    if private.TIMELINE_FRAME then
        private.TIMELINE_FRAME:ClearAllPoints()
        private.TIMELINE_FRAME:SetPoint(private.db.profile.timeline_frame[layoutName].point,
        private.db.profile.timeline_frame[layoutName].x, private.db.profile.timeline_frame[layoutName].y)
                HandleTickVisibility(layoutName)
    end
    private.ACTIVE_EDITMODE_LAYOUT = layoutName
end)


local function Constructor()
    local count = AceGUI:GetNextWidgetNum(Type)
    local frame = CreateFrame("Frame", "AbilityTimelineFrame", UIParent, "BackdropTemplate")
    frame:SetWidth(60)
    frame:SetHeight(500)

    LibEditMode:AddFrame(frame, onPositionChanged, private.TimelineFrame.defaultPosition, "Ability Timeline")
    
    LibEditMode:AddFrameSettings(frame, {
        {
            name = 'Enable Ticks',
            kind = LibEditMode.SettingType.Checkbox,
            default = true,
            get = function(layoutName)
                return private.db.profile.timeline_frame_ticks_enabled[layoutName]
            end,
            set = function(layoutName, value)
                private.db.profile.timeline_frame_ticks_enabled[layoutName] = value
                HandleTickVisibility(layoutName)
            end,
        }
    })

    frame:SetFrameStrata("BACKGROUND")
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    frame:SetBackdropColor(0, 0, 0, 1)
    frame.Ticks = {}


    local moveHeight = frame:GetHeight()  
    for i, tick in ipairs(private.TIMELINE_TICKS) do
        local tickLine = frame:CreateTexture(nil, "ARTWORK")
        local tickPosition = (tick / private.AT_THRESHHOLD_TIME) * moveHeight
        tickLine:SetColorTexture(1, 1, 1, 1)
        tickLine:SetHeight(1)
        tickLine:SetPoint("LEFT", frame, "BOTTOMLEFT", 0, tickPosition)
        tickLine:SetPoint("RIGHT", frame, "BOTTOMRIGHT", 0, tickPosition)
        tickLine.tickText =  frame:CreateFontString(nil, "OVERLAY", "SystemFont_Shadow_Med3")
        tickLine.tickText:SetPoint("LEFT", tickLine, "RIGHT", 5, 0)
        tickLine.tickText:SetText(tick .. "s")
        frame.Ticks[i] = tickLine
        tickLine:Hide()
    end
    frame:Hide()
    private.Debug(frame, "AT_TIMELINE_FRAME")

    ---@class AtTimelineFrame : AceGUIWidget
    local widget = {
        OnAcquire = OnAcquire,
        OnRelease = OnRelease,
        type = Type,
        count = count,
        frame = frame,
        moveHeight = moveHeight,
    }

    return AceGUI:RegisterAsWidget(widget)
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)
