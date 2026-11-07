local appName, app = ...
---@class AbilityTimeline
local private = app
local ThemeApply = private.ThemeApply

private.RegisterThemeTextures("Blizzard", {
    "blizzard_timeline", "blizzard_cooldown", "blizzard_icon_mask", "blizzard_break_mask", "blizzard_highlight_mask", "blizzard_ej_icons",
    "blizzard_border",
})

local ATLAS_ART = {
    ["ui-hud-cooldownmanager-iconoverlay"] = { File = "blizzard_cooldown", Coords = { 0.00390625, 0.33984375, 0.0078125, 0.6796875 } },
    ["ui-hud-cooldownmanager-mask"] = { File = "blizzard_icon_mask" },
    ["combattimeline-cooldown-divider"] = { File = "blizzard_timeline", Coords = { 0.0009765625, 0.0556640625, 0.751953125, 0.796875 } },
    ["combattimeline-fx-highlight"] = { File = "blizzard_timeline", Coords = { 0.337890625, 0.421875, 0.05859375, 0.142578125 } },
    ["combattimeline-fx-highlight-fx"] = { File = "blizzard_timeline", Coords = { 0.05859375, 0.1640625, 0.05859375, 0.1640625 } },
    ["combattimeline-fx-highlight-mask"] = { File = "blizzard_highlight_mask" },
    ["combattimeline-fx-pause"] = { File = "blizzard_timeline", Coords = { 0.423828125, 0.5078125, 0.05859375, 0.142578125 } },
    ["combattimeline-fx-pause-icon"] = { File = "blizzard_timeline", Coords = { 0.0009765625, 0.0244140625, 0.798828125, 0.82421875 } },
    ["combattimeline-fx-queued"] = { File = "blizzard_timeline", Coords = { 0.509765625, 0.59375, 0.05859375, 0.142578125 } },
    ["combattimeline-fx-queued-icon"] = { File = "blizzard_timeline", Coords = { 0.6943359375, 0.7109375, 0.0322265625, 0.048828125 } },
    ["combattimeline-line-break-mask"] = { File = "blizzard_break_mask" },
    ["combattimeline-line-icontrail"] = { File = "blizzard_timeline", Coords = { 0.884765625, 0.916015625, 0.0009765625, 0.0029296875 } },
    ["combattimeline-line-left"] = { File = "blizzard_timeline", Coords = { 0.6943359375, 0.8828125, 0.0009765625, 0.0146484375 } },
    ["combattimeline-line-right"] = { File = "blizzard_timeline", Coords = { 0.6943359375, 0.8828125, 0.0166015625, 0.0302734375 } },
    ["combattimeline-line-shadow"] = { File = "blizzard_timeline", Coords = { 0.0009765625, 0.6923828125, 0.0009765625, 0.056640625 } },
    ["combattimeline-line-shadow-vertical"] = { File = "blizzard_timeline", Coords = { 0.0009765625, 0.056640625, 0.05859375, 0.75 } },
    ["combattimeline-pip"] = { File = "blizzard_timeline", Coords = { 0.712890625, 0.728515625, 0.0322265625, 0.0478515625 } },
}

local component = function(atlas, extra)
    local spec = extra or {}
    local art = ATLAS_ART[atlas:lower()]
    spec.Atlas, spec.File, spec.Coords = atlas, art.File, art.Coords
    return spec
end

local MASK = component("UI-HUD-CoolDownManager-Mask")
local OVERLAY = component("UI-HUD-CoolDownManager-IconOverlay", {
    ReferenceSize = 35,
    Offsets = { left = -7, top = 6, right = 7, bottom = -7 },
})
local STATES = {
    ReferenceSize = 35,
    Paused = component("combattimeline-fx-pause"),
    PausedIcon = component("combattimeline-fx-pause-icon"),
    Queued = component("combattimeline-fx-queued"),
    QueuedIcon = component("combattimeline-fx-queued-icon"),
}
local HIGHLIGHT = component("combattimeline-fx-highlight", {
    ReferenceSize = 35,
    Fade = { 1, 0 }, Time = 0.2,
    Offsets = { left = -8, top = 7, right = 8, bottom = -8 },
})
local TIMELINE_MOTION = {
    SlideTime = 0.35, SlideDistance = 25,
    Pulse = { Grow = 1.1, Shrink = 0.9, Time = 0.2, Delay = 0.6 },
    Highlight = {
        Glow = HIGHLIGHT,
        Swirl = component("combattimeline-fx-highlight-fx", { BlendMode = "ADD" }),
        Mask = component("combattimeline-fx-highlight-mask"),
    },
    QueuedDot = component("combattimeline-fx-queued-icon"),
}

local icon = function(pulse)
    return {
        Zoom = 0, Mask = MASK, Overlay = OVERLAY, StateArt = STATES,
        Border = { File = "blizzard_border", Alpha = 1, Glow = false },
        Enter = { Ease = "linear" },
        Exit = { Ghost = { Source = "Icon", Mask = MASK, Fade = { 1, 0 }, Time = 0.2 } },
        Pulse = false,
        TimelineMotion = pulse and TIMELINE_MOTION or false,
        Text = { Font = { Media = false, Object = "SystemFont_Shadow_Med3", Flags = {} } },
    }
end
local spellIcon = icon(true)
spellIcon.Size = 35
spellIcon.DispelIcon = { Size = 12 }
spellIcon.Trail = component("combattimeline-line-icontrail", { BlendMode = "ADD" })
spellIcon.Exit = {
    Finished = { Ghost = {
        Source = "Icon", Mask = MASK, Fade = { 1, 0 }, Time = 0.2,
        Scale = { 1, 1.35 }, NativeScale = true, Overlay = OVERLAY, Labels = true,
        Flash = HIGHLIGHT, FlashAlpha = 1, FlashMask = false,
    } },
    Canceled = { Ghost = {
        Source = "Icon", Mask = MASK, Fade = { 1, 0 }, Time = 0.2, Overlay = OVERLAY, Labels = true,
        CrossAxis = { Distance = 25, Time = 0.35 },
    } },
}

private.RegisterTheme({
    Name = "Blizzard",
    DisplayName = private.getLocalisation("ThemeBlizzard"),
    Description = private.getLocalisation("ThemeBlizzardDescription"),
    Effects = true,
    Motion = { Time = { Enter = 0.2, Exit = 0.2 } },
    Elements = {
        Timeline = {
            Backdrop = { Background = false, Border = false }, Background = false,
            Track = {
                Start = component("combattimeline-line-left"),
                End = component("combattimeline-line-right"),
                Divider = component("combattimeline-cooldown-divider"),
                DividerWidth = 56, DividerHeight = 46, DividerOffset = -22,
                BreakMask = component("combattimeline-line-break-mask", { WrapMode = "CLAMP" }),
                Shadow = component("combattimeline-line-shadow", { Alpha = 0 }),
                ShadowVertical = component("combattimeline-line-shadow-vertical", { Alpha = 0 }),
                Pip = component("combattimeline-pip"),
                Thickness = 14, ShadowThickness = 57, PipSize = 16, PipTime = 5, PipText = true,
                PipFont = { Object = "SystemFont_Shadow_Large" },
            },
        },
        Tick = {
            Line = { Alpha = 0, Thickness = 1 },
            Text = { Show = false, Font = { Object = "SystemFont_Shadow_Med3", Flags = {} } },
        },
        Cooldown = { Font = { Media = false, Object = "SystemFont_Shadow_Med3", Size = 16 } },
        SpellIcon = spellIcon,
        BigIcon = icon(false),
    },
})
