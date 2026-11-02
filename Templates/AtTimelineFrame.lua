local appName, app = ...
---@class AbilityTimeline
local private = app
local AceGUI                = LibStub("AceGUI-3.0")
local LibEditMode           = LibStub("LibEditMode")
local SharedMedia           = LibStub("LibSharedMedia-3.0")
local Type                  = "AtTimelineFrame"
local Version               = 1
local variables             = {
    otherSize = 50,
    travelSize = 500,
    inverse_travel_direction = false,
    ticks_enabled = true,
    timelineTexture = "Blizzard Dialog Background",
    position = {
        point = 'CENTER',
        y = 110,
        x = 410,
    },
    timelineTextureColor = CreateColor(1, 1, 1, 1),
    timelineBorder = "None",
    timelineBorderColor = CreateColor(1, 1, 1, 1),
    timelineBorderSize = 2,
    IconMargin = 5,
    thresholdTime = 10,
    preventOverlap = true,
    mergeTimers = true,
    mergeWindow = 0.2,
    tickInterval = 5,
    minTickDistance = 40,
}
private.TIMELINE_DIRECTIONS = {
    VERTICAL = "VERTICAL",
    HORIZONTAL = "HORIZONTAL"
}
private.TimelineFrame       = {}

---@param self AtTimelineFrame
local function OnAcquire(self)
end

---@param self AtTimelineFrame
local function OnRelease(self)
end
local function onPositionChanged(frame, layoutName, point, x, y)
    -- from here you can save the position into a savedvariable
    private.db.global.timeline_frame[layoutName] = private.db.global.timeline_frame[layoutName] or {}
    private.db.global.timeline_frame[layoutName].x = x
    private.db.global.timeline_frame[layoutName].y = y
    private.db.global.timeline_frame[layoutName].point = point

    private.TIMELINE_FRAME:SetPoint(private.db.global.timeline_frame[layoutName].point,
        private.db.global.timeline_frame[layoutName].x, private.db.global.timeline_frame[layoutName].y)
end

local function HandleTickVisibility(layoutName)
    for _, tick in ipairs(private.TIMELINE_FRAME.frame.Ticks) do
        if private.db.global.timeline_frame[layoutName].ticks_enabled then
            tick:SetTick(private.TIMELINE_FRAME.frame, tick.tick, private.TIMELINE_FRAME:GetMoveSize(),
                private.db.global.timeline_frame[private.ACTIVE_EDITMODE_LAYOUT].threshold_time,
                private.db.global.timeline_frame[private.ACTIVE_EDITMODE_LAYOUT].travel_direction ==
                private.TIMELINE_DIRECTIONS.HORIZONTAL)
            tick.frame:Show()
        else
            tick.frame:Hide()
        end
    end
end

local function SetFrameSize(self, width, height)
    self:SetWidth(width)
    self:SetHeight(height)
end

