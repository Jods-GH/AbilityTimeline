local appName, app = ...
---@class AbilityTimeline
local private = app
local AceGUI = LibStub("AceGUI-3.0")
local L = private.getLocalisation

-- the pages of the spell icons, big icons and text highlights and of the cooldown they share, each with a live
-- preview of the element it changes
local variables = {
    dispelColor = { r = 0, g = 0.5019607843137255, b = 1 },
    bossModsColor = { r = 1, g = 20 / 255, b = 147 / 255, a = 1 },
    previewIcon = 237538,
    -- the index of the magic dispel type in private.dispellTypeList
    magicIndex = 3,
    -- the db.profile table with the colorOrder of an element's spell name
    colorSettings = { SpellIcon = "text_settings", BigIcon = "big_icon_text_settings", TextHighlight = "highlight_text_settings" },
}

---a row named by the localisation of key and of key .. "Description"
---@param kind string
---@param key string
---@param fields table
---@return table
local row = function(kind, key, fields)
    fields.kind = kind
    fields.name = L(key)
    fields.desc = L(key .. "Description")
    return fields
end

---@param key string
---@return table
local heading = function(key)
    return { kind = "Heading", name = L(key) }
end

---@param items string[]
---@return table
local listOf = function(items)
    local values = {}
    for _, item in ipairs(items) do
        values[item] = item
    end
    return values
end

local anchorValues = listOf(private.AnchorPointOrder)
local strataValues = listOf(private.FrameStrataOrder)

-- every preview built, refreshed as the profile settings they show change
local previews = {}

local previewEvent = function()
    return {
        duration = 15,
        maxQueueDuration = 0,
        spellName = L("TestIcon"),
        spellID = 0,
        iconFileID = variables.previewIcon,
        severity = 1,
        paused = false,
        color = { r = 1, g = 1, b = 1, a = 1 },
    }
end

---shows the markers of a magic healer ability that is deadly: an icon comes from a pool, an ended event left the
---markers it had no use for without a texture and invisible
---@param frame Frame
local showMarkers = function(frame)
    local dispelIcon = (frame.dispellTypeIcons or frame.DispellTypeIcons)[1]
    private.ThemeApply.Texture(dispelIcon, private.manager.getEventIconArt(8))
    dispelIcon:SetAlpha(1)
    for i, texture in ipairs(frame.RoleIcons) do
        if i == 1 then
            private.ThemeApply.Texture(texture, private.manager.getEventIconArt(256))
        else
            texture:SetTexture(nil)
        end
        texture:SetAlpha(1)
    end
    private.ThemeApply.Texture(frame.DangerIcon[1], private.manager.getEventIconArt(1))
    frame.DangerIcon[1]:SetAlpha(1)
    -- only the magic border of the dispel borders
    for i, edges in ipairs(frame.DispellTypeBorderEdges) do
        for _, edge in ipairs(edges) do
            edge:SetAlpha(i == variables.magicIndex and 1 or 0)
        end
        frame.BorderGlows[i + 1]:SetAlpha(i == variables.magicIndex and 1 or 0)
    end
end

local colorSources

---colors the spell name of a preview of kind by its first color source that has a color for a magic ability
---@param kind string
---@param frame Frame
local colorPreviewName = function(kind, frame)
    local shown = colorSources(variables.colorSettings[kind])
    for _, source in ipairs(private.db.profile[variables.colorSettings[kind]].colorOrder) do
        local color = source == "dispel" and variables.dispelColor or
            source ~= "default" and shown[source] and variables.bossModsColor
        if color then
            frame.SpellName:SetTextColor(color.r, color.g, color.b)
        end
        if color or source == "default" then break end
    end
end

