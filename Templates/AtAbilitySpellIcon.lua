local addonName, private = ...
local AceGUI = LibStub("AceGUI-3.0")
local CustomGlow = LibStub("LibCustomGlow-1.0")
local Type = "AtAbilitySpellIcon"
local Version = 1
local variables = {
	IconSize = {
		width = 44,
		height = 44,
	},
	IconMargin = 5,
	IconZoom = 0.7,
}

---@param self AtAbilitySpellIcon
local function OnAcquire(self)
	private.Debug(self.frame, "AT_ABILITY_SPELL_ICON_FRAME_ACQUIRED")
end

---@param self AtAbilitySpellIcon
local function OnRelease(self)
	self.frame.eventInfo = nil
	self.frame.SpellIcon:SetTexture(nil)
	self.frame.SpellName:SetText("")
	self.frame:SetScript("OnUpdate", nil)
	self.frame.frameIsMoving = false
end

local getRawIconPosition = function(iconSize, moveHeight, remainingDuration, isStopped)
	local x = 0
	if isStopped then
		x = variables.IconSize.width + variables.IconMargin
	end
	if not (remainingDuration < private.AT_THRESHHOLD_TIME) then
		-- We are out of range of the moving timeline
		return x, moveHeight + (iconSize / 2), false
	end
	local y = ((remainingDuration) / private.AT_THRESHHOLD_TIME) * moveHeight + (iconSize / 2)
	return x, y, true
end


---set state to blocked for blocked events
---@param eventID any
---@param duration any
---@param timeElapsed any
---@param timeRemaining any
---@return EncounterTimelineEventState state
local fixStateForBlocked = function(eventID, duration, timeElapsed, timeRemaining)
	local state = C_EncounterTimeline.GetEventState(eventID)
	local isBlocked = C_EncounterTimeline.IsEventBlocked(eventID)
	if state == private.ENCOUNTER_STATES.Active and isBlocked then
		return private.ENCOUNTER_STATES.Blocked
	elseif timeRemaining == 0 or timeElapsed >= duration then
		return private.ENCOUNTER_STATES.Blocked
	else
		return state
	end
end

local function isStoppedForPosition(state)
	return state == private.ENCOUNTER_STATES.Paused or state == private.ENCOUNTER_STATES.Blocked
end

-- TODO FIX THIS
-- Currently the offset is ignored when calculating if a conflict is happening. The official timeline also does no conflict resolving and just overlaps icons so maybe we should do the same?
local calculateOffset = function(iconSize, timelineHeight, sourceEventID, sourceTimeElapsed, rawSourcePosX,
								 rawSourcePosY)
	local eventList = C_EncounterTimeline.GetEventList()
	local totalEvents = 0
	local conflictingEvents = 0
	local shorterConflictingEvents = 0
	local sourceEventInfo = C_EncounterTimeline.GetEventInfo(sourceEventID)
	local sourceRemainingTime = C_EncounterTimeline.GetEventTimeRemaining(sourceEventID)
	local sourceRemainingTimeInThreshold = sourceRemainingTime < private.AT_THRESHHOLD_TIME
	local sourceState = fixStateForBlocked(sourceEventID, sourceEventInfo.duration, sourceTimeElapsed,
		sourceRemainingTime)
	local sourceUpperXBound = rawSourcePosX + (iconSize / 2) + variables.IconMargin
	local sourceLowerXBound = rawSourcePosX - (iconSize / 2) - variables.IconMargin
	local sourceUpperYBound = rawSourcePosY + (iconSize / 2) + variables.IconMargin
	local sourceLowerYBound = rawSourcePosY - (iconSize / 2) - variables.IconMargin
	for _, eventID in pairs(eventList) do
		--print("-------")
		if eventID ~= sourceEventID then
			local timeElapsed = C_EncounterTimeline.GetEventTimeElapsed(eventID)
			local eventInfo = C_EncounterTimeline.GetEventInfo(eventID)
			local remainingTime = C_EncounterTimeline.GetEventTimeRemaining(eventID)
			local state = fixStateForBlocked(eventID, eventInfo.duration, timeElapsed, remainingTime)
			if sourceState == state then
				totalEvents = totalEvents + 1
				local x, y = getRawIconPosition(iconSize, timelineHeight, remainingTime,
					isStoppedForPosition(state))
				local upperXBound = x + iconSize / 2 + variables.IconMargin
				local lowerXBound = x - iconSize / 2 - variables.IconMargin
				local upperYBound = y + iconSize / 2 + variables.IconMargin
				local lowerYBound = y - iconSize / 2 - variables.IconMargin
				--print("X " .. x .. ", Y " .. y)
				if TIMELINE_DIRECTION == TIMELINE_DIRECTIONS.VERTICAL then
					--print("Checking bounds")
					if upperYBound >= sourceLowerYBound and upperYBound <= sourceUpperYBound or
						lowerYBound >= sourceLowerYBound and lowerYBound <= sourceUpperYBound then
						--print("conflict detected")
						conflictingEvents = conflictingEvents + 1
						-- use eventID as tiebreaker to have a consistent order
						if remainingTime < sourceRemainingTime or (remainingTime == sourceRemainingTime and eventID < sourceEventID) then
							--print("shorter conflict detected")
							shorterConflictingEvents = shorterConflictingEvents + 1
						end
					end
				else
					assert(false, "Horizontal timeline not implemented yet.")
				end
			end
		end
	end
	return 0, shorterConflictingEvents * (iconSize + variables.IconMargin)
