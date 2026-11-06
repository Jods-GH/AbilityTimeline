local appName, app = ...
---@class AbilityTimeline
local private = app
local AceGUI = LibStub("AceGUI-3.0")
local ThemeApply = private.ThemeApply
local ThemedWidgets = private.ThemedWidgets

-- the settings window: pages on the left, the rows of a page in the middle and on the right a preview with the
-- description of the hovered row
local Type = "AtSettingsWindow"
local Version = 1
local variables = {
    width = 930,
    height = 580,
    headerHeight = 34,
    padding = 12,
    navWidth = 170,
    navButtonHeight = 28,
    navMarker = 2,
    detailsWidth = 280,
    previewHeight = 150,
    -- screenshots of a row are twice as wide as high, e.g. 512x256
    imageAspect = 0.5,
    searchWidth = 220,
    buttonHeight = 22,
    footerHeight = 30,
    linkSize = 16,
    -- the pinned rows end where the scrolling ones do, left of the scroll bar
    scrollBarWidth = 20,
}

---@param button Button
local drawNavButton = function(button)
    local selected, hover = button.atSelectedProgress or 0, button.atHover or 0
    local r, g, b, a = ThemeApply.Color("Highlight")
    local style = ThemeApply.ControlStyle("Navigation")
    button.AtFill:SetTexture(ThemeApply.File(style and style.File or "panel"))
    if style then
        button.AtFill:ClearTextureSlice()
        r, g, b, a = ThemeApply.Color(style.Color, 0.4)
    else
        button.AtFill:SetTextureSliceMargins(8, 8, 8, 8)
        button.AtFill:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched)
    end
    button.AtFill:SetVertexColor(r, g, b, a * math.max(selected * 0.6, hover))
    r, g, b = ThemeApply.Color("Accent")
    button.AtMarker:SetVertexColor(r, g, b, selected)
    ThemeApply.FontRole(button.Text, selected > 0.5 and "TabSelected" or "Tab")
end

---@param button Button
---@param selected boolean
local selectNavButton = function(button, selected)
    local to = selected and 1 or 0
    if button.atSelected == to then return end
    private.TweenMotion(button.AtMarker, "Select", button.atSelected or to, to, function(progress)
        button.atSelectedProgress = progress
        drawNavButton(button)
    end)
    button.atSelected = to
end

---@param self AtSettingsWindow
local function ApplySettings(self)
    local frame = self.frame
    local style = private.GetWindowStyle("Window")
    ThemeApply.Window(frame, style, frame.CloseButton, frame.Title)
    private.DrawFooterLinks(frame.Footer, style)
    for _, panel in ipairs({ frame.Nav, frame.Details }) do
        ThemeApply.PanelStyle(panel.AtFill, panel.AtEdge)
        panel.AtFill:SetVertexColor(ThemeApply.Color("Card"))
        panel.AtEdge:SetVertexColor(ThemeApply.Color("Edge"))
    end
    frame.Title:SetPoint("TOPLEFT", frame, "TOPLEFT", style.HeaderArt and 44 or variables.padding + 4, -10)
    for _, button in ipairs(frame.Nav.Buttons) do
        drawNavButton(button)
        ThemeApply.FontRole(button.New, "Label")
        button.New:SetTextColor(ThemeApply.Color("Accent"))
    end
    local details = frame.Details
    details.Preview.AtFill:SetVertexColor(ThemeApply.Color("Field"))
    details.Preview.AtEdge:SetVertexColor(ThemeApply.Color("Edge"))
    ThemeApply.FontRole(details.Title, "Heading")
    ThemeApply.FontRole(details.Text, "Control")
    ThemeApply.FontRole(details.Notice, "Control")
    details.Notice:SetTextColor(ThemeApply.Color("Danger"))
    ThemeApply.FontRole(frame.SearchHint, "Muted")
    for _, button in ipairs({ details.Reset, details.ResetPage, frame.TestButton, frame.MoveButton }) do
        ThemedWidgets.DrawButton(button)
    end
end

---@param self AtSettingsWindow
local function OnAcquire(self)
end

---@param self AtSettingsWindow
local function LayoutFinished(self, width, height)
end

