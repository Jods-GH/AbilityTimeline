local appName, app = ...
---@class AbilityTimeline
local private = app
private.RegisterThemeTextures("WeatherSandstorm", { "gust" }, { "erode" })

-- dusky ochre, sand gold and rust, picked from tools/sim/scenarios/weather_sandstorm.js: a gale of sand across the
-- timeline, the stronger the storm the more, things are blown in, an echo of them blown off at every tick, carried off
-- in a whirl and eroded away; a red sun glowing through the sand in the evening, a few stars at night
local GUST = private.ThemeApply.File("gust")
local DUST = private.ThemeApply.File("dust")
local GLOW = private.ThemeApply.File("glow")
local GLINT = private.ThemeApply.File("glint")
local SAND = { "Accent", "Accent2", "Muted" }

---sand and gusts blowing fast across anywhere over the frame
local gale = function(rate, max)
    return {
        Texture = { DUST, DUST, GUST },
        Colors = SAND,
        Area = "All",
        Rate = rate,
        Max = max,
        Size = { 4, 12 },
        Life = { 0.8, 1.4 },
        Speed = { { 160, 240 }, { -10, 4 } },
        Sway = { 3, 2 },
        Alpha = 0.55,
        Align = true,
        Intensity = { 0.3, 1.5 },
    }
end
local GALE = gale(10, 30)

---grains blown off at once with the wind
local blown = function(count)
    return {
        Texture = DUST,
        Colors = SAND,
        Count = count,
        Size = { 3, 7 },
        Life = { 0.4, 0.8 },
        Speed = { { 60, 180 }, { -30, 40 } },
        Alpha = 1,
    }
end

---grains blown in onto the frame
local gather = function(count, radius)
    return { Texture = GUST, Colors = SAND, Count = count, Radius = radius, Size = { 8, 12 }, Time = 0.4, Turns = 0.2, Angle = { 150, 210 }, Align = true }
end

-- what each period adds to the timeline
local RED_SUN = {
    Texture = GLOW,
    Colors = { "Accent" },
    Rate = 0.4,
    Max = 1,
    Size = { 60, 70 },
    Life = { 3, 4 },
    Speed = { { 0, 0 }, { 0, 0 } },
    Alpha = 0.35,
}
local STARS = {
    Texture = GLINT,
    Colors = { "Accent", "White" },
    Area = "All",
    Rate = 0.8,
    Max = 5,
    Size = { 3, 6 },
    Life = { 2.5, 4 },
    Speed = { { 0, 0 }, { 0, 0 } },
    Alpha = 0.45,
}

-- eroded away from the side the wind comes from, its edge glowing in the sun
local ERODE = {
    Frames = "erode",
    Count = 12,
    Edge = { File = "erode_edge1", Color = "Accent", Alpha = 0.8, BlendMode = "ADD" },
}
local BLOWN_IN = { Scale = 0.96, Vortex = gather(16, 0.6) }
local BLOWN_AWAY = {
    Ghost = { File = "panel", Slice = 8, Color = "Body", Dissolve = ERODE, Time = 0.55 },
    Burst = blown(18),
}

---the style of spell and big icons: blown in and carried off, pulse for the timeline icons only, big icons are
---already in sight
local iconStyle = function(pulse)
    return {
        Enter = { Scale = 0.85, Vortex = gather(8, 0.8) },
        -- shrinks into a whirl of sand that spins away
        Exit = {
            Ghost = { Source = "Icon", Scale = { 1, 0.3 }, Time = 0.35 },
            Burst = {
                Texture = DUST,
                Colors = SAND,
                Count = 12,
                Size = { 3, 7 },
                Life = { 0.4, 0.7 },
                Speed = { { 40, 120 }, { 10, 60 } },
                Alpha = 1,
            },
        },
        -- an echo of it blown off by a gust as it passes a tick
        Pulse = pulse and {
            Glow = false,
            Scale = false,
            Ghost = { Source = "Icon", Scale = { 1, 1.2 }, Fade = { 0.5, 0 }, Time = 0.35 },
            Burst = blown(5),
        } or false,
        Text = {
            Font = { Media = false, Object = "GameFontHighlight", Flags = { OUTLINE = true }, Color = "Text", Shadow = true },
            Background = { Show = false, Media = false, File = "pill", Slice = 8, Color = "Body", Alpha = 0.75, Offset = { x = 8, y = 4 } },
        },
    }
