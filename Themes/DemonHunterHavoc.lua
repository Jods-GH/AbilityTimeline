local appName, app = ...
---@class AbilityTimeline
local private = app
private.RegisterThemeTextures("DemonHunterHavoc", { "tattoo1", "tattoo2", "tattoo3" }, { "immolate" })

-- charred black with a chaotic fel green and a hot yellow: fel tattoos glow up over the timeline, icons are burnt out of
-- the shadow by Immolation Aura and burn up when they leave
local EMBER = private.ThemeApply.File("fel_ember")
local CHAOS = { "Accent", "Accent", "Accent2" }
local TATTOOS = { private.ThemeApply.File("tattoo1"), private.ThemeApply.File("tattoo2"), private.ThemeApply.File("tattoo3") }

---fel tattoos lighting up in place anywhere over the frame and fading, a tiny sideways speed with Align keeps them
---upright
local tattoos = function(rate, max)
    return { Texture = TATTOOS, Colors = { "Accent" }, Area = "All", Rate = rate, Max = max, Size = { 14, 18 },
        Life = { 2.2, 3.2 }, Speed = { { 0.5, 0.5 }, { 0, 0 } }, Align = true, Alpha = 0.4 }
end

---fel tattoos lighting up at once
local tattooBurst = function(count, life)
    return { Texture = TATTOOS, Colors = { "Accent" }, Count = count, Size = { 14, 18 }, Life = life,
        Speed = { { 0.5, 0.5 }, { 0, 0 } }, Align = true, Alpha = 0.8 }
end

---embers rising off what burns
local rising = function(count)
    return {
        Texture = EMBER,
        Colors = CHAOS,
        Count = count,
        Size = { 6, 10 },
        Life = { 0.5, 0.9 },
        Speed = { { -12, 12 }, { 30, 60 } },
        Sway = { 3, 3 },
        Alpha = 0.9,
    }
end

-- burning away from the bottom up in licks of fel fire, glowing where it burns
local IMMOLATING = {
    Frames = "immolate",
    Count = 12,
    Edge = { File = "immolate_edge1", Color = "Accent", Alpha = 1, BlendMode = "ADD" },
}
-- fades in while the tattoos light up, fades out leaving a few glowing
local TATTOOS_IN = { Burst = tattooBurst(6, { 0.8, 1.3 }) }
local TATTOOS_OUT = { Ghost = { File = "panel", Slice = 8, Color = "Body", Fade = { 1, 0 }, Time = 0.45 }, Burst = tattooBurst(5, { 0.6, 1.1 }) }

---the style of spell and big icons: burnt out of the shadow and burning up, pulse for the timeline icons only, big icons
---are already in sight
local iconStyle = function(pulse)
    return {
        -- Fel embers kindle and hop once.
        QueuedMarkers = pulse and {
            Art = { File = "fel_ember", BlendMode = "ADD" }, Colors = { "Accent", "Accent2", "Accent" },
            Size = 16, Spacing = 12, Offset = 5,
            Enter = { Time = 0.25, Stagger = 0.08, Y = -5, Hop = 4 },
        } or false,
        Enter = {
            Ghost = { File = "panel", Slice = 8, Color = "Shadow", Alpha = 0.97, Dissolve = IMMOLATING, Time = 0.45 },
            Burst = rising(4),
        },
        Exit = {
            Ghost = { Source = "Icon", Dissolve = IMMOLATING, Time = 0.5 },
            Burst = rising(7),
        },
        -- a fel tattoo lighting up over it as it passes a tick
        Pulse = pulse and {
            Glow = { Color = "Accent", Alpha = 0.35 },
            Scale = false,
            Flare = { File = "tattoo1", Color = "Accent", Alpha = 0.55, BlendMode = "ADD", Size = { 0.9, 1.05 }, Time = 0.5 },
        } or false,
        Text = {
            Font = { Media = false, Object = "GameFontHighlight", Flags = { OUTLINE = true }, Color = "Text", Shadow = true },
            Background = { Show = false, Media = false, File = "pill", Slice = 8, Color = "Body", Alpha = 0.75, Offset = { x = 8, y = 4 } },
        },
    }
end

private.RegisterTheme({
    Name = "DemonHunterHavoc",
    DisplayName = "Havoc Demon Hunter",
    Description = private.getLocalisation("ThemeDemonHunterHavocDescription"),
    Class = "DEMONHUNTER",
    Spec = 1,
    Effects = true,
    Palette = {
        Body = { 0.045, 0.05, 0.03, 0.96 },
        Card = { 0.55, 1, 0.15, 0.05 },
        Field = { 0.08, 0.09, 0.05, 1 },
        FieldHover = { 0.11, 0.13, 0.07, 1 },
        FieldPressed = { 0.06, 0.07, 0.04, 1 },
        Track = { 0.17, 0.25, 0.08, 1 },
        Edge = { 0.55, 1, 0.15, 0.3 },
        Line = { 1, 0.9, 0.3, 0.45 },
        Accent = { 0.55, 1, 0.15, 1 },
        Accent2 = { 1, 0.9, 0.3, 1 },
        Highlight = { 0.55, 1, 0.15, 0.15 },
        Text = { 0.96, 1, 0.9, 1 },
        Muted = { 0.66, 0.74, 0.54, 1 },
        Danger = { 1, 0.45, 0.5, 1 },
        Wash = { 0.55, 1, 0.15, 0.12 },
        FooterFill = { 0.01, 0.02, 0, 0.3 },
        Shadow = { 0.01, 0.02, 0, 0.9 },
    },
    Fonts = {
        Title = { Size = 18 },
        Heading = { Color = "Accent2" },
        CardTitle = { Size = 15 },
    },
    Motion = {
        Time = { Open = 0.25, Enter = 0.35 },
    },
    Windows = {
        Window = { WashHeight = 200, Sparkles = tattoos(0.6, 3), Enter = TATTOOS_IN, Exit = TATTOOS_OUT },
        Dialog = { WashHeight = 200, Sparkles = tattoos(0.45, 2), Enter = TATTOOS_IN, Exit = TATTOOS_OUT },
    },
    Elements = {
        Timeline = {
            Backdrop = { Background = "None", Border = "None" },
            Background = { File = "panel", Slice = 8, Color = "Body" },
            Edge = { File = "panel_edge", Slice = 8, Color = "Accent", Alpha = 0.4 },
            -- a calm bar, now and then a fel tattoo glowing up on it
            Now = false,
            Wash = { Color = "Accent", Alpha = 0.12 },
            Sparkles = tattoos(0.45, 2),
            Enter = TATTOOS_IN,
            Exit = TATTOOS_OUT,
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
            Enter = { Burst = rising(5) },
            Exit = { Burst = rising(8) },
        },
    },
})
