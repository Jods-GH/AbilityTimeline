local appName, app = ...
---@class AbilityTimeline
local private = app

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

    if not private.db.profile.cooldown_settings.cooldown_highlight then
        private.db.profile.cooldown_settings.cooldown_highlight = {}
    end

    if not private.db.profile.cooldown_settings.cooldown_highlight.enabled then
        private.db.profile.cooldown_settings.cooldown_highlight.enabled = true
    end

    if not private.db.profile.cooldown_settings.cooldown_highlight.highlights then
        private.db.profile.cooldown_settings.cooldown_highlight.highlights = {
            {
                time = 3,
                color = { r = 1, g = 0, b = 0 },
                useGlow = false,
                glowType = private.GlowTypes.PROC,
                glowColor = { r = 0.95, g = 0.95, b = 0.32, a = 1 },
            },
            {
                time = 5,
                color = { r = 1, g = 1, b = 0 },
                useGlow = false,
                glowType = private.GlowTypes.PROC,
                glowColor = { r = 0.95, g = 0.95, b = 0.32, a = 1 },
            },
        }
    end

    if private.db.profile.importMergeMode == nil then
        private.db.profile.importMergeMode = true
    end

    if private.db.profile.importRelevant == nil then
        private.db.profile.importRelevant = true
    end

    -- fix cooldown highlights missing essential settings
    for _, highlight in ipairs(private.db.profile.cooldown_settings.cooldown_highlight.highlights) do
        if highlight.useGlow == nil then
            highlight.useGlow = false
        end
        if highlight.glowType == nil then
            highlight.glowType = private.GlowTypes.PROC
        end
        if highlight.glowColor == nil then
            highlight.glowColor = { r = 0.95, g = 0.95, b = 0.32, a = 1 }
        end
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

    if not private.GetThemeSettings().migrated then
        migrateToThemes()
        private.RestoreSavedTheme()
    end
end
