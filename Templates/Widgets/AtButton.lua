local appName, app = ...
---@class AbilityTimeline
local private = app
local ThemedWidgets = private.ThemedWidgets

-- AceGUI's Button in the theme, SetStyle("Primary") or SetStyle("Danger") for the other button styles
local Type = "AtButton"
local Version = 1

---@param self AtButton
local function ApplySettings(self)
    ThemedWidgets.DrawButton(self.frame)
    self.frame:SetAlpha(self.disabled and 0.5 or 1)
end

---@param self AtButton
---@param style string -- Plain, Primary or Danger
local function SetStyle(self, style)
    self.frame.atStyle = style
    ApplySettings(self)
end

---@param widget AtButton
local function Skin(widget)
    ThemedWidgets.SkinButton(widget.frame)
    widget.SetStyle = SetStyle
    local stockAcquire = widget.OnAcquire
    widget.OnAcquire = function(self)
        self.frame.atStyle = "Plain"
        stockAcquire(self)
    end
end

ThemedWidgets.Register(Type, "Button", Version, Skin, ApplySettings, { "OnAcquire", "SetDisabled" })
