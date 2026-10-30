local appName, app                             = ...
---@class AbilityTimeline
local private                                  = app
local AceGUI                                   = LibStub("AceGUI-3.0")
local LibEditMode                              = LibStub("LibEditMode")

private.activeFrames                             = {}

private.AT_THRESHHOLD                          = 0.8

private.ENCOUNTER_STATES                       = private.manager.STATES

local ZONES                                    = private.TIMELINE_ZONES
local RESORT_INTERVAL                          = 0.25
-- how much faster than the timeline a pushed back icon moves back to its real position once there is room again
local CATCH_UP_SPEED                           = 1

local getTimelineLayout = function()
   return private.db.global.timeline_frame[private.ACTIVE_EDITMODE_LAYOUT]
end

---@type table<string, AtDynamicGroup>
private.TimelineGroups                         = {
   [ZONES.WAITING] = private.DynamicGroup.Create(function()
      return private.WAITING_FRAME:GetSettings()
   end, function()
      return private.WAITING_FRAME and private.WAITING_FRAME.frame
   end, function(grow)
      return private.WAITING_FRAME:ResolveGrow(grow)
   end),
   [ZONES.QUEUED] = private.DynamicGroup.Create(function()
      return private.QUEUED_FRAME:GetSettings()
   end, function()
      return private.QUEUED_FRAME and private.QUEUED_FRAME.frame
   end, function(grow)
      return private.QUEUED_FRAME:ResolveGrow(grow)
   end, function()
      return private.QUEUED_FRAME:GetSettings().attached
   end),
   [ZONES.PAUSED] = private.DynamicGroup.Create(function()
      return private.PAUSED_FRAME:GetSettings()
   end, function()
      return private.PAUSED_FRAME and private.PAUSED_FRAME.frame
   end, function(grow)
      return private.PAUSED_FRAME:ResolveGrow(grow)
   end, function()
      return private.PAUSED_FRAME:GetSettings().attached
   end),
}
local groups                                   = private.TimelineGroups

---returns the icon size used in a zone
---@param zone string
---@return number
local getZoneIconSize                          = function(zone)
   if zone == ZONES.WAITING then
      return private.WAITING_FRAME:GetIconSize()
   elseif zone == ZONES.QUEUED then
      return private.QUEUED_FRAME:GetIconSize()
   elseif zone == ZONES.PAUSED then
      return private.PAUSED_FRAME:GetIconSize()
   end
   return private.db.profile.icon_settings.size
end

---returns the zone an icon should be displayed in
---@param state number
---@param positionRemaining number
---@return string
local getZone                                  = function(state, positionRemaining)
   local isWaiting = not (positionRemaining < getTimelineLayout().threshold_time)
   if state == private.ENCOUNTER_STATES.Queued then
      return ZONES.QUEUED
   elseif state == private.ENCOUNTER_STATES.Paused then
      if private.PAUSED_FRAME:IsActive() then
         return ZONES.PAUSED
      elseif isWaiting then
         return ZONES.WAITING
      end
      return ZONES.INLINE_PAUSED
   elseif isWaiting then
      return ZONES.WAITING
   end
   return ZONES.MOVING
end

---moves an icon into a zone
---@param eventID number
---@param widget AtAbilitySpellIcon
---@param zone string|nil
local setZone                                  = function(eventID, widget, zone)
   local frame = widget.frame
   if frame.zone == zone then return end
   -- animated groups slide the icon in from where it was shown before, new icons have no previous position
   local fromX, fromY
   if frame.zone and (frame:IsShown() or frame.mergedInto) then
      fromX, fromY = frame:GetCenter()
   end
   -- merged icons only exist while moving
   if frame.mergedInto then
      frame.mergedInto = nil
      frame:Show()
   end
   widget:SetMergedIcons(nil)
   frame.displayRemaining = nil
   if frame.zone and groups[frame.zone] then
      groups[frame.zone]:Remove(eventID)
   end
   frame.zone = zone
   if not zone then return end
   frame:ClearAllPoints()
   local size = getZoneIconSize(zone)
   frame:SetSize(size, size)
   if groups[zone] then
      groups[zone]:Add(eventID, frame, fromX, fromY)
   end
end

local refreshAnchors                           = function()
   private.WAITING_FRAME:ApplyAnchor()
   private.QUEUED_FRAME:ApplyAnchor()
   private.PAUSED_FRAME:ApplyAnchor()
end

---returns if the waiting group continues the timeline in its travel direction, in that case its icons
---have to trail behind the icons that just started moving instead of jumping into their spot
---@return boolean
local waitingFollowsTimeline                   = function()
   local settings = private.WAITING_FRAME:GetSettings()
   return settings.attached and settings.attachPoint == private.GroupAnchor.ATTACH_AUTO and
       private.WAITING_FRAME:ResolveGrow(settings.grow) == private.GroupAnchor.getTimelineGrow(true)
