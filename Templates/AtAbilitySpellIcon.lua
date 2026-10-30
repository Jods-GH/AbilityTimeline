local appName, app = ...
---@class AbilityTimeline
local private = app
local AceGUI = LibStub("AceGUI-3.0")
local SharedMedia = LibStub("LibSharedMedia-3.0")
local Type = "AtAbilitySpellIcon"
local Version = 1
local variables = {
	IconSize = {
		width = 44,
		height = 44,
	},
	IconZoom = 0.7,
	TextOffset = {
		x = 10,
		y = 0,
	},
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
	local anchor = private.db.profile.icon_settings.roleIconAnchor
	if not anchor then return end
	local offset = private.db.profile.icon_settings.roleIconOffset or { x = 0, y = 0 }
	local size = private.db.profile.icon_settings.roleIconSize or variables.ExtraIcons.IconSize
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
	local relPos, anchorPos, xOffset, yOffset
	if isStopped then
		relPos = private.db.profile.text_settings.text_anchor
		anchorPos = private.RELATIVE_POSITIONS
			[private.db.profile.text_settings.text_anchor]
	else
		relPos = private.RELATIVE_POSITIONS[private.db.profile.text_settings.text_anchor]
		anchorPos = private.db.profile.text_settings.text_anchor
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

	if relPos == 'LEFT' then
		if private.db.profile.icon_settings and private.db.profile.icon_settings.TextOffset then
			xOffset = private.db.profile.icon_settings.TextOffset.x
			yOffset = private.db.profile.icon_settings.TextOffset.y
		else
			xOffset = variables.TextOffset.x
			yOffset = variables.TextOffset.y
		end
	elseif relPos == 'RIGHT' then
		if private.db.profile.icon_settings and private.db.profile.icon_settings.TextOffset then
			xOffset = -private.db.profile.icon_settings.TextOffset.x
			yOffset = -private.db.profile.icon_settings.TextOffset.y
		else
			xOffset = -variables.TextOffset.x
			yOffset = -variables.TextOffset.y
		end
	elseif relPos == 'TOP' then
		if private.db.profile.icon_settings and private.db.profile.icon_settings.TextOffset then
			xOffset = private.db.profile.icon_settings.TextOffset.y
			yOffset = -private.db.profile.icon_settings.TextOffset.x
		else
			xOffset = variables.TextOffset.y
			yOffset = -variables.TextOffset.x
		end
	else -- BOTTOM
		if private.db.profile.icon_settings and private.db.profile.icon_settings.TextOffset then
			xOffset = -private.db.profile.icon_settings.TextOffset.y
			yOffset = private.db.profile.icon_settings.TextOffset.x
		else
			xOffset = -variables.TextOffset.y
			yOffset = variables.TextOffset.x
		end
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
		if private.db.profile.text_settings.text_anchor == 'RIGHT' then
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

---Plays a short highlight animation
---@param self Frame
local PlayHighlight         = function(self)
	private.EnableGlow(self, private.GlowTypes.PROC, 0.5)
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
	if private.db.profile.cooldown_settings.cooldown_color then
		self.Cooldown:SetTextColor(
			private.db.profile.cooldown_settings.cooldown_color.r,
			private.db.profile.cooldown_settings.cooldown_color.g,
			private.db.profile.cooldown_settings.cooldown_color.b
		)
	else
		self.Cooldown:SetTextColor(1, 1, 1)
	end
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
		local iconSize = private.db.profile.icon_settings and private.db.profile.icon_settings.size or variables.IconSize.height
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
	local color = private.db.profile.text_settings and private.db.profile.text_settings.defaultColor
	if color then
		frame.SpellName:SetTextColor(color.r, color.g, color.b)
	else
		frame.SpellName:SetTextColor(1, 1, 1)
	end
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
	local zoom = 1 - (private.db.profile.icon_settings.zoom or 0)
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
			separator:SetSize(1, height)
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
		private.Debug("Setting event info for eventID: " .. eventInfo.id .. " with spell name: " .. eventInfo.spellName)
		if private.db.profile.icon_settings.dispellIcons then
			private.manager.SetEventIconTextures(eventInfo.id, 126, self.frame.dispellTypeIcons)
		end
		local borderColor = private.manager.getEventBorderColor(eventInfo.id)
		if private.db.profile.icon_settings.border == private.IconBorderSettings.dispell then
			for i, dispellValue in ipairs(private.dispellTypeList) do
				for _, edgeTexture in ipairs(self.frame.DispellTypeBorderEdges[i]) do
					private.manager.SetEventIconTextures(eventInfo.id, dispellValue.mask, { edgeTexture })
					edgeTexture:SetTexture(nil)
					edgeTexture:SetColorTexture(dispellValue.color.r, dispellValue.color.g, dispellValue.color.b,
						dispellValue.color.a)
				end
			end
		elseif private.db.profile.icon_settings.border == private.IconBorderSettings.bossmods and borderColor then
			private.Debug("Found border color for bossmods event, applying to border for timer event")
			for _, edgeTexture in pairs(self.frame.BossModsBorderEdges) do
                edgeTexture:SetColorTexture(borderColor.r, borderColor.g, borderColor.b, borderColor.a)
				edgeTexture:Show()
            end
		else
			private.Debug("No border color found for bossmods event, using no border for timer event".. eventInfo.id)
			for _, edgeTexture in pairs(self.frame.BossModsBorderEdges) do
				edgeTexture:Hide()
            end
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
	-- Apply settings to the icon
	if private.db.profile.icon_settings and private.db.profile.icon_settings.size then
		self.frame:SetSize(private.db.profile.icon_settings.size, private.db.profile.icon_settings.size)
	else
		self.frame:SetSize(variables.IconSize.width, variables.IconSize.height)
	end
	if private.db.profile.icon_settings and private.db.profile.icon_settings.TextOffset then
		handleAnchors(self.frame, self.frame.isStopped)
	end
	if private.db.profile.text_settings and private.db.profile.text_settings.font and private.db.profile.text_settings.fontSize and private.db.profile.text_settings.fontFlag then
		local fontFlags = ""
		for flag, isEnabled in pairs(private.db.profile.text_settings.fontFlag) do
			if isEnabled then
				if fontFlags ~= "" then
					fontFlags = fontFlags .. ",".. flag
				else
					fontFlags = flag
				end
			end
		end
		self.frame.SpellName:SetFont(SharedMedia:Fetch("font", private.db.profile.text_settings.font),
			private.db.profile.text_settings.fontSize, fontFlags)
			
	elseif private.db.profile.text_settings and private.db.profile.text_settings.font and private.db.profile.text_settings.fontSize then
		self.frame.SpellName:SetFont(SharedMedia:Fetch("font", private.db.profile.text_settings.font),
			private.db.profile.text_settings.fontSize, "OUTLINE")
	elseif private.db.profile.text_settings and private.db.profile.text_settings.fontSize then
		self.frame.SpellName:SetFontHeight(private.db.profile.text_settings.fontSize)
	end

	if private.db.profile.cooldown_settings and private.db.profile.cooldown_settings.font and private.db.profile.cooldown_settings.fontSize then
		self.frame.Cooldown:SetFont(SharedMedia:Fetch("font", private.db.profile.cooldown_settings.font),
			private.db.profile.cooldown_settings.fontSize, "OUTLINE")
	elseif private.db.profile.cooldown_settings and private.db.profile.cooldown_settings.fontSize then
		self.frame.Cooldown:SetFontHeight(private.db.profile.cooldown_settings.fontSize)
	end

	if private.db.profile.text_settings and private.db.profile.text_settings.defaultColor then
		self.frame.SpellName:SetTextColor(
			private.db.profile.text_settings.defaultColor.r,
			private.db.profile.text_settings.defaultColor.g,
			private.db.profile.text_settings.defaultColor.b
		)
	end

	if private.db.profile.text_settings and private.db.profile.text_settings.enableShadow then
		self.frame.SpellName:SetShadowColor(0, 0, 0, 1)
	else
		self.frame.SpellName:SetShadowColor(0, 0, 0, 0)
	end

	if private.db.profile.icon_settings and private.db.profile.icon_settings.strata then
		self.frame:SetFrameStrata(private.db.profile.icon_settings.strata)
	end

	if not self.frame.SpellIcon.zoomApplied or self.frame.SpellIcon.zoomApplied ~= (1 - private.db.profile.icon_settings.zoom) then
		if self.frame.SpellIcon.zoomApplied then
			private.ResetZoom(self.frame.SpellIcon)
		end
		private.SetZoom(self.frame.SpellIcon, 1 - private.db.profile.icon_settings.zoom)
		self.frame.SpellIcon.zoomApplied = 1 - private.db.profile.icon_settings.zoom
	end
	if private.db.profile.icon_settings.borderWidth then
		self.frame.BossModsBorderEdges[1]:SetHeight(private.db.profile.icon_settings.borderWidth)
		self.frame.BossModsBorderEdges[2]:SetHeight(private.db.profile.icon_settings.borderWidth)
		self.frame.BossModsBorderEdges[3]:SetWidth(private.db.profile.icon_settings.borderWidth)
		self.frame.BossModsBorderEdges[4]:SetWidth(private.db.profile.icon_settings.borderWidth)
	end
	for i, edges in ipairs(self.frame.DispellTypeBorderEdges) do
		if private.db.profile.icon_settings.borderWidth then
			edges[1]:SetHeight(private.db.profile.icon_settings.borderWidth)
			edges[2]:SetHeight(private.db.profile.icon_settings.borderWidth)
			edges[3]:SetWidth(private.db.profile.icon_settings.borderWidth)
			edges[4]:SetWidth(private.db.profile.icon_settings.borderWidth)
		end
		for _, edgeTexture in ipairs(edges) do
			if private.db.profile.icon_settings.border == private.IconBorderSettings.dispell then
				edgeTexture:Show()
			else
				edgeTexture:Hide()
			end
		end
	end

	if private.db.profile.icon_settings.border ~= private.IconBorderSettings.bossmods then
		for _, edgeTexture in pairs(self.frame.BossModsBorderEdges) do
			edgeTexture:Hide()
		end
	end

	for i, texture in ipairs(self.frame.dispellTypeIcons) do
		if private.db.profile.icon_settings.dispellIconSize then
			texture:SetSize(private.db.profile.icon_settings.dispellIconSize, private.db.profile.icon_settings.dispellIconSize)
		end
		texture:ClearAllPoints()
		if private.db.profile.icon_settings.dispellIconAnchor and private.db.profile.icon_settings.dispellIconOffset then
			texture:SetPoint(private.db.profile.icon_settings.dispellIconAnchor, self.frame, private.db.profile.icon_settings.dispellIconAnchor, private.db.profile.icon_settings.dispellIconOffset.x, private.db.profile.icon_settings.dispellIconOffset.y)
		elseif private.db.profile.icon_settings.dispellIconAnchor then
			texture:SetPoint(private.db.profile.icon_settings.dispellIconAnchor, self.frame, private.db.profile.icon_settings.dispellIconAnchor)
		end
		if private.db.profile.icon_settings.dispellIcons then
			texture:Show()
		else
			texture:Hide()
		end
	end
	for i, texture in ipairs(self.frame.DangerIcon) do
		if private.db.profile.icon_settings.dangerIcon then
			texture:Show()
		else
			texture:Hide()
		end
	end

	for i, texture in ipairs(self.frame.RoleIcons) do
		if private.db.profile.icon_settings.roleIconSize then
			texture:SetSize(private.db.profile.icon_settings.roleIconSize, private.db.profile.icon_settings.roleIconSize)
		end
		if private.db.profile.icon_settings.roleIcons then
			texture:Show()
		else
			texture:Hide()
		end
	end
	handleRoleIconAnchors(self.frame, self.frame.isStopped)
	if private.db.profile.text_settings.useBackground then
		local texture = SharedMedia:Fetch("background", private.db.profile.text_settings.backgroundTexture)
		self.frame.SpellNameBackground:SetPoint("LEFT", self.frame.SpellName, "LEFT",
			-private.db.profile.text_settings.backgroundTextureOffset.x, 0)
		self.frame.SpellNameBackground:SetPoint("RIGHT", self.frame.SpellName, "RIGHT",
			private.db.profile.text_settings.backgroundTextureOffset.x, 0)
		self.frame.SpellNameBackground:SetPoint("TOP", self.frame.SpellName, "TOP", 0,
			private.db.profile.text_settings.backgroundTextureOffset.y)
		self.frame.SpellNameBackground:SetPoint("BOTTOM", self.frame.SpellName, "BOTTOM", 0,
			-private.db.profile.text_settings.backgroundTextureOffset.y)
		self.frame.SpellNameBackground:SetTexture(texture)
		self.frame.SpellNameBackground:Show()
	else
		self.frame.SpellNameBackground:Hide()
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
	for _, edgeTexture in pairs(self.frame.BossModsBorderEdges) do
		edgeTexture:Hide()
	end
	private.StopGlow(self.frame)
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
			separator:SetColorTexture(0, 0, 0, 1)
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
	frame.SpellNameBackground:SetPoint("LEFT", frame.SpellName, "LEFT",
		-private.db.profile.text_settings.backgroundTextureOffset.x, 0)
	frame.SpellNameBackground:SetPoint("RIGHT", frame.SpellName, "RIGHT",
		private.db.profile.text_settings.backgroundTextureOffset.x, 0)
	frame.SpellNameBackground:SetPoint("TOP", frame.SpellName, "TOP", 0,
		private.db.profile.text_settings.backgroundTextureOffset.y)
	frame.SpellNameBackground:SetPoint("BOTTOM", frame.SpellName, "BOTTOM", 0,
		-private.db.profile.text_settings.backgroundTextureOffset.y)
	frame.SpellNameBackground:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
	frame.SpellNameBackground:Hide()
	-- cooldown
	frame.Cooldown = frame:CreateFontString(nil, "OVERLAY", "SystemFont_Shadow_Med3")
	frame.Cooldown:SetPoint("CENTER", frame, "CENTER")

	frame.RoleIcons = {}

	for i = 1, 3 do
		local texture = frame:CreateTexture(nil, "OVERLAY")
		texture:SetPoint("LEFT", frame, "RIGHT", 18 * (i - 1), 0)
		texture:SetSize(variables.ExtraIcons.IconSize, variables.ExtraIcons.IconSize)
		texture:Show()
		table.insert(frame.RoleIcons, texture)
	end

	frame.DangerIcon = {}

	local dangerTexture = frame:CreateTexture(nil, "OVERLAY")
	dangerTexture:SetSize(variables.ExtraIcons.IconSize, variables.ExtraIcons.IconSize)
	dangerTexture:SetPoint("CENTER", frame, "TOPLEFT", 0, 0)
	dangerTexture:Show()
	table.insert(frame.DangerIcon, dangerTexture)

	frame.dispellTypeIcons = {}

	local dispellTypeTexture = frame:CreateTexture(nil, "OVERLAY")
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

	return AceGUI:RegisterAsWidget(widget)
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)
