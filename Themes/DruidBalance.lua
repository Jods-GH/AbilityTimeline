local appName, app = ...
---@class AbilityTimeline
local private = app
local ThemeApply = private.ThemeApply
local behavior = {}

local stepBeam = function(host, beam, progress)
    local width, height = host:GetWidth(), host:GetHeight()
    local above = height * (beam.Height or 2.4)
    local reach = 1 - (1 - math.min(progress / 0.35, 1)) ^ 3
    local fading = math.max((progress - 0.35) / 0.65, 0)
    host.Beam:SetPoint("TOP", host, "TOP", 0, above)
    host.Beam:SetSize(math.max(width * (beam.Width or 0.6) * (1 - fading * 0.6), 0.01),
        math.max((above + height / 2) * reach + height * 0.15, 0.01))
    host.Beam:SetAlpha(progress < 0.35 and math.min(progress / 0.12, 1) or 1 - fading)
end

behavior.GetEffectSpec = function(spec)
    return spec.Beam
end

behavior.SetupEffect = function(host, spec)
    if not host.Beam then host.Beam = host:CreateTexture(nil, "OVERLAY", nil, 5) end
    host.Beam:SetShown(ThemeApply.Texture(host.Beam, spec))
end

behavior.StepEffect = stepBeam

behavior.ResetEffect = function(host)
    if host.Beam then host.Beam:Hide() end
end

ThemeApply.RegisterBehavior("DruidBalance", behavior)

private.RegisterThemeTextures("DruidBalance", { "corona", "moonbeam", "shooting_star", "twinkle" }, { "eclipse" })

-- the night sky with lunar silver and solar gold: still stars and shooting stars over the timeline, icons appear as
-- shooting stars land on them and leave in an eclipse, windows fade in as the stars come out
local TWINKLE = private.ThemeApply.File("twinkle")
local SHOOTING_STAR = private.ThemeApply.File("shooting_star")
local SKY = { "Accent", "Accent", "White", "Accent2" }

---stars lighting up in place anywhere over the frame, twinkling and fading
local stars = function(rate, max)
    return { Texture = TWINKLE, Colors = SKY, Area = "All", Rate = rate, Max = max, Size = { 4, 9 }, Life = { 2.5, 4.5 },
        Speed = { { 0, 0 }, { 0, 0 } }, Alpha = 0.75 }
end

---now and then a shooting star streaking across
local shootingStars = {
    Texture = SHOOTING_STAR,
    Colors = { "Accent", "Accent", "Accent2" },
    Area = "All",
    Rate = 0.45,
    Max = 2,
    Size = { 30, 42 },
    Life = { 0.6, 0.9 },
    Speed = { { -170, -120 }, { -45, -25 } },
    Alpha = 0.95,
    Align = true,
}

---stars lighting up in place at once
local burst = function(count, life)
    return { Texture = TWINKLE, Colors = SKY, Count = count, Size = { 5, 9 }, Life = life or { 0.7, 1.3 },
        Speed = { { 0, 0 }, { 0, 0 } }, Alpha = 1 }
end

-- fades in while the stars come out
local NIGHTFALL = { Burst = burst(14, { 0.8, 1.5 }) }
local NIGHT_ENDS = { Ghost = { File = "panel", Slice = 8, Color = "Body", Fade = { 1, 0 }, Time = 0.5 }, Burst = burst(12, { 0.6, 1.2 }) }

