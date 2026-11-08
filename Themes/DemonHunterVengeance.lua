local appName, app = ...
---@class AbilityTimeline
local private = app
private.RegisterThemeTextures("DemonHunterVengeance", { "sigil", "soul_fragment" }, { "sigil_flame" })

-- smouldering purple with sigil orange: sigils glow up over the timeline, icons are burnt out of the shadow by a Sigil of
-- Flame, shed soul fragments as they pass a tick and leave drawn in by their own soul fragments
local SOUL = private.ThemeApply.File("soul_fragment")
local SIGIL = private.ThemeApply.File("sigil")
-- Havoc's fel embers, tinted in sigil orange
local EMBER = private.ThemeApply.File("fel_ember")
local SOULS = { "Accent2", "Accent2", "White" }

---sigils glowing up in place anywhere over the frame and fading, a tiny sideways speed with Align keeps them upright
local sigils = function(rate, max)
    return { Texture = SIGIL, Colors = { "Accent" }, Area = "All", Rate = rate, Max = max, Size = { 18, 24 },
        Life = { 2.4, 3.4 }, Speed = { { 0.5, 0.5 }, { 0, 0 } }, Align = true, Alpha = 0.35 }
end

---embers of the sigil flying apart at once
local burst = function(count)
    return {
        Texture = SOUL,
        Colors = { "Accent", "Accent", "Accent2" },
        Count = count,
        Size = { 5, 9 },
        Life = { 0.4, 0.8 },
        Speed = { { -100, 100 }, { -30, 120 } },
        Gravity = 90,
        Alpha = 1,
    }
end

---embers rising off what the sigil burns
local rising = function(count)
    return {
        Texture = EMBER,
        Colors = { "Accent", "Accent", "Accent2" },
        Count = count,
        Size = { 6, 10 },
        Life = { 0.5, 0.9 },
        Speed = { { -14, 14 }, { 30, 60 } },
        Sway = { 3, 3 },
        Alpha = 0.9,
    }
end

---soul fragments coming loose and floating up
local released = function(count)
    return {
        Texture = SOUL,
        Colors = SOULS,
        Count = count,
        Size = { 8, 12 },
        Life = { 0.9, 1.4 },
        Speed = { { -18, 18 }, { 20, 40 } },
        Sway = { 5, 1 },
        Alpha = 0.85,
    }
end

---soul fragments drawn in onto the frame from radius times its larger side
local vortex = function(count, radius)
    return { Texture = SOUL, Colors = SOULS, Count = count, Radius = radius, Size = { 8, 12 }, Time = 0.45, Turns = 0.3 }
end

-- burning away from the middle outwards, glowing where it burns
local SIGIL_FLAME = {
    Frames = "sigil_flame",
    Count = 12,
    Edge = { File = "sigil_flame_edge1", Color = "Accent", Alpha = 1, BlendMode = "ADD" },
}
local SIGIL_IN = {
    Scale = 0.96,
    Flare = { File = "sigil", Color = "Accent", Alpha = 0.55, BlendMode = "ADD", Size = { 1.15, 0.95 }, Spin = 1.2, Time = 0.55 },
    Burst = burst(10),
}
-- shrinks while its soul fragments are drawn in
local CONSUME = {
    Ghost = { File = "panel", Slice = 8, Color = "Body", Scale = { 1, 0.9 }, Time = 0.4 },
    Vortex = vortex(14, 0.6),
}

---the style of spell and big icons: burnt out of the shadow from the middle by a Sigil of Flame, its soul drawn in when
---it leaves, pulse for the timeline icons only, big icons are already in sight
local iconStyle = function(pulse)
    return {
        -- Soul fragments draw inward with the theme's consuming motion.
        QueuedMarkers = pulse and {
            Art = { File = "soul_fragment", BlendMode = "ADD" }, Colors = { "Accent2", "Accent", "Accent2" },
            Size = 16, Spacing = 12, Offset = 5,
            Enter = { Time = 0.32, Stagger = 0.1, Y = 7, Rotation = 0.6, Grow = 0.35 },
        } or false,
        Enter = {
            Ghost = { File = "panel", Slice = 8, Color = "Shadow", Alpha = 0.97, Dissolve = SIGIL_FLAME, Time = 0.45 },
            Burst = rising(4),
        },
        Exit = {
            Ghost = { Source = "Icon", Scale = { 1, 0.7 }, Time = 0.45 },
            Vortex = vortex(8, 0.9),
        },
        -- two soul fragments shattering off it as it passes a tick
        Pulse = pulse and { Glow = { Color = "Accent2", Alpha = 0.4 }, Scale = false, Burst = released(2) } or false,
        Text = {
            Font = { Media = false, Object = "GameFontHighlight", Flags = { OUTLINE = true }, Color = "Text", Shadow = true },
            Background = { Show = false, Media = false, File = "pill", Slice = 8, Color = "Body", Alpha = 0.75, Offset = { x = 8, y = 4 } },
        },
    }
end

private.RegisterTheme({
    Name = "DemonHunterVengeance",
    DisplayName = "Vengeance Demon Hunter",
    Description = private.getLocalisation("ThemeDemonHunterVengeanceDescription"),
    Class = "DEMONHUNTER",
    Spec = 2,
    Effects = true,
    Palette = {
        Body = { 0.07, 0.04, 0.09, 0.96 },
        Card = { 1, 0.55, 0.15, 0.05 },
        Field = { 0.12, 0.07, 0.15, 1 },
        FieldHover = { 0.16, 0.09, 0.2, 1 },
        FieldPressed = { 0.09, 0.05, 0.11, 1 },
        Track = { 0.26, 0.14, 0.3, 1 },
        Edge = { 1, 0.55, 0.15, 0.3 },
        Line = { 0.75, 0.5, 1, 0.45 },
        Accent = { 1, 0.55, 0.15, 1 },
        Accent2 = { 0.75, 0.5, 1, 1 },
        Highlight = { 1, 0.55, 0.15, 0.15 },
        Text = { 1, 0.95, 0.92, 1 },
        Muted = { 0.75, 0.62, 0.78, 1 },
        Danger = { 1, 0.4, 0.45, 1 },
        Wash = { 1, 0.55, 0.15, 0.12 },
        FooterFill = { 0.02, 0, 0.03, 0.3 },
        Shadow = { 0.02, 0, 0.03, 0.9 },
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
        Window = { WashHeight = 200, Sparkles = sigils(0.55, 3), Enter = SIGIL_IN, Exit = CONSUME },
        Dialog = { WashHeight = 200, Sparkles = sigils(0.4, 2), Enter = SIGIL_IN, Exit = CONSUME },
    },
    Elements = {
        Timeline = {
            Backdrop = { Background = "None", Border = "None" },
            Background = { File = "panel", Slice = 8, Color = "Body" },
            Edge = { File = "panel_edge", Slice = 8, Color = "Accent", Alpha = 0.35 },
            -- a calm bar, now and then a sigil glowing up on it
            Now = false,
            Wash = { Color = "Accent", Alpha = 0.12 },
            Sparkles = sigils(0.4, 2),
            Enter = SIGIL_IN,
            Exit = CONSUME,
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
            Exit = { Vortex = vortex(6, 0.6) },
        },
    },
})