---the first child holds what a page pins above its scrolling rows, the second child scrolls below it. An empty
---header is hidden, a frame of no height has no place on screen and the scroll frame would lose its own with it
---@param self AtSettingsWindow
local function DoLayout(self)
    local header, scroll = self.children[1], self.children[2]
    if not scroll then return end
    local pinned = #header.children > 0
    header.frame:SetShown(pinned)
    scroll.frame:ClearAllPoints()
    if pinned then
        header.frame:ClearAllPoints()
        header.frame:SetPoint("TOPLEFT", self.content, "TOPLEFT")
        header.frame:SetPoint("TOPRIGHT", self.content, "TOPRIGHT", -variables.scrollBarWidth, 0)
        header:DoLayout()
        scroll.frame:SetPoint("TOPLEFT", header.frame, "BOTTOMLEFT", 0, -variables.padding)
    else
        scroll.frame:SetPoint("TOPLEFT", self.content, "TOPLEFT")
    end
    scroll.frame:SetPoint("BOTTOMRIGHT", self.content, "BOTTOMRIGHT")
end

---lists the pages in the navigation, clicking one fires OnPageSelected with its key
---@param self AtSettingsWindow
---@param pages table[] -- { key, name, new }
local function SetPages(self, pages)
    local nav = self.frame.Nav
    for i, page in ipairs(pages) do
        local button = nav.Buttons[i]
        if not button then
            button = CreateFrame("Button", nil, nav)
            button:SetHeight(variables.navButtonHeight)
            button:SetPoint("TOPLEFT", nav, "TOPLEFT", 4, -4 - (i - 1) * variables.navButtonHeight)
            button:SetPoint("TOPRIGHT", nav, "TOPRIGHT", -4, -4 - (i - 1) * variables.navButtonHeight)
            button.AtFill = ThemeApply.CreateSliced(button, "panel", "BACKGROUND", 1)
            button.AtFill:SetAllPoints(button)
            button.AtMarker = button:CreateTexture(nil, "ARTWORK")
            button.AtMarker:SetTexture("Interface\\Buttons\\WHITE8X8")
            button.AtMarker:SetWidth(variables.navMarker)
            button.AtMarker:SetPoint("TOPLEFT", 0, -6)
            button.AtMarker:SetPoint("BOTTOMLEFT", 0, 6)
            button.New = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            button.New:SetPoint("RIGHT", -8, 0)
            button.New:SetText(private.getLocalisation("SettingsNew"))
            button.Text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            button.Text:SetPoint("LEFT", 12, 0)
            button.Text:SetJustifyH("LEFT")
            button.Text:SetWordWrap(false)
            ThemedWidgets.HookHover(button, button, function(progress)
                button.atHover = progress
                drawNavButton(button)
            end)
            button:SetScript("OnClick", function()
                self:Fire("OnPageSelected", button.key)
            end)
            nav.Buttons[i] = button
        end
        button.key = page.key
        button.Text:SetText(page.name)
        button.New:SetShown(page.new)
        if page.new then
            button.Text:SetPoint("RIGHT", button.New, "LEFT", -8, 0)
        else
            button.Text:SetPoint("RIGHT", button, "RIGHT", -8, 0)
        end
        button:Show()
        drawNavButton(button)
        ThemeApply.FontRole(button.New, "Label")
        button.New:SetTextColor(ThemeApply.Color("Accent"))
    end
    for i = #pages + 1, #nav.Buttons do
        nav.Buttons[i]:Hide()
    end
end

---marks the page of key as the one shown, nil while search results are shown
---@param self AtSettingsWindow
---@param key string|nil
local function SelectPage(self, key)
    for _, button in ipairs(self.frame.Nav.Buttons) do
        selectNavButton(button, button:IsShown() and button.key == key)
    end
end

---shows what the hovered row does, onReset offers to reset it to the theme, notice stands out above the text, e.g.
---why the row is disabled
---@param self AtSettingsWindow
---@param title string
---@param text string|nil
---@param onReset function|nil
---@param notice string|nil
local function ShowDetails(self, title, text, onReset, notice)
    local details = self.frame.Details
    details.Title:SetText(title)
    details.Notice:SetShown(notice ~= nil)
    details.Notice:SetFormattedText("|A:Professions_Icon_Warning:16:16|a %s", notice or "")
    details.Text:ClearAllPoints()
    details.Text:SetPoint("TOPLEFT", notice and details.Notice or details.Title, "BOTTOMLEFT", 0,
        -variables.padding / 2)
    details.Text:SetText(text or "")
    details.Reset:SetShown(onReset ~= nil)
    details.Reset.onReset = onReset
end

