local appName, app = ...
---@class AbilityTimeline
local private = app
local AceGUI = LibStub("AceGUI-3.0")

private.BIG_ICONS = {}

private.evaluateBigIconPositions = function()
   local visibleIcons = 0
   table.sort(private.BIG_ICONS, function(a, b)
      local aRemaining = private.manager.getEventRemainingTime(a.eventInfo.id)
      local bRemaining = private.manager.getEventRemainingTime(b.eventInfo.id)
      if aRemaining and bRemaining and aRemaining ~= bRemaining then
         return aRemaining < bRemaining
      else
         return a.eventInfo.id < b.eventInfo.id
      end
   end)
   for i, frame in ipairs(private.BIG_ICONS) do
      if frame and frame:IsShown() then
         if private.db.global.bigicon[private.ACTIVE_EDITMODE_LAYOUT].grow_direction == 'RIGHT' then
            local xOffset = (private.db.profile.big_icon_settings.size + private.db.global.bigicon[private.ACTIVE_EDITMODE_LAYOUT].margin) *
            (visibleIcons)
            if frame.offset ~= xOffset or frame.growdirection ~= 'RIGHT' then
               frame.offset = xOffset
               frame:ClearAllPoints()
               frame:SetPoint("LEFT", private.BIGICON_FRAME.frame, "LEFT", xOffset, 0)
               frame.growdirection = 'RIGHT'
            end
         elseif private.db.global.bigicon[private.ACTIVE_EDITMODE_LAYOUT].grow_direction == 'LEFT' then
            local xOffset = -1 *
            (private.db.profile.big_icon_settings.size + private.db.global.bigicon[private.ACTIVE_EDITMODE_LAYOUT].margin) *
            (visibleIcons)
            if frame.offset ~= xOffset or frame.growdirection ~= 'LEFT' then
               frame.offset = xOffset
               frame:ClearAllPoints()
               frame:SetPoint("RIGHT", private.BIGICON_FRAME.frame, "RIGHT", xOffset, 0)
               frame.growdirection = 'LEFT'
            end
         elseif private.db.global.bigicon[private.ACTIVE_EDITMODE_LAYOUT].grow_direction == 'UP' then
            local yOffset = (private.db.profile.big_icon_settings.size + private.db.global.bigicon[private.ACTIVE_EDITMODE_LAYOUT].margin) *
            (visibleIcons)
            if frame.offset ~= yOffset or frame.growdirection ~= 'UP' then
               frame.offset = yOffset
               frame:ClearAllPoints()
               frame:SetPoint("BOTTOM", private.BIGICON_FRAME.frame, "BOTTOM", 0, yOffset)
               frame.growdirection = 'UP'
            end
         elseif private.db.global.bigicon[private.ACTIVE_EDITMODE_LAYOUT].grow_direction == 'DOWN' then
            local yOffset = -1 *
            (private.db.profile.big_icon_settings.size + private.db.global.bigicon[private.ACTIVE_EDITMODE_LAYOUT].margin) *
            (visibleIcons)
            if frame.offset ~= yOffset or frame.growdirection ~= 'DOWN' then
               frame.offset = yOffset
               frame:ClearAllPoints()
               frame:SetPoint("TOP", private.BIGICON_FRAME.frame, "TOP", 0, yOffset)
               frame.growdirection = 'DOWN'
            end
         end

         visibleIcons = visibleIcons + 1
      end
   end
end

local bigIcons = {}

private.createBigIcon = function(eventID)
   local frame = AceGUI:Create("AtBigIcon")
   frame:SetEventInfo(private.manager.getEventInfo(eventID))
   bigIcons[eventID] = frame
   table.insert(private.BIG_ICONS, frame)
   private.Debug(frame, "AT_BIGICON_FRAME_" .. eventID)
   private.evaluateBigIconPositions()
end

local removeBigIcon = function(eventID)
   local frame = bigIcons[eventID]
   if not frame then return end
   bigIcons[eventID] = nil
   for i, f in ipairs(private.BIG_ICONS) do
      if f == frame then
         table.remove(private.BIG_ICONS, i)
         break
      end
   end
   frame:Release()
   private.evaluateBigIconPositions()
end

private.manager.RegisterCallback("AtBigIcon", "EVENT_DISPLAY_START", function(_, eventID, display)
   if display == "bigIcon" and not bigIcons[eventID] then
      private.createBigIcon(eventID)
   end
end)

private.manager.RegisterCallback("AtBigIcon", "EVENT_DISPLAY_STOP", function(_, eventID, display)
   if display == "bigIcon" then
      removeBigIcon(eventID)
   end
end)
