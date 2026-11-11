local appName, app = ...
---@class AbilityTimeline
local private = app
local AceGUI = LibStub("AceGUI-3.0")
local CustomGlow = LibStub("LibCustomGlow-1.0")
local ThemeApply = private.ThemeApply

-- the welcome tour's callout: a small window in the theme's dialog style next to what a step is about, which glows,
-- while the screen around it is dimmed
local variables = {
    width = 320,
    padding = 16,
    headerHeight = 34,
    buttonHeight = 24,
    -- between the callout and what it is about
    gap = 16,
    dimAlpha = 0.5,
    -- the clear space around what is dimmed around
    dimMargin = 4,
    glow = { lines = 12, frequency = 0.25, thickness = 2, offset = 3 },
    -- a target wider than this share of the screen gets the callout above or below it, else beside it
    wideShare = 0.4,
}
local GLOW_KEY = "AtTour"

---the rectangle of every target with a margin around it, in the coordinates of frame
---@param targets Frame[]
---@param frame Frame
---@return table[] -- { left, bottom, right, top }
local getRects = function(targets, frame)
    local rects = {}
    local margin = variables.dimMargin
    for _, target in ipairs(targets) do
        local left, bottom, width, height = target:GetRect()
        if left then
            local scale = target:GetEffectiveScale() / frame:GetEffectiveScale()
            left, bottom = left * scale, bottom * scale
            table.insert(rects, { left - margin, bottom - margin, left + width * scale + margin,
                bottom + height * scale + margin })
        end
    end
    return rects
end

---dark parts around each target, which stay clear; they follow them while they are dragged. The screen is cut into
---bands at every target's top and bottom, each band is dark where no target crosses it
---@return Frame
local createDim = function()
    local dim = CreateFrame("Frame", nil, UIParent)
    dim:Hide()
    dim:SetAllPoints(UIParent)
    dim.Parts = {}
    local count
    local addPart = function(x, y, width, height)
        count = count + 1
        local part = dim.Parts[count]
        if not part then
            part = dim:CreateTexture(nil, "BACKGROUND")
            part:SetColorTexture(0, 0, 0, variables.dimAlpha)
            dim.Parts[count] = part
        end
        part:ClearAllPoints()
        part:SetPoint("BOTTOMLEFT", dim, "BOTTOMLEFT", x, y)
        part:SetSize(width, height)
        part:Show()
    end
    dim:SetScript("OnUpdate", function()
        local rects = getRects(dim.targets, dim)
        local screenWidth, screenHeight = dim:GetSize()
        local edges = { 0, screenHeight }
        for _, rect in ipairs(rects) do
            table.insert(edges, math.max(0, math.min(screenHeight, rect[2])))
            table.insert(edges, math.max(0, math.min(screenHeight, rect[4])))
        end
        table.sort(edges)
        count = 0
        for i = 1, #edges - 1 do
            local low, high = edges[i], edges[i + 1]
            if high > low then
                local spans = {}
                for _, rect in ipairs(rects) do
                    if rect[2] <= low and rect[4] >= high then
                        table.insert(spans, rect)
                    end
                end
                table.sort(spans, function(a, b) return a[1] < b[1] end)
                local x = 0
                for _, span in ipairs(spans) do
                    if span[1] > x then
                        addPart(x, low, span[1] - x, high - low)
                    end
                    x = math.max(x, span[3])
                end
                if x < screenWidth then
                    addPart(x, low, screenWidth - x, high - low)
                end
            end
        end
        for i = count + 1, #dim.Parts do
            dim.Parts[i]:Hide()
        end
    end)
    return dim
end

