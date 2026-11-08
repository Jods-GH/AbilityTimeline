local appName, app = ...
---@class AbilityTimeline
local private = app
local AceGUI = LibStub("AceGUI-3.0")
local Type = "AtMergedDisplayGroup"
local Version = 1
local groupMixin = private.DynamicGroup.Mixin
local mergedMixin = {}

function mergedMixin:Setup(getSettings, getAnchor, playEnter)
   groupMixin.Setup(self, getSettings, getAnchor)
   self.playEnter = playEnter
   return self
end

function mergedMixin:OnAcquire()
   groupMixin.OnAcquire(self)
   self.elapsed = 0
end

function mergedMixin:OnRelease()
   groupMixin.OnRelease(self)
   for _, widget in pairs(self.widgets) do
      widget:SetMergedIcons(nil)
      if widget.frame.mergedInto then widget.frame:Show() end
      widget.frame.mergedInto = nil
   end
   wipe(self.widgets)
   wipe(self.moving)
   wipe(self.clusters)
   self.playEnter = nil
   self.elapsed = 0
end

function mergedMixin:AddWidget(id, widget)
   self.widgets[id] = widget
   self.frame:Show()
end

function mergedMixin:RemoveWidget(id)
   self.widgets[id] = nil
   if not next(self.widgets) then self.frame:Hide() end
end

function mergedMixin:Layout()
   local moving, clusters = self.moving, self.clusters
   wipe(moving)
   for id, widget in pairs(self.widgets) do
      local info = widget.frame.eventInfo
      local elapsed = private.manager.getEventTimeElapsed(id)
      if not elapsed or elapsed < 0 then elapsed = info.duration end
      widget.frame.positionRemaining = info.duration - elapsed
      table.insert(moving, widget)
   end
   local count = private.manager.clusterTimers(moving, clusters, self.getSettings())
   for i = 1, count do
      local members = clusters[i].members
      local host = members[1]
      host:SetMergedIcons(members)
      for index, widget in ipairs(members) do
         local frame = widget.frame
         local id = frame.eventInfo.id
         if index == 1 then
            if frame.mergedInto then
               frame.mergedInto = nil
            end
            self:Add(id, frame)
         else
            self:Remove(id)
            widget:SetMergedIcons(nil)
            if frame.mergedInto ~= host then private.ThemeApply.StopEnterEffects(frame) end
            frame.mergedInto = host
            frame:Hide()
         end
      end
   end
   groupMixin.Layout(self)
   for _, item in ipairs(self.items) do
      local widget = self.widgets[item.id]
      if widget and not item.hiddenByLimit then
         if widget.frame.pendingEnter then
            widget.frame.pendingEnter = nil
            self.playEnter(widget)
         end
         widget.frame:Show()
      end
   end
end

local function Constructor()
   local widget = {
      type = Type,
      frame = CreateFrame("Frame", nil, UIParent),
      items = {}, index = {}, widgets = {}, moving = {}, clusters = {},
   }
   for key, value in pairs(groupMixin) do widget[key] = value end
   for key, value in pairs(mergedMixin) do widget[key] = value end
   -- Hidden members cannot drive their own updates. Recheck timing and settings even while merged.
   widget.frame:SetScript("OnUpdate", function(_, delta)
      widget.elapsed = widget.elapsed + delta
      if widget.elapsed >= 0.1 then
         widget.elapsed = 0
         widget:Layout()
      end
   end)
   return AceGUI:RegisterAsWidget(widget)
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)
