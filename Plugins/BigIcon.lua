local appName, app = ...
---@class AbilityTimeline
local private = app
local AceGUI = LibStub("AceGUI-3.0")

private.BIG_ICONS = {}

local bigIconGroup = AceGUI:Create("AtMergedDisplayGroup"):Setup(function()
   local settings = private.db.global.bigicon[private.ACTIVE_EDITMODE_LAYOUT]
   return {
      grow = settings.grow_direction,
      spacing = settings.margin,
      limit = private.db.profile.big_icon_settings.limit,
      sort = private.db.profile.big_icon_settings.sort,
      merge_timers = private.db.profile.big_icon_settings.merge_timers,
      merge_window = private.db.profile.timeline_settings.merge_window,
   }
end, function()
   return private.BIGICON_FRAME and private.BIGICON_FRAME.frame
end, function(widget)
   private.ThemeApply.PlayEnter(widget.frame, private.GetElementStyle("BigIcon").Enter, true, widget.frame.SpellIcon,
      widget.eventInfo.iconFileID)
end)

private.evaluateBigIconPositions = function()
   if private.manager.isUpdatingDisplays then bigIconGroup:MarkDirty() else bigIconGroup:Layout() end
end

local bigIcons = {}

private.createBigIcon = function(eventID)
   local frame = AceGUI:Create("AtBigIcon")
   frame.frame:Hide()
   frame:SetEventInfo(private.manager.getEventInfo(eventID), false, true)
   bigIcons[eventID] = frame
   table.insert(private.BIG_ICONS, frame)
   private.Debug(frame, "AT_BIGICON_FRAME_" .. eventID)
   bigIconGroup:AddWidget(eventID, frame)
   private.evaluateBigIconPositions()
end

local removeBigIcon = function(eventID)
   local frame = bigIcons[eventID]
   if not frame then return end
   bigIcons[eventID] = nil
   bigIconGroup:RemoveWidget(eventID)
   for i, f in ipairs(private.BIG_ICONS) do
      if f == frame then
         table.remove(private.BIG_ICONS, i)
         break
      end
   end
   local exitTime = 0
   if frame.frame:IsVisible() then
      exitTime = private.ThemeApply.PlayIconExit(frame.frame, private.GetElementStyle("BigIcon").Exit, frame.frame.SpellIcon,
         frame.eventInfo and frame.eventInfo.iconFileID)
   end
   -- the other icons keep their place until the icon finished shattering
   bigIconGroup:Hold(eventID, exitTime)
   frame:Release()
   private.evaluateBigIconPositions()
end

private.manager.RegisterCallback("AtBigIcon", "EVENT_DISPLAY_START", function(_, eventID, display)
   if display == "bigIcon" and not bigIcons[eventID] then
      private.createBigIcon(eventID)
   end
end)

private.manager.RegisterCallback("AtBigIcon", "EVENT_DISPLAYS_UPDATED", function()
   if bigIconGroup:IsDirty() then bigIconGroup:Layout() end
end)

private.manager.RegisterCallback("AtBigIcon", "EVENT_DISPLAY_STOP", function(_, eventID, display)
   if display == "bigIcon" then
      removeBigIcon(eventID)
   end
end)
