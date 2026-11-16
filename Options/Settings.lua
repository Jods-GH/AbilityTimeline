local appName, app = ...
---@class AbilityTimeline
local private = app
local AceGUI = LibStub("AceGUI-3.0")
local LibEditMode = LibStub("LibEditMode")
local SharedMedia = LibStub("LibSharedMedia-3.0")
local ThemeApply = private.ThemeApply

-- the pages of the settings window: { key, name, desc, order, rows, hidden, disabled, disabledReason, notice, image,
-- GetPreview, Render, OnShow, OnHide, testTimers, pinned }. Render(scroll, header) adds content of its own, pinned keeps
-- the rows above the scrolling part, testTimers runs the test timers while the page is shown, disabled greys out all
-- its rows and disabledReason tells why, as a row's own disabledReason does, notice is a warning of a page that is
-- not disabled. Rows are written like Edit Mode settings with kind
-- Heading, Checkbox, Slider, Dropdown, Color, Button, Input (set when enter is pressed) or Media (a SharedMedia pick
-- of its mediaType), and instead of
-- get and set they can name themePath (a value of the current theme) or profileKey (a dotted path into db.profile).
-- A row with get and set can give modified() and reset() so it shows as changed and can be reset like a theme value.
-- A row's image (a screenshot, 512x256) is shown while it is hovered, in place of the page's live preview, as is the
-- frame its preview function returns; preview false shows neither. A Dropdown
-- with multiselect gets and sets a table of keys
local variables = {
    -- typing renders the results once it paused this long
    searchDelay = 0.25,
    -- the second button of a Button row with secondaryFunc
    secondaryWidth = 96,
    buttonGap = 4,
}

-- a Button row's two buttons: the second its own width on the right, the first fills the rest. Anchored, so they follow
-- the row's width without a layout pass
AceGUI:RegisterLayout("AtButtonPair", function(content, children)
    local first, second = children[1], children[2]
    -- AddChild lays out after each child, the first one is added alone
    if not second then return end
    second.frame:ClearAllPoints()
    second.frame:SetPoint("TOPRIGHT", content, "TOPRIGHT")
    first.frame:ClearAllPoints()
    first.frame:SetPoint("TOPLEFT", content, "TOPLEFT")
    first.frame:SetPoint("TOPRIGHT", second.frame, "TOPLEFT", -variables.buttonGap, 0)
end)
local pages = {}
local window
local searchTimer
local currentPage
local searchText = ""
local scrollStatus = {}
local rendered = {}
local hiddenRows = {}
local hoveredEntry
local pagePreview
local renderedThemeKey
local testRunning = false
-- whether the test timers were started by the page shown
local pageTestRunning = false
local shownPage
local wasEditModeOpen = false
local reopenAfterEditMode = false
local hiddenAt
local longLabels = false
local gamePadFocus = false
local gamePadEnabled = false
local colorPickerHooked = false
local colorPickerOwner
local gamePadMode
local GAMEPAD_HINTS = {
    Rows = {
        { "GamePadSelect", "PADDUP", "PADDDOWN" },
        { "GamePadChange", "PADDLEFT", "PADDRIGHT" },
        { "GamePadUse", "PAD1" },
        { "GamePadPage", "PADLSHOULDER", "PADRSHOULDER" },
        { "GamePadClose", "PAD2" },
    },
    List = {
        { "GamePadSelect", "PADDUP", "PADDDOWN" },
        { "GamePadUse", "PAD1" },
        { "GamePadDone", "PAD2" },
    },
    Change = {
        { "GamePadChange", "PADDLEFT", "PADDRIGHT" },
        { "GamePadDone", "PAD2" },
    },
    Number = {
        { "GamePadChange", "PADDLEFT", "PADDRIGHT" },
        { "GamePadFine", "PADDUP", "PADDDOWN" },
        { "GamePadDone", "PAD2" },
    },
    Zoom = {
        { "GamePadMove", "PADDLEFT", "PADDRIGHT" },
        { "GamePadZoom", "PADDUP", "PADDDOWN" },
        { "GamePadDone", "PAD2" },
    },
    Lanes = {
        { "GamePadSelect", "PADDUP", "PADDDOWN" },
        { "GamePadUse", "PAD1" },
        { "GamePadAddRule", "PAD3" },
        { "GamePadPage", "PADLSHOULDER", "PADRSHOULDER" },
        { "GamePadClose", "PAD2" },
    },
    Order = {
        { "GamePadSelect", "PADDUP", "PADDDOWN" },
        { "GamePadMove", "PADDLEFT", "PADDRIGHT" },
        { "GamePadDone", "PAD2" },
    },
}
-- the widgets a gamepad picks, as the pointer hovers them: each with the frame of it that the pointer enters
local GAMEPAD_WIDGETS = {
    AtCheckBox = "frame", AtButton = "frame", AtSlider = "slider", AtDropdown = "button_cover", AtEditBox = "editbox",
    AtColorPicker = "frame", AtMediaPicker = "frame", AtOrderList = "frame", AtThemeCard = "frame",
    AtCountdownChoice = "frame", AtCountdownSituation = "frame", AtCountdownSummary = "frame",
    AtCountdownLaneItem = "frame", AtCountdownZoom = "frame", Button = "frame", AtMultiLineEditBox = "editBox",
}
local gamePadWidget, gamePadIndex, gamePadRoot
local gamePadRing
local GAMEPAD_BUTTONS = { Reset = "PAD3", Test = "PAD4", Move = "PADLSTICK", ResetPage = "PADRSTICK",
    Undo = "PADLTRIGGER", Redo = "PADRTRIGGER" }

---@param page table
private.RegisterSettingsPage = function(page)
    table.insert(pages, page)
    table.sort(pages, function(a, b) return a.order < b.order end)
end

