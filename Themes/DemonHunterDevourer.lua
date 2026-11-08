local appName, app = ...
---@class AbilityTimeline
local private = app
private.RegisterThemeTextures("DemonHunterDevourer", { "collapsing_star", "starlight" })

-- the indigo of the void with the cyan of Void Metamorphosis: specks of starlight twinkle over the timeline, icons are
-- born of a star, draw in starlight as they pass a tick and leave as a Collapsing Star going off
local STARLIGHT = private.ThemeApply.File("starlight")
local COSMOS = { "Accent2", "White", "Accent" }

---specks of starlight lighting up in place anywhere over the frame, twinkling and fading
local specks = function(rate, max)
    return { Texture = STARLIGHT, Colors = COSMOS, Area = "All", Rate = rate, Max = max, Size = { 3, 7 },
        Life = { 2, 3.5 }, Speed = { { 0, 0 }, { 0, 0 } }, Alpha = 0.6 }
end

---specks of starlight lighting up all at once
local speckBurst = function(count, life)
    return { Texture = STARLIGHT, Colors = COSMOS, Count = count, Size = { 4, 8 }, Life = life, Speed = { { 0, 0 }, { 0, 0 } },
        Alpha = 1 }
end

---a star going off, specks flung out in every direction
local blast = function(count)
    return {
        Texture = STARLIGHT,
        Colors = COSMOS,
        Count = count,
        Size = { 5, 9 },
        Life = { 0.35, 0.7 },
        Speed = { { -130, 130 }, { -130, 130 } },
        Alpha = 1,
    }
end

---starlight spiralling in onto the frame from radius times its larger side
local gather = function(count, radius, time)
    return { Texture = STARLIGHT, Colors = COSMOS, Count = count, Radius = radius, Size = { 5, 9 }, Time = time or 0.45, Turns = 1 }
end

---a star over the frame from size[1] to size[2] times its smaller side
local star = function(alpha, size, spin, time)
    return { File = "collapsing_star", Color = "Accent2", Alpha = alpha, BlendMode = "ADD", Size = size, Spin = spin, Time = time }
end

local STARFIELD_IN = { Burst = speckBurst(12, { 0.8, 1.4 }) }
-- fades out leaving a few specks twinkling
local STARFIELD_OUT = {
    Ghost = { File = "panel", Slice = 8, Color = "Body", Fade = { 1, 0 }, Time = 0.45 },
    Burst = speckBurst(10, { 0.6, 1.1 }),
}

---the style of spell and big icons: born of a star, leaving as a Collapsing Star, pulse for the timeline icons only, big
---icons are already in sight
local iconStyle = function(pulse)
    return {
        -- Void starlight coalesces from small rotating sparks.
        QueuedMarkers = pulse and {
            Art = { File = "starlight", BlendMode = "ADD" }, Colors = { "Accent", "Accent2", "Accent" },
            Size = 16, Spacing = 12, Offset = 5,
            Enter = { Time = 0.35, Stagger = 0.09, Rotation = 1.2, Grow = 0.8 },
        } or false,
        -- starlight spirals in and a star shrinks onto it
        Enter = { Scale = 0.9, Vortex = gather(8, 0.9), Flare = star(0.9, { 1.7, 0.4 }, 3, 0.5) },
        -- shrinks to a point under a collapsing star, then goes off in a blast of starlight
        Exit = {
            Ghost = { Source = "Icon", Scale = { 1, 0.05 }, Time = 0.3 },
            Flare = star(0.9, { 1.4, 0.05 }, 3, 0.35),
            Burst = blast(10),
            BurstDelay = 0.3,
        },
        -- draws in starlight as it passes a tick
        Pulse = pulse and { Glow = { Color = "Accent2", Alpha = 0.35 }, Scale = false, Vortex = gather(4, 0.8, 0.4) } or false,
        Text = {
            Font = { Media = false, Object = "GameFontHighlight", Flags = { OUTLINE = true }, Color = "Text", Shadow = true },
            Background = { Show = false, Media = false, File = "pill", Slice = 8, Color = "Body", Alpha = 0.75, Offset = { x = 8, y = 4 } },
        },
    }
end

private.RegisterTheme({
    Name = "DemonHunterDevourer",
    DisplayName = "Devourer Demon Hunter",
    Description = private.getLocalisation("ThemeDemonHunterDevourerDescription"),
    Class = "DEMONHUNTER",
    Spec = 3,
    Effects = true,
    Palette = {
        Body = { 0.04, 0.03, 0.08, 0.96 },
        Card = { 0.55, 0.38, 1, 0.05 },
        Field = { 0.07, 0.05, 0.13, 1 },
        FieldHover = { 0.1, 0.07, 0.18, 1 },
        FieldPressed = { 0.05, 0.04, 0.1, 1 },
        Track = { 0.17, 0.12, 0.32, 1 },
        Edge = { 0.55, 0.38, 1, 0.3 },
        Line = { 0.35, 0.8, 1, 0.45 },
        Accent = { 0.55, 0.38, 1, 1 },
        Accent2 = { 0.35, 0.8, 1, 1 },
        Highlight = { 0.55, 0.38, 1, 0.15 },
        Text = { 0.94, 0.95, 1, 1 },
        Muted = { 0.62, 0.6, 0.8, 1 },
        Danger = { 1, 0.45, 0.5, 1 },
        Wash = { 0.55, 0.38, 1, 0.12 },
        FooterFill = { 0.01, 0, 0.03, 0.3 },
        Shadow = { 0.01, 0, 0.03, 0.9 },
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
        Window = { WashHeight = 200, Sparkles = specks(1.2, 8), Enter = STARFIELD_IN, Exit = STARFIELD_OUT },
        Dialog = { WashHeight = 200, Sparkles = specks(1, 6), Enter = STARFIELD_IN, Exit = STARFIELD_OUT },
    },
    Elements = {
        Timeline = {
            Backdrop = { Background = "None", Border = "None" },
            Background = { File = "panel", Slice = 8, Color = "Body" },
            Edge = { File = "panel_edge", Slice = 8, Color = "Accent", Alpha = 0.35 },
            -- a calm bar, specks of starlight twinkling in place over it
            Now = false,
            Wash = { Color = "Accent", Alpha = 0.12 },
            Sparkles = specks(1.6, 10),
            Enter = STARFIELD_IN,
            Exit = STARFIELD_OUT,
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
            Enter = { Vortex = gather(6, 0.6) },
            Exit = { Burst = blast(8) },
        },
    },
})
