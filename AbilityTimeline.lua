local addonName, private = ...
local AceGUI = LibStub("AceGUI-3.0")


local activeFrames                = {}
private.ENCOUNTER_TIMELINE_EVENT_ADDED = function(self, eventInfo, initialState)
   if not private.TIMELINE_FRAME then
      private.createTimelineFrame()
   end
   if not private.TIMELINE_FRAME:IsVisible() then
      private.handleFrame(true)
   end
   private.createTimelineIcon(eventInfo)
end

TIMELINE_TICKS                    = { 5 }
AT_THRESHHOLD                     = 0.8
AT_THRESHHOLD_TIME                = 10
TIMELINE_DIRECTIONS               = {
   VERTICAL = "VERTICAL",
   HORIZONTAL = "HORIZONTAL"
}
TIMELINE_DIRECTION                = TIMELINE_DIRECTIONS.VERTICAL
ICON_MARGIN                       = 5

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

BIGICON_THRESHHOLD_TIME          = 5

private.createTimelineIcon             = function(eventInfo)
   local frame = private.ICON_POOL:Acquire()
   activeFrames[eventInfo.id] = frame
   frame:SetToDefaults() -- Reset the frame to default state
   frame.eventInfo = eventInfo

   frame:SetParent(private.TIMELINE_FRAME)
   frame:SetSize(40, 40)
   frame:SetPoint("CENTER", private.TIMELINE_FRAME, "CENTER")
   if frame.SpellName then
      frame.SpellName:Hide()
      frame.SpellName = nil
   end

   frame.SpellName = frame:CreateFontString(nil, "OVERLAY", "SystemFont_Shadow_Med3")
   frame.SpellName:SetPoint("RIGHT", frame, "LEFT", -10, 0)
   frame.SpellName:SetText(C_Spell.GetSpellName(eventInfo.tooltipSpellID))
   --frame:PlayCancelAnimation()
   frame:PlayIntroAnimation()
   --frame.TrailAnimation:Play()
   --frame:PlayHighlightAnimation()
   frame.Cooldown = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
   frame.Cooldown:SetDrawSwipe(false)
   frame.Cooldown:SetDrawEdge(false)
   frame.Cooldown:SetCooldown(GetTime(), eventInfo.duration)
   -- OnUpdate we want to update the position of the icon based on elapsed time
   local moveHeight = private.TIMELINE_FRAME:GetHeight() * 0.8
   frame.frameIsMoving = false
   frame:SetScript("OnUpdate", function(self)
      local timeElapsed = C_EncounterTimeline.GetEventTimeElapsed(self.eventInfo.id)
      if not timeElapsed or timeElapsed < 0 then timeElapsed = self.eventInfo.duration end

      local xPos, yPos, isMoving = calculateIconPosition(self, timeElapsed, moveHeight)
      if frame.frameIsMoving ~= isMoving then
         if isMoving then
            self.TrailAnimation:Play()
         else
            self.TrailAnimation:Stop()
         end
         frame.frameIsMoving = isMoving
      end
      self:SetPoint("CENTER", private.TIMELINE_FRAME, "BOTTOM", xPos, yPos)
      for tick, time in ipairs(TIMELINE_TICKS) do
         local inRange = (eventInfo.duration - timeElapsed - time)
         if inRange < 0.01 and inRange > -0.01 then -- this is not gonna work if fps are to low
            self.IconContainer.HighlightAnimation:Play()
         end
      end
      local inBigIconRange = (eventInfo.duration - timeElapsed - BIGICON_THRESHHOLD_TIME)
      if inBigIconRange < 0.01 and inBigIconRange > -0.01 then -- this is not gonna work if fps are to low
         private.TRIGGER_HIGHLIGHT(self.eventInfo)
      end
   end)

   -- On cooldown done we want to show a fadeout and then remove the icon from the pool
   -- frame.Cooldown:SetScript("OnCooldownDone", function(self)
   --    frame.fadeOutStarted = GetTime()
   --    local fadeoutDuration = 0.2
   --    -- frame:SetScript("OnUpdate", function(self)
   --    --    local alpha = 1 - (GetTime() - self.fadeOutStarted) / fadeoutDuration
   --    --    self:SetAlpha(alpha)
   --    --    self:SetSize(40 + 20 * (1 - alpha), 40 + 20 * (1 - alpha))
   --    -- end)
   --    frame:PlayFinishAnimation()
   --    C_Timer.After(fadeoutDuration, function()
   --       private.ICON_POOL:Release(frame)
   --       print("Icon removed from timeline.")
   --    end)
   -- end)
   frame.Cooldown:SetAllPoints(frame)
   frame:Show()
   frame.IconContainer.SpellIcon = frame:CreateTexture(nil, "BACKGROUND")

   frame.IconContainer.SpellIcon:SetAllPoints(frame)
   frame.IconContainer.SpellIcon:SetTexture(eventInfo.iconFileID)
   private.ZetZoom(frame.IconContainer.SpellIcon, private.ICON_ZOOM)

   DevTool:AddData(frame, "AT_TIMELINE_ICON")
   -- frame.border:SetVertexColor(DebuffTypeColor[eventInfo.dispelType])
