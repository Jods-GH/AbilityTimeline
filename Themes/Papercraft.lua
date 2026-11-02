local appName, app = ...
---@class AbilityTimeline
local private = app
private.RegisterThemeTextures("Papercraft", { "confetti", "confetti_dot", "deckle", "doodle_heart", "doodle_plane",
    "doodle_sun", "hatch", "highlight", "paper_grain", "paper_strip", "tape" }, { "scribble", "tear" })

-- cream paper, ink, red and blue pencil, washi tape and a highlighter, after BetterBags' Papercraft (Sonata, Cidan):
-- a strip of torn paper with a stroke of highlighter where icons arrive, icons drawn in pencil before they show and
-- torn off when they leave. Picked in tools/sim/scenarios/papercraft.js
local FONTS = "Interface\\AddOns\\AbilityTimeline\\Media\\Fonts\\"
local CAVEAT, PATRICK = "Caveat", "Patrick Hand"
-- the locales the fonts draw, the others keep the client's font
local LATIN = { "enUS", "enGB", "deDE", "frFR", "esES", "esMX", "itIT", "ptBR" }
local LATIN_CYRILLIC = { "enUS", "enGB", "deDE", "frFR", "esES", "esMX", "itIT", "ptBR", "ruRU" }

---a text role in handwriting: Caveat for titles and headings, Patrick Hand for the rest
local script = function(size, color)
    return { Object = "GameFontHighlight", Media = CAVEAT, Locales = LATIN_CYRILLIC, Size = size, Color = color, Shadow = false }
end
local hand = function(size, color)
    return { Object = "GameFontHighlight", Media = PATRICK, Locales = LATIN, Size = size, Color = color, Shadow = false }
end
-- names and numbers drawn over the game world stay white and outlined
local OUTLINED = function(size)
    return { Media = PATRICK, Locales = LATIN, Size = size, Flags = { OUTLINE = true }, Color = "White", Shadow = true }
end

local CONFETTI_TEXTURES = { private.ThemeApply.File("confetti"), private.ThemeApply.File("confetti"),
    private.ThemeApply.File("confetti_dot") }
local TAPE_COLORS = { "TapeTan", "TapeBlue", "TapePink", "Accent" }
-- bits of paper drifting down over the bar, drawn as they are, not as light
local CONFETTI = {
    Texture = CONFETTI_TEXTURES,
    Colors = TAPE_COLORS,
    Area = "All",
    Rate = 0.5,
    Max = 3,
    Size = { 7, 11 },
    Life = { 2.6, 4 },
    Speed = { { -6, 6 }, { -14, -6 } },
    Sway = { 6, 1.6 },
    Spin = 1.5,
    Alpha = 0.9,
    BlendMode = "BLEND",
    Steady = true,
}
local confettiBurst = function(count)
    return {
        Texture = CONFETTI_TEXTURES,
        Colors = TAPE_COLORS,
        Count = count,
        Size = { 7, 10 },
        Life = { 0.5, 0.9 },
        Speed = { { -90, 90 }, { 30, 120 } },
        Gravity = -320,
        Spin = 4,
        Alpha = 1,
        BlendMode = "BLEND",
        Steady = true,
    }
end

-- ripped away along a ragged line, white fibres along the tear
local TEARING = {
    Frames = "tear",
    Count = 12,
    Edge = { File = "tear_edge1", Color = "White", Alpha = 1 },
}
-- pencil hatching scribbled over it before the paper shows through, torn away when it hides
local SKETCH_IN = {
    Ghost = { File = "hatch", Color = "Muted", Time = 0.7, Sketch = { Back = "PaperLight", Frames = "scribble", Count = 12, Draw = 0.6 } },
}
local TEAR_AWAY = {
    Ghost = { File = "panel", Slice = 8, Color = "Body", Dissolve = TEARING, Time = 0.5 },
    Burst = confettiBurst(6),
}

---a strip of washi tape over a corner of a window
local tape = function(point, x, rotation, color)
    return { File = "tape", Color = color, Alpha = 0.85, Point = point, X = x, Y = -2, Size = { 64, 16 }, Rotation = rotation }
end

---a sheet of paper with a torn edge, taped on and doodled on
local window = function(decor)
    return {
        Fill = "Body",
        Grain = { File = "paper_grain", Color = "Muted", Alpha = 0.16 },
        EdgeArt = { File = "deckle", Slice = 12, Color = "Ink", Alpha = 0.45 },
        WashHeight = 90,
        HeaderLine = "Line",
        Decor = decor,
        Enter = SKETCH_IN,
        Exit = TEAR_AWAY,
    }
end

---the style of spell and big icons: drawn in pencil before they show, torn off as they leave, a few bits of paper
---hopping off as they pass a tick (timeline icons only, big icons are already in sight)
local iconStyle = function(pulse, size)
    return {
        Enter = {
            Ghost = { Source = "Icon", Time = 0.8,
                Sketch = { Back = "PaperLight", Color = "Muted", Hatch = "hatch", Frames = "scribble", Count = 12, Draw = 0.55 } },
        },
        Exit = {
            Ghost = { Source = "Icon", Dissolve = TEARING, Time = 0.4 },
            Burst = confettiBurst(2),
        },
        Pulse = pulse and { Glow = false, Burst = confettiBurst(3) } or false,
        Text = {
            Font = OUTLINED(size),
            Background = { Show = false, Media = false, File = "pill", Slice = 8, Color = "Body", Alpha = 0.85, Offset = { x = 8, y = 4 } },
        },
    }