private.showReloadPopup = function()
    StaticPopupDialogs["ABILITYTIMELINE_RELOAD"] = StaticPopupDialogs["ABILITYTIMELINE_RELOAD"] or {
        text = private.getLocalisation("ReloadRequired"),
        button1 = RELOADUI,
        button2 = CANCEL,
        OnAccept = ReloadUI,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
    }
    StaticPopup_Show("ABILITYTIMELINE_RELOAD")
end

---the text shown, doubled by /at test labels to see how long translations fit
---@param text string|nil
---@return string|nil
local display = function(text)
    if longLabels and text then
        return text .. " " .. text
    end
    return text
end

private.DisplaySettingsText = display

local getRows = function(page)
    if type(page.rows) == "function" then
        return page.rows()
    end
    return page.rows
end

local isHidden = function(item)
    return item.hidden ~= nil and item.hidden() == true
end

---@param item table -- a page or a row
local isDisabled = function(item)
    return item ~= nil and item.disabled ~= nil and item.disabled() == true
end

---the warning shown with entry: why its row is disabled, its own reason first, then its page's, else its page's notice
---@param entry table -- { row, page }, either can be nil
---@return string|nil
local getNotice = function(entry)
    for _, item in ipairs({ entry.row or false, entry.page or false }) do
        if item and isDisabled(item) and item.disabledReason then
            return item.disabledReason()
        end
    end
    if entry.page and entry.page.notice then
        return entry.page.notice()
    end
end

---@param path string -- dotted, e.g. "icon_settings.strata"
local getProfileValue = function(path)
    local node = private.db.profile
    for key in path:gmatch("[^%.]+") do
        if type(node) ~= "table" then
            return nil
        end
        node = node[key]
    end
    return node
end

