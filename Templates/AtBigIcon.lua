local appName, app = ...
---@class AbilityTimeline
local private = app
local AceGUI             = LibStub("AceGUI-3.0")
local Type               = "AtBigIcon"
local Version            = 1
local variables          = {
	cooldown_scale = 2,
	icon_text_width = 95,
	icon_text_offset_x = 0,
	icon_text_offset_y = 10,
}

---handles the Text anchoring depending on the selected text anchor
---@param self Frame
---@param isStopped boolean
local handleAnchors      = function(self)
	self.SpellName:ClearAllPoints()
	local text = private.GetElementStyle("BigIcon").Text
	local relPos, anchorPos, xOffset, yOffset
	relPos = private.RELATIVE_POSITIONS[text.Anchor]
	anchorPos = text.Anchor
	local offset = text.Offset
	if relPos == 'LEFT' then
		xOffset, yOffset = offset.x, offset.y
	elseif relPos == 'RIGHT' then
		xOffset, yOffset = -offset.x, -offset.y
	elseif relPos == 'TOP' then
		xOffset, yOffset = offset.x, -offset.y
	else -- BOTTOM
		xOffset, yOffset = -offset.x, offset.y
	end
	self.SpellName:SetPoint(relPos, self, anchorPos, xOffset, yOffset)
	for _, texture in pairs(self.DangerIcon) do
		texture:ClearAllPoints()
		texture:SetPoint(relPos, self, anchorPos, 0, 0)
	end
end

---Handles the cooldown display for a given frame (the frame needs to be the frame of a AtAbilitySpellIcon widget)
---@param self frame
---@param remainingTime number
local HandleCooldown     = function(self, remainingTime)
	local roundedTime = math.ceil(remainingTime)
	self.CooldownText:SetText(roundedTime)
	-- a reminder's own glow for as long as it shows, it replaces the cooldown highlight glow
	local info = self.eventID and private.manager.getEventInfo(self.eventID)
	local glow = info and info.glow
	if glow and remainingTime > 0 then
		private.EnableGlow(self, glow, remainingTime, info.glowColor)
	end
	if private.db.profile.cooldown_settings.cooldown_highlight and private.db.profile.cooldown_settings.cooldown_highlight.enabled then
		for _, value in pairs(private.db.profile.cooldown_settings.cooldown_highlight.highlights) do
			local time, color = value.time, value.color
			if (remainingTime <= time) then
				self.CooldownText:SetTextColor(color.r, color.g, color.b)
				if value.useGlow and not glow then
					private.EnableGlow(self, value.glowType, remainingTime, value.glowColor)
				end
				return
			end
		end
	end
	self.CooldownText:SetTextColor(private.ThemeApply.Color(private.GetElementStyle("Cooldown").Font.Color))
end

---applies the event color to the spell name when enabled
---@param frame Frame
local applyEventColor = function(frame)
	if frame.eventID and private.db.profile.text_settings.useEventColor then
		local color = private.manager.getEventColor(frame.eventID)
		if color then
			frame.SpellName:SetTextColor(color.r, color.g, color.b)
		end
	end
end