end

ENCOUNTER_STATES                  = {
   Active = 0,
   Paused = 1,
   Finished = 2,
   Canceled = 3,
}

local function removeFrame(eventID, animation)
   local frame = activeFrames[eventID]
   if frame then
      frame[animation](frame)
      C_Timer.After(0.2, function()
         frame.Trail:SetAlpha(0);
         frame:SetCountdownDuration(0);
         frame:SetCountdownPaused(false);
         frame:SetIconTexture(nil);
         frame:SetSpellName(nil);
         frame:StopAnimations();
         frame:Reset()
         private.ICON_POOL:Release(frame)
         activeFrames[eventID] = nil
      end)
   end
end

private.ENCOUNTER_TIMELINE_EVENT_STATE_CHANGED = function(self, eventID, newState)
   if newState == ENCOUNTER_STATES.Finished then
      removeFrame(eventID, 'PlayFinishAnimation')
   elseif newState == ENCOUNTER_STATES.Canceled then
      removeFrame(eventID, 'PlayCancelAnimation')
   elseif newState == ENCOUNTER_STATES.Paused then
      local frame = activeFrames[eventID]
      if frame then
         local eventInfo = C_EncounterTimeline.GetEventInfo(eventID)
         frame.Cooldown:Pause()
         frame:SetPoint("LEFT", private.TIMELINE_FRAME, "RIGHT", 10, 0)
         if frame.SpellName then
            frame.SpellName:Hide()
            frame.SpellName = nil
         end
         frame.SpellName = frame:CreateFontString(nil, "OVERLAY", "SystemFont_Shadow_Med3")
         frame.SpellName:SetPoint("LEFT", frame, "RIGHT", 10, 0)
         frame.SpellName:SetText(C_Spell.GetSpellName(eventInfo.tooltipSpellID))
      end
   elseif newState == ENCOUNTER_STATES.Active then
      local frame = activeFrames[eventID]
      if frame then
         local eventInfo = C_EncounterTimeline.GetEventInfo(eventID)
         frame.Cooldown:Resume()
         frame:SetPoint("CENTER", private.TIMELINE_FRAME, "CENTER")
         frame:SetScript("OnUpdate", function(self)
            local timeElapsed = C_EncounterTimeline.GetEventTimeElapsed(eventID)
            if not timeElapsed or timeElapsed < 0 then timeElapsed = eventInfo.duration end
            local y = (timeElapsed / eventInfo.duration) * private.TIMELINE_FRAME:GetHeight() - frame:GetHeight() / 2
            frame:SetPoint("CENTER", private.TIMELINE_FRAME, "TOP", 0, -y)
         end)
         if frame.SpellName then
            frame.SpellName:Hide()
            frame.SpellName = nil
         end
         frame.SpellName = frame:CreateFontString(nil, "OVERLAY", "SystemFont_Shadow_Med3")
         frame.SpellName:SetPoint("RIGHT", frame, "LEFT", -10, 0)
         frame.SpellName:SetText(C_Spell.GetSpellName(eventInfo.tooltipSpellID))
      end
   end
end

private.BIG_ICONS = {}

private.HIGHLIGHT_EVENTS = {
   BigIcons = {},
   HighlightTexts = {}
}

private.evaluateIconPositions = function()
   local visibleIcons = 0
   table.sort(private.BIG_ICONS, function(a, b) return a.eventInfo.duration < b.eventInfo.duration end)
   for i, frame in ipairs(private.BIG_ICONS) do
      if frame and frame:IsShown() then
         local xOffset = (private.BIG_ICON_SIZE + private.BIG_ICON_MARGIN) * (visibleIcons)
         if frame.xOffset ~=  xOffset then
            frame.xOffset = xOffset
            frame:SetPoint("LEFT", private.BIGICON_FRAME, "LEFT", xOffset, 0)
         end
         visibleIcons = visibleIcons + 1
      end
   end
end

local function zoomAroundCenter(u, c, zoom)
   return c + (u - c) * zoom
end

local function clamp(v, lo, hi)
   if v < lo then return lo end
   if v > hi then return hi end
   return v
end

private.ZetZoom = function(icon, zoom)
   -- get existing texcoords (ULx, ULy, LLx, LLy, URx, URy, LRx, LRy)
local ULx, ULy, LLx, LLy, URx, URy, LRx, LRy = icon:GetTexCoord()

