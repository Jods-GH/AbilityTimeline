local appName, app = ...
---@class AbilityTimeline
local private = app
private.RegisterThemeTextures("WeatherClear", { "sunshaft" })

-- a clear sky and sun gold, picked from tools/sim/scenarios/weather_clear.js: shafts of sunlight and motes over the
-- timeline, icons come down out of the light and rise back into it, the timeline grows in with motes and rises away; the
-- sky changes with the time of day, mist in the morning, warm motes in the evening and stars at night
local MOTE = private.ThemeApply.File("mote")
local SUNSHAFT = private.ThemeApply.File("sunshaft")
local GLINT = private.ThemeApply.File("glint")
local SUNLIGHT = { "Accent", "Accent2", "White" }

---motes of sunlight drifting up, anywhere over the frame with area "All"
local motes = function(rate, max, area)
    return {
        Texture = MOTE,
        Colors = SUNLIGHT,
        Area = area,
        Rate = rate,
        Max = max,
        Size = { 4, 9 },
        Life = { 2.5, 4 },
        Speed = { { -4, 4 }, { 4, 10 } },
        Sway = { 4, 0.6 },
        Alpha = 0.7,
    }
end

---motes flying apart at once
local burst = function(count)
    return {
        Texture = MOTE,
        Colors = SUNLIGHT,
        Count = count,
        Size = { 4, 9 },
        Life = { 0.4, 0.8 },
        Speed = { { -90, 90 }, { -50, 110 } },
        Gravity = 40,
        Alpha = 1,
    }
end

-- soft shafts of light fading in and out along the timeline
local SHAFTS = {
    Texture = SUNSHAFT,
    Colors = { "Accent" },
    Area = "All",
    Rate = 0.6,
    Max = 3,
    Size = { 12, 18 },
    Tall = 4,
    Life = { 2.5, 3.5 },
    Speed = { { 0, 0 }, { 0, 0 } },
    Alpha = 0.3,
}
local SKY = { SHAFTS, motes(0.8, 6, "All") }
-- what each period adds to the sky
local MIST = {
    Texture = MOTE,
    Colors = { "Accent2" },
    Area = "All",
    Rate = 0.8,
    Max = 5,
    Size = { 18, 30 },
    Life = { 4, 6 },
    Speed = { { 6, 12 }, { -1, 1 } },
    Alpha = 0.18,
}
local DUSK_MOTES = {
    Texture = MOTE,
    Colors = { "Accent" },
    Rate = 1.2,
    Max = 6,
    Size = { 4, 8 },
    Life = { 1.5, 2.5 },
    Speed = { { -4, 4 }, { 6, 14 } },
    Alpha = 0.8,
}
local STARS = {
    Texture = GLINT,
    Colors = { "Accent", "White" },
    Area = "All",
    Rate = 1.6,
    Max = 10,
    Size = { 4, 8 },
    Life = { 2.5, 4 },
    Speed = { { 0, 0 }, { 0, 0 } },
    Alpha = 0.7,
}

local FLASH = { File = "panel", Slice = 8, Color = "Accent", Alpha = 0.35, BlendMode = "ADD" }
-- the timeline and windows grow in with motes flying off, and rise away in a gold flash
local DAWN = { Scale = 0.94, Burst = burst(14) }
local DUSK = {
    Ghost = { File = "panel", Slice = 8, Color = "Body", Rise = 12, Flash = FLASH, Time = 0.45 },
    Burst = burst(16),
}