private.ModernizeTimelineFrame = function(layoutName)
     if not private.db.global.timeline_frame then
        private.db.global.timeline_frame = {}
    end
    if not private.db.global.timeline_frame[layoutName].point then
        private.db.global.timeline_frame[layoutName].point = variables.position.point
    end
    if not private.db.global.timeline_frame[layoutName].x then
        private.db.global.timeline_frame[layoutName].x = variables.position.x
    end
    if not private.db.global.timeline_frame[layoutName].y then
        private.db.global.timeline_frame[layoutName].y = variables.position.y
    end
    if private.db.global.timeline_frame[layoutName].enabled == nil then
        private.db.global.timeline_frame[layoutName].enabled = true
    end
    if private.db.global.timeline_frame[layoutName].ticks_enabled == nil then
        private.db.global.timeline_frame[layoutName].ticks_enabled = variables.ticks_enabled
    end
    if not private.db.global.timeline_frame[layoutName].otherSize then
        private.db.global.timeline_frame[layoutName].otherSize = variables.otherSize
    end
    if not private.db.global.timeline_frame[layoutName].travelSize then
        private.db.global.timeline_frame[layoutName].travelSize = variables.travelSize
    end
    if not private.db.global.timeline_frame[layoutName].inverse_travel_direction then
        private.db.global.timeline_frame[layoutName].inverse_travel_direction = variables.inverse_travel_direction
    end
    if not private.db.global.timeline_frame[layoutName].horizontal then
        private.db.global.timeline_frame[layoutName].horizontal = false
    end
    if not private.db.global.timeline_frame[layoutName].iconMargin then
        private.db.global.timeline_frame[layoutName].iconMargin = variables.IconMargin
    end

    if not private.db.global.timeline_frame[layoutName].threshold_time then
        private.db.global.timeline_frame[layoutName].threshold_time = variables.thresholdTime
    end

    if private.db.global.timeline_frame[layoutName].prevent_overlap == nil then
        private.db.global.timeline_frame[layoutName].prevent_overlap = variables.preventOverlap
    end

    if private.db.global.timeline_frame[layoutName].merge_timers == nil then
        private.db.global.timeline_frame[layoutName].merge_timers = variables.mergeTimers
    end

    if not private.db.global.timeline_frame[layoutName].merge_window then
        private.db.global.timeline_frame[layoutName].merge_window = variables.mergeWindow
    end
end

private.TimelineFrame.applyLayout = function(layoutName)
    -- this will be called every time the Edit Mode layout is changed (which also happens at login),
    -- use it to load the saved button position from savedvariables and position it
   private.ModernizeTimelineFrame(layoutName)


    if private.TIMELINE_FRAME then
        private.TIMELINE_FRAME:ClearAllPoints()
        private.TIMELINE_FRAME:SetPoint(private.db.global.timeline_frame[layoutName].point,
            private.db.global.timeline_frame[layoutName].x, private.db.global.timeline_frame[layoutName].y)
        local width, height
        if private.db.global.timeline_frame[layoutName].travel_direction == private.TIMELINE_DIRECTIONS.HORIZONTAL then
            width = private.db.global.timeline_frame[layoutName].travelSize
            height = private.db.global.timeline_frame[layoutName].otherSize
        else
            width = private.db.global.timeline_frame[layoutName].otherSize
            height = private.db.global.timeline_frame[layoutName].travelSize
        end
        SetFrameSize(private.TIMELINE_FRAME, width, height)
        private.TIMELINE_FRAME:HandleTicks()
        HandleTickVisibility(layoutName)
        private.TIMELINE_FRAME:ApplySettings()
        if private.refreshTimelineGroups then
            private.refreshTimelineGroups()
        end
    end
end

LibEditMode:RegisterCallback('layout', private.TimelineFrame.applyLayout)


local function HandleTicks(self)
    for i = 1, #self.frame.Ticks do
        self.frame.Ticks[i].frame:Hide()
        self.frame.Ticks[i]:Release()
    end
    self.frame.Ticks = {}
    local thresholdTime = private.db.global.timeline_frame[private.ACTIVE_EDITMODE_LAYOUT].threshold_time
    local minTickTime = variables.minTickDistance * thresholdTime / self:GetMoveSize()
    local step = variables.tickInterval * math.max(math.ceil(minTickTime / variables.tickInterval), 1)
    private.TIMELINE_TICKS = {}
    for tick = step, thresholdTime - 1, step do
        table.insert(private.TIMELINE_TICKS, tick)
    end
    for i, tick in ipairs(private.TIMELINE_TICKS) do
        local widget = AceGUI:Create("AtTimelineTicks")
        self.frame.Ticks[i] = widget
        widget:SetTick(self.frame, tick, self:GetMoveSize(),
            private.db.global.timeline_frame[private.ACTIVE_EDITMODE_LAYOUT].threshold_time,
            private.db.global.timeline_frame[private.ACTIVE_EDITMODE_LAYOUT].travel_direction ==
            private.TIMELINE_DIRECTIONS.HORIZONTAL)
        widget.frame:Show()
    end
