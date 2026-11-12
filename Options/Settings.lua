local appName, app = ...
---@class AbilityTimeline
local private = app
local AceGUI = LibStub("AceGUI-3.0")
local LibEditMode = LibStub("LibEditMode")
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

---why the row of entry is disabled, its own reason first, then its page's
---@param entry table
---@return string|nil
local getDisabledReason = function(entry)
    for _, item in ipairs({ entry.row, entry.page }) do
        if isDisabled(item) and item.disabledReason then
            return item.disabledReason()
        end
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
        private.OnTourEvent("page" .. page.key)
    end
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
    window:ShowDetails(display(row.name), display(row.desc), onReset, display(getDisabledReason(entry)))
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
    setShownPage(page)
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
    if page.ResetPage then window:SetResetPage(page.ResetPage, display(page.resetText))
    else
        window:SetResetPage(#themePaths > 0 and function()
            for _, path in ipairs(themePaths) do
                private.ResetThemeModifications(path)
            end
            rerender()
        end or nil)
    end
    if page.GetHistory then window:SetPageHistory(page.GetHistory()) else window:SetPageHistory(nil) end
    render(rows, page.key, page.Render, page.pinned, function() return page end)
    window:ShowDetails(display(page.name), display(page.desc), nil,
        display(isDisabled(page) and page.disabledReason and page.disabledReason() or page.notice and page.notice() or nil))
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
    window.frame:HookScript("OnHide", function()
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
    searchText = ""
    window:ClearSearch()
    showPage(key or (currentPage and currentPage.key))
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
