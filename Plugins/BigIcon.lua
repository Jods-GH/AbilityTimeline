local addonName, private = ...
local AceGUI = LibStub("AceGUI-3.0")

private.BIG_ICONS = {}

private.evaluateBigIconPositions = function()
   local visibleIcons = 0
   table.sort(private.BIG_ICONS, function(a, b) return a.eventInfo.duration < b.eventInfo.duration end)
   for i, frame in ipairs(private.BIG_ICONS) do
      if frame and frame:IsShown() then
         local xOffset = (private.BIG_ICON_SIZE + private.BIG_ICON_MARGIN) * (visibleIcons)
         if frame.xOffset ~= xOffset then
            frame.xOffset = xOffset
            frame:SetPoint("LEFT", private.BIGICON_FRAME.frame, "LEFT", xOffset, 0)
         end
         visibleIcons = visibleIcons + 1
      end
   end
end

private.createBigIcon = function(eventInfo)
   local frame = AceGUI:Create("AtBigIcon")
   frame:SetEventInfo(eventInfo)
   private.HIGHLIGHT_EVENTS.BigIcons[eventInfo.id] = true
   table.insert(private.BIG_ICONS, frame)
   private.Debug(frame, "AT_BIGICON_FRAME_" .. eventInfo.id)
   private.evaluateBigIconPositions()
end