local appName, app = ...
---@class AbilityTimeline
local private = app
local L = private.getLocalisation

-- the profiles page, made of AceDB's own methods. Esc > Options keeps the AceDBOptions table, registered by Main.lua
-- under this name
private.PROFILES_OPTIONS = appName .. "Profiles"

---the saved profiles by name, with the ones every character can start (Default, its own name, realm and class) when
---presets is set
---@param withCurrent boolean
---@param presets boolean|nil
---@return table<string, string>
local getProfiles = function(withCurrent, presets)
    local db = private.db
    local current = db:GetCurrentProfile()
    local profiles = {}
    for _, name in ipairs(db:GetProfiles()) do
        profiles[name] = name
    end
    if presets or profiles.Default then
        profiles.Default = L("ProfilesDefault")
    end
    if presets then
        profiles[db.keys.char] = db.keys.char
        profiles[db.keys.realm] = db.keys.realm
        profiles[db.keys.class] = UnitClass("player")
    end
    if not withCurrent then
        profiles[current] = nil
    end
    return profiles
end

local hasNoOthers = function()
    return next(getProfiles(false)) == nil
end

---asks before what can't be undone, the page is rendered again either way so a dropdown shows no choice again
---@param title string
---@param text string
---@param accept string
---@param onAccept function
local confirm = function(title, text, accept, onAccept)
    private.AskQuestion({
        title = title,
        text = text,
        accept = accept,
        acceptStyle = "Danger",
        back = L("ReminderCancelButton"),
        onAccept = function()
            onAccept()
            private.RefreshSettingsPage()
        end,
        onBack = private.RefreshSettingsPage,
    })
end

local setProfile = function(name)
    if name and name ~= "" then
        private.db:SetProfile(name)
    end
    private.RefreshSettingsPage()
end

private.RegisterSettingsPage({
    key = "Profiles",
    order = 70,
    name = L("SettingsPageProfiles"),
    desc = L("SettingsPageProfilesDescription"),
    rows = {
        { kind = "Heading", name = L("ProfilesSectionActive") },
        {
            kind = "Dropdown",
            name = L("ProfilesChoose"),
            desc = L("ProfilesChooseDescription"),
            values = function() return getProfiles(true, true) end,
            get = function() return private.db:GetCurrentProfile() end,
            set = setProfile,
        },
        {
            kind = "Input",
            name = L("ProfilesNew"),
            desc = L("ProfilesNewDescription"),
            get = function() return "" end,
            set = setProfile,
        },
        { kind = "Heading", name = L("ProfilesSectionManage") },
        {
            kind = "Dropdown",
            name = L("ProfilesCopy"),
            desc = L("ProfilesCopyDescription"),
            values = function() return getProfiles(false) end,
            get = function() end,
            set = function(name)
                confirm(L("ProfilesCopyTitle"), L("ProfilesCopyText"):format(private.db:GetCurrentProfile(), name),
                    L("ProfilesCopyButton"), function() private.db:CopyProfile(name) end)
            end,
            disabled = hasNoOthers,
            disabledReason = function() return L("ProfilesNoOthers") end,
        },
        {
            kind = "Dropdown",
            name = L("ProfilesDelete"),
            desc = L("ProfilesDeleteDescription"),
            values = function() return getProfiles(false) end,
            get = function() end,
            set = function(name)
                confirm(L("ProfilesDeleteTitle"), L("ProfilesDeleteText"):format(name), L("ProfilesDeleteButton"),
                    function() private.db:DeleteProfile(name) end)
            end,
            disabled = hasNoOthers,
            disabledReason = function() return L("ProfilesNoOthers") end,
        },
        {
            kind = "Button",
            name = L("ProfilesReset"),
            desc = L("ProfilesResetDescription"),
            buttonText = L("ProfilesResetButton"),
            func = function()
                confirm(L("ProfilesResetTitle"), L("ProfilesResetText"):format(private.db:GetCurrentProfile()),
                    L("ProfilesResetButton"), function() private.db:ResetProfile() end)
            end,
        },
    },
})
