local appName, app = ...
---@class AbilityTimeline
local private = app

-- the original timeline of Ability Timeline with modern windows and controls in a neutral palette and no
-- ambient effects, every other theme inherits what it does not set from here
local FONT = "Friz Quadrata TT"
local WHITE = { r = 1, g = 1, b = 1, a = 1 }

---a text role in the client's font for the locale
local role = function(size, color, shadow)
    return { Object = "GameFontHighlight", Size = size, Color = color, Shadow = shadow or false }
end

local WINDOW = {
    Fill = "Body",
    Edge = "Edge",
    Wash = "Wash",
    WashHeight = 120,
    HeaderLine = "Line",
    HeaderHeight = 34,
    Footer = "FooterFill",
    Sparkles = false,
}

-- dispel and boss mod borders: File (a plain color without one), BlendMode, Alpha and a Glow behind the icon
local BORDER = { File = false, BlendMode = "BLEND", Alpha = 1, Glow = false }

private.RegisterTheme({
    Name = "Classic",
    DisplayName = "Classic",
    Description = private.getLocalisation("ThemeClassicDescription"),
    Effects = false,
    -- colors every other part of the theme names
    Palette = {
        Body = { 0.07, 0.07, 0.08, 0.96 },
        Card = { 1, 1, 1, 0.04 },
        Field = { 0.14, 0.14, 0.16, 1 },
        FieldHover = { 0.18, 0.18, 0.21, 1 },
        FieldPressed = { 0.11, 0.11, 0.12, 1 },
        Track = { 0.24, 0.24, 0.27, 1 },
        Edge = { 1, 1, 1, 0.12 },
        Line = { 1, 0.82, 0, 0.3 },
        Accent = { 1, 0.82, 0, 1 },
        Accent2 = { 0.85, 0.85, 0.9, 1 },
        Highlight = { 1, 1, 1, 0.08 },
        Text = { 0.95, 0.95, 0.95, 1 },
        Muted = { 0.62, 0.62, 0.66, 1 },
        Danger = { 1, 0.4, 0.4, 1 },
        Wash = { 1, 0.82, 0, 0.05 },
        FooterFill = { 0, 0, 0, 0.25 },
        Shadow = { 0, 0, 0, 0.7 },
        White = WHITE,
        Black = { 0, 0, 0, 1 },
        -- dispel borders and names
        DispelEnrage = private.dispellTypeList[1].color,
        DispelBleed = private.dispellTypeList[2].color,
        DispelMagic = private.dispellTypeList[3].color,
        DispelDisease = private.dispellTypeList[4].color,
        DispelCurse = private.dispellTypeList[5].color,
        DispelPoison = private.dispellTypeList[6].color,
    },
    -- text roles of windows and controls
    Fonts = {
        Title = role(16, "Text", true),
        DialogTitle = role(16, "Text", true),
        Footer = role(11, "Muted"),
        Heading = role(13, "Accent"),
        Label = role(12, "Muted"),
        Control = role(12, "Text"),
        Muted = role(11, "Muted"),
        Button = role(12, "Text"),
        ButtonPrimary = role(12, "Black"),
        ButtonDanger = role(12, "Danger"),
        Tab = role(12, "Muted"),
        TabSelected = role(12, "Text"),
        CardTitle = role(14, "Text", true),
        CardText = role(11, "Muted"),
        MenuItem = role(12, "Text"),
    },
    -- animation times in seconds and their eases (Util/Tween.lua)
    Motion = {
        Time = { Hover = 0.15, Open = 0.2, Toggle = 0.18, Select = 0.2, Enter = 0.3, Exit = 0.25 },
        Ease = { Hover = "outCubic", Open = "outCubic", Toggle = "outCubic", Select = "outCubic" },
    },
    Windows = {
        Window = WINDOW,
        Dialog = WINDOW,
    },
    Elements = {
        Timeline = {
            Backdrop = {
                Background = "Blizzard Dialog Background",
                Border = "None",
                EdgeSize = 2,
                Color = WHITE,
                BorderColor = WHITE,
            },
            Background = false,
        },
        Tick = {
            Line = { Color = WHITE, Thickness = 1 },
            Text = {
                Font = { Object = "SystemFont_Shadow_Med3" },
                Offset = { x = 5, y = 0 },
            },
        },
        Cooldown = {
            Font = { Media = FONT, Size = 24, Flags = { OUTLINE = true }, Color = WHITE, Shadow = true },
        },
        SpellIcon = {
            Size = 44,
            Zoom = 0.3,
            BorderWidth = 3,
            Mask = false,
            Overlay = false,
            MergeSeparator = { Color = { r = 0, g = 0, b = 0, a = 1 }, Width = 1 },
            -- a golden beat as it passes a tick, like the proc glow it replaces
            Pulse = { Glow = { Color = { 1, 0.85, 0.4, 1 }, Alpha = 0.7 }, Scale = 1.1 },
            Border = BORDER,
            Text = {
                Anchor = "LEFT",
                Offset = { x = 16, y = 0 },
                Font = { Media = FONT, Size = 14, Flags = { OUTLINE = true }, Color = WHITE, Shadow = true },
                Background = { Show = false, Media = "Blizzard Dialog Background", Offset = { x = 10, y = 10 } },
            },
            RoleIcons = { Size = 16, Anchor = "RIGHT", Offset = { x = 18, y = 0 } },
            DispelIcon = { Size = 16, Anchor = "BOTTOMRIGHT", Offset = { x = -3, y = 3 } },
        },
        BigIcon = {
            Size = 100,
            Zoom = 0.3,
            BorderWidth = 3,
            Mask = false,
            Overlay = false,
            Border = BORDER,
            Text = {
                Anchor = "BOTTOM",
                Offset = { x = 0, y = 10 },
                Font = { Media = FONT, Size = 20, Flags = { OUTLINE = true }, Color = WHITE, Shadow = true },
                Background = { Show = false, Media = "Blizzard Dialog Background", Offset = { x = 0, y = 0 } },
            },
            RoleIcons = { Size = 16, Anchor = "TOP", Offset = { x = 0, y = 18 } },
            DispelIcon = { Size = 16, Anchor = "BOTTOMRIGHT", Offset = { x = -3, y = 3 } },
        },
        TextHighlight = {
            Text = {
                Font = { Media = FONT, Size = 14, Flags = { OUTLINE = true }, Color = WHITE, Shadow = true },
                Background = { Show = false, Media = "Blizzard Dialog Background", Offset = { x = 0, y = 0 } },
            },
        },
    },
})