local setProfileValue = function(path, value)
    local keys = { strsplit(".", path) }
    local node = private.db.profile
    for i = 1, #keys - 1 do
        node[keys[i]] = node[keys[i]] or {}
        node = node[keys[i]]
    end
    node[keys[#keys]] = value
end

local getValue = function(row)
    if row.themePath then
        return private.GetThemeValue(row.themePath)
    elseif row.profileKey then
        return getProfileValue(row.profileKey)
    end
    return row.get()
end

---whether a row differs from its default: a theme value the player changed, or a row's own modified()
local isModified = function(row)
    if row.modified then return row.modified() == true end
    return row.themePath ~= nil and private.IsThemeModified(row.themePath)
end

---a setting is known by where it is stored, rows without (buttons, color changes) are never new
---@param row table
---@return string|nil
local getSettingID = function(row)
    return row.profileKey or row.themePath
end

---remembers every setting of every page, the ones not there the last time are new until they are hovered. The first
---time (a new install, or the version that brought this) remembers them all without any being new
local detectNewSettings = function()
    local global = private.db.global
    local firstTime = global.knownSettings == nil
    global.knownSettings = global.knownSettings or {}
    global.newSettings = global.newSettings or {}
    for _, page in ipairs(pages) do
        for _, row in ipairs(isHidden(page) and {} or getRows(page)) do
            local id = getSettingID(row)
            if id and not global.knownSettings[id] then
                global.knownSettings[id] = true
                if not firstTime then
                    global.newSettings[id] = true
                end
            end
        end
    end
end

---@param row table
---@return boolean
local isNew = function(row)
    local id = getSettingID(row)
    return id ~= nil and private.db.global.newSettings[id] == true
end

local markSeen = function(row)
    private.db.global.newSettings[getSettingID(row)] = nil
end

local rerender
local setNavigation
local setGamePadMode
local showGamePadHints
local refocus
local onGamePadButton

---updates whether rows are disabled or changed, renders again when a row was hidden or shown (after the
---control that changed it finished its callback)
local refreshRows = function()
    for row, hidden in pairs(hiddenRows) do
        if isHidden(row) ~= hidden then
            hiddenRows = {}
            C_Timer.After(0, rerender)
            return
        end
    end
    for _, entry in ipairs(rendered) do
        local disabled = isDisabled(entry.row) or isDisabled(entry.page)
        if entry.disabled ~= disabled then
            entry.disabled = disabled
            entry.widget:SetDisabled(disabled)
        end
        entry.widget:SetChanged(isModified(entry.row))
    end
end

local showEntry
---@param key string|nil -- the item of a multiselect dropdown
local setValue = function(row, value, key)
    local suffix = key and "." .. key or ""
    if row.themePath then
        private.SetThemeModification(row.themePath .. suffix, value)
    elseif row.profileKey then
        setProfileValue(row.profileKey .. suffix, value)
    else
        row.set(value, key)
    end
    if row.onChange then
        row.onChange(value)
    end
    refreshRows()
    if hoveredEntry and hoveredEntry.row == row then
        showEntry(hoveredEntry)
    end
end

---@param row table
---@return table
local createControl = function(row)
    local control
    if row.kind == "Checkbox" then
        control = AceGUI:Create("AtCheckBox")
        control:SetLabel("")
        control:SetValue(getValue(row))
    elseif row.kind == "Slider" then
        control = AceGUI:Create("AtSlider")
        control:SetLabel("")
        control:SetSliderValues(row.minValue, row.maxValue, row.valueStep)
        control:SetIsPercent(row.isPercent)
        control:SetValue(getValue(row))
    elseif row.kind == "Dropdown" then
        control = AceGUI:Create("AtDropdown")
        local values = type(row.values) == "function" and row.values() or row.values
        local sorting = type(row.sorting) == "function" and row.sorting() or row.sorting
        if row.multiselect then
            control:SetMultiselect(true)
            control:SetList(values, sorting)
            for key, checked in pairs(getValue(row) or {}) do
                control:SetItemValue(key, checked)
            end
            control:SetCallback("OnValueChanged", function(_, _, key, checked)
                setValue(row, checked, key)
            end)
            return control
        end
        control:SetList(values, sorting)
        control:SetValue(getValue(row))
    elseif row.kind == "Order" then
        control = AceGUI:Create("AtOrderList")
        control:SetList(type(row.values) == "function" and row.values() or row.values, getValue(row))
    elseif row.kind == "Media" then
        control = AceGUI:Create("AtMediaPicker")
        control:SetMediaType(row.mediaType)
        if row.mediaType == "font" and row.themePath then
            local font = private.GetThemeValue(row.themePath:gsub("%.Media$", ""))
            control:SetValue(font.Media or font.Path or font.Object)
        else
            control:SetValue(getValue(row))
        end
    elseif row.kind == "Color" then
        control = AceGUI:Create("AtColorPicker")
        control:SetLabel("")
        control:SetHasAlpha(row.hasOpacity)
        control:SetColor(ThemeApply.Color(getValue(row)))
        control:SetCallback("OnValueChanged", function(_, _, r, g, b, a)
            setValue(row, { r = r, g = g, b = b, a = a })
        end)
        return control
    elseif row.kind == "Input" then
        control = AceGUI:Create("AtEditBox")
        control:SetLabel("")
        control:SetText(getValue(row) or "")
        control:SetCallback("OnEnterPressed", function(_, _, value)
            setValue(row, value)
        end)
        return control
    elseif row.kind == "Button" then
        control = AceGUI:Create("AtButton")
        control:SetText(row.buttonText or row.name)
        control:SetCallback("OnClick", function()
            row.func()
            refreshRows()
        end)
        if not row.secondaryFunc then
            return control
        end
        -- a second button beside the first, e.g. to delete what the first edits
        local secondary = AceGUI:Create("AtButton")
        secondary:SetText(row.secondaryText)
        secondary:SetStyle("Danger")
        secondary:SetCallback("OnClick", function()
            row.secondaryFunc()
            refreshRows()
        end)
        local group = AceGUI:Create("SimpleGroup")
        group:SetLayout("AtButtonPair")
        group:SetAutoAdjustHeight(false)
        group:SetHeight(control.frame:GetHeight())
        secondary:SetWidth(variables.secondaryWidth)
        for _, button in ipairs({ control, secondary }) do
            button:SetCallback("OnEnter", function()
                group:Fire("OnEnter")
            end)
            group:AddChild(button)
        end
        return group
    end
    control:SetCallback("OnValueChanged", function(_, _, value)
        setValue(row, value)
    end)
    return control
end

local setTestRunning = function(running)
    testRunning = running
    pageTestRunning = false
    if running then
        private.startTestEvents()
    else
        private.stopTestEvents()
    end
    window:SetTestRunning(running)
    private.OnTourEvent(running and "test" or "testStop")
end

---calls OnHide of the page shown before and OnShow of page (nil while nothing or search results are shown)
---@param page table|nil
local setShownPage = function(page)
    if shownPage == page then return end
    if shownPage then
        if shownPage.OnHide then
            shownPage.OnHide()
        end
        if pageTestRunning then
            setTestRunning(false)
        end
    end
    shownPage = page
    if page then
        if page.testTimers and not testRunning then
            setTestRunning(true)
            pageTestRunning = true
        end
        if page.OnShow then
            page.OnShow()
        end
    end
    return true
end

---shows what content of a page's own is about, e.g. a hovered theme card
---@param title string
---@param text string|nil
---@param preview Frame|nil
private.ShowSettingsDetails = function(title, text, preview)
    if hoveredEntry then
        hoveredEntry.widget:SetHovered(false)
        hoveredEntry = nil
    end
    window:SetMedia(preview)
    window:ShowDetails(title, text)
end

showEntry = function(entry)
    if hoveredEntry and hoveredEntry ~= entry then
        hoveredEntry.widget:SetHovered(false)
    end
    hoveredEntry = entry
    entry.widget:SetHovered(true)
    local row = entry.row
    local onReset
    if isModified(row) then
        onReset = function()
            if row.reset then
                row.reset()
            else
                private.ResetThemeModifications(row.themePath)
            end
            rerender()
        end
    end
    local preview = pagePreview
    if row.preview == false then
        preview = nil
    elseif row.preview then
        preview = row.preview()
    end
    window:SetMedia(preview, row.image)
    if isNew(row) then
        markSeen(row)
        entry.widget:SetNew(false)
        setNavigation()
    end
    window:ShowDetails(display(row.name), display(row.desc), onReset, display(getNotice(entry)))
end

---shows rows (and headings) in the middle of the window
---@param rows table[]
---@param statusKey string -- keeps the scroll position of each page
---@param custom function|nil -- adds content of its own below the rows
---@param pinned boolean|nil -- the rows stay above the scrolling part
---@param getPage function -- returns the page of the row at an index
local render = function(rows, statusKey, custom, pinned, getPage)
    local header, scroll = window.children[1], window.children[2]
    local parent = pinned and header or scroll
    if gamePadMode then
        setGamePadMode(nil)
    end
    gamePadWidget = nil
    hoveredEntry = nil
    rendered = {}
    hiddenRows = {}
    renderedThemeKey = private.GetCurrentThemeKey()
    scrollStatus[statusKey] = scrollStatus[statusKey] or {}
    scroll:SetStatusTable(scrollStatus[statusKey])
    scroll:PauseLayout()
    scroll:ReleaseChildren()
    header:PauseLayout()
    header:ReleaseChildren()
    for index, row in ipairs(rows) do
        if row.hidden then
            hiddenRows[row] = isHidden(row)
        end
        if not isHidden(row) then
            if row.kind == "Heading" then
                local heading = AceGUI:Create("AtSettingHeading")
                heading:SetText(display(row.name))
                parent:AddChild(heading)
            else
                local widget = AceGUI:Create("AtSettingRow")
                widget:SetLabel(display(row.name))
                widget:SetNew(isNew(row))
                local control = createControl(row)
                local entry = { row = row, widget = widget, page = getPage(index) }
                local onEnter = function()
                    showEntry(entry)
                end
                widget:SetCallback("OnEnter", onEnter)
                control:SetCallback("OnEnter", onEnter)
                widget:AddChild(control)
                parent:AddChild(widget)
                table.insert(rendered, entry)
            end
        end
    end
    if custom then
        custom(scroll, header)
    end
    header:ResumeLayout()
    scroll:ResumeLayout()
    window:DoLayout()
    scroll:DoLayout()
    refreshRows()
end

---@param key string
local showPage = function(key)
    for _, page in ipairs(pages) do
        if page.key == key and not isHidden(page) then
            currentPage = page
        end
    end
    currentPage = currentPage or pages[1]
    local page = currentPage
    local opened = setShownPage(page)
    window:SelectPage(page.key)
    pagePreview = page.GetPreview and page.GetPreview()
    window:SetMedia(pagePreview, page.image)
    local rows = getRows(page)
    local themePaths = {}
    for _, row in ipairs(rows) do
        if row.themePath then
            table.insert(themePaths, row.themePath)
        end
    end
    local confirmReset = function(onReset)
        return function()
            private.AskQuestion({
                title = private.getLocalisation("SettingsResetPageTitle"),
                text = private.getLocalisation("SettingsResetPageText"):format(display(page.name)),
                accept = private.getLocalisation("SettingsReset"),
                acceptStyle = "Danger",
                back = CANCEL,
                onAccept = onReset,
            })
        end
    end
    if page.ResetPage then window:SetResetPage(confirmReset(page.ResetPage), display(page.resetText))
    else
        window:SetResetPage(#themePaths > 0 and confirmReset(function()
            for _, path in ipairs(themePaths) do
                private.ResetThemeModifications(path)
            end
            rerender()
        end) or nil)
    end
    if page.GetHistory then window:SetPageHistory(page.GetHistory()) else window:SetPageHistory(nil) end
    render(rows, page.key, page.Render, page.pinned, function() return page end)
    window:ShowDetails(display(page.name), display(page.desc), nil, display(getNotice({ page = page })))
    if opened then private.OnTourEvent("page" .. page.key) end
end

---lists the rows of every page whose name or description contain text
---@param text string
local showSearch = function(text)
    local query = text:lower()
    local matches = function(value)
        return value ~= nil and value:lower():find(query, 1, true) ~= nil
    end
    local rows = {}
    -- a row can be on more than one page, so the page it was found on is kept next to it
    local rowPages = {}
    for _, page in ipairs(pages) do
        if not isHidden(page) then
            local found = false
            if page.Render and page.searchTerms and (matches(page.name) or matches(page.searchTerms)) then
                table.insert(rows, { kind = "Heading", name = page.name })
                table.insert(rows, { kind = "Button", name = page.name, desc = page.desc, buttonText = private.getLocalisation("CountdownOpenEditor"),
                    func = function() private.openSettings(page.key) end })
                rowPages[#rows] = page
                found = true
            end
            for _, row in ipairs(getRows(page)) do
                if row.kind ~= "Heading" and not isHidden(row) and (matches(row.name) or matches(row.desc)) then
                    if not found then
                        table.insert(rows, { kind = "Heading", name = page.name })
                        found = true
                    end
                    table.insert(rows, row)
                    rowPages[#rows] = page
                end
            end
        end
    end
    if #rows == 0 then
        table.insert(rows, { kind = "Heading", name = private.getLocalisation("SettingsNoResults") })
    end
    setShownPage(nil)
    window:SelectPage(nil)
    pagePreview = nil
    window:SetMedia(nil)
    window:SetResetPage(nil)
    window:SetPageHistory(nil)
    render(rows, "search", nil, nil, function(index) return rowPages[index] end)
    window:ShowDetails(display(private.getLocalisation("SettingsSearchResults")),
        display(private.getLocalisation("SettingsSearchResultsDescription")))
    private.OnTourEvent("search")
end

---renders the page again, e.g. after rows were added to it
private.RefreshSettingsPage = function()
    if window and window.frame:IsShown() then
        C_Timer.After(0, rerender)
    end
end

rerender = function()
    if searchText ~= "" then
        showSearch(searchText)
    else
        showPage(currentPage.key)
    end
    refocus()
end

setNavigation = function()
    local navigation = {}
    for _, page in ipairs(pages) do
        if not isHidden(page) then
            local new = false
            for _, row in ipairs(getRows(page)) do
                new = new or (not isHidden(row) and isNew(row))
            end
            table.insert(navigation, { key = page.key, name = display(page.name), new = new })
        end
    end
    window:SetPages(navigation)
end

---scrolls a widget into view in the scroll frame it is in, with the row it is the control of
---@param widget table
local scrollTo = function(widget)
    local scroll = widget.parent
    while scroll and scroll.type ~= "AtScrollFrame" do
        scroll = scroll.parent
    end
    if not scroll or not scroll.scrollBarShown then return end
    local frame = widget.parent.type == "AtSettingRow" and widget.parent.frame or widget.frame
    local view, height = scroll.scrollframe:GetHeight(), scroll.content:GetHeight()
    local top = scroll.content:GetTop() - frame:GetTop()
    local offset = (scroll.status or scroll.localstatus).offset or 0
    if top < offset then
        offset = top
    elseif top + frame:GetHeight() > offset + view then
        offset = top + frame:GetHeight() - view
    else
        return
    end
    scroll.scrollbar:SetValue(offset / (height - view) * 1000)
end

---@return boolean
local isSettingsShown = function()
    return window ~= nil and window.frame:IsShown()
end

---@param button Button
---@param kind string
---@param parent table|nil -- the widget it is part of
---@return table
local getButtonWidget = function(button, kind, parent)
    button.atGamePadWidget = button.atGamePadWidget or { type = kind, frame = button, parent = parent }
    return button.atGamePadWidget
end

---@param widget table
---@param list table
---@return table list
local function collectWidgets(widget, list)
    if GAMEPAD_WIDGETS[widget.type] then
        if widget.frame:IsVisible() then
            table.insert(list, widget)
        end
        return list
    end
    -- the blocks of the timer rule lanes, not their drag handles, and the bar that sets the time they show
    if widget.type == "AtCountdownLanes" then
        if widget.zoomBar.track:IsVisible() then
            table.insert(list, getButtonWidget(widget.zoomBar.track, "AtCountdownZoom", widget))
        end
        for _, item in ipairs(widget.buttons) do
            if item:IsVisible() and not item.handle then
                table.insert(list, getButtonWidget(item, "AtCountdownLaneItem", widget))
            end
        end
    end
    for _, child in ipairs(widget.children or {}) do
        collectWidgets(child, list)
    end
    for _, child in ipairs(widget.headerWidgets or {}) do
        collectWidgets(child, list)
    end
    return list
end

---@return table
local getGamePadWidgets = function()
    local list = collectWidgets(gamePadRoot or window or {}, {})
    for _, name in ipairs({ "Done", "Copy", "Remove" }) do
        local button = gamePadRoot and gamePadRoot.frame[name]
        if button and button:IsVisible() then
            table.insert(list, getButtonWidget(button, "Button"))
        end
    end
    return list
end

---runs what the pointer entering (OnEnter) or leaving (OnLeave) a widget does, so it looks and describes itself as hovered
---@param widget table
---@param script string
local hoverWidget = function(widget, script)
    local frame = widget[GAMEPAD_WIDGETS[widget.type]]
    local handler = frame:GetScript(script)
    if handler then
        handler(frame)
    else
        widget:Fire(script)
    end
end

---@param widget table
---@param list table -- the widgets that can be picked now
local focusWidget = function(widget, list)
    if gamePadWidget ~= widget and tContains(list, gamePadWidget) then
        hoverWidget(gamePadWidget, "OnLeave")
    end
    gamePadWidget, gamePadIndex = widget, tIndexOf(list, widget)
    hoverWidget(widget, "OnEnter")
    scrollTo(widget)
    if not gamePadMode then
        showGamePadHints(widget.type == "AtCountdownLaneItem" and GAMEPAD_HINTS.Lanes or GAMEPAD_HINTS.Rows)
    end
    -- an accent edge around the picked widget, not every widget shows that it is hovered
    if not gamePadRing then
        gamePadRing = CreateFrame("Frame")
        gamePadRing.Edge = ThemeApply.CreateSliced(gamePadRing, "panel_edge", "OVERLAY", 1)
        gamePadRing.Edge:SetAllPoints(gamePadRing)
    end
    local frame = widget[GAMEPAD_WIDGETS[widget.type]]
    gamePadRing:SetParent(frame)
    gamePadRing:SetFrameLevel(frame:GetFrameLevel() + 5)
    gamePadRing:ClearAllPoints()
    gamePadRing:SetPoint("TOPLEFT", frame, "TOPLEFT", -3, 3)
    gamePadRing:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 3, -3)
    gamePadRing.Edge:SetVertexColor(ThemeApply.Color("Accent"))
    gamePadRing:Show()
end

---picks the widget in the place of the picked one when that is gone, as the page rendered again
refocus = function()
    if not (gamePadFocus and (gamePadRoot or isSettingsShown())) then return end
    local list = getGamePadWidgets()
    if not list[1] then
        gamePadWidget = nil
        if gamePadRing then gamePadRing:Hide() end
    elseif not tContains(list, gamePadWidget) then
        focusWidget(list[math.min(gamePadIndex or 1, #list)], list)
    end
end

---picks the closest widget in a direction, sideways only one on the line of the picked widget
---@param dx number
---@param dy number
---@return boolean moved
local moveFocus = function(dx, dy)
    local list = getGamePadWidgets()
    if not tContains(list, gamePadWidget) then
        refocus()
        return true
    end
    local left, bottom, width, height = gamePadWidget.frame:GetRect()
    local best, bestScore
    for _, widget in ipairs(list) do
        local widgetLeft, widgetBottom, widgetWidth, widgetHeight = widget.frame:GetRect()
        local offsetX = widgetLeft + widgetWidth / 2 - left - width / 2
        local offsetY = widgetBottom + widgetHeight / 2 - bottom - height / 2
        local along = offsetX * dx + offsetY * dy
        -- how far the widget is beside the picked one, none while they overlap in that direction
        local gap
        if dx == 0 then
            gap = math.max(0, left - widgetLeft - widgetWidth, widgetLeft - left - width)
        else
            gap = math.max(0, bottom - widgetBottom - widgetHeight, widgetBottom - bottom - height)
        end
        if along > 1 and (dx == 0 or gap == 0) then
            local score = along + gap * 3 + math.abs(offsetX * dy + offsetY * dx) / 100
            if not bestScore or score < bestScore then
                best, bestScore = widget, score
            end
        end
    end
    if best then
        focusWidget(best, list)
    end
    return best ~= nil
end

---@param hints table[]
showGamePadHints = function(hints)
    if not isSettingsShown() then return end
    local texts, buttons = {}, {}
    for _, hint in ipairs(hints) do
        table.insert(texts, ("%s%s %s"):format(GetBindingText(hint[2], 1), hint[3] and GetBindingText(hint[3], 1) or "",
            private.getLocalisation(hint[1])))
    end
    for key, button in pairs(GAMEPAD_BUTTONS) do
        buttons[key] = GetBindingText(button, 1)
    end
    window:SetGamePadHints(table.concat(texts, "   "), buttons)
end

---@param mode fun(button: string)|nil -- gets the buttons instead of the rows
---@param hints table[]|nil
setGamePadMode = function(mode, hints)
    gamePadMode = mode
    showGamePadHints(hints or GAMEPAD_HINTS.Rows)
end

---@param control table
local useDropdown = function(control)
    control.button:Click()
    if not control.open then return end
    local pullout = control.pullout
    local items, index = {}, 1
    local refreshItems = function()
        local picked = items[index]
        items = {}
        index = 1
        for _, item in pullout:IterateItems() do
            if item.frame:IsShown() and not item.disabled then
                table.insert(items, item)
                if item == picked or not picked and not control.multiselect and item.userdata.value == control.value then
                    index = #items
                end
            end
        end
    end
    refreshItems()
    if #items == 0 then
        pullout:Close()
        return
    end
    local pick = function(to)
        local frame = items[index].frame
        frame:GetScript("OnLeave")(frame)
        index = math.max(1, math.min(#items, to))
        frame = items[index].frame
        frame:GetScript("OnEnter")(frame)
        local view, height = pullout.scrollFrame:GetHeight(), pullout.itemFrame:GetHeight()
        if height > view then
            local top = pullout.itemFrame:GetTop() - frame:GetTop()
            pullout.slider:SetValue(math.max(0, math.min(1, (top - view / 2) / (height - view))) * 1000)
        end
    end
    pick(index)
    setGamePadMode(function(button)
        if not control.open then
            setGamePadMode(nil)
            return
        end
        refreshItems()
        if #items == 0 then
            if button == "PAD2" then pullout:Close() end
        elseif button == "PADDUP" then
            pick(index - 1)
        elseif button == "PADDDOWN" then
            pick(index + 1)
        elseif button == "PAD1" then
            items[index].frame:Click()
        elseif button == "PAD2" then
            pullout:Close()
        end
        if gamePadMode and not control.open then
            setGamePadMode(nil)
        end
    end, GAMEPAD_HINTS.List)
end

---@param control table
local useOrder = function(control)
    local index = 1
    if #control.shown == 0 then return end
    control:Pick(control.shown[index])
    setGamePadMode(function(button)
        if button == "PADDUP" or button == "PADDDOWN" then
            index = math.max(1, math.min(#control.shown, index + (button == "PADDUP" and -1 or 1)))
            control:Pick(control.shown[index])
        elseif button == "PADDLEFT" or button == "PADDRIGHT" then
            index = control:Move(button == "PADDLEFT" and -1 or 1)
        elseif button == "PAD1" or button == "PAD2" then
            control:Pick(nil)
            setGamePadMode(nil)
        end
    end, GAMEPAD_HINTS.Order)
end

---moves a slider a step or a media picker a file on, the files start over at their end
---@param widget table
---@param step number
local changeWidget = function(widget, step)
    if widget.disabled then return end
    if widget.type == "AtSlider" then
        widget.slider:SetValue((widget.value or 0) + step * (widget.step or 1))
    elseif widget.type == "AtMediaPicker" then
        local names = SharedMedia:List(widget.mediaType)
        if #names == 0 then return end
        local value = names[((tIndexOf(names, widget.value) or 1) - 1 + step) % #names + 1]
        widget:SetValue(value)
        widget:Fire("OnValueChanged", value)
    end
end

---@param widget table
local useWidget = function(widget)
    if widget.disabled then return end
    if widget.type == "AtCheckBox" then
        widget:ToggleChecked()
        widget:Fire("OnValueChanged", widget:GetValue())
    elseif widget.type == "AtDropdown" then
        useDropdown(widget)
    elseif widget.type == "AtOrderList" then
        useOrder(widget)
    elseif widget.type == "AtEditBox" and tonumber(widget:GetText()) then
        -- a number is changed in steps and entered after each, which can render its field again: the one in its place
        -- is the one changed then
        setGamePadMode(function(button)
            local field = getGamePadWidgets()[gamePadIndex]
            local value = field and field.type == "AtEditBox" and tonumber(field:GetText())
            local step = ({ PADDLEFT = -1, PADDRIGHT = 1, PADDUP = 0.1, PADDDOWN = -0.1 })[button]
            if not value or button == "PAD1" or button == "PAD2" then
                setGamePadMode(nil)
            elseif step then
                local text = tostring(math.floor((value + step) * 10 + 0.5) / 10)
                field:SetText(text)
                field:Fire("OnEnterPressed", text)
            end
        end, GAMEPAD_HINTS.Number)
    elseif widget.type == "AtEditBox" or widget.type == "AtMultiLineEditBox" then
        widget:SetFocus()
    elseif widget.type == "AtCountdownZoom" then
        -- the lanes are rendered again once the view is done, not while it changes
        local lanes = widget.parent
        setGamePadMode(function(button)
            local from, to = lanes.model.zoom, lanes.model.viewEnd or 0
            local span = from - to
            if button == "PADDLEFT" or button == "PADDRIGHT" then
                -- the time left runs out to the right
                local shift = span / 10 * (button == "PADDLEFT" and 1 or -1)
                shift = math.max(-to, math.min(lanes.zoomLimit - from, shift))
                lanes:SetView(from + shift, to + shift, false)
            elseif button == "PADDUP" or button == "PADDDOWN" then
                span = math.max(1, math.min(lanes.zoomLimit, span * (button == "PADDUP" and 0.8 or 1.25)))
                from = math.min(lanes.zoomLimit, to + span)
                lanes:SetView(from, from - span, false)
            elseif button == "PAD1" or button == "PAD2" then
                setGamePadMode(nil)
                lanes:SetView(from, to, true)
            end
        end, GAMEPAD_HINTS.Zoom)
    elseif widget.type == "AtMediaPicker" then
        widget:OpenList()
        setGamePadMode(function(button)
            if button == "PADDUP" or button == "PADDDOWN" then
                if not widget:StepList(button == "PADDUP" and -1 or 1) then
                    setGamePadMode(nil)
                end
            elseif button == "PAD1" or button == "PAD2" then
                widget:CloseList(button == "PAD1")
                setGamePadMode(nil)
            end
        end, GAMEPAD_HINTS.List)
    elseif widget.type == "AtCountdownLaneItem" then
        widget.parent.gamePadItem = widget.frame
        widget.frame:Click()
        widget.parent.gamePadItem = nil
    elseif widget.type == "AtSlider" then
        -- left and right change it, also where they would pick the widget beside it
        setGamePadMode(function(button)
            if button == "PADDLEFT" or button == "PADDRIGHT" then
                changeWidget(widget, button == "PADDLEFT" and -1 or 1)
            elseif button == "PAD1" or button == "PAD2" then
                setGamePadMode(nil)
            end
        end, GAMEPAD_HINTS.Change)
    else
        widget.frame:Click()
        if widget.type == "AtColorPicker" and ColorPickerFrame:IsShown() then
            colorPickerOwner = gamePadRoot and gamePadRoot.frame or window.frame
            colorPickerOwner:EnableGamePadButton(false)
            if window then window.frame:EnableGamePadButton(false) end
            if not colorPickerHooked then
                colorPickerHooked = true
                ColorPickerFrame:HookScript("OnHide", function()
                    local owner = colorPickerOwner
                    colorPickerOwner = nil
                    if owner and (gamePadRoot and owner == gamePadRoot.frame or not gamePadRoot and window and owner == window.frame) then
                        owner:EnableGamePadButton(C_GamePad.IsEnabled())
                    end
                    if window then
                        window.frame:EnableGamePadButton(C_GamePad.IsEnabled() and not gamePadRoot)
                    end
                end)
            end
        end
    end
end

local focusPage = function()
    gamePadFocus = true
    gamePadWidget, gamePadIndex = nil, 1
    for index, widget in ipairs(getGamePadWidgets()) do
        if widget.type ~= "AtEditBox" and widget.type ~= "AtMultiLineEditBox" then
            gamePadIndex = index
            break
        end
    end
    refocus()
end

---a window opened from a page that a gamepad picks from instead of the settings window, nil as it closes
---@param root table|nil
private.SetGamePadRoot = function(root)
    setGamePadMode(nil)
    if gamePadRoot and gamePadRoot.frame.EnableGamePadButton then
        gamePadRoot.frame:EnableGamePadButton(false)
    end
    gamePadRoot = root
    local enabled = C_GamePad ~= nil and C_GamePad.IsEnabled()
    if window and window.frame.EnableGamePadButton then
        window.frame:EnableGamePadButton(enabled and not root)
    end
    private.UpdateTimingsEditorGamePad()
    local editor = private.TIMINGS_EDITOR_WINDOW
    if root and editor and editor.frame.EnableGamePadButton then
        editor.frame:EnableGamePadButton(false)
    end
    if root and root.frame.EnableGamePadButton then
        root.frame:EnableGamePadButton(enabled)
        root.frame:SetScript("OnGamePadButtonDown", onGamePadButton)
    end
    if enabled and (root or isSettingsShown()) then
        C_Timer.After(0, focusPage)
    else
        gamePadFocus = false
        if gamePadRing then
            gamePadRing:Hide()
        end
    end
end

---shows the page step pages below the one shown, as picking it in the navigation
---@param step number
local stepPage = function(step)
    local keys, index = {}, 1
    for _, page in ipairs(pages) do
        if not isHidden(page) then
            table.insert(keys, page.key)
            if page == currentPage then
                index = #keys
            end
        end
    end
    window:Fire("OnPageSelected", keys[(index - 1 + step) % #keys + 1])
    focusPage()
end

---@param button string
onGamePadButton = function(_, button)
    if private.OnTourGamePadButton(button) then return end
    gamePadFocus = true
    local picked = tContains(getGamePadWidgets(), gamePadWidget) and gamePadWidget
    if gamePadMode and (not picked or picked.disabled) then
        setGamePadMode(nil)
    end
    if gamePadMode then
        gamePadMode(button)
    elseif button == "PADDUP" then
        moveFocus(0, 1)
    elseif button == "PADDDOWN" then
        moveFocus(0, -1)
    elseif button == "PADDLEFT" or button == "PADDRIGHT" then
        local step = button == "PADDLEFT" and -1 or 1
        if not moveFocus(step, 0) then
            changeWidget(gamePadWidget, step)
        end
    elseif button == "PAD1" then
        if picked then
            useWidget(picked)
        end
    elseif button == "PAD2" then
        -- leaves a text field first, then a window opened from the page
        local focus = GetCurrentKeyBoardFocus()
        if focus then
            focus:ClearFocus()
        elseif gamePadRoot and gamePadRoot.closeButton then
            gamePadRoot.closeButton:Click()
        elseif gamePadRoot then
            gamePadRoot.frame:Hide()
        else
            window.frame:Hide()
        end
    elseif button == "PAD3" then
        local reset = isSettingsShown() and not gamePadRoot and window.frame.Details.Reset
        local remove = gamePadRoot and gamePadRoot.frame.Remove
        if picked and picked.type == "AtCountdownLaneItem" then
            -- a right click starts a rule at the time clicked, the middle of the block here
            picked.parent.gamePadItem = picked.frame
            picked.frame:Click("RightButton")
            picked.parent.gamePadItem = nil
        elseif remove and remove:IsShown() then
            remove:Click()
        elseif picked and picked.type == "AtCountdownSituation" then
            picked:Fire("OnRemove")
        elseif reset and reset:IsShown() then
            reset.onReset()
        end
    elseif gamePadRoot or not isSettingsShown() then
        return
    elseif button == "PAD4" then
        setTestRunning(not testRunning)
    elseif button == "PADLSHOULDER" or button == "PADRSHOULDER" then
        stepPage(button == "PADLSHOULDER" and -1 or 1)
    elseif button == "PADLTRIGGER" or button == "PADRTRIGGER" then
        local history = window.frame.Details[button == "PADLTRIGGER" and "Undo" or "Redo"]
        if history:IsShown() and history.onClick then
            history.onClick()
        end
    elseif button == "PADLSTICK" then
        window:Fire("OnMoveClicked")
    elseif button == "PADRSTICK" then
        local reset = window.frame.Details.ResetPage
        if reset:IsShown() then
            reset.onReset()
        end
    end
    -- what the button did can have rendered the widgets again
    C_Timer.After(0, refocus)
end

local updateGamePad = function()
    if not (C_GamePad and window.frame.EnableGamePadButton) then return end
    gamePadEnabled = C_GamePad.IsEnabled()
    window.frame:EnableGamePadButton(gamePadEnabled and not gamePadRoot and not colorPickerOwner)
    if gamePadEnabled then
        setGamePadMode(nil)
    else
        window:SetGamePadHints("")
    end
end

local createWindow = function()
    detectNewSettings()
    window = AceGUI:Create("AtSettingsWindow")
    local header = AceGUI:Create("SimpleGroup")
    header:SetLayout("List")
    window:AddChild(header)
    local scroll = AceGUI:Create("AtScrollFrame")
    scroll:SetLayout("List")
    window:AddChild(scroll)
    setNavigation()
    window:SetCallback("OnPageSelected", function(_, _, key)
        if searchTimer then
            searchTimer:Cancel()
        end
        searchText = ""
        window:ClearSearch()
        showPage(key)
    end)
    window:SetCallback("OnSearch", function(_, _, text)
        searchText = text
        if searchTimer then
            searchTimer:Cancel()
        end
        searchTimer = C_Timer.NewTimer(variables.searchDelay, rerender)
    end)
    window:SetCallback("OnTestClicked", function()
        setTestRunning(not testRunning)
    end)
    -- the window comes back when Edit Mode closes
    window:SetCallback("OnMoveClicked", function()
        if InCombatLockdown() or not EditModeManagerFrame then return end
        window.frame:Hide()
        ShowUIPanel(EditModeManagerFrame)
    end)
    -- a label set while the window grows in is laid out at the size it grows from and keeps it, so the labels are set
    -- again once the window has its full size
    window.frame.AtShowAnimation:HookScript("OnFinished", function()
        for _, entry in ipairs(rendered) do
            local label = entry.widget.frame.Label
            local text = label:GetText()
            label:SetText("")
            label:SetText(text)
        end
    end)
    if window.frame.EnableGamePadButton then
        window.frame:SetScript("OnGamePadButtonDown", onGamePadButton)
    end
    window.frame:HookScript("OnHide", function()
        gamePadFocus = false
        gamePadMode = nil
        if gamePadRing then
            gamePadRing:Hide()
        end
        setShownPage(nil)
        if testRunning then
            setTestRunning(false)
        end
        if wasEditModeOpen and not InCombatLockdown() then
            ShowUIPanel(EditModeManagerFrame)
        else
            hiddenAt = GetTime()
        end
        wasEditModeOpen = false
    end)
    -- the values shown are the ones of the theme they were rendered in, so another theme renders them again,
    -- after the theme's widgets are drawn; a page with content of its own keeps it up to date itself. The themed are
    -- held weakly, the window holds it
    window.AtThemed = {
        ApplySettings = function()
            if window.frame:IsShown() and renderedThemeKey ~= private.GetCurrentThemeKey() then
                renderedThemeKey = private.GetCurrentThemeKey()
                if searchText ~= "" or not (shownPage and shownPage.Render) then
                    C_Timer.After(0, rerender)
                else
                    -- its rows can still show or hide with the theme (the Theme page's glass and weather rows)
                    C_Timer.After(0, refreshRows)
                end
            end
        end
    }
    private.RegisterThemed(window.AtThemed)
end

---the settings window, nil until it was opened once
---@return AtSettingsWindow|nil
private.GetSettingsWindow = function()
    return window
end

---@return string|nil -- nil while nothing or search results are shown
private.GetShownSettingsPage = function()
    return shownPage and shownPage.key
end

---@return boolean
private.IsSettingsTestRunning = function()
    return testRunning
end

private.StopSettingsTest = function()
    if testRunning then
        setTestRunning(false)
    end
end

---the dot of a changed theme value shown, when none is changed the first theme value shows its dot until
---private.RefreshSettingRows
---@return Frame|nil
private.GetChangedSettingDot = function()
    local first
    for _, entry in ipairs(rendered) do
        if entry.row.themePath then
            if isModified(entry.row) then
                return entry.widget.frame.DotHover
            end
            first = first or entry
        end
    end
    if first then
        first.widget:SetChanged(true)
        return first.widget.frame.DotHover
    end
end

---the button of the first Button row shown that the tour may point at
---@return Frame|nil
private.GetFirstSettingButton = function()
    for _, entry in ipairs(rendered) do
        if entry.row.kind == "Button" and not entry.row.skipTour then
            return entry.widget.children[1].frame
        end
    end
end

private.RefreshSettingRows = function()
    refreshRows()
end

private.closeSettings = function()
    if window then
        window.frame:Hide()
    end
end

---opens the settings window on the page of key, the last page shown without one
---@param key string|nil
private.openSettings = function(key)
    if not window then
        createWindow()
    end
    if EditModeManagerFrame and EditModeManagerFrame:IsShown() then
        wasEditModeOpen = true
        HideUIPanel(EditModeManagerFrame)
    end
    window.frame:Show()
    updateGamePad()
    searchText = ""
    window:ClearSearch()
    showPage(key or (currentPage and currentPage.key))
    if gamePadEnabled then
        focusPage()
    end
end

-- the window makes way for Edit Mode, also when opening Edit Mode already closed it, and comes back after it
LibEditMode:RegisterCallback('enter', function()
    if window and (window.frame:IsShown() or hiddenAt == GetTime()) then
        reopenAfterEditMode = true
        window.frame:Hide()
    end
end)

LibEditMode:RegisterCallback('exit', function()
    if reopenAfterEditMode then
        reopenAfterEditMode = false
        C_Timer.After(0, function()
            private.openSettings()
        end)
    end
end)

---/at test labels: doubles every text of the settings window to see how long translations fit
private.toggleLongSettingsLabels = function()
    longLabels = not longLabels
    if window then
        setNavigation()
        rerender()
    end
end

private.RegisterWindowState("settings", function()
    if window and window.frame:IsShown() then
        return { page = currentPage and currentPage.key }
    end
end, function(state)
    private.openSettings(state.page)
end)
