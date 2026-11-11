local appName, app = ...
---@class AbilityTimeline
local private = app
local SharedMedia = LibStub("LibSharedMedia-3.0")

local WHITE = { r = 1, g = 1, b = 1, a = 1 }
local WHITE_RGB = { r = 1, g = 1, b = 1 }
local FONT = "Friz Quadrata TT"
local BACKGROUND = "Blizzard Dialog Background"

-- visual settings from before themes: { settings table, key, theme path, default before themes }
local THEMED_SETTINGS = {
    { "icon_settings", "size", "Elements.SpellIcon.Size", 44 },
    { "icon_settings", "zoom", "Elements.SpellIcon.Zoom", 0.3 },
    { "icon_settings", "TextOffset", "Elements.SpellIcon.Text.Offset", { x = 16, y = 0 } },
    { "icon_settings", "borderWidth", "Elements.SpellIcon.BorderWidth", 3 },
    { "icon_settings", "roleIconSize", "Elements.SpellIcon.RoleIcons.Size", 16 },
    { "icon_settings", "roleIconAnchor", "Elements.SpellIcon.RoleIcons.Anchor", "RIGHT" },
    { "icon_settings", "roleIconOffset", "Elements.SpellIcon.RoleIcons.Offset", { x = 18, y = 0 } },
    { "icon_settings", "dispellIconSize", "Elements.SpellIcon.DispelIcon.Size", 16 },
    { "icon_settings", "dispellIconAnchor", "Elements.SpellIcon.DispelIcon.Anchor", "BOTTOMRIGHT" },
    { "icon_settings", "dispellIconOffset", "Elements.SpellIcon.DispelIcon.Offset", { x = -3, y = 3 } },
    { "text_settings", "text_anchor", "Elements.SpellIcon.Text.Anchor", "LEFT" },
    { "text_settings", "fontSize", "Elements.SpellIcon.Text.Font.Size", 14 },
    { "text_settings", "font", "Elements.SpellIcon.Text.Font.Media", FONT },
    { "text_settings", "fontFlag", "Elements.SpellIcon.Text.Font.Flags", { OUTLINE = true } },
    { "text_settings", "defaultColor", "Elements.SpellIcon.Text.Font.Color", WHITE_RGB },
    { "text_settings", "enableShadow", "Elements.SpellIcon.Text.Font.Shadow", true },
    { "text_settings", "useBackground", "Elements.SpellIcon.Text.Background.Show", false },
    { "text_settings", "backgroundTexture", "Elements.SpellIcon.Text.Background.Media", BACKGROUND },
    { "text_settings", "backgroundTextureOffset", "Elements.SpellIcon.Text.Background.Offset", { x = 10, y = 10 } },
    { "big_icon_settings", "size", "Elements.BigIcon.Size", 100 },
    { "big_icon_settings", "zoom", "Elements.BigIcon.Zoom", 0.3 },
    { "big_icon_settings", "TextOffset", "Elements.BigIcon.Text.Offset", { x = 0, y = 10 } },
    { "big_icon_settings", "borderWidth", "Elements.BigIcon.BorderWidth", 3 },
    { "big_icon_settings", "roleIconSize", "Elements.BigIcon.RoleIcons.Size", 16 },
    { "big_icon_settings", "roleIconAnchor", "Elements.BigIcon.RoleIcons.Anchor", "TOP" },
    { "big_icon_settings", "roleIconOffset", "Elements.BigIcon.RoleIcons.Offset", { x = 0, y = 18 } },
    { "big_icon_settings", "dispellIconSize", "Elements.BigIcon.DispelIcon.Size", 16 },
    { "big_icon_settings", "dispellIconAnchor", "Elements.BigIcon.DispelIcon.Anchor", "BOTTOMRIGHT" },
    { "big_icon_settings", "dispellIconOffset", "Elements.BigIcon.DispelIcon.Offset", { x = -3, y = 3 } },
    { "big_icon_text_settings", "text_anchor", "Elements.BigIcon.Text.Anchor", "BOTTOM" },
    { "big_icon_text_settings", "fontSize", "Elements.BigIcon.Text.Font.Size", 20 },
    { "big_icon_text_settings", "font", "Elements.BigIcon.Text.Font.Media", FONT },
    { "big_icon_text_settings", "fontFlag", "Elements.BigIcon.Text.Font.Flags", { OUTLINE = true } },
    { "big_icon_text_settings", "defaultColor", "Elements.BigIcon.Text.Font.Color", WHITE_RGB },
    { "big_icon_text_settings", "enableShadow", "Elements.BigIcon.Text.Font.Shadow", true },
    { "big_icon_text_settings", "useBackground", "Elements.BigIcon.Text.Background.Show", false },
    { "big_icon_text_settings", "backgroundTexture", "Elements.BigIcon.Text.Background.Media", BACKGROUND },
    { "big_icon_text_settings", "backgroundTextureOffset", "Elements.BigIcon.Text.Background.Offset", { x = 0, y = 0 } },
    { "highlight_text_settings", "fontSize", "Elements.TextHighlight.Text.Font.Size", 14 },
    { "highlight_text_settings", "font", "Elements.TextHighlight.Text.Font.Media", FONT },
    { "highlight_text_settings", "defaultColor", "Elements.TextHighlight.Text.Font.Color", WHITE_RGB },
    { "highlight_text_settings", "enableShadow", "Elements.TextHighlight.Text.Font.Shadow", true },
    { "highlight_text_settings", "useBackground", "Elements.TextHighlight.Text.Background.Show", false },
    { "highlight_text_settings", "backgroundTexture", "Elements.TextHighlight.Text.Background.Media", BACKGROUND },
    { "highlight_text_settings", "backgroundTextureOffset", "Elements.TextHighlight.Text.Background.Offset", { x = 0, y = 0 } },
    { "cooldown_settings", "fontSize", "Elements.Cooldown.Font.Size", 24 },
    { "cooldown_settings", "font", "Elements.Cooldown.Font.Media", FONT },
    { "cooldown_settings", "cooldown_color", "Elements.Cooldown.Font.Color", WHITE_RGB },
}