---@return table
local createCallout = function()
    local padding = variables.padding
    local frame = CreateFrame("Frame", "AbilityTimelineTourCallout", UIParent)
    frame:Hide()
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetWidth(variables.width)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)

    frame.Title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.Title:SetPoint("TOPLEFT", frame, "TOPLEFT", padding, -10)
    frame.Title:SetJustifyH("LEFT")
    frame.CloseButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    frame.Counter = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.Counter:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -40, -14)
    -- room for the counter and the close button right of it
    frame.Title:SetWidth(variables.width - padding * 2 - 80)
    frame.Title:SetWordWrap(false)
    frame.Text = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.Text:SetPoint("TOPLEFT", frame, "TOPLEFT", padding, -variables.headerHeight - padding)
    frame.Text:SetWidth(variables.width - padding * 2)
    frame.Text:SetJustifyH("LEFT")
    frame.Text:SetWordWrap(true)
    frame.Text:SetSpacing(3)

    local callout = { frame = frame }
    local createButton = function(anchor, answer)
        local button = AceGUI:Create("AtButton")
        button:SetWidth((variables.width - padding * 3) / 2)
        button.frame:SetParent(frame)
        button.frame:SetPoint(anchor, frame, anchor, anchor == "BOTTOMLEFT" and padding or -padding, padding)
        button.frame:Show()
        button:SetCallback("OnClick", function()
            callout.info[answer]()
        end)
        return button
    end
    callout.back = createButton("BOTTOMLEFT", "onBack")
    callout.next = createButton("BOTTOMRIGHT", "onNext")
    frame.CloseButton:SetScript("OnClick", function()
        callout.info.onClose()
    end)
    callout.dim = createDim()
    -- one glow around several targets together; outside of them, so a scroll frame they are in doesn't cut it off
    callout.box = CreateFrame("Frame", nil, UIParent)
    callout.box:Hide()
    local fitBox = function()
        local rects = getRects(callout.box.targets, UIParent)
        if not rects[1] then return false end
        local left, bottom, right, top = unpack(rects[1])
        for _, rect in ipairs(rects) do
            left, bottom = math.min(left, rect[1]), math.min(bottom, rect[2])
            right, top = math.max(right, rect[3]), math.max(top, rect[4])
        end
        callout.box:ClearAllPoints()
        callout.box:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, bottom)
        callout.box:SetSize(right - left, top - bottom)
        return true
    end
    callout.box:SetScript("OnUpdate", fitBox)

    -- the window grows with its text
    callout.Layout = function(self)
        frame:SetHeight(variables.headerHeight + padding * 3 + frame.Text:GetStringHeight() + variables.buttonHeight +
            padding)
    end

    ---@param info table -- { title, text, counter, back, backDisabled, next, nextDisabled, nextStyle, onBack, onNext, onClose }
    callout.SetContent = function(self, info)
        self.info = info
        frame.Title:SetText(info.title)
        frame.Text:SetText(info.text)
        frame.Counter:SetText(info.counter or "")
        self.back:SetText(info.back)
        self.back:SetDisabled(info.backDisabled == true)
        self.next:SetDisabled(info.nextDisabled == true)
        self.next:SetText(info.next)
        self.next:SetStyle(info.nextStyle or "Primary")
        self:Layout()
        frame:Show()
    end

    local startGlow = function(target)
        local glow = variables.glow
        CustomGlow.PixelGlow_Start(target, { ThemeApply.Color("Accent") }, glow.lines, glow.frequency, nil,
            glow.thickness, glow.offset, glow.offset, false, GLOW_KEY)
    end

    ---lets the targets glow and darkens everything around them, strata is the layer the dark goes up to
    ---@param targets Frame[]|nil
    ---@param strata string|nil -- FULLSCREEN without
    ---@param together boolean|nil -- one glow around all of them
    callout.Highlight = function(self, targets, strata, together)
        self:ClearHighlight()
        if not targets or #targets == 0 then return end
        callout.dim:SetFrameStrata(strata or "FULLSCREEN")
        if together then
            self.box.targets = targets
            if not fitBox() then return end
            self.box:SetFrameStrata(strata or "FULLSCREEN")
            self.box:SetFrameLevel(callout.dim:GetFrameLevel() + 10)
            self.box:Show()
            targets = { self.box }
        end
        self.targets = targets
        for _, target in ipairs(targets) do
            startGlow(target)
        end
        callout.dim.targets = targets
        callout.dim:Show()
    end

    callout.ClearHighlight = function(self)
        for _, target in ipairs(self.targets or {}) do
            CustomGlow.PixelGlow_Stop(target, GLOW_KEY)
        end
        self.targets = nil
        self.box:Hide()
        callout.dim:Hide()
    end

    ---places the callout beside anchor (or above or below a wide one) on the side with more room, side forces one,
    ---without an anchor it is centered
    ---@param anchor Frame|nil
    ---@param side string|nil -- TOP, BOTTOM, LEFT or RIGHT
    callout.Place = function(self, anchor, side)
        local x, y
        if anchor then
            x, y = anchor:GetCenter()
            -- not laid out yet, the callout stays where it is
            if not x then return end
        end
        frame:ClearAllPoints()
        if not anchor then
            frame:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
            return
        end
        local scale = anchor:GetEffectiveScale() / UIParent:GetEffectiveScale()
        if not side then
            local screenWidth, screenHeight = UIParent:GetSize()
            if anchor:GetWidth() * scale > screenWidth * variables.wideShare then
                side = y * scale > screenHeight / 2 and "BOTTOM" or "TOP"
            else
                side = x * scale > screenWidth / 2 and "LEFT" or "RIGHT"
            end
        end
        local gap = variables.gap
        if side == "TOP" then
            frame:SetPoint("BOTTOM", anchor, "TOP", 0, gap)
        elseif side == "BOTTOM" then
            frame:SetPoint("TOP", anchor, "BOTTOM", 0, -gap)
        elseif side == "LEFT" then
            frame:SetPoint("RIGHT", anchor, "LEFT", -gap, 0)
        else
            frame:SetPoint("LEFT", anchor, "RIGHT", gap, 0)
        end
    end

    callout.Hide = function(self)
        self:ClearHighlight()
        frame:Hide()
    end

    -- another theme restyles it, its fonts can make the text higher or lower and the glow takes its accent
    callout.ApplySettings = function(self)
        ThemeApply.Window(frame, private.GetWindowStyle("Dialog"), frame.CloseButton, frame.Title)
        ThemeApply.FontRole(frame.Text, "Control")
        ThemeApply.FontRole(frame.Counter, "Muted")
        self:Layout()
        for _, target in ipairs(self.targets or {}) do
            startGlow(target)
        end
    end
    callout:ApplySettings()
    private.RegisterThemed(callout)
    return callout
end

local callout

---the tour's callout, created the first time it is needed
---@return table
private.GetTourCallout = function()
    if not callout then
        callout = createCallout()
    end
    return callout
end
