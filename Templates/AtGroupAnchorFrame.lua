local appName, app = ...
---@class AbilityTimeline
local private = app
local AceGUI = LibStub("AceGUI-3.0")
local LibEditMode = LibStub("LibEditMode")
local Type = "AtGroupAnchorFrame"
local Version = 1
local variables = {
    spacing = 5,
    offsetRange = 300,
    maxIconSize = 150,
}

private.GroupAnchor = {}

private.GroupAnchor.PAUSED_MODES = {
    GROUP = "GROUP",
    TIMELINE = "TIMELINE",
}

private.GroupAnchor.ATTACH_AUTO = "AUTO"

local ATTACH_POINTS = {
    { value = "AUTO",        localisation = "AttachPointAuto" },
    { value = "TOP",         localisation = "AttachPointTop" },
    { value = "BOTTOM",      localisation = "AttachPointBottom" },
    { value = "LEFT",        localisation = "AttachPointLeft" },
    { value = "RIGHT",       localisation = "AttachPointRight" },
    { value = "TOPLEFT",     localisation = "AttachPointTopLeft" },
    { value = "TOPRIGHT",    localisation = "AttachPointTopRight" },
    { value = "BOTTOMLEFT",  localisation = "AttachPointBottomLeft" },
    { value = "BOTTOMRIGHT", localisation = "AttachPointBottomRight" },
    { value = "CENTER",      localisation = "AttachPointCenter" },
}

---returns the point of the timeline at its near (remaining 0) or far (threshold) end
---@param atFarEnd boolean
---@return string point
---@return boolean isHorizontal
private.GroupAnchor.getTimelineEndPoint = function(atFarEnd)
    local layout = private.db.global.timeline_frame[private.ACTIVE_EDITMODE_LAYOUT]
    local isHorizontal = layout.travel_direction == private.TIMELINE_DIRECTIONS.HORIZONTAL
    -- without inversion the icons travel towards the bottom / left
    local atStart = (not layout.inverse_travel_direction) ~= atFarEnd
    if isHorizontal then
        return atStart and "LEFT" or "RIGHT", true
    end
    return atStart and "BOTTOM" or "TOP", false
end

---returns the grow direction pointing from one end of the timeline to the other
---@param towardsFarEnd boolean
---@return string grow
private.GroupAnchor.getTimelineGrow = function(towardsFarEnd)
    local point = private.GroupAnchor.getTimelineEndPoint(not towardsFarEnd)
    local GROW = private.DynamicGroup.GROW
    if point == "LEFT" then
        return GROW.RIGHT
    elseif point == "RIGHT" then
        return GROW.LEFT
    elseif point == "BOTTOM" then
        return GROW.UP
    end
    return GROW.DOWN
end

---returns the coordinates of a point of a frame
---@param frame Frame
---@param point string
---@return number|nil x
---@return number|nil y
local getPointCoordinates = function(frame, point)
    local left, bottom, width, height = frame:GetRect()
    if not left then return end
    local x, y = left + width / 2, bottom + height / 2
    if point:find("LEFT") then
        x = left
    elseif point:find("RIGHT") then
        x = left + width
    end
    if point:find("TOP") then
        y = bottom + height
    elseif point:find("BOTTOM") then
        y = bottom
    end
    return x, y
end

---returns the distance of a point of a frame to its center
---@param point string
---@param width number
---@param height number
local getPointOffsetFromCenter = function(point, width, height)
    local x, y = 0, 0
    if point:find("LEFT") then
        x = -width / 2
    elseif point:find("RIGHT") then
        x = width / 2
    end
    if point:find("TOP") then
        y = height / 2
    elseif point:find("BOTTOM") then
        y = -height / 2
    end
    return x, y
end

---@param self AtGroupAnchorFrame
local function GetSettings(self, layoutName)
    return private.db.global[self.config.dbKey][layoutName or private.ACTIVE_EDITMODE_LAYOUT]
end

---@param self AtGroupAnchorFrame
---@return number
local function GetIconSize(self)
    local settings = self:GetSettings()
    if settings and settings.iconSize and settings.iconSize > 0 then
        return settings.iconSize
    end
    return private.db.profile.icon_settings.size
end

---@param self AtGroupAnchorFrame
---@return boolean
local function IsActive(self)
    if not self.config.hasModeSetting then return true end
    return self:GetSettings().mode == private.GroupAnchor.PAUSED_MODES.GROUP
end

