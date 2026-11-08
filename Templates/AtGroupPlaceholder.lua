local appName, app = ...
---@class AbilityTimeline
local private = app
local AceGUI = LibStub("AceGUI-3.0")
local Type = "AtGroupPlaceholder"
local Version = 1

local function OnAcquire(self)
   self.frame:Hide()
end

local function OnRelease(self)
   if self.timer then
      self.timer:Cancel()
      self.timer = nil
   end
   self.frame.groupAnchor = nil
   self.frame.groupPoint = nil
   self.frame.groupRelativePoint = nil
   self.frame.groupX = nil
   self.frame.groupY = nil
end

local function SetDuration(self, duration, onFinished)
   if self.timer then self.timer:Cancel() end
   self.timer = C_Timer.NewTimer(duration, function()
      self.timer = nil
      onFinished()
   end)
end

local function Constructor()
   return AceGUI:RegisterAsWidget({
      type = Type,
      frame = CreateFrame("Frame", nil, UIParent),
      OnAcquire = OnAcquire,
      OnRelease = OnRelease,
      SetDuration = SetDuration,
   })
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)
