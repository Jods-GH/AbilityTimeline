local addonName, private    = ...
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
    private.db.profile.timeline_frame[layoutName] = private.db.profile.timeline_frame[layoutName] or {}
    private.db.profile.timeline_frame[layoutName].x = x
    private.db.profile.timeline_frame[layoutName].y = y
    private.db.profile.timeline_frame[layoutName].point = point

    private.TIMELINE_FRAME:SetPoint(private.db.profile.timeline_frame[layoutName].point,
        private.db.profile.timeline_frame[layoutName].x, private.db.profile.timeline_frame[layoutName].y)
end

local function HandleTickVisibility(layoutName)
    for _, tick in ipairs(private.TIMELINE_FRAME.frame.Ticks) do
        if private.db.profile.timeline_frame[layoutName].ticks_enabled then
            tick:SetTick(private.TIMELINE_FRAME, tick.tick)
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

LibEditMode:RegisterCallback('layout', function(layoutName)
    -- this will be called every time the Edit Mode layout is changed (which also happens at login),
    -- use it to load the saved button position from savedvariables and position it
    if not private.db.profile.timeline_frame then
        private.db.profile.timeline_frame = {}
    end
    if not private.db.profile.timeline_frame[private.ACTIVE_EDITMODE_LAYOUT].point then
        private.db.profile.timeline_frame[private.ACTIVE_EDITMODE_LAYOUT].point = variables.position.point
    end
    if not private.db.profile.timeline_frame[private.ACTIVE_EDITMODE_LAYOUT].x then
        private.db.profile.timeline_frame[private.ACTIVE_EDITMODE_LAYOUT].x = variables.position.x
    end
    if not private.db.profile.timeline_frame[private.ACTIVE_EDITMODE_LAYOUT].y then
        private.db.profile.timeline_frame[private.ACTIVE_EDITMODE_LAYOUT].y = variables.position.y
    end
    if not private.db.profile.timeline_frame[layoutName].ticks_enabled then
        private.db.profile.timeline_frame[layoutName].ticks_enabled = variables.ticks_enabled
    end
    if not private.db.profile.timeline_frame[layoutName].otherSize then
        private.db.profile.timeline_frame[layoutName].otherSize = variables.otherSize
    end
    if not private.db.profile.timeline_frame[layoutName].travelSize then
        private.db.profile.timeline_frame[layoutName].travelSize = variables.travelSize
    end
    if not private.db.profile.timeline_frame[layoutName].inverse_travel_direction then
        private.db.profile.timeline_frame[layoutName].inverse_travel_direction = variables.inverse_travel_direction
    end
    if not private.db.profile.timeline_frame[layoutName].text_anchor then
        private.db.profile.timeline_frame[layoutName].text_anchor = 'LEFT'
    end
    if not private.db.profile.timeline_frame[layoutName].horizontal then
        private.db.profile.timeline_frame[layoutName].horizontal = false
    end
    if not private.db.profile.timeline_frame[layoutName].timeline_texture then
        private.db.profile.timeline_frame[layoutName].timeline_texture = variables.timelineTexture
    end


    if private.TIMELINE_FRAME then
        private.TIMELINE_FRAME:ClearAllPoints()
        private.TIMELINE_FRAME:SetPoint(private.db.profile.timeline_frame[layoutName].point,
            private.db.profile.timeline_frame[layoutName].x, private.db.profile.timeline_frame[layoutName].y)
        HandleTickVisibility(layoutName)
        local width, height
        if private.db.profile.timeline_frame[layoutName].travel_direction == private.TIMELINE_DIRECTIONS.HORIZONTAL then
            width = private.db.profile.timeline_frame[layoutName].travelSize
            height = private.db.profile.timeline_frame[layoutName].otherSize
        else
            width = private.db.profile.timeline_frame[layoutName].otherSize
            height = private.db.profile.timeline_frame[layoutName].travelSize
        end
        SetFrameSize(private.TIMELINE_FRAME, width, height)
        private.TIMELINE_FRAME:HandleTicks()
        private.TIMELINE_FRAME.SetBackDrop(private.TIMELINE_FRAME.frame,
            private.db.profile.timeline_frame[layoutName].timeline_texture)
    end
end)


local function HandleTicks(self)
    for i = 1, #self.frame.Ticks do
        self.frame.Ticks[i].frame:Hide()
        self.frame.Ticks[i]:Release()
    end
    for i, tick in ipairs(private.TIMELINE_TICKS) do
        local widget = AceGUI:Create("AtTimelineTicks")
        self.frame.Ticks[i] = widget
        widget:SetTick(self, tick)
        widget.frame:Show()
    end