local function ApplySettings(self)
	local frame = self.frame
	local style = private.GetElementStyle("BigIcon")
	local iconSettings = private.db.profile.big_icon_settings
	frame:SetFrameStrata(iconSettings.strata)
	local size = private.GetBigIconSize()
	frame:SetSize(size, size)
	handleAnchors(frame)
	private.ThemeApply.Font(frame.SpellName, style.Text.Font)
	applyEventColor(frame)
	private.ThemeApply.Font(frame.CooldownText, private.GetElementStyle("Cooldown").Font)
	local skinned = private.SyncMasque(frame)
	private.ThemeApply.IconArt(frame, frame.SpellIcon, style, frame.TextureHolder, skinned)
	if not skinned then
		frame.Cooldown:ClearAllPoints()
		frame.Cooldown:SetAllPoints(frame)
	end
	-- the swipe takes the shape of the icon's mask
	local mask = frame.iconMasked and style.Mask
	local atlas = mask and mask.Atlas and private.ThemeApply.AtlasInfo(mask.Atlas)
	frame.Cooldown:SetSwipeTexture(atlas and (atlas.file or atlas.filename) or
		mask and mask.File and private.ThemeApply.File(mask.File) or
		"Interface\\Buttons\\WHITE8X8", 0, 0, 0, 0.64)

	local borderWidth = style.BorderWidth
	if not style.Border.File then
		frame.BossModsBorderEdges[1]:SetHeight(borderWidth)
		frame.BossModsBorderEdges[2]:SetHeight(borderWidth)
		frame.BossModsBorderEdges[3]:SetWidth(borderWidth)
		frame.BossModsBorderEdges[4]:SetWidth(borderWidth)
	end
	local eventID = frame.eventID
	for i, edges in ipairs(frame.DispellTypeBorderEdges) do
		private.ThemeApply.DispelBorder(frame, i, style.Border, eventID)
		if not style.Border.File then
			edges[1]:SetHeight(borderWidth)
			edges[2]:SetHeight(borderWidth)
			edges[3]:SetWidth(borderWidth)
			edges[4]:SetWidth(borderWidth)
		end
		for _, edgeTexture in ipairs(edges) do
			edgeTexture:SetShown(iconSettings.border == private.IconBorderSettings.dispell)
		end
	end
	for i = 2, #frame.BorderGlows do
		frame.BorderGlows[i]:SetShown(iconSettings.border == private.IconBorderSettings.dispell and style.Border.Glow and true or false)
	end

	private.ThemeApply.BossModsBorder(frame, style.Border,
		iconSettings.border == private.IconBorderSettings.bossmods and private.manager.getEventBorderColor(eventID) or nil)

	local dispelIcon = style.DispelIcon
	for _, texture in ipairs(frame.DispellTypeIcons) do
		texture:SetSize(dispelIcon.Size, dispelIcon.Size)
		texture:ClearAllPoints()
		texture:SetPoint(dispelIcon.Anchor, frame.TextureHolder, dispelIcon.Anchor, dispelIcon.Offset.x,
			dispelIcon.Offset.y)
		texture:SetShown(iconSettings.dispellIcons)
	end
	for _, texture in ipairs(frame.DangerIcon) do
		texture:SetShown(iconSettings.dangerIcon)
	end

	local roleIcons = style.RoleIcons
	for i, texture in ipairs(frame.RoleIcons) do
		texture:SetSize(roleIcons.Size, roleIcons.Size)
		texture:ClearAllPoints()
		texture:SetPoint(roleIcons.Anchor, frame.TextureHolder, roleIcons.Anchor,
			roleIcons.Offset.x + (i - 1) * roleIcons.Size, roleIcons.Offset.y)
		texture:SetShown(iconSettings.roleIcons)
	end

	local background = style.Text.Background
	if background.Show then
		frame.SpellNameBackground:SetPoint("LEFT", frame.SpellName, "LEFT", -background.Offset.x, 0)
		frame.SpellNameBackground:SetPoint("RIGHT", frame.SpellName, "RIGHT", background.Offset.x, 0)
		frame.SpellNameBackground:SetPoint("TOP", frame.SpellName, "TOP", 0, background.Offset.y)
		frame.SpellNameBackground:SetPoint("BOTTOM", frame.SpellName, "BOTTOM", 0, -background.Offset.y)
		private.ThemeApply.Texture(frame.SpellNameBackground, background)
		frame.SpellNameBackground:Show()
	else
		frame.SpellNameBackground:Hide()
	end
end

---@param self AtBigIcon
local function OnAcquire(self)
	ApplySettings(self)
end

---@param self AtBigIcon
local function OnRelease(self)
	private.ThemeApply.IconState(self.frame, nil, nil)
	self.frame.SpellIcon:SetTexture(nil)
	self.frame.SpellName:SetText("")
	self.frame.eventInfo = nil
	self.frame.eventID = nil
	self.frame:SetScript("OnUpdate", nil)
	private.ClearEventTooltip(self.frame)
	private.ThemeApply.BossModsBorder(self.frame, private.GetElementStyle("BigIcon").Border, nil)
	private.StopGlow(self.frame)
end

