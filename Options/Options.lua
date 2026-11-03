local appName, app = ...
---@class AbilityTimeline
local private = app
local ThemeApply = private.ThemeApply
local ThemedWidgets = private.ThemedWidgets
local L = private.getLocalisation

-- the page in Esc > Options > AddOns: what the addon is, the way into its settings window and where to find it, in
-- the theme. Profiles is a category below it, drawn by AceConfigDialog
local variables = {
    padding = 24,
    gap = 12,
    logoSize = 64,
    buttonHeight = 28,
    buttonWidth = 200,
    linkIcon = 16,
}

-- brand names as their owners spell them, where each logo comes from is in Media/Textures/Brands/BrandLicensing.txt.
-- aspect is a logo's width to its height; on light buttons a logo shows its darkIcon file, or itself drawn black with
-- darkTint, or itself without either
local LINK_GROUPS = {
    {
        name = "SettingsLinksHelp",
        links = {
            -- Discord's brand allows its logo in black, the white file drawn black is that
            {
                name = "Discord",
                url = "https://discord.com/invite/v3gYmYamGJ",
                icon = "Discord_logo",
                darkTint = true,
                aspect = 528 / 400,
            },
            {
                key = "SettingsReportBug",
                url = "https://github.com/Jods-GH/AbilityTimeline/issues",
                icon = "GitHub_logo",
                -- GitHub's mark for light buttons, its brand allows it in white or black only
                darkIcon = "GitHub_logo_black",
                aspect = 294 / 288,
            },
        },
    },
    {
        name = "SettingsLinksDownload",
        links = {
            {
                name = "CurseForge",
                url = "https://www.curseforge.com/wow/addons/better-timeline",
                icon = "CurseForge_logo",
                darkIcon = "CurseForge_logo_black",
                aspect = 202 / 128,
            },
            {
                name = "Wago",
                url = "https://addons.wago.io/addons/better-timeline",
                icon = "Wago_logo",
                darkIcon = "Wago_logo_black",
                aspect = 222 / 128,
            },
        },
    },
    {
        name = "SettingsLinksSupport",
        links = {
            {
                name = "Patreon",
                url = "https://www.patreon.com/c/Jodsderechte",
                icon = "Patreon_logo",
                -- Patreon's own black mark, its brand names no colors and forbids modifying the mark
                darkIcon = "Patreon_logo_black",
                aspect = 117 / 128,
            },
            -- in its own blues on every button
            {
                name = "PayPal",
                url = "https://www.paypal.com/donate/?hosted_button_id=PSQ4D3HXNZKMG",
                icon = "PayPal_logo",
                aspect = 1,
            },
        },
    },
}

---the addon's own windows take the place of Blizzard's settings
local leaveSettingsPanel = function()
    if SettingsPanel and SettingsPanel:IsShown() then
        HideUIPanel(SettingsPanel)
    end
end

---@param parent Frame
---@param text string
---@param style string -- Plain or Primary
---@param width number
---@param onClick function
---@return Button
local createButton = function(parent, text, style, width, onClick)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    ThemedWidgets.SkinButton(button)
    button.atStyle = style
    button:SetSize(width, variables.buttonHeight)
    button:SetText(text)
    button:SetScript("OnClick", onClick)
    return button
end