end
local function HandleSizeChanges(self)
    local layoutName = private.ACTIVE_EDITMODE_LAYOUT
    local width, height
    if private.db.global.timeline_frame[layoutName].travel_direction == private.TIMELINE_DIRECTIONS.HORIZONTAL then
        width = private.db.global.timeline_frame[layoutName].travelSize
        height = private.db.global.timeline_frame[layoutName].otherSize
    else
        width = private.db.global.timeline_frame[layoutName].otherSize
        height = private.db.global.timeline_frame[layoutName].travelSize
    end
    SetFrameSize(self, width, height)
end

---@param self AtTimelineFrame
---the end of the timeline icons arrive at
---@return string point
---@return boolean isHorizontal
local function GetArrivalPoint()
    local layout = private.ACTIVE_EDITMODE_LAYOUT and private.db.global.timeline_frame[private.ACTIVE_EDITMODE_LAYOUT]
    local isHorizontal = layout and layout.travel_direction == private.TIMELINE_DIRECTIONS.HORIZONTAL or false
    local inverse = layout and layout.inverse_travel_direction
    if isHorizontal then
        return inverse and "RIGHT" or "LEFT", true
    end
    return inverse and "TOP" or "BOTTOM", false
end

---a wash of color that fades from the arrival point to the far end
---@param frame Frame
---@param wash table|nil
---@param arrival string
---@param isHorizontal boolean
local function ApplyWash(frame, wash, arrival, isHorizontal)
    if not wash then
        frame.Wash:Hide()
        return
    end
    local r, g, b, a = private.ThemeApply.Color(wash.Color, wash.Alpha)
    local strong, faint = CreateColor(r, g, b, a), CreateColor(r, g, b, 0)
    -- the gradient's minimum is the bottom or left end
    local atMinimum = arrival == "BOTTOM" or arrival == "LEFT"
    frame.Wash:SetGradient(isHorizontal and "HORIZONTAL" or "VERTICAL", atMinimum and strong or faint,
        atMinimum and faint or strong)
    frame.Wash:Show()
end

---lays the flow's texture along the timeline, tiled once per its width and shifted by its offset, the texture's
---downwards pointing at the end icons arrive at
---@param frame Frame
local function UpdateFlowCoords(frame)
    if not frame.flow then return end
    local along, across = frame:GetHeight(), frame:GetWidth()
    if frame.isHorizontal then
        along, across = across, along
    end
    local near = frame.flowOffset
    local far = near + along / math.max(across, 1)
    local arrival = frame.arrival
    if arrival == "BOTTOM" then
        frame.Flow:SetTexCoord(0, near, 0, far, 1, near, 1, far)
    elseif arrival == "TOP" then
        frame.Flow:SetTexCoord(0, far, 0, near, 1, far, 1, near)
    elseif arrival == "LEFT" then
        frame.Flow:SetTexCoord(0, far, 1, far, 0, near, 1, near)
    else
        frame.Flow:SetTexCoord(0, near, 1, near, 0, far, 1, far)
    end
end

---moves the flow Speed pixels a second towards the end icons arrive at, away from it while Speed is negative
---@param driver Frame
---@param elapsed number
local function StepFlow(driver, elapsed)
    local frame = driver:GetParent()
    local across = frame.isHorizontal and frame:GetHeight() or frame:GetWidth()
    frame.flowOffset = (frame.flowOffset - frame.flow.Speed * elapsed / math.max(across, 1)) % 1
    UpdateFlowCoords(frame)
end

