local appName, app = ...
---@class AbilityTimeline
local private = app
local Masque = LibStub("Masque", true)

local GROUP_NAMES = {
    TimelineIcons = "Timeline Icons",
    BigIcons = "Big Icons",
}
local groups = {}
local buttons = setmetatable({}, { __mode = "k" })

---makes an icon frame available to Masque, regions as in Masque's Group:AddButton (Icon, Cooldown)
---@param groupKey string
---@param frame Frame
---@param regions table
private.AddToMasque = function(groupKey, frame, regions)
    if not Masque then return end
    if not groups[groupKey] then
        groups[groupKey] = Masque:Group("Ability Timeline", GROUP_NAMES[groupKey])
    end
    buttons[frame] = { group = groups[groupKey], regions = regions }
end

---adds or removes the frame from its Masque group depending on the theme, returns whether Masque skins it
---@param frame Frame
---@return boolean
private.SyncMasque = function(frame)
    local button = buttons[frame]
    if not button then
        return false
    end
    local useMasque = private.GetCurrentTheme().Masque ~= false
    if useMasque and not button.added then
        button.group:AddButton(frame, button.regions)
    elseif not useMasque and button.added then
        button.group:RemoveButton(frame)
    elseif useMasque and button.size ~= frame:GetWidth() then
        button.group:ReSkin(frame)
    end
    button.added = useMasque
    button.size = frame:GetWidth()
    return useMasque
end
