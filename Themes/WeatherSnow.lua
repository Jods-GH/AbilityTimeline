local appName, app = ...
---@class AbilityTimeline
local private = app
private.RegisterThemeTextures("WeatherSnow", {}, { "thaw", "snowdrift" })

-- a quiet winter night, snow white and a warm hearth amber, picked from tools/sim/scenarios/weather_snow.js: a
-- blizzard driving across the timeline, the harder the more it snows, things appear in a flurry, shake off flakes at
-- every tick and are blown away, the timeline appears under falling snow and crumbles away; glints on the snow in the
-- morning, hearth embers in the evening, stars and embers at night
local FLAKE = private.ThemeApply.File("flake")
local MOTE = private.ThemeApply.File("mote")
local GLINT = private.ThemeApply.File("glint")
local SNOWFALL = { "Accent", "White" }

---snow driven fast and nearly sideways anywhere over the frame
local blizzard = function(rate, max)
    return {
        Texture = { FLAKE, MOTE },
        Colors = SNOWFALL,
        Area = "All",
        Rate = rate,
        Max = max,
        Size = { 3, 8 },
        Life = { 0.9, 1.5 },
        Speed = { { -140, -90 }, { -30, -15 } },
        Alpha = 0.6,
        Spin = 1,
        Intensity = { 0.3, 1.5 },
    }
end
local BLIZZARD = blizzard(6, 20)

---a flurry of flakes at once
local flurry = function(count)
    return {
        Texture = FLAKE,
        Colors = SNOWFALL,
        Count = count,
        Size = { 4, 10 },
        Life = { 0.5, 0.9 },
        Speed = { { -80, 80 }, { -40, 80 } },
        Gravity = -120,
        Alpha = 1,
        Spin = 2,
    }
end

-- what each period adds to the timeline
local glints = function(colors, rate, max, life)
    return {
        Texture = GLINT,
        Colors = colors,
        Area = "All",
        Rate = rate,
        Max = max,
        Size = { 4, 7 },
        Life = life,
        Speed = { { 0, 0 }, { 0, 0 } },
        Alpha = 0.6,
    }
end
local EMBERS = {
    Texture = MOTE,
    Colors = { "Accent2" },
    Rate = 1,
    Max = 5,
    Size = { 3, 6 },
    Life = { 1, 1.8 },
    Speed = { { -6, 6 }, { 10, 22 } },
    Alpha = 0.8,
}

-- crumbling away from the top in blocks of snow
local SNOWDRIFT = {
    Frames = "snowdrift",
    Count = 12,
    Edge = { File = "snowdrift_edge1", Color = "Accent", Alpha = 1, BlendMode = "ADD" },
}
local SNOWING_IN = {
    Burst = {
        Texture = FLAKE,
        Colors = SNOWFALL,
        Count = 14,
        Size = { 5, 9 },
        Life = { 0.6, 1 },
        Speed = { { -8, 8 }, { -60, -30 } },
        Alpha = 1,
        Spin = 1,
    },
}
local CRUMBLING = {
    Ghost = { File = "panel", Slice = 8, Color = "Body", Dissolve = SNOWDRIFT, Time = 0.6 },
    Burst = flurry(14),
}

---the style of spell and big icons: blown away, pulse for the timeline icons only, big icons are already in sight
local iconStyle = function(pulse)
    return {
        Enter = { Scale = 0.8, Burst = flurry(8) },
        -- fades as a gust of snow blows across it and away
        Exit = {
            Ghost = { Source = "Icon", Scale = { 1, 0.95 }, Time = 0.4 },
            Burst = {
                Texture = FLAKE,
                Colors = SNOWFALL,
                Count = 14,
                Size = { 4, 9 },
                Life = { 0.4, 0.8 },
                Speed = { { -200, -120 }, { -30, 30 } },
                Alpha = 1,
                Spin = 3,
            },
        },
        -- a small thump that shakes a few flakes off it
        Pulse = pulse and { Glow = false, Scale = 1.06, Burst = flurry(5) } or false,
        Text = {
            Font = { Media = false, Object = "GameFontHighlight", Flags = { OUTLINE = true }, Color = "Text", Shadow = true },
            Background = { Show = false, Media = false, File = "pill", Slice = 8, Color = "Body", Alpha = 0.75, Offset = { x = 8, y = 4 } },
        },
    }