-- build min/max and center (handles non-full textures / atlas subrects)
local minU = math.min(ULx, LLx, URx, LRx)
local maxU = math.max(ULx, LLx, URx, LRx)
local minV = math.min(ULy, LLy, URy, LRy)
local maxV = math.max(ULy, LLy, URy, LRy)

local centerU = (minU + maxU) * 0.5
local centerV = (minV + maxV) * 0.5

local nULx = clamp(zoomAroundCenter(ULx, centerU, zoom), 0, 1)
local nULy = clamp(zoomAroundCenter(ULy, centerV, zoom), 0, 1)
local nLLx = clamp(zoomAroundCenter(LLx, centerU, zoom), 0, 1)
local nLLy = clamp(zoomAroundCenter(LLy, centerV, zoom), 0, 1)
local nURx = clamp(zoomAroundCenter(URx, centerU, zoom), 0, 1)
local nURy = clamp(zoomAroundCenter(URy, centerV, zoom), 0, 1)
local nLRx = clamp(zoomAroundCenter(LRx, centerU, zoom), 0, 1)
local nLRy = clamp(zoomAroundCenter(LRy, centerV, zoom), 0, 1)

icon:SetTexCoord(nULx, nULy, nLLx, nLLy, nURx, nURy, nLRx, nLRy)
end

