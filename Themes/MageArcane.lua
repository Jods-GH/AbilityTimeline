local appName, app = ...
---@class AbilityTimeline
local private = app
private.RegisterThemeTextures("MageArcane", { "arcane_swirl", "arcane_vortex", "glyph" }, { "disintegrate" })

-- deep indigo with arcane pink-violet and a pale cyan for contrast: glyphs drifting over the timeline, things appear
-- out of spiralling glyphs and disintegrate into specks
local GLYPH = private.ThemeApply.File("glyph")
local MOTE = private.ThemeApply.File("mote")
local ARCANE = { "Accent", "Accent2", "White" }

---glyphs and motes swaying upwards, anywhere over the frame with area "All"
local glyphs = function(rate, max, area)
    return {
        Texture = area and { GLYPH, MOTE } or GLYPH,
        Colors = ARCANE,
        Area = area,
        Rate = rate,
        Max = max,
        Size = { 6, 11 },
        Life = { 2, 3.5 },
        Speed = { { -6, 6 }, { 8, 18 } },
        Sway = { 8, 1 },
        Alpha = 0.8,
        Spin = 0.5,
    }
end

---arcane motes flying apart at once
local burst = function(count)
    return {
        Texture = MOTE,
        Colors = ARCANE,
        Count = count,
        Size = { 4, 10 },
        Life = { 0.4, 0.9 },
        Speed = { { -120, 120 }, { -70, 130 } },
        Gravity = 60,
        Alpha = 1,
    }
end

-- coming apart into fine specks from the edges in, glowing where it comes apart
local DISINTEGRATE = {
    Frames = "disintegrate",
    Count = 12,
    Edge = { File = "disintegrate_edge1", Color = "Accent", Alpha = 1, BlendMode = "ADD" },
}
---glyphs spiralling in onto the frame from radius times its larger side
local vortex = function(count, radius)
    return { Texture = GLYPH, Colors = ARCANE, Count = count, Radius = radius, Size = { 9, 13 }, Time = 0.5, Turns = 0.5 }
end
-- glyphs spiralling in onto the frame
local SWIRL_IN = { Scale = 0.94, Vortex = vortex(20, 0.5) }
local FLASH = { File = "panel", Slice = 8, Color = "Accent", Alpha = 0.4, BlendMode = "ADD" }
local DISSOLVE = {
    Ghost = { File = "panel", Slice = 8, Color = "Body", Dissolve = DISINTEGRATE, Flash = FLASH, Time = 0.6 },
    Burst = burst(20),
}

---the style of spell and big icons: glyphs spiralling in, disintegrating, pulse for the timeline icons only, big icons
---are already in sight
local iconStyle = function(pulse)
    return {
        -- Violet and cyan glyphs turn into place.
        QueuedMarkers = pulse and {
            Art = { File = "glyph", BlendMode = "ADD" }, Colors = { "Accent", "Accent2", "Accent" },
            Size = 16, Spacing = 12, Offset = 5,
            Enter = { Time = 0.32, Stagger = 0.09, Rotation = -1.5, Grow = 0.5 },
        } or false,
        -- grows in while glyphs spiral into it over a faint swirl closing in on it
        Enter = {
            Scale = 0.6,
            Flare = { File = "arcane_vortex", Color = "Accent", Alpha = 0.45, BlendMode = "ADD", Size = { 1.4, 0.3 }, Spin = -9, Time = 0.55 },
            Vortex = vortex(12, 0.7),
        },
        -- disintegrates into specks drifting up while an arcane swirl spins into it
        Exit = {
            Ghost = { Source = "Icon", Scale = { 1, 0.9 }, Rise = 6, Dissolve = DISINTEGRATE, Flash = FLASH, Time = 0.55 },
            Flare = { File = "arcane_swirl", Color = "Accent", Alpha = 0.8, BlendMode = "ADD", Size = { 1.5, 0.3 }, Spin = -5, Time = 0.55 },
            Burst = burst(8),
        },
        -- a violet halo charging up as a few glyphs draw in, as it passes a tick
        Pulse = pulse and { Glow = { Color = "Accent" }, Scale = false, Vortex = vortex(5, 0.6) } or false,
        Text = {
            Font = { Media = false, Object = "GameFontHighlight", Flags = { OUTLINE = true }, Color = "Text", Shadow = true },
            Background = { Show = false, Media = false, File = "pill", Slice = 8, Color = "Body", Alpha = 0.75, Offset = { x = 8, y = 4 } },
        },
    }
end

private.RegisterTheme({
    Name = "MageArcane",
    DisplayName = "Arcane Mage",
    Description = private.getLocalisation("ThemeMageArcaneDescription"),
    Class = "MAGE",
    Spec = 1,
    Effects = true,
    Palette = {
        Body = { 0.07, 0.035, 0.12, 0.96 },
        Card = { 0.85, 0.45, 1, 0.05 },
        Field = { 0.13, 0.07, 0.21, 1 },
        FieldHover = { 0.17, 0.09, 0.28, 1 },
        FieldPressed = { 0.1, 0.05, 0.16, 1 },
        Track = { 0.25, 0.14, 0.38, 1 },
        Edge = { 0.85, 0.45, 1, 0.3 },
        Line = { 0.55, 0.9, 1, 0.45 },
        Accent = { 0.85, 0.45, 1, 1 },
        Accent2 = { 0.55, 0.9, 1, 1 },
        Highlight = { 0.85, 0.45, 1, 0.15 },
        Text = { 0.97, 0.92, 1, 1 },
        Muted = { 0.7, 0.58, 0.82, 1 },
        Danger = { 1, 0.5, 0.55, 1 },
        Wash = { 0.85, 0.45, 1, 0.14 },
        FooterFill = { 0.02, 0, 0.05, 0.3 },
        Shadow = { 0.02, 0, 0.05, 0.9 },
    },
    Fonts = {
        Title = { Size = 18 },
        Heading = { Color = "Accent2" },
        CardTitle = { Size = 15 },
    },
    Motion = {
        Time = { Open = 0.35, Enter = 0.5 },
    },
    Windows = {
        Window = { WashHeight = 200, Sparkles = glyphs(1.2, 10), Enter = SWIRL_IN, Exit = DISSOLVE },
        Dialog = { WashHeight = 200, Sparkles = glyphs(1, 8), Enter = SWIRL_IN, Exit = DISSOLVE },
    },
    Elements = {
        Timeline = {
            Backdrop = { Background = "None", Border = "None" },
            Background = { File = "panel", Slice = 8, Color = "Body" },
            Edge = { File = "panel_edge", Slice = 8, Color = "Accent", Alpha = 0.35 },
            -- a calm bar, glyphs and motes swaying up all over it
            Now = false,
            Wash = { Color = "Accent", Alpha = 0.14 },
            Sparkles = glyphs(3, 18, "All"),
            Enter = SWIRL_IN,
            Exit = DISSOLVE,
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
