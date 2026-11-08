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

local GROW_LOCALISATION = {
   [GROW.UP] = "GrowDirectionUp",
   [GROW.DOWN] = "GrowDirectionDown",
   [GROW.LEFT] = "GrowDirectionLeft",
   [GROW.RIGHT] = "GrowDirectionRight",
   [GROW.HORIZONTAL] = "GrowDirectionHorizontal",
   [GROW.VERTICAL] = "GrowDirectionVertical",
   [GROW.AUTO] = "GrowDirectionAuto",
}

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

---builds the shared edit mode settings (grow, spacing) of a dynamic group, its limit and sort are in the settings window
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
   return settings
end