end

---the sky of a period: its colors and what it adds to the timeline
local period = function(palette, extra)
    return { Palette = palette, Elements = { Timeline = { Sparkles = { GALE, extra } } } }
end

private.RegisterTheme({
    Name = "WeatherSandstorm",
    DisplayName = "Sandstorm",
    Description = private.getLocalisation("ThemeWeatherSandstormDescription"),
    Weather = "Sandstorm",
    Effects = true,
    Palette = {
        Body = { 0.12, 0.08, 0.05, 0.95 },
        Card = { 0.95, 0.75, 0.42, 0.05 },
        Field = { 0.19, 0.13, 0.08, 1 },
        FieldHover = { 0.25, 0.17, 0.1, 1 },
        FieldPressed = { 0.14, 0.1, 0.06, 1 },
        Track = { 0.32, 0.22, 0.13, 1 },
        Edge = { 0.95, 0.75, 0.42, 0.3 },
        Line = { 0.82, 0.42, 0.24, 0.45 },
        Accent = { 0.95, 0.75, 0.42, 1 },
        Accent2 = { 0.82, 0.42, 0.24, 1 },
        Highlight = { 0.95, 0.75, 0.42, 0.14 },
        Text = { 1, 0.95, 0.86, 1 },
        Muted = { 0.72, 0.6, 0.46, 1 },
        Danger = { 1, 0.5, 0.55, 1 },
        Wash = { 0.95, 0.75, 0.42, 0.12 },
        FooterFill = { 0.04, 0.02, 0, 0.3 },
        Shadow = { 0.04, 0.02, 0, 0.85 },
    },
    TimeOfDay = {
        Morning = { Palette = { Body = { 0.11, 0.08, 0.08, 0.95 }, Accent = { 1, 0.75, 0.55, 1 }, Accent2 = { 0.85, 0.5, 0.4, 1 } } },
        Evening = period({ Body = { 0.13, 0.06, 0.04, 0.95 }, Accent = { 1, 0.55, 0.25, 1 }, Accent2 = { 0.75, 0.25, 0.15, 1 } }, RED_SUN),
        Night = period({
            Body = { 0.03, 0.03, 0.06, 0.95 }, Accent = { 0.65, 0.68, 0.85, 1 }, Accent2 = { 0.45, 0.4, 0.6, 1 }, Muted = { 0.5, 0.5, 0.62, 1 },
        }, STARS),
    },
    Fonts = {
        Title = { Size = 18 },
        Heading = { Color = "Accent" },
        CardTitle = { Size = 15 },
    },
    Motion = {
        Time = { Open = 0.3, Enter = 0.4 },
    },
    Windows = {
        Window = { WashHeight = 200, Sparkles = gale(12, 36), Enter = BLOWN_IN, Exit = BLOWN_AWAY },
        Dialog = { WashHeight = 200, Sparkles = gale(10, 28), Enter = BLOWN_IN, Exit = BLOWN_AWAY },
    },
    Elements = {
        Timeline = {
            Backdrop = { Background = "None", Border = "None" },
            Background = { File = "panel", Slice = 8, Color = "Body" },
            Edge = { File = "panel_edge", Slice = 8, Color = "Accent", Alpha = 0.3 },
            Now = false,
            Wash = { Color = "Accent", Alpha = 0.12 },
            Sparkles = GALE,
            Enter = BLOWN_IN,
            Exit = BLOWN_AWAY,
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
            Enter = { Burst = blown(8) },
            Exit = { Burst = blown(10) },
        },
    },
})
