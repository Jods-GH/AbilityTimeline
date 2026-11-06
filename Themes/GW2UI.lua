local appName, app = ...
---@class AbilityTimeline
local private = app
local SharedMedia = LibStub("LibSharedMedia-3.0")

-- Refinement picks B5 E3 P1 X2 W3, 2026-11-06.
private.RegisterThemeTextures("GW2UI", {}, { "gw2_brush", "gw2_ink" })
local ART = "Interface\\AddOns\\GW2_UI\\Textures\\"
SharedMedia:Register("background", private.MediaName("gw2_panel"), ART .. "uistuff\\settingspanelbg.png")
SharedMedia:Register("background", private.MediaName("gw2_header"), ART .. "bag\\bagheader.png")
for name, path in pairs({
    gw2_world = "character\\worldmap-background.png",
    gw2_menu = "character\\menu-hover.png",
    gw2_checkbox = "uistuff\\checkbox.png",
    gw2_checked = "uistuff\\checkboxchecked.png",
    gw2_slider = "uistuff\\sliderhandle.png",
    gw2_track = "uistuff\\sliderbg.png",
    gw2_settings_icon = "character\\settings-window-icon.png",
    gw2_white = "uistuff\\white.png",
    gw2_border = "addonSkins\\border.png",
    gw2_button = "uistuff\\button.png",
}) do
    SharedMedia:Register("background", private.MediaName(name), ART .. path)
end

local providerColor = function(group, key, fallback)
    return function()
        local GW = GW2_ADDON
        local colors = GW and GW.Colors
        local color = colors and (group and colors[group] or colors)
        color = color and color[key]
        if not color then return fallback end
        return { color:GetRGBA() }
    end
end

local dissolve = function(frames)
    return { Frames = frames, Count = 12,
        Edge = { File = frames .. "_edge1", Color = "Accent2", Alpha = 0.12 } }
end
local BRUSH_IN = {
    Ghost = { Color = "Body", Dissolve = dissolve("gw2_brush"), Time = 0.24 },
}
local WINDOW_IN = {
    Ghost = { Color = "Body", Dissolve = dissolve("gw2_ink"), Time = "$GWWindowTime" },
}
local WINDOW_OUT = {
    Ghost = { File = "gw2_world", Color = "White", Fade = { 1, 0 }, Time = "$GWWindowTime" },
}
local WINDOW = {
    Fill = "Body", Edge = { 0, 0, 0, 0 }, Wash = { 0, 0, 0, 0 }, HeaderLine = { 0, 0, 0, 0 },
    Grain = { File = "gw2_world", Color = "White", Alpha = 1 },
    HeaderArt = { File = "gw2_header", Color = "White", Height = 40 },
    ShowScale = 1, FadeOut = "$GWWindowTime",
    Decor = { { File = "gw2_settings_icon", Color = "White", Point = "TOPLEFT", X = -12, Y = 10, Size = { 64, 64 } } },
    Footer = "FooterFill", Enter = WINDOW_IN, Exit = WINDOW_OUT,
}

local fonts = {}
for role in pairs(private.Themes.Classic.Fonts) do
    fonts[role] = { Path = "$GWFont", Shadow = false, Flags = {} }
end
for _, role in ipairs({ "Title", "DialogTitle", "Heading", "CardTitle" }) do
    fonts[role].Path = "$GWHeaderFont"
    fonts[role].Color = "Accent2"
end
fonts.ButtonPrimary.Color = "Black"
fonts.Button.Color = "Black"
fonts.Tab.Color = "Accent2"
fonts.Control.Size = 13
fonts.Title.Size = 20

local iconStyle = function(pulse)
    return {
        Enter = BRUSH_IN,
        Exit = { Ghost = { Source = "Icon", Fade = { 1, 0 }, Time = 0.3 } },
        Pulse = pulse and {
            Glow = false,
            Ghost = { Color = "Accent2", Alpha = 0.1, Fade = { 1, 0 }, Time = 0.14 },
        } or false,
        Text = { Font = { Media = false, Path = "$GWFont" } },
    }
