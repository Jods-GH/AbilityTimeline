local appName, app = ...
---@class AbilityTimeline
local private = app
private.RegisterThemeTextures("DruidRestoration", { "bloom", "flowerlet", "life_mote", "petal" }, { "closing" })

-- soft green with a blossom pink: leaves drifting over the timeline while flowers of Efflorescence spring up on it,
-- motes of light gather into icons like Tranquility and they leave closing like a flower, petals fluttering down
local PETAL = private.ThemeApply.File("petal")
local LEAF = private.ThemeApply.File("leaf")
local FLOWER = private.ThemeApply.File("flowerlet")
local MOTE = private.ThemeApply.File("life_mote")
local BLOSSOM = { "Accent2", "Accent2", "White" }

---leaves drifting down and swaying
local leaves = function(rate, max)
    return {
        Texture = LEAF,
        Colors = { "Accent", "Accent", "Muted" },
        Area = "All",
        Rate = rate,
        Max = max,
        Size = { 6, 9 },
        Life = { 2.5, 4 },
        Speed = { { -4, 8 }, { -12, -5 } },
        Sway = { 8, 1.2 },
        Alpha = 0.5,
        Spin = 1,
    }
end

---now and then a small flower springing up and fading where it is
local flowers = function(rate, max)
    return {
        Texture = FLOWER,
        Colors = { "Accent", "Accent", "Accent2" },
        Area = "All",
        Rate = rate,
        Max = max,
        Size = { 7, 10 },
        Life = { 2, 3 },
        Speed = { { 0, 0 }, { 0, 0 } },
        Alpha = 0.45,
        Spin = 0.15,
    }
end

---petals fluttering down slowly
local flutter = function(count)
    return {
        Texture = PETAL,
        Colors = BLOSSOM,
        Count = count,
        Size = { 6, 10 },
        Life = { 0.8, 1.3 },
        Speed = { { -40, 40 }, { -10, 30 } },
        Gravity = -45,
        Sway = { 6, 3 },
        Alpha = 1,
        Spin = 2,
    }
end

---petals drifting apart at once
local burst = function(count)
    return {
        Texture = PETAL,
        Colors = BLOSSOM,
        Count = count,
        Size = { 5, 9 },
        Life = { 0.5, 1 },
        Speed = { { -70, 70 }, { -20, 80 } },
        Gravity = -60,
        Alpha = 1,
        Spin = 3,
    }
end

---a flower opening over the frame
local bloom = function(alpha, size, time)
    return { File = "bloom", Color = "Accent", Alpha = alpha, BlendMode = "ADD", Size = size, Spin = 0.8, Time = time }
end
local BLOOM = { Scale = 0.95, Flare = bloom(0.45, { 0.5, 1.2 }, 0.6), Burst = burst(8) }
-- closing in from the edges like a flower
local CLOSING = {
    Frames = "closing",
    Count = 12,
    Edge = { File = "closing_edge1", Color = "Accent2", Alpha = 1, BlendMode = "ADD" },
}

-- drifts up a little and away in petals
local DRIFT = {
    Ghost = { File = "panel", Slice = 8, Color = "Body", Scale = { 1, 0.96 }, Rise = 8, Time = 0.4 },
    Burst = burst(14),
}

