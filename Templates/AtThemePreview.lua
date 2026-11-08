local appName, app = ...
---@class AbilityTimeline
local private = app
local AceGUI = LibStub("AceGUI-3.0")
local Type = "AtThemePreview"
local Version = 1
local variables = { width = 240, inset = 12, nameHeight = 24, iconSize = 64, iconIn = 0.6, iconOut = 3.6, barOut = 4.4, loop = 5.6, icon = 237538 }

---@param widget table
---@param kind string -- Timeline or BigIcon
local showPiece = function(widget, kind)
    local frame = widget.frame
    frame:Show()
    if kind == "Timeline" then
        private.ThemeApply.PlayEnter(frame, private.GetElementStyle(kind).Enter)
    else
        -- the countdown and its swipe start over with every entry
        widget.startTime = GetTime()
        frame.Cooldown:SetCooldown(widget.startTime, widget.duration)
        private.ThemeApply.PlayEnter(frame, private.GetElementStyle(kind).Enter, true, frame.SpellIcon,
            variables.icon)
    end
end

---@param widget table
---@param kind string -- Timeline or BigIcon
local hidePiece = function(widget, kind)
    local frame = widget.frame
    if kind == "Timeline" then
        private.ThemeApply.PlayExit(frame, private.GetElementStyle(kind).Exit)
    else
        private.ThemeApply.PlayExit(frame, private.GetElementStyle(kind).Exit, frame.SpellIcon, variables.icon)
    end
    frame:Hide()
end

---starts the preview's loop from the beginning, with both pieces gone
local restartPreview = function(self)
    self.time = 0
    self.step = 1
    self.bar.frame:Hide()
    self.icon.frame:Hide()
end

local function Setup(self, getPreviewKey)
    local frame = self.frame
    frame:Hide()
    frame:SetWidth(variables.width)
    local bar = private.CreateSettingsPreview("Timeline", getPreviewKey)
    local icon = private.CreateSettingsPreview("BigIcon", getPreviewKey)
    for _, widget in ipairs({ bar, icon }) do
        widget.frame:SetParent(frame)
        widget.frame:ClearAllPoints()
    end
    bar.frame:SetPoint("TOP", frame, "TOP", 0, -variables.inset)
    icon.frame:SetPoint("TOP", bar.frame, "BOTTOM", 0, -variables.inset)
    -- the icon has a size of its own, big icons can be too small or too large to show a theme
    local applySettings = icon.ApplySettings
    icon.ApplySettings = function(self)
        applySettings(self)
        self.frame:SetSize(variables.iconSize, variables.iconSize)
    end
    icon:ApplySettings()
    self.bar, self.icon = bar, icon
    local steps = {
        { at = 0, play = function() showPiece(bar, "Timeline") end },
        { at = variables.iconIn, play = function() showPiece(icon, "BigIcon") end },
        { at = variables.iconOut, play = function() hidePiece(icon, "BigIcon") end },
        { at = variables.barOut, play = function() hidePiece(bar, "Timeline") end },
    }
    -- the settings window puts the preview above its panel, its pieces go above it
    frame:SetScript("OnShow", function()
        for _, widget in ipairs({ bar, icon }) do
            widget.frame:SetFrameLevel(frame:GetFrameLevel() + 1)
        end
        restartPreview(self)
    end)
    frame:SetScript("OnUpdate", function(_, elapsed)
        self.time = self.time + elapsed
        local step = steps[self.step]
        if self.time >= step.at then
            private.DrawInTheme(getPreviewKey(), step.play)
            self.step = self.step % #steps + 1
            if self.step == 1 then
                self.time = self.time - variables.loop
            end
        end
    end)
    restartPreview(self)
end

local function Refresh(self)
    self.bar:ApplySettings()
    self.icon:ApplySettings()
    self.frame:SetHeight(variables.inset * 3 + self.bar.frame:GetHeight() + variables.iconSize + variables.nameHeight)
    restartPreview(self)
end

local function OnAcquire(self)
    self.frame:Hide()
end

local function OnRelease(self)
    self.frame:SetScript("OnShow", nil)
    self.frame:SetScript("OnUpdate", nil)
    if self.bar then self.bar:Release() end
    if self.icon then self.icon:Release() end
    self.bar, self.icon = nil, nil
    self.time, self.step = nil, nil
end

local function Constructor()
    return AceGUI:RegisterAsWidget({
        type = Type,
        frame = CreateFrame("Frame", nil, UIParent),
        OnAcquire = OnAcquire,
        OnRelease = OnRelease,
        Setup = Setup,
        Refresh = Refresh,
    })
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)