---a texture streaming along the timeline, brightest at the end icons arrive at
---@param frame Frame
---@param flow table|nil
---@param arrival string
---@param isHorizontal boolean
local function ApplyFlow(frame, flow, arrival, isHorizontal)
    frame.flow = flow
    frame.FlowDriver:SetScript("OnUpdate", nil)
    if not flow then
        frame.Flow:Hide()
        return
    end
    frame.Flow:SetTexture(private.ThemeApply.File(flow.File), "REPEAT", "REPEAT")
    frame.Flow:SetBlendMode(flow.BlendMode or "BLEND")
    local r, g, b, a = private.ThemeApply.Color(flow.Color, flow.Alpha)
    local strong, faint = CreateColor(r, g, b, a), CreateColor(r, g, b, a * (flow.Far or 1))
    local atMinimum = arrival == "BOTTOM" or arrival == "LEFT"
    frame.Flow:SetGradient(isHorizontal and "HORIZONTAL" or "VERTICAL", atMinimum and strong or faint,
        atMinimum and faint or strong)
    frame.flowOffset = frame.flowOffset or 0
    frame.Flow:Show()
    UpdateFlowCoords(frame)
    if flow.Speed and private.AmbientEffectsEnabled() then
        frame.FlowDriver:SetScript("OnUpdate", StepFlow)
    end
end

---@param self AtTimelineFrame
local function ApplySettings(self)
    local frame = self.frame
    local style = private.GetElementStyle("Timeline")
    private.ThemeApply.Backdrop(frame, style.Backdrop)
    frame.Background:SetShown(private.ThemeApply.Texture(frame.Background, style.Background))
    frame.Edge:SetShown(private.ThemeApply.Texture(frame.Edge, style.Edge))
    local arrival, isHorizontal = GetArrivalPoint()
    ApplyWash(frame, style.Wash, arrival, isHorizontal)
    frame.NowPulse:Stop()
    frame.Now:SetShown(private.ThemeApply.Texture(frame.Now, style.Now))
    if style.Now then
        frame.Now:ClearAllPoints()
        frame.Now:SetPoint("CENTER", frame, arrival)
        frame.Now:SetSize(style.Now.Size, style.Now.Size)
        -- the glow breathes slowly, a looping animation the client runs without any Lua
        if style.Now.Pulse and private.AmbientEffectsEnabled() then
            frame.NowPulse:Play()
        end
    end
    frame.arrival, frame.isHorizontal = arrival, isHorizontal
    ApplyFlow(frame, style.Flow, arrival, isHorizontal)
    frame.Sparkles:Start(style.Sparkles)
end

---@param path string
---@return colorRGBA
local function getStyleColor(path)
    return CreateColor(private.ThemeApply.Color(private.GetThemeValue(path)))
end

---@param path string
---@param color colorRGBA
local function setStyleColor(path, color)
    private.SetThemeModification(path, { r = color.r, g = color.g, b = color.b, a = color.a })
end


local function GetMoveSize(self)
    if private.db.global.timeline_frame[private.ACTIVE_EDITMODE_LAYOUT].travel_direction == private.TIMELINE_DIRECTIONS.HORIZONTAL then
        return self.frame:GetWidth()
    end
    return self.frame:GetHeight()
end