end

local movingIcons                              = {}
local clusters                                 = {}

local compareMoving                            = function(a, b)
   if a.frame.positionRemaining ~= b.frame.positionRemaining then
      return a.frame.positionRemaining < b.frame.positionRemaining
   end
   return a.frame.eventInfo.id < b.frame.eventInfo.id
end

---merges moving icons with the same timing and pushes overlapping icons back, so no two moving icons overlap
---sets displayRemaining (the remaining time the icon is shown at) on every moving icon
---@param elapsed number
local resolveMovingCollisions                  = function(elapsed)
   local layout = getTimelineLayout()
   table.sort(movingIcons, compareMoving)

   -- events within the merge window of the first event of a cluster share one icon
   local clusterCount = 0
   for _, widget in ipairs(movingIcons) do
      local remaining = widget.frame.positionRemaining
      local cluster = clusters[clusterCount]
      if layout.merge_timers and cluster and #cluster.members < private.MAX_MERGED_TIMELINE_ICONS and
          remaining - cluster.remaining <= layout.merge_window then
         table.insert(cluster.members, widget)
      else
         clusterCount = clusterCount + 1
         cluster = clusters[clusterCount] or { members = {} }
         clusters[clusterCount] = cluster
         wipe(cluster.members)
         cluster.remaining = remaining
         table.insert(cluster.members, widget)
      end
   end

   -- the time one icon takes up on the timeline, later icons are pushed back by that much
   local moveSize = private.TIMELINE_FRAME:GetMoveSize()
   local iconTime = moveSize > 0 and
       (private.db.profile.icon_settings.size + layout.iconMargin) / moveSize * layout.threshold_time or 0
   local previous
   for i = 1, clusterCount do
      local members = clusters[i].members
      local host = members[1]
      local displayRemaining = clusters[i].remaining
      if layout.prevent_overlap then
         if previous then
            displayRemaining = math.max(displayRemaining, previous + iconTime)
         end
         -- glide back to the real position once the icon in front left instead of jumping
         local lastDisplayed = host.frame.displayRemaining
         if lastDisplayed then
            displayRemaining = math.max(displayRemaining, lastDisplayed - elapsed * (1 + CATCH_UP_SPEED))
         end
      end
      previous = displayRemaining
      host:SetMergedIcons(members)
      for index, widget in ipairs(members) do
         local frame = widget.frame
         frame.displayRemaining = displayRemaining
         if index == 1 then
            if frame.mergedInto then
               frame.mergedInto = nil
               frame:Show()
            end
         else
            if frame.mergeKey then
               widget:SetMergedIcons(nil)
            end
            if frame.mergedInto ~= host then
               frame.mergedInto = host
               frame:Hide()
            end
         end
      end
   end
end

local inlinePausedIcons                        = {}

---returns if the queued group stacks in the same column besides the timeline as the paused icons shown on the timeline
---@return boolean
local queuedSharesPausedColumn                 = function()
   local settings = private.QUEUED_FRAME:GetSettings()
   return settings.attached and settings.attachPoint == private.GroupAnchor.ATTACH_AUTO and
       settings.offsetX == 0 and settings.offsetY == 0 and
       private.QUEUED_FRAME:ResolveGrow(settings.grow) == private.GroupAnchor.getTimelineGrow(true)
end

---keeps paused icons shown besides the timeline clear of each other and of the queued stack in the same column
---sets displayRemaining (the remaining time the icon is shown at) on every inline paused icon
---@param elapsed number
local resolveInlinePausedCollisions            = function(elapsed)
   local layout = getTimelineLayout()
   local moveSize = private.TIMELINE_FRAME:GetMoveSize()
   if not layout.prevent_overlap or moveSize <= 0 then
      for _, widget in ipairs(inlinePausedIcons) do
         widget.frame.displayRemaining = widget.frame.positionRemaining
      end
      return
   end
   table.sort(inlinePausedIcons, compareMoving)

   -- the queued stack grows from the near end, paused icons have to stay above it
   local minimum = 0
   if queuedSharesPausedColumn() then
      local visible = groups[ZONES.QUEUED]:GetVisibleCount()
      if visible > 0 then
         local extent = visible * private.QUEUED_FRAME:GetIconSize() +
             (visible - 1) * private.QUEUED_FRAME:GetSettings().spacing + layout.iconMargin
         minimum = extent / moveSize * layout.threshold_time
      end
   end
   local iconTime = (private.db.profile.icon_settings.size + layout.iconMargin) / moveSize * layout.threshold_time
   local previous
   for _, widget in ipairs(inlinePausedIcons) do
      local frame = widget.frame
      local displayRemaining = math.max(frame.positionRemaining, minimum)
      if previous then
         displayRemaining = math.max(displayRemaining, previous + iconTime)
      end
      -- glide down once there is room again instead of jumping
      if frame.displayRemaining then
         displayRemaining = math.max(displayRemaining, frame.displayRemaining - elapsed * (1 + CATCH_UP_SPEED))
      end
      frame.displayRemaining = displayRemaining
      previous = displayRemaining
   end