---sets up a preview: what a test event can't show is applied after the widget's own ApplySettings every time, as
---that resets it on every theme refresh: the markers, a magic dispel border and boss mod border, the dispel color of
---its name by its first color source. It is also kept above the settings window, its strata setting would put it behind it
---@param kind string -- SpellIcon, BigIcon or TextHighlight
---@param widget table
---@param settings string|nil -- the db.profile table of an icon's settings
local setupPreview = function(kind, widget, settings)
    local applySettings = widget.ApplySettings
    widget.frame.countdownPreview = { source = private.manager.SOURCES.Addon, state = private.manager.STATES.Active,
        duration = 15, elapsed = 0, autoElapsed = true }
    widget.ApplySettings = function(self)
        applySettings(self)
        local frame = self.frame
        frame:SetFrameStrata("DIALOG")
        if frame.TextureHolder then
            frame.TextureHolder:SetFrameStrata("DIALOG")
        end
        if settings then
            showMarkers(frame)
            local border = private.GetElementStyle(kind).Border
            private.ThemeApply.DispelBorder(frame, variables.magicIndex, border)
            if private.db.profile[settings].border == private.IconBorderSettings.bossmods then
                private.ThemeApply.BossModsBorder(frame, border, variables.bossModsColor)
            end
        end
        colorPreviewName(kind, frame)
    end
    local onRelease = widget.OnRelease
    widget.OnRelease = function(self)
        self.ApplySettings = applySettings
        self.OnRelease = onRelease
        onRelease(self)
    end
    table.insert(previews, widget)
    widget:ApplySettings()
    return widget
end

local createPreview = {
    SpellIcon = function()
        local widget = AceGUI:Create("AtAbilitySpellIcon")
        widget:SetEventInfo(previewEvent(), true)
        widget.startTime = GetTime()
        widget.duration = 15
        widget.frame:SetScript("OnUpdate", function()
            if widget.startTime + widget.duration < GetTime() then
                widget.startTime = GetTime()
                private.ThemeApply.EnterTimelineMotion(widget.frame, widget.duration)
            end
            local remaining = (widget.startTime + widget.duration) - GetTime()
            widget.HandleCooldown(widget.frame, remaining)
            private.ThemeApply.UpdateTimelineMotion(widget.frame, private.manager.STATES.Active, remaining, remaining,
                private.TIMELINE_ZONES.MOVING)
        end)
        return setupPreview("SpellIcon", widget, "icon_settings")
    end,
    BigIcon = function()
        local widget = AceGUI:Create("AtBigIcon")
        widget:SetEventInfo(previewEvent(), true)
        widget.startTime, widget.duration = 0, 0
        widget.frame:SetScript("OnUpdate", function()
            -- counts down from the time big icons are shown at, from the start again once that changed
            local threshold = private.db.profile.big_icon_settings.threshold_time
            if widget.startTime + widget.duration < GetTime() or widget.duration ~= threshold then
                widget.startTime, widget.duration = GetTime(), threshold
                widget.frame.Cooldown:SetCooldown(widget.startTime, widget.duration)
            end
            widget.frame.countdownPreview.duration = widget.duration
            widget.HandleCooldown(widget.frame, (widget.startTime + widget.duration) - GetTime())
        end)
        return setupPreview("BigIcon", widget, "big_icon_settings")
    end,
    TextHighlight = function()
        local widget = AceGUI:Create("AtTextHighlight")
        local eventInfo = previewEvent()
        widget:SetEventInfo(eventInfo, true)
        widget.startTime, widget.duration = 0, 0
        widget.frame:SetScript("OnUpdate", function(self)
            local threshold = private.db.profile.highlight_text_settings.threshold_time
            if widget.startTime + widget.duration < GetTime() or widget.duration ~= threshold then
                widget.startTime, widget.duration = GetTime(), threshold
            end
            local remainingDuration = (widget.startTime + widget.duration) - GetTime()
            widget.frame.countdownPreview = { remaining = remainingDuration, duration = threshold, elapsed = threshold - remainingDuration,
                source = private.manager.SOURCES.Addon, state = private.manager.STATES.Active }
            widget:HandleTexts(eventInfo, remainingDuration)
            colorPreviewName("TextHighlight", self)
            if private.db.profile.highlight_text_settings.dispellIcons then
                local art = private.manager.getEventIconArt(8)
                private.ThemeApply.Texture(self.dispellTypeTexture, art)
                self.dispellTypeTexture:SetAlpha(1)
            end
        end)
        return setupPreview("TextHighlight", widget)
    end,
    Timeline = function()
        local widget = AceGUI:Create("AtTimelinePreview")
        table.insert(previews, widget)
        return widget
    end,
    Ticks = function()
        local widget = AceGUI:Create("AtTimelinePreview")
        widget:SetTicks(true)
        table.insert(previews, widget)
        return widget
    end,
}