local SetEventInfo = function(widget, eventInfo, disableOnUpdate)
	widget.eventInfo = eventInfo
	if not disableOnUpdate then
		private.ThemeApply.PlayEnter(widget.frame, private.GetElementStyle("BigIcon").Enter, true, widget.frame.SpellIcon,
			eventInfo.iconFileID)
		widget.frame.Cooldown:SetCooldown(GetTime(), private.manager.getEventRemainingTime(eventInfo.id))
		widget.frame:SetScript("OnUpdate", function(self)
			private.ThemeApply.IconState(self, private.manager.getEventState(eventInfo.id), eventInfo)
			local remaining = private.manager.getEventRemainingTime(eventInfo.id)
			if remaining and remaining > 0 then
				HandleCooldown(self, remaining)
			end
		end)
		if private.db.profile.big_icon_settings.dispellIcons then
			private.manager.SetEventIconTextures(eventInfo.id, 126, widget.frame.DispellTypeIcons)
		end
		local borderColor = private.manager.getEventBorderColor(eventInfo.id)
		local border = private.GetElementStyle("BigIcon").Border
		if private.db.profile.big_icon_settings.border == private.IconBorderSettings.dispell then
			for i in ipairs(private.dispellTypeList) do
				private.ThemeApply.DispelBorder(widget.frame, i, border, eventInfo.id)
			end
		elseif private.db.profile.big_icon_settings.border == private.IconBorderSettings.bossmods and borderColor then
			private.ThemeApply.BossModsBorder(widget.frame, border, borderColor)
		else
			private.ThemeApply.BossModsBorder(widget.frame, border, nil)
		end
		if private.db.profile.big_icon_settings.dangerIcon then
			private.manager.SetEventIconTextures(eventInfo.id, 1, widget.frame.DangerIcon)
		end
		if private.db.profile.big_icon_settings.roleIcons then
			private.manager.SetEventIconTextures(eventInfo.id, 896, widget.frame.RoleIcons)
		end
	end

	widget.frame.SpellIcon:SetTexture(eventInfo.iconFileID)
	widget.frame.SpellName:SetText(eventInfo.spellName)
	widget.frame.eventID = eventInfo.id
	private.ThemeApply.IconState(widget.frame, nil, eventInfo)
	applyEventColor(widget.frame)
	widget.frame:Show()
	if private.db.profile.big_icon_settings and private.db.profile.big_icon_settings.useTooltip and private.db.profile.big_icon_settings.useTooltip ~= Enum.EncounterEventsTooltipAnchor.Hidden then
		private.AddEventTooltip(widget.frame, eventInfo, private.db.profile.big_icon_settings.useTooltip)
	end
end