---creates the page and registers it as the addon's category, returns the name the Profiles category goes below
---@return string
private.RegisterOptionsPage = function()
    local name = L("SettingsTitle")
    local padding, gap = variables.padding, variables.gap
    local frame = CreateFrame("Frame")
    frame.name = name

    local card = CreateFrame("Frame", nil, frame)
    card:SetPoint("TOPLEFT", frame, "TOPLEFT", padding, -padding)
    card:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -padding, -padding)
    -- without a height the card has no place on screen and never learns its width, the layout below sets the real one
    card:SetHeight(1)
    ThemeApply.CreatePanel(card)

    card.Logo = card:CreateTexture(nil, "ARTWORK")
    card.Logo:SetTexture("Interface\\AddOns\\AbilityTimeline\\Media\\Logo.tga")
    card.Logo:SetSize(variables.logoSize, variables.logoSize)
    card.Logo:SetPoint("TOPLEFT", card, "TOPLEFT", padding, -padding)
    card.Title = card:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    card.Title:SetPoint("BOTTOMLEFT", card.Logo, "RIGHT", gap, 2)
    card.Title:SetText(name)
    card.Version = card:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    card.Version:SetPoint("TOPLEFT", card.Logo, "RIGHT", gap, -2)
    card.Version:SetText(L("SettingsVersion"):format(C_AddOns.GetAddOnMetadata(appName, "Version")))
    card.Text = card:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    -- only its top left is anchored, a RIGHT anchor would also pin its middle to the card's and cut it to one line
    card.Text:SetPoint("TOPLEFT", card.Logo, "BOTTOMLEFT", 0, -gap)
    card.Text:SetJustifyH("LEFT")
    card.Text:SetWordWrap(true)
    card.Text:SetSpacing(3)
    card.Text:SetText(L("SettingsLauncherDescription"))

    local open = createButton(card, L("SettingsOpenPage"), "Primary", variables.buttonWidth, function()
        leaveSettingsPanel()
        private.openSettings()
    end)
    open:SetPoint("TOPLEFT", card.Text, "BOTTOMLEFT", 0, -gap * 2)
    local buttons = { open }

    -- a column per group of links, side by side
    local columns = {}
    for i, group in ipairs(LINK_GROUPS) do
        local heading = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        heading:SetText(L(group.name))
        local previous = heading
        local column = { heading = heading, buttons = {} }
        for _, link in ipairs(group.links) do
            local button = createButton(card, link.name or L(link.key), "Plain", variables.buttonWidth, function()
                private.ShowCopyLink(link.url)
            end)
            button:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -gap / 2)
            if link.icon then
                button.Icon = button:CreateTexture(nil, "OVERLAY")
                button.Icon:SetSize(variables.linkIcon * link.aspect, variables.linkIcon)
                button.Icon:SetPoint("LEFT", button, "LEFT", gap, 0)
                button.link = link
            end
            table.insert(buttons, button)
            table.insert(column.buttons, button)
            previous = button
        end
        columns[i] = column
    end

    -- the card and its columns are as wide as Blizzard's settings make the page: laid out once the card has its width,
    -- which it doesn't yet the moment the page is shown
    local layout = function()
        local width = card:GetWidth() - padding * 2
        if width <= 0 then return end
        card.Text:SetWidth(width)
        local columnWidth = (width - gap * (#columns - 1)) / #columns
        for i, column in ipairs(columns) do
            column.heading:ClearAllPoints()
            column.heading:SetPoint("TOPLEFT", open, "BOTTOMLEFT", (i - 1) * (columnWidth + gap), -gap * 2)
            for _, button in ipairs(column.buttons) do
                button:SetWidth(columnWidth)
            end
        end
        local mostLinks = 0
        for _, group in ipairs(LINK_GROUPS) do
            mostLinks = math.max(mostLinks, #group.links)
        end
        card:SetHeight(padding * 2 + variables.logoSize + gap * 5 + card.Text:GetStringHeight() +
            variables.buttonHeight + columns[1].heading:GetStringHeight() +
            mostLinks * (variables.buttonHeight + gap / 2))
    end
    card:SetScript("OnSizeChanged", layout)
    frame:SetScript("OnShow", layout)

    -- the themed are held weakly, the page's frame holds it
    frame.AtThemed = {
        ApplySettings = function()
            -- drawn like a window of the addon: Blizzard's dark panel is behind it, not one of the theme's windows
            local style = private.GetWindowStyle("Window")
            card.AtFill:SetVertexColor(ThemeApply.Color(style.Fill))
            card.AtEdge:SetVertexColor(ThemeApply.Color(style.Edge))
            ThemeApply.FontRole(card.Title, "Title")
            ThemeApply.FontRole(card.Version, "Muted")
            ThemeApply.FontRole(card.Text, "Control")
            for _, column in ipairs(columns) do
                ThemeApply.FontRole(column.heading, "Heading")
            end
            for _, button in ipairs(buttons) do
                ThemedWidgets.DrawButton(button)
                if button.link then
                    private.DrawBrandLogo(button.Icon, button.link, "Field")
                end
            end
            -- another theme's fonts make the texts higher or lower, the card follows
            layout()
        end,
    }
    frame.AtThemed:ApplySettings()
    private.RegisterThemed(frame.AtThemed)

    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(frame, name)
        -- AceConfigDialog finds the parent of the Profiles category by this ID
        category.ID = name
        Settings.RegisterAddOnCategory(category)
    else
        InterfaceOptions_AddCategory(frame)
    end
    return name
end