---resolves the attach point to the timeline without the user offsets
---@param self AtGroupAnchorFrame
---@return string point
---@return string relativePoint
---@return number x
---@return number y
local function ResolveAttach(self)
    local settings = self:GetSettings()
    if settings.attachPoint ~= private.GroupAnchor.ATTACH_AUTO then
        return settings.attachPoint, settings.attachPoint, 0, 0
    end
    local point, isHorizontal = private.GroupAnchor.getTimelineEndPoint(self.config.atFarEnd)
    if self.config.outsideTimeline then
        -- automatic places the group just outside of the timeline end, centered on the timeline
        return private.RELATIVE_POSITIONS[point], point, 0, 0
    end
    -- automatic places the group besides the timeline end, on the opposite side of the spell names
    local timelineIconSize = private.db.profile.icon_settings.size
    local margin = private.db.global.timeline_frame[private.ACTIVE_EDITMODE_LAYOUT].iconMargin or variables.spacing
    local side = private.db.profile.text_settings.text_anchor == 'RIGHT' and -1 or 1
    local besides = side * (timelineIconSize / 2 + margin + self:GetIconSize() / 2)
    if isHorizontal then
        return point, point, 0, besides
    end
    return point, point, besides, 0
end

---resolves the grow direction of the group, automatic grows along the timeline
---@param self AtGroupAnchorFrame
---@param grow string
---@return string
local function ResolveGrow(self, grow)
    if grow ~= private.DynamicGroup.GROW.AUTO then
        return grow
    end
    return private.GroupAnchor.getTimelineGrow(self.config.growTowardsFarEnd)
end

---positions the anchor frame, only touches the anchors if something changed
---@param self AtGroupAnchorFrame
local function ApplyAnchor(self)
    local settings = self:GetSettings()
    if not settings then return end
    local size = self:GetIconSize()
    if self.frame:GetWidth() ~= size or self.frame:GetHeight() ~= size then
        self.frame:SetSize(size, size)
    end
    local key
    if settings.attached and private.TIMELINE_FRAME then
        local point, relativePoint, x, y = self:ResolveAttach()
        x = x + settings.offsetX
        y = y + settings.offsetY
        key = string.format("attached:%s:%s:%.2f:%.2f", point, relativePoint, x, y)
        if self.anchorKey ~= key then
            self.frame:ClearAllPoints()
            self.frame:SetPoint(point, private.TIMELINE_FRAME.frame, relativePoint, x, y)
        end
    else
        key = string.format("free:%s:%.2f:%.2f", settings.point, settings.x, settings.y)
        if self.anchorKey ~= key then
            self.frame:ClearAllPoints()
            self.frame:SetPoint(settings.point, settings.x, settings.y)
        end
    end
    self.anchorKey = key
end

---calculates the user offsets of the current frame position relative to the attach point
---@param self AtGroupAnchorFrame
---@return number|nil offsetX
---@return number|nil offsetY
local function CalculateAttachOffsets(self)
    local centerX, centerY = self.frame:GetCenter()
    if not centerX or not private.TIMELINE_FRAME then return end
    local point, relativePoint, x, y = self:ResolveAttach()
    local relativeX, relativeY = getPointCoordinates(private.TIMELINE_FRAME.frame, relativePoint)
    if not relativeX then return end
    local pointX, pointY = getPointOffsetFromCenter(point, self.frame:GetWidth(), self.frame:GetHeight())
    local baseX = relativeX + x - pointX
    local baseY = relativeY + y - pointY
    return math.floor(centerX - baseX + 0.5), math.floor(centerY - baseY + 0.5)
end

---stores the current position of the frame as free position
---@param self AtGroupAnchorFrame
local function StoreFreePosition(self, layoutName)
    local centerX, centerY = self.frame:GetCenter()
    if not centerX then return end
    local settings = self:GetSettings(layoutName)
    local parentWidth, parentHeight = UIParent:GetSize()
    settings.point = "CENTER"
    settings.x = math.floor(centerX - parentWidth / 2 + 0.5)
    settings.y = math.floor(centerY - parentHeight / 2 + 0.5)
end

---@param self AtGroupAnchorFrame
local function Refresh(self)
    self.anchorKey = nil
    self:ApplyAnchor()
    if self.config.onChange then
        self.config.onChange()
    end
end

