local appName, app = ...
---@class AbilityTimeline
local private = app
local AceGUI = LibStub("AceGUI-3.0")
local LibEditMode = LibStub("LibEditMode")
local Type = "AtBigIconFrame"
local Version = 1
local variables = {
    offset = {
        x = 30,
        y = -10,
    },
    size = 100,
    margin = 10,
}
private.BigIcon = {}
private.BigIcon.defaultPosition = {
    point = 'CENTER',
    y = -200,
    x = 410,
}

---the size of big icons, stored per edit mode layout, the theme's while the layout has none
---@return number
private.GetBigIconSize = function()
    local layouts = private.db.global.bigicon
    local layout = layouts and private.ACTIVE_EDITMODE_LAYOUT and layouts[private.ACTIVE_EDITMODE_LAYOUT]
    return layout and layout.size or private.GetElementStyle("BigIcon").Size
end

---@param size number
private.SetBigIconSize = function(size)
    private.db.global.bigicon[private.ACTIVE_EDITMODE_LAYOUT].size = size
    private.RefreshTheme()
end

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

private.BigIcon.applyLayout = function(layoutName)
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
    if private.db.global.bigicon_enabled[layoutName] == nil then
        private.db.global.bigicon_enabled[layoutName] = true
    end
    if not private.db.global.bigicon then
        private.db.global.bigicon = {}
    end
    if not private.db.global.bigicon[layoutName] then
        private.db.global.bigicon[layoutName] = {
            grow_direction = 'RIGHT',
        }
    end
    if private.BIGICON_FRAME then
        private.BIGICON_FRAME:ClearAllPoints()
        private.BIGICON_FRAME:SetPoint(private.db.global.bigicon_frame[layoutName].point,
            private.db.global.bigicon_frame[layoutName].x, private.db.global.bigicon_frame[layoutName].y)
    end
    if not private.db.global.bigicon then
        private.db.global.bigicon = {}
    end

    if not private.db.global.bigicon[private.ACTIVE_EDITMODE_LAYOUT] then
        private.db.global.bigicon[private.ACTIVE_EDITMODE_LAYOUT] = {}
    end

    if not private.db.global.bigicon[private.ACTIVE_EDITMODE_LAYOUT].margin then
        private.db.global.bigicon[private.ACTIVE_EDITMODE_LAYOUT].margin = variables.margin
    end

    if layoutName == private.ACTIVE_EDITMODE_LAYOUT then
        -- the layout can have another big icon size
        private.RefreshTheme()
        if private.evaluateBigIconPositions then
            private.evaluateBigIconPositions()
        end
    end
end

LibEditMode:RegisterCallback('layout', private.BigIcon.applyLayout)

local function Constructor()
    local count = AceGUI:GetNextWidgetNum(Type)
    local frame = CreateFrame("Frame", "AbilityTimelineBigIconFrame", UIParent)
    local size = private.db and private.GetBigIconSize() or variables.size
    frame:SetWidth(size)
    frame:SetHeight(size)
    frame:Show()
    private.Debug(frame, "AT_BIGICON_FRAME_BASE")

    LibEditMode:AddFrame(frame, onPositionChanged, private.BigIcon.defaultPosition,
        "|TInterface\\AddOns\\AbilityTimeline\\Media\\Textures\\logo_transparent.png:32|t Better Timeline Big Icon")
    local settings = {
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
        },
        {
            name = private.getLocalisation("IconSize"),
            desc = private.getLocalisation("IconSizeDescription"),
            kind = LibEditMode.SettingType.Slider,
            default = variables.size,
            get = function(layoutName)
                return private.db.global.bigicon[layoutName].size or private.GetElementStyle("BigIcon").Size
            end,
            set = function(layoutName, value)
                private.db.global.bigicon[layoutName].size = value
                if layoutName == private.ACTIVE_EDITMODE_LAYOUT then
                    private.RefreshTheme()
                end
            end,
            minValue = 1,
            maxValue = 150,
            valueStep = 1,
        },
    }
    -- grow and spacing are shared with all other dynamic groups, listed after the enable checkbox
    local groupSettings = private.DynamicGroup.BuildEditModeSettings(function(layoutName)
        return private.db.global.bigicon[layoutName]
    end, function()
        private.evaluateBigIconPositions()
    end, {
        growValues = {
            private.DynamicGroup.GROW.RIGHT,
            private.DynamicGroup.GROW.LEFT,
            private.DynamicGroup.GROW.UP,
            private.DynamicGroup.GROW.DOWN,
            private.DynamicGroup.GROW.HORIZONTAL,
            private.DynamicGroup.GROW.VERTICAL,
        },
        growKey = "grow_direction",
        spacingKey = "margin",
        spacingName = private.getLocalisation("BigIconMargin"),
        spacingDescription = private.getLocalisation("BigIconMarginDescription"),
        defaults = {
            grow = private.DynamicGroup.GROW.RIGHT,
            spacing = variables.margin,
        },
    })
    for i, setting in ipairs(groupSettings) do
        table.insert(settings, 1 + i, setting)
    end
    LibEditMode:AddFrameSettings(frame, settings)

    local buttons = {
        {
            text = private.getLocalisation("SettingsOpenPage"),
            click = function() private.openSettings("BigIcon") end
        }
    }
    LibEditMode:AddFrameSettingsButtons(frame, buttons)

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
