local appName, app = ...
---@class AbilityTimeline
local private = app
local AceGUI = LibStub("AceGUI-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local L = private.getLocalisation

-- the profiles page, AceDBOptions as Ace draws it, registered by Main.lua under this name
private.PROFILES_OPTIONS = appName .. "Profiles"

private.RegisterSettingsPage({
    key = "Profiles",
    order = 70,
    name = L("SettingsPageProfiles"),
    desc = L("SettingsPageProfilesDescription"),
    rows = {},
    Render = function(scroll)
        -- Ace adds its controls straight into a simple group, a scroll frame of its own would sit in ours
        local group = AceGUI:Create("SimpleGroup")
        group:SetLayout("Flow")
        group:SetFullWidth(true)
        scroll:AddChild(group)
        AceConfigDialog:Open(private.PROFILES_OPTIONS, group)
    end,
})