end


local calculateIconPosition = function(self, timeElapsed, moveHeight, isStopped)
	local x, y, isMoving = getRawIconPosition(variables.IconSize.height, moveHeight,
		self.eventInfo.duration - timeElapsed, isStopped)
	if self.eventInfo.duration - timeElapsed > private.AT_THRESHHOLD_TIME or isStopped then
		-- only add offset for waiting icons
		local xOffset, yOffset = calculateOffset(variables.IconSize.height, moveHeight, self.eventInfo.id, timeElapsed, x,
			y)
		return x + xOffset, y + yOffset, isMoving
	end
	return x, y, isMoving
end

local PlayHighlight         = function(self)
	CustomGlow.ProcGlow_Start(self)
	C_Timer.After(0.5, function()
		CustomGlow.ProcGlow_Stop(self)
	end)
end
local SetEventInfo          = function(self, eventInfo)
	self.frame.eventInfo = eventInfo
	self.frame.SpellIcon:SetTexture(eventInfo.iconFileID)
	if not self.frame.SpellIcon.zoomApplied then
		private.SetZoom(self.frame.SpellIcon, variables.IconZoom)
		self.frame.SpellIcon.zoomApplied = true
	end
	self.frame.SpellName:SetText(eventInfo.spellName)
	self.frame.Cooldown:SetCooldown(GetTime(), eventInfo.duration)

	-- OnUpdate we want to update the position of the icon based on elapsed time
	self.frame.frameIsMoving = false
	self.frame:SetScript("OnUpdate", function(self)
		local timeElapsed = C_EncounterTimeline.GetEventTimeElapsed(self.eventInfo.id)
		local timeRemaining = C_EncounterTimeline.GetEventTimeRemaining(self.eventInfo.id)
		local state = fixStateForBlocked(self.eventInfo.id, self.eventInfo.duration, timeElapsed, timeRemaining)
		local isStopped = isStoppedForPosition(state)
		if not timeElapsed or timeElapsed < 0 then timeElapsed = self.eventInfo.duration end
		if not timeRemaining or timeRemaining < 0 then timeRemaining = 0 end
		if state ~= self.state then
			self.state = state
			self.SpellName:ClearAllPoints()
			if isStopped then
				self.SpellName:SetPoint("LEFT", self, "RIGHT", 10, 0)
			else
				self.SpellName:SetPoint("RIGHT", self, "LEFT", -10, 0)
			end
		elseif state == private.ENCOUNTER_STATES.Paused then
			return
		end

		local xPos, yPos, isMoving = calculateIconPosition(self, timeElapsed, private.TIMELINE_FRAME:GetHeight(), isStopped)
		if self.frameIsMoving ~= isMoving then
			if isMoving then
				--self.TrailAnimation:Play()
				--self.HighlightAnimation:Play()
			else
				--self.TrailAnimation:Stop()
			end
			self.frameIsMoving = isMoving
		end
		self:SetPoint("CENTER", private.TIMELINE_FRAME.frame, "BOTTOM", xPos, yPos)
		for tick, time in ipairs(private.TIMELINE_TICKS) do
			local inRange = (eventInfo.duration - timeElapsed - time)
			if inRange < 0.01 and inRange > -0.01 then -- this is not gonna work if fps are to low
				-- self.IconContainer.HighlightAnimation:Play()
				PlayHighlight(self)
			end
		end

		for time, color in pairs(private.TIMER_COLORS) do
			-- TODO this requires some refactor of how we display cooldowns to actually use a fontstring we can change the color for
			if (timeRemaining <= time) then
				--self.Cooldown:SetTextColor(color[1], color[2], color[3])
				break
			end
		end
		local inBigIconRange = (eventInfo.duration - timeElapsed - BIGICON_THRESHHOLD_TIME)
		if inBigIconRange < 0.01 and inBigIconRange > -0.01 then -- this is not gonna work if fps are to low
			private.TRIGGER_HIGHLIGHT(self.eventInfo)
		end
	end)
	self.frame:Show()