end

private.RegisterTheme({
    Name = "Papercraft",
    DisplayName = "Papercraft",
    Description = private.getLocalisation("ThemePapercraftDescription"),
    SharedMedia = {
        font = {
            [CAVEAT] = FONTS .. "Caveat-Bold.ttf",
            [PATRICK] = FONTS .. "PatrickHand-Regular.ttf",
        },
    },
    Effects = true,
    Palette = {
        Body = { 0.925, 0.885, 0.805, 0.97 },
        Card = { 0.18, 0.16, 0.14, 0.045 },
        Field = { 0.975, 0.955, 0.895, 1 },
        FieldHover = { 1, 0.985, 0.94, 1 },
        FieldPressed = { 0.9, 0.86, 0.78, 1 },
        Track = { 0.48, 0.43, 0.36, 1 },
        Edge = { 0.18, 0.16, 0.14, 0.55 },
        Line = { 0.77, 0.27, 0.23, 0.9 },
        Accent = { 0.77, 0.27, 0.23, 1 },
        Accent2 = { 0.3, 0.48, 0.71, 1 },
        Highlight = { 0.3, 0.48, 0.71, 0.14 },
        Text = { 0.18, 0.16, 0.14, 1 },
        Muted = { 0.48, 0.43, 0.36, 1 },
        Danger = { 0.72, 0.2, 0.18, 1 },
        Wash = { 0.96, 0.86, 0.47, 0.12 },
        FooterFill = { 0.862, 0.815, 0.725, 1 },
        Shadow = { 0, 0, 0, 0.34 },
        PaperLight = { 0.975, 0.955, 0.895, 1 },
        Ink = { 0.18, 0.16, 0.14, 1 },
        Highlighter = { 0.96, 0.86, 0.47, 1 },
        TapeTan = { 0.8, 0.7, 0.52, 1 },
        TapeBlue = { 0.56, 0.71, 0.86, 1 },
        TapePink = { 0.9, 0.63, 0.6, 1 },
        Heart = { 0.85, 0.42, 0.47, 1 },
    },
    Fonts = {
        Title = script(24, "Text"),
        DialogTitle = script(22, "Text"),
        Heading = script(19, "Accent"),
        CardTitle = script(20, "Text"),
        Footer = hand(13, "Muted"),
        Label = hand(14, "Muted"),
        Control = hand(14, "Text"),
        Muted = hand(13, "Muted"),
        Button = hand(14, "Text"),
        ButtonPrimary = hand(14, "PaperLight"),
        ButtonDanger = hand(14, "Danger"),
        Tab = hand(14, "Muted"),
        TabSelected = hand(14, "Text"),
        CardText = hand(13, "Muted"),
        MenuItem = hand(14, "Text"),
    },
    Windows = {
        Window = window({
            tape("TOPLEFT", 6, 35, "TapeTan"),
            tape("TOPRIGHT", -6, -35, "TapeBlue"),
            { File = "doodle_plane", Color = "Ink", Alpha = 0.35, Point = "BOTTOMRIGHT", X = -70, Y = 18, Size = { 28, 28 } },
            { File = "doodle_heart", Color = "Heart", Alpha = 0.6, Point = "BOTTOMRIGHT", X = -38, Y = 16, Size = { 18, 18 } },
            { File = "doodle_sun", Color = "Ink", Alpha = 0.3, Point = "BOTTOMLEFT", X = 30, Y = 52, Size = { 30, 30 } },
        }),
        Dialog = window({
            tape("TOPLEFT", 6, 35, "TapePink"),
            tape("TOPRIGHT", -6, -35, "TapeTan"),
        }),
    },
    Elements = {
        Timeline = {
            Backdrop = { Background = "None", Border = "None" },
            Background = { File = "paper_strip", Slice = 12, Color = "Body" },
            Edge = { File = "deckle", Slice = 12, Color = "Ink", Alpha = 0.5 },
            -- a stroke of highlighter where icons arrive, bits of paper drifting over the bar
            Mark = { File = "highlight", Color = "Highlighter", Alpha = 0.55, Length = 2.2 },
            Sparkles = CONFETTI,
            Enter = SKETCH_IN,
            Exit = TEAR_AWAY,
        },
        Tick = {
            Line = { Color = "Ink", Alpha = 0.3 },
            Text = { Font = hand(12, "Muted") },
        },
        Cooldown = {
            Font = OUTLINED(24),
        },
        SpellIcon = iconStyle(true, 15),
        BigIcon = iconStyle(false, 20),
        TextHighlight = {
            Text = {
                Font = OUTLINED(16),
                Background = { Show = false, Media = false, File = "pill", Slice = 8, Color = "Body", Alpha = 0.85, Offset = { x = 12, y = 6 } },
            },
        },
    },
})
