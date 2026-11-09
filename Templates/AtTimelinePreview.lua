local appName, app = ...
---@class AbilityTimeline
local private = app
local AceGUI = LibStub("AceGUI-3.0")
local Type = "AtTimelinePreview"
local Version = 1
local variables = { width = 200, height = 36, long = 220, short = 30 }

local function ReleaseTicks(self)
    for i = #self.ticks, 1, -1 do
        self.ticks[i]:Release()
        self.ticks[i] = nil
    end
end

local function ApplySettings(self)
    if not self.active then return end
    local frame = self.frame
    ReleaseTicks(self)
    if not self.showTicks then
        frame:SetSize(variables.width, variables.height)
        private.TimelineFrame.ApplyTheme(frame, "LEFT", true)
        return
    end
    private.TimelineFrame.ApplyTheme(frame, private.TimelineFrame.GetArrivalPoint())
    local layout = private.db.global.timeline_frame[private.ACTIVE_EDITMODE_LAYOUT]
    local isHorizontal = layout.travel_direction == private.TIMELINE_DIRECTIONS.HORIZONTAL
    local long, short = variables.long, variables.short
    frame:SetSize(isHorizontal and long or short, isHorizontal and short or long)
    local settings = private.db.profile.timeline_settings
    if not settings.ticks_enabled then return end
    for _, time in ipairs(private.TimelineFrame.GetTickTimes(long)) do
        local tick = AceGUI:Create("AtTimelineTicks")
        tick:SetTick(frame, time, long, settings.threshold_time, isHorizontal)
        tick.frame:Show()
        table.insert(self.ticks, tick)
    end
end

local function SetTicks(self, enabled)
    self.showTicks = enabled
    self:ApplySettings()
end

local function OnAcquire(self)
    self.active = true
    self.showTicks = false
    self:ApplySettings()
end

local function OnRelease(self)
    self.active = false
    ReleaseTicks(self)
    private.ThemeApply.StopEnterEffects(self.frame)
    private.ThemeApply.ConfigureTrack(self.frame, nil)
    private.ThemeApply.ConfigureTimelineArt(self.frame, {}, "LEFT", true)
    self.frame.NowPulse:Stop()
    self.frame.Sparkles:Stop()
    self.frame.Glass:Apply(nil)
    self.frame.FlowDriver:SetScript("OnUpdate", nil)
    self.frame.flow = nil
end

local function Constructor()
    local widget = AceGUI:RegisterAsWidget({
        type = Type,
        frame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate"),
        ticks = {},
        OnAcquire = OnAcquire,
        OnRelease = OnRelease,
        ApplySettings = ApplySettings,
        SetTicks = SetTicks,
    })
    private.TimelineFrame.AddThemeLayers(widget.frame)
    private.RegisterThemed(widget)
    return widget
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)
