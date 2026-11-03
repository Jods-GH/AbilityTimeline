local appName, app = ...
---@class AbilityTimeline
local private = app
local ThemedWidgets = private.ThemedWidgets

-- AceGUI's ScrollFrame in the theme: a thin scroll bar

---@param self AtScrollFrame
local function ApplyScrollSettings(self)
    self.scrollbar.AtDraw()
end

---@param widget AtScrollFrame
local function SkinScrollFrame(widget)
    ThemedWidgets.SkinScrollBar(widget.scrollbar)
end

ThemedWidgets.Register("AtScrollFrame", "ScrollFrame", 1, SkinScrollFrame, ApplyScrollSettings, { "OnAcquire" })