-- visual settings of the timeline that were stored per edit mode layout
local THEMED_LAYOUT_SETTINGS = {
    { "timeline_texture", "Elements.Timeline.Backdrop.Background", BACKGROUND },
    { "timeline_texture_color", "Elements.Timeline.Backdrop.Color", WHITE },
    { "timeline_border", "Elements.Timeline.Backdrop.Border", "None" },
    { "timeline_border_color", "Elements.Timeline.Backdrop.BorderColor", WHITE },
    { "timeline_border_size", "Elements.Timeline.Backdrop.EdgeSize", 2 },
}

-- behaviour settings that were stored per edit mode layout and are now in the profile:
-- { db.global key, key, db.profile table, default }
local LAYOUT_TO_PROFILE = {
    { "timeline_frame", "threshold_time", "timeline_settings", 10 },
    { "timeline_frame", "ticks_enabled", "timeline_settings", true },
    { "timeline_frame", "prevent_overlap", "timeline_settings", true },
    { "timeline_frame", "merge_timers", "timeline_settings", true },
    { "timeline_frame", "merge_window", "timeline_settings", 0.2 },
    { "bigicon", "threshold_time", "big_icon_settings", 5 },
    { "bigicon", "limit", "big_icon_settings", 0 },
    { "bigicon", "sort", "big_icon_settings", "ascending" },
    { "text_highlight", "threshold_time", "highlight_text_settings", 5 },
    { "text_highlight", "limit", "highlight_text_settings", 0 },
    { "text_highlight", "sort", "highlight_text_settings", "ascending" },
    { "waiting_group", "limit", "waiting_group", 0 },
    { "waiting_group", "sort", "waiting_group", "ascending" },
    { "queued_group", "limit", "queued_group", 0 },
    { "queued_group", "sort", "queued_group", "ascending" },
    { "paused_group", "limit", "paused_group", 0 },
    { "paused_group", "sort", "paused_group", "ascending" },
}