end

-- drives all timeline icons, decides their zone and lets the zone groups position them
local driver                                  = CreateFrame("Frame")
driver:Hide()
local resortElapsed                            = 0
driver:SetScript("OnUpdate", function(_, elapsed)
   local threshold = getTimelineLayout().threshold_time
   local moveSize = private.TIMELINE_FRAME:GetMoveSize()
   local followsTimeline = waitingFollowsTimeline()
   -- space the icons that entered the timeline still take up in front of the waiting group
   local waitingLeadOffset = 0
   local waitingSpace = private.db.profile.icon_settings.size + private.WAITING_FRAME:GetSettings().spacing
   wipe(movingIcons)
   wipe(inlinePausedIcons)
   for eventID, widget in pairs(private.activeFrames) do
      local timeElapsed = private.manager.getEventTimeElapsed(eventID)
      local timeRemaining = private.manager.getEventRemainingTime(eventID)
      local state = private.manager.getEventState(eventID)
      local eventInfo = widget.frame.eventInfo
      if state and timeRemaining and eventInfo then
         if not timeElapsed or timeElapsed < 0 then timeElapsed = eventInfo.duration end
         local positionRemaining = eventInfo.duration - timeElapsed
         local zone = getZone(state, positionRemaining)
         setZone(eventID, widget, zone)
         if zone == ZONES.MOVING or zone == ZONES.INLINE_PAUSED then
            local frame = widget.frame
            frame.positionRemaining = positionRemaining
            frame.timeRemaining = timeRemaining
            frame.currentState = state
            table.insert(zone == ZONES.MOVING and movingIcons or inlinePausedIcons, widget)
         else
            widget:UpdateTimeline(state, timeRemaining, positionRemaining, zone)
         end
      end
   end
   resolveInlinePausedCollisions(elapsed)
   for _, widget in ipairs(inlinePausedIcons) do
      local frame = widget.frame
      widget:UpdateTimeline(frame.currentState, frame.timeRemaining, frame.displayRemaining, ZONES.INLINE_PAUSED)
   end
   resolveMovingCollisions(elapsed)
   for _, widget in ipairs(movingIcons) do
      local frame = widget.frame
      widget:UpdateTimeline(frame.currentState, frame.timeRemaining, frame.displayRemaining, ZONES.MOVING)
      if followsTimeline and not frame.mergedInto then
         local travelled = (threshold - frame.displayRemaining) / threshold * moveSize
         waitingLeadOffset = math.max(waitingLeadOffset, waitingSpace - travelled)
      end
   end
   groups[ZONES.WAITING]:SetLeadOffset(waitingLeadOffset)
   -- remaining times only change their order while something is paused, so a regular resort is enough
   resortElapsed = resortElapsed + elapsed
   local resort = resortElapsed >= RESORT_INTERVAL
   if resort then
      resortElapsed = 0
      refreshAnchors()
   end
   for _, group in pairs(groups) do
      if resort or group:IsDirty() then
         group:Layout()
      end
      group:Animate(elapsed)
   end
end)

---re-evaluates the zones, sizes and anchors of all timeline icons, call after changing any group related setting
private.refreshTimelineGroups                  = function()
   if not private.TIMELINE_FRAME or not private.WAITING_FRAME or not private.QUEUED_FRAME or not private.PAUSED_FRAME then return end
   refreshAnchors()
   for eventID, widget in pairs(private.activeFrames) do
      setZone(eventID, widget, nil)
   end
end

private.createTimelineIcon                     = function(eventID)
   if private.activeFrames[eventID] then
     -- private.Debug("Frame already exists for eventID".. eventID.. "removing existing frame")
      private.removeAtIconFrame(eventID)
   end
   local frame = AceGUI:Create("AtAbilitySpellIcon")
   frame:SetEventInfo(private.manager.getEventInfo(eventID))
   private.activeFrames[eventID] = frame
   frame.frame:Show()
   if not driver:IsShown() then
      refreshAnchors()
      driver:Show()
   end
end

