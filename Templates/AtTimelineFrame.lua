local appName, app = ...
---@class AbilityTimeline
local private = app
local AceGUI                = LibStub("AceGUI-3.0")
local LibEditMode           = LibStub("LibEditMode")
local Type                  = "AtTimelineFrame"
local Version               = 1
local variables             = {
    otherSize = 50,
    travelSize = 500,
    inverse_travel_direction = false,
    position = {
        point = 'CENTER',
        y = 110,
        x = 410,
    },
    IconMargin = 5,
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
        if private.db.profile.timeline_settings.ticks_enabled then
            tick:SetTick(private.TIMELINE_FRAME.frame, tick.tick, private.TIMELINE_FRAME:GetMoveSize(),
                private.db.profile.timeline_settings.threshold_time,
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


---the seconds the ticks of a timeline moveSize long are at, far enough apart to be read
---@param moveSize number
---@return number[]
private.TimelineFrame.GetTickTimes = function(moveSize)
    local thresholdTime = private.db.profile.timeline_settings.threshold_time
    local minTickTime = variables.minTickDistance * thresholdTime / moveSize
    local step = variables.tickInterval * math.max(math.ceil(minTickTime / variables.tickInterval), 1)
    local times = {}
    for tick = step, thresholdTime - 1, step do
        table.insert(times, tick)
    end
    return times
end

local function HandleTicks(self)
    for i = 1, #self.frame.Ticks do
        self.frame.Ticks[i].frame:Hide()
        self.frame.Ticks[i]:Release()
    end
    self.frame.Ticks = {}
    local thresholdTime = private.db.profile.timeline_settings.threshold_time
    private.TIMELINE_TICKS = private.TimelineFrame.GetTickTimes(self:GetMoveSize())
    for i, tick in ipairs(private.TIMELINE_TICKS) do
        local widget = AceGUI:Create("AtTimelineTicks")
        self.frame.Ticks[i] = widget
        widget:SetTick(self.frame, tick, self:GetMoveSize(), thresholdTime,
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

-- the texture coordinates that lay a mark's left end at the end icons arrive at, its top towards the frame's top or left
local MARK_COORDS = {
    LEFT = { 0, 0, 0, 1, 1, 0, 1, 1 },
    RIGHT = { 1, 0, 1, 1, 0, 0, 0, 1 },
    BOTTOM = { 1, 0, 0, 0, 1, 1, 0, 1 },
    TOP = { 0, 0, 1, 0, 0, 1, 1, 1 },
}

---keeps a mark Length times the timeline's thickness long
---@param frame Frame
local function UpdateMarkSize(frame)
    if not frame.mark then return end
    if frame.isHorizontal then
        frame.Mark:SetWidth(frame:GetHeight() * (frame.mark.Length or 2))
    else
        frame.Mark:SetHeight(frame:GetWidth() * (frame.mark.Length or 2))
    end
end

---a still texture across the timeline at the end icons arrive at, Length times its thickness long, e.g. a stroke of
---highlighter
---@param frame Frame
---@param mark table|nil
---@param arrival string
---@param isHorizontal boolean
local function ApplyMark(frame, mark, arrival, isHorizontal)
    frame.mark = mark
    if not (mark and private.ThemeApply.Texture(frame.Mark, mark)) then
        frame.Mark:Hide()
        return
    end
    frame.Mark:ClearAllPoints()
    if isHorizontal then
        frame.Mark:SetPoint("TOP" .. arrival, frame, "TOP" .. arrival)
        frame.Mark:SetPoint("BOTTOM" .. arrival, frame, "BOTTOM" .. arrival)
    else
        frame.Mark:SetPoint(arrival .. "LEFT", frame, arrival .. "LEFT")
        frame.Mark:SetPoint(arrival .. "RIGHT", frame, arrival .. "RIGHT")
    end
    frame.Mark:SetTexCoord(unpack(MARK_COORDS[arrival]))
    frame.Mark:Show()
    UpdateMarkSize(frame)
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

---draws the current theme's look of the timeline on a frame made by AddThemeLayers, icons arriving at arrival
---@param frame Frame
---@param arrival string
---@param isHorizontal boolean
private.TimelineFrame.ApplyTheme = function(frame, arrival, isHorizontal)
    local style = private.GetElementStyle("Timeline")
    private.ThemeApply.Backdrop(frame, style.Backdrop)
    frame.Background:SetShown(private.ThemeApply.Texture(frame.Background, style.Background))
    frame.Edge:SetShown(private.ThemeApply.Texture(frame.Edge, style.Edge))
    frame.arrival, frame.isHorizontal = arrival, isHorizontal
    ApplyWash(frame, style.Wash, arrival, isHorizontal)
    ApplyMark(frame, style.Mark, arrival, isHorizontal)
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
    ApplyFlow(frame, style.Flow, arrival, isHorizontal)
    frame.Sparkles:Start(style.Sparkles)
end

private.TimelineFrame.GetArrivalPoint = GetArrivalPoint

---@param self AtTimelineFrame
local function ApplySettings(self)
    private.TimelineFrame.ApplyTheme(self.frame, GetArrivalPoint())
end

local function GetMoveSize(self)
    if private.db.global.timeline_frame[private.ACTIVE_EDITMODE_LAYOUT].travel_direction == private.TIMELINE_DIRECTIONS.HORIZONTAL then
        return self.frame:GetWidth()
    end
    return self.frame:GetHeight()
end

-- Edit Mode has where the timeline is and how it lies, its look and behaviour are on the settings window's Timeline page
local function SetupEditModeSettings(frame)
    LibEditMode:AddFrame(frame, onPositionChanged, variables.position,
        "|TInterface\\AddOns\\AbilityTimeline\\Media\\Textures\\logo_transparent.tga:32|t Better Timeline")

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
        },
    }
    LibEditMode:AddFrameSettings(frame, settings)

    local buttons = {
        {
            text = private.getLocalisation("SettingsOpenPage"),
            click = function() private.openSettings("Timeline") end
        }
    }
    LibEditMode:AddFrameSettingsButtons(frame, buttons)
end

---creates the textures and sparkles a theme draws the timeline with on frame, e.g. for a preview of the timeline
---@param frame Frame
private.TimelineFrame.AddThemeLayers = function(frame)
    frame.Background = frame:CreateTexture(nil, "BACKGROUND")
    frame.Background:SetAllPoints(frame)
    frame.Edge = frame:CreateTexture(nil, "BORDER")
    frame.Edge:SetAllPoints(frame)
    frame.Wash = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
    frame.Wash:SetTexture("Interface\\Buttons\\WHITE8X8")
    frame.Wash:SetPoint("TOPLEFT", 1, -1)
    frame.Wash:SetPoint("BOTTOMRIGHT", -1, 1)
    frame.Mark = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
    frame.Mark:Hide()
    frame.Flow = frame:CreateTexture(nil, "BACKGROUND", nil, 2)
    frame.Flow:SetPoint("TOPLEFT", 2, -2)
    frame.Flow:SetPoint("BOTTOMRIGHT", -2, 2)
    frame.Flow:Hide()
    frame.FlowDriver = CreateFrame("Frame", nil, frame)
    frame:HookScript("OnSizeChanged", UpdateFlowCoords)
    frame:HookScript("OnSizeChanged", UpdateMarkSize)
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
end

local function Constructor()
    local count = AceGUI:GetNextWidgetNum(Type)
    local frame = CreateFrame("Frame", "AbilityTimelineFrame", UIParent, "BackdropTemplate")
    frame:SetWidth(variables.otherSize)
    frame:SetHeight(variables.travelSize)

    frame:SetFrameStrata("BACKGROUND")
    private.TimelineFrame.AddThemeLayers(frame)
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