---the style of spell and big icons: out of the light and back into it, pulse for the timeline icons only,
---big icons are already in sight
local iconStyle = function(pulse)
    return {
        -- Sunlit motes drift down into a quiet golden ellipsis.
        QueuedMarkers = pulse and {
            Art = { File = "glint", BlendMode = "ADD" }, Colors = { "Accent", "Accent2", "Accent" },
            Size = 16, Spacing = 12, Offset = 5,
            Enter = { Time = 0.3, Stagger = 0.1, Y = 5 },
        } or false,
        -- its leave backwards: an image of it flashing gold comes down into place as it fades in, motes gathering onto it
        Enter = {
            Ghost = { Source = "Icon", Scale = { 1.1, 1 }, Rise = { 10, 0 }, Fade = { 0, 1 }, Flash = FLASH, Time = 0.4 },
            Vortex = { Texture = MOTE, Colors = SUNLIGHT, Count = 8, Radius = 0.9, Size = { 5, 9 }, Turns = 0, Time = 0.4 },
        },
        Exit = {
            Ghost = { Source = "Icon", Scale = { 1, 1.1 }, Rise = 10, Flash = FLASH, Time = 0.4 },
            Burst = burst(8),
        },
        -- Classic's halo in the sun's gold
        Pulse = pulse and { Glow = { Color = "Accent" } } or false,
        Text = {
            Font = { Media = false, Object = "GameFontHighlight", Flags = { OUTLINE = true }, Color = "Text", Shadow = true },
            Background = { Show = false, Media = false, File = "pill", Slice = 8, Color = "Body", Alpha = 0.75, Offset = { x = 8, y = 4 } },
        },
    }
end

---the sky of a period: its colors and what it adds to the timeline
local period = function(palette, extra)
    return { Palette = palette, Elements = { Timeline = { Sparkles = { SHAFTS, SKY[2], extra } } } }
end

private.RegisterTheme({
    Name = "WeatherClear",
    DisplayName = "Clear Skies",
    Description = private.getLocalisation("ThemeWeatherClearDescription"),
    Weather = "Clear",
    Effects = true,
    Palette = {
        Body = { 0.04, 0.09, 0.16, 0.95 },
        Card = { 1, 0.82, 0.4, 0.05 },
        Field = { 0.07, 0.15, 0.25, 1 },
        FieldHover = { 0.09, 0.19, 0.32, 1 },
        FieldPressed = { 0.05, 0.11, 0.19, 1 },
        Track = { 0.13, 0.25, 0.4, 1 },
        Edge = { 0.5, 0.78, 1, 0.3 },
        Line = { 1, 0.82, 0.4, 0.45 },
        Accent = { 1, 0.82, 0.4, 1 },
        Accent2 = { 0.5, 0.78, 1, 1 },
        Highlight = { 1, 0.82, 0.4, 0.14 },
        Text = { 1, 0.98, 0.92, 1 },
        Muted = { 0.62, 0.7, 0.8, 1 },
        Danger = { 1, 0.5, 0.55, 1 },
        Wash = { 1, 0.82, 0.4, 0.12 },
        FooterFill = { 0, 0.02, 0.05, 0.3 },
        Shadow = { 0, 0.02, 0.05, 0.85 },
    },
    TimeOfDay = {
        Morning = period({
            Body = { 0.08, 0.08, 0.15, 0.95 }, Accent = { 1, 0.68, 0.62, 1 }, Accent2 = { 0.7, 0.75, 1, 1 }, Muted = { 0.7, 0.66, 0.8, 1 },
        }, MIST),
        Evening = period({
            Body = { 0.12, 0.06, 0.08, 0.95 }, Accent = { 1, 0.55, 0.25, 1 }, Accent2 = { 0.85, 0.45, 0.6, 1 }, Muted = { 0.78, 0.6, 0.58, 1 },
        }, DUSK_MOTES),
        Night = period({
            Body = { 0.02, 0.03, 0.08, 0.95 }, Accent = { 0.75, 0.82, 1, 1 }, Accent2 = { 0.45, 0.5, 0.9, 1 }, Muted = { 0.5, 0.55, 0.72, 1 },
            Text = { 0.85, 0.88, 1, 1 },
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
        Window = { WashHeight = 200, Sparkles = motes(1.2, 10), Enter = DAWN, Exit = DUSK },
        Dialog = { WashHeight = 200, Sparkles = motes(1, 8), Enter = DAWN, Exit = DUSK },
    },
    Elements = {
        Timeline = {
            Backdrop = { Background = "None", Border = "None" },
            Background = { File = "panel", Slice = 8, Color = "Body" },
            Edge = { File = "panel_edge", Slice = 8, Color = "Accent2", Alpha = 0.35 },
            Now = false,
            Wash = { Color = "Accent", Alpha = 0.12 },
            Sparkles = SKY,
            Enter = DAWN,
            Exit = DUSK,
        },
        Tick = {
            Line = { Color = "Accent2", Alpha = 0.25 },
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
            Exit = { Burst = burst(10) },
        },
    },
})
