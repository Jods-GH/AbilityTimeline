local appName, app = ...
---@class AbilityTimeline
local private = app
local AceGUI = LibStub("AceGUI-3.0")
local Type = "AtDynamicGroup"
local Version = 1
local GROW = private.DynamicGroup.GROW
local SORT = private.DynamicGroup.SORT

local HORIZONTAL_GROWS = {
   [GROW.LEFT] = true,
   [GROW.RIGHT] = true,
   [GROW.HORIZONTAL] = true,
}

---returns point, relativePoint, x, y for an item
---@param acc number -- summed size and spacing of all previous items
---@param total number -- summed size and spacing of all visible items
local growers = {
   [GROW.UP] = function(acc, total)
      return "BOTTOM", "BOTTOM", 0, acc
   end,
   [GROW.DOWN] = function(acc, total)
      return "TOP", "TOP", 0, -acc
   end,
   [GROW.RIGHT] = function(acc, total)
      return "LEFT", "LEFT", acc, 0
   end,
   [GROW.LEFT] = function(acc, total)
      return "RIGHT", "RIGHT", -acc, 0
   end,
   [GROW.HORIZONTAL] = function(acc, total)
      return "LEFT", "CENTER", -total / 2 + acc, 0
   end,
   [GROW.VERTICAL] = function(acc, total)
      return "TOP", "CENTER", 0, total / 2 - acc
   end,
}

local compareAscending = function(a, b)
   if a.sortValue ~= b.sortValue then
      return a.sortValue < b.sortValue
   end
   return a.id < b.id
end

local compareDescending = function(a, b)
   if a.sortValue ~= b.sortValue then
      return a.sortValue > b.sortValue
   end
   return a.id < b.id
end

-- duration in seconds of the slide animation of animated groups
local ANIMATION_DURATION = 0.25

local clearCachedPosition = function(frame)
   frame.groupAnchor = nil
   frame.groupPoint = nil
   frame.groupRelativePoint = nil
   frame.groupX = nil
   frame.groupY = nil
end

---@class AtDynamicGroup
local groupMixin = {}

---adds a frame to the group, the frame is positioned on the next layout
---@param id number -- eventID of the item, used for sorting
---@param frame Frame
---@param fromX number|nil -- optional screen center the frame slides in from in animated groups
---@param fromY number|nil
function groupMixin:Add(id, frame, fromX, fromY)
   if self.index[id] then
      if self.index[id].frame == frame then return end
      self:Remove(id)
   end
   local item = { id = id, frame = frame, sortValue = 0, fromX = fromX, fromY = fromY }
   self.index[id] = item
   table.insert(self.items, item)
   clearCachedPosition(frame)
   self.dirty = true
end

---removes a frame from the group, frames hidden by the limit are shown again
---@param id number
function groupMixin:Remove(id)
   local item = self.index[id]
   if not item then return end
   self.index[id] = nil
   for i, entry in ipairs(self.items) do
      if entry == item then
         table.remove(self.items, i)
         break
      end
   end
   if item.hiddenByLimit then
      item.frame:Show()
   end
   clearCachedPosition(item.frame)
   if item.placeholder then
      item.placeholder:Release()
   end
   self.dirty = true
end

---keeps the place of an item free for time seconds, e.g. while it plays a hide animation, then removes it.
---an invisible frame takes the item's place so the frame itself can be released right away
---@param id number
---@param time number
function groupMixin:Hold(id, time)
   local item = self.index[id]
   if not item or time <= 0 or item.hiddenByLimit then
      self:Remove(id)
      return
   end
   local frame = item.frame
   if item.held then return end
   local holder = AceGUI:Create("AtGroupPlaceholder")
   local placeholder = holder.frame
   placeholder:SetSize(frame:GetSize())
   placeholder:ClearAllPoints()
   for _, key in ipairs({ "groupAnchor", "groupPoint", "groupRelativePoint", "groupX", "groupY" }) do
      placeholder[key] = frame[key]
   end
   if frame.groupAnchor then
      placeholder:SetPoint(frame.groupPoint, frame.groupAnchor, frame.groupRelativePoint, frame.groupX, frame.groupY)
   end
   clearCachedPosition(frame)
   item.frame = placeholder
   item.held = true
   item.placeholder = holder
   -- its event just ended, so it stays at the end of the order where events end
   item.sortValue = 0
   item.animation = nil
   holder:SetDuration(time, function()
      if self.index[id] == item then
         self:Remove(id)
         self:Layout()
      end
   end)
end

---@param id number
---@return boolean
function groupMixin:Contains(id)
   return self.index[id] ~= nil
end

---@return number
function groupMixin:Count()
   return #self.items
end

---@return number -- amount of items shown, respecting the limit
function groupMixin:GetVisibleCount()
   local limit = self.getSettings().limit or 0
   if limit > 0 and limit < #self.items then
      return limit
   end
   return #self.items
end

function groupMixin:MarkDirty()
   self.dirty = true
end

---sets a space kept free in front of the first item, e.g. for an item that just left the group
---@param offset number
function groupMixin:SetLeadOffset(offset)
   if self.leadOffset ~= offset then
      self.leadOffset = offset
      self.dirty = true
   end
end

---@return boolean
function groupMixin:IsDirty()
   return self.dirty
end