end
local function HandleSizeChanges(self)
    local layoutName = private.ACTIVE_EDITMODE_LAYOUT
    local width, height
    if private.db.profile.timeline_frame[layoutName].travel_direction == private.TIMELINE_DIRECTIONS.HORIZONTAL then
        width = private.db.profile.timeline_frame[layoutName].travelSize
        height = private.db.profile.timeline_frame[layoutName].otherSize
    else
        width = private.db.profile.timeline_frame[layoutName].otherSize
        height = private.db.profile.timeline_frame[layoutName].travelSize
    end
    SetFrameSize(self, width, height)
end

local function SetBackDrop(frame, textureName)
    local texture = SharedMedia:Fetch("background", textureName) or ""
    frame:SetBackdrop({
        bgFile = texture,
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
end


local function GetMoveSize(self)
    if private.db.profile.timeline_frame[private.ACTIVE_EDITMODE_LAYOUT].travel_direction == private.TIMELINE_DIRECTIONS.HORIZONTAL then
        return self.frame:GetWidth()
    end
    return self.frame:GetHeight()
end

local function SetupEditModeSettings(frame)
    LibEditMode:AddFrame(frame, onPositionChanged, variables.position, "Ability Timeline")


    local TextureSettings = {
    }
    for _, texName in ipairs(SharedMedia:List("background")) do
        local texPath = SharedMedia:Fetch("background", texName) or ""
        local display = ("|T%s:16:128|t %s"):format(tostring(texPath), texName)
        table.insert(TextureSettings, {
            text = display,
            value = texName,
            isRadio = false,
        })
    end

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
            name = private.getLocalisation("TextAnchor"),
            desc = private.getLocalisation("TextAnchorDescription"),
            kind = LibEditMode.SettingType.Dropdown,

            get = function(layoutName)
                return private.db.profile.timeline_frame[layoutName].text_anchor
            end,
            set = function(layoutName, value)
                private.db.profile.timeline_frame[layoutName].text_anchor = value
            end,
            default = 'LEFT',
            height = 100,
            values = {
                {
                    text = private.getLocalisation("TextAnchorRight"),
                    value = 'RIGHT',
                    isRadio = true,
                },
                {
                    text = private.getLocalisation("TextAnchorLeft"),
                    value = 'LEFT',
                    isRadio = true,
                },
            },
        },
        {
            name = private.getLocalisation("TravelDirection"),
            desc = private.getLocalisation("TravelDirectionDescription"),
            kind = LibEditMode.SettingType.Dropdown,

            get = function(layoutName)
                return private.db.profile.timeline_frame[layoutName].travel_direction
            end,
            set = function(layoutName, value)
                private.db.profile.timeline_frame[layoutName].travel_direction = value
                HandleSizeChanges(private.TIMELINE_FRAME)
                HandleTickVisibility(layoutName)
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
            name = private.getLocalisation("TimelineTexture"),
            desc = private.getLocalisation("TimelineTextureDescription"),
            kind = LibEditMode.SettingType.Dropdown,

            get = function(layoutName)
                return private.db.profile.timeline_frame[layoutName].timeline_texture
            end,
            set = function(layoutName, value)
                private.db.profile.timeline_frame[layoutName].timeline_texture = value
                SetBackDrop(private.TIMELINE_FRAME.frame, value)
            end,
            default = variables.timelineTexture,
            height = 300,
            values = TextureSettings,

        },
        {
            name = private.getLocalisation("TimelineOtherSize"),
            desc = private.getLocalisation("TimelineOtherSizeDescription"),
            kind = LibEditMode.SettingType.Slider,
            default = variables.otherSize,
            get = function(layoutName)
                return private.db.profile.timeline_frame[layoutName].otherSize
            end,
            set = function(layoutName, value)
                private.db.profile.timeline_frame[layoutName].otherSize = value
                HandleSizeChanges(private.TIMELINE_FRAME)
                HandleTicks(private.TIMELINE_FRAME)
            end,
            minValue = 1,
            maxValue = 200,
            valueStep = 1,
        },
        {
            name = private.getLocalisation("TimelineTravelSize"),
            desc = private.getLocalisation("TimelineTravelSizeDescription"),
            kind = LibEditMode.SettingType.Slider,
            default = variables.travelSize,
            get = function(layoutName)
                return private.db.profile.timeline_frame[layoutName].travelSize
            end,
            set = function(layoutName, value)
                private.db.profile.timeline_frame[layoutName].travelSize = value
                HandleSizeChanges(private.TIMELINE_FRAME)
                HandleTicks(private.TIMELINE_FRAME)
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
    SetupEditModeSettings(frame)
    SetBackDrop(frame, variables.timelineTexture)
    frame:SetBackdropColor(0, 0, 0, 1)
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
        SetBackDrop = SetBackDrop,
        HandleSizeChanges = HandleSizeChanges,
    }

    return AceGUI:RegisterAsWidget(widget)
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)