---the profiles that existed while these were saved per layout get the values of the active layout, once; the
---old values stay untouched. A reset or new profile gets the defaults
local migrateLayoutToProfile = function()
    local global = private.db.global
    if not global.layoutSettingsPending then
        global.layoutSettingsPending = {}
        for _, name in ipairs((private.db:GetProfiles())) do
            global.layoutSettingsPending[name] = true
        end
    end
    local profileName = private.db:GetCurrentProfile()
    local fromLayout = global.layoutSettingsPending[profileName]
    global.layoutSettingsPending[profileName] = nil
    for _, setting in ipairs(LAYOUT_TO_PROFILE) do
        local profileTable = private.db.profile[setting[3]] or {}
        private.db.profile[setting[3]] = profileTable
        if profileTable[setting[2]] == nil then
            local layouts = fromLayout and global[setting[1]]
            local layout = layouts and layouts[private.ACTIVE_EDITMODE_LAYOUT]
            local value = layout and layout[setting[2]]
            if value == nil then
                value = setting[4]
            end
            profileTable[setting[2]] = value
        end
    end
end

---copies a saved value without functions (colors from a color picker can be color objects)
local function plainCopy(value)
    if type(value) ~= "table" then
        return value
    end
    local copy = {}
    for k, v in pairs(value) do
        if type(v) ~= "function" then
            copy[k] = plainCopy(v)
        end
    end
    return copy
end

local function isEqual(value, default)
    if type(value) ~= "table" or type(default) ~= "table" then
        return value == default or (not value and not default)
    end
    for k, v in pairs(plainCopy(value)) do
        if not isEqual(v, default[k]) then
            return false
        end
    end
    for k, v in pairs(default) do
        if not isEqual(value[k], v) then
            return false
        end
    end
    return true
end