---the style of spell and big icons: shooting stars landing on it, leaving in an eclipse, pulse for the timeline icons
---only, big icons are already in sight
local iconStyle = function(pulse)
    return {
        -- shooting stars streak in from the upper right and land on it
        Enter = {
            Scale = 0.92,
            Vortex = { Texture = SHOOTING_STAR, Colors = { "Accent", "Accent", "Accent2" }, Count = 4, Radius = 1.6,
                Angle = { 28, 62 }, Turns = 0, Align = true, Size = { 42, 54 }, Time = 0.42 },
        },
        -- the moon slides over it, the sun's corona flares round the last crescent
        Exit = {
            Ghost = { Source = "Icon", Time = 0.45,
                Dissolve = { Frames = "eclipse", Count = 12, Edge = { File = "eclipse_edge1", Color = "Accent2", Alpha = 0.6, BlendMode = "ADD" } } },
            Flare = { File = "corona", Color = "Accent2", Alpha = 0.5, BlendMode = "ADD", Size = { 0.95, 1.2 }, Time = 0.6 },
        },
        -- a beam of Moonfire coming down onto it as it passes a tick
        Pulse = pulse and {
            Behavior = "DruidBalance",
            Glow = { Color = "Accent", Alpha = 0.4 },
            Scale = false,
            Beam = { Behavior = "DruidBalance", File = "moonbeam", Color = "Accent", Alpha = 0.6, BlendMode = "ADD", Width = 0.5, Time = 0.45 },
        } or false,
        Text = {
            Font = { Media = false, Object = "GameFontHighlight", Flags = { OUTLINE = true }, Color = "Text", Shadow = true },
            Background = { Show = false, Media = false, File = "pill", Slice = 8, Color = "Body", Alpha = 0.75, Offset = { x = 8, y = 4 } },
        },
    }
end

private.RegisterTheme({
    Name = "DruidBalance",
    DisplayName = "Balance Druid",
    Description = private.getLocalisation("ThemeDruidBalanceDescription"),
    Class = "DRUID",
    Spec = 1,
    Effects = true,
    Palette = {
        Body = { 0.035, 0.045, 0.1, 0.96 },
        Card = { 0.75, 0.82, 1, 0.05 },
        Field = { 0.06, 0.08, 0.16, 1 },
        FieldHover = { 0.08, 0.11, 0.22, 1 },
        FieldPressed = { 0.05, 0.06, 0.12, 1 },
        Track = { 0.14, 0.18, 0.34, 1 },
        Edge = { 0.75, 0.82, 1, 0.3 },
        Line = { 1, 0.78, 0.35, 0.45 },
        Accent = { 0.75, 0.82, 1, 1 },
        Accent2 = { 1, 0.78, 0.35, 1 },
        Highlight = { 0.75, 0.82, 1, 0.15 },
        Text = { 0.95, 0.96, 1, 1 },
        Muted = { 0.6, 0.64, 0.8, 1 },
        Danger = { 1, 0.45, 0.5, 1 },
        Wash = { 0.75, 0.82, 1, 0.1 },
        FooterFill = { 0, 0.01, 0.04, 0.3 },
        Shadow = { 0, 0.01, 0.04, 0.9 },
    },
    Fonts = {
        Title = { Size = 18 },
        Heading = { Color = "Accent2" },
        CardTitle = { Size = 15 },
    },
    Motion = {
        Time = { Open = 0.3, Enter = 0.4 },
    },
    Windows = {
        Window = { WashHeight = 200, Sparkles = stars(1.2, 10), Enter = NIGHTFALL, Exit = NIGHT_ENDS },
        Dialog = { WashHeight = 200, Sparkles = stars(1, 8), Enter = NIGHTFALL, Exit = NIGHT_ENDS },
    },
    Elements = {
        Timeline = {
            Backdrop = { Background = "None", Border = "None" },
            Background = { File = "panel", Slice = 8, Color = "Body" },
            Edge = { File = "panel_edge", Slice = 8, Color = "Accent", Alpha = 0.35 },
            -- a calm bar, still stars and now and then a shooting star
            Now = false,
            Wash = { Color = "Accent", Alpha = 0.1 },
            Sparkles = { stars(1.4, 9), shootingStars },
            Enter = NIGHTFALL,
            Exit = NIGHT_ENDS,
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
            Enter = { Burst = burst(5) },
            Exit = { Burst = burst(8, { 0.5, 1 }) },
        },
    },
})
