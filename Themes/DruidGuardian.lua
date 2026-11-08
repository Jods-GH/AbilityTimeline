local appName, app = ...
---@class AbilityTimeline
local private = app
private.RegisterThemeTextures("DruidGuardian", { "bark_chip", "clod", "thrash" }, { "gashed" })

-- dark earth with bark brown and a rage red: heavy bevelled icon frames with three claw slashes cut through them, chips
-- of bark at the end icons arrive at, Thrash's three gashes tearing things open, apart or into heavy pieces that drop away
local CHIP = private.ThemeApply.File("bark_chip")
local CLOD = private.ThemeApply.File("clod")
local BARK = { "Accent", "Accent", "Muted" }

---a few chips of bark falling off the end icons arrive at, kept dim so they don't distract
local chips = {
    Texture = CHIP,
    Colors = BARK,
    Rate = 0.8,
    Max = 5,
    Size = { 5, 8 },
    Life = { 0.9, 1.4 },
    Speed = { { -4, 4 }, { -14, -4 } },
    Gravity = -20,
    Alpha = 0.45,
    Spin = 1.5,
}

---chips of bark falling anywhere over the frame
local barkfall = function(rate, max)
    return {
        Texture = CHIP,
        Colors = BARK,
        Area = "All",
        Rate = rate,
        Max = max,
        Size = { 5, 8 },
        Life = { 1.6, 2.6 },
        Speed = { { -4, 4 }, { -16, -6 } },
        Alpha = 0.45,
        Spin = 1.5,
    }
end

---chunks of bark breaking off at once and falling
local burst = function(count)
    return {
        Texture = CHIP,
        Colors = BARK,
        Count = count,
        Size = { 6, 11 },
        Life = { 0.5, 0.9 },
        Speed = { { -80, 80 }, { 0, 90 } },
        Gravity = -380,
        Alpha = 1,
        Spin = 4,
    }
end

---heavy clods of earth thrown up by Thrash and dropping fast
local clods = function(count)
    return {
        Texture = CLOD,
        Colors = BARK,
        Count = count,
        Size = { 6, 10 },
        Life = { 0.5, 0.8 },
        Speed = { { -90, 90 }, { 30, 120 } },
        Gravity = -650,
        Alpha = 1,
        Spin = 3,
    }
end

-- torn open along Thrash's three gashes, glowing red where it tears
local GASHED = {
    Frames = "gashed",
    Count = 12,
    Edge = { File = "gashed_edge1", Color = "Accent2", Alpha = 1, BlendMode = "ADD" },
}
local THRASH_IN = {
    Scale = 0.97,
    Flare = { File = "thrash", Color = "Accent2", Alpha = 0.5, BlendMode = "ADD", Size = { 1.3, 1.1 }, Time = 0.3 },
}
-- cut by the gashes for a moment, then breaking into heavy pieces that fall
local THRASH_OUT = {
    Crack = { File = "thrash", Color = "Accent2", Alpha = 0.8, BlendMode = "ADD", Time = 0.14 },
    Shards = { Color = "Body", Speed = { 50, 140 }, Gravity = -900, Time = 0.5 },
    Burst = clods(10),
}

---the style of spell and big icons: torn open by Thrash and torn apart when they leave, pulse for the timeline icons
---only, big icons are already in sight
local iconStyle = function(pulse)
    return {
        -- Heavy earth chips land with a short, low bounce.
        QueuedMarkers = pulse and {
            Art = { File = "clod", BlendMode = "BLEND" }, Colors = { "Accent", "Accent2", "Accent" },
            Size = 14, Spacing = 12, Offset = 5,
            Enter = { Time = 0.22, Stagger = 0.09, Y = 4, Hop = 2 },
        } or false,
        Enter = {
            Scale = 0.96,
            Ghost = { File = "panel", Slice = 8, Color = "Shadow", Alpha = 0.97, Dissolve = GASHED, Time = 0.45 },
        },
        Exit = {
            Ghost = { Source = "Icon", Dissolve = GASHED, Time = 0.4 },
            Flare = { File = "thrash", Color = "Accent2", Alpha = 0.75, BlendMode = "ADD", Size = { 1.15, 1.05 }, Time = 0.3 },
            Burst = clods(5),
        },
        -- Thrash's three gashes flashing over it as it passes a tick
        Pulse = pulse and {
            Glow = false,
            Scale = false,
            Flare = { File = "thrash", Color = "Accent2", Alpha = 0.5, BlendMode = "ADD", Size = { 1.1, 1 }, Time = 0.3 },
        } or false,
        Text = {
            Font = { Media = false, Object = "GameFontHighlight", Flags = { OUTLINE = true }, Color = "Text", Shadow = true },
            Background = { Show = false, Media = false, File = "pill", Slice = 8, Color = "Body", Alpha = 0.75, Offset = { x = 8, y = 4 } },
        },
    }
end

-- only clients with four druid specializations have Guardian, older ones have three talent trees with Restoration
-- third, the Guardian theme is still listed there but never picked automatically
local hasGuardian = C_SpecializationInfo.GetNumSpecializationsForClassID(11) == 4

private.RegisterTheme({
    Name = "DruidGuardian",
    DisplayName = "Guardian Druid",
    Description = private.getLocalisation("ThemeDruidGuardianDescription"),
    Class = "DRUID",
    Spec = hasGuardian and 3 or false,
    Effects = true,
    Palette = {
        Body = { 0.07, 0.05, 0.035, 0.96 },
        Card = { 0.75, 0.55, 0.35, 0.05 },
        Field = { 0.12, 0.085, 0.06, 1 },
        FieldHover = { 0.16, 0.115, 0.08, 1 },
        FieldPressed = { 0.09, 0.065, 0.045, 1 },
        Track = { 0.26, 0.19, 0.12, 1 },
        Edge = { 0.75, 0.55, 0.35, 0.3 },
        Line = { 0.86, 0.2, 0.12, 0.45 },
        Accent = { 0.75, 0.55, 0.35, 1 },
        Accent2 = { 0.86, 0.2, 0.12, 1 },
        Highlight = { 0.75, 0.55, 0.35, 0.15 },
        Text = { 1, 0.96, 0.9, 1 },
        Muted = { 0.72, 0.64, 0.54, 1 },
        Danger = { 1, 0.45, 0.45, 1 },
        Wash = { 0.75, 0.55, 0.35, 0.12 },
        FooterFill = { 0.03, 0.01, 0, 0.3 },
        Shadow = { 0.03, 0.01, 0, 0.9 },
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
        Window = { WashHeight = 200, Sparkles = barkfall(0.8, 6), Enter = THRASH_IN, Exit = THRASH_OUT },
        Dialog = { WashHeight = 200, Sparkles = barkfall(0.6, 5), Enter = THRASH_IN, Exit = THRASH_OUT },
    },
    Elements = {
        Timeline = {
            Backdrop = { Background = "None", Border = "None" },
            Background = { File = "panel", Slice = 8, Color = "Body" },
            Edge = { File = "panel_edge", Slice = 8, Color = "Accent", Alpha = 0.4 },
            -- a calm bar, a few chips of bark falling at the end icons arrive at
            Now = false,
            Wash = { Color = "Accent", Alpha = 0.12 },
            Sparkles = chips,
            Enter = THRASH_IN,
            Exit = THRASH_OUT,
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
            Enter = { Burst = burst(4) },
            Exit = { Burst = burst(8) },
        },
    },
})