local createGroupPreview = function(path, asText)
    local widget = AceGUI:Create("AtGroupPreview")
    widget:Setup(path, asText)
    table.insert(previews, widget)
    return widget
end

local groupPreviews = {}

---the preview of a group's rows, built the first time
---@param path string
---@param asText boolean|nil
---@return function
local groupPreview = function(path, asText)
    return function()
        groupPreviews[path] = groupPreviews[path] or createGroupPreview(path, asText)
        return groupPreviews[path].frame
    end
end

---builds another preview of kind (SpellIcon, BigIcon, TextHighlight or Timeline), drawn in the theme getThemeKey
---returns when given, e.g. for the theme page
---@param kind string
---@param getThemeKey function|nil
---@return table widget
private.CreateSettingsPreview = function(kind, getThemeKey)
    local widget = createPreview[kind]()
    local applySettings, onRelease = widget.ApplySettings, widget.OnRelease
    local scripts = {}
    widget.OnRelease = function(self)
        self.ApplySettings = applySettings
        self.OnRelease = onRelease
        for frame, script in pairs(scripts) do frame:SetScript("OnUpdate", script) end
        for i = #previews, 1, -1 do
            if previews[i] == self then table.remove(previews, i) end
        end
        onRelease(self)
    end
    if getThemeKey then
        local applySettings = widget.ApplySettings
        widget.ApplySettings = function(self)
            private.DrawInTheme(getThemeKey(), applySettings, self)
        end
        -- the countdown reads the theme's colors every frame, the timeline's sparkles as they spawn
        for _, frame in ipairs({ widget.frame, widget.frame.Sparkles and widget.frame.Sparkles.driver }) do
            local onUpdate = frame:GetScript("OnUpdate")
            if onUpdate then
                scripts[frame] = onUpdate
                frame:SetScript("OnUpdate", function(...)
                    private.DrawInTheme(getThemeKey(), onUpdate, ...)
                end)
            end
        end
        widget:ApplySettings()
    end
    return widget
end

local pagePreviews = {}

---the GetPreview of a page, its preview of kind is built the first time
---@param kind string
---@return function
local getPreview = function(kind)
    return function()
        pagePreviews[kind] = pagePreviews[kind] or private.CreateSettingsPreview(kind)
        return pagePreviews[kind].frame
    end
end

local refreshPreviews = function()
    for _, widget in ipairs(previews) do
        widget:ApplySettings()
    end
end

---a checkbox of a profile setting that only changes the previews, e.g. "icon_settings.roleIcons"
---@param key string
---@param path string
---@return table
local profileToggle = function(key, path)
    return row("Checkbox", key, { profileKey = path, onChange = refreshPreviews })
end

-- the key every color source is shown under, per settings table
local shownSources = {}

---the sources a spell name is colored by. A source answering for several keys of the order (a fallback for an addon
---not loaded) is shown once, under the highest of them; keys no source answers for are not shown
---@param settings string
---@return table<string, string>
colorSources = function(settings)
    local values = { default = L("ColorSourceDefault") }
    shownSources[settings] = {}
    for _, key in ipairs(private.db.profile[settings].colorOrder) do
        local source = private.manager.getColorSource(key)
        if source and not shownSources[settings][source] then
            shownSources[settings][source] = key
            values[key] = L(source.name)
        end
    end
    return values