---shows a live preview frame or an image above the description, an image wins, neither leaves the area out
---@param self AtSettingsWindow
---@param preview Frame|nil
---@param image string|nil
local function SetMedia(self, preview, image)
    local details = self.frame.Details
    if image then
        preview = nil
    end
    if details.preview and details.preview ~= preview then
        details.preview:Hide()
    end
    details.preview = preview
    details.Preview:SetShown(image ~= nil or preview ~= nil)
    details.Image:SetShown(image ~= nil)
    -- a preview with atNoField stands on the details panel itself, e.g. a boss model
    local field = not (preview and preview.atNoField)
    details.Preview.AtFill:SetShown(field)
    details.Preview.AtEdge:SetShown(field)
    details.Title:ClearAllPoints()
    if image then
        details.Image:SetTexture(image)
        details.Preview:SetHeight((variables.detailsWidth - variables.padding * 2) * variables.imageAspect)
    elseif preview then
        preview:SetParent(details.Preview)
        preview:SetFrameLevel(details.Preview:GetFrameLevel() + 1)
        preview:ClearAllPoints()
        preview:SetPoint("CENTER", details.Preview, "CENTER")
        preview:Show()
        details.Preview:SetHeight(math.max(variables.previewHeight, preview:GetHeight() + variables.padding * 2))
    end
    if image or preview then
        details.Title:SetPoint("TOPLEFT", details.Preview, "BOTTOMLEFT", 0, -variables.padding)
    else
        details.Title:SetPoint("TOPLEFT", details, "TOPLEFT", variables.padding, -variables.padding)
    end
    details.Title:SetWidth(variables.detailsWidth - variables.padding * 2)
end

---@param self AtSettingsWindow
---@param onReset function|nil -- nil hides the button
local function SetResetPage(self, onReset)
    local button = self.frame.Details.ResetPage
    button:SetShown(onReset ~= nil)
    button.onReset = onReset
end

---@param self AtSettingsWindow
local function ClearSearch(self)
    self.search:SetText("")
    self.search:ClearFocus()
    self.frame.SearchHint:Show()
end

---@param self AtSettingsWindow
---@param running boolean
local function SetTestRunning(self, running)
    self.frame.TestButton:SetText(private.getLocalisation(running and "SettingsStopTest" or "SettingsStartTest"))
end

---@param parent Frame
---@param text string
---@param onClick function
---@return Button
local createButton = function(parent, text, onClick)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    ThemedWidgets.SkinButton(button)
    button:SetHeight(variables.buttonHeight)
    button:SetText(text)
    button:SetScript("OnClick", onClick)
    return button
end

---shows url in a window to copy it from
---@param url string
local showLink = function(url)
    if not private.TextCopyFrame then
        private.TextCopyFrame = AceGUI:Create("AtTextCopyFrame")
    end
    private.TextCopyFrame.frame.CloseButton:SetScript("OnClick", function()
        if private.TextCopyFrame and not private.TextCopyFrame:IsReleasing() then
            private.TextCopyFrame:Release()
            private.TextCopyFrame = nil
        end
    end)
    private.TextCopyFrame.frame:SetPoint("TOP", UIParent, "TOP", 0, -50)
    -- above the settings window and Blizzard's settings
    private.TextCopyFrame.frame:SetFrameStrata("FULLSCREEN_DIALOG")
    private.TextCopyFrame.frame:Show()
    private.TextCopyFrame:SetValues(url)
end
private.ShowCopyLink = showLink

---draws a brand's logo for the color behind it: on a light one its darkIcon file, or itself drawn black with darkTint
---(see Media/Textures/Brands/BrandLicensing.txt for what each brand allows)
---@param texture Texture
---@param link table -- icon, darkIcon, darkTint
---@param background string|table -- a palette color
private.DrawBrandLogo = function(texture, link, background)
    local r, g, b = ThemeApply.Color(background)
    local light = 0.299 * r + 0.587 * g + 0.114 * b > 0.5
    local file, shade = link.icon, 1
    if light and link.darkIcon then
        file = link.darkIcon
    elseif light and link.darkTint then
        shade = 0
    end
    texture:SetTexture("Interface\\AddOns\\AbilityTimeline\\Media\\Textures\\Brands\\" .. file .. ".tga")
    texture:SetVertexColor(shade, shade, shade)
end

local LINKS = {
    {
        icon = "Patreon_logo",
        darkIcon = "Patreon_logo_black",
        width = 15,
        url = "https://www.patreon.com/c/Jodsderechte",
        tooltip = "PatreonDescription",
    },
    {
        icon = "Discord_logo",
        darkTint = true,
        width = 21,
        url = "https://discord.com/invite/v3gYmYamGJ",
        tooltip = "DiscordDescription",
    },
}

