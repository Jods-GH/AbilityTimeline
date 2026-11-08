local appName, app = ...
---@class AbilityTimeline
local private = app
private.RegisterThemeTextures("DruidFeral", { "drop", "rake", "tuft" }, { "shred", "clawed" })

-- dusky brown with a feral amber and a blood red: single drops of blood falling through the timeline, icons are clawed
-- open out of the shadow and shredded to pieces when they leave
local TUFT = private.ThemeApply.File("tuft")
local FUR = { "Accent", "Accent", "Muted" }

---single drops of blood falling slowly through the bar, Align turns them along their path
local bleeding = {
    Texture = private.ThemeApply.File("drop"),
    Colors = { "Accent2" },
    Area = "All",
    Rate = 0.7,
    Max = 4,
    Size = { 7, 9 },
    Life = { 1, 1.5 },
    Speed = { { 0, 0 }, { -12, -6 } },
    Gravity = -14,
    Align = true,
    Alpha = 0.6,
}

---tufts of fur drifting anywhere over the frame
local drift = function(rate, max)
    return {
        Texture = TUFT,
        Colors = FUR,
        Area = "All",
        Rate = rate,
        Max = max,
        Size = { 5, 9 },
        Life = { 2, 3 },
        Speed = { { -8, 8 }, { -6, 6 } },
        Sway = { 6, 1 },
        Alpha = 0.45,
        Spin = 1,
    }
end

---tufts torn off at once
local burst = function(count)
    return {
        Texture = TUFT,
        Colors = FUR,
        Count = count,
        Size = { 6, 10 },
        Life = { 0.4, 0.8 },
        Speed = { { -120, 120 }, { -40, 110 } },
        Gravity = -160,
        Alpha = 1,
        Spin = 5,
    }
end

-- torn apart along diagonal streaks, glowing where it tears
local SHREDDING = {
    Frames = "shred",
    Count = 12,
    Edge = { File = "shred_edge1", Color = "Accent2", Alpha = 1, BlendMode = "ADD" },
}
-- a shadow ripped open by three claw slits, glowing where it tears
local CLAWING = {
    Frames = "clawed",
    Count = 12,
    Edge = { File = "clawed_edge1", Color = "Accent", Alpha = 1, BlendMode = "ADD" },
}
local RAKE = { File = "rake", Color = "Accent2", Alpha = 0.8, BlendMode = "ADD" }
local CLAW_IN = {
    Scale = 0.95,
    Flare = { File = "rake", Color = "Accent", Alpha = 0.6, BlendMode = "ADD", Size = { 1.1, 0.95 }, Time = 0.3 },
}
local SHRED = {
    Ghost = { File = "panel", Slice = 8, Color = "Body", Dissolve = SHREDDING, Flash = RAKE, Time = 0.5 },
    Burst = burst(14),
}

---the style of spell and big icons: clawed open and shredded, pulse for the timeline icons only, big icons are already
---in sight
local iconStyle = function(pulse)
    return {
        -- Three blood beads fall and settle like its bleed particles.
        QueuedMarkers = pulse and {
            Art = { File = "drop", BlendMode = "BLEND" }, Colors = { "Accent2", "Accent2", "Accent2" },
            Size = 14, Spacing = 12, Offset = 5, Rotation = -math.pi / 2,
            Enter = { Time = 0.24, Stagger = 0.08, Y = 6 },
        } or false,
        Enter = {
            Scale = 0.96,
            Ghost = { File = "panel", Slice = 8, Color = "Shadow", Alpha = 0.97, Dissolve = CLAWING, Time = 0.45 },
        },
        Exit = {
            Ghost = { Source = "Icon", Dissolve = SHREDDING, Flash = RAKE, Time = 0.45 },
            Burst = burst(7),
        },
        -- a bleed ticking as it passes a tick, two drops of blood falling off it
        Pulse = pulse and {
            Glow = { Color = "Accent2", Alpha = 0.5 },
            Scale = false,
            Burst = {
                Texture = private.ThemeApply.File("drop"),
                Colors = { "Accent2" },
                Count = 2,
                Size = { 7, 10 },
                Life = { 0.45, 0.8 },
                Speed = { { -40, 40 }, { -10, 40 } },
                Gravity = -320,
                Align = true,
                Alpha = 1,
            },
        } or false,
        Text = {
            Font = { Media = false, Object = "GameFontHighlight", Flags = { OUTLINE = true }, Color = "Text", Shadow = true },
            Background = { Show = false, Media = false, File = "pill", Slice = 8, Color = "Body", Alpha = 0.75, Offset = { x = 8, y = 4 } },
        },
    }
end

private.RegisterTheme({
    Name = "DruidFeral",
    DisplayName = "Feral Druid",
    Description = private.getLocalisation("ThemeDruidFeralDescription"),
    Class = "DRUID",
    Spec = 2,
    Effects = true,
    Palette = {
        Body = { 0.08, 0.055, 0.035, 0.96 },
        Card = { 1, 0.65, 0.2, 0.05 },
        Field = { 0.13, 0.09, 0.06, 1 },
        FieldHover = { 0.18, 0.12, 0.07, 1 },
        FieldPressed = { 0.1, 0.07, 0.04, 1 },
        Track = { 0.3, 0.19, 0.08, 1 },
        Edge = { 1, 0.65, 0.2, 0.3 },
        Line = { 0.9, 0.2, 0.15, 0.45 },
        Accent = { 1, 0.65, 0.2, 1 },
        Accent2 = { 0.9, 0.2, 0.15, 1 },
        Highlight = { 1, 0.65, 0.2, 0.15 },
        Text = { 1, 0.96, 0.9, 1 },
        Muted = { 0.78, 0.66, 0.52, 1 },
        Danger = { 1, 0.4, 0.45, 1 },
        Wash = { 1, 0.65, 0.2, 0.12 },
        FooterFill = { 0.03, 0.01, 0, 0.3 },
        Shadow = { 0.03, 0.01, 0, 0.9 },
    },
    Fonts = {
        Title = { Size = 18 },
        Heading = { Color = "Accent" },
        CardTitle = { Size = 15 },
    },
    Motion = {
        Time = { Open = 0.25, Enter = 0.35 },
    },
    Windows = {
        Window = { WashHeight = 200, Sparkles = drift(0.8, 6), Enter = CLAW_IN, Exit = SHRED },
        Dialog = { WashHeight = 200, Sparkles = drift(0.6, 5), Enter = CLAW_IN, Exit = SHRED },
    },
    Elements = {
        Timeline = {
            Backdrop = { Background = "None", Border = "None" },
            Background = { File = "panel", Slice = 8, Color = "Body" },
            Edge = { File = "panel_edge", Slice = 8, Color = "Accent", Alpha = 0.35 },
            -- a calm bar, now and then a drop of blood falling through it
            Now = false,
            Wash = { Color = "Accent", Alpha = 0.12 },
            Sparkles = bleeding,
            Enter = CLAW_IN,
            Exit = SHRED,
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
