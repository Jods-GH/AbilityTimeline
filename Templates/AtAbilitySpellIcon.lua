local addonName, private = ...
local AceGUI = LibStub("AceGUI-3.0")

local Type = "AtAbilitySpellIcon"
local Version = 1
local variables = {
	IconSize = {
		width = 44,
		height = 44,
	},
}

---@param self AtAbilitySpellIcon
local function OnAcquire(self)
	DevTool:AddData(self.frame, "AT_ABILITY_SPELL_ICON_FRAME_ACQUIRED")
	print("Acquiring AtAbilitySpellIcon")
end

---@param self AtAbilitySpellIcon
local function OnRelease(self)
	print("Releasing AtAbilitySpellIcon for event " .. self.eventInfo.id)
	self.frame.eventInfo = nil
	self.frame.SpellIcon:SetImage(nil)
	self.frame.SpellName:SetText("")
	self.frame:SetScript("OnUpdate", nil)
	self.frame.frameIsMoving = false
end

local getRawIconPosition          = function(iconSize, moveHeight, remainingDuration)
   if not (remainingDuration < AT_THRESHHOLD_TIME) then
      -- We are out of range of the moving timeline
      return 0, moveHeight + (iconSize / 2), false
   end
   local y = ((remainingDuration) / AT_THRESHHOLD_TIME) * moveHeight + (iconSize / 2)
   return 0, y, true
end
-- TODO FIX THIS
-- Currently the offset is ignored when calculating if a conflict is happening. The official timeline also does no conflict resolving and just overlaps icons so maybe we should do the same?
local calculateOffset             = function(iconSize, timelineHeight, sourceEventID, sourceTimeElapsed, rawSourcePosX,
                                             rawSourcePosY)
   local eventList = C_EncounterTimeline.GetEventList()
   local totalEvents = 0
   local conflictingEvents = 0
   local shorterConflictingEvents = 0
   local sourceEventInfo = C_EncounterTimeline.GetEventInfo(sourceEventID)
   local sourceRemainingTime = sourceEventInfo.duration - sourceTimeElapsed
   local sourceRemainingTimeInThreshold = sourceRemainingTime < AT_THRESHHOLD_TIME
   local sourceState = C_EncounterTimeline.GetEventState(sourceEventID)
   local sourceUpperXBound = rawSourcePosX + (iconSize / 2) + ICON_MARGIN
   local sourceLowerXBound = rawSourcePosX - (iconSize / 2) - ICON_MARGIN
   local sourceUpperYBound = rawSourcePosY + (iconSize / 2) + ICON_MARGIN
   local sourceLowerYBound = rawSourcePosY - (iconSize / 2) - ICON_MARGIN
   for _, eventID in pairs(eventList) do
      --print("-------")
      local state = C_EncounterTimeline.GetEventState(eventID)
      local timeElapsed = C_EncounterTimeline.GetEventTimeElapsed(eventID)
      local eventInfo = C_EncounterTimeline.GetEventInfo(eventID)
      local remainingTime = eventInfo.duration - timeElapsed
      if sourceState == state then
         totalEvents = totalEvents + 1
         local x, y = getRawIconPosition(iconSize, timelineHeight, remainingTime)
         local upperXBound = x + iconSize / 2 + ICON_MARGIN
         local lowerXBound = x - iconSize / 2 - ICON_MARGIN
         local upperYBound = y + iconSize / 2 + ICON_MARGIN
         local lowerYBound = y - iconSize / 2 - ICON_MARGIN
         --print("X " .. x .. ", Y " .. y)
         if TIMELINE_DIRECTION == TIMELINE_DIRECTIONS.VERTICAL then
            --print("Checking bounds")
            if upperYBound >= sourceLowerYBound and upperYBound <= sourceUpperYBound or
                lowerYBound >= sourceLowerYBound and lowerYBound <= sourceUpperYBound then
               --print("conflict detected")
               conflictingEvents = conflictingEvents + 1
               if remainingTime < sourceRemainingTime then
                  --print("shorter conflict detected")
                  shorterConflictingEvents = shorterConflictingEvents + 1
               end
            end
         else
            assert(false, "Horizontal timeline not implemented yet.")
         end
      end
   end
   return 0, shorterConflictingEvents * (iconSize + ICON_MARGIN)
end

