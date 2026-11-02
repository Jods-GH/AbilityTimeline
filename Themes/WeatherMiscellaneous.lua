local appName, app = ...
---@class AbilityTimeline
local private = app
private.RegisterThemeTextures("WeatherMiscellaneous", { "mistbank" })

-- the game's other weather (Enum.WeatherType.Miscellaneous, which kinds it covers isn't documented), picked from
-- tools/sim/scenarios/weather_misc.js: grey and a pale violet, banks of mist drifting over the timeline, things appear
-- out of the mist, puff out mist at every tick and are swallowed by it; a low glow in the evening, faint stars at night
local MISTBANK = private.ThemeApply.File("mistbank")
local MOTE = private.ThemeApply.File("mote")
local GLOW = private.ThemeApply.File("glow")
local GLINT = private.ThemeApply.File("glint")
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

local OUT_OF_MIST = { Scale = 0.95, Ghost = { File = "panel", Slice = 8, Color = "Accent2", Alpha = 0.6, Fade = { 0.6, 0 }, Time = 0.5 } }
local INTO_MIST = { Ghost = { File = "panel", Slice = 8, Color = "Body", Fade = { 1, 0 }, Time = 0.5 }, Burst = puff(10) }

---the style of spell and big icons: out of the mist and back into it, pulse for the timeline icons only, big icons are
---already in sight
local iconStyle = function(pulse)
    return {
        Enter = { Scale = 0.95, Ghost = { Color = "Accent2", Alpha = 0.6, Fade = { 0.6, 0 }, Time = 0.45 } },
        -- shrinks into the mist and is gone, a few wisps left
        Exit = {
            Ghost = { Source = "Icon", Scale = { 1, 0.4 }, Time = 0.4 },
            Burst = puff(8),
        },
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

private.RegisterTheme({
    Name = "WeatherMiscellaneous",
    DisplayName = "Mist",
    Description = private.getLocalisation("ThemeWeatherMiscellaneousDescription"),
    Weather = "Miscellaneous",
    Effects = true,
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
    },
    TimeOfDay = {
        Morning = { Palette = { Body = { 0.1, 0.09, 0.11, 0.95 }, Accent = { 0.88, 0.82, 0.85, 1 }, Accent2 = { 0.8, 0.62, 0.7, 1 } } },
        Evening = {
            Palette = { Body = { 0.1, 0.07, 0.09, 0.95 }, Accent = { 0.85, 0.7, 0.65, 1 }, Accent2 = { 0.75, 0.45, 0.6, 1 } },
            Elements = { Timeline = { Sparkles = { mist(0.6, 5), DUSK_GLOW } } },
        },
        Night = {
            Palette = {
                Body = { 0.03, 0.03, 0.06, 0.95 }, Accent = { 0.55, 0.6, 0.75, 1 }, Accent2 = { 0.45, 0.4, 0.7, 1 }, Muted = { 0.45, 0.47, 0.58, 1 },
            },
            Elements = { Timeline = { Sparkles = { mist(0.6, 5), STARS } } },
        },
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
        Window = { WashHeight = 200, Sparkles = mist(0.8, 6), Enter = OUT_OF_MIST, Exit = INTO_MIST },
        Dialog = { WashHeight = 200, Sparkles = mist(0.6, 5), Enter = OUT_OF_MIST, Exit = INTO_MIST },
    },
    Elements = {
        Timeline = {
            Backdrop = { Background = "None", Border = "None" },
            Background = { File = "panel", Slice = 8, Color = "Body" },
            Edge = { File = "panel_edge", Slice = 8, Color = "Accent", Alpha = 0.3 },
            Now = false,
            Wash = { Color = "Accent2", Alpha = 0.1 },
            Sparkles = mist(0.6, 5),
            Enter = OUT_OF_MIST,
            Exit = INTO_MIST,
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
