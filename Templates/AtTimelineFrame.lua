local addonName, private = ...
local AceGUI = LibStub("AceGUI-3.0")
local LibEditMode = LibStub("LibEditMode")
local Type = "AtTimelineFrame"
local Version = 1
local variables = {
    width = 50,
    height = 500,
    inverse_travel_direction = false,
    ticks_enabled = true,
    position = {
        point = 'CENTER',
        x = 0,
        y = 0,
    }
}
private.TimelineFrame = {}

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
        private.db.profile.timeline_frame[layoutName] = CopyTable(variables.position)
    end
    if not private.db.profile.timeline_frame[layoutName].ticks_enabled then
        private.db.profile.timeline_frame[layoutName].ticks_enabled = variables.ticks_enabled
    end
    if not private.db.profile.timeline_frame[layoutName].width then
        private.db.profile.timeline_frame[layoutName].width = variables.width
    end
    if not private.db.profile.timeline_frame[layoutName].height then
        private.db.profile.timeline_frame[layoutName].height = variables.height
    end
    if not private.db.profile.timeline_frame[layoutName].inverse_travel_direction then
        private.db.profile.timeline_frame[layoutName].inverse_travel_direction = variables.inverse_travel_direction
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

local function HandleSizeChanges(self)
    local layoutName = private.ACTIVE_EDITMODE_LAYOUT
    local width = private.db.profile.timeline_frame[layoutName].width
    local height = private.db.profile.timeline_frame[layoutName].height
    self.frame:SetWidth(width)
    self.frame:SetHeight(height)
end


local function Constructor()
    local count = AceGUI:GetNextWidgetNum(Type)
    local frame = CreateFrame("Frame", "AbilityTimelineFrame", UIParent, "BackdropTemplate")
    frame:SetWidth(variables.width)
    frame:SetHeight(variables.height)

    LibEditMode:AddFrame(frame, onPositionChanged, variables.position, "Ability Timeline")
    
    LibEditMode:AddFrameSettings(frame, {
        {
            name = private.getLocalisation("EnableTicks"),
            desc = private.getLocalisation("EnableTicksDescription"),
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
            name = private.getLocalisation("InverseTravelDirection"),
            desc = private.getLocalisation("InverseTravelDirectionDescription"),
            kind = LibEditMode.SettingType.Checkbox,
            default = false,
            get = function(layoutName)
                return private.db.profile.timeline_frame[layoutName].inverse_travel_direction
            end,
            set = function(layoutName, value)
                private.db.profile.timeline_frame[layoutName].inverse_travel_direction = value
                HandleTickVisibility(layoutName)
            end,
        },
        {
            name = private.getLocalisation("TimelineWidth"),
            desc = private.getLocalisation("TimelineWidthDescription"),
            kind = LibEditMode.SettingType.Slider,
            default = variables.width,
            get = function(layoutName)
                return private.db.profile.timeline_frame[layoutName].width
            end,
            set = function(layoutName, value)
                private.db.profile.timeline_frame[layoutName].width = value
                HandleSizeChanges(private.TIMELINE_FRAME)
            end,
            minValue = 1,
            maxValue = 200,
            valueStep = 1,
        },
        {
            name = private.getLocalisation("TimelineHeight"),
            desc = private.getLocalisation("TimelineHeightDescription"),
            kind = LibEditMode.SettingType.Slider,
            default = variables.height,
            get = function(layoutName)
                return private.db.profile.timeline_frame[layoutName].height
            end,
            set = function(layoutName, value)
                private.db.profile.timeline_frame[layoutName].height = value
                HandleSizeChanges(private.TIMELINE_FRAME)
            end,
            minValue = 1,
            maxValue = 1000,
            valueStep = 1,
        },
        -- {
        --     name = 'Style',
        --     kind = LibEditMode.SettingType.Dropdown,
        
        --     get = function(layoutName)
        --         return private.db.profile.timeline_frame[layoutName].style
        --     end,
        --     set = function(layoutName, value)
        --         private.db.profile.timeline_frame[layoutName].style = value
        --     end,
        --     height = 500,
        --     values = {
        --         {
        --             text = 'Default',
        --             value = 'default',
        --         },
        --         {
        --             text = 'Compact',
        --             value = 'compact',
        --         },
        --         {
        --             text = 'Expanded',
        --             value = 'expanded',
        --         },
        --     },
        -- }
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
        HandleSizeChanges = HandleSizeChanges,
    }

    return AceGUI:RegisterAsWidget(widget)
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)