end

---@param settings string
---@return fun(order: string[])
local onColorOrderChanged = function(settings)
    return function(order)
        -- the keys of a source that are not shown follow the shown one
        local shown, followers, sorted = shownSources[settings], {}, {}
        for _, key in ipairs(order) do
            local source = private.manager.getColorSource(key)
            if source and shown[source] ~= key then
                followers[source] = followers[source] or {}
                table.insert(followers[source], key)
            end
        end
        for _, key in ipairs(order) do
            local source = private.manager.getColorSource(key)
            if not source or shown[source] == key then
                table.insert(sorted, key)
                for _, follower in ipairs(source and followers[source] or {}) do
                    table.insert(sorted, follower)
                end
            end
        end
        for index, key in ipairs(sorted) do
            order[index] = key
        end
        refreshPreviews()
        private.RefreshEventColorisation()
    end
end

---the theme's text anchor of kind fits the direction its text can go, e.g. a spell icon's text is never above it
---@param path string
---@param vertical boolean
local alignTextAnchor = function(path, vertical)
    local anchor = private.GetThemeValue(path)
    local aligned = vertical and { RIGHT = "TOP", LEFT = "BOTTOM" } or { TOP = "RIGHT", BOTTOM = "LEFT" }
    if aligned[anchor] then
        private.SetThemeModification(path, aligned[anchor])
    end
end

local TEXT_ANCHORS = {
    [true] = {
        values = { TOP = L("TextAnchorTop"), BOTTOM = L("TextAnchorBottom") },
        sorting = { "TOP", "BOTTOM" },
    },
    [false] = {
        values = { RIGHT = L("TextAnchorRight"), LEFT = L("TextAnchorLeft") },
        sorting = { "RIGHT", "LEFT" },
    },
}

---the rows of a spell name's text
---@param kind string
---@param options table -- anchors (TEXT_ANCHORS entry), flags
---@return table[]
local textRows = function(kind, options)
    local style = "Elements." .. kind .. ".Text"
    local backgroundOff = function()
        return not private.GetThemeValue(style .. ".Background.Show")
    end
    local rows = { heading("TextSettings") }
    if options.anchors then
        table.insert(rows, row("Dropdown", "TextAnchor", {
            themePath = style .. ".Anchor",
            values = options.anchors.values,
            sorting = options.anchors.sorting,
        }))
        table.insert(rows, row("Slider", "TextOffsetX",
            { themePath = style .. ".Offset.x", minValue = -50, maxValue = 50, valueStep = 1 }))
        table.insert(rows, row("Slider", "TextOffsetY",
            { themePath = style .. ".Offset.y", minValue = -50, maxValue = 50, valueStep = 1 }))
    end
    table.insert(rows, row("Media", "SpellnameFont", { themePath = style .. ".Font.Media", mediaType = "font" }))
    table.insert(rows, row("Slider", "SpellnameFontSize",
        { themePath = style .. ".Font.Size", minValue = 1, maxValue = 64, valueStep = 1 }))
    if options.flags then
        table.insert(rows, row("Dropdown", "SpellnameFontFlag", {
            themePath = style .. ".Font.Flags",
            multiselect = true,
            values = listOf({ "MONOCHROME", "OUTLINE", "THICKOUTLINE", "SLUG" }),
            sorting = { "MONOCHROME", "OUTLINE", "THICKOUTLINE", "SLUG" },
        }))
    end
    local settings = variables.colorSettings[kind]
    table.insert(rows, row("Order", "SpellnameColorOrder", {
        profileKey = settings .. ".colorOrder",
        values = function() return colorSources(settings) end,
        onChange = onColorOrderChanged(settings),
    }))
    table.insert(rows, row("Color", "SpellnameDefaultColor", { themePath = style .. ".Font.Color" }))
    table.insert(rows, row("Checkbox", "SpellnameEnableShadow", { themePath = style .. ".Font.Shadow" }))
    table.insert(rows, row("Checkbox", "SpellnameBackground", { themePath = style .. ".Background.Show" }))
    table.insert(rows, row("Media", "SpellnameBackgroundTexture", {
        themePath = style .. ".Background.Media",
        mediaType = "background",
        hidden = backgroundOff,
    }))
    table.insert(rows, row("Slider", "TextBackgroundOffsetX", {
        themePath = style .. ".Background.Offset.x", minValue = -50, maxValue = 50, valueStep = 1,
        hidden = backgroundOff,
    }))
    table.insert(rows, row("Slider", "TextBackgroundOffsetY", {
        themePath = style .. ".Background.Offset.y", minValue = -50, maxValue = 50, valueStep = 1,
        hidden = backgroundOff,
    }))
    return rows
