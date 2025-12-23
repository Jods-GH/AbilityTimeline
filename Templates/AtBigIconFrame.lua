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
private.BigIcon = {}
private.BigIcon.defaultPosition = {
    point = 'RIGHT',
    y = -200,
    x = -280,
}

---@param self AtBigIconFrame
local function OnAcquire(self)
end

---@param self AtBigIconFrame
local function OnRelease(self)
end
local function onPositionChanged(frame, layoutName, point, x, y)
    -- from here you can save the position into a savedvariable
    private.db.global.bigicon_frame[layoutName] = private.db.global.bigicon_frame[layoutName] or {}
    private.db.global.bigicon_frame[layoutName].x = x
    private.db.global.bigicon_frame[layoutName].y = y
    private.db.global.bigicon_frame[layoutName].point = point

    private.BIGICON_FRAME:SetPoint(private.db.global.bigicon_frame[layoutName].point,
        private.db.global.bigicon_frame[layoutName].x, private.db.global.bigicon_frame[layoutName].y)
end

LibEditMode:RegisterCallback('layout', function(layoutName)
    -- this will be called every time the Edit Mode layout is changed (which also happens at login),
    -- use it to load the saved button position from savedvariables and position it
    if not private.db.global.bigicon_frame then
        private.db.global.bigicon_frame = {}
    end
    if not private.db.global.bigicon_frame[layoutName] then
        private.db.global.bigicon_frame[layoutName] = CopyTable(private.BigIcon.defaultPosition)
    end
     if not private.db.global.bigicon_enabled then
        private.db.global.bigicon_enabled = {}
    end
    if not private.db.global.bigicon_enabled[layoutName] then
        private.db.global.bigicon_enabled[layoutName] = true
    end
    if private.BIGICON_FRAME then
        private.BIGICON_FRAME:ClearAllPoints()
        private.BIGICON_FRAME:SetPoint(private.db.global.bigicon_frame[layoutName].point,
            private.db.global.bigicon_frame[layoutName].x, private.db.global.bigicon_frame[layoutName].y)
    end
end)

local function Constructor()
    local count = AceGUI:GetNextWidgetNum(Type)
    local frame = CreateFrame("Frame", "AbilityTimelineBigIconFrame", UIParent)
    frame:SetWidth(variables.width)
    frame:SetHeight(variables.height)
    frame:Show()
    private.Debug(frame, "AT_BIGICON_FRAME_BASE")

    LibEditMode:AddFrame(frame, onPositionChanged, private.BigIcon.defaultPosition, "Ability Timeline Big Icon")
    LibEditMode:AddFrameSettings(frame, {
        {
            name = private.getLocalisation("EnableBigIcon"),
            desc = private.getLocalisation("EnableBigIconDescription"),
            kind = LibEditMode.SettingType.Checkbox,
            default = true,
            get = function(layoutName)
                return private.db.global.bigicon_enabled[layoutName]
            end,
            set = function(layoutName, value)
                private.db.global.bigicon_enabled[layoutName] = value
            end,
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
