local appName, app = ...
---@class AbilityTimeline
local private = app
local AceGUI = LibStub("AceGUI-3.0")
local LibEditMode = LibStub("LibEditMode")
local Type = "AtTextHighlightFrame"
local Version = 1
local variables = {
    width = 300,
    height = 20,
    margin = 5,
    thresholdTime = 5,
}

private.TextHighlight = {}
private.TextHighlight.defaultPosition = {
    point = 'CENTER',
    x = 0,
    y = 0,
}

---@param self AtTextHighlightFrame
local function OnAcquire(self)
end

---@param self AtTextHighlightFrame
local function OnRelease(self)
end
local function onPositionChanged(frame, layoutName, point, x, y)
    -- from here you can save the position into a savedvariable
    private.db.global.text_highlight_frame[layoutName] = private.db.global.text_highlight_frame[layoutName] or {}
    private.db.global.text_highlight_frame[layoutName].x = x
    private.db.global.text_highlight_frame[layoutName].y = y
    private.db.global.text_highlight_frame[layoutName].point = point

    private.TEXT_HIGHLIGHT_FRAME:SetPoint(private.db.global.text_highlight_frame[layoutName].point,
        private.db.global.text_highlight_frame[layoutName].x, private.db.global.text_highlight_frame[layoutName].y)
end

private.TextHighlight.applyLayout = function(layoutName)
    -- this will be called every time the Edit Mode layout is changed (which also happens at login),
    -- use it to load the saved button position from savedvariables and position it
    if not private.db.global.text_highlight_frame then
        private.db.global.text_highlight_frame = {}
    end
    if not private.db.global.text_highlight_frame[layoutName] then
        private.db.global.text_highlight_frame[layoutName] = CopyTable(private.TextHighlight.defaultPosition)
    end
    if not private.db.global.text_highlight_enabled then
        private.db.global.text_highlight_enabled = {}
    end
    if private.db.global.text_highlight_enabled[layoutName] == nil then
        private.db.global.text_highlight_enabled[layoutName] = true
    end
    if not private.db.global.text_highlight then
        private.db.global.text_highlight = {}
    end
    if not private.db.global.text_highlight[layoutName] then
        private.db.global.text_highlight[layoutName] = {
            grow_direction = 'UP',
            margin = variables.margin,
        }
    end
    if not private.db.global.text_highlight[layoutName].threshold_time then
        private.db.global.text_highlight[layoutName].threshold_time = variables.thresholdTime
    end
    if not private.db.global.text_highlight[layoutName].margin then
        private.db.global.text_highlight[layoutName].margin = variables.margin
    end
    if not private.db.global.text_highlight[layoutName].limit then
        private.db.global.text_highlight[layoutName].limit = 0
    end
    if not private.db.global.text_highlight[layoutName].sort then
        private.db.global.text_highlight[layoutName].sort = private.DynamicGroup.SORT.ASCENDING
    end
    if private.evaluateTextPositions and layoutName == private.ACTIVE_EDITMODE_LAYOUT then
        private.evaluateTextPositions()
    end
    if private.TEXT_HIGHLIGHT_FRAME then
        private.TEXT_HIGHLIGHT_FRAME:ClearAllPoints()
        private.TEXT_HIGHLIGHT_FRAME:SetPoint(private.db.global.text_highlight_frame[layoutName].point,
            private.db.global.text_highlight_frame[layoutName].x, private.db.global.text_highlight_frame[layoutName].y)
    end
end

LibEditMode:RegisterCallback('layout', private.TextHighlight.applyLayout)

local function Constructor()
    local count = AceGUI:GetNextWidgetNum(Type)
    local frame = CreateFrame("Frame", "AbilityTimelineTextHighlightFrame", UIParent)
    frame:SetPoint("CENTER", UIParent, "CENTER")
    frame:SetWidth(variables.width)
    frame:SetHeight(variables.height)
    frame:Show()

    LibEditMode:AddFrame(frame, onPositionChanged, private.TextHighlight.defaultPosition,
        "|TInterface\\AddOns\\AbilityTimeline\\Media\\Textures\\logo_transparent.tga:32|t Better Ability Timeline Text Highlight")

    local settings = {
        {
            name = private.getLocalisation("EnableTextHighlight"),
            desc = private.getLocalisation("EnableTextHighlightDescription"),
            kind = LibEditMode.SettingType.Checkbox,
            default = true,
            get = function(layoutName)
                return private.db.global.text_highlight_enabled[layoutName]
            end,
            set = function(layoutName, value)
                private.db.global.text_highlight_enabled[layoutName] = value
            end,
        },
        {
            name = private.getLocalisation("TextHighlightThreshold"),
            desc = private.getLocalisation("TextHighlightThresholdDescription"),
            kind = LibEditMode.SettingType.Slider,
            default = variables.thresholdTime,
            get = function(layoutName)
                return private.db.global.text_highlight[layoutName].threshold_time
            end,
            set = function(layoutName, value)
                private.db.global.text_highlight[layoutName].threshold_time = value
            end,
            minValue = 1,
            maxValue = 30,
            valueStep = 1,
        },
    }
    -- grow, spacing, limit and sort are shared with all other dynamic groups, listed after the enable checkbox
    local groupSettings = private.DynamicGroup.BuildEditModeSettings(function(layoutName)
        return private.db.global.text_highlight[layoutName]
    end, function()
        private.evaluateTextPositions()
    end, {
        growValues = {
            private.DynamicGroup.GROW.UP,
            private.DynamicGroup.GROW.DOWN,
            private.DynamicGroup.GROW.VERTICAL,
        },
        growKey = "grow_direction",
        spacingKey = "margin",
        growDescription = private.getLocalisation("TextGrowDirectionDescription"),
        spacingName = private.getLocalisation("TextHighlightMargin"),
        spacingDescription = private.getLocalisation("TextHighlightMarginDescription"),
        defaults = {
            grow = private.DynamicGroup.GROW.UP,
            spacing = variables.margin,
        },
    })
    for i, setting in ipairs(groupSettings) do
        table.insert(settings, 1 + i, setting)
    end
    LibEditMode:AddFrameSettings(frame, settings)

    local buttons = {
        {
            text = private.getLocalisation("OpenTextEditor"),
            click = function() private.openHighlightTextSettings() end
        }
    }
    LibEditMode:AddFrameSettingsButtons(frame, buttons)

    ---@class AtTextHighlightFrame : AceGUIWidget
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
