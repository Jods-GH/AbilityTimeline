local addonName, private = ...
local AceGUI = LibStub("AceGUI-3.0")
local LibEditMode = LibStub("LibEditMode")
local Type = "AtTimelineFrame"
local Version = 1
local variables = {
}

local defaultPosition = {
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

LibEditMode:RegisterCallback('layout', function(layoutName)
    -- this will be called every time the Edit Mode layout is changed (which also happens at login),
    -- use it to load the saved button position from savedvariables and position it
    if not private.db.profile.timeline_frame then
        private.db.profile.timeline_frame = {}
    end
    if not private.db.profile.timeline_frame[layoutName] then
        private.db.profile.timeline_frame[layoutName] = CopyTable(defaultPosition)
    end

    private.TIMELINE_FRAME:ClearAllPoints()
    private.TIMELINE_FRAME:SetPoint(private.db.profile.timeline_frame[layoutName].point,
        private.db.profile.timeline_frame[layoutName].x, private.db.profile.timeline_frame[layoutName].y)
end)

-- -- LibEditMode:RegisterCallback('rename', function(oldLayoutName, newLayoutName)
-- -- 	-- this will be called every time the Edit Mode layout is changed (which also happens at login),
-- -- 	-- use it to load the saved button position from savedvariables and position it
-- -- 	if not  private.db.profile.timeline_frame then
-- -- 		private.db.profile.timeline_frame = {}
-- -- 	end
-- --    local layout = private.db.profile.timeline_frame[oldLayoutName]
-- -- 	if not private.db.profile.timeline_frame[oldLayoutName] then
-- -- 		layout = CopyTable(defaultPosition)
-- -- 	end
-- --    private.db.profile.timeline_frame[newLayoutName] = layout
-- -- 	private.TIMELINE_FRAME:ClearAllPoints()
-- -- 	private.TIMELINE_FRAME:SetPoint(private.db.profile.timeline_frame[newLayoutName].point, private.db.profile.timeline_frame[newLayoutName].x, private.db.profile.timeline_frame[newLayoutName].y)
-- -- end)

-- LibEditMode:RegisterCallback('create', function(layoutName)
-- 	if not  private.db.profile.timeline_frame then
-- 		private.db.profile.timeline_frame = {}
-- 	end

--    private.db.profile.timeline_frame[layoutName] = CopyTable(defaultPosition)
-- end)

-- LibEditMode:RegisterCallback('delete', function(layoutName)
-- 	if not private.db.profile.timeline_frame then
-- 		return
-- 	end

--    private.db.profile.timeline_frame[layoutName] = {}
-- end)

local function Constructor()
    local count = AceGUI:GetNextWidgetNum(Type)
    local frame = CreateFrame("Frame", "AbilityTimelineFrame", UIParent, "BackdropTemplate")
    frame:SetWidth(60)
    frame:SetHeight(500)

    LibEditMode:AddFrame(frame, onPositionChanged, defaultPosition, "Ability Timeline")
    
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
    local left, bottom, width, height = frame:GetBoundsRect()
    for i, tick in ipairs(private.TIMELINE_TICKS) do
        local tickLine = frame:CreateTexture(nil, "ARTWORK")
        local tickPosition = (tick / private.AT_THRESHHOLD_TIME) * moveHeight
        print("Creating tick at position " ..
        (tick / private.AT_THRESHHOLD_TIME) .. " for position" .. tickPosition .. " for tick " .. tick)
        tickLine:SetColorTexture(1, 1, 1, 1)
        tickLine:SetHeight(1)
        tickLine:SetPoint("LEFT", frame, "BOTTOMLEFT", 0, tickPosition)
        tickLine:SetPoint("RIGHT", frame, "BOTTOMRIGHT", 0, tickPosition)
        local tickText = frame:CreateFontString(nil, "OVERLAY", "SystemFont_Shadow_Med3")
        tickText:SetPoint("LEFT", tickLine, "RIGHT", 5, 0)
        tickText:SetText(tick .. "s")
        tickLine.tickText = tickText
        frame.Ticks[i] = tickLine
    end

    frame:Hide()
    DevTool:AddData(frame, "AT_TIMELINE_FRAME")

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
