local appName, app = ...
---@class AbilityTimeline
local private = app
private.RegisterThemeTextures("WeatherMiscellaneous", { "mistbank" })

-- the game's other weather (Enum.WeatherType.Miscellaneous, which kinds it covers isn't documented), picked from
-- tools/sim/scenarios/weather_misc.js: grey and a pale violet, the timeline a pane of glass over the world with fog
-- pressed against it drifting past and covered in fine condensation that gathers and slowly runs (G3, the fog bank and
-- the condensation together, 2026-11-09); a light haze, banks of mist and thick fog as it gets denser, the mist leaving
-- condensation where it drifts off (B9); icons, the timeline and windows condense into view (E9), puff out mist at every
-- tick and are swallowed by it (X2); the fog heaviest in the morning, a lamp glowing through it in the evening, darker
-- with faint stars at night (T4 with T2's life)
local MISTBANK = private.ThemeApply.File("mistbank")
local MOTE = private.ThemeApply.File("mote")
local GLOW = private.ThemeApply.File("glow")
local GLINT = private.ThemeApply.File("glint")
local GLASS_BEAD = private.ThemeApply.File("glass_bead")
local HAZE = { "Accent", "Accent2" }

---banks of mist drifting slowly anywhere over the frame
local mist = function(rate, max)
    return {
        Texture = MISTBANK,
        Colors = HAZE,
        Area = "All",
        Rate = rate,
        Max = max,
        Size = { 30, 50 },
        Life = { 4, 6 },
        Speed = { { 4, 10 }, { -1, 1 } },
        Alpha = 0.25,
    }
end

---mist that leaves condensation where it drifts off the glass, a fine bead where most of it ends
local condensing = function(spec)
    spec.Land = { Behavior = "GlassBead", Chance = 0.6, Size = { 1.5, 3 } }
    return spec
end

---wisps of mist puffing out at once
local puff = function(count)
    return {
        Texture = MOTE,
        Colors = HAZE,
        Count = count,
        Size = { 8, 16 },
        Life = { 0.5, 0.9 },
        Speed = { { -40, 40 }, { -20, 30 } },
        Alpha = 0.5,
    }
end

---fine condensation on the glass over an icon, drying away
local dew = function(count)
    return {
        Texture = GLASS_BEAD,
        Colors = { "Water" },
        Count = count,
        Size = { 4, 7 },
        Life = { 0.9, 1.4 },
        Speed = { { 0, 0 }, { 0, 0 } },
        Alpha = 1,
        BlendMode = "BLEND",
        Steady = true,
        Spot = { 0.08, 0.92, 0.08, 0.92 },
    }
end

-- fog pressed against the glass drifting past, the world barely showing, the glass covered in fine condensation that
-- gathers and slowly runs
local DEW = {
    Density = 1.2, Size = { 1.5, 3.5 }, Max = 40, BeadSize = { 1.5, 3 }, Life = { 6, 10 }, Color = "Shadow", Alpha = 0.7,
    Shine = { Color = "Water", Alpha = 0.5 },
    Runners = { Count = 3, Size = { 4, 6 }, Speed = { 10, 25 }, Wait = { 3, 8 }, Slide = { 0.4, 1.4 }, Catch = { 0.4, 1.2 }, Every = 5 },
}
local GLASS = {
    Tint = { Color = "Smoke", Strength = 0.45, Veil = { Color = "Mist", Alpha = 0.45 } },
    Grain = { File = "glassfog", Color = "Mist", Alpha = 0.18, Size = 260, Drift = { 8, 0 } },
    Rim = { Color = "Mist", Alpha = { 0.35, 0.1 } },
    Drops = DEW,
}
-- the windows darker and clearer so their text reads, the fog thinner
local WINDOW_GLASS = {
    Tint = { Color = "Smoke", Strength = 0.85, Veil = { Color = "Mist", Alpha = 0.15 } },
    Grain = { File = "glassfog", Color = "Mist", Alpha = 0.07, Size = 300, Drift = { 6, 0 } },
    Rim = { Color = "Mist", Alpha = { 0.35, 0.1 } },
    Drops = {
        Density = 0.3, Size = { 1.5, 3.5 }, Max = 40, BeadSize = { 1.5, 3 }, Life = { 6, 10 }, Color = "Shadow", Alpha = 0.7,
        Shine = { Color = "Water", Alpha = 0.5 },
        Runners = { Count = 1, Size = { 4, 6 }, Speed = { 10, 25 }, Wait = { 4, 10 }, Slide = { 0.4, 1.4 }, Catch = { 0.4, 1.2 }, Every = 5 },
    },
}

---what the mist does on the timeline from an intensity on
local level = function(from, sparkles, glass)
    return { From = from, Elements = { Timeline = { Sparkles = sparkles, Glass = glass } } }
end
local MIST_BANKS = condensing(mist(0.6, 5))
local BY_INTENSITY = {
    level(0, condensing(mist(0.4, 3))),
    level(0.3, MIST_BANKS),
    -- thick fog, the glass misted heavier
    level(0.6, condensing(mist(1, 8)), { Tint = { Veil = { Alpha = 0.55 } }, Grain = { Alpha = 0.22 } }),
}

-- what each period adds to the timeline: a low glow through the mist in the evening, faint stars at night
local DUSK_GLOW = {
    Texture = GLOW,
    Colors = { "Accent2" },
    Rate = 0.4,
    Max = 1,
    Size = { 60, 70 },
    Life = { 3, 4 },
    Speed = { { 0, 0 }, { 0, 0 } },
    Alpha = 0.25,
}
local STARS = {
    Texture = GLINT,
    Colors = { "Accent" },
    Area = "All",
    Rate = 0.6,
    Max = 4,
    Size = { 3, 6 },
    Life = { 2.5, 4 },
    Speed = { { 0, 0 }, { 0, 0 } },
    Alpha = 0.35,
}

-- icons, the timeline and windows show slowly through mist on the glass that thins away, leaving fine condensation
local CONDENSE_IN = {
    Ghost = { File = "fog_patch", Color = "Mist", Alpha = 0.85, Fade = { 1, 0 }, Time = 0.55 },
    Burst = dew(5),
}
-- and shrink into the mist and are gone, a few wisps left
local SWALLOWED = {
    Ghost = { Source = "Icon", Scale = { 1, 0.4 }, Time = 0.4 },
    Burst = puff(8),
}

---the style of spell and big icons: out of the mist and back into it, pulse for the timeline icons only, big icons are
---already in sight
local iconStyle = function(pulse)
    return {
        -- Pale mist beads condense with a slow, soft reveal.
        QueuedMarkers = pulse and {
            Art = { File = "mote", BlendMode = "ADD" }, Colors = { "Accent2", "Accent", "Accent2" },
            Size = 20, Spacing = 12, Offset = 5,
            Enter = { Time = 0.4, Stagger = 0.1, X = -3, Grow = 0.5 },
        } or false,
        Enter = CONDENSE_IN,
        Exit = SWALLOWED,
        -- a puff of mist spreading out from it as it passes a tick
        Pulse = pulse and {
            Glow = false,
            Scale = false,
            Flare = { File = "mistbank", Color = "Accent", Alpha = 0.4, Size = { 0.8, 1.6 }, Time = 0.5 },
        } or false,
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
    Name = "WeatherMiscellaneous",
    DisplayName = "Mist",
    Description = private.getLocalisation("ThemeWeatherMiscellaneousDescription"),
    Weather = "Miscellaneous",
    Effects = true,
    ByIntensity = BY_INTENSITY,
    Palette = {
        Body = { 0.08, 0.08, 0.1, 0.95 },
        Card = { 0.75, 0.78, 0.85, 0.05 },
        Field = { 0.13, 0.13, 0.16, 1 },
        FieldHover = { 0.17, 0.17, 0.21, 1 },
        FieldPressed = { 0.1, 0.1, 0.12, 1 },
        Track = { 0.23, 0.23, 0.28, 1 },
        Edge = { 0.75, 0.78, 0.85, 0.25 },
        Line = { 0.62, 0.55, 0.8, 0.4 },
        Accent = { 0.75, 0.78, 0.85, 1 },
        Accent2 = { 0.62, 0.55, 0.8, 1 },
        Highlight = { 0.75, 0.78, 0.85, 0.12 },
        Text = { 0.94, 0.94, 0.97, 1 },
        Muted = { 0.58, 0.6, 0.66, 1 },
        Danger = { 1, 0.5, 0.55, 1 },
        Wash = { 0.75, 0.78, 0.85, 0.1 },
        FooterFill = { 0, 0, 0.02, 0.3 },
        Shadow = { 0, 0, 0.02, 0.85 },
        Smoke = { 0.16, 0.16, 0.2, 1 },
        Mist = { 0.88, 0.88, 0.94, 1 },
        Water = { 0.86, 0.88, 0.95, 1 },
    },
    TimeOfDay = {
        -- the fog heaviest
        Morning = period({ Body = { 0.1, 0.09, 0.11, 0.95 }, Accent = { 0.88, 0.82, 0.85, 1 }, Accent2 = { 0.8, 0.62, 0.7, 1 } },
            { Tint = { Veil = { Alpha = 0.55 } } }),
        -- a lamp glowing through the fog
        Evening = period({ Body = { 0.1, 0.07, 0.09, 0.95 }, Accent = { 0.85, 0.7, 0.65, 1 }, Accent2 = { 0.75, 0.45, 0.6, 1 } },
            { Lamp = { File = "glow", Color = "Accent2", Alpha = 0.14, Size = 160, At = { 0.5, 0.2 } } }, DUSK_GLOW),
        -- darker, faint stars
        Night = period({
            Body = { 0.03, 0.03, 0.06, 0.95 }, Accent = { 0.55, 0.6, 0.75, 1 }, Accent2 = { 0.45, 0.4, 0.7, 1 }, Muted = { 0.45, 0.47, 0.58, 1 },
        }, { Tint = { Strength = 0.7 } }, STARS),
    },
    Fonts = {
        Title = { Size = 18 },
        Heading = { Color = "Accent2" },
        CardTitle = { Size = 15 },
    },
    Motion = {
        Time = { Open = 0.35, Enter = 0.45 },
    },
    Windows = {
        Window = { WashHeight = 200, Glass = WINDOW_GLASS, Sparkles = condensing(mist(0.8, 6)), Enter = CONDENSE_IN, Exit = SWALLOWED },
        Dialog = { WashHeight = 200, Glass = WINDOW_GLASS, Sparkles = condensing(mist(0.6, 5)), Enter = CONDENSE_IN, Exit = SWALLOWED },
    },
    Elements = {
        Timeline = {
            Backdrop = { Background = "None", Border = "None" },
            -- the glass is the bar, its rim its edge
            Background = false,
            Edge = false,
            Glass = GLASS,
            Now = false,
            Wash = { Color = "Accent2", Alpha = 0.1 },
            Sparkles = MIST_BANKS,
            Enter = CONDENSE_IN,
            Exit = SWALLOWED,
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
            Enter = { Burst = puff(6) },
            Exit = { Burst = puff(8) },
        },
    },
})
