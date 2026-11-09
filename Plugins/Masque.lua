local appName, app = ...
---@class AbilityTimeline
local private = app
local Masque = LibStub("Masque", true)

local GROUP_NAMES = {
    TimelineIcons = "Timeline Icons",
    BigIcons = "Big Icons",
}
local groups = {}
local buttons = setmetatable({}, { __mode = "k" })

local prepareCooldown = function(frame)
    if not frame.CooldownText or frame.atIconSkinned then return end
    local cooldown = frame.Cooldown
    cooldown:SetDrawEdge(true)
    if cooldown.SetTexCoordRange then
        cooldown:SetTexCoordRange(CreateVector2D(0, 0), CreateVector2D(1, 1))
    end
end

-- The reference region is never an event border: Masque must not overwrite secret event visibility.
local queueRefresh = function(frame)
    local button = buttons[frame]
    if not button or button.refreshQueued then return end
    button.refreshQueued = true
    C_Timer.After(0, function()
        button.refreshQueued = nil
        private.DrawInTheme(button.themeKey, function()
            local style = frame.atIconStyle
            if not style then return end
            local skinned = button.added and not button.group.db.Disabled or false
            private.ThemeApply.IconArt(frame, frame.SpellIcon, style, frame.TextureHolder or frame, skinned)
            if frame.CooldownText then private.ThemeApply.CooldownArt(frame, style, skinned) end
            if frame.atIconSettings then
                private.ThemeApply.IconBorders(frame, frame.atIconSettings, frame.eventID or
                    (frame.eventInfo and frame.eventInfo.id))
            end
            local widget = frame.obj
            if widget and frame.eventInfo then
                frame.mergeKey = nil
                widget:SetMergedIcons(widget.mergedMembers)
            end
        end)
    end)
end

---makes an icon frame available to Masque, regions as in Masque's Group:AddButton (Icon, Cooldown)
---@param groupKey string
---@param frame Frame
---@param regions table
private.AddToMasque = function(groupKey, frame, regions)
    if not Masque then return end
    if not groups[groupKey] then
        groups[groupKey] = Masque:Group("Ability Timeline", GROUP_NAMES[groupKey])
    end
    local reference = frame:CreateTexture(nil, "OVERLAY")
    reference:Hide()
    regions.DebuffBorder = reference
    frame.MasqueBorderStyle = { Source = reference, Glow = false }
    buttons[frame] = { group = groups[groupKey], regions = regions }
    -- Skin passes, including profile changes and disabling, lay this region out before returning.
    local onLayout = function()
        local button = buttons[frame]
        if button.added and not button.group.db.Disabled then prepareCooldown(frame) end
        queueRefresh(frame)
    end
    hooksecurefunc(reference, "SetPoint", onLayout)
    hooksecurefunc(reference, "SetAllPoints", onLayout)
    frame:HookScript("OnSizeChanged", function()
        local button = buttons[frame]
        if button.added and not button.syncing then
            local width, height = frame:GetSize()
            if width ~= button.width or height ~= button.height then
                button.width, button.height = width, height
                button.group:ReSkin(frame)
            end
        end
    end)
end

---adds or removes the frame from its Masque group depending on the theme, returns whether Masque skins it
---@param frame Frame
---@return boolean
private.SyncMasque = function(frame)
    local button = buttons[frame]
    if not button then
        return false
    end
    local useMasque = private.GetCurrentTheme().Masque ~= false
    button.themeKey = private.GetCurrentThemeKey()
    local width, height = frame:GetSize()
    button.syncing = true
    if useMasque and not button.added then
        prepareCooldown(frame)
        button.group:AddButton(frame, button.regions)
    elseif not useMasque and button.added then
        button.group:RemoveButton(frame)
    elseif useMasque and (button.width ~= width or button.height ~= height) then
        button.group:ReSkin(frame)
    end
    button.syncing = nil
    button.added = useMasque
    button.width, button.height = width, height
    return useMasque and not button.group.db.Disabled
end