end

private.RegisterTheme({
    Name = "GW2UI",
    Addon = "GW2_UI",
    DisplayName = "GW2 UI",
    Description = private.getLocalisation("ThemeGW2UIDescription"),
    Available = function()
        local GW = GW2_ADDON
        return GW and GW.settings and GW.Colors and GW.Colors.Accent
    end,
    Effects = true,
    Variables = {
        GWAccent = providerColor(nil, "Accent", { 120 / 255, 70 / 255, 180 / 255, 1 }),
        GWHeader = providerColor("TextColors", "LightHeader", { 1, 0.945, 0.8196, 1 }),
        -- GW.LoadFonts resolves custom media and locale fallbacks into these globals.
        GWFont = function() return STANDARD_TEXT_FONT end,
        GWHeaderFont = function() return DAMAGE_TEXT_FONT or STANDARD_TEXT_FONT end,
        GWWindowTime = function()
            return GW2_ADDON and GW2_ADDON.WINDOW_FADE_DURATION or 0.2
        end,
    },
    Palette = {
        Body = { 0.11, 0.055, 0.055, 1 },
        Accent = "$GWAccent", Accent2 = "$GWHeader",
        Line = { 1, 0.945, 0.8196, 0.25 },
        Field = { 0, 0, 0, 0.45 }, FieldHover = { 0.12, 0.1, 0.08, 0.65 },
        FieldPressed = { 0.09, 0.045, 0.045, 1 }, Track = { 1, 1, 1, 0.12 },
        Muted = { 0.75, 0.75, 0.75, 1 }, Text = { 1, 1, 1, 1 },
        Card = { 0, 0, 0, 0.35 }, Edge = { 0, 0, 0, 1 },
        FooterFill = { 0, 0, 0, 0.35 }, Wash = { 0, 0, 0, 0 },
    },
    Controls = {
        Panel = { Fill = "gw2_white", Edge = "gw2_border", Slice = 4 },
        CheckBox = { Box = "gw2_checkbox", Check = "gw2_checked", Size = 20 },
        Slider = { Thumb = "gw2_slider", Track = "gw2_track", Size = 16, Height = 12, Color = "Accent2", Fill = false },
        Button = { File = "gw2_button", Fill = "White", Edge = "Black" },
        Navigation = { File = "gw2_menu", Color = "Accent2" },
    },
    Motion = { Time = { Open = "$GWWindowTime" } },
    Fonts = fonts,
    Windows = { Window = WINDOW, Dialog = WINDOW },
    Elements = {
        Timeline = {
            Backdrop = {
                Background = false, Border = "None", BgFile = "Interface\\Buttons\\WHITE8X8",
                Color = "Body", BorderColor = { 0, 0, 0, 0 },
            },
            Background = { File = "gw2_panel", Color = "White", Alpha = 0.58 },
            Header = { File = "gw2_header", Color = "White", Height = 18 },
            Enter = WINDOW_IN, Exit = WINDOW_OUT,
        },
        Tick = {
            Line = { Color = "Accent", Alpha = 0.25 },
            Text = { Font = { Path = "$GWFont", Size = 11, Color = "Muted", Flags = { OUTLINE = true } } },
        },
        Cooldown = { Font = { Media = false, Path = "$GWFont" } },
        SpellIcon = iconStyle(true),
        BigIcon = iconStyle(false),
        TextHighlight = { Text = { Font = { Media = false, Path = "$GWFont" } } },
    },
})

local GW = GW2_ADDON
if GW and GW.LoadFonts then
    local pending = false
    hooksecurefunc(GW, "LoadFonts", function()
        if pending or not private.db then return end
        pending = true
        C_Timer.After(0, function()
            pending = false
            if private.GetCurrentThemeKey() == "GW2UI" or
                (private.isThemePageShown and private.isThemePageShown()) then
                private.RefreshTheme()
            end
        end)
    end)
end
