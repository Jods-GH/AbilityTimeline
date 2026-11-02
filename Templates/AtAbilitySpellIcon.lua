local appName, app = ...
---@class AbilityTimeline
local private = app
local AceGUI = LibStub("AceGUI-3.0")
local Type = "AtAbilitySpellIcon"
local Version = 1
local variables = {
	ExtraIcons={
		IconSize = 16,
	},
	MaxMergedIcons = 4,
}

private.MAX_MERGED_TIMELINE_ICONS = variables.MaxMergedIcons

private.RELATIVE_POSITIONS = {
	RIGHT = "LEFT",
	LEFT = "RIGHT",
	TOP = "BOTTOM",
	BOTTOM = "TOP",
}

setmetatable(private.RELATIVE_POSITIONS, {
	__index = function(_, key)
		error(string.format(private.getLocalisation('InvalidTextPosition') .. "%s", tostring(key)), 2);
	end,
})

---handles the RoleIcons anchoring depending on the selected RoleIcon anchor
---@param self Frame
---@param isStopped boolean
local handleRoleIconAnchors = function(self, isStopped)
	local roleIcons = private.GetElementStyle("SpellIcon").RoleIcons
	local anchor = roleIcons.Anchor
	if not anchor then return end
	local offset = roleIcons.Offset or { x = 0, y = 0 }
	local size = roleIcons.Size or variables.ExtraIcons.IconSize
	local xOffset = offset.x
	local stackDir = 1
	-- only left/right aligned anchors follow the spell name when it swaps sides while queued
	if isStopped and (anchor == "LEFT" or anchor == "RIGHT") then
		anchor = private.RELATIVE_POSITIONS[anchor]
		xOffset = -offset.x
		stackDir = -1
	end
	for i, texture in ipairs(self.RoleIcons) do
		texture:ClearAllPoints()
		texture:SetPoint(anchor, self, anchor, xOffset + stackDir * (i - 1) * size, offset.y)
	end
end
---handles the Text anchoring depending on the selected text anchor
---@param self Frame
---@param isStopped boolean
local handleAnchors      = function(self, isStopped)
	self.SpellName:ClearAllPoints()
	local text = private.GetElementStyle("SpellIcon").Text
	local relPos, anchorPos, xOffset, yOffset
	if isStopped then
		relPos = text.Anchor
		anchorPos = private.RELATIVE_POSITIONS[text.Anchor]
	else
		relPos = private.RELATIVE_POSITIONS[text.Anchor]
		anchorPos = text.Anchor
	end

	if private.db.global.timeline_frame[private.ACTIVE_EDITMODE_LAYOUT].travel_direction == private.TIMELINE_DIRECTIONS.HORIZONTAL then
		-- in horizontal mode we need to adjust position accordingly
		if relPos == 'LEFT' then
			relPos = 'TOP'
		else
			relPos = 'BOTTOM'
		end
		if anchorPos == 'LEFT' then
			anchorPos = 'TOP'
		else
			anchorPos = 'BOTTOM'
		end
	end

	local offset = text.Offset
	if relPos == 'LEFT' then
		xOffset, yOffset = offset.x, offset.y
	elseif relPos == 'RIGHT' then
		xOffset, yOffset = -offset.x, -offset.y
	elseif relPos == 'TOP' then
		xOffset, yOffset = offset.y, -offset.x
	else -- BOTTOM
		xOffset, yOffset = -offset.y, offset.x
	end
	self.SpellName:SetPoint(relPos, self, anchorPos, xOffset, yOffset)
	for _, texture in pairs(self.DangerIcon) do
		texture:ClearAllPoints()
		texture:SetPoint(relPos, self, anchorPos, 0, 0)
	end
	handleRoleIconAnchors(self, isStopped)