end

---the sky of a period: its colors and what it adds to the timeline
local period = function(palette, ...)
    return { Palette = palette, Elements = { Timeline = { Sparkles = { BLIZZARD, ... } } } }
end

private.RegisterTheme({
    Name = "WeatherSnow",
    DisplayName = "Snow",
    Description = private.getLocalisation("ThemeWeatherSnowDescription"),
    Weather = "Snow",
    Effects = true,
    Palette = {
        Body = { 0.07, 0.08, 0.12, 0.95 },
        Card = { 0.85, 0.9, 1, 0.05 },
        Field = { 0.12, 0.13, 0.19, 1 },
        FieldHover = { 0.15, 0.17, 0.24, 1 },
        FieldPressed = { 0.09, 0.1, 0.14, 1 },
        Track = { 0.22, 0.24, 0.32, 1 },
        Edge = { 0.85, 0.9, 1, 0.25 },
        Line = { 1, 0.72, 0.42, 0.4 },
        Accent = { 0.85, 0.9, 1, 1 },
        Accent2 = { 1, 0.72, 0.42, 1 },
        Highlight = { 0.85, 0.9, 1, 0.12 },
        Text = { 0.96, 0.97, 1, 1 },
        Muted = { 0.62, 0.65, 0.75, 1 },
        Danger = { 1, 0.5, 0.55, 1 },
        Wash = { 0.85, 0.9, 1, 0.1 },
        FooterFill = { 0, 0, 0.03, 0.3 },
        Shadow = { 0, 0, 0.03, 0.85 },
    },
    TimeOfDay = {
        Morning = period({ Body = { 0.09, 0.08, 0.13, 0.95 }, Accent = { 0.95, 0.85, 0.9, 1 }, Accent2 = { 1, 0.75, 0.55, 1 } },
            glints({ "White" }, 1.2, 6, { 1, 1.8 })),
        Evening = period({ Body = { 0.1, 0.07, 0.1, 0.95 }, Accent = { 0.9, 0.78, 0.85, 1 }, Accent2 = { 1, 0.6, 0.3, 1 } }, EMBERS),
        Night = period({
            Body = { 0.02, 0.03, 0.07, 0.95 }, Accent = { 0.7, 0.8, 1, 1 }, Accent2 = { 1, 0.7, 0.35, 1 }, Muted = { 0.5, 0.55, 0.7, 1 },
        }, glints({ "Accent", "White" }, 1.2, 8, { 2.5, 4 }), EMBERS),
    },
    Fonts = {
        Title = { Size = 18 },
        Heading = { Color = "Accent2" },
        CardTitle = { Size = 15 },
    },
    Motion = {
        Time = { Open = 0.35, Enter = 0.4 },
    },
    Windows = {
        Window = { WashHeight = 200, Sparkles = blizzard(8, 26), Enter = SNOWING_IN, Exit = CRUMBLING },
        Dialog = { WashHeight = 200, Sparkles = blizzard(6, 18), Enter = SNOWING_IN, Exit = CRUMBLING },
    },
    Elements = {
        Timeline = {
            Backdrop = { Background = "None", Border = "None" },
            Background = { File = "panel", Slice = 8, Color = "Body" },
            Edge = { File = "panel_edge", Slice = 8, Color = "Accent", Alpha = 0.35 },
            Now = false,
            Wash = { Color = "Accent", Alpha = 0.1 },
            Sparkles = BLIZZARD,
            Enter = SNOWING_IN,
            Exit = CRUMBLING,
        },
        Tick = {
            Line = { Color = "Accent", Alpha = 0.2 },
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
            Enter = { Burst = flurry(8) },
            Exit = { Burst = flurry(10) },
        },
    },
})