---starts sliding a frame from a screen position to its group position
---@param item table
---@param fromX number|nil
---@param fromY number|nil
local startAnimation = function(item, fromX, fromY)
   item.animation = nil
   if not fromX or not fromY then return end
   local toX, toY = item.frame:GetCenter()
   if not toX or not toY then return end
   local deltaX, deltaY = fromX - toX, fromY - toY
   if math.abs(deltaX) < 0.5 and math.abs(deltaY) < 0.5 then return end
   item.animation = { deltaX = deltaX, deltaY = deltaY, elapsed = 0 }
   local frame = item.frame
   frame:SetPoint(frame.groupPoint, frame.groupAnchor, frame.groupRelativePoint, frame.groupX + deltaX,
      frame.groupY + deltaY)
end

---advances the slide animations of the group, needs to be called every frame for animated groups
---@param elapsed number
function groupMixin:Animate(elapsed)
   for _, item in ipairs(self.items) do
      local animation = item.animation
      if animation then
         local frame = item.frame
         animation.elapsed = animation.elapsed + elapsed
         local progress = math.min(animation.elapsed / ANIMATION_DURATION, 1)
         -- ease out, fast start and slow finish
         local remaining = (1 - progress) * (1 - progress)
         frame:SetPoint(frame.groupPoint, frame.groupAnchor, frame.groupRelativePoint,
            frame.groupX + animation.deltaX * remaining, frame.groupY + animation.deltaY * remaining)
         if progress >= 1 then
            item.animation = nil
         end
      end
   end
end

---sorts, limits and positions all items of the group
function groupMixin:Layout()
   self.dirty = false
   local anchor = self.getAnchor()
   if not anchor or #self.items == 0 then return end
   local settings = self.getSettings()
   local grow = settings.grow
   if self.resolveGrow then
      grow = self.resolveGrow(grow)
   end
   if not growers[grow] then
      grow = GROW.UP
   end
   local grower = growers[grow]
   local isHorizontal = HORIZONTAL_GROWS[grow]
   local animate = self.shouldAnimate and self.shouldAnimate()
   local spacing = settings.spacing or 0
   local limit = settings.limit or 0

   local getSortValue = self.getSortValue or private.manager.getEventRemainingTime
   for _, item in ipairs(self.items) do
      -- a held item's event is gone, it keeps its place in the order
      if not item.held then
         item.sortValue = getSortValue(item.id) or 0
      end
   end
   table.sort(self.items, settings.sort == SORT.DESCENDING and compareDescending or compareAscending)

   local visible = #self.items
   if limit > 0 and limit < visible then
      visible = limit
   end
   local total = spacing * math.max(visible - 1, 0)
   for i = 1, visible do
      local frame = self.items[i].frame
      total = total + (isHorizontal and frame:GetWidth() or frame:GetHeight())
   end

   local acc = self.leadOffset
   for i, item in ipairs(self.items) do
      local frame = item.frame
      if i <= visible then
         local point, relativePoint, x, y = grower(acc, total)
         if frame.groupAnchor ~= anchor or frame.groupPoint ~= point or frame.groupRelativePoint ~= relativePoint or
             frame.groupX ~= x or frame.groupY ~= y then
            -- slide from where the frame currently is, frames revealed by the limit just appear
            local fromX, fromY
            if animate and not item.hiddenByLimit then
               if item.fromX then
                  fromX, fromY = item.fromX, item.fromY
               else
                  fromX, fromY = frame:GetCenter()
               end
            end
            item.fromX, item.fromY = nil, nil
            frame:ClearAllPoints()
            frame:SetPoint(point, anchor, relativePoint, x, y)
            frame.groupAnchor = anchor
            frame.groupPoint = point
            frame.groupRelativePoint = relativePoint
            frame.groupX = x
            frame.groupY = y
            startAnimation(item, fromX, fromY)
         end
         if item.hiddenByLimit then
            item.hiddenByLimit = nil
            frame:Show()
         end
         acc = acc + (isHorizontal and frame:GetWidth() or frame:GetHeight()) + spacing
      elseif not item.hiddenByLimit then
         item.hiddenByLimit = true
         item.animation = nil
         frame:Hide()
      end
   end
end

---configures the callbacks read by the group on each layout
function groupMixin:Setup(getSettings, getAnchor, resolveGrow, shouldAnimate, getSortValue)
   self.getSettings = getSettings
   self.getAnchor = getAnchor
   self.resolveGrow = resolveGrow
   self.shouldAnimate = shouldAnimate
   self.getSortValue = getSortValue
   return self
end

function groupMixin:OnAcquire()
   self.dirty = false
   self.leadOffset = 0
   self.frame:Hide()
end

function groupMixin:OnRelease()
   for i = #self.items, 1, -1 do
      self:Remove(self.items[i].id)
   end
   self.getSettings = nil
   self.getAnchor = nil
   self.resolveGrow = nil
   self.shouldAnimate = nil
   self.getSortValue = nil
   self.dirty = false
   self.leadOffset = 0
end

private.DynamicGroup.Mixin = groupMixin

local function Constructor()
   local widget = { type = Type, frame = CreateFrame("Frame", nil, UIParent), items = {}, index = {} }
   for key, value in pairs(groupMixin) do
      widget[key] = value
   end
   return AceGUI:RegisterAsWidget(widget)
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)