---@param self AtGroupAnchorFrame
local function ApplyLayout(self, layoutName)
    local dbKey = self.config.dbKey
    if not private.db.global[dbKey] then
        private.db.global[dbKey] = {}
    end
    if not private.db.global[dbKey][layoutName] then
        private.db.global[dbKey][layoutName] = {}
    end
    local settings = private.db.global[dbKey][layoutName]
    local defaultPosition = self.config.defaultPosition
    if not settings.point then
        settings.point = defaultPosition.point
        settings.x = defaultPosition.x
        settings.y = defaultPosition.y
    end
    if settings.attached == nil then
        settings.attached = true
    end
    if not settings.attachPoint then
        settings.attachPoint = private.GroupAnchor.ATTACH_AUTO
    end
    if not settings.offsetX then
        settings.offsetX = 0
    end
    if not settings.offsetY then
        settings.offsetY = 0
    end
    if not settings.grow then
        settings.grow = private.DynamicGroup.GROW.AUTO
    end
    if not settings.spacing then
        -- the timeline icon margin was used to stack these icons before they became groups
        settings.spacing = private.db.global.timeline_frame[layoutName] and
            private.db.global.timeline_frame[layoutName].iconMargin or variables.spacing
    end
    if not settings.limit then
        settings.limit = 0
    end
    if not settings.sort then
        settings.sort = private.DynamicGroup.SORT.ASCENDING
    end
    if not settings.iconSize then
        settings.iconSize = 0
    end
    if self.config.hasModeSetting and not settings.mode then
        settings.mode = private.GroupAnchor.PAUSED_MODES.TIMELINE
    end
    if layoutName == private.ACTIVE_EDITMODE_LAYOUT then
        self:Refresh()
    end
end

---@param self AtGroupAnchorFrame
local function SetupEditModeSettings(self)
    local config = self.config
    local widget = self
    local frame = self.frame

    local onPositionChanged = function(_, layoutName, point, x, y)
        local settings = widget:GetSettings(layoutName)
        if settings.attached then
            local default = config.defaultPosition
            if point == default.point and x == default.x and y == default.y then
                -- reset position resets the offsets to the timeline
                settings.offsetX, settings.offsetY = 0, 0
            else
                local offsetX, offsetY = widget:CalculateAttachOffsets()
                if offsetX then
                    settings.offsetX, settings.offsetY = offsetX, offsetY
                end
            end
        else
            settings.point, settings.x, settings.y = point, x, y
        end
        widget:Refresh()
    end

    LibEditMode:AddFrame(frame, onPositionChanged, config.defaultPosition, config.title)

    local isInactive = function()
        return not widget:IsActive()
    end
    local isDetached = function(layoutName)
        return not widget:GetSettings(layoutName).attached
    end
    local attachPointValues = {}
    for _, attachPoint in ipairs(ATTACH_POINTS) do
        table.insert(attachPointValues, {
            text = private.getLocalisation(attachPoint.localisation),
            value = attachPoint.value,
            isRadio = true,
        })
    end

    local settings = {}
    if config.hasModeSetting then
        table.insert(settings, {
            name = private.getLocalisation("PausedDisplayMode"),
            desc = private.getLocalisation("PausedDisplayModeDescription"),
            kind = LibEditMode.SettingType.Dropdown,
            get = function(layoutName)
                return widget:GetSettings(layoutName).mode
            end,
            set = function(layoutName, value)
                widget:GetSettings(layoutName).mode = value
                widget:Refresh()
            end,
            default = private.GroupAnchor.PAUSED_MODES.TIMELINE,
            height = 50,
            values = {
                {
                    text = private.getLocalisation("PausedDisplayModeTimeline"),
                    value = private.GroupAnchor.PAUSED_MODES.TIMELINE,
                    isRadio = true,
                },
                {
                    text = private.getLocalisation("PausedDisplayModeGroup"),
                    value = private.GroupAnchor.PAUSED_MODES.GROUP,
                    isRadio = true,
                },
            },
        })
    end
    private.DynamicGroup.AppendSettings(settings, {
        {
            name = private.getLocalisation("AttachToTimeline"),
            desc = private.getLocalisation("AttachToTimelineDescription"),
            kind = LibEditMode.SettingType.Checkbox,
            default = true,
            get = function(layoutName)
                return widget:GetSettings(layoutName).attached
            end,
            set = function(layoutName, value)
                local groupSettings = widget:GetSettings(layoutName)
                if groupSettings.attached == value then return end
                if value then
                    groupSettings.offsetX, groupSettings.offsetY = 0, 0
                else
                    -- keep the frame where it currently is
                    widget:StoreFreePosition(layoutName)
                end
                groupSettings.attached = value
                widget:Refresh()
            end,
            disabled = isInactive,
        },
        {
            name = private.getLocalisation("AttachPoint"),
            desc = private.getLocalisation("AttachPointDescription"),
            kind = LibEditMode.SettingType.Dropdown,
            get = function(layoutName)
                return widget:GetSettings(layoutName).attachPoint
            end,
            set = function(layoutName, value)
                local groupSettings = widget:GetSettings(layoutName)
                groupSettings.attachPoint = value
                groupSettings.offsetX, groupSettings.offsetY = 0, 0
                widget:Refresh()
            end,
            default = private.GroupAnchor.ATTACH_AUTO,
            height = 200,
            values = attachPointValues,
            hidden = isDetached,
            disabled = isInactive,
        },
        {
            name = private.getLocalisation("AttachOffsetX"),
            desc = private.getLocalisation("AttachOffsetDescription"),
            kind = LibEditMode.SettingType.Slider,
            default = 0,
            get = function(layoutName)
                return widget:GetSettings(layoutName).offsetX
            end,
            set = function(layoutName, value)
                widget:GetSettings(layoutName).offsetX = value
                widget:Refresh()
            end,
            minValue = -variables.offsetRange,
            maxValue = variables.offsetRange,
            valueStep = 1,
            hidden = isDetached,
            disabled = isInactive,
        },
        {
            name = private.getLocalisation("AttachOffsetY"),
            desc = private.getLocalisation("AttachOffsetDescription"),
            kind = LibEditMode.SettingType.Slider,
            default = 0,
            get = function(layoutName)
                return widget:GetSettings(layoutName).offsetY
            end,
            set = function(layoutName, value)
                widget:GetSettings(layoutName).offsetY = value
                widget:Refresh()
            end,
            minValue = -variables.offsetRange,
            maxValue = variables.offsetRange,
            valueStep = 1,
            hidden = isDetached,
            disabled = isInactive,
        },
        {
            name = private.getLocalisation("GroupIconSize"),
            desc = private.getLocalisation("GroupIconSizeDescription"),
            kind = LibEditMode.SettingType.Slider,
            default = 0,
            get = function(layoutName)
                return widget:GetSettings(layoutName).iconSize
            end,
            set = function(layoutName, value)
                widget:GetSettings(layoutName).iconSize = value
                widget:Refresh()
            end,
            minValue = 0,
            maxValue = variables.maxIconSize,
            valueStep = 1,
            disabled = isInactive,
        },
    })
    private.DynamicGroup.AppendSettings(settings, private.DynamicGroup.BuildEditModeSettings(
        function(layoutName) return widget:GetSettings(layoutName) end,
        function() widget:Refresh() end,
        {
            growValues = {
                private.DynamicGroup.GROW.UP,
                private.DynamicGroup.GROW.DOWN,
                private.DynamicGroup.GROW.LEFT,
                private.DynamicGroup.GROW.RIGHT,
                private.DynamicGroup.GROW.HORIZONTAL,
                private.DynamicGroup.GROW.VERTICAL,
            },
            allowAuto = true,
            defaults = {
                grow = private.DynamicGroup.GROW.AUTO,
                spacing = variables.spacing,
            },
            disabled = isInactive,
        }))
    LibEditMode:AddFrameSettings(frame, settings)

    local buttons = {
        {
            text = private.getLocalisation("OpenIconEditor"),
            click = function() private.openSpellIconSettings() end
        }
    }
    LibEditMode:AddFrameSettingsButtons(frame, buttons)
