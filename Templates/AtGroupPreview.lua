local appName, app = ...
---@class AbilityTimeline
local private = app
local AceGUI = LibStub("AceGUI-3.0")
local L = private.getLocalisation
local Type = "AtGroupPreview"
local Version = 1
local variables = { count = 5, gap = 5, iconSize = 24, textWidth = 200, textHeight = 16, spacing = 4, layoutInterval = 0.25 }

local function ApplySettings(self)
    if self.group then self.group:Layout() end
end

local function OnAcquire(self)
    self.frame:Hide()
end

local function OnRelease(self)
    self.frame:SetScript("OnUpdate", nil)
    if self.group then self.group:Release() end
    self.group = nil
    for _, item in ipairs(self.items) do
        item.frame:Hide()
        item.frame:ClearAllPoints()
        item.label:SetText("")
    end
end

local function Setup(self, path, asText)
    if self.group then self.group:Release() end
    local settings = variables
    local count = settings.count
    local cycle = count * settings.gap
    local width = asText and settings.textWidth or settings.iconSize
    local height = asText and settings.textHeight or settings.iconSize
    local anchor = self.frame
    if asText then
        anchor:SetSize(width, count * height + (count - 1) * settings.spacing)
    else
        anchor:SetSize(count * width + (count - 1) * settings.spacing, height)
    end
    local startTime = GetTime()
    local remaining = function(id)
        return cycle - (GetTime() - startTime + (id - 1) * settings.gap) % cycle
    end
    local groupSettings = {
        grow = asText and private.DynamicGroup.GROW.DOWN or private.DynamicGroup.GROW.RIGHT,
        spacing = settings.spacing,
    }
    local group = AceGUI:Create("AtDynamicGroup"):Setup(function()
        groupSettings.limit = private.db.profile[path].limit
        groupSettings.sort = private.db.profile[path].sort
        return groupSettings
    end, function() return anchor end, nil, nil, remaining)
    self.group = group
    for id, item in ipairs(self.items) do
        local frame, label = item.frame, item.label
        frame:SetSize(width, height)
        label:ClearAllPoints()
        label:SetFontObject(asText and "GameFontHighlight" or "NumberFontNormal")
        if asText then label:SetAllPoints(frame) else label:SetPoint("CENTER") end
        item.texture:SetShown(not asText)
        frame:Show()
        group:Add(id, frame)
    end
    local sinceLayout = settings.layoutInterval
    anchor:SetScript("OnUpdate", function(_, elapsed)
        for id, item in ipairs(self.items) do
            local seconds = math.ceil(remaining(id))
            if asText then
                item.label:SetFormattedText("|T%d:0|t %s in %d", item.icon, L("TestIcon"), seconds)
            else
                item.label:SetText(seconds)
            end
        end
        sinceLayout = sinceLayout + elapsed
        if sinceLayout >= settings.layoutInterval then
            sinceLayout = 0
            group:Layout()
        end
    end)
end

local function Constructor()
    local anchor = CreateFrame("Frame", nil, UIParent)
    local items = {}
    for id = 1, variables.count do
        local frame = CreateFrame("Frame", nil, anchor)
        local icon = private.TEST_ICONS[(id - 1) % #private.TEST_ICONS + 1]
        local label = frame:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
        local texture = frame:CreateTexture(nil, "ARTWORK")
        texture:SetAllPoints(frame)
        texture:SetTexture(icon)
        items[id] = { frame = frame, label = label, texture = texture, icon = icon }
    end
    return AceGUI:RegisterAsWidget({
        type = Type,
        frame = anchor,
        items = items,
        OnAcquire = OnAcquire,
        OnRelease = OnRelease,
        Setup = Setup,
        ApplySettings = ApplySettings,
    })
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)