local calculateIconPosition       = function(self, timeElapsed, moveHeight)
   local x, y, isMoving = getRawIconPosition(self:GetHeight(), moveHeight, self.eventInfo.duration - timeElapsed)
   if self.eventInfo.duration - timeElapsed > AT_THRESHHOLD_TIME then
      -- only add offset for waiting icons
      local xOffset, yOffset = calculateOffset(self:GetHeight(), moveHeight, self.eventInfo.id, timeElapsed, x, y)
      return x + xOffset, y + yOffset, isMoving
   end
   return x, y, isMoving
end

local PlayHighlight = function (self)
	print("Playing highlight for AtAbilitySpellIcon for event " .. self.eventInfo.id)
	self.Border:Show()
	C_Timer.After(0.5, function()
		self.Border:Hide()
	end)
end

local SetEventInfo = function(self, eventInfo)
	print("Setting event info for AtAbilitySpellIcon for event " .. eventInfo.id)
	self.frame.eventInfo = eventInfo
	self.frame.SpellIcon:SetImage(eventInfo.iconFileID)
	self.frame.SpellIcon:SetImage(eventInfo.iconFileID, private.GetZoom(self.frame.SpellIcon.image, private.ICON_ZOOM))
    self.frame.SpellName:SetText(string.format("%s in %s", eventInfo.spellName, eventInfo.id))
	self.frame.Cooldown:SetCooldown(GetTime(), eventInfo.duration)

	-- OnUpdate we want to update the position of the icon based on elapsed time
	local moveHeight = private.TIMELINE_FRAME:GetHeight() * 0.8
	self.frame.frameIsMoving = false
	self.frame:SetScript("OnUpdate", function(self)
		local timeElapsed = C_EncounterTimeline.GetEventTimeElapsed(self.eventInfo.id)
		if not timeElapsed or timeElapsed < 0 then timeElapsed = self.eventInfo.duration end

		local xPos, yPos, isMoving = calculateIconPosition(self, timeElapsed, moveHeight)
		if self.frameIsMoving ~= isMoving then
			if isMoving then
				--self.TrailAnimation:Play()
				--self.HighlightAnimation:Play()
			else
				--self.TrailAnimation:Stop()
			end
			self.frameIsMoving = isMoving
		end
		self:SetPoint("CENTER", private.TIMELINE_FRAME, "BOTTOM", xPos, yPos)
		for tick, time in ipairs(TIMELINE_TICKS) do
			local inRange = (eventInfo.duration - timeElapsed - time)
			if inRange < 0.01 and inRange > -0.01 then -- this is not gonna work if fps are to low
			-- self.IconContainer.HighlightAnimation:Play()
				PlayHighlight(self)
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
    frame:SetSize(variables.IconSize.width, variables.IconSize.height)
	
	-- spell icon
    frame.SpellIcon = AceGUI:Create("Icon")
	frame.SpellIcon:SetImageSize(variables.IconSize.width, variables.IconSize.height)
    frame.SpellIcon:SetPoint("CENTER", frame, "CENTER")
	frame.SpellIcon.frame:Show()
	
	-- border
	DevTool:AddData(frame, Type .. count)
	frame.Border = CreateFrame("Frame", nil, frame, "BackdropTemplate")
	local borderColor = {1, 0, 0}
	local borderWidth = 2
	frame.Border:SetPoint("CENTER", frame, "CENTER")
	frame.Border:SetSize(frame.SpellIcon.image:GetWidth(), frame.SpellIcon.image:GetHeight())
	frame.Border:SetFrameLevel(frame:GetFrameLevel() + 1)
	frame.Border.backdrop = {
		edgeFile = "Interface\\Buttons\\WHITE8x8",
		tileEdge = false,
		edgeSize = borderWidth,
		insets = {left = borderWidth, right = borderWidth, top = borderWidth, bottom = borderWidth},
	}
	frame.Border:SetBackdrop(frame.Border.backdrop)
	frame.Border:SetBackdropBorderColor(borderColor[1], borderColor[2], borderColor[3], 1)
	frame.Border:Hide()
	-- spell name
	frame.SpellName = AceGUI:Create("Label")
    frame.SpellName:SetPoint("RIGHT", frame, "LEFT", -10, 0)
    frame.SpellName.frame:Show()
	-- cooldown
	frame.Cooldown = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
	frame.Cooldown:SetDrawSwipe(false)
	frame.Cooldown:SetDrawEdge(false)
	frame.Cooldown:SetAllPoints(frame)
	
	frame:Show()


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