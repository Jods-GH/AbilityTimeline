local addonName, private = ...
local AceGUI = LibStub("AceGUI-3.0")
local LibEditMode = LibStub("LibEditMode")
local Type = "AtBigIconFrame"
local Version = 1
local variables = {
    offset = {
        x = 30,
        y = -10,
    },
    width = 400,
    height =100,
}

local defaultPosition = {
    point = 'CENTER',
    x = 0,
    y = 0,
}

---@param self AtBigIconFrame
local function OnAcquire(self)
end

---@param self AtBigIconFrame
local function OnRelease(self)
end
local function onPositionChanged(frame, layoutName, point, x, y)
    -- from here you can save the position into a savedvariable
    private.db.profile.bigicon_frame[layoutName] = private.db.profile.bigicon_frame[layoutName] or {}
    private.db.profile.bigicon_frame[layoutName].x = x
    private.db.profile.bigicon_frame[layoutName].y = y
    private.db.profile.bigicon_frame[layoutName].point = point

    private.BIGICON_FRAME:SetPoint(private.db.profile.bigicon_frame[layoutName].point,
        private.db.profile.bigicon_frame[layoutName].x, private.db.profile.bigicon_frame[layoutName].y)
end

LibEditMode:RegisterCallback('layout', function(layoutName)
    -- this will be called every time the Edit Mode layout is changed (which also happens at login),
    -- use it to load the saved button position from savedvariables and position it
    if not private.db.profile.bigicon_frame then
        private.db.profile.bigicon_frame = {}
    end
    if not private.db.profile.bigicon_frame[layoutName] then
        private.db.profile.bigicon_frame[layoutName] = CopyTable(defaultPosition)
    end

    private.BIGICON_FRAME:ClearAllPoints()
    private.BIGICON_FRAME:SetPoint(private.db.profile.bigicon_frame[layoutName].point,
        private.db.profile.bigicon_frame[layoutName].x, private.db.profile.bigicon_frame[layoutName].y)
end)

local function Constructor()
    local count = AceGUI:GetNextWidgetNum(Type)
    local frame = CreateFrame("Frame", "AbilityTimelineBigIconFrame", UIParent)
    frame:SetWidth(variables.width)
    frame:SetHeight(variables.height)
    frame:Show()
    DevTool:AddData(frame, "AT_BIGICON_FRAME_BASE")

    LibEditMode:AddFrame(frame, onPositionChanged, defaultPosition, "Ability Timeline Big Icon")
    
    LibEditMode:AddFrameSettings(frame, {
        {
            name = 'Y Offset',
            kind = LibEditMode.SettingType.Slider,
            default = 1,
            get = function(layoutName)
                return 1
            end,
            set = function(layoutName, value)
                print(1)
            end,
            minValue = 1,
            maxValue = 1,
            valueStep = 1,
        }
    })

    ---@class AtBigIconFrame : AceGUIWidget
    local widget = {
        OnAcquire = OnAcquire,
        OnRelease = OnRelease,
        type = Type,
        count = count,
        frame = frame,
    }

    return AceGUI:RegisterAsWidget(widget)
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)
