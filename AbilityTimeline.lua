local addonName, private = ...
local AceGUI = LibStub("AceGUI-3.0")


local activeFrames                     = {}
private.ENCOUNTER_TIMELINE_EVENT_ADDED = function(self, eventInfo, initialState)
   if not private.TIMELINE_FRAME then
      private.createTimelineFrame()
   end
   if not private.TIMELINE_FRAME:IsVisible() then
      private.handleFrame(true)
   end
   private.createTimelineIcon(eventInfo)
end

private.TIMELINE_TICKS                         = { 5 }
private.AT_THRESHHOLD                          = 0.8
private.AT_THRESHHOLD_TIME                     = 10
TIMELINE_DIRECTIONS                    = {
   VERTICAL = "VERTICAL",
   HORIZONTAL = "HORIZONTAL"
}
TIMELINE_DIRECTION                     = TIMELINE_DIRECTIONS.VERTICAL
ICON_MARGIN                            = 5
private.TIMER_COLORS = {
   [3] = {1, 0, 0},
   [5] = {1, 1, 0},
}

BIGICON_THRESHHOLD_TIME    = 5

private.createTimelineIcon = function(eventInfo)
   local frame = AceGUI:Create("AtAbilitySpellIcon")
   frame:SetEventInfo(eventInfo)
   print("Created timeline icon for event " .. eventInfo.id)
   activeFrames[eventInfo.id] = frame
   frame.frame:Show()

   --frame:PlayCancelAnimation()
   --frame:PlayIntroAnimation()
   --frame.TrailAnimation:Play()
   --frame:PlayHighlightAnimation()


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

   DevTool:AddData(frame, "AT_TIMELINE_ICON")
   -- frame.border:SetVertexColor(DebuffTypeColor[eventInfo.dispelType])
end

ENCOUNTER_STATES           = {
   Active = 0,
   Paused = 1,
   Finished = 2,
   Canceled = 3,
}

local function removeFrame(eventID, animation)
   local frame = activeFrames[eventID]
   if frame then
      frame.frame:Hide()
      frame:Release()
   end
end

private.ENCOUNTER_TIMELINE_EVENT_STATE_CHANGED = function(self, eventID)
   local newState = C_EncounterTimeline.GetEventState(eventID)
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
         frame.SpellName:SetText(eventInfo.spellName)
      end
   elseif newState == ENCOUNTER_STATES.Active then
      local frame = activeFrames[eventID]
      if frame then
         local eventInfo = C_EncounterTimeline.GetEventInfo(eventID)
         frame.Cooldown:Resume()
         frame:SetPoint("CENTER", private.TIMELINE_FRAME, "CENTER")
         -- frame:SetScript("OnUpdate", function(self)
         --    local timeElapsed = C_EncounterTimeline.GetEventTimeElapsed(eventID)
         --    if not timeElapsed or timeElapsed < 0 then timeElapsed = eventInfo.duration end
         --    local y = (timeElapsed / eventInfo.duration) * private.TIMELINE_FRAME:GetHeight() - frame:GetHeight() / 2
         --    frame:SetPoint("CENTER", private.TIMELINE_FRAME, "TOP", 0, -y)
         -- end)
         -- if frame.SpellName then
         --    frame.SpellName:Hide()
         --    frame.SpellName = nil
         -- end
         frame.SpellName = frame:CreateFontString(nil, "OVERLAY", "SystemFont_Shadow_Med3")
         frame.SpellName:SetPoint("RIGHT", frame, "LEFT", -10, 0)
         frame.SpellName:SetText(eventInfo.spellName)
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
         if frame.xOffset ~= xOffset then
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

private.GetZoom = function(icon, zoom)
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

   return nULx, nULy, nLLx, nLLy, nURx, nURy, nLRx, nLRy
end

private.SetZoom = function(icon, zoom)
   local nULx, nULy, nLLx, nLLy, nURx, nURy, nLRx, nLRy = private.GetZoom(icon, zoom)
   icon:SetTexCoord(nULx, nULy, nLLx, nLLy, nURx, nURy, nLRx, nLRy)
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
   private.TIMELINE_FRAME:SetFrameStrata("BACKGROUND")
   private.TIMELINE_FRAME:SetBackdrop({
      bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
      tile = true,
      tileSize = 32,
      edgeSize = 32,
      insets = { left = 11, right = 12, top = 12, bottom = 11 }
   })
   private.TIMELINE_FRAME:SetBackdropColor(0, 0, 0, 1)
   private.TIMELINE_FRAME.Ticks = {}
   

   local moveHeight = private.TIMELINE_FRAME:GetHeight()
   local left, bottom, width, height = private.TIMELINE_FRAME:GetBoundsRect()
   for i, tick in ipairs(private.TIMELINE_TICKS) do
      local tickLine = private.TIMELINE_FRAME:CreateTexture(nil, "ARTWORK")
      local tickPosition = (tick / private.AT_THRESHHOLD_TIME ) * moveHeight
      print("Creating tick at position ".. (tick / private.AT_THRESHHOLD_TIME ) .." for position" .. tickPosition .. " for tick " .. tick)
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

   private.TIMELINE_FRAME.moveHeight = moveHeight
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