end

local function Constructor()
	local count = AceGUI:GetNextWidgetNum(Type)
	local frame = CreateFrame("Frame", Type .. count, UIParent)
	frame:Show()
	frame:SetSize(variables.IconSize.width, variables.IconSize.height)

	-- spell icon
	frame.SpellIcon = frame:CreateTexture(nil, "BACKGROUND")
	frame.SpellIcon:SetAllPoints(frame)
	frame.SpellIcon:SetPoint("CENTER", frame, "CENTER")

	-- border
	private.Debug(frame, Type .. count)

	--TODO this is supposed to be showing stuff like debufftype or importance
	frame.Border = CreateFrame("Frame", nil, frame, "BackdropTemplate")
	local borderColor = { 1, 0, 0 }
	local borderWidth = 2
	frame.Border:SetPoint("CENTER", frame, "CENTER")
	frame.Border:SetAllPoints(frame)
	frame.Border:SetFrameLevel(frame:GetFrameLevel() + 1)
	frame.Border.backdrop = {
		edgeFile = "Interface\\Buttons\\WHITE8x8",
		tileEdge = false,
		edgeSize = borderWidth,
		insets = { left = borderWidth, right = borderWidth, top = borderWidth, bottom = borderWidth },
	}
	frame.Border:SetBackdrop(frame.Border.backdrop)
	frame.Border:SetBackdropBorderColor(borderColor[1], borderColor[2], borderColor[3], 1)
	frame.Border:Hide()
	-- spell name
	frame.SpellName = frame:CreateFontString(nil, "OVERLAY", "SystemFont_Shadow_Med3")
	frame.SpellName:SetPoint("RIGHT", frame, "LEFT", -10, 0)
	frame.SpellName:Show()
	-- cooldown
	frame.Cooldown = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
	frame.Cooldown:SetDrawSwipe(false)
	frame.Cooldown:SetDrawEdge(false)
	frame.Cooldown:SetAllPoints(frame)
	frame.Cooldown:Show()

	---@class AtAbilitySpellIcon : AceGUIWidget
	local widget = {
		OnAcquire = OnAcquire,
		OnRelease = OnRelease,
		type = Type,
		count = count,
		frame = frame,
		eventInfo = {},
		SetEventInfo = SetEventInfo,
	}

	return AceGUI:RegisterAsWidget(widget)
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)
