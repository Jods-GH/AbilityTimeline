local appName, app = ...
---@class AbilityTimeline
local private = app

local engine = function()
    return ElvUI and ElvUI[1]
end

-- Read resolved media, not profile defaults: ElvUI has already applied class-color choices here.
local mediaColor = function(key, fallback)
    return function()
        local E = engine()
        local color = E and E.media and E.media[key]
        if not color then return fallback end
        return { color[1], color[2], color[3], color[4] or 1 }
    end
end

local FADE_IN = { Ghost = { Color = "Body", Alpha = 1, Fade = { 1, 0 }, Time = 0.18 } }
local FADE_OUT = { Ghost = { Color = "Body", Fade = { 1, 0 }, Time = 0.18 } }
local WINDOW = {
    Fill = "Body", Edge = "Edge", Wash = { 0, 0, 0, 0 }, HeaderLine = "Edge",
    Footer = "FooterFill", Enter = FADE_IN, Exit = FADE_OUT,
}

local fonts = {}
for role in pairs(private.Themes.Classic.Fonts) do
    fonts[role] = { Path = "$ElvFont", Shadow = false, Flags = {} }
end
fonts.ButtonPrimary.Color = "$ElvButtonText"

local iconStyle = function(pulse)
    return {
        -- Flat squares with a short staggered fade.
        QueuedMarkers = pulse and {
            Art = { File = false, Color = "White" }, Colors = { "Accent", "Accent", "Accent" },
            Size = 8, Spacing = 12, Offset = 5,
            Enter = { Time = 0.16, Stagger = 0.04 },
        } or false,
        Enter = FADE_IN,
        Exit = { Ghost = { Source = "Icon", Fade = { 1, 0 }, Time = 0.16 } },
        -- Classic's halo
        Pulse = pulse and {} or false,
        Text = { Font = { Media = false, Path = "$ElvFont" } },
    }
end

private.RegisterTheme({
    Name = "ElvUI",
    Addon = "ElvUI",
    DisplayName = "ElvUI",
    Description = private.getLocalisation("ThemeElvUIDescription"),
    Available = function()
        local E = engine()
        return E and E.db and E.media and E.media.normFont
    end,
    Effects = true,
    Variables = {
        ElvBody = mediaColor("backdropcolor", { 0.1, 0.1, 0.1, 1 }),
        ElvEdge = mediaColor("bordercolor", { 0, 0, 0, 1 }),
        ElvAccent = mediaColor("rgbvaluecolor", { 0.09, 0.52, 0.82, 1 }),
        ElvField = mediaColor("backdropfadecolor", { 0.06, 0.06, 0.06, 0.8 }),
        ElvButtonText = function()
            local color = mediaColor("rgbvaluecolor", { 0.09, 0.52, 0.82, 1 })()
            local brightness = color[1] * 0.299 + color[2] * 0.587 + color[3] * 0.114
            return brightness > 0.5 and { 0, 0, 0, 1 } or { 1, 1, 1, 1 }
        end,
        ElvFont = function()
            local E = engine()
            return E and E.media and E.media.normFont or STANDARD_TEXT_FONT
        end,
        ElvBlank = function()
            local E = engine()
            return E and E.media and E.media.blankTex or "Interface\\Buttons\\WHITE8X8"
        end,
    },
    Palette = {
        Body = "$ElvBody", Edge = "$ElvEdge", Line = "$ElvEdge",
        Accent = "$ElvAccent", Accent2 = "$ElvAccent",
        Field = "$ElvField", FieldPressed = "$ElvBody", FooterFill = "$ElvField",
        FieldHover = { 0.18, 0.18, 0.18, 1 }, Track = { 0.24, 0.24, 0.24, 1 },
        Card = { 1, 1, 1, 0.04 }, Highlight = { 1, 1, 1, 0.08 },
        Text = { 1, 1, 1, 1 }, Muted = { 0.65, 0.65, 0.65, 1 },
        Wash = { 0, 0, 0, 0 },
    },
    Fonts = fonts,
    Windows = { Window = WINDOW, Dialog = WINDOW },
    Elements = {
        Timeline = {
            Backdrop = {
                Background = false, Border = false, BgFile = "$ElvBlank", EdgeFile = "$ElvBlank",
                EdgeSize = 1, Insets = { left = 1, right = 1, top = 1, bottom = 1 },
                Color = "$ElvBody", BorderColor = "$ElvEdge",
            },
            Background = false, Enter = FADE_IN, Exit = FADE_OUT,
        },
        Tick = {
            Line = { Color = "Muted", Alpha = 0.25 },
            Text = { Font = { Path = "$ElvFont", Size = 11, Color = "Muted", Flags = { OUTLINE = true } } },
        },
        Cooldown = { Font = { Media = false, Path = "$ElvFont" } },
        SpellIcon = iconStyle(true),
        BigIcon = iconStyle(false),
        TextHighlight = { Text = { Font = { Media = false, Path = "$ElvFont" } } },
    },
})

-- UpdateMedia runs both for profile changes (UpdateAll -> UpdateStart) and color/font edits.
-- Defer to the next frame so ElvUI finishes its update before our widgets read the media.
local E = engine()
if E and E.UpdateMedia then
    local pending = false
    hooksecurefunc(E, "UpdateMedia", function()
        if pending or not private.db then return end
        pending = true
        C_Timer.After(0, function()
            pending = false
            if private.GetCurrentThemeKey() == "ElvUI" or
                (private.isThemePageShown and private.isThemePageShown()) then
                private.RefreshTheme()
            end
        end)
    end)
end