---adds the Patreon and Discord buttons to the right end of a window's footer, private.DrawFooterLinks draws them
---@param footer Frame
private.CreateFooterLinks = function(footer)
    local anchor
    footer.Links = {}
    for i = #LINKS, 1, -1 do
        local link = LINKS[i]
        local button = CreateFrame("Button", nil, footer)
        button:SetSize(link.width, variables.linkSize)
        button.Icon = button:CreateTexture(nil, "ARTWORK")
        button.Icon:SetAllPoints(button)
        button.link = link
        table.insert(footer.Links, button)
        if anchor then
            button:SetPoint("RIGHT", anchor, "LEFT", -variables.padding, 0)
        else
            button:SetPoint("RIGHT", footer, "RIGHT", -variables.padding - 4, 0)
        end
        button:SetScript("OnClick", function() showLink(link.url) end)
        private.AddFrameTooltip(button, link.tooltip)
        anchor = button
    end
end

---draws the footer's links for the footer color of a window style
---@param footer Frame
---@param style table
private.DrawFooterLinks = function(footer, style)
    for _, button in ipairs(footer.Links) do
        private.DrawBrandLogo(button.Icon, button.link, style.Footer)
    end
end

local function Constructor()
    local count = AceGUI:GetNextWidgetNum(Type)
    local frame = CreateFrame("Frame", "AbilityTimelineSettingsFrame", UIParent)
    frame:Hide()
    -- This settings frame is retained by Options/Settings.lua, so its real contents can fade before hiding.
    local hide, show = frame.Hide, frame.Show
    local fadeKey = {}
    frame.Hide = function(self)
        local style = self.atWindowStyle
        if not (style and style.FadeOut and self:IsShown() and private.AmbientEffectsEnabled()) then
            if self.atClosing then
                private.StopTween(fadeKey)
                self.atClosing = nil
                self:SetAlpha(1)
            end
            hide(self)
            return
        end
        if self.atClosing then return end
        self.atClosing = true
        local alpha = self:GetAlpha()
        private.Tween(fadeKey, alpha, 0, style.FadeOut, "linear", function(value)
            self:SetAlpha(value)
        end, function()
            self.atClosing = nil
            self.atWindowFadeComplete = true
            hide(self)
            self.atWindowFadeComplete = nil
            self:SetAlpha(alpha)
        end)
    end
    frame.Show = function(self)
        if self.atClosing then
            private.StopTween(fadeKey)
            self.atClosing = nil
            self:SetAlpha(1)
        end
        show(self)
    end
    frame:SetFrameStrata("DIALOG")
    frame:SetSize(variables.width, variables.height)
    frame:SetPoint("CENTER", UIParent, "CENTER")
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    -- closes with escape
    table.insert(UISpecialFrames, frame:GetName())

    frame.Title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.Title:SetPoint("TOPLEFT", frame, "TOPLEFT", variables.padding + 4, -10)
    frame.Title:SetText(private.getLocalisation("SettingsTitle"))
    frame.CloseButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    frame.CloseButton:SetScript("OnClick", function() frame:Hide() end)

    local top = -variables.headerHeight - variables.padding
    local bottom = variables.footerHeight + variables.padding

    frame.Footer = CreateFrame("Frame", nil, frame)
    frame.Footer:SetHeight(variables.footerHeight)
    frame.Footer:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 1, 1)
    frame.Footer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
    frame.Footer.Background = frame.Footer:CreateTexture(nil, "BACKGROUND")
    frame.Footer.Background:SetAllPoints(frame.Footer)
    frame.Footer.AddonName = frame.Footer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.Footer.AddonName:SetPoint("LEFT", frame.Footer, "LEFT", variables.padding + 4, 0)
    frame.Footer.AddonName:SetFormattedText("%s %s", private.getLocalisation("SettingsTitle"),
        C_AddOns.GetAddOnMetadata(appName, "Version"))
    private.CreateFooterLinks(frame.Footer)

    frame.Nav = CreateFrame("Frame", nil, frame)
    frame.Nav:SetPoint("TOPLEFT", frame, "TOPLEFT", variables.padding, top)
    frame.Nav:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", variables.padding, bottom)
    frame.Nav:SetWidth(variables.navWidth)
    ThemeApply.CreatePanel(frame.Nav)
    frame.Nav.Buttons = {}

    local details = CreateFrame("Frame", nil, frame)
    details:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -variables.padding, top)
    details:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -variables.padding, bottom)
    details:SetWidth(variables.detailsWidth)
    ThemeApply.CreatePanel(details)
    details.Preview = CreateFrame("Frame", nil, details)
    details.Preview:SetPoint("TOPLEFT", details, "TOPLEFT", variables.padding, -variables.padding)
    details.Preview:SetPoint("TOPRIGHT", details, "TOPRIGHT", -variables.padding, -variables.padding)
    details.Preview:SetHeight(variables.previewHeight)
    -- the preview stands on a field of its own
    ThemeApply.CreatePanel(details.Preview)
    details.Image = details.Preview:CreateTexture(nil, "ARTWORK")
    details.Image:SetAllPoints(details.Preview)
    details.Title = details:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    details.Title:SetJustifyH("LEFT")
    details.Notice = details:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    details.Notice:SetPoint("TOPLEFT", details.Title, "BOTTOMLEFT", 0, -variables.padding / 2)
    details.Notice:SetWidth(variables.detailsWidth - variables.padding * 2)
    details.Notice:SetJustifyH("LEFT")
    details.Notice:SetWordWrap(true)
    details.Notice:SetSpacing(3)
    details.Notice:Hide()
    details.Text = details:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    details.Text:SetPoint("TOPLEFT", details.Title, "BOTTOMLEFT", 0, -variables.padding / 2)
    details.Text:SetWidth(variables.detailsWidth - variables.padding * 2)
    details.Text:SetJustifyH("LEFT")
    details.Text:SetWordWrap(true)
    details.Text:SetSpacing(3)
    -- both resets sit at the bottom, the hovered row's above the page's
    details.ResetPage = createButton(details, private.getLocalisation("SettingsResetPage"), function(button)
        button.onReset()
    end)
    details.ResetPage:SetPoint("BOTTOMLEFT", details, "BOTTOMLEFT", variables.padding, variables.padding)
    details.ResetPage:SetPoint("BOTTOMRIGHT", details, "BOTTOMRIGHT", -variables.padding, variables.padding)
    details.Reset = createButton(details, private.getLocalisation("ResetToTheme"), function(button)
        button.onReset()
    end)
    details.Reset:SetPoint("BOTTOMLEFT", details.ResetPage, "TOPLEFT", 0, variables.padding / 2)
    details.Reset:SetPoint("BOTTOMRIGHT", details.ResetPage, "TOPRIGHT", 0, variables.padding / 2)
    frame.Details = details

    local contentFrame = CreateFrame("Frame", Type .. "ContentFrame" .. count, frame)
    contentFrame:SetPoint("TOPLEFT", frame.Nav, "TOPRIGHT", variables.padding, 0)
    contentFrame:SetPoint("BOTTOMRIGHT", details, "BOTTOMLEFT", -variables.padding, 0)

    ---@class AtSettingsWindow : AceGUIContainer
    local widget = {
        OnAcquire = OnAcquire,
        ApplySettings = ApplySettings,
        LayoutFinished = LayoutFinished,
        DoLayout = DoLayout,
        SetPages = SetPages,
        SelectPage = SelectPage,
        ShowDetails = ShowDetails,
        SetMedia = SetMedia,
        SetResetPage = SetResetPage,
        ClearSearch = ClearSearch,
        SetTestRunning = SetTestRunning,
        type = Type,
        count = count,
        frame = frame,
        content = contentFrame,
    }

    frame.TestButton = createButton(frame, "", function()
        widget:Fire("OnTestClicked")
    end)
    frame.TestButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -40, -6)
    frame.TestButton:SetWidth(150)
    frame.MoveButton = createButton(frame, private.getLocalisation("SettingsMoveTimers"), function()
        widget:Fire("OnMoveClicked")
    end)
    frame.MoveButton:SetPoint("RIGHT", frame.TestButton, "LEFT", -variables.padding / 2, 0)
    frame.MoveButton:SetWidth(120)
    private.AddFrameTooltip(frame.MoveButton, "SettingsMoveTimersDescription")

    local search = AceGUI:Create("AtEditBox")
    search:SetLabel("")
    search:DisableButton(true)
    search:SetWidth(variables.searchWidth)
    search.frame:SetParent(frame)
    search.frame:SetPoint("RIGHT", frame.MoveButton, "LEFT", -variables.padding, 0)
    search.frame:Show()
    search:SetCallback("OnTextChanged", function(_, _, text)
        frame.SearchHint:SetShown(text == "")
        widget:Fire("OnSearch", text)
    end)
    frame.SearchHint = search.editbox:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.SearchHint:SetPoint("LEFT", search.editbox, "LEFT", 6, 0)
    frame.SearchHint:SetText(private.getLocalisation("SettingsSearch"))
    widget.search = search

    ApplySettings(widget)
    SetTestRunning(widget, false)
    private.RegisterThemed(widget)

    return AceGUI:RegisterAsContainer(widget)
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)
