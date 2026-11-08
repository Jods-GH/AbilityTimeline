local appName, app = ...
---@class AbilityTimeline
local private = app
local SharedMedia = LibStub("LibSharedMedia-3.0")
SharedMedia:Register(private.ThemeMediaType, private.MediaName("eui_stock_checkbox"), "Interface\\Buttons\\UI-CheckBox-Up")
SharedMedia:Register(private.ThemeMediaType, private.MediaName("eui_stock_checked"), "Interface\\Buttons\\UI-CheckBox-Check")

local provider = function()
    return not EUI_CLIENT_BLOCKED and EllesmereUI
end

-- Apply to All records the profile's window look separately from its accent theme.
-- Do not infer it from an arbitrary module: users can mix module styles.
local look = function()
    local E = provider()
    local profile = E and E.GetActiveProfileData and E.GetActiveProfileData()
    local key = profile and profile.windowSkinLook
    if not key then
        local slots = EllesmereUIDB and EllesmereUIDB.fonts and EllesmereUIDB.fonts._styleSlots
        key = slots and slots.active
    end
    if key == "forever" then return E and E.IS_FOREVER and key or "blizzard" end
    if key == "classic" or key == "blizzard" then return key end
    return "eui"
end

local backdrop = function(window)
    local key = look()
    local stock = key ~= "eui"
    local edge = "Interface\\Buttons\\WHITE8X8"
    if key == "forever" then
        edge = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border"
    elseif key == "classic" then
        edge = "Interface\\DialogFrame\\UI-DialogBox-Border"
    elseif key == "blizzard" then
        edge = "Interface\\Tooltips\\UI-Tooltip-Border"
    end
    local inset = stock and (window and 8 or 3) or 1
    return {
        Background = false, Border = false,
        BgFile = key == "classic" and "Interface\\DialogFrame\\UI-DialogBox-Background"
            or "Interface\\Buttons\\WHITE8X8",
        EdgeFile = edge, EdgeSize = stock and (window and 24 or 12) or 1,
        Insets = { left = inset, right = inset, top = inset, bottom = inset },
        Color = key == "classic" and { 1, 1, 1, 0.97 } or "Body",
        BorderColor = stock and { 1, 1, 1, 1 } or "Edge",
    }
end

local color = function(prefix, fallback)
    return function()
        local E = provider()
        if not E then return fallback end
        return { E[prefix .. "_R"] or fallback[1], E[prefix .. "_G"] or fallback[2],
            E[prefix .. "_B"] or fallback[3], E[prefix .. "_A"] or fallback[4] }
    end
end

local accent = function()
    local E = provider()
    if E and E.GetAccentColor then
        local r, g, b = E.GetAccentColor()
        return { r, g, b, 1 }
    end
    return { 0.047, 0.824, 0.624, 1 }
end

local FADE_IN = { Ghost = { Color = "Body", Alpha = 1, Fade = { 1, 0 }, Time = 0.18 } }
local FADE_OUT = { Ghost = { Color = "Body", Fade = { 1, 0 }, Time = 0.18 } }
local WINDOW = {
    Fill = "Body", Edge = "Edge", Wash = { 0, 0, 0, 0 }, HeaderLine = "Accent",
    Footer = "FooterFill", Enter = FADE_IN, Exit = FADE_OUT,
    Backdrop = "$EuiWindowBackdrop",
    HeaderHeight = "$EuiHeaderHeight",
}

local fonts = {}
for role in pairs(private.Themes.Classic.Fonts) do
    fonts[role] = { Path = "$EuiFont", Shadow = false, Flags = {} }
end
fonts.ButtonPrimary.Color = "$EuiButtonText"

local iconStyle = function(pulse)
    return {
        -- Small accent beads with the same restrained fade as its icons.
        QueuedMarkers = pulse and {
            Art = { File = "circle" }, Colors = { "Accent", "Accent", "Accent" },
            Size = 10, Spacing = 12, Offset = 5,
            Enter = { Time = 0.18, Stagger = 0.05 },
        } or false,
        Enter = FADE_IN,
        Exit = { Ghost = { Source = "Icon", Fade = { 1, 0 }, Time = 0.18 } },
        Pulse = pulse and {
            Glow = false,
            Ghost = { Color = "Accent", Alpha = 0.12, Fade = { 1, 0 }, Time = 0.15 },
        } or false,
        Text = { Font = { Media = false, Path = "$EuiFont" } },
    }
