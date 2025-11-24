local addonName, private = ...

private.BIG_ICON_SIZE = 100
private.BIG_ICON_MARGIN = 10
private.ICON_ZOOM = 0.7
private.BIG_ICON_COOLDOWN_SCALE = 2
private.createBigIcon = function(eventInfo)
   local frame = CreateFrame("Frame", "BIGICON"..eventInfo.id, private.BIGICON_FRAME.frame) -- TODO CHANGE THIS TO ICON POOL with template
   frame.eventInfo = eventInfo
   frame.Cooldown = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
   frame.Cooldown:SetDrawSwipe(true)
   frame.Cooldown:SetDrawEdge(true)
   frame.Cooldown:SetAllPoints(frame)
   frame.Cooldown:SetScale(private.BIG_ICON_COOLDOWN_SCALE)
   frame.Cooldown:SetCooldown(GetTime(), eventInfo.duration - C_EncounterTimeline.GetEventTimeElapsed(eventInfo.id))
   frame.Cooldown:SetScript("OnCooldownDone", function(self)
      frame:Hide()
      private.HIGHLIGHT_EVENTS.BigIcons[eventInfo.id] = nil
      for i, f in ipairs(private.BIG_ICONS) do
         if f == frame then
            table.remove(private.BIG_ICONS, i)
            break
         end
      end
      private.evaluateIconPositions()
   end)
   local xOffset = (private.BIG_ICON_SIZE + private.BIG_ICON_MARGIN) * (#private.BIG_ICONS)
   frame:SetPoint("LEFT", private.BIGICON_FRAME.frame, "LEFT", xOffset, 0)
   frame.xOffset = xOffset
   frame:SetSize(private.BIG_ICON_SIZE, private.BIG_ICON_SIZE)
   --frame:SetCooldown(GetTime(),eventInfo.duration - C_EncounterTimeline.GetEventTimeElapsed(eventInfo.id))
   frame.icon = frame:CreateTexture(nil, "OVERLAY")
   private.SetZoom(frame.icon, private.ICON_ZOOM)
   frame.icon:SetAllPoints(frame)
   frame.icon:SetTexture(eventInfo.iconFileID)
   frame.iconText = frame:CreateFontString(nil, "OVERLAY", "SystemFont_Shadow_Med3")
   frame.iconText:SetWidth(95)
   frame.iconText:SetWordWrap(true)
   frame.iconText:SetPoint("TOP", frame, "BOTTOM", 0, -10)
   frame.iconText:SetText(eventInfo.spellName)
   frame:Show()
   -- frame:SetScript("OnClick", function(self)
   --    print("Big icon clicked for event " .. self.eventInfo.id)
   -- end)
   frame:EnableMouse(true)
   private.HIGHLIGHT_EVENTS.BigIcons[eventInfo.id] = true
   table.insert(private.BIG_ICONS, frame)
   DevTool:AddData(frame, "AT_BIGICON_FRAME_" .. eventInfo.id)
   private.evaluateIconPositions()
end