local appName, app = ...
---@class AbilityTimeline
local private = app
local AceGUI = LibStub("AceGUI-3.0")

local MAX_DEBUG_LINES = 1000
local LINE_HEIGHT = 14
local debugLines = {}
local debugLineCount = 0
local debugWindow
local scrollOffset = 0
local updatingScrollBar = false

-- secrets can only be displayed through fontstrings (editboxes reject them) so every visible line gets its own
-- fontstring and scrolling just refills them, similar to the dbm debug log
local updateDebugWindow = function()
    if not debugWindow or not debugWindow.frame:IsShown() then return end
    local viewport = debugWindow.viewport
    local visibleLines = math.max(1, math.floor(viewport:GetHeight() / LINE_HEIGHT))
    local maxOffset = math.max(0, #debugLines - visibleLines)
    scrollOffset = math.max(0, math.min(scrollOffset, maxOffset))
    updatingScrollBar = true
    debugWindow.scrollBar:SetMinMaxValues(0, maxOffset)
    debugWindow.scrollBar:SetValue(scrollOffset)
    updatingScrollBar = false
    for i = 1, visibleLines do
        local line = viewport.lines[i]
        if not line then
            line = viewport:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
            line:SetJustifyH("LEFT")
            line:SetWordWrap(false)
            line:SetPoint("TOPLEFT", viewport, "TOPLEFT", 4, -(i - 1) * LINE_HEIGHT)
            line:SetPoint("RIGHT", viewport, "RIGHT")
            line:SetHeight(LINE_HEIGHT)
            line.background = viewport:CreateTexture(nil, "BACKGROUND")
            line.background:SetPoint("TOPLEFT", viewport, "TOPLEFT", 0, -(i - 1) * LINE_HEIGHT)
            line.background:SetPoint("RIGHT", viewport, "RIGHT")
            line.background:SetHeight(LINE_HEIGHT)
            viewport.lines[i] = line
        end
        local entry = debugLines[#debugLines - scrollOffset - i + 1]
        if entry then
            line:SetText(string.format("#%d  %s", entry.number, entry.text))
            -- stripes follow the entry number so a line keeps its color while scrolling
            line.background:SetColorTexture(1, 1, 1, entry.number % 2 == 0 and 0.08 or 0)
        else
            line:SetText("")
            line.background:SetColorTexture(0, 0, 0, 0)
        end
    end
    for i = visibleLines + 1, #viewport.lines do
        viewport.lines[i]:SetText("")
        viewport.lines[i].background:SetColorTexture(0, 0, 0, 0)
    end
end

---Adds a line to the debug log window, lines may contain secrets since they are only formatted and displayed
---@param line string
private.DebugLog = function(line)
    debugLineCount = debugLineCount + 1
    table.insert(debugLines, { number = debugLineCount, text = line })
    if #debugLines > MAX_DEBUG_LINES then
        table.remove(debugLines, 1)
    end
    if scrollOffset > 0 then
        scrollOffset = scrollOffset + 1 -- keep the scrolled to lines in place
    end
    updateDebugWindow()
end

---Opens a window showing the debug log with the newest lines on top
private.openDebugLog = function()
    if not debugWindow then
        debugWindow = AceGUI:Create("Frame")
        debugWindow:SetTitle("AbilityTimeline Debug")
        debugWindow:SetStatusText("Newest entries on top, scroll with the mouse wheel. Secrets can't be copied, take screenshots instead")
        debugWindow:SetWidth(1000)
        debugWindow:SetHeight(600)
        local onMouseWheel = function(_, delta)
            scrollOffset = scrollOffset - delta * 3
            updateDebugWindow()
        end

        -- vertical sliders have their minimum at the top which matches newest lines being on top
        local scrollBar = CreateFrame("Slider", nil, debugWindow.content)
        scrollBar:SetPoint("TOPRIGHT", debugWindow.content, "TOPRIGHT")
        scrollBar:SetPoint("BOTTOMRIGHT", debugWindow.content, "BOTTOMRIGHT")
        scrollBar:SetWidth(16)
        scrollBar:SetOrientation("VERTICAL")
        scrollBar:SetThumbTexture("Interface\\Buttons\\UI-ScrollBar-Knob")
        scrollBar:GetThumbTexture():SetSize(16, 24)
        scrollBar:SetValueStep(1)
        scrollBar:SetObeyStepOnDrag(true)
        local scrollBarBackground = scrollBar:CreateTexture(nil, "BACKGROUND")
        scrollBarBackground:SetAllPoints(scrollBar)
        scrollBarBackground:SetColorTexture(0, 0, 0, 0.5)
        scrollBar:EnableMouseWheel(true)
        scrollBar:SetScript("OnMouseWheel", onMouseWheel)
        scrollBar:SetScript("OnValueChanged", function(_, value)
            if updatingScrollBar then return end
            scrollOffset = math.floor(value + 0.5)
            updateDebugWindow()
        end)
        debugWindow.scrollBar = scrollBar

        local viewport = CreateFrame("Frame", nil, debugWindow.content)
        viewport:SetPoint("TOPLEFT", debugWindow.content, "TOPLEFT")
        viewport:SetPoint("BOTTOMRIGHT", scrollBar, "BOTTOMLEFT", -4, 0)
        viewport:SetClipsChildren(true)
        viewport:EnableMouseWheel(true)
        viewport:SetScript("OnMouseWheel", onMouseWheel)
        viewport:SetScript("OnSizeChanged", updateDebugWindow)
        viewport.lines = {}
        debugWindow.viewport = viewport
    end
    debugWindow:Show()
    updateDebugWindow()
end

---Prints debug value to chat or adds table to Devtool (when installed) when debugmode is enabled
---@param debugValue any --value to print to chat or add to DevTool
---@param tableName string? --optional name for the table when using DevTool
private.Debug = function(debugValue, tableName)
    if private.db.profile.debugMode then
        if type(debugValue) == "table" then
            if DevTool then
                DevTool:AddData(debugValue, tableName or "DebugTable")
                return
            else
                print("AbilityTimeline DEBUG (" .. tableName .. "):")
                for k, v in pairs(debugValue) do
                    print("  " .. tostring(k) .. " = " .. tostring(v))
                end
            end
        else
            print("AbilityTimeline DEBUG: " .. tostring(debugValue))
        end
    end
end

---prints every shown texture under the mouse in the window under it, to find stray art
private.debugTexturesUnderMouse = function()
    local printTextures
    printTextures = function(frame)
        for _, region in ipairs({ frame:GetRegions() }) do
            if region:IsObjectType("Texture") and region:IsVisible() and region:IsMouseOver() then
                local r, g, b, a = region:GetVertexColor()
                print(("%s | %s | %s | %.2f %.2f %.2f %.2f"):format(region:GetDebugName(),
                    tostring(region:GetAtlas() or region:GetTexture()), region:GetDrawLayer(), r, g, b, a))
            end
        end
        for _, child in ipairs({ frame:GetChildren() }) do
            if child:IsVisible() then
                printTextures(child)
            end
        end
    end
    local foci = GetMouseFoci and GetMouseFoci() or { GetMouseFocus() }
    for _, focus in ipairs(foci) do
        local window = focus
        while window:GetParent() and window:GetParent() ~= UIParent do
            window = window:GetParent()
        end
        printTextures(window)
    end
end

local themeDebugWindow

local openThemeDebugReport = function(report)
    if not themeDebugWindow then
        themeDebugWindow = AceGUI:Create("Frame")
        themeDebugWindow:SetTitle(private.getLocalisation("ThemeDebugTitle"))
        themeDebugWindow:SetStatusText(private.getLocalisation("ThemeDebugCopyHint"))
        themeDebugWindow:SetWidth(1000)
        themeDebugWindow:SetHeight(600)
        themeDebugWindow:SetLayout("Fill")
        themeDebugWindow:SetCallback("OnClose", function(widget)
            AceGUI:Release(widget)
            themeDebugWindow = nil
        end)
        local text = AceGUI:Create("MultiLineEditBox")
        text:SetLabel("")
        text:DisableButton(true)
        themeDebugWindow:AddChild(text)
        themeDebugWindow.report = text
    end
    themeDebugWindow.report:SetText(report)
    themeDebugWindow:Show()
end

---captures the theme in use, the player's changes and the timeline's actual art in a copyable debug window
private.debugTheme = function()
    local lines = {}
    local print = function(...)
        local values = {}
        for index = 1, select("#", ...) do values[index] = tostring((select(index, ...))) end
        local line = table.concat(values, " ")
        lines[#lines + 1] = line
        private.DebugLog(line)
    end
    local settings = private.GetThemeSettings()
    print("theme:", private.GetCurrentThemeKey(), "saved:", settings.key, "resolves to:", private.GetSavedThemeKey(), "animations:", private.GetAnimationLevel())
    local printTable
    printTable = function(value, indent)
        for k, v in pairs(value) do
            if type(v) == "table" then
                print(indent .. tostring(k) .. ":")
                printTable(v, indent .. "  ")
            else
                print(indent .. tostring(k) .. " = " .. tostring(v))
            end
        end
    end
    print("changes:")
    printTable(settings.modifications[private.GetCurrentThemeKey()] or {}, "  ")
    print("timeline style:")
    printTable(private.GetElementStyle("Timeline"), "  ")
    local frame = private.TIMELINE_FRAME and private.TIMELINE_FRAME.frame
    if frame then
        print("timeline frame alpha:", frame:GetAlpha())
        print("palette Body:", ("%.3f %.3f %.3f %.3f"):format(private.ThemeApply.Color("Body")))
        local backdrop = frame:GetBackdrop()
        if backdrop then
            print("drawn backdrop:", tostring(backdrop.bgFile), tostring(backdrop.edgeFile),
                ("%.2f %.2f %.2f %.2f"):format(frame:GetBackdropColor()))
        else
            print("drawn backdrop: none")
        end
        for _, key in ipairs({ "Background", "Edge", "Wash", "Now", "Header", "Mark", "Flow" }) do
            local texture = frame[key]
            print(key, texture:IsShown(), tostring(texture:GetTexture()), ("%.2f %.2f %.2f %.2f"):format(texture:GetVertexColor()))
        end
        print("background alpha:", frame.Background:GetAlpha(), "blend:", frame.Background:GetBlendMode(),
            "desaturated:", frame.Background:IsDesaturated())
    end
    openThemeDebugReport(table.concat(lines, "\n"))
end