---stores every visual setting changed from its old default as a modification of the Classic theme,
---the old settings stay untouched
local migrateToThemes = function()
    local modifications = {}
    local addModification = function(path, value, default)
        if value == nil or isEqual(value, default) then return end
        local node = modifications
        local keys = { strsplit(".", path) }
        for i = 1, #keys - 1 do
            node[keys[i]] = node[keys[i]] or {}
            node = node[keys[i]]
        end
        node[keys[#keys]] = plainCopy(value)
    end
    for _, setting in ipairs(THEMED_SETTINGS) do
        local settings = private.db.profile[setting[1]]
        if settings then
            addModification(setting[3], settings[setting[2]], setting[4])
        end
    end
    local layout = private.db.global.timeline_frame[private.ACTIVE_EDITMODE_LAYOUT]
    if layout then
        for _, setting in ipairs(THEMED_LAYOUT_SETTINGS) do
            addModification(setting[2], layout[setting[1]], setting[3])
        end
    end
    if next(modifications) then
        local themeModifications = private.GetThemeSettings().modifications
        themeModifications[private.DEFAULT_THEME] = themeModifications[private.DEFAULT_THEME] or {}
        private.MergeTables(themeModifications[private.DEFAULT_THEME], modifications)
    end
    private.GetThemeSettings().migrated = true
end

---converts saved theme art backgrounds to file specs now that the art has its own media type
local function migrateThemeMedia(node)
    local changed = false
    for _, key in ipairs({ "Media", "Background" }) do
        local value = node[key]
        local name = type(value) == "string" and (value:match("^AbilityTimeline (.+)$") or value:match("^BT (.+)$"))
        local path = name and SharedMedia:Fetch(private.ThemeMediaType, private.MediaName(name), true)
        if path then
            if key == "Media" then
                node.File = name
            else
                node.BgFile = path
            end
            node[key] = false
            changed = true
        end
    end
    for _, value in pairs(node) do
        if type(value) == "table" then
            changed = migrateThemeMedia(value) or changed
        end
    end
    return changed
end

private.modernize = function()
    if not private.db.global.timeline_frame then
        private.db.global.timeline_frame = {}
    end
    if private.db.profile.timeline_frame then
        private.db.global.timeline_frame = private.db.profile.timeline_frame
        private.db.profile.timeline_frame = nil
    end
    if private.db.profile.bigicon_frame then
        private.db.global.bigicon_frame = private.db.profile.bigicon_frame
        private.db.profile.bigicon_frame = nil
    end
    if private.db.profile.text_highlight_frame then
        private.db.global.text_highlight_frame = private.db.profile.text_highlight_frame
        private.db.profile.text_highlight_frame = nil
    end
    if not private.db.global.timeline_frame[private.ACTIVE_EDITMODE_LAYOUT] then
        private.db.global.timeline_frame[private.ACTIVE_EDITMODE_LAYOUT] = {}
    end
    private.ModernizeTimelineFrame(private.ACTIVE_EDITMODE_LAYOUT)

    if not private.db.profile.reminders then
        private.db.profile.reminders = {}
    end

    if not private.db.profile.editor then
        private.db.profile.editor = {}
    end
    if not private.db.profile.editor.defaultEncounterDuration then
        private.db.profile.editor.defaultEncounterDuration = 300
    end
    if not private.db.profile.audioCountdownTime then
        private.db.profile.audioCountdownTime = 5
    end
    if private.db.profile.useTimelineModule == nil then
        private.db.profile.useTimelineModule = true
    end
    if private.db.global.timeline_frame[private.ACTIVE_EDITMODE_LAYOUT].height then
        private.db.global.timeline_frame[private.ACTIVE_EDITMODE_LAYOUT].travelSize = private.db.global.timeline_frame
            [private.ACTIVE_EDITMODE_LAYOUT].height
        private.db.global.timeline_frame[private.ACTIVE_EDITMODE_LAYOUT].height = nil
    end
    if not private.db.global.timeline_frame[private.ACTIVE_EDITMODE_LAYOUT].otherSize then
        private.db.global.timeline_frame[private.ACTIVE_EDITMODE_LAYOUT].otherSize = private.db.global.timeline_frame
            [private.ACTIVE_EDITMODE_LAYOUT].width
    end

    if not private.db.global.timeline_frame[private.ACTIVE_EDITMODE_LAYOUT].travel_direction then
        private.db.global.timeline_frame[private.ACTIVE_EDITMODE_LAYOUT].travel_direction = private.TIMELINE_DIRECTIONS
        .VERTICAL
    end

    if not private.db.profile.icon_settings then
        private.db.profile.icon_settings = {}
    end
    if private.db.profile.icon_settings.border == nil then
        if private.db.profile.icon_settings.dispellBorders == true then
            private.db.profile.icon_settings.border = private.IconBorderSettings.dispell
            private.db.profile.icon_settings.dispellBorders = nil
        elseif private.db.profile.icon_settings.dispellBorders == false then
            private.db.profile.icon_settings.border = private.IconBorderSettings.none
            private.db.profile.icon_settings.dispellBorders = nil
        else
            private.db.profile.icon_settings.border = private.IconBorderSettings.dispell
        end
    end
    if private.db.profile.icon_settings.dispellIcons == nil then
        private.db.profile.icon_settings.dispellIcons = true
    end
    if private.db.profile.icon_settings.dangerIcon == nil then
        private.db.profile.icon_settings.dangerIcon = true
    end

    if private.db.profile.icon_settings.roleIcons == nil then
        private.db.profile.icon_settings.roleIcons = true
    end

    if private.db.profile.icon_settings.strata == nil then
        private.db.profile.icon_settings.strata = private.FrameStrata.FULLSCREEN
    end

    if not private.db.profile.big_icon_settings then
        private.db.profile.big_icon_settings = {}
    end

    if private.db.profile.big_icon_settings.strata == nil then
        private.db.profile.big_icon_settings.strata = UIParent:GetFrameStrata()
    end

    if private.db.profile.big_icon_settings.border == nil then
        if private.db.profile.big_icon_settings.dispellBorders == true then
            private.db.profile.big_icon_settings.border = private.IconBorderSettings.dispell
            private.db.profile.big_icon_settings.dispellBorders = nil
        elseif private.db.profile.big_icon_settings.dispellBorders == false then
            private.db.profile.big_icon_settings.border = private.IconBorderSettings.none
            private.db.profile.big_icon_settings.dispellBorders = nil
        else
            private.db.profile.big_icon_settings.border = private.IconBorderSettings.dispell
        end
    end
    if private.db.profile.big_icon_settings.dispellIcons == nil then
        private.db.profile.big_icon_settings.dispellIcons = true
    end
    if private.db.profile.big_icon_settings.dangerIcon == nil then
        private.db.profile.big_icon_settings.dangerIcon = true
    end

    if private.db.profile.big_icon_settings.roleIcons == nil then
        private.db.profile.big_icon_settings.roleIcons = false
    end

    if not private.db.profile.text_settings then
        private.db.profile.text_settings = {}
    end
    if not private.db.profile.big_icon_text_settings then
        private.db.profile.big_icon_text_settings = {}
    end
    if not private.db.profile.highlight_text_settings then
        private.db.profile.highlight_text_settings = {}
    end
    if private.db.profile.highlight_text_settings.dispellIcons == nil then
        private.db.profile.highlight_text_settings.dispellIcons = true
    end

    if private.db.profile.highlight_text_settings.strata == nil then
        private.db.profile.highlight_text_settings.strata = private.FrameStrata.FULLSCREEN
    end

    if private.db.global.timeline_frame[private.ACTIVE_EDITMODE_LAYOUT].text_anchor then
        private.db.profile.big_icon_text_settings.text_anchor = private.db.global.timeline_frame
        [private.ACTIVE_EDITMODE_LAYOUT].text_anchor
        private.db.global.timeline_frame[private.ACTIVE_EDITMODE_LAYOUT].text_anchor = nil
    end

    if not private.db.profile.cooldown_settings then
        private.db.profile.cooldown_settings = {}
    end

    private.CooldownText.SetupDefaults(private.db.profile.cooldown_settings)

    if private.db.profile.importMergeMode == nil then
        private.db.profile.importMergeMode = true
    end

    if private.db.profile.disableBossModsBars == nil then
        private.db.profile.disableBossModsBars = true
    end

    if private.db.profile.disableBossModsEmphasisedBars == nil then
        private.db.profile.disableBossModsEmphasisedBars = true
    end

    if private.db.profile.text_settings.useEventColor == nil then
        private.db.profile.text_settings.useEventColor = true
    end

    if private.db.profile.big_icon_settings.useTooltip == nil then
        if private.db.profile.big_icon_settings.enableTooltip ~= nil then
            if private.db.profile.big_icon_settings.enableTooltip then
                private.db.profile.big_icon_settings.useTooltip = Enum.EncounterEventsTooltipAnchor.Default
            else
                private.db.profile.big_icon_settings.useTooltip = Enum.EncounterEventsTooltipAnchor.Hidden
            end
        else
            private.db.profile.big_icon_settings.useTooltip = Enum.EncounterEventsTooltipAnchor.Hidden
        end
    end

    if private.db.profile.icon_settings.useTooltip == nil then
        if private.db.profile.icon_settings.enableTooltip ~= nil then
            if private.db.profile.icon_settings.enableTooltip then
                private.db.profile.icon_settings.useTooltip = Enum.EncounterEventsTooltipAnchor.Default
            else
                private.db.profile.icon_settings.useTooltip = Enum.EncounterEventsTooltipAnchor.Hidden
            end
            private.db.profile.icon_settings.enableTooltip = nil
        else
            private.db.profile.icon_settings.useTooltip = Enum.EncounterEventsTooltipAnchor.Hidden
        end
    end

    if private.db.profile.dispellTextColor == nil then
        if private.db.profile.icon_settings.dispellTextColor~=nil or private.db.profile.highlight_text_settings.dispellTextColor~=nil then
            private.db.profile.dispellTextColor = private.db.profile.icon_settings.dispellTextColor or private.db.profile.highlight_text_settings.dispellTextColor
            if private.db.profile.dispellTextColor then
                private.db.profile.text_settings.useEventColor = true
            end
            private.db.profile.icon_settings.dispellTextColor = nil
            private.db.profile.highlight_text_settings.dispellTextColor = nil
        else
            private.db.profile.dispellTextColor = true
        end
    end

    migrateLayoutToProfile()

    for _, key in ipairs({ "big_icon_settings", "highlight_text_settings", "waiting_group", "queued_group", "paused_group" }) do
        local settings = private.db.profile[key]
        if settings.merge_timers == nil then
            settings.merge_timers = private.db.profile.timeline_settings.merge_timers
        end
    end

    local restoreTheme = not private.GetThemeSettings().migrated
    if restoreTheme then
        migrateToThemes()
    end
    if migrateThemeMedia(private.GetThemeSettings().modifications) then
        restoreTheme = true
    end
    if restoreTheme then
        private.RestoreSavedTheme()
    end
end
