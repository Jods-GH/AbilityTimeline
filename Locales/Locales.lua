local appName, app = ...
---@class AbilityTimeline
local private = app
local AceLocale = LibStub ('AceLocale-3.0')
local currentLocale = AceLocale:GetLocale (appName, true)---@type AbilityTimelineLocale
private.getLocalisation = function(Object)
      return currentLocale[Object]
end