end

---the rows of the markers around an icon: dispel, role and danger icons and its border
---@param kind string
---@param settings string -- the db.profile table of its settings
---@return table[]
local markerRows = function(kind, settings)
    local style = "Elements." .. kind
    local isOff = function(key)
        return function()
            return not private.db.profile[settings][key]
        end
    end
    local markerSize = function(key, path, off)
        return row("Slider", key, { themePath = path, minValue = 1, maxValue = 64, valueStep = 1, hidden = off })
    end
    local markerAnchor = function(key, path, off)
        return row("Dropdown", key,
            { themePath = path, values = anchorValues, sorting = private.AnchorPointOrder, hidden = off })
    end
    local markerOffset = function(key, path, off)
        return row("Slider", key, { themePath = path, minValue = -100, maxValue = 100, valueStep = 1, hidden = off })
    end
    local dispelOff, roleOff = isOff("dispellIcons"), isOff("roleIcons")
    return {
        heading("SettingsSectionDispel"),
        profileToggle("IconDispellIcon", settings .. ".dispellIcons"),
        markerSize("DispellIconSize", style .. ".DispelIcon.Size", dispelOff),
        markerAnchor("DispellIconAnchor", style .. ".DispelIcon.Anchor", dispelOff),
        markerOffset("DispellIconOffsetX", style .. ".DispelIcon.Offset.x", dispelOff),
        markerOffset("DispellIconOffsetY", style .. ".DispelIcon.Offset.y", dispelOff),
        heading("SettingsSectionRole"),
        profileToggle("IconRoleIcons", settings .. ".roleIcons"),
        markerSize("RoleIconSize", style .. ".RoleIcons.Size", roleOff),
        markerAnchor("RoleIconAnchor", style .. ".RoleIcons.Anchor", roleOff),
        markerOffset("RoleIconOffsetX", style .. ".RoleIcons.Offset.x", roleOff),
        markerOffset("RoleIconOffsetY", style .. ".RoleIcons.Offset.y", roleOff),
        heading("SettingsSectionDanger"),
        profileToggle("IconDangerIcon", settings .. ".dangerIcon"),
        heading("SettingsSectionBorder"),
        row("Dropdown", "IconBorder", {
            profileKey = settings .. ".border",
            values = {
                [private.IconBorderSettings.dispell] = L("IconDispellBorder"),
                [private.IconBorderSettings.bossmods] = L("IconBossModsBorder"),
                [private.IconBorderSettings.none] = L("IconNoneBorder"),
            },
            sorting = {
                private.IconBorderSettings.dispell,
                private.IconBorderSettings.bossmods,
                private.IconBorderSettings.none,
            },
            onChange = refreshPreviews,
        }),
        row("Slider", "IconBorderWidth", {
            themePath = style .. ".BorderWidth", minValue = 1, maxValue = 20, valueStep = 1,
            hidden = function()
                return private.db.profile[settings].border == private.IconBorderSettings.none
            end,
        }),
    }
end

