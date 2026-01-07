local addonName, private = ...
local AceGUI = LibStub("AceGUI-3.0")
local Type = "AtBigIcon"
local Version = 1
local variables = {
    zoom = 0.7,
    cooldown_scale = 2,
    icon_text_width = 95,
    icon_text_offset_x = 0,
    icon_text_offset_y = -10,
}

private.BIG_ICON_SIZE = 100
private.BIG_ICON_MARGIN = 10


---@param self AtBigIcon
local function OnAcquire(self)
end

---@param self AtBigIcon
local function OnRelease(self)
    self.frame.icon:SetTexture(nil)
    self.frame.iconText:SetText("")
end

---Handles the cooldown display for a given frame (the frame needs to be the frame of a AtAbilitySpellIcon widget)
---@param self frame
---@param remainingTime number
local HandleCooldown        = function(self, remainingTime)
	local roundedTime = math.ceil(remainingTime)
	self.frame.CooldownText:SetText(roundedTime)
	if private.db.profile.cooldown_settings.cooldown_highlight and private.db.profile.cooldown_settings.cooldown_highlight.enabled then
		for _,value in pairs(private.db.profile.cooldown_settings.cooldown_highlight.highlights) do
			local time, color = value.time, value.color
			if (remainingTime <= time) then
				self.frame.CooldownText:SetTextColor(color.r, color.g, color.b)
				if value.useGlow then
					private.EnableGlow(self, value.glowType, time, value.glowColor)
				end
				return
			end
		end
	end
	if private.db.profile.cooldown_settings.cooldown_color then
		self.frame.CooldownText:SetTextColor(
			private.db.profile.cooldown_settings.cooldown_color.r,
			private.db.profile.cooldown_settings.cooldown_color.g,
			private.db.profile.cooldown_settings.cooldown_color.b
		)
	else
		self.CooldownText:SetTextColor(1, 1, 1)
	end
end

local function ApplySettings(self)
	-- Apply settings to the icon
	if private.db.profile.icon_settings and private.db.profile.icon_settings.size then
		self.frame:SetSize(private.db.profile.icon_settings.size, private.db.profile.icon_settings.size)
	else
		self.frame:SetSize(variables.IconSize.width, variables.IconSize.height)
	end
	if private.db.profile.icon_settings and private.db.profile.icon_settings.TextOffset then
		handleAnchors(self.frame, self.isStopped)
	end
	if private.db.profile.text_settings and private.db.profile.text_settings.font and private.db.profile.text_settings.fontSize then
		self.frame.SpellName:SetFont(SharedMedia:Fetch("font", private.db.profile.text_settings.font),
			private.db.profile.text_settings.fontSize, "OUTLINE")
	elseif private.db.profile.text_settings and private.db.profile.text_settings.fontSize then
		self.frame.SpellName:SetFontHeight(private.db.profile.text_settings.fontSize)
	end

	if private.db.profile.cooldown_settings and private.db.profile.cooldown_settings.font and private.db.profile.cooldown_settings.fontSize then
		self.frame.Cooldown:SetFont(SharedMedia:Fetch("font", private.db.profile.cooldown_settings.font),
			private.db.profile.cooldown_settings.fontSize, "OUTLINE")
	elseif private.db.profile.cooldown_settings and private.db.profile.cooldown_settings.fontSize then
		self.frame.Cooldown:SetFontHeight(private.db.profile.cooldown_settings.fontSize)
	end

	if  private.db.profile.text_settings and  private.db.profile.text_settings.defaultColor then
		self.frame.SpellName:SetTextColor(
			private.db.profile.text_settings.defaultColor.r,
			private.db.profile.text_settings.defaultColor.g,
			private.db.profile.text_settings.defaultColor.b
		)
	end

	if not self.frame.SpellIcon.zoomApplied or self.frame.SpellIcon.zoomApplied ~= (1-private.db.profile.icon_settings.zoom) then
		if self.frame.SpellIcon.zoomApplied then
			private.ResetZoom(self.frame.SpellIcon)
		end
		private.SetZoom(self.frame.SpellIcon, 1-private.db.profile.icon_settings.zoom)
		self.frame.SpellIcon.zoomApplied = 1-private.db.profile.icon_settings.zoom
	end

	for i, edges in ipairs(self.frame.DispellTypeBorderEdges) do
		for _, edgeTexture in ipairs(edges) do
			if private.db.profile.icon_settings.dispellBorders then
				edgeTexture:Show()
			else
				edgeTexture:Hide()
			end
		end
	end
	for i,texture in ipairs(self.frame.DispellTypeIcons) do
		if private.db.profile.icon_settings.dispellIcons then
			texture:Show()
		else
			texture:Hide()	
		end
	end
	for i,texture in ipairs(self.frame.DangerIcon) do
		if private.db.profile.icon_settings.dangerIcon then
			texture:Show()
		else
			texture:Hide()	
		end
	end
	if private.db.profile.text_settings.useBackground then
		local texture = SharedMedia:Fetch("background", private.db.profile.text_settings.backgroundTexture)
		self.frame.SpellNameBackground:SetPoint("LEFT", self.frame.SpellName, "LEFT", -private.db.profile.text_settings.backgroundTextureOffset.x, 0)
		self.frame.SpellNameBackground:SetPoint("RIGHT", self.frame.SpellName, "RIGHT", private.db.profile.text_settings.backgroundTextureOffset.x, 0)
		self.frame.SpellNameBackground:SetPoint("TOP", self.frame.SpellName, "TOP", 0, private.db.profile.text_settings.backgroundTextureOffset.y)
		self.frame.SpellNameBackground:SetPoint("BOTTOM", self.frame.SpellName, "BOTTOM", 0, -private.db.profile.text_settings.backgroundTextureOffset.y)
		self.frame.SpellNameBackground:SetTexture(texture)
		self.frame.SpellNameBackground:Show()
	else
		self.frame.SpellNameBackground:Hide()
	end