end
---returns a raw icon position without any overlap handling
---@param iconSize number -- the size of the icon
---@param moveHeight number -- the total height of the timeline for position calculation
---@param remainingDuration number -- remaining duration of the icon
---@param isStopped boolean -- whether the icon is currently stopped (paused/blocked)
---@param unclamped boolean|nil -- keeps moving past the far end instead of stopping there (icons pushed back by overlap handling)
---@return integer -- x position
---@return integer -- y position
---@return boolean -- is moving
local getRawIconPosition = function(iconSize, moveHeight, remainingDuration, isStopped, unclamped)
	local timelineOtherPosition = 0
	local timelineMainPosition = 0
	local isMoving = false
	local margin = private.db.global.timeline_frame[private.ACTIVE_EDITMODE_LAYOUT].iconMargin or 5
	if isStopped then
		if private.GetElementStyle("SpellIcon").Text.Anchor == 'RIGHT' then
			timelineOtherPosition = 0 - iconSize - margin
		else
			timelineOtherPosition = iconSize +
				margin
		end
	end
	local thresholdTime = private.db.global.timeline_frame[private.ACTIVE_EDITMODE_LAYOUT].threshold_time
	if not unclamped and not (remainingDuration < thresholdTime) then
		-- We are out of range of the moving timeline
		if private.db.global.timeline_frame[private.ACTIVE_EDITMODE_LAYOUT].inverse_travel_direction then
			timelineMainPosition = 0 - (iconSize / 2)
		else
			timelineMainPosition = moveHeight + (iconSize / 2)
		end
	else
		if private.db.global.timeline_frame[private.ACTIVE_EDITMODE_LAYOUT].inverse_travel_direction then
			timelineMainPosition = moveHeight - ((remainingDuration) / thresholdTime) * moveHeight -
				(iconSize / 2)
			isMoving = true
		else
			timelineMainPosition = ((remainingDuration) / thresholdTime) * moveHeight + (iconSize / 2)
			isMoving = true
		end
	end
	if private.db.global.timeline_frame[private.ACTIVE_EDITMODE_LAYOUT].travel_direction == private.TIMELINE_DIRECTIONS.HORIZONTAL then
		return timelineMainPosition, timelineOtherPosition, isMoving
	else
		return timelineOtherPosition, timelineMainPosition, isMoving
	end
end


-- zones a timeline icon can be in, icons in grouped zones are positioned by the zone's dynamic group
private.TIMELINE_ZONES = {
	MOVING = "MOVING",               -- travels along the timeline
	WAITING = "WAITING",             -- waits at the far end until it enters the timeline window
	QUEUED = "QUEUED",               -- reached 0 and waits for the cast
	PAUSED = "PAUSED",               -- paused and shown in the paused group
	INLINE_PAUSED = "INLINE_PAUSED", -- paused and shown besides the timeline at its position
}
local ZONES = private.TIMELINE_ZONES

local ApplySpellName

---Plays the theme's Pulse, when the icon passes a tick of the timeline
---@param self Frame
local PlayHighlight         = function(self)
	-- icons merged into another are hidden, the icon they show in pulses for them
	if not self:IsShown() then return end
	private.ThemeApply.PlayPulse(self, private.GetElementStyle("SpellIcon").Pulse, self.SpellIcon,
		self.eventInfo and self.eventInfo.iconFileID)
end
---Handles the cooldown display for a given frame (the frame needs to be the frame of a AtAbilitySpellIcon widget)
---@param self frame
---@param remainingTime number
local HandleCooldown        = function(self, remainingTime)
	local formatedTime = remainingTime
	if formatedTime <= 0 then
		self.Cooldown:SetText("")
		return
	end
	if remainingTime > 60 then
		local seconds = remainingTime % 60
		if seconds > 30 then
			formatedTime = math.ceil(remainingTime / 60) .. "m"
		else
			formatedTime = math.floor(remainingTime / 60) .. "m"
		end
	else
		formatedTime = math.ceil(remainingTime)
	end
	self.Cooldown:SetText(formatedTime)
	if private.db.profile.cooldown_settings.cooldown_highlight and private.db.profile.cooldown_settings.cooldown_highlight.enabled then
		for _, value in pairs(private.db.profile.cooldown_settings.cooldown_highlight.highlights) do
			local time, color = value.time, value.color
			if (remainingTime <= time) then
				self.Cooldown:SetTextColor(color.r, color.g, color.b)
				if value.useGlow then
					private.EnableGlow(self, value.glowType, remainingTime, value.glowColor)
				end
				return
			end
		end
	end
	self.Cooldown:SetTextColor(private.ThemeApply.Color(private.GetElementStyle("Cooldown").Font.Color))