---the look of the duration and heartbeat lanes, shared by spell icons and big icons
---@return table[]
local durationRows = function()
    return {
        heading("SettingsSectionDuration"),
        row("Slider", "DurationThickness", { themePath = "Elements.Duration.Thickness", minValue = 1, maxValue = 12, valueStep = 0.5 }),
        row("Checkbox", "DurationUseCountdownColor", { themePath = "Elements.Duration.UseCountdownColor" }),
        row("Color", "DurationColor", {
            themePath = "Elements.Duration.Color",
            hidden = function() return private.GetThemeValue("Elements.Duration.UseCountdownColor") ~= false end,
        }),
        row("Slider", "DurationPips", { themePath = "Elements.Duration.Pips.Count", minValue = 1, maxValue = 10, valueStep = 1 }),
        row("Slider", "DurationHeartbeatAlpha", {
            themePath = "Elements.Duration.Heartbeat.Alpha", minValue = 0.1, maxValue = 1, valueStep = 0.05, isPercent = true,
        }),
    }
end

---the rows of an icon itself, size only when it is not saved per Edit Mode layout
---@param kind string
---@param settings string
---@param withSize boolean
---@return table[]
local iconRows = function(kind, settings, withSize)
    local style = "Elements." .. kind
    local rows = { heading("SettingsSectionIcon") }
    if withSize then
        table.insert(rows, row("Slider", "IconSize",
            { themePath = style .. ".Size", minValue = 1, maxValue = 100, valueStep = 1 }))
    end
    table.insert(rows, row("Slider", "IconZoom",
        { themePath = style .. ".Zoom", minValue = 0, maxValue = 1, valueStep = 0.01, isPercent = true }))
    table.insert(rows, row("Dropdown", "Strata", {
        profileKey = settings .. ".strata",
        values = strataValues,
        sorting = private.FrameStrataOrder,
        onChange = refreshPreviews,
    }))
    table.insert(rows, row("Dropdown", "UseTooltip", {
        profileKey = settings .. ".useTooltip",
        values = function()
            local values = {}
            for key, value in pairs(Enum.EncounterEventsTooltipAnchor) do
                values[value] = key
            end
            return values
        end,
        hidden = function()
            return not (Enum and Enum.EncounterEventsTooltipAnchor)
        end,
    }))
    return rows
end

---@param ... table[]
---@return table[]
local join = function(...)
    local rows = {}
    for i = 1, select("#", ...) do
        for _, item in ipairs((select(i, ...))) do
            table.insert(rows, item)
        end
    end
    return rows
end

local SORT = private.DynamicGroup.SORT

---the rows of how many elements a group shows and in which order, kept in the db.profile table at path
---@param path string
---@param onChange function
---@param asText boolean|nil -- its preview shows texts instead of icons
---@param inactive function|nil -- greys the rows out while it returns true
---@param inactiveReason string|nil
---@return table[]
local groupRows = function(path, onChange, asText, inactive, inactiveReason)
    local reason = inactiveReason and function() return L(inactiveReason) end
    local preview = groupPreview(path, asText)
    local changed = function()
        onChange()
        refreshPreviews()
    end
    return {
        row("Slider", "GroupLimit", {
            profileKey = path .. ".limit", minValue = 0, maxValue = 20, valueStep = 1,
            onChange = changed, disabled = inactive, disabledReason = reason, preview = preview,
        }),
        row("Dropdown", "GroupSort", {
            profileKey = path .. ".sort",
            values = { [SORT.ASCENDING] = L("GroupSortAscending"), [SORT.DESCENDING] = L("GroupSortDescending") },
            sorting = { SORT.ASCENDING, SORT.DESCENDING },
            onChange = changed, disabled = inactive, disabledReason = reason, preview = preview,
        }),
    }
end

