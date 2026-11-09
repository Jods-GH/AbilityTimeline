local appName, app = ...
---@class AbilityTimeline
local private = app
private.RegisterThemeTextures("WeatherRain", { "raindrop", "ripple" })

-- slate grey and rain blue with a pale silver, picked from tools/sim/scenarios/weather_rain.js: the timeline is a pane
-- of smoked glass over the world (G1, 2026-11-09) with the rain landing on it in beads, its ambient following the
-- intensity from drops striking it over a drizzle, puddles, rain on the glass (B5) and a downpour to a thunderstorm;
-- icons show through mist on the glass that thins away (E16), a drop strikes them at every tick and they mist over,
-- leaving beads of water behind, when they leave (X23); the timeline and windows show and hide the same way; the
-- glass misted in the morning, a lamp in it in the evening, lightning over it at night (T4)
local RAINDROP = private.ThemeApply.File("raindrop")
local RIPPLE = private.ThemeApply.File("ripple")
local WATER = { "Accent", "Accent2" }
local GLASS_BEAD = private.ThemeApply.File("glass_bead")

---beads of water sitting on the glass over an icon, round and see-through, drawn as they are, drying away
local beads = function(count, size, life)
    return {
        Texture = GLASS_BEAD,
        Colors = { "Water" },
        Count = count,
        Size = size,
        Life = life,
        Speed = { { 0, 0 }, { 0, 0 } },
        Alpha = 1,
        BlendMode = "BLEND",
        Steady = true,
        Spot = { 0.08, 0.92, 0.08, 0.92 },
    }
end

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

---rain that lands on the glass, chance of its streaks leaving a bead where they end
local landing = function(spec, chance)
    spec.Land = { Behavior = "GlassBead", Chance = chance }
    return spec
end

---rings spreading where drops strike
local ripples = function(rate, max, size, life, alpha)
    return {
        Texture = RIPPLE,
        Colors = { "Accent2" },
        Area = "All",
        Rate = rate,
        Max = max,
        Size = size,
        Life = life,
        Speed = { { 0, 0 }, { 0, 0 } },
        Alpha = alpha,
        Intensity = { 0.5, 1.5 },
    }
end

-- the drizzle hitting the glass, half its streaks leaving a bead where they end
local DRIZZLE = landing(rain(3, 10, true), 0.5)
local DOWNPOUR = landing(rain(8, 24), 0.25)