end

---Updates text anchors, cooldown and (for non grouped zones) the position of a timeline icon
---@param self AtAbilitySpellIcon
---@param state number -- state of the event
---@param timeRemaining number -- remaining time of the event
---@param positionRemaining number -- remaining time used to position the icon on the timeline
---@param zone string -- zone of the icon
local UpdateTimeline = function(self, state, timeRemaining, positionRemaining, zone)
	local frame = self.frame
	local isStopped = zone == ZONES.QUEUED or zone == ZONES.PAUSED or zone == ZONES.INLINE_PAUSED
	local changed = state ~= frame.state or isStopped ~= frame.isStopped
	if changed then
		frame.state = state
		frame.isStopped = isStopped
		handleAnchors(frame, isStopped)
	end
	if changed or state ~= private.ENCOUNTER_STATES.Paused then
		HandleCooldown(frame, timeRemaining)
	end
	if zone == ZONES.MOVING or zone == ZONES.INLINE_PAUSED then
		local iconSize = private.GetElementStyle("SpellIcon").Size
		local xPos, yPos, isMoving = getRawIconPosition(iconSize, private.TIMELINE_FRAME:GetMoveSize(), positionRemaining,
			isStopped, true)
		frame.frameIsMoving = isMoving
		if private.db.global.timeline_frame[private.ACTIVE_EDITMODE_LAYOUT].travel_direction == private.TIMELINE_DIRECTIONS.HORIZONTAL then
			frame:SetPoint("CENTER", private.TIMELINE_FRAME.frame, "LEFT", xPos, yPos)
		else
			frame:SetPoint("CENTER", private.TIMELINE_FRAME.frame, "BOTTOM", xPos, yPos)
		end
	else
		frame.frameIsMoving = false
	end
end

---Sets the spell name text of the icon and its color
---@param self AtAbilitySpellIcon
---@param disableOnUpdate boolean|nil -- disables debug output for previews
ApplySpellName              = function(self, disableOnUpdate)
	local eventInfo = self.frame.eventInfo
	if private.db.global.timeline_frame[private.ACTIVE_EDITMODE_LAYOUT].travel_direction == private.TIMELINE_DIRECTIONS.HORIZONTAL then
		self.frame.SpellName:SetText("")
		if eventInfo and eventInfo.id then
			private.Debug("Timeline is in horizontal mode, hiding text for eventID: " .. eventInfo.id)
		end
	else
		self.frame.SpellName:SetText(eventInfo.spellName)
		if private.db.profile.text_settings.useEventColor then
			local color = private.manager.getEventColor(eventInfo.id)
			if color then
				self.frame.SpellName:SetTextColor(color.r, color.g, color.b)
			elseif not disableOnUpdate then
				private.Debug("Not using  color for text for eventID: " .. eventInfo.id)
			end
		elseif not disableOnUpdate then
			private.Debug("Event coloring disabled for text for eventID: " .. eventInfo.id)
		end
	end
end

---applies the configured default color to the spell name
---@param frame Frame
local applyDefaultTextColor = function(frame)
	frame.SpellName:SetTextColor(private.ThemeApply.Color(private.GetElementStyle("SpellIcon").Text.Font.Color))
end

---hides all merge slices and separators of an icon
---@param frame Frame
local hideMergeSlices = function(frame)
	for _, slice in ipairs(frame.MergeSlices) do
		slice:Hide()
	end
	for _, separator in ipairs(frame.MergeSeparators) do
		separator:Hide()
	end