local function SetupEditModeSettings(frame)
    LibEditMode:AddFrame(frame, onPositionChanged, variables.position,
        "|TInterface\\AddOns\\AbilityTimeline\\Media\\Textures\\logo_transparent.tga:32|t Better Ability Timeline")

    local areTravelSettingsExpanded = false
    local areVisualSettingsExpanded = false
    local settings = {
        {
            name = private.getLocalisation("EnableTimeline"),
            desc = private.getLocalisation("EnableTimelineDescription"),
            kind = LibEditMode.SettingType.Checkbox,
            default = true,
            get = function(layoutName)
                return private.db.global.timeline_frame[layoutName].enabled
            end,
            set = function(layoutName, value)
                private.db.global.timeline_frame[layoutName].enabled = value
            end,
        },
        {
            name = private.getLocalisation("ExpandTravelSettings"),
            expandedLabel = private.getLocalisation("CollapseTravelSettings"),
            collapsedLabel = private.getLocalisation("ExpandTravelSettings"),
            desc = private.getLocalisation("TravelSettingsDescription"),
            kind = LibEditMode.SettingType.Expander,
            default = areTravelSettingsExpanded,
            get = function()
                return areTravelSettingsExpanded
            end,
            set = function(_, value)
                areTravelSettingsExpanded = value
            end,
        },
        {
            name = private.getLocalisation("InverseTravelDirection"),
            desc = private.getLocalisation("InverseTravelDirectionDescription"),
            kind = LibEditMode.SettingType.Checkbox,
            default = false,
            get = function(layoutName)
                return private.db.global.timeline_frame[layoutName].inverse_travel_direction
            end,
            set = function(layoutName, value)
                private.db.global.timeline_frame[layoutName].inverse_travel_direction = value
                HandleTickVisibility(layoutName)
                private.refreshTimelineGroups()
                private.TIMELINE_FRAME:ApplySettings()
            end,
            hidden = function()
                return not areTravelSettingsExpanded
            end,
        },
        {
            name = private.getLocalisation("TravelDirection"),
            desc = private.getLocalisation("TravelDirectionDescription"),
            kind = LibEditMode.SettingType.Dropdown,

            get = function(layoutName)
                return private.db.global.timeline_frame[layoutName].travel_direction
            end,
            set = function(layoutName, value)
                private.db.global.timeline_frame[layoutName].travel_direction = value
                HandleSizeChanges(private.TIMELINE_FRAME)
                HandleTickVisibility(layoutName)
                private.refreshTimelineGroups()
                private.TIMELINE_FRAME:ApplySettings()
            end,
            default = private.TIMELINE_DIRECTIONS.VERTICAL,
            height = 100,
            values = {
                {
                    text = private.getLocalisation("TravelDirectionVertical"),
                    value = private.TIMELINE_DIRECTIONS.VERTICAL,
                    isRadio = true,
                },
                {
                    text = private.getLocalisation("TravelDirectionHorizontal"),
                    value = private.TIMELINE_DIRECTIONS.HORIZONTAL,
                    isRadio = true,
                },
            },
            hidden = function()
                return not areTravelSettingsExpanded
            end,
        },
        {
            name = private.getLocalisation("TimelineWindow"),
            desc = private.getLocalisation("TimelineWindowDescription"),
            kind = LibEditMode.SettingType.Slider,
            default = variables.thresholdTime,
            get = function(layoutName)
                return private.db.global.timeline_frame[layoutName].threshold_time
            end,
            set = function(layoutName, value)
                private.db.global.timeline_frame[layoutName].threshold_time = value
                HandleTicks(private.TIMELINE_FRAME)
                HandleTickVisibility(layoutName)
            end,
            minValue = 5,
            maxValue = 60,
            valueStep = 1,
            hidden = function()
                return not areTravelSettingsExpanded
            end,
        },
        {
            name = private.getLocalisation("PreventOverlap"),
            desc = private.getLocalisation("PreventOverlapDescription"),
            kind = LibEditMode.SettingType.Checkbox,
            default = variables.preventOverlap,
            get = function(layoutName)
                return private.db.global.timeline_frame[layoutName].prevent_overlap
            end,
            set = function(layoutName, value)
                private.db.global.timeline_frame[layoutName].prevent_overlap = value
            end,
            hidden = function()
                return not areTravelSettingsExpanded
            end,
        },
        {
            name = private.getLocalisation("MergeTimers"),
            desc = private.getLocalisation("MergeTimersDescription"),
            kind = LibEditMode.SettingType.Checkbox,
            default = variables.mergeTimers,
            get = function(layoutName)
                return private.db.global.timeline_frame[layoutName].merge_timers
            end,
            set = function(layoutName, value)
                private.db.global.timeline_frame[layoutName].merge_timers = value
            end,
            hidden = function()
                return not areTravelSettingsExpanded
            end,
        },
        {
            name = private.getLocalisation("MergeWindow"),
            desc = private.getLocalisation("MergeWindowDescription"),
            kind = LibEditMode.SettingType.Slider,
            default = variables.mergeWindow,
            get = function(layoutName)
                return private.db.global.timeline_frame[layoutName].merge_window
            end,
            set = function(layoutName, value)
                private.db.global.timeline_frame[layoutName].merge_window = value
            end,
            minValue = 0,
            maxValue = 2,
            valueStep = 0.1,
            formatter = function(value)
                return string.format("%.1f", value)
            end,
            hidden = function(layoutName)
                return not areTravelSettingsExpanded or not private.db.global.timeline_frame[layoutName].merge_timers
            end,
        },
        {
            name = private.getLocalisation("ExpandVisualSettings"),
            expandedLabel = private.getLocalisation("CollapseVisualSettings"),
            collapsedLabel = private.getLocalisation("ExpandVisualSettings"),
            desc = private.getLocalisation("VisualSettingsDescription"),
            kind = LibEditMode.SettingType.Expander,
            default = areVisualSettingsExpanded,
            get = function()
                return areVisualSettingsExpanded
            end,
            set = function(_, value)
                areVisualSettingsExpanded = value
            end,
        },
        {
            name = private.getLocalisation("EnableTicks"),
            desc = private.getLocalisation("EnableTicksDescription"),
            kind = LibEditMode.SettingType.Checkbox,
            default = true,
            get = function(layoutName)
                return private.db.global.timeline_frame[layoutName].ticks_enabled
            end,
            set = function(layoutName, value)
                private.db.global.timeline_frame[layoutName].ticks_enabled = value
                HandleTickVisibility(layoutName)
            end,
             hidden = function()
                return not areVisualSettingsExpanded
            end,
        },
        {
            name = private.getLocalisation("TimelineTexture"),
            desc = private.getLocalisation("TimelineTextureDescription"),
            kind = LibEditMode.SettingType.Dropdown,

            get = function()
                return private.GetThemeValue("Elements.Timeline.Backdrop.Background")
            end,
            set = function(_, value)
                private.SetThemeModification("Elements.Timeline.Backdrop.Background", value)
            end,
            default = variables.timelineTexture,
            height = 300,
            values = function()
                local Textures = {}
                for _, texName in ipairs(SharedMedia:List("background")) do
                    local texPath = SharedMedia:Fetch("background", texName) or ""
                    local display = ("|T%s:16:128|t %s"):format(tostring(texPath), texName)
                    table.insert(Textures, {
                        text = display,
                        value = texName,
                        isRadio = false,
                    })
                end
                return Textures
            end,
            hidden = function()
                return not areVisualSettingsExpanded
            end,
        },
        {
            name = private.getLocalisation("TimelineTextureColor"),
            desc = private.getLocalisation("TimelineTextureColorDescription"),
            kind = LibEditMode.SettingType.ColorPicker,
            hasOpacity = true,
            get = function()
                return getStyleColor("Elements.Timeline.Backdrop.Color")
            end,
            set = function(_, value)
                setStyleColor("Elements.Timeline.Backdrop.Color", value)
            end,
            default = variables.timelineTextureColor,
            hidden = function()
                return not areVisualSettingsExpanded
            end,
        },
        {
            name = private.getLocalisation("TimelineBorder"),
            desc = private.getLocalisation("TimelineBorderDescription"),
            kind = LibEditMode.SettingType.Dropdown,

            get = function()
                return private.GetThemeValue("Elements.Timeline.Backdrop.Border")
            end,
            set = function(_, value)
                private.SetThemeModification("Elements.Timeline.Backdrop.Border", value)
            end,
            default = variables.timelineBorder,
            height = 300,
            values = function()
                local Borders = {}
                for _, borderName in ipairs(SharedMedia:List("border")) do
                    local borderPath = SharedMedia:Fetch("border", borderName) or ""
                    local display = borderPath ~= "" and ("|T%s:16:128|t %s"):format(tostring(borderPath), borderName) or borderName
                    table.insert(Borders, {
                        text = display,
                        value = borderName,
                        isRadio = false,
                    })
                end
                return Borders
            end,
            hidden = function()
                return not areVisualSettingsExpanded
            end,
        },
        {
            name = private.getLocalisation("TimelineBorderColor"),
            desc = private.getLocalisation("TimelineBorderColorDescription"),
            kind = LibEditMode.SettingType.ColorPicker,
            hasOpacity = true,
            get = function()
                return getStyleColor("Elements.Timeline.Backdrop.BorderColor")
            end,
            set = function(_, value)
                setStyleColor("Elements.Timeline.Backdrop.BorderColor", value)
            end,
            default = variables.timelineBorderColor,
            hidden = function()
                return not areVisualSettingsExpanded
            end,
        },
        {
            name = private.getLocalisation("TimelineBorderSize"),
            desc = private.getLocalisation("TimelineBorderSizeDescription"),
            kind = LibEditMode.SettingType.Slider,
            default = variables.timelineBorderSize,
            get = function()
                return private.GetThemeValue("Elements.Timeline.Backdrop.EdgeSize")
            end,
            set = function(_, value)
                private.SetThemeModification("Elements.Timeline.Backdrop.EdgeSize", value)
            end,
            minValue = 1,
            maxValue = 32,
            valueStep = 1,
            hidden = function()
                return not areVisualSettingsExpanded
            end,
        },
        {
            name = private.getLocalisation("TimelineOtherSize"),
            desc = private.getLocalisation("TimelineOtherSizeDescription"),
            kind = LibEditMode.SettingType.Slider,
            default = variables.otherSize,
            get = function(layoutName)
                return private.db.global.timeline_frame[layoutName].otherSize
            end,
            set = function(layoutName, value)
                private.db.global.timeline_frame[layoutName].otherSize = value
                HandleSizeChanges(private.TIMELINE_FRAME)
                HandleTicks(private.TIMELINE_FRAME)
                HandleTickVisibility(layoutName)
            end,
            minValue = 1,
            maxValue = 200,
            valueStep = 1,
            hidden = function()
                return not areVisualSettingsExpanded
            end,
        },
        {
            name = private.getLocalisation("TimelineTravelSize"),
            desc = private.getLocalisation("TimelineTravelSizeDescription"),
            kind = LibEditMode.SettingType.Slider,
            default = variables.travelSize,
            get = function(layoutName)
                return private.db.global.timeline_frame[layoutName].travelSize
            end,
            set = function(layoutName, value)
                private.db.global.timeline_frame[layoutName].travelSize = value
                HandleSizeChanges(private.TIMELINE_FRAME)
                HandleTicks(private.TIMELINE_FRAME)
                HandleTickVisibility(layoutName)
            end,
            minValue = 1,
            maxValue = 1000,
            valueStep = 1,
            hidden = function()
                return not areVisualSettingsExpanded
            end,
        },
        {
            name = private.getLocalisation("IconMargin"),
            desc = private.getLocalisation("IconMarginDescription"),
            kind = LibEditMode.SettingType.Slider,
            default = variables.IconMargin,
            get = function(layoutName)
                return private.db.global.timeline_frame[layoutName].iconMargin
            end,
            set = function(layoutName, value)
                private.db.global.timeline_frame[layoutName].iconMargin = value
                private.refreshTimelineGroups()
            end,
            minValue = 0,
            maxValue = 50,
            valueStep = 1,
            hidden = function()
                return not areVisualSettingsExpanded
            end,
        },
        {
            name = COMBAT_WARNINGS_HIDE_QUEUED_COUNTDOWNS_LABEL,
            desc = COMBAT_WARNINGS_HIDE_QUEUED_COUNTDOWNS_TOOLTIP,
            kind = LibEditMode.SettingType.Checkbox,
            default = false,
            get = function(layoutName)
                return C_CVar.GetCVar("encounterTimelineHideQueuedCountdowns") == "1" and true or false
            end,
            set = function(layoutName, value)
                C_CVar.SetCVar("encounterTimelineHideQueuedCountdowns", value and "1" or "0")
            end,
            hidden = function()
                return not private.isRetail
            end,
        },
        -- {
        --     name = 'Style',
        --     kind = LibEditMode.SettingType.Dropdown,

        --     get = function(layoutName)
        --         return private.db.global.timeline_frame[layoutName].style
        --     end,
        --     set = function(layoutName, value)
        --         private.db.global.timeline_frame[layoutName].style = value
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
    }
    LibEditMode:AddFrameSettings(frame, settings)

    local buttons = {
        {
            text = private.getLocalisation("OpenIconEditor"),
            click = function() private.openSpellIconSettings() end
        }
    }
    LibEditMode:AddFrameSettingsButtons(frame, buttons)
end


local function Constructor()
    local count = AceGUI:GetNextWidgetNum(Type)
    local frame = CreateFrame("Frame", "AbilityTimelineFrame", UIParent, "BackdropTemplate")
    frame:SetWidth(variables.otherSize)
    frame:SetHeight(variables.travelSize)

    frame:SetFrameStrata("BACKGROUND")
    frame.Background = frame:CreateTexture(nil, "BACKGROUND")
    frame.Background:SetAllPoints(frame)
    frame.Edge = frame:CreateTexture(nil, "BORDER")
    frame.Edge:SetAllPoints(frame)
    frame.Wash = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
    frame.Wash:SetTexture("Interface\\Buttons\\WHITE8X8")
    frame.Wash:SetPoint("TOPLEFT", 1, -1)
    frame.Wash:SetPoint("BOTTOMRIGHT", -1, 1)
    frame.Flow = frame:CreateTexture(nil, "BACKGROUND", nil, 2)
    frame.Flow:SetPoint("TOPLEFT", 2, -2)
    frame.Flow:SetPoint("BOTTOMRIGHT", -2, 2)
    frame.Flow:Hide()
    frame.FlowDriver = CreateFrame("Frame", nil, frame)
    frame:HookScript("OnSizeChanged", UpdateFlowCoords)
    frame.Now = frame:CreateTexture(nil, "BORDER", nil, 1)
    frame.NowPulse = frame.Now:CreateAnimationGroup()
    frame.NowPulse:SetLooping("BOUNCE")
    local breathe = frame.NowPulse:CreateAnimation("Alpha")
    breathe:SetFromAlpha(1)
    breathe:SetToAlpha(0.45)
    breathe:SetDuration(1.8)
    breathe:SetSmoothing("IN_OUT")

    -- sparkles drift off the end icons arrive at, or with Area "All" anywhere over the timeline
    frame.Sparkles = private.CreateParticles(frame, function(particle, spec)
        if spec.Area == "All" then
            particle.x = math.random() * frame:GetWidth()
            particle.y = math.random() * frame:GetHeight()
            return
        end
        local along = math.random() * 40
        if frame.isHorizontal then
            particle.x = frame.arrival == "LEFT" and along or frame:GetWidth() - along
            particle.y = math.random() * frame:GetHeight()
            particle.vx, particle.vy = frame.arrival == "LEFT" and particle.vy or -particle.vy, particle.vx
        else
            particle.x = math.random() * frame:GetWidth()
            particle.y = frame.arrival == "BOTTOM" and along or frame:GetHeight() - along
            particle.vy = frame.arrival == "BOTTOM" and particle.vy or -particle.vy
        end
    end)
    SetupEditModeSettings(frame)
    frame.Ticks = {}
    frame:Hide()

    ---@class AtTimelineFrame : AceGUIWidget
    local widget = {
        OnAcquire = OnAcquire,
        OnRelease = OnRelease,
        type = Type,
        count = count,
        frame = frame,
        HandleTicks = HandleTicks,
        GetMoveSize = GetMoveSize,
        ApplySettings = ApplySettings,
        HandleSizeChanges = HandleSizeChanges,
    }
    ApplySettings(widget)
    private.RegisterThemed(widget)

    return AceGUI:RegisterAsWidget(widget)
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)
