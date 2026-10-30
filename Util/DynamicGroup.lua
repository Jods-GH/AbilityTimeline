local appName, app = ...
---@class AbilityTimeline
local private = app
local LibEditMode = LibStub("LibEditMode")

-- A dynamic group positions a set of frames relative to an anchor frame, similar to the WeakAuras dynamic group.
-- Items are sorted by the remaining time of their event, optionally limited and then stacked in the grow direction.
private.DynamicGroup = {}

private.DynamicGroup.GROW = {
   UP = "UP",
   DOWN = "DOWN",
   LEFT = "LEFT",
   RIGHT = "RIGHT",
   HORIZONTAL = "HORIZONTAL",
   VERTICAL = "VERTICAL",
   AUTO = "AUTO",
}
local GROW = private.DynamicGroup.GROW

private.DynamicGroup.SORT = {
   ASCENDING = "ascending",
   DESCENDING = "descending",
}
local SORT = private.DynamicGroup.SORT

local GROW_LOCALISATION = {
   [GROW.UP] = "GrowDirectionUp",
   [GROW.DOWN] = "GrowDirectionDown",
   [GROW.LEFT] = "GrowDirectionLeft",
   [GROW.RIGHT] = "GrowDirectionRight",
   [GROW.HORIZONTAL] = "GrowDirectionHorizontal",
   [GROW.VERTICAL] = "GrowDirectionVertical",
   [GROW.AUTO] = "GrowDirectionAuto",
}

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
   self.dirty = true
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

   for _, item in ipairs(self.items) do
      item.sortValue = private.manager.getEventRemainingTime(item.id) or 0
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

---creates a new dynamic group
---@param getSettings fun():table -- returns { grow, spacing, limit, sort }, read on every layout
---@param getAnchor fun():Frame|nil -- returns the frame the items are attached to
---@param resolveGrow fun(grow:string):string|nil -- optional, resolves GROW.AUTO into a real grow direction
---@param shouldAnimate fun():boolean|nil -- optional, frames slide to their new position while this returns true, requires calling Animate every frame
---@return AtDynamicGroup
private.DynamicGroup.Create = function(getSettings, getAnchor, resolveGrow, shouldAnimate)
   local group = {
      items = {},
      index = {},
      dirty = false,
      leadOffset = 0,
      getSettings = getSettings,
      getAnchor = getAnchor,
      resolveGrow = resolveGrow,
      shouldAnimate = shouldAnimate,
   }
   for key, value in pairs(groupMixin) do
      group[key] = value
   end
   return group
end

---appends all entries of source to target
---@param target table
---@param source table
---@return table target
private.DynamicGroup.AppendSettings = function(target, source)
   for _, entry in ipairs(source) do
      table.insert(target, entry)
   end
   return target
end

---builds the shared edit mode settings (grow, spacing, limit, sort) of a dynamic group
---@param getDb fun(layoutName:string):table -- returns the settings table of the layout
---@param onChange fun(layoutName:string) -- called after any setting changed
---@param opts table -- growValues, allowAuto, defaults, hidden, growKey, spacingKey, noSpacing, growDescription, spacingName, spacingDescription
---@return table settings
private.DynamicGroup.BuildEditModeSettings = function(getDb, onChange, opts)
   local growKey = opts.growKey or "grow"
   local spacingKey = opts.spacingKey or "spacing"
   local defaults = opts.defaults or {}
   local growValues = {}
   if opts.allowAuto then
      table.insert(growValues, {
         text = private.getLocalisation(GROW_LOCALISATION[GROW.AUTO]),
         value = GROW.AUTO,
         isRadio = true,
      })
   end
   for _, grow in ipairs(opts.growValues) do
      table.insert(growValues, {
         text = private.getLocalisation(GROW_LOCALISATION[grow]),
         value = grow,
         isRadio = true,
      })
   end

   local settings = {
      {
         name = private.getLocalisation("GrowDirection"),
         desc = opts.growDescription or private.getLocalisation("IconGrowDirectionDescription"),
         kind = LibEditMode.SettingType.Dropdown,
         get = function(layoutName)
            return getDb(layoutName)[growKey]
         end,
         set = function(layoutName, value)
            getDb(layoutName)[growKey] = value
            onChange(layoutName)
         end,
         default = defaults.grow,
         height = 150,
         values = growValues,
         hidden = opts.hidden,
         disabled = opts.disabled,
      },
   }
   if not opts.noSpacing then
      table.insert(settings, {
         name = opts.spacingName or private.getLocalisation("GroupSpacing"),
         desc = opts.spacingDescription or private.getLocalisation("GroupSpacingDescription"),
         kind = LibEditMode.SettingType.Slider,
         default = defaults.spacing,
         get = function(layoutName)
            return getDb(layoutName)[spacingKey]
         end,
         set = function(layoutName, value)
            getDb(layoutName)[spacingKey] = value
            onChange(layoutName)
         end,
         minValue = 0,
         maxValue = 50,
         valueStep = 1,
         hidden = opts.hidden,
         disabled = opts.disabled,
      })
   end
   table.insert(settings, {
      name = private.getLocalisation("GroupLimit"),
      desc = private.getLocalisation("GroupLimitDescription"),
      kind = LibEditMode.SettingType.Slider,
      default = defaults.limit or 0,
      get = function(layoutName)
         return getDb(layoutName).limit
      end,
      set = function(layoutName, value)
         getDb(layoutName).limit = value
         onChange(layoutName)
      end,
      minValue = 0,
      maxValue = 20,
      valueStep = 1,
      hidden = opts.hidden,
      disabled = opts.disabled,
   })
   table.insert(settings, {
      name = private.getLocalisation("GroupSort"),
      desc = private.getLocalisation("GroupSortDescription"),
      kind = LibEditMode.SettingType.Dropdown,
      get = function(layoutName)
         return getDb(layoutName).sort
      end,
      set = function(layoutName, value)
         getDb(layoutName).sort = value
         onChange(layoutName)
      end,
      default = defaults.sort or SORT.ASCENDING,
      height = 50,
      values = {
         {
            text = private.getLocalisation("GroupSortAscending"),
            value = SORT.ASCENDING,
            isRadio = true,
         },
         {
            text = private.getLocalisation("GroupSortDescending"),
            value = SORT.DESCENDING,
            isRadio = true,
         },
      },
      hidden = opts.hidden,
      disabled = opts.disabled,
   })
   return settings
end