private.BIG_ICON_SIZE = 100
private.BIG_ICON_MARGIN = 10
private.ICON_ZOOM = 0.7
private.BIG_ICON_COOLDOWN_SCALE = 2
private.createBigIcon = function(eventInfo)
   local frame = CreateFrame("Frame", "BIGICON"..eventInfo.id, private.BIGICON_FRAME) -- TODO CHANGE THIS TO ICON POOL with template
   frame.eventInfo = eventInfo
   frame.Cooldown = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
   frame.Cooldown:SetDrawSwipe(true)
   frame.Cooldown:SetDrawEdge(true)
   frame.Cooldown:SetAllPoints(frame)
   frame.Cooldown:SetScale(private.BIG_ICON_COOLDOWN_SCALE)
   frame.Cooldown:SetCooldown(GetTime(), eventInfo.duration - C_EncounterTimeline.GetEventTimeElapsed(eventInfo.id))
   frame.Cooldown:SetScript("OnCooldownDone", function(self)
      print('hiding bigion')

      frame:Hide()
      private.HIGHLIGHT_EVENTS.BigIcons[eventInfo.id] = nil
      for i, f in ipairs(private.BIG_ICONS) do
         if f == frame then
            print("Removing big icon for event " .. eventInfo.id)
            table.remove(private.BIG_ICONS, i)
            break
         end
      end
      private.evaluateIconPositions()
   end)
   local xOffset = (private.BIG_ICON_SIZE + private.BIG_ICON_MARGIN) * (#private.BIG_ICONS)
   frame:SetPoint("LEFT", private.BIGICON_FRAME, "LEFT", xOffset, 0)
   frame.xOffset = xOffset
   frame:SetSize(private.BIG_ICON_SIZE, private.BIG_ICON_SIZE)
   --frame:SetCooldown(GetTime(),eventInfo.duration - C_EncounterTimeline.GetEventTimeElapsed(eventInfo.id))
   frame.icon = frame:CreateTexture(nil, "OVERLAY")
   private.ZetZoom(frame.icon, private.ICON_ZOOM)
   frame.icon:SetAllPoints(frame)
   frame.icon:SetTexture(eventInfo.iconFileID)
   frame.iconText = frame:CreateFontString(nil, "OVERLAY", "SystemFont_Shadow_Med3")
   frame.iconText:SetWidth(95)
   frame.iconText:SetWordWrap(true)
   frame.iconText:SetPoint("TOP", frame, "BOTTOM", 0, -10)
   frame.iconText:SetText(C_Spell.GetSpellName(eventInfo.tooltipSpellID))
   frame:Show()
   -- frame:SetScript("OnClick", function(self)
   --    print("Big icon clicked for event " .. self.eventInfo.id)
   -- end)
   frame:EnableMouse(true)
   private.HIGHLIGHT_EVENTS.BigIcons[eventInfo.id] = true
   table.insert(private.BIG_ICONS, frame)
   DevTool:AddData(frame, "AT_BIGICON_FRAME_" .. eventInfo.id)
   private.evaluateIconPositions()
end

USE_BIGICONS = true
USE_HIGHLIGHTTEXT = true
private.TRIGGER_HIGHLIGHT = function(eventInfo)
   if USE_BIGICONS and not private.HIGHLIGHT_EVENTS.BigIcons[eventInfo.id] then
       private.createBigIcon(eventInfo)
   end
   if USE_HIGHLIGHTTEXT and not private.HIGHLIGHT_EVENTS.HighlightTexts[eventInfo.id] then
      private.createTextHighlight(eventInfo)
   end
   
end
private.ENCOUNTER_TIMELINE_EVENT_REMOVED = function()
   if C_EncounterTimeline.HasAnyEvents() then
   else
      print("No more events in the timeline, hiding frame.")
      private.handleFrame(false)
   end
end

local resetIconFrame = function(pool, frame)
   frame.IconContainer.HighlightAnimation:Stop();
   frame:SetScript("OnUpdate", nil)
   frame:SetAlpha(1)
end

private.createIconPool = function()
   if not private.ICON_POOL then
      private.ICON_POOL = CreateFramePool("Frame", private.TIMELINE_FRAME, "AbilityTimelineIconTemplate", resetIconFrame)
   end
end

private.createTimelineFrame = function()
   private.TIMELINE_FRAME = CreateFrame("Frame", "AbilityTimelineFrame", UIParent, "BackdropTemplate")
   private.TIMELINE_FRAME:SetPoint("CENTER")
   private.TIMELINE_FRAME:SetWidth(60)
   private.TIMELINE_FRAME:SetHeight(500)
   private.TIMELINE_FRAME:SetBackdrop({
      bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
      tile = true,
      tileSize = 32,
      edgeSize = 32,
      insets = { left = 11, right = 12, top = 12, bottom = 11 }
   })
   private.TIMELINE_FRAME:SetBackdropColor(0, 0, 0, 1)
   private.TIMELINE_FRAME.Ticks = {}


   local moveHeight = private.TIMELINE_FRAME:GetHeight() * 0.8
   local left, bottom, width, height = private.TIMELINE_FRAME:GetBoundsRect()
   for i, tick in ipairs(TIMELINE_TICKS) do
      local tickLine = private.TIMELINE_FRAME:CreateTexture(nil, "ARTWORK")
      local tickPosition = (tick / AT_THRESHHOLD_TIME) * moveHeight
      tickLine:SetColorTexture(1, 1, 1, 1)
      tickLine:SetHeight(1)
      tickLine:SetPoint("LEFT", private.TIMELINE_FRAME, "BOTTOMLEFT", 0, tickPosition)
      tickLine:SetPoint("RIGHT", private.TIMELINE_FRAME, "BOTTOMRIGHT", 0, tickPosition)
      local tickText = private.TIMELINE_FRAME:CreateFontString(nil, "OVERLAY", "SystemFont_Shadow_Med3")
      tickText:SetPoint("LEFT", tickLine, "RIGHT", 5, 0)
      tickText:SetText(tick .. "s")
      tickLine.tickText = tickText
      private.TIMELINE_FRAME.Ticks[i] = tickLine
   end
   private.TIMELINE_FRAME:Show()
   private.TIMELINE_FRAME:EnableMouse(true)
   private.TIMELINE_FRAME:SetMovable(true)
   private.TIMELINE_FRAME:RegisterForDrag("LeftButton")
   private.TIMELINE_FRAME:SetScript("OnDragStart", function(self) self:StartMoving() end)
   private.TIMELINE_FRAME:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
   DevTool:AddData(private.TIMELINE_FRAME, "AT_TIMELINE_FRAME")
   private.createIconPool()


   private.BIGICON_FRAME = CreateFrame("Frame", "AbilityTimelineBigIconFrame", UIParent)
   private.BIGICON_FRAME:SetPoint("TOP", private.TIMELINE_FRAME, "BOTTOM", 30, -10)
   private.BIGICON_FRAME:SetWidth(private.BIG_ICON_SIZE)
   private.BIGICON_FRAME:SetHeight(private.BIG_ICON_SIZE)
   private.BIGICON_FRAME:Show()
   DevTool:AddData(private.BIGICON_FRAME, "AT_BIGICON_FRAME")


   private.TEXT_HIGHLIGHT_FRAME = CreateFrame("Frame", "AbilityTimelineTextHighlightFrame", UIParent)
   private.TEXT_HIGHLIGHT_FRAME:SetPoint("CENTER", UIParent, "CENTER")
   private.TEXT_HIGHLIGHT_FRAME:SetWidth(private.TEXT_HIGHLIGHT_WIDTH)
   private.TEXT_HIGHLIGHT_FRAME:SetHeight(private.TEXT_HIGHLIGHT_HEIGHT)
   private.TEXT_HIGHLIGHT_FRAME:Show()

   DevTool:AddData(private.TEXT_HIGHLIGHT_FRAME, "AT_TEXT_HIGHLIGHT_FRAME")
end

private.handleFrame = function(show)
   if show then
      if not private.TIMELINE_FRAME then
         private.createTimelineFrame()
      end
      private.TIMELINE_FRAME:Show()
   else
      if private.TIMELINE_FRAME then
         private.TIMELINE_FRAME:Hide()
      end
   end
end
