local addonName, private = ...
local AceGUI = LibStub("AceGUI-3.0")
local LibEditMode = LibStub("LibEditMode")
local Type = "AtTimelineFrame"
local Version = 1
local variables = {
    width = 50,
    height =500
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
    if private.db.profile.timeline_frame[layoutName].ticks_enabled then
        for _, tick in ipairs(private.TIMELINE_FRAME.frame.Ticks) do
            tick.frame:Show()
        end
    else
        for _, tick in ipairs(private.TIMELINE_FRAME.frame.Ticks) do
            tick.frame:Hide()
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
    if not private.db.profile.timeline_frame[layoutName].ticks_enabled then
        private.db.profile.timeline_frame[layoutName].ticks_enabled = true
    end
    if not private.db.profile.timeline_frame[layoutName].width then
        private.db.profile.timeline_frame[layoutName].width = variables.width
    end
    if not private.db.profile.timeline_frame[layoutName].height then
        private.db.profile.timeline_frame[layoutName].height = variables.height
    end
    if private.TIMELINE_FRAME then
        private.TIMELINE_FRAME:ClearAllPoints()
        private.TIMELINE_FRAME:SetPoint(private.db.profile.timeline_frame[layoutName].point,
        private.db.profile.timeline_frame[layoutName].x, private.db.profile.timeline_frame[layoutName].y)
                HandleTickVisibility(layoutName)
        private.TIMELINE_FRAME.frame:SetWidth(private.db.profile.timeline_frame[layoutName].width)
        private.TIMELINE_FRAME.frame:SetHeight(private.db.profile.timeline_frame[layoutName].height)
    end
    private.ACTIVE_EDITMODE_LAYOUT = layoutName
end)

local function HandleTicks(self)
    for i = 1, #self.Ticks do
        self.Ticks[i].frame:Hide()
        self.Ticks[i]:Release()
    end
    for i, tick in ipairs(private.TIMELINE_TICKS) do
        local widget = AceGUI:Create("AtTimelineTicks")
        self.Ticks[i] = widget
        widget:SetTick(self, tick)
        widget.frame:Show()  
    end
end


local function Constructor()
    local count = AceGUI:GetNextWidgetNum(Type)
    local frame = CreateFrame("Frame", "AbilityTimelineFrame", UIParent, "BackdropTemplate")
    frame:SetWidth(variables.width)
    frame:SetHeight(variables.height)

    LibEditMode:AddFrame(frame, onPositionChanged, private.TimelineFrame.defaultPosition, "Ability Timeline")
    
    LibEditMode:AddFrameSettings(frame, {
        {
            name = 'Enable Ticks',
            kind = LibEditMode.SettingType.Checkbox,
            default = true,
            get = function(layoutName)
                return private.db.profile.timeline_frame[layoutName].ticks_enabled
            end,
            set = function(layoutName, value)
                private.db.profile.timeline_frame[layoutName].ticks_enabled = value
                HandleTickVisibility(layoutName)
            end,
        },
        {
            name = 'Width',
            kind = LibEditMode.SettingType.Slider,
            default = variables.width,
            get = function(layoutName)
                return private.db.profile.timeline_frame[layoutName].width
            end,
            set = function(layoutName, value)
                private.db.profile.timeline_frame[layoutName].width = value
            end,
        },
        {
            name = 'Height',
            kind = LibEditMode.SettingType.Slider,
            default = variables.height,
            get = function(layoutName)
                return private.db.profile.timeline_frame[layoutName].height
            end,
            set = function(layoutName, value)
                private.db.profile.timeline_frame[layoutName].height = value
            end,
        }
    })

    frame:SetFrameStrata("BACKGROUND")
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    frame:SetBackdropColor(0, 0, 0, 1)
    frame.Ticks = {}
    private.Debug(frame, "AT_TIMELINE_FRAME")
    HandleTicks(frame)
    frame:Hide()

    ---@class AtTimelineFrame : AceGUIWidget
    local widget = {
        OnAcquire = OnAcquire,
        OnRelease = OnRelease,
        type = Type,
        count = count,
        frame = frame,
        HandleTicks = HandleTicks,
        GetHeight = function(self)
            return self.frame:GetHeight()
        end,
    }

    return AceGUI:RegisterAsWidget(widget)
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)