end

private.RegisterTheme({
    Name = "EllesmereUI",
    Addon = "EllesmereUI",
    DisplayName = "EllesmereUI",
    Description = private.getLocalisation("ThemeEllesmereUIDescription"),
    Available = function()
        local E = provider()
        return E and E.GetAccentColor and E.GetFontPath
    end,
    Effects = true,
    Variables = {
        EuiHeaderHeight = function() return look() == "eui" and 34 or 42 end,
        EuiControls = function()
            if look() == "eui" then return {} end
            return { CheckBox = { Box = "eui_stock_checkbox", Check = "eui_stock_checked", Size = 24 } }
        end,
        EuiWindowBackdrop = function() return backdrop(true) end,
        EuiTimelineBackdrop = function() return backdrop(false) end,
        EuiAccent = accent,
        EuiText = color("TEXT_WHITE", { 1, 1, 1, 1 }),
        EuiMuted = color("TEXT_DIM", { 1, 1, 1, 0.5 }),
        EuiField = color("DD_BG", { 0.1, 0.1, 0.1, 0.8 }),
        EuiTrack = color("SL_TRACK", { 1, 1, 1, 0.1 }),
        EuiButtonText = function()
            local c = accent()
            return c[1] * 0.299 + c[2] * 0.587 + c[3] * 0.114 > 0.5
                and { 0, 0, 0, 1 } or { 1, 1, 1, 1 }
        end,
        EuiFont = function()
            local E = provider()
            return E and E.GetFontPath and E.GetFontPath() or STANDARD_TEXT_FONT
        end,
    },
    Palette = {
        Body = { 0.067, 0.067, 0.067, 0.97 },
        Edge = { 1, 1, 1, 0.18 }, Line = "$EuiAccent",
        Accent = "$EuiAccent", Accent2 = "$EuiAccent",
        Text = "$EuiText", Muted = "$EuiMuted",
        Field = "$EuiField", Track = "$EuiTrack",
        FieldHover = { 1, 1, 1, 0.1 }, FieldPressed = { 0, 0, 0, 0.3 },
        FooterFill = { 0, 0, 0, 0.25 }, Wash = { 0, 0, 0, 0 },
    },
    Fonts = fonts,
    Controls = "$EuiControls",
    Windows = { Window = WINDOW, Dialog = WINDOW },
    Elements = {
        Timeline = {
            Backdrop = "$EuiTimelineBackdrop",
            Background = false, Enter = FADE_IN, Exit = FADE_OUT,
        },
        Tick = {
            Line = { Color = "Muted", Alpha = 0.25 },
            Text = { Font = { Path = "$EuiFont", Size = 11, Color = "Muted", Flags = { OUTLINE = true } } },
        },
        Cooldown = { Font = { Media = false, Path = "$EuiFont" } },
        SpellIcon = iconStyle(true),
        BigIcon = iconStyle(false),
        TextHighlight = { Text = { Font = { Media = false, Path = "$EuiFont" } } },
    },
})

local E = provider()
if E then
    local pending = false
    local refresh = function()
        if pending or not private.db then return end
        pending = true
        C_Timer.After(0, function()
            pending = false
            if private.GetCurrentThemeKey() == "EllesmereUI" or
                (private.isThemePageShown and private.isThemePageShown()) then
                private.RefreshTheme()
            end
        end)
    end
    for _, method in ipairs({ "RefreshAccent", "SetAccentColor", "ApplyAccentColorLive", "ResetAccentColor", "SetActiveTheme",
        "InvalidateFontCache", "SwapWindowSkinStyle", "ReconcileWindowSkinLook" }) do
        if type(E[method]) == "function" then
            hooksecurefunc(E, method, refresh)
        end
    end
end
