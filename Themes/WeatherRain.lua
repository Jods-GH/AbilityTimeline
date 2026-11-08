local appName, app = ...
---@class AbilityTimeline
local private = app
private.RegisterThemeTextures("WeatherRain", { "raindrop", "ripple", "waterdrop" })

-- slate grey and rain blue with a pale silver, picked from tools/sim/scenarios/weather_rain.js: a drizzle with rings
-- spreading over the timeline, heavier the harder it rains, icons appear in a splash of water, splash at every
-- tick and burst into a spray of water when they leave; mist in the morning, lamplight in the evening, lightning at night
local RAINDROP = private.ThemeApply.File("raindrop")
local RIPPLE_TEXTURE = private.ThemeApply.File("ripple")
local MOTE = private.ThemeApply.File("mote")
local GLOW = private.ThemeApply.File("glow")
local WATER = { "Accent", "Accent2" }
local WATERDROP = private.ThemeApply.File("waterdrop")

---rain slanting down anywhere over the frame, short lived as it crosses the timeline in about a quarter of a second,
---slow for a drizzle, the more the harder it rains
local rain = function(rate, max, slow)
    return {
        Texture = RAINDROP,
        Colors = WATER,
        Area = "All",
        Rate = rate * 3,
        Max = max,
        Size = { 18, 26 },
        Life = slow and { 0.35, 0.5 } or { 0.22, 0.35 },
        Speed = slow and { { -12, -6 }, { -110, -80 } } or { { -30, -20 }, { -190, -150 } },
        Alpha = 0.7,
        Align = true,
        Intensity = { 0.4, 1.6 },
    }
end

-- rings spreading where drops land
local PUDDLES = {
    Texture = RIPPLE_TEXTURE,
    Colors = { "Accent2" },
    Area = "All",
    Rate = 1.5,
    Max = 6,
    Size = { 8, 16 },
    Life = { 0.6, 0.9 },
    Speed = { { 0, 0 }, { 0, 0 } },
    Alpha = 0.35,
    Intensity = { 0.5, 1.5 },
}
local DRIZZLE = rain(3, 10, true)

---drops splashing up and falling back at once
local splash = function(count)
    return {
        Texture = MOTE,
        Colors = WATER,
        Count = count,
        Size = { 3, 6 },
        Life = { 0.35, 0.6 },
        Speed = { { -70, 70 }, { 40, 120 } },
        Gravity = -500,
        Alpha = 0.9,
    }
end

-- what each period adds to the timeline
local MIST = {
    Texture = MOTE,
    Colors = { "Accent2" },
    Area = "All",
    Rate = 0.8,
    Max = 5,
    Size = { 18, 30 },
    Life = { 4, 6 },
    Speed = { { 6, 12 }, { -1, 1 } },
    Alpha = 0.16,
}
local LAMPLIGHT = {
    Texture = MOTE,
    Colors = { "Accent2" },
    Rate = 1,
    Max = 4,
    Size = { 5, 9 },
    Life = { 1.5, 2.5 },
    Speed = { { 0, 0 }, { 0, 0 } },
    Alpha = 0.7,
}
local LIGHTNING = {
    Texture = GLOW,
    Colors = { "Accent2" },
    Area = "All",
    Rate = 0.15,
    Max = 1,
    Size = { 120, 160 },
    Life = { 0.25, 0.35 },
    Speed = { { 0, 0 }, { 0, 0 } },
    Alpha = 0.25,
}

local SHEEN = { File = "panel", Slice = 8, Color = "Accent", Alpha = 0.3, BlendMode = "ADD" }
local SPLASH_IN = { Scale = 0.96, Burst = splash(14) }
local WASH_AWAY = {
    Ghost = { File = "panel", Slice = 8, Color = "Body", Rise = -14, Flash = SHEEN, Time = 0.45 },
    Burst = splash(16),
}