private.removeAtIconFrame                      = function(eventID)
   local frame = private.activeFrames[eventID]
   if frame then
      setZone(eventID, frame, nil)
      frame.frame:Hide()
      frame:Release()
      private.activeFrames[eventID] = nil
      if not next(private.activeFrames) then
         driver:Hide()
      end
   else
      -- private.Debug("No frame found for eventID".. eventID)
   end
end

private.manager.RegisterCallback("AbilityTimeline", "EVENT_DISPLAY_START", function(_, eventID, display)
   if display ~= "timeline" then return end
   if not private.TIMELINE_FRAME.frame:IsVisible() then
      private.handleFrame(true)
   end
   private.createTimelineIcon(eventID)
end)

private.manager.RegisterCallback("AbilityTimeline", "EVENT_DISPLAY_STOP", function(_, eventID, display)
   if display ~= "timeline" then return end
   private.removeAtIconFrame(eventID)
   if not private.manager.hasVisibleEvents() and not LibEditMode:IsInEditMode() then
      private.handleFrame(false)
   end
end)

private.manager.RegisterCallback("AbilityTimeline", "EVENT_TICK", function(_, eventID)
   local frame = private.activeFrames[eventID]
   if frame then
      frame:PlayHighlight()
   end
end)

private.createTimelineFrame = function()
   private.TIMELINE_FRAME = AceGUI:Create("AtTimelineFrame")

   private.BIGICON_FRAME = AceGUI:Create("AtBigIconFrame")


   private.TEXT_HIGHLIGHT_FRAME = AceGUI:Create("AtTextHighlightFrame")

   private.WAITING_FRAME = AceGUI:Create("AtGroupAnchorFrame")
   private.WAITING_FRAME:Setup({
      dbKey = "waiting_group",
      title = "|TInterface\\AddOns\\AbilityTimeline\\Media\\Textures\\logo_transparent.tga:32|t " ..
          private.getLocalisation("WaitingIconsFrameTitle"),
      defaultPosition = { point = 'CENTER', x = 410, y = 400 },
      atFarEnd = true,
      outsideTimeline = true,
      growTowardsFarEnd = true,
      hasModeSetting = false,
      onChange = private.refreshTimelineGroups,
   })

   private.QUEUED_FRAME = AceGUI:Create("AtGroupAnchorFrame")
   private.QUEUED_FRAME:Setup({
      dbKey = "queued_group",
      title = "|TInterface\\AddOns\\AbilityTimeline\\Media\\Textures\\logo_transparent.tga:32|t " ..
          private.getLocalisation("QueuedIconsFrameTitle"),
      defaultPosition = { point = 'CENTER', x = 470, y = -150 },
      atFarEnd = false,
      growTowardsFarEnd = true,
      hasModeSetting = false,
      onChange = private.refreshTimelineGroups,
   })

   private.PAUSED_FRAME = AceGUI:Create("AtGroupAnchorFrame")
   private.PAUSED_FRAME:Setup({
      dbKey = "paused_group",
      title = "|TInterface\\AddOns\\AbilityTimeline\\Media\\Textures\\logo_transparent.tga:32|t " ..
          private.getLocalisation("PausedIconsFrameTitle"),
      defaultPosition = { point = 'CENTER', x = 470, y = 350 },
      atFarEnd = true,
      growTowardsFarEnd = false,
      hasModeSetting = true,
      onChange = private.refreshTimelineGroups,
   })

   -- LibEditMode can report the layout while the first frame is still being created
   if private.ACTIVE_EDITMODE_LAYOUT then
      private.TimelineFrame.applyLayout(private.ACTIVE_EDITMODE_LAYOUT)
      private.BigIcon.applyLayout(private.ACTIVE_EDITMODE_LAYOUT)
      private.TextHighlight.applyLayout(private.ACTIVE_EDITMODE_LAYOUT)
      private.WAITING_FRAME:ApplyLayout(private.ACTIVE_EDITMODE_LAYOUT)
      private.QUEUED_FRAME:ApplyLayout(private.ACTIVE_EDITMODE_LAYOUT)
      private.PAUSED_FRAME:ApplyLayout(private.ACTIVE_EDITMODE_LAYOUT)
   end
end

private.handleFrame = function(show)
   if show then
      if not private.TIMELINE_FRAME.frame then
         private.createTimelineFrame()
      end
      private.TIMELINE_FRAME.frame:Show()
   else
      if private.TIMELINE_FRAME.frame then
         private.TIMELINE_FRAME.frame:Hide()
      end
      private.removeAllFrames()
   end
end

private.removeAllFrames = function()
   for eventID, frame in pairs(private.activeFrames) do
      private.removeAtIconFrame(eventID)
   end
end