local function Constructor()
	local count = AceGUI:GetNextWidgetNum(Type)
	local frame = CreateFrame("Frame", "BIGICON" .. count, private.BIGICON_FRAME.frame)
	-- the scaled swipe rounds a pixel past the icon, clipped here so it can cover the icon to its edge
	frame.CooldownClip = CreateFrame("Frame", nil, frame)
	frame.CooldownClip:SetAllPoints(frame)
	frame.CooldownClip:SetClipsChildren(true)
	frame.Cooldown = CreateFrame("Cooldown", nil, frame.CooldownClip, "CooldownFrameTemplate")
	frame.Cooldown:SetDrawSwipe(true)
	frame.Cooldown:SetDrawEdge(true)
	frame.Cooldown:SetAllPoints(frame)
	frame.Cooldown:SetScale(variables.cooldown_scale)
	frame.Cooldown:SetHideCountdownNumbers(true)

	frame.CooldownText = frame.Cooldown:CreateFontString(nil, "OVERLAY", "SystemFont_Shadow_Med3")
	frame.CooldownText:SetPoint("CENTER", frame.Cooldown, "CENTER", 0, 0)

	frame.TextureHolder = CreateFrame("Frame", nil, frame)
	frame.TextureHolder:SetAllPoints(frame)
	frame.TextureHolder:SetFrameStrata("HIGH")

	frame.SpellIcon = frame:CreateTexture(nil, "BACKGROUND")
	frame.SpellIcon:SetAllPoints(frame)
	frame.SpellName = frame.TextureHolder:CreateFontString(nil, "OVERLAY", "SystemFont_Shadow_Med3")
	frame.SpellName:SetWidth(variables.icon_text_width)
	frame.SpellName:SetWordWrap(true)
	frame.SpellName:SetPoint("TOP", frame, "BOTTOM", variables.icon_text_offset_x, variables.icon_text_offset_y)
	frame:Show()

	-- spell name background
	frame.SpellNameBackground = frame:CreateTexture(nil, "BACKGROUND")
	frame.SpellNameBackground:Hide()

	frame.RoleIcons = {}

	for i = 1, 4 do
		local texture = frame.TextureHolder:CreateTexture(nil, "OVERLAY", nil, 7)
		texture:SetPoint("LEFT", frame.TextureHolder, "RIGHT", 18 * (i - 1), 0)
		texture:SetSize(16, 16)
		texture:Show()
		table.insert(frame.RoleIcons, texture)
	end

	frame.DangerIcon = {}

	local dangerTexture = frame.TextureHolder:CreateTexture(nil, "OVERLAY", nil, 7)
	dangerTexture:SetSize(16, 16)
	dangerTexture:SetPoint("CENTER", frame.TextureHolder, "TOPLEFT", 0, 0)
	dangerTexture:Show()
	table.insert(frame.DangerIcon, dangerTexture)

	frame.DispellTypeIcons = {}

	local dispellTypeTexture = frame.TextureHolder:CreateTexture(nil, "OVERLAY", nil, 7)
	dispellTypeTexture:SetPoint("BOTTOMRIGHT", frame.TextureHolder, "BOTTOMRIGHT", -3, 3)
	dispellTypeTexture:SetSize(16, 16)
	dispellTypeTexture:Show()
	table.insert(frame.DispellTypeIcons, dispellTypeTexture)

	frame.BossModsBorderEdges = {}
	local bossBorderWidth = 3

	-- Top edge
	local bossTopEdge = frame.TextureHolder:CreateTexture(nil, "BORDER")
	bossTopEdge:SetPoint("TOPLEFT", frame.TextureHolder, "TOPLEFT", 0, 0)
	bossTopEdge:SetPoint("TOPRIGHT", frame.TextureHolder, "TOPRIGHT", 0, 0)
	bossTopEdge:SetHeight(bossBorderWidth)
	bossTopEdge:Hide()

	-- Bottom edge
	local bossBottomEdge = frame.TextureHolder:CreateTexture(nil, "BORDER")
	bossBottomEdge:SetPoint("BOTTOMLEFT", frame.TextureHolder, "BOTTOMLEFT", 0, 0)
	bossBottomEdge:SetPoint("BOTTOMRIGHT", frame.TextureHolder, "BOTTOMRIGHT", 0, 0)
	bossBottomEdge:SetHeight(bossBorderWidth)
	bossBottomEdge:Hide()

	-- Left edge
	local bossLeftEdge = frame.TextureHolder:CreateTexture(nil, "BORDER")
	bossLeftEdge:SetPoint("TOPLEFT", frame.TextureHolder, "TOPLEFT", 0, 0)
	bossLeftEdge:SetPoint("BOTTOMLEFT", frame.TextureHolder, "BOTTOMLEFT", 0, 0)
	bossLeftEdge:SetWidth(bossBorderWidth)
	bossLeftEdge:Hide()

	-- Right edge
	local bossRightEdge = frame.TextureHolder:CreateTexture(nil, "BORDER")
	bossRightEdge:SetPoint("TOPRIGHT", frame.TextureHolder, "TOPRIGHT", 0, 0)
	bossRightEdge:SetPoint("BOTTOMRIGHT", frame.TextureHolder, "BOTTOMRIGHT", 0, 0)
	bossRightEdge:SetWidth(bossBorderWidth)
	bossRightEdge:Hide()
	frame.BossModsBorderEdges = { bossTopEdge, bossBottomEdge, bossLeftEdge, bossRightEdge }

	frame.DispellTypeBorderEdges = {}

	for i, value in pairs(private.dispellTypeList) do
		local topTexture = frame.TextureHolder:CreateTexture(nil, "BORDER")
		topTexture:SetPoint("TOPLEFT", frame.TextureHolder, "TOPLEFT", 0, 0)
		topTexture:SetPoint("TOPRIGHT", frame.TextureHolder, "TOPRIGHT", 0, 0)
		topTexture:SetHeight(3)
		topTexture:Show()

		-- Bottom edge
		local bottomTexture = frame.TextureHolder:CreateTexture(nil, "BORDER")
		bottomTexture:SetPoint("BOTTOMLEFT", frame.TextureHolder, "BOTTOMLEFT", 0, 0)
		bottomTexture:SetPoint("BOTTOMRIGHT", frame.TextureHolder, "BOTTOMRIGHT", 0, 0)
		bottomTexture:SetHeight(3)
		bottomTexture:Show()

		-- Left edge
		local leftTexture = frame.TextureHolder:CreateTexture(nil, "BORDER")
		leftTexture:SetPoint("TOPLEFT", frame.TextureHolder, "TOPLEFT", 0, 0)
		leftTexture:SetPoint("BOTTOMLEFT", frame.TextureHolder, "BOTTOMLEFT", 0, 0)
		leftTexture:SetWidth(3)
		leftTexture:Show()

		-- Right edge
		local rightTexture = frame.TextureHolder:CreateTexture(nil, "BORDER")
		rightTexture:SetPoint("TOPRIGHT", frame.TextureHolder, "TOPRIGHT", 0, 0)
		rightTexture:SetPoint("BOTTOMRIGHT", frame.TextureHolder, "BOTTOMRIGHT", 0, 0)
		rightTexture:SetWidth(3)
		rightTexture:Show()

		frame.DispellTypeBorderEdges[i] = { topTexture, bottomTexture, leftTexture, rightTexture }
	end


	---@class AtBigIcon : AceGUIWidget
	local widget = {
		OnAcquire = OnAcquire,
		OnRelease = OnRelease,
		type = Type,
		count = count,
		frame = frame,
		SetEventInfo = SetEventInfo,
		HandleCooldown = HandleCooldown,
		ApplySettings = ApplySettings,
	}
	private.AddToMasque("BigIcons", frame, { Icon = frame.SpellIcon, Cooldown = frame.Cooldown })
	private.RegisterThemed(widget)

	return AceGUI:RegisterAsWidget(widget)
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)