end

local SetEventInfo = function(widget, eventInfo)
    widget.eventInfo = eventInfo
    widget.frame.Cooldown:SetCooldown(GetTime(), eventInfo.duration - C_EncounterTimeline.GetEventTimeElapsed(eventInfo.id))
    widget.frame:SetScript("OnUpdate", function(self)
        local remaining = C_EncounterTimeline.GetEventTimeRemaining(eventInfo.id)
        local state = C_EncounterTimeline.GetEventState(eventInfo.id)
        if state ~= private.ENCOUNTER_STATES.Active then -- this should be handled better but for now we just hide non active states from the ui
            remaining = 0
        end
        if remaining > 0 then
            HandleCooldown(widget, remaining)
        else
            private.HIGHLIGHT_EVENTS.BigIcons[eventInfo.id] = nil
            for i, f in ipairs(private.BIG_ICONS) do
                if f == widget then
                    table.remove(private.BIG_ICONS, i)
                    break
                end
            end
            widget:Release()
            private.evaluateBigIconPositions()
        end
    end)


    local xOffset = (private.BIG_ICON_SIZE + private.BIG_ICON_MARGIN) * (#private.BIG_ICONS)
    widget.frame:SetPoint("LEFT", private.BIGICON_FRAME.frame, "LEFT", xOffset, 0)
    widget.frame.xOffset = xOffset
    widget.frame.icon:SetAllPoints(widget.frame)
    widget.frame.icon:SetTexture(eventInfo.iconFileID)
    widget.frame.iconText:SetText(eventInfo.spellName)
    widget.frame:Show()
end

local function Constructor()
    local count = AceGUI:GetNextWidgetNum(Type)
    local frame = CreateFrame("Frame", "BIGICON"..count, private.BIGICON_FRAME.frame)
    frame.Cooldown = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
    frame.Cooldown:SetDrawSwipe(true)
    frame.Cooldown:SetDrawEdge(true)
    frame.Cooldown:SetAllPoints(frame)
    frame.Cooldown:SetScale(variables.cooldown_scale)
    frame.Cooldown:SetHideCountdownNumbers(true)

    frame.CooldownText = frame.Cooldown:CreateFontString(nil, "OVERLAY", "SystemFont_Shadow_Med3")
    frame.CooldownText:SetPoint("CENTER", frame.Cooldown, "CENTER", 0, 0)
    
    frame:SetSize(private.BIG_ICON_SIZE, private.BIG_ICON_SIZE)

    frame.icon = frame:CreateTexture(nil, "OVERLAY")
    private.SetZoom(frame.icon, variables.zoom)
    frame.iconText = frame:CreateFontString(nil, "OVERLAY", "SystemFont_Shadow_Med3")
    frame.iconText:SetWidth(variables.icon_text_width)
    frame.iconText:SetWordWrap(true)
    frame.iconText:SetPoint("TOP", frame, "BOTTOM",variables.icon_text_offset_x, variables.icon_text_offset_y)
    frame:Show()


    ---@class AtBigIcon : AceGUIWidget
    local widget = {
        OnAcquire = OnAcquire,
        OnRelease = OnRelease,
        type = Type,
        count = count,
        frame = frame,
        SetEventInfo = SetEventInfo,
    }

    return AceGUI:RegisterAsWidget(widget)
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)
