local appName, app = ...
---@class AbilityTimeline
local private = app
local SharedMedia = LibStub("LibSharedMedia-3.0")

-- Internal theme art uses its own SharedMedia type so masks, sprites and controls stay out of background pickers.
-- Shared holds what the engine, the widgets or several themes use; every theme registers its own folder.
private.ThemeMediaType = "bt_theme"
local TEXTURES = "Interface\\AddOns\\AbilityTimeline\\Media\\Textures\\Theme\\"
local SHARED_TEXTURES = {
    "check", "chevron", "circle", "close", "cracks", "dust", "fel_ember", "flake", "fog_patch", "frost", "glass_bead",
    "glassdrop", "glassfog", "glassreflect", "glassshine", "glint", "glow", "gradient", "ice", "leaf", "minus", "mote", "panel",
    "panel_edge", "pill", "plus", "ring", "shadow", "thumb", "undo",
}
-- the pieces ice shatters into, Util/Transitions.lua cuts shards with them
for i = 1, 10 do
    table.insert(SHARED_TEXTURES, "shard" .. i)
end

---the SharedMedia name of a texture of Media/Textures/Theme
---@param name string
---@return string
private.MediaName = function(name)
    return "BT " .. name
end

local mediaPreviews = {}

---registers a composite media preview without duplicating its texture artwork
private.RegisterMediaPreview = function(mediaType, name, draw, reset)
    mediaPreviews[mediaType] = mediaPreviews[mediaType] or {}
    mediaPreviews[mediaType][name] = { Draw = draw, Reset = reset }
end

private.GetMediaPreview = function(mediaType, name)
    return mediaPreviews[mediaType] and mediaPreviews[mediaType][name]
end

---registers the textures of a theme's folder of Media/Textures/Theme, dissolves are the names of Ghost.Dissolve frame
---sets: <name>1..12 and <name>_edge1..12, Util/Transitions.lua steps through them
---@param folder string
---@param names string[]
---@param dissolves string[]|nil
private.RegisterThemeTextures = function(folder, names, dissolves)
    local path = TEXTURES .. folder .. "\\"
    for _, name in ipairs(names) do
        SharedMedia:Register(private.ThemeMediaType, private.MediaName(name), path .. name .. ".tga")
    end
    for _, name in ipairs(dissolves or {}) do
        for i = 1, 12 do
            SharedMedia:Register(private.ThemeMediaType, private.MediaName(name .. i), path .. name .. i .. ".tga")
            SharedMedia:Register(private.ThemeMediaType, private.MediaName(name .. "_edge" .. i), path .. name .. "_edge" .. i .. ".tga")
        end
    end
end

private.RegisterThemeTextures("Shared", SHARED_TEXTURES)