---greys out a page while its display is turned off in the active Edit Mode layout, or warns that only reminders
---use it while they still show there. Both texts are the localisation of "Settings" .. page.key .. "Disabled" or
---"RemindersOnly" naming the layout and the Edit Mode checkbox of enableKey
---@param page table
---@param isEnabled function
---@param enableKey string
---@return table page
local turnedOffInEditMode = function(page, isEnabled, enableKey)
    local reason = function(key)
        return L("Settings" .. page.key .. key):format(private.ACTIVE_EDITMODE_LAYOUT, L(enableKey))
    end
    page.disabled = function()
        return not isEnabled() and not private.db.profile.showRemindersInDisabledDisplays
    end
    page.disabledReason = function()
        return reason("Disabled")
    end
    page.notice = function()
        return not isEnabled() and reason("RemindersOnly") or nil
    end
    return page
end

---@param key string -- the db.global table of a setting saved per Edit Mode layout
---@return any
local layoutSettings = function(key)
    return private.db.global[key] and private.db.global[key][private.ACTIVE_EDITMODE_LAYOUT]
end

local spellIconRows = join(
    iconRows("SpellIcon", "icon_settings", true),
    textRows("SpellIcon", { anchors = TEXT_ANCHORS[false], flags = true }),
    markerRows("SpellIcon", "icon_settings"),
    durationRows())

private.RegisterSettingsPage({
    key = "SpellIcons",
    order = 20,
    name = L("SettingsPageSpellIcons"),
    desc = L("SettingsPageSpellIconsDescription"),
    GetPreview = getPreview("SpellIcon"),
    rows = function()
        alignTextAnchor("Elements.SpellIcon.Text.Anchor", false)
        return spellIconRows
    end,
})

---big icons in a row have their names above or below them, in a column next to them
---@return boolean
local isBigIconTextVertical = function()
    local layout = private.db.global.bigicon and private.db.global.bigicon[private.ACTIVE_EDITMODE_LAYOUT]
    local grow = layout and layout.grow_direction
    return grow == "RIGHT" or grow == "LEFT" or grow == "HORIZONTAL"
end

local bigIconGeneralRows = join({
    heading("SettingsSectionGeneral"),
    row("Slider", "BigIconThreshold",
        { profileKey = "big_icon_settings.threshold_time", minValue = 1, maxValue = 30, valueStep = 1 }),
}, groupRows("big_icon_settings", function() private.evaluateBigIconPositions() end))

local bigIconRows = {}
for _, vertical in ipairs({ true, false }) do
    bigIconRows[vertical] = join(
        bigIconGeneralRows,
        iconRows("BigIcon", "big_icon_settings", false),
        textRows("BigIcon", { anchors = TEXT_ANCHORS[vertical], flags = true }),
        markerRows("BigIcon", "big_icon_settings"),
        durationRows())
end

private.RegisterSettingsPage(turnedOffInEditMode({
    key = "BigIcon",
    order = 30,
    name = L("SettingsPageBigIcon"),
    desc = L("SettingsPageBigIconDescription"),
    GetPreview = getPreview("BigIcon"),
    rows = function()
        local vertical = isBigIconTextVertical()
        alignTextAnchor("Elements.BigIcon.Text.Anchor", vertical)
        return bigIconRows[vertical]
    end,
}, function() return layoutSettings("bigicon_enabled") end, "EnableBigIcon"))

private.RegisterSettingsPage(turnedOffInEditMode({
    key = "TextHighlight",
    order = 40,
    name = L("SettingsPageTextHighlight"),
    desc = L("SettingsPageTextHighlightDescription"),
    GetPreview = getPreview("TextHighlight"),
    rows = join({
        heading("SettingsSectionGeneral"),
        row("Slider", "TextHighlightThreshold",
            { profileKey = "highlight_text_settings.threshold_time", minValue = 1, maxValue = 30, valueStep = 1 }),
    }, groupRows("highlight_text_settings", function() private.evaluateTextPositions() end, true), {
        row("Dropdown", "Strata", {
            profileKey = "highlight_text_settings.strata",
            values = strataValues,
            sorting = private.FrameStrataOrder,
            onChange = refreshPreviews,
        }),
        profileToggle("TextDispellIcon", "highlight_text_settings.dispellIcons"),
    }, textRows("TextHighlight", {})),
}, function() return layoutSettings("text_highlight_enabled") end, "EnableTextHighlight"))

