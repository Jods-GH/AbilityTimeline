local addonName, private               = ...
local AceGUI                           = LibStub("AceGUI-3.0")

local activeFrames                     = {}
private.ENCOUNTER_TIMELINE_EVENT_ADDED = function(self, eventInfo, initialState)
   if not private.TIMELINE_FRAME.frame:IsVisible() then
      private.handleFrame(true)
   end
   private.createTimelineIcon(eventInfo)
end

private.TIMELINE_TICKS                 = { 5 }
private.AT_THRESHHOLD                  = 0.8
private.AT_THRESHHOLD_TIME             = 10

BIGICON_THRESHHOLD_TIME                = 5

private.createTimelineIcon             = function(eventInfo)
   local frame = AceGUI:Create("AtAbilitySpellIcon")
   frame:SetEventInfo(eventInfo)
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
   --    end)
   -- end)
   --C_ChatInfo.SendChatMessage(eventInfo.spellName , 'VOICE_TEXT') -- for some reason this can be send here but not after the duration is finished?
   private.Debug(frame, "AT_TIMELINE_ICON")
   -- frame.border:SetVertexColor(DebuffTypeColor[eventInfo.dispelType])
end

private.ENCOUNTER_STATES               = {
   Active = 0,
   Paused = 1,
   Finished = 2,
   Canceled = 3,
   Blocked = 4,
}

private.removeAtIconFrame = function(eventID, animation)
   local frame = activeFrames[eventID]
   if frame then
      frame.frame:Hide()
      frame:Release()
      activeFrames[eventID] = nil
   end
end

private.ENCOUNTER_TIMELINE_EVENT_STATE_CHANGED = function(self, eventID)
   local newState = C_EncounterTimeline.GetEventState(eventID)
   if newState == private.ENCOUNTER_STATES.Finished then
      private.removeAtIconFrame(eventID, 'PlayFinishAnimation')
   elseif newState == private.ENCOUNTER_STATES.Canceled then
      private.removeAtIconFrame(eventID, 'PlayCancelAnimation')
   elseif newState == private.ENCOUNTER_STATES.Paused then
   elseif newState == private.ENCOUNTER_STATES.Active then
   end
end

private.HIGHLIGHT_EVENTS = {
   BigIcons = {},
   HighlightTexts = {}
}

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

private.ResetZoom = function(icon)
   icon:SetTexCoord(0, 1, 0, 1)
end

private.SetZoom = function(icon, zoom)
   local nULx, nULy, nLLx, nLLy, nURx, nURy, nLRx, nLRy = private.GetZoom(icon, zoom)
   icon:SetTexCoord(nULx, nULy, nLLx, nLLy, nURx, nURy, nLRx, nLRy)
end

private.TRIGGER_HIGHLIGHT = function(eventInfo)
   if private.db.global.bigicon_enabled[private.ACTIVE_EDITMODE_LAYOUT] and not private.HIGHLIGHT_EVENTS.BigIcons[eventInfo.id] then
      private.createBigIcon(eventInfo)
   end
   if private.db.global.text_highlight_enabled[private.ACTIVE_EDITMODE_LAYOUT] and not private.HIGHLIGHT_EVENTS.HighlightTexts[eventInfo.id] then
      private.createTextHighlight(eventInfo)
   end
   if private.db.profile.useAudioCountdowns then
      private.playAudioAlert(eventInfo)
   end
end
private.ENCOUNTER_TIMELINE_EVENT_REMOVED = function()
   if C_EncounterTimeline.HasAnyEvents() then
   else
      private.handleFrame(false)
   end
end


private.createTimelineFrame = function()
   private.TIMELINE_FRAME = AceGUI:Create("AtTimelineFrame")

   private.BIGICON_FRAME = AceGUI:Create("AtBigIconFrame")


   private.TEXT_HIGHLIGHT_FRAME = AceGUI:Create("AtTextHighlightFrame")

   private.Debug(private.TEXT_HIGHLIGHT_FRAME, "AT_TEXT_HIGHLIGHT_FRAME")
   private.Debug(private.TIMELINE_FRAME, "AT_TIMELINE_FRAME")
end

private.handleFrame = function(show)
   if show then
      if not private.TIMELINE_FRAME.frame then
         private.createTimelineFrame()
      end
      private.TIMELINE_FRAME.frame:Show()
   else
      if private.TIMELINE_FRAME.frame then
         private.TIMELINE_FRAME.frame:Hide()
      end
   end
end
