local appName, app = ...
---@class AbilityTimeline
local private = app
local SharedMedia = LibStub("LibSharedMedia-3.0")

-- the theme art of Media/Textures/Theme (tools/textures/generate.py), registered with SharedMedia by name, so names
-- stay unique across the folders. Shared holds what the engine, the widgets or several themes use, every theme
-- registers its own folder with RegisterThemeTextures
local TEXTURES = "Interface\\AddOns\\AbilityTimeline\\Media\\Textures\\Theme\\"
local SHARED_TEXTURES = {
    "check", "chevron", "circle", "close", "cracks", "dust", "fel_ember", "flake", "frost", "glint", "glow", "gradient", "ice",
    "leaf", "minus", "mote", "panel", "panel_edge", "pill", "plus", "ring", "shadow", "thumb",
}
-- the pieces ice shatters into, Util/Transitions.lua cuts shards with them
for i = 1, 10 do
    table.insert(SHARED_TEXTURES, "shard" .. i)
end

---the SharedMedia background name of a texture of Media/Textures/Theme
---@param name string
---@return string
private.MediaName = function(name)
    return "AbilityTimeline " .. name
end

---registers the textures of a theme's folder of Media/Textures/Theme, dissolves are the names of Ghost.Dissolve frame
---sets: <name>1..12 and <name>_edge1..12, Util/Transitions.lua steps through them
---@param folder string
---@param names string[]
---@param dissolves string[]|nil
private.RegisterThemeTextures = function(folder, names, dissolves)
    local path = TEXTURES .. folder .. "\\"
    for _, name in ipairs(names) do
        SharedMedia:Register("background", private.MediaName(name), path .. name .. ".tga")
    end
    for _, name in ipairs(dissolves or {}) do
        for i = 1, 12 do
            SharedMedia:Register("background", private.MediaName(name .. i), path .. name .. i .. ".tga")
            SharedMedia:Register("background", private.MediaName(name .. "_edge" .. i), path .. name .. "_edge" .. i .. ".tga")
        end
    end
end

private.RegisterThemeTextures("Shared", SHARED_TEXTURES)
