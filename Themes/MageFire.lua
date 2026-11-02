local appName, app = ...
---@class AbilityTimeline
local private = app
private.RegisterThemeTextures("MageFire", { "ember", "wisp" }, { "burn" })

-- charcoal with fire orange and a glowing gold: small flames rising on the timeline, things appear out of a sheet of
-- fire and burn away from the bottom up when they leave
local EMBER = private.ThemeApply.File("ember")
local WISP = private.ThemeApply.File("wisp")
local HOT = { "Accent", "Gold", "Gold" }

---a few small flames and embers rising from the end icons arrive at, kept dim so they don't distract
local wisps = {
    Texture = { WISP, WISP, EMBER },
    Colors = { "Accent", "Accent", "Gold" },
    Rate = 1.6,
    Max = 8,
    Size = { 8, 12 },
    Life = { 1, 1.6 },
    Speed = { { -2, 2 }, { 16, 26 } },
    Sway = { 2, 3 },
    Alpha = 0.45,
}

---embers rising and swaying
local embers = function(rate, max, area)
    return {
        Texture = EMBER,
        Colors = HOT,
        Area = area,
        Rate = rate,
        Max = max,
        Size = { 4, 8 },
        Life = { 1.2, 2.4 },
        Speed = { { -8, 8 }, { 14, 30 } },
        Gravity = 10,
        Sway = { 5, 1.6 },
        Alpha = 1,
    }
end

---embers flying apart at once, drifting up
local burst = function(count)
    return {
        Texture = EMBER,
        Colors = HOT,
        Count = count,
        Size = { 4, 9 },
        Life = { 0.4, 0.9 },
        Speed = { { -110, 110 }, { -40, 140 } },
        Gravity = 120,
        Alpha = 1,
    }
end

-- burning away from the bottom up in flickering licks, glowing where it burns
local BURNING = {
    Frames = "burn",
    Count = 12,
    Edge = { File = "burn_edge1", Color = "Accent", Alpha = 1, BlendMode = "ADD" },
}
-- a sheet of fire burning off the frame
local IGNITE = {
    Scale = 0.96,
    Ghost = { File = "panel", Slice = 8, Color = "Accent", Alpha = 0.6, BlendMode = "ADD", Dissolve = BURNING, Time = 0.5 },
    Burst = burst(16),
}
local HEAT = { File = "panel", Slice = 8, Color = "Gold", Alpha = 0.3, BlendMode = "ADD" }
local BURN = {
    Ghost = { File = "panel", Slice = 8, Color = "Body", Dissolve = BURNING, Flash = HEAT, Time = 0.7 },
    Burst = burst(20),
}

---the style of spell and big icons: flames up the sides, igniting and burning away, pulse for the timeline icons
---only, big icons are already in sight
local iconStyle = function(pulse)
    return {
        -- a sheet of fire burns off it from the bottom up
        Enter = {
            Scale = 0.9,
            Ghost = { File = "panel", Slice = 8, Color = "Accent", Alpha = 0.95, Dissolve = BURNING, Time = 0.5 },
            Burst = burst(6),
        },
        -- heats up and burns away from the bottom, embers rising off it
        Exit = {
            Ghost = { Source = "Icon", Dissolve = BURNING, Flash = HEAT, Time = 0.6 },
            Burst = burst(8),
        },
        -- embers rising off it as it passes a tick, as Ignite burns on
        Pulse = pulse and {
            Glow = { Color = "Accent", Alpha = 0.4 },
            Scale = false,
            Burst = {
                Texture = EMBER,
                Colors = HOT,
                Count = 4,
                Size = { 4, 8 },
                Life = { 0.5, 0.9 },
                Speed = { { -12, 12 }, { 30, 60 } },
                Gravity = 20,
                Sway = { 3, 3 },
                Alpha = 0.9,
            },
        } or false,
        Text = {
            Font = { Media = false, Object = "GameFontHighlight", Flags = { OUTLINE = true }, Color = "Text", Shadow = true },
            Background = { Show = false, Media = false, File = "pill", Slice = 8, Color = "Body", Alpha = 0.75, Offset = { x = 8, y = 4 } },
        },
    }
end

private.RegisterTheme({
    Name = "MageFire",
    DisplayName = "Fire Mage",
    Description = private.getLocalisation("ThemeMageFireDescription"),
    Class = "MAGE",
    Spec = 2,
    Effects = true,
    Palette = {
        Body = { 0.09, 0.05, 0.035, 0.96 },
        Card = { 1, 0.45, 0.1, 0.05 },
        Field = { 0.16, 0.08, 0.05, 1 },
        FieldHover = { 0.22, 0.11, 0.06, 1 },
        FieldPressed = { 0.12, 0.06, 0.04, 1 },
        Track = { 0.35, 0.15, 0.06, 1 },
        Edge = { 1, 0.45, 0.1, 0.3 },
        Line = { 1, 0.82, 0.35, 0.45 },
        Accent = { 1, 0.45, 0.1, 1 },
        Accent2 = { 1, 0.82, 0.35, 1 },
        Gold = { 1, 0.82, 0.35, 1 },
        Highlight = { 1, 0.45, 0.1, 0.15 },
        Text = { 1, 0.95, 0.88, 1 },
        Muted = { 0.8, 0.62, 0.5, 1 },
        Danger = { 1, 0.35, 0.4, 1 },
        Wash = { 1, 0.45, 0.1, 0.14 },
        FooterFill = { 0.04, 0.01, 0, 0.3 },
        Shadow = { 0.04, 0.01, 0, 0.9 },
    },
    Fonts = {
        Title = { Size = 18 },
        Heading = { Color = "Gold" },
        CardTitle = { Size = 15 },
    },
    Motion = {
        Time = { Open = 0.3, Enter = 0.35 },
    },
    Windows = {
        Window = { WashHeight = 200, Sparkles = embers(2, 16, "All"), Enter = IGNITE, Exit = BURN },
        Dialog = { WashHeight = 200, Sparkles = embers(1.5, 12, "All"), Enter = IGNITE, Exit = BURN },
    },
    Elements = {
        Timeline = {
            Backdrop = { Background = "None", Border = "None" },
            Background = { File = "panel", Slice = 8, Color = "Body" },
            Edge = { File = "panel_edge", Slice = 8, Color = "Accent", Alpha = 0.4 },
            -- a calm bar, small flames rising from the end icons arrive at
            Now = false,
            Wash = { Color = "Accent", Alpha = 0.14 },
            Sparkles = wisps,
            Enter = IGNITE,
            Exit = BURN,
        },
        Tick = {
            Line = { Color = "Accent", Alpha = 0.25 },
            Text = { Font = { Object = "GameFontHighlightSmall", Color = "Muted" } },
        },
        Cooldown = {
            Font = { Media = false, Object = "GameFontHighlightHuge", Size = 22, Color = "Text" },
        },
        SpellIcon = iconStyle(true),
        BigIcon = iconStyle(false),
        TextHighlight = {
            Text = {
                Font = { Media = false, Object = "GameFontHighlight", Flags = { OUTLINE = true }, Color = "Text" },
                Background = { Show = false, Media = false, File = "pill", Slice = 8, Color = "Body", Alpha = 0.75, Offset = { x = 12, y = 6 } },
            },
            Enter = { Burst = burst(8) },
            Exit = { Burst = burst(12) },
        },
    },
})
