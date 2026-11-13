local appName, app = ...
---@class AbilityTimeline
local private = app

local function clamp(v, lo, hi)
   if v < lo then return lo end
   if v > hi then return hi end
   return v
end

---the crop (left, right, top, bottom) of an icon zoomed around its middle, 1 shows all of it; worked out from the
---full image instead of read back, an icon showing an encounter's texture can't be read while it is secret
private.ZoomCrop = function(zoom)
   local half = clamp(zoom, 0, 1) / 2
   return 0.5 - half, 0.5 + half, 0.5 - half, 0.5 + half
end

private.ResetZoom = function(icon)
   icon:SetTexCoord(0, 1, 0, 1)
   icon.atCrop = nil
end

---crops the icon and keeps the crop on it (atCrop) for the art cut from it
private.SetZoom = function(icon, zoom)
   local left, right, top, bottom = private.ZoomCrop(zoom)
   icon:SetTexCoord(left, right, top, bottom)
   icon.atCrop = { left, right, top, bottom }
end