end

---configures the frame, needs to be called once after creating the widget
---@param self AtGroupAnchorFrame
---@param config table -- dbKey, title, defaultPosition, atFarEnd, outsideTimeline, growTowardsFarEnd, hasModeSetting, onChange
local function Setup(self, config)
    self.config = config
    self.frame:SetSize(private.db.profile.icon_settings.size, private.db.profile.icon_settings.size)
    SetupEditModeSettings(self)
    LibEditMode:RegisterCallback('layout', function(layoutName)
        self:ApplyLayout(layoutName)
    end)
end

---@param self AtGroupAnchorFrame
local function OnAcquire(self)
end

---@param self AtGroupAnchorFrame
local function OnRelease(self)
end

local function Constructor()
    local count = AceGUI:GetNextWidgetNum(Type)
    local frame = CreateFrame("Frame", "AbilityTimelineGroupAnchorFrame" .. count, UIParent)
    frame:Show()
    private.Debug(frame, "AT_GROUP_ANCHOR_FRAME_" .. count)

    ---@class AtGroupAnchorFrame : AceGUIWidget
    local widget = {
        OnAcquire = OnAcquire,
        OnRelease = OnRelease,
        type = Type,
        count = count,
        frame = frame,
        config = {},
        Setup = Setup,
        ApplyLayout = ApplyLayout,
        ApplyAnchor = ApplyAnchor,
        CalculateAttachOffsets = CalculateAttachOffsets,
        StoreFreePosition = StoreFreePosition,
        Refresh = Refresh,
        GetSettings = GetSettings,
        GetIconSize = GetIconSize,
        IsActive = IsActive,
        ResolveAttach = ResolveAttach,
        ResolveGrow = ResolveGrow,
    }

    return AceGUI:RegisterAsWidget(widget)
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)