---what the rain does on the timeline from an intensity on (the game's: light up to about 0.1, medium up to 0.5)
local level = function(from, sparkles, glass)
    return { From = from, Elements = { Timeline = { Sparkles = sparkles, Glass = glass } } }
end
local BY_INTENSITY = {
    -- drops striking the glass, a small ring where each hits and a bead left behind, no streaks
    level(0, landing(ripples(2, 6, { 6, 11 }, { 0.3, 0.45 }, 0.3), 1)),
    -- a drizzle, nearly straight, some of it staying on the glass
    level(0.04, landing(rain(4, 12, true), 0.3)),
    -- the drizzle with rings spreading where it lands
    level(0.1, { landing(rain(3, 10, true), 0.4), ripples(1.5, 6, { 8, 16 }, { 0.6, 0.9 }, 0.35) }),
    -- rain on the glass, half of it beading up
    level(0.3, DRIZZLE),
    -- a downpour, slanting fast, a quarter of it staying
    level(0.5, DOWNPOUR),
    -- a thunderstorm: the downpour and lightning flashing over the glass
    level(0.8, DOWNPOUR, { Flash = { Every = { 5, 12 }, Time = 0.5, Color = "Mist", Alpha = 0.24 } }),
}

-- smoked glass: the world darkened behind it, fog in it, bands of reflected light and a lit rim, a few drops sitting on
-- it and now and then one running down, more of them the harder it rains
local GLASS = {
    Tint = { Color = "Smoke", Strength = 0.6, Veil = { Color = "Mist", Alpha = 0.16 } },
    Grain = { File = "glassfog", Color = "Mist", Alpha = 0.05, Size = 256 },
    Reflections = { File = "glassreflect", Color = "Mist", Alpha = 0.2, Angle = 64, Period = 500, Length = 900, Drift = 6 },
    Rim = { Color = "Mist", Alpha = { 0.45, 0.1 } },
    Drops = {
        Density = 0.6, Size = { 3, 8 }, Max = 28, BeadSize = { 2, 4 }, Life = { 7, 12 }, Color = "Shadow", Alpha = 0.85,
        Shine = { Color = "Water", Alpha = 0.7 }, Intensity = { 0.5, 1.5 },
        Runners = { Count = 2, Size = { 6, 9 }, Speed = { 30, 70 }, Wait = { 2, 6 }, Slide = { 0.25, 1 }, Catch = { 0.2, 0.9 }, Every = 7 },
    },
}

-- the windows are the same smoked glass, darker so their text reads over the world, fewer drops sitting on them and
-- one running now and then; the rain over them lands on them
local WINDOW_GLASS = {
    Tint = { Color = "Smoke", Strength = 0.85, Veil = { Color = "Mist", Alpha = 0.1 } },
    Grain = { File = "glassfog", Color = "Mist", Alpha = 0.04, Size = 256 },
    Reflections = { File = "glassreflect", Color = "Mist", Alpha = 0.12, Angle = 64, Period = 700, Length = 1200, Drift = 6 },
    Rim = { Color = "Mist", Alpha = { 0.45, 0.12 } },
    Drops = {
        Density = 0.12, Size = { 3, 8 }, Max = 30, BeadSize = { 2, 4 }, Life = { 7, 12 }, Color = "Shadow", Alpha = 0.85,
        Shine = { Color = "Water", Alpha = 0.7 },
        Runners = { Count = 1, Size = { 6, 9 }, Speed = { 30, 70 }, Wait = { 3, 8 }, Slide = { 0.25, 1 }, Catch = { 0.2, 0.9 }, Every = 7 },
    },
}

-- icons, the timeline and windows all show and hide the same way:
-- appearing, it shows through a patch of mist on the glass that thins away, leaving a few beads that dry
local MIST_IN = {
    Ghost = { File = "fog_patch", Color = "Mist", Alpha = 0.75, Fade = { 1, 0 }, Time = 0.45 },
    Burst = beads(4, { 6, 10 }, { 0.9, 1.4 }),
}
-- leaving, mist gathers on the glass over it as it fades and leaves beads of water there that dry (the timeline and
-- windows have no image of their own to fade, only the mist and beads show where they were)
local MIST_OUT = {
    Ghost = { Source = "Icon", Fade = { 1, 0 }, Flash = { File = "fog_patch", Color = "Mist", Alpha = 0.9, BlendMode = "ADD" }, Time = 0.4 },
    -- short lived: groups keep the slot until the beads are gone
    Burst = beads(6, { 6, 11 }, { 0.7, 1 }),
    BurstDelay = 0.2,
}

---the style of spell and big icons: shown through and lost in mist on the glass, pulse for the timeline icons only,
---big icons are already in sight
local iconStyle = function(pulse)
    return {
        -- beads of water falling in sequence with a small hop
        QueuedMarkers = pulse and {
            Art = { File = "glass_bead", BlendMode = "BLEND" }, Colors = { "Water", "Accent2", "Water" },
            Size = 14, Spacing = 12, Offset = 5,
            Enter = { Time = 0.26, Stagger = 0.1, Y = 7, Hop = 2 },
        } or false,
        Enter = MIST_IN,
        Exit = MIST_OUT,
        -- a drop strikes the glass on it as it passes a tick: a faint ring and a bead or two left behind
        Pulse = pulse and {
            Flare = { File = "ripple", Color = "Mist", Alpha = 0.35, Size = { 0.5, 1.2 }, Time = 0.45 },
            Burst = beads(2, { 6, 9 }, { 0.6, 0.9 }),
        } or false,
        Text = {
            Font = { Media = false, Object = "GameFontHighlight", Flags = { OUTLINE = true }, Color = "Text", Shadow = true },
            Background = { Show = false, Media = false, File = "pill", Slice = 8, Color = "Body", Alpha = 0.75, Offset = { x = 8, y = 4 } },
        },
    }
end

---the sky of a period: its colors and how the glass changes with it
local period = function(palette, glass)
    return { Palette = palette, Elements = { Timeline = { Glass = glass } } }
end

private.RegisterTheme({
    Name = "WeatherRain",
    DisplayName = "Rain",
    Description = private.getLocalisation("ThemeWeatherRainDescription"),
    Weather = "Rain",
    Effects = true,
    ByIntensity = BY_INTENSITY,
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
        Smoke = { 0.14, 0.17, 0.22, 1 },
        Mist = { 0.78, 0.84, 0.92, 1 },
    },
    TimeOfDay = {
        -- misted over
        Morning = period({
            Body = { 0.08, 0.08, 0.11, 0.96 }, Accent = { 0.62, 0.7, 0.85, 1 }, Accent2 = { 0.9, 0.8, 0.82, 1 },
            Smoke = { 0.2, 0.2, 0.25, 1 }, Mist = { 0.9, 0.86, 0.9, 1 },
        }, { Tint = { Strength = 0.55, Veil = { Alpha = 0.34 } }, Grain = { Alpha = 0.12, Size = 200 } }),
        -- a warm lamp reflected in the pane, away from where icons arrive
        Evening = period({
            Body = { 0.1, 0.07, 0.07, 0.96 }, Accent = { 0.75, 0.6, 0.55, 1 }, Accent2 = { 1, 0.7, 0.45, 1 },
            Smoke = { 0.2, 0.15, 0.14, 1 }, Mist = { 0.95, 0.82, 0.72, 1 },
        }, { Lamp = { File = "glow", Color = "Accent2", Alpha = 0.14, Size = 150, At = { 0.5, 0.8 } } }),
        -- lightning flashing over the glass
        Night = period({
            Body = { 0.02, 0.03, 0.05, 0.96 }, Accent = { 0.35, 0.5, 0.7, 1 }, Accent2 = { 0.6, 0.68, 0.8, 1 }, Muted = { 0.45, 0.52, 0.6, 1 },
            Smoke = { 0.07, 0.09, 0.13, 1 }, Mist = { 0.7, 0.78, 0.9, 1 },
        }, { Flash = { Every = { 8, 16 }, Time = 0.5, Color = "Mist", Alpha = 0.24 } }),
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
        Window = { WashHeight = 200, Glass = WINDOW_GLASS, Sparkles = landing(rain(10, 30), 0.3), Enter = MIST_IN, Exit = MIST_OUT },
        Dialog = { WashHeight = 200, Glass = WINDOW_GLASS, Sparkles = landing(rain(8, 24), 0.3), Enter = MIST_IN, Exit = MIST_OUT },
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
            Sparkles = DRIZZLE,
            Enter = MIST_IN,
            Exit = MIST_OUT,
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
        },
    },
})