end

---Shows multiple events with the same timing as one icon split into equal slices
---@param self AtAbilitySpellIcon
---@param members table|nil -- widgets of all merged events with this icon first, nil or a single member shows the icon normally
local SetMergedIcons        = function(self, members)
	local frame = self.frame
	local count = members and math.min(#members, variables.MaxMergedIcons) or 1
	local key
	if count > 1 then
		local ids = {}
		for i = 1, count do
			ids[i] = members[i].frame.eventInfo.id
		end
		key = table.concat(ids, ",")
	end
	if frame.mergeKey == key then return end
	frame.mergeKey = key
	if not key then
		hideMergeSlices(frame)
		frame.SpellIcon:Show()
		applyDefaultTextColor(frame)
		ApplySpellName(self, true)
		return
	end

	local width, height = frame:GetWidth(), frame:GetHeight()
	local sliceWidth = width / count
	-- same crop as the regular icon zoom, split horizontally
	local zoom = 1 - (private.GetElementStyle("SpellIcon").Zoom or 0)
	local minCoord, maxCoord = 0.5 - 0.5 * zoom, 0.5 + 0.5 * zoom
	local coordWidth = (maxCoord - minCoord) / count
	for i, slice in ipairs(frame.MergeSlices) do
		if i <= count then
			slice:ClearAllPoints()
			slice:SetPoint("TOPLEFT", frame, "TOPLEFT", (i - 1) * sliceWidth, 0)
			slice:SetSize(sliceWidth, height)
			slice:SetTexture(members[i].frame.eventInfo.iconFileID)
			slice:SetTexCoord(minCoord + (i - 1) * coordWidth, minCoord + i * coordWidth, minCoord, maxCoord)
			slice:Show()
		else
			slice:Hide()
		end
	end
	for i, separator in ipairs(frame.MergeSeparators) do
		if i < count then
			separator:ClearAllPoints()
			separator:SetPoint("TOP", frame, "TOPLEFT", i * sliceWidth, 0)
			separator:SetSize(private.GetElementStyle("SpellIcon").MergeSeparator.Width, height)
			separator:Show()
		else
			separator:Hide()
		end
	end
	frame.SpellIcon:Hide()
	if private.db.global.timeline_frame[private.ACTIVE_EDITMODE_LAYOUT].travel_direction ~= private.TIMELINE_DIRECTIONS.HORIZONTAL then
		applyDefaultTextColor(frame)
		frame.SpellName:SetText(string.format(private.getLocalisation("MultipleTimers"), count))
	end
end

---Sets the event info and all associated handling for an icon
---@param self AtAbilitySpellIcon
---@param eventInfo EncounterTimelineEventInfo
---@param disableOnUpdate boolean -- if true, the event specific textures will not be set (used for previews)
local SetEventInfo          = function(self, eventInfo, disableOnUpdate)
	self:ApplySettings()
	self.frame.eventInfo = eventInfo
	self.frame.SpellIcon:SetTexture(eventInfo.iconFileID)
	private.Debug("============================")
	ApplySpellName(self, disableOnUpdate)
	-- the position is updated by the timeline driver (see AbilityTimeline.lua) based on the zone of the icon
	self.frame.frameIsMoving = false
	if not disableOnUpdate then
		private.ThemeApply.PlayEnter(self.frame, private.GetElementStyle("SpellIcon").Enter, true, self.frame.SpellIcon,
			eventInfo.iconFileID)
		private.Debug("Setting event info for eventID: " .. eventInfo.id .. " with spell name: " .. eventInfo.spellName)
		if private.db.profile.icon_settings.dispellIcons then
			private.manager.SetEventIconTextures(eventInfo.id, 126, self.frame.dispellTypeIcons)
		end
		local borderColor = private.manager.getEventBorderColor(eventInfo.id)
		local border = private.GetElementStyle("SpellIcon").Border
		if private.db.profile.icon_settings.border == private.IconBorderSettings.dispell then
			for i in ipairs(private.dispellTypeList) do
				private.ThemeApply.DispelBorder(self.frame, i, border, eventInfo.id)
			end
		elseif private.db.profile.icon_settings.border == private.IconBorderSettings.bossmods and borderColor then
			private.Debug("Found border color for bossmods event, applying to border for timer event")
			private.ThemeApply.BossModsBorder(self.frame, border, borderColor)
		else
			private.Debug("No border color found for bossmods event, using no border for timer event".. eventInfo.id)
			private.ThemeApply.BossModsBorder(self.frame, border, nil)
		end

		if private.db.profile.icon_settings.roleIcons then
			private.manager.SetEventIconTextures(eventInfo.id, 896, self.frame.RoleIcons)
		end

		if private.db.profile.icon_settings.dangerIcon then
			private.manager.SetEventIconTextures(eventInfo.id, 1, self.frame.DangerIcon)
		end
	end
	self.frame:Show()

	if private.db.profile.icon_settings and private.db.profile.icon_settings.useTooltip and private.db.profile.icon_settings.useTooltip ~= Enum.EncounterEventsTooltipAnchor.Hidden then
		private.AddEventTooltip(self.frame, eventInfo, private.db.profile.icon_settings.useTooltip)
	end
end

local function ApplySettings(self)
	local frame = self.frame
	local style = private.GetElementStyle("SpellIcon")
	local iconSettings = private.db.profile.icon_settings
	frame:SetSize(style.Size, style.Size)
	handleAnchors(frame, frame.isStopped)
	private.ThemeApply.Font(frame.SpellName, style.Text.Font)
	private.ThemeApply.Font(frame.Cooldown, private.GetElementStyle("Cooldown").Font)

	if iconSettings.strata then
		frame:SetFrameStrata(iconSettings.strata)
	end

	private.ThemeApply.IconArt(frame, frame.SpellIcon, style, frame, private.SyncMasque(frame))
	for _, separator in ipairs(frame.MergeSeparators) do
		private.ThemeApply.Texture(separator, style.MergeSeparator)
	end

	local borderWidth = style.BorderWidth
	frame.BossModsBorderEdges[1]:SetHeight(borderWidth)
	frame.BossModsBorderEdges[2]:SetHeight(borderWidth)
	frame.BossModsBorderEdges[3]:SetWidth(borderWidth)
	frame.BossModsBorderEdges[4]:SetWidth(borderWidth)
	for _, edges in ipairs(frame.DispellTypeBorderEdges) do
		edges[1]:SetHeight(borderWidth)
		edges[2]:SetHeight(borderWidth)
		edges[3]:SetWidth(borderWidth)
		edges[4]:SetWidth(borderWidth)
		for _, edgeTexture in ipairs(edges) do
			edgeTexture:SetShown(iconSettings.border == private.IconBorderSettings.dispell)
		end
	end
	for i = 2, #frame.BorderGlows do
		frame.BorderGlows[i]:SetShown(iconSettings.border == private.IconBorderSettings.dispell and style.Border.Glow and true or false)
	end

	if iconSettings.border ~= private.IconBorderSettings.bossmods then
		private.ThemeApply.BossModsBorder(frame, style.Border, nil)
	end

	local dispelIcon = style.DispelIcon
	for _, texture in ipairs(frame.dispellTypeIcons) do
		texture:SetSize(dispelIcon.Size, dispelIcon.Size)
		texture:ClearAllPoints()
		texture:SetPoint(dispelIcon.Anchor, frame, dispelIcon.Anchor, dispelIcon.Offset.x, dispelIcon.Offset.y)
		texture:SetShown(iconSettings.dispellIcons)
	end
	for _, texture in ipairs(frame.DangerIcon) do
		texture:SetShown(iconSettings.dangerIcon)
	end

	for _, texture in ipairs(frame.RoleIcons) do
		texture:SetSize(style.RoleIcons.Size, style.RoleIcons.Size)
		texture:SetShown(iconSettings.roleIcons)
	end
	handleRoleIconAnchors(frame, frame.isStopped)

	local background = style.Text.Background
	if background.Show then
		frame.SpellNameBackground:SetPoint("LEFT", frame.SpellName, "LEFT", -background.Offset.x, 0)
		frame.SpellNameBackground:SetPoint("RIGHT", frame.SpellName, "RIGHT", background.Offset.x, 0)
		frame.SpellNameBackground:SetPoint("TOP", frame.SpellName, "TOP", 0, background.Offset.y)
		frame.SpellNameBackground:SetPoint("BOTTOM", frame.SpellName, "BOTTOM", 0, -background.Offset.y)
		private.ThemeApply.Texture(frame.SpellNameBackground, background)
		frame.SpellNameBackground:Show()
	else
		frame.SpellNameBackground:Hide()
	end

	-- the font color above replaced the event color of the spell name
	if frame.eventInfo and not frame.mergeKey then
		ApplySpellName(self, true)
	end
end

---@param self AtAbilitySpellIcon
local function OnAcquire(self)
	private.modernize()
	private.Debug(self.frame, "AT_ABILITY_SPELL_ICON_FRAME_ACQUIRED")
	ApplySettings(self)
end

---@param self AtAbilitySpellIcon
local function OnRelease(self)
	self.frame.eventInfo = nil
	self.frame.SpellIcon:SetTexture(nil)
	self.frame.SpellName:SetText("")
	self.frame.state = nil
	self.frame.isStopped = nil
	self.frame.zone = nil
	self.frame.mergeKey = nil
	self.frame.mergedInto = nil
	self.frame.displayRemaining = nil
	hideMergeSlices(self.frame)
	self.frame.SpellIcon:Show()
	handleAnchors(self.frame, false)
	self.frame:SetScript("OnUpdate", nil)
	self.frame.frameIsMoving = false
	private.ClearEventTooltip(self.frame)
	private.ThemeApply.BossModsBorder(self.frame, private.GetElementStyle("SpellIcon").Border, nil)
	private.StopGlow(self.frame)
	private.ThemeApply.StopPulse(self.frame)
end

local function Constructor()
	local count = AceGUI:GetNextWidgetNum(Type)
	local frame = CreateFrame("Frame", Type .. count, UIParent)
	frame:Show()

	-- spell icon
	frame.SpellIcon = frame:CreateTexture(nil, "BACKGROUND")
	frame.SpellIcon:SetAllPoints(frame)
	frame.SpellIcon:SetPoint("CENTER", frame, "CENTER")

	-- slices used while multiple events are merged into this icon
	frame.MergeSlices = {}
	frame.MergeSeparators = {}
	for i = 1, variables.MaxMergedIcons do
		local slice = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
		slice:Hide()
		table.insert(frame.MergeSlices, slice)
		if i < variables.MaxMergedIcons then
			local separator = frame:CreateTexture(nil, "BORDER")
			separator:Hide()
			table.insert(frame.MergeSeparators, separator)
		end
	end

	private.Debug(frame, Type .. count)
	
	frame:SetFrameStrata(private.FrameStrata.FULLSCREEN)
	local borderWidth = 3
	
	frame.BossModsBorderEdges = {}
	
	-- Top edge
	local topEdge = frame:CreateTexture(nil, "ARTWORK")
	topEdge:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
	topEdge:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
	topEdge:SetHeight(borderWidth)
	topEdge:Hide()
	
	-- Bottom edge
	local bottomEdge = frame:CreateTexture(nil, "ARTWORK")
	bottomEdge:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
	bottomEdge:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
	bottomEdge:SetHeight(borderWidth)
	bottomEdge:Hide()
	
	-- Left edge
	local leftEdge = frame:CreateTexture(nil, "ARTWORK")
	leftEdge:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
	leftEdge:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
	leftEdge:SetWidth(borderWidth)
	leftEdge:Hide()
	
	-- Right edge
	local rightEdge = frame:CreateTexture(nil, "ARTWORK")
	rightEdge:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
	rightEdge:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
	rightEdge:SetWidth(borderWidth)
	rightEdge:Hide()
	frame.BossModsBorderEdges = { topEdge, bottomEdge, leftEdge, rightEdge }
	-- spell name
	frame.SpellName = frame:CreateFontString(nil, "OVERLAY", "SystemFont_Shadow_Med3")
	frame.SpellName:Show()
	-- spell name background
	frame.SpellNameBackground = frame:CreateTexture(nil, "BACKGROUND")
	frame.SpellNameBackground:Hide()
	-- cooldown
	frame.Cooldown = frame:CreateFontString(nil, "OVERLAY", "SystemFont_Shadow_Med3")
	frame.Cooldown:SetPoint("CENTER", frame, "CENTER")

	frame.RoleIcons = {}

	for i = 1, 3 do
		local texture = frame:CreateTexture(nil, "OVERLAY", nil, 7)
		texture:SetPoint("LEFT", frame, "RIGHT", 18 * (i - 1), 0)
		texture:SetSize(variables.ExtraIcons.IconSize, variables.ExtraIcons.IconSize)
		texture:Show()
		table.insert(frame.RoleIcons, texture)
	end

	frame.DangerIcon = {}

	local dangerTexture = frame:CreateTexture(nil, "OVERLAY", nil, 7)
	dangerTexture:SetSize(variables.ExtraIcons.IconSize, variables.ExtraIcons.IconSize)
	dangerTexture:SetPoint("CENTER", frame, "TOPLEFT", 0, 0)
	dangerTexture:Show()
	table.insert(frame.DangerIcon, dangerTexture)

	frame.dispellTypeIcons = {}

	local dispellTypeTexture = frame:CreateTexture(nil, "OVERLAY", nil, 7)
	dispellTypeTexture:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -3, 3)
	dispellTypeTexture:SetSize(variables.ExtraIcons.IconSize, variables.ExtraIcons.IconSize)
	dispellTypeTexture:Show()
	table.insert(frame.dispellTypeIcons, dispellTypeTexture)

	frame.DispellTypeBorderEdges = {}

	for i, value in pairs(private.dispellTypeList) do
		local topTexture = frame:CreateTexture(nil, "ARTWORK")
		topTexture:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
		topTexture:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
		topTexture:SetHeight(3)
		topTexture:Show()

		-- Bottom edge
		local bottomTexture = frame:CreateTexture(nil, "ARTWORK")
		bottomTexture:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
		bottomTexture:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
		bottomTexture:SetHeight(3)
		bottomTexture:Show()

		-- Left edge
		local leftTexture = frame:CreateTexture(nil, "ARTWORK")
		leftTexture:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
		leftTexture:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
		leftTexture:SetWidth(3)
		leftTexture:Show()

		-- Right edge
		local rightTexture = frame:CreateTexture(nil, "ARTWORK")
		rightTexture:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
		rightTexture:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
		rightTexture:SetWidth(3)
		rightTexture:Show()

		frame.DispellTypeBorderEdges[i] = { topTexture, bottomTexture, leftTexture, rightTexture }
	end

	handleAnchors(frame, false)
	---@class AtAbilitySpellIcon : AceGUIWidget
	local widget = {
		OnAcquire = OnAcquire,
		OnRelease = OnRelease,
		type = Type,
		count = count,
		frame = frame,
		eventInfo = {},
		SetEventInfo = SetEventInfo,
		ApplySettings = ApplySettings,
		HandleCooldown = HandleCooldown,
		UpdateTimeline = UpdateTimeline,
		SetMergedIcons = SetMergedIcons,
		PlayHighlight = function(self) PlayHighlight(self.frame) end,
	}
	private.AddToMasque("TimelineIcons", frame, { Icon = frame.SpellIcon })
	private.RegisterThemed(widget)

	return AceGUI:RegisterAsWidget(widget)
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)
