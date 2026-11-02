local appName, app = ...
---@class AbilityTimeline
local private = app
private.RegisterThemeTextures("MageFrost", { "splinter" })

-- glacial blue with an arcane violet for contrast: splinters and flakes falling over the timeline, everything freezes
-- over when it appears and shatters into ice when it leaves
local SPLINTER = private.ThemeApply.File("splinter")
local FLAKE = private.ThemeApply.File("flake")
local COLD = { "Accent", "Accent2", "White" }

---splinters and flakes falling anywhere over the frame
local frostfall = function(rate, max)
    return {
        Texture = { SPLINTER, FLAKE },
        Colors = COLD,
        Area = "All",
        Rate = rate,
        Max = max,
        Size = { 5, 10 },
        Life = { 3, 5 },
        Speed = { { -4, 4 }, { -30, -14 } },
        Sway = { 3, 0.6 },
        Alpha = 0.7,
        Spin = 0.4,
    }
end

---splinters flying apart at once
local burst = function(count)
    return {
        Texture = SPLINTER,
        Colors = COLD,
        Count = count,
        Size = { 6, 12 },
        Life = { 0.4, 0.8 },
        Speed = { { -140, 140 }, { -60, 150 } },
        Gravity = -260,
        Alpha = 1,
        Spin = 5,
    }
end

-- frost growing onto the frame and melting off it
local COVER = { File = "frost", Color = "Accent2", Alpha = 0.9, BlendMode = "ADD", Grow = 1.2, Time = 0.6 }
local SHARD_EDGE = { File = "cracks", Color = "Accent2", Alpha = 0.9, BlendMode = "ADD" }
local FREEZE = { Scale = 0.96, Cover = COVER, Burst = burst(14) }
local SHATTER = {
    Crack = { File = "cracks", Color = "Accent2", Alpha = 0.9, BlendMode = "ADD", Time = 0.1 },
    Shards = { File = "ice", Color = "Body", Edge = SHARD_EDGE, Speed = { 80, 200 }, Gravity = -700, Time = 0.55 },
    Burst = burst(20),
}

---the style of spell and big icons: shattering into pieces of the icon, pulse for the timeline icons only, big icons
---are already in sight
local iconStyle = function(pulse)
    return {
        Enter = {
            Scale = 0.8,
            Cover = { File = "frost", Color = "Accent2", Alpha = 0.9, BlendMode = "ADD", Grow = 1.2, Time = 0.6 },
            Burst = burst(6),
        },
        Exit = {
            Crack = { File = "cracks", Color = "Accent2", Alpha = 0.9, BlendMode = "ADD", Time = 0.08 },
            Shards = { Source = "Icon", Edge = SHARD_EDGE, Speed = { 40, 110 }, Gravity = -500, Time = 0.4 },
            Burst = burst(8),
        },
        -- glinting white and throwing off splinters as it passes a tick, like a Shatter
        Pulse = pulse and {
            Glow = false,
            Scale = false,
            Ghost = {
                Source = "Icon",
                Fade = { 1, 0 },
                Flash = { File = "panel", Slice = 8, Color = "Accent2", Alpha = 0.5, BlendMode = "ADD" },
                Time = 0.25,
            },
            Burst = burst(4),
        } or false,
        Text = {
            Font = { Media = false, Object = "GameFontHighlight", Flags = { OUTLINE = true }, Color = "Text", Shadow = true },
            Background = { Show = false, Media = false, File = "pill", Slice = 8, Color = "Body", Alpha = 0.75, Offset = { x = 8, y = 4 } },
        },
    }
end

private.RegisterTheme({
    Name = "MageFrost",
    DisplayName = "Frost Mage",
    Description = private.getLocalisation("ThemeMageFrostDescription"),
    Class = "MAGE",
    Spec = 3,
    Effects = true,
    Palette = {
        Body = { 0.03, 0.1, 0.17, 0.96 },
        Card = { 0.55, 0.88, 1, 0.05 },
        Field = { 0.05, 0.15, 0.24, 1 },
        FieldHover = { 0.07, 0.2, 0.31, 1 },
        FieldPressed = { 0.04, 0.12, 0.19, 1 },
        Track = { 0.09, 0.27, 0.42, 1 },
        Edge = { 0.55, 0.88, 1, 0.3 },
        Line = { 0.68, 0.55, 1, 0.45 },
        Accent = { 0.55, 0.88, 1, 1 },
        Accent2 = { 0.88, 0.97, 1, 1 },
        Violet = { 0.68, 0.55, 1, 1 },
        Highlight = { 0.55, 0.88, 1, 0.15 },
        Text = { 0.9, 0.97, 1, 1 },
        Muted = { 0.55, 0.72, 0.84, 1 },
        Danger = { 1, 0.5, 0.55, 1 },
        Wash = { 0.55, 0.88, 1, 0.12 },
        FooterFill = { 0, 0.03, 0.06, 0.3 },
        Shadow = { 0, 0.02, 0.05, 0.9 },
    },
    Fonts = {
        Title = { Size = 18 },
        Heading = { Color = "Violet" },
        CardTitle = { Size = 15 },
    },
    Motion = {
        Time = { Open = 0.35, Enter = 0.4 },
    },
    Windows = {
        Window = { WashHeight = 200, Enter = FREEZE, Exit = SHATTER },
        Dialog = { WashHeight = 200, Enter = FREEZE, Exit = SHATTER },
    },
    Elements = {
        Timeline = {
            Backdrop = { Background = "None", Border = "None" },
            Background = { File = "panel", Slice = 8, Color = "Body" },
            Edge = { File = "panel_edge", Slice = 8, Color = "Accent2", Alpha = 0.4 },
            -- a calm bar, snowflakes and splinters falling all over it
            Now = false,
            Wash = { Color = "Accent", Alpha = 0.1 },
            Sparkles = frostfall(3, 20),
            Enter = FREEZE,
            Exit = SHATTER,
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
