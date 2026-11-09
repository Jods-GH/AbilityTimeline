local appName, app = ...
---@class AbilityTimeline
local private = app
private.RegisterThemeTextures("WeatherSandstorm", { "gust" })

-- dusky ochre, sand gold and rust, picked from tools/sim/scenarios/weather_sandstorm.js: the timeline is a pane of
-- scoured, dusty glass over the world (G2, 2026-11-09), dust racing through it on the wind and gusts of light sweeping
-- across, grit that hits it clinging and blowing off again; a dust haze, blowing sand, a gale and a sandstorm as it
-- blows harder (B9); icons, the timeline and windows show through dust that settles away (E10), an echo of them blown
-- off at every tick, carried off in a whirl (X2); a red sun glowing through the dust in the evening, the glass dark and
-- a few stars at night (T4 with T2's life)
local GUST = private.ThemeApply.File("gust")
local DUST = private.ThemeApply.File("dust")
local GLOW = private.ThemeApply.File("glow")
local GLINT = private.ThemeApply.File("glint")
local SAND = { "Accent", "Accent2", "Muted" }

---sand and gusts blowing across anywhere over the frame, fast for a gale
local sand = function(rate, max, fast)
    return {
        Texture = { DUST, DUST, GUST },
        Colors = SAND,
        Area = "All",
        Rate = rate,
        Max = max,
        Size = { 4, 12 },
        Life = { 0.8, 1.4 },
        Speed = fast and { { 160, 240 }, { -10, 4 } } or { { 90, 150 }, { -12, 6 } },
        Sway = { 3, 2 },
        Alpha = 0.55,
        Align = true,
        Intensity = { 0.3, 1.5 },
    }
end

---sand that hits the glass, chance of the grains clinging where they end
local landing = function(spec, chance)
    spec.Land = { Behavior = "GlassBead", Chance = chance }
    return spec
end

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

---grains clinging to the glass over an icon
local grit = function(count)
    return {
        Texture = DUST,
        Colors = { "Grit", "Accent" },
        Count = count,
        Size = { 3, 6 },
        Life = { 0.6, 1 },
        Speed = { { 0, 0 }, { 0, 0 } },
        Alpha = 1,
        BlendMode = "BLEND",
        Steady = true,
        Spot = { 0.08, 0.92, 0.08, 0.92 },
    }
end

-- scoured glass: amber smoke, a film of dust thicker the harder it blows, dust racing through it on the wind and gusts
-- of reflected light sweeping across, grit clinging and blown off again (dull, no light in it)
local GRIT = {
    File = "dust", Density = 0.3, Size = { 2, 4 }, Max = 40, BeadSize = { 2, 4 }, Life = { 1.5, 3 }, Color = "Grit", Alpha = 0.9,
    Shine = false, Intensity = { 0.5, 1.6 },
}
local GLASS = {
    Tint = { Color = "Smoke", Strength = 0.6, Veil = { Color = "Mist", Alpha = 0.12 } },
    Grain = { File = "glassfog", Color = "Mist", Alpha = 0.09, Size = 200, Drift = { 40, 0 } },
    Overlay = { File = "glassfog", Color = "Grit", Alpha = 0.16, Intensity = { 0.5, 1.6 } },
    Reflections = { File = "glassreflect", Color = "Mist", Alpha = 0.22, Angle = 50, Period = 420, Length = 800, Drift = 30 },
    Rim = { Color = "Mist", Alpha = { 0.4, 0.12 } },
    Drops = GRIT,
}
-- the windows darker so their text reads, the dust calmer
local WINDOW_GLASS = {
    Tint = { Color = "Smoke", Strength = 0.85, Veil = { Color = "Mist", Alpha = 0.08 } },
    Grain = { File = "glassfog", Color = "Mist", Alpha = 0.05, Size = 256, Drift = { 15, 0 } },
    Overlay = { File = "glassfog", Color = "Grit", Alpha = 0.1 },
    Reflections = { File = "glassreflect", Color = "Mist", Alpha = 0.12, Angle = 50, Period = 600, Length = 1100, Drift = 12 },
    Rim = { Color = "Mist", Alpha = { 0.4, 0.12 } },
    Drops = { File = "dust", Density = 0.1, Size = { 2, 4 }, Max = 40, BeadSize = { 2, 4 }, Life = { 1.5, 3 }, Color = "Grit", Alpha = 0.9, Shine = false },
}

---what the sand does on the timeline from an intensity on
local level = function(from, sparkles, glass)
    return { From = from, Elements = { Timeline = { Sparkles = sparkles, Glass = glass } } }
end
local BLOWING = landing(sand(6, 16), 0.3)
local BY_INTENSITY = {
    level(0, landing(sand(2, 6), 0.3)),
    level(0.2, BLOWING),
    level(0.5, landing(sand(10, 30, true), 0.2)),
    -- a sandstorm, the dust in the glass racing
    level(0.8, landing(sand(14, 40, true), 0.15), { Grain = { Drift = { 60, 0 } } }),
}

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

-- icons, the timeline and windows show through a film of dust that settles away, a few grains left clinging
local DUST_IN = {
    Ghost = { File = "fog_patch", Color = "Grit", Alpha = 0.7, Fade = { 1, 0 }, Time = 0.45 },
    Burst = grit(5),
}
-- and shrink into a whirl of sand that spins away
local CARRIED_OFF = {
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
}

---the style of spell and big icons: out of the dust and carried off, pulse for the timeline icons only, big icons are
---already in sight
local iconStyle = function(pulse)
    return {
        -- Sand grains blow in from the side.
        QueuedMarkers = pulse and {
            Art = { File = "dust", BlendMode = "BLEND" }, Colors = { "Accent", "Accent2", "Accent" },
            Size = 16, Spacing = 12, Offset = 5,
            Enter = { Time = 0.28, Stagger = 0.07, X = -8, Y = 2 },
        } or false,
        Enter = DUST_IN,
        Exit = CARRIED_OFF,
        -- a sandy halo with a few grains blown off by a gust as it passes a tick
        Pulse = pulse and { Glow = { Color = "Accent" }, Scale = false, Burst = blown(4) } or false,
        Text = {
            Font = { Media = false, Object = "GameFontHighlight", Flags = { OUTLINE = true }, Color = "Text", Shadow = true },
            Background = { Show = false, Media = false, File = "pill", Slice = 8, Color = "Body", Alpha = 0.75, Offset = { x = 8, y = 4 } },
        },
    }
end

---the sky of a period: its colors, how the glass changes with it and what it adds to the timeline
local period = function(palette, glass, extra)
    return { Palette = palette, Elements = { Timeline = { Glass = glass, ExtraSparkles = extra } } }
end

private.RegisterTheme({
    Name = "WeatherSandstorm",
    DisplayName = "Sandstorm",
    Description = private.getLocalisation("ThemeWeatherSandstormDescription"),
    Weather = "Sandstorm",
    Effects = true,
    ByIntensity = BY_INTENSITY,
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
        Smoke = { 0.22, 0.15, 0.08, 1 },
        Mist = { 1, 0.86, 0.62, 1 },
        Grit = { 0.86, 0.7, 0.45, 1 },
    },
    TimeOfDay = {
        Morning = { Palette = { Body = { 0.11, 0.08, 0.08, 0.95 }, Accent = { 1, 0.75, 0.55, 1 }, Accent2 = { 0.85, 0.5, 0.4, 1 } } },
        -- a red sun glowing through the dust, low at the far end
        Evening = period({ Body = { 0.13, 0.06, 0.04, 0.95 }, Accent = { 1, 0.55, 0.25, 1 }, Accent2 = { 0.75, 0.25, 0.15, 1 } },
            { Lamp = { File = "glow", Color = "Accent2", Alpha = 0.2, Size = 180, At = { 0.5, 0.85 } } }, RED_SUN),
        -- dark glass, the dust dim, a few stars
        Night = period({
            Body = { 0.03, 0.03, 0.06, 0.95 }, Accent = { 0.65, 0.68, 0.85, 1 }, Accent2 = { 0.45, 0.4, 0.6, 1 }, Muted = { 0.5, 0.5, 0.62, 1 },
        }, { Tint = { Strength = 0.75 }, Overlay = { Alpha = 0.08 } }, STARS),
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
        Window = { WashHeight = 200, Glass = WINDOW_GLASS, Sparkles = landing(sand(12, 36, true), 0.15), Enter = DUST_IN, Exit = CARRIED_OFF },
        Dialog = { WashHeight = 200, Glass = WINDOW_GLASS, Sparkles = landing(sand(10, 28, true), 0.15), Enter = DUST_IN, Exit = CARRIED_OFF },
    },
    Elements = {
        Timeline = {
            Backdrop = { Background = "None", Border = "None" },
            -- the glass is the bar, its rim its edge
            Background = false,
            Edge = false,
            Glass = GLASS,
            Now = false,
            Wash = { Color = "Accent", Alpha = 0.12 },
            Sparkles = BLOWING,
            Enter = DUST_IN,
            Exit = CARRIED_OFF,
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
