local appName, app = ...
---@class AbilityTimeline
local private = app
private.RegisterThemeTextures("WeatherSnow", { "frostedge" })

-- a quiet winter night, snow white and a warm hearth amber, picked from tools/sim/scenarios/weather_snow.js: the
-- timeline is a pane of frosted glass over the world (G1, 2026-11-09), frost creeping in from its edges the harder it
-- snows, the flakes that land sticking and melting; flurries, snowfall, heavy snow and a blizzard as it snows harder
-- (B9); icons, the timeline and windows show through frost that thaws away (E9), shake off flakes at every tick and are
-- blown away (X2); morning frost and glints, the hearth glowing in the glass with embers in the evening and at night,
-- stars at night (T4 with T2's life)
local FLAKE = private.ThemeApply.File("flake")
local MOTE = private.ThemeApply.File("mote")
local GLINT = private.ThemeApply.File("glint")
local SNOWFALL = { "Accent", "White" }

---snow drifting down slowly anywhere over the frame
local snow = function(rate, max)
    return {
        Texture = { FLAKE, MOTE },
        Colors = SNOWFALL,
        Area = "All",
        Rate = rate,
        Max = max,
        Size = { 4, 12 },
        Life = { 5, 8 },
        Speed = { { -4, 4 }, { -16, -8 } },
        Sway = { 8, 0.5 },
        Alpha = 0.75,
        Spin = 0.3,
    }
end

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

---snow that lands on the glass, chance of the flakes sticking where they end
local landing = function(spec, chance)
    spec.Land = { Behavior = "GlassBead", Chance = chance }
    return spec
end

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

---flakes stuck on the glass over an icon, melting away
local stuck = function(count)
    return {
        Texture = FLAKE,
        Colors = { "Ice", "Accent" },
        Count = count,
        Size = { 5, 9 },
        Life = { 0.8, 1.2 },
        Speed = { { 0, 0 }, { 0, 0 } },
        Alpha = 1,
        BlendMode = "BLEND",
        Steady = true,
        Spot = { 0.08, 0.92, 0.08, 0.92 },
    }
end

-- frosted glass: a light frost creeping in from its edges, thicker the harder it snows, flakes that land sticking and
-- melting, no light in them
local FLAKES = {
    File = "flake", Density = 0.25, Size = { 4, 8 }, Max = 30, BeadSize = { 4, 7 }, Life = { 3, 6 }, Color = "Ice", Alpha = 0.8,
    Shine = false, Intensity = { 0.5, 1.5 },
}
local GLASS = {
    Tint = { Color = "Smoke", Strength = 0.6, Veil = { Color = "Mist", Alpha = 0.12 } },
    Grain = { File = "glassfog", Color = "Mist", Alpha = 0.05, Size = 256 },
    Reflections = { File = "glassreflect", Color = "Mist", Alpha = 0.12, Angle = 64, Period = 500, Length = 900, Drift = 4 },
    -- frost along the edges, tiled at its own size: the whole-surface frost stretched over a tall timeline turned into
    -- streaks as soon as it snowed harder
    Overlay = { File = "frostedge", Slice = 12, Color = "Ice", Alpha = 0.45, Intensity = { 0.4, 1.3 } },
    Rim = { Color = "Ice", Alpha = { 0.45, 0.12 } },
    Drops = FLAKES,
}
-- the windows darker so their text reads, only a breath of frost
local WINDOW_GLASS = {
    Tint = { Color = "Smoke", Strength = 0.85, Veil = { Color = "Mist", Alpha = 0.08 } },
    Grain = { File = "glassfog", Color = "Mist", Alpha = 0.04, Size = 256 },
    Reflections = { File = "glassreflect", Color = "Mist", Alpha = 0.1, Angle = 64, Period = 700, Length = 1200, Drift = 4 },
    Overlay = { File = "frostedge", Slice = 12, Color = "Ice", Alpha = 0.3 },
    Rim = { Color = "Ice", Alpha = { 0.45, 0.12 } },
    Drops = { File = "flake", Density = 0.08, Size = { 4, 8 }, Max = 30, BeadSize = { 4, 7 }, Life = { 3, 6 }, Color = "Ice", Alpha = 0.8, Shine = false },
}

---what the snow does on the timeline from an intensity on
local level = function(from, sparkles, glass)
    return { From = from, Elements = { Timeline = { Sparkles = sparkles, Glass = glass } } }
end
local SNOWFALL_LEVEL = landing(snow(5, 14), 0.4)
local BY_INTENSITY = {
    level(0, landing(snow(2, 6), 0.5)),
    level(0.15, SNOWFALL_LEVEL),
    level(0.4, landing(snow(9, 24), 0.35)),
    -- driven sideways, the frost at its thickest
    level(0.7, landing(blizzard(6, 20), 0.2), { Overlay = { Alpha = 0.6 } }),
}

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
-- the hearth glowing low in the glass
local HEARTH = { File = "glow", Color = "Accent2", Alpha = 0.14, Size = 150, At = { 0.5, 0.1 } }

-- icons, the timeline and windows show through frost on the glass that thaws away, a few flakes left stuck that melt
local THAW_IN = {
    Ghost = { File = "frost", Color = "Ice", Alpha = 0.6, Fade = { 1, 0 }, Time = 0.45 },
    Burst = stuck(4),
}
-- and fade as a gust of snow blows across them and away
local BLOWN_AWAY = {
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
}

---the style of spell and big icons: thawed in and blown away, pulse for the timeline icons only, big icons are already
---in sight
local iconStyle = function(pulse)
    return {
        -- Snowflakes drift sideways and settle.
        QueuedMarkers = pulse and {
            Art = { File = "flake", BlendMode = "BLEND" }, Colors = { "Accent2", "Accent", "Accent2" },
            Size = 15, Spacing = 12, Offset = 5,
            Enter = { Time = 0.38, Stagger = 0.1, X = 4, Y = 6, Rotation = 0.7 },
        } or false,
        Enter = THAW_IN,
        Exit = BLOWN_AWAY,
        -- a small thump that shakes a few flakes off it
        Pulse = pulse and { Glow = false, Scale = 1.06, Burst = flurry(5) } or false,
        Text = {
            Font = { Media = false, Object = "GameFontHighlight", Flags = { OUTLINE = true }, Color = "Text", Shadow = true },
            Background = { Show = false, Media = false, File = "pill", Slice = 8, Color = "Body", Alpha = 0.75, Offset = { x = 8, y = 4 } },
        },
    }
end

---the sky of a period: its colors, how the glass changes with it and what it adds to the timeline
local period = function(palette, glass, ...)
    return { Palette = palette, Elements = { Timeline = { Glass = glass, ExtraSparkles = { ... } } } }
end

private.RegisterTheme({
    Name = "WeatherSnow",
    DisplayName = "Snow",
    Description = private.getLocalisation("ThemeWeatherSnowDescription"),
    Weather = "Snow",
    Effects = true,
    ByIntensity = BY_INTENSITY,
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
        Smoke = { 0.12, 0.14, 0.2, 1 },
        Mist = { 0.88, 0.92, 1, 1 },
        Ice = { 0.92, 0.96, 1, 1 },
    },
    TimeOfDay = {
        -- hoarfrost and glints on the snow
        Morning = period({ Body = { 0.09, 0.08, 0.13, 0.95 }, Accent = { 0.95, 0.85, 0.9, 1 }, Accent2 = { 1, 0.75, 0.55, 1 } },
            { Overlay = { Alpha = 0.6 } }, glints({ "White" }, 1.2, 6, { 1, 1.8 })),
        -- the hearth glowing in the glass, embers rising
        Evening = period({ Body = { 0.1, 0.07, 0.1, 0.95 }, Accent = { 0.9, 0.78, 0.85, 1 }, Accent2 = { 1, 0.6, 0.3, 1 } },
            { Lamp = HEARTH }, EMBERS),
        -- dark glass, the hearth, stars and embers
        Night = period({
            Body = { 0.02, 0.03, 0.07, 0.95 }, Accent = { 0.7, 0.8, 1, 1 }, Accent2 = { 1, 0.7, 0.35, 1 }, Muted = { 0.5, 0.55, 0.7, 1 },
        }, { Tint = { Strength = 0.75 }, Lamp = { File = "glow", Color = "Accent2", Alpha = 0.18, Size = 150, At = { 0.5, 0.1 } } },
            glints({ "Accent", "White" }, 1.2, 8, { 2.5, 4 }), EMBERS),
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
        Window = { WashHeight = 200, Glass = WINDOW_GLASS, Sparkles = landing(blizzard(8, 26), 0.2), Enter = THAW_IN, Exit = BLOWN_AWAY },
        Dialog = { WashHeight = 200, Glass = WINDOW_GLASS, Sparkles = landing(blizzard(6, 18), 0.2), Enter = THAW_IN, Exit = BLOWN_AWAY },
    },
    Elements = {
        Timeline = {
            Backdrop = { Background = "None", Border = "None" },
            -- the glass is the bar, its rim its edge
            Background = false,
            Edge = false,
            Glass = GLASS,
            Now = false,
            Wash = { Color = "Accent", Alpha = 0.1 },
            Sparkles = SNOWFALL_LEVEL,
            Enter = THAW_IN,
            Exit = BLOWN_AWAY,
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
