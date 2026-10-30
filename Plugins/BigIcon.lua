local appName, app = ...
---@class AbilityTimeline
local private = app
local AceGUI = LibStub("AceGUI-3.0")

private.BIG_ICONS = {}

local bigIconGroup = private.DynamicGroup.Create(function()
   local settings = private.db.global.bigicon[private.ACTIVE_EDITMODE_LAYOUT]
   return {
      grow = settings.grow_direction,
      spacing = settings.margin,
      limit = settings.limit,
      sort = settings.sort,
   }
end, function()
   return private.BIGICON_FRAME and private.BIGICON_FRAME.frame
end)

private.evaluateBigIconPositions = function()
   bigIconGroup:Layout()
end

local bigIcons = {}

private.createBigIcon = function(eventID)
   local frame = AceGUI:Create("AtBigIcon")
   frame:SetEventInfo(private.manager.getEventInfo(eventID))
   bigIcons[eventID] = frame
   table.insert(private.BIG_ICONS, frame)
   private.Debug(frame, "AT_BIGICON_FRAME_" .. eventID)
   bigIconGroup:Add(eventID, frame.frame)
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
   bigIconGroup:Remove(eventID)
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