---the style of spell and big icons: plain squares like Classic's, motes of light gathering into them like Tranquility,
---closing like a flower as they leave, pulse
---for the timeline icons only, big icons are already in sight
local iconStyle = function(pulse)
    return {
        -- Tiny Efflorescence blossoms open one after another.
        QueuedMarkers = pulse and {
            Art = { File = "flowerlet", BlendMode = "ADD" }, Colors = { "Accent", "Accent2", "Accent" },
            Size = 16, Spacing = 12, Offset = 5,
            Enter = { Time = 0.34, Stagger = 0.1, Grow = 0.8, Rotation = -0.5 },
        } or false,
        Enter = {
            Scale = 0.9,
            Vortex = { Texture = MOTE, Colors = { "Accent", "Accent", "Light" }, Count = 9, Radius = 0.9, Turns = 0.6,
                Size = { 4, 7 }, Time = 0.45 },
        },
        Exit = { Ghost = { Source = "Icon", Dissolve = CLOSING, Time = 0.5 }, Burst = flutter(7) },
        -- three flowers of Efflorescence springing up on it as it passes a tick
        Pulse = pulse and {
            Glow = { Color = "Accent", Alpha = 0.35 },
            Scale = false,
            Burst = {
                Texture = FLOWER,
                Colors = { "Accent", "Accent", "Accent2" },
                Count = 3,
                Size = { 7, 11 },
                Life = { 0.7, 1.1 },
                Speed = { { -30, 30 }, { -30, 30 } },
                Alpha = 0.9,
                Spin = 0.5,
            },
        } or false,
        Text = {
            Font = { Media = false, Object = "GameFontHighlight", Flags = { OUTLINE = true }, Color = "Text", Shadow = true },
            Background = { Show = false, Media = false, File = "pill", Slice = 8, Color = "Body", Alpha = 0.75, Offset = { x = 8, y = 4 } },
        },
    }
end

-- clients with three druid talent trees have Restoration third, see DruidGuardian.lua
local hasGuardian = C_SpecializationInfo.GetNumSpecializationsForClassID(11) == 4

private.RegisterTheme({
    Name = "DruidRestoration",
    DisplayName = "Restoration Druid",
    Description = private.getLocalisation("ThemeDruidRestorationDescription"),
    Class = "DRUID",
    Spec = hasGuardian and 4 or 3,
    Effects = true,
    Palette = {
        Body = { 0.045, 0.075, 0.06, 0.96 },
        Card = { 0.5, 0.9, 0.55, 0.05 },
        Field = { 0.075, 0.12, 0.095, 1 },
        FieldHover = { 0.1, 0.16, 0.125, 1 },
        FieldPressed = { 0.06, 0.095, 0.075, 1 },
        Track = { 0.16, 0.28, 0.2, 1 },
        Edge = { 0.5, 0.9, 0.55, 0.3 },
        Line = { 1, 0.62, 0.8, 0.45 },
        Accent = { 0.5, 0.9, 0.55, 1 },
        Accent2 = { 1, 0.62, 0.8, 1 },
        Highlight = { 0.5, 0.9, 0.55, 0.15 },
        Text = { 0.95, 1, 0.96, 1 },
        Muted = { 0.64, 0.76, 0.68, 1 },
        Danger = { 1, 0.45, 0.45, 1 },
        Wash = { 0.5, 0.9, 0.55, 0.12 },
        Light = { 0.85, 1, 0.75, 1 },
        FooterFill = { 0, 0.02, 0.01, 0.3 },
        Shadow = { 0, 0.02, 0.01, 0.9 },
    },
    Fonts = {
        Title = { Size = 18 },
        Heading = { Color = "Accent2" },
        CardTitle = { Size = 15 },
    },
    Motion = {
        Time = { Open = 0.3, Enter = 0.45 },
    },
    Windows = {
        Window = { WashHeight = 200, Sparkles = leaves(0.8, 6), Enter = BLOOM, Exit = DRIFT },
        Dialog = { WashHeight = 200, Sparkles = leaves(0.6, 5), Enter = BLOOM, Exit = DRIFT },
    },
    Elements = {
        Timeline = {
            Backdrop = { Background = "None", Border = "None" },
            Background = { File = "panel", Slice = 8, Color = "Body" },
            Edge = { File = "panel_edge", Slice = 8, Color = "Accent", Alpha = 0.35 },
            -- a calm bar, leaves drifting over it and now and then a flower springing up
            Now = false,
            Wash = { Color = "Accent", Alpha = 0.12 },
            Sparkles = { leaves(0.9, 7), flowers(0.35, 2) },
            Enter = BLOOM,
            Exit = DRIFT,
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
            Enter = { Burst = burst(5) },
            Exit = { Burst = flutter(8) },
        },
    },
})