---hides a row while the SharedMedia texture or border at path is None, e.g. a border color without a border
---@param path string
---@return function
local isNone = function(path)
    return function()
        return private.GetThemeValue(path) == "None"
    end
end

local refreshTimeline = function()
    private.TimelineFrame.applyLayout(private.ACTIVE_EDITMODE_LAYOUT)
    refreshPreviews()
end

local refreshTimelineGroups = function()
    private.refreshTimelineGroups()
end

private.RegisterSettingsPage(turnedOffInEditMode({
    key = "Timeline",
    order = 17,
    name = L("SettingsPageTimeline"),
    desc = L("SettingsPageTimelineDescription"),
    GetPreview = getPreview("Timeline"),
    rows = join({
        heading("SettingsSectionBackground"),
        row("Media", "TimelineTexture", { themePath = "Elements.Timeline.Backdrop.Background", mediaType = "background" }),
        row("Color", "TimelineTextureColor", {
            themePath = "Elements.Timeline.Backdrop.Color",
            hasOpacity = true,
            hidden = isNone("Elements.Timeline.Backdrop.Background"),
        }),
        heading("SettingsSectionBorder"),
        row("Media", "TimelineBorder", { themePath = "Elements.Timeline.Backdrop.Border", mediaType = "border" }),
        row("Color", "TimelineBorderColor", {
            themePath = "Elements.Timeline.Backdrop.BorderColor",
            hasOpacity = true,
            hidden = isNone("Elements.Timeline.Backdrop.Border"),
        }),
        row("Slider", "TimelineBorderSize", {
            themePath = "Elements.Timeline.Backdrop.EdgeSize",
            minValue = 1,
            maxValue = 32,
            valueStep = 1,
            hidden = isNone("Elements.Timeline.Backdrop.Border"),
        }),
        heading("SettingsSectionTimeScale"),
        row("Slider", "TimelineWindow", {
            profileKey = "timeline_settings.threshold_time", minValue = 5, maxValue = 60, valueStep = 1,
            onChange = refreshTimeline, preview = false,
        }),
        heading("SettingsSectionTicks"),
        row("Checkbox", "EnableTicks", {
            profileKey = "timeline_settings.ticks_enabled", onChange = refreshTimeline, preview = getPreview("Ticks"),
        }),
        heading("SettingsSectionOverlap"),
        row("Checkbox", "PreventOverlap", { profileKey = "timeline_settings.prevent_overlap", preview = false }),
        {
            kind = "Heading",
            name = L("SettingsSectionTimerText"),
            hidden = function() return not private.isRetail end,
        },
        {
            kind = "Checkbox",
            name = COMBAT_WARNINGS_HIDE_QUEUED_COUNTDOWNS_LABEL,
            desc = COMBAT_WARNINGS_HIDE_QUEUED_COUNTDOWNS_TOOLTIP,
            hidden = function() return not private.isRetail end,
            preview = false,
            get = function()
                return C_CVar.GetCVar("encounterTimelineHideQueuedCountdowns") == "1"
            end,
            set = function(value)
                C_CVar.SetCVar("encounterTimelineHideQueuedCountdowns", value and "1" or "0")
            end,
        },
        heading("SettingsSectionWaitingGroup"),
    }, groupRows("waiting_group", refreshTimelineGroups),
    { heading("SettingsSectionQueuedGroup") },
    groupRows("queued_group", refreshTimelineGroups),
    { heading("SettingsSectionPausedGroup") },
    groupRows("paused_group", refreshTimelineGroups, false, function()
        return private.PAUSED_FRAME ~= nil and not private.PAUSED_FRAME:IsActive()
    end, "SettingsPausedGroupInactive")),
}, function()
    local layout = layoutSettings("timeline_frame")
    return layout and layout.enabled
end, "EnableTimeline"))