---the style of spell and big icons: washed away downwards, pulse for the timeline icons only, big icons are already
---in sight
local iconStyle = function(pulse)
    return {
        -- Water beads fall in sequence with a small splash-like hop.
        QueuedMarkers = pulse and {
            Art = { File = "waterdrop", BlendMode = "BLEND" }, Colors = { "Water", "Accent2", "Water" },
            Size = 18, Spacing = 12, Offset = 5, Rotation = -math.pi / 2,
            Enter = { Time = 0.26, Stagger = 0.1, Y = 7, Hop = 2 },
        } or false,
        -- drops of water splash up round it and fall back as it fades in, the same water as its leave, fewer and lower
        Enter = {
            Burst = {
                Texture = WATERDROP,
                Colors = { "Water", "Water", "Accent2" },
                Count = 10,
                Size = { 16, 26 },
                Life = { 0.4, 0.6 },
                Speed = { { -70, 70 }, { 40, 130 } },
                Gravity = -700,
                Alpha = 0.95,
                Align = true,
                BlendMode = "BLEND",
                Steady = true,
            },
        },
        -- gone in a blink, a spray of water bursting up out of where it was and raining back down
        Exit = {
            Ghost = { Source = "Icon", Fade = { 1, 0 }, Time = 0.15 },
            Burst = {
                Texture = WATERDROP,
                Colors = { "Water", "Water", "Accent2" },
                Count = 18,
                Size = { 10, 17 },
                Life = { 0.45, 0.75 },
                Speed = { { -100, 100 }, { 70, 200 } },
                Gravity = -1000,
                Alpha = 0.95,
                Align = true,
                BlendMode = "BLEND",
                Steady = true,
                Spot = { 0.35, 0.65, 0.3, 0.5 },
            },
        },
        -- drops bouncing up off it as it passes a tick
        Pulse = pulse and { Glow = { Color = "Accent", Alpha = 0.35 }, Scale = false, Burst = splash(6) } or false,
        Text = {
            Font = { Media = false, Object = "GameFontHighlight", Flags = { OUTLINE = true }, Color = "Text", Shadow = true },
            Background = { Show = false, Media = false, File = "pill", Slice = 8, Color = "Body", Alpha = 0.75, Offset = { x = 8, y = 4 } },
        },
    }
end

---the sky of a period: its colors and what it adds to the timeline
local period = function(palette, extra)
    return { Palette = palette, Elements = { Timeline = { Sparkles = { DRIZZLE, PUDDLES, extra } } } }
end

private.RegisterTheme({
    Name = "WeatherRain",
    DisplayName = "Rain",
    Description = private.getLocalisation("ThemeWeatherRainDescription"),
    Weather = "Rain",
    Effects = true,
    Palette = {
        Body = { 0.06, 0.08, 0.1, 0.96 },
        Card = { 0.45, 0.7, 0.9, 0.05 },
        Field = { 0.1, 0.13, 0.16, 1 },
        FieldHover = { 0.13, 0.17, 0.21, 1 },
        FieldPressed = { 0.08, 0.1, 0.12, 1 },
        Track = { 0.18, 0.23, 0.28, 1 },
        Edge = { 0.45, 0.7, 0.9, 0.3 },
        Line = { 0.78, 0.85, 0.9, 0.4 },
        Accent = { 0.45, 0.7, 0.9, 1 },
        Accent2 = { 0.78, 0.85, 0.9, 1 },
        Highlight = { 0.45, 0.7, 0.9, 0.14 },
        Text = { 0.92, 0.95, 0.97, 1 },
        Muted = { 0.56, 0.63, 0.7, 1 },
        Danger = { 1, 0.5, 0.55, 1 },
        Wash = { 0.45, 0.7, 0.9, 0.1 },
        FooterFill = { 0, 0.01, 0.02, 0.3 },
        Shadow = { 0, 0.01, 0.02, 0.9 },
        Water = { 0.78, 0.9, 1, 1 },
    },
    TimeOfDay = {
        Morning = period({ Body = { 0.08, 0.08, 0.11, 0.96 }, Accent = { 0.62, 0.7, 0.85, 1 }, Accent2 = { 0.9, 0.8, 0.82, 1 } }, MIST),
        Evening = period({ Body = { 0.1, 0.07, 0.07, 0.96 }, Accent = { 0.75, 0.6, 0.55, 1 }, Accent2 = { 1, 0.7, 0.45, 1 } }, LAMPLIGHT),
        Night = period({
            Body = { 0.02, 0.03, 0.05, 0.96 }, Accent = { 0.35, 0.5, 0.7, 1 }, Accent2 = { 0.6, 0.68, 0.8, 1 }, Muted = { 0.45, 0.52, 0.6, 1 },
        }, LIGHTNING),
    },
    Fonts = {
        Title = { Size = 18 },
        Heading = { Color = "Accent" },
        CardTitle = { Size = 15 },
    },
    Motion = {
        Time = { Open = 0.3, Enter = 0.35 },
    },
    Windows = {
        Window = { WashHeight = 200, Sparkles = rain(10, 30), Enter = SPLASH_IN, Exit = WASH_AWAY },
        Dialog = { WashHeight = 200, Sparkles = rain(8, 24), Enter = SPLASH_IN, Exit = WASH_AWAY },
    },
    Elements = {
        Timeline = {
            Backdrop = { Background = "None", Border = "None" },
            Background = { File = "panel", Slice = 8, Color = "Body" },
            Edge = { File = "panel_edge", Slice = 8, Color = "Accent2", Alpha = 0.3 },
            Now = false,
            Wash = { Color = "Accent", Alpha = 0.1 },
            Sparkles = { DRIZZLE, PUDDLES },
            Enter = SPLASH_IN,
            Exit = WASH_AWAY,
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
            Enter = { Burst = splash(8) },
            Exit = { Burst = splash(10) },
        },
    },
})
