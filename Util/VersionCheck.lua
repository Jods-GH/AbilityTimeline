local appName, app = ...
---@class AbilityTimeline
local private = app
local AceCom = LibStub("AceComm-3.0")
local issecretvalue = issecretvalue or function() return false end
local InChatMessagingLockdown = C_ChatInfo.InChatMessagingLockdown or function() return false end
local VERSION_PREFIX = "ATVersion"
local VERSION = C_AddOns.GetAddOnMetadata(appName, "Version")

---returns a key of the release tag that compares as a string, nil for anything that isn't a tag
---@param version string
---@return string|nil
local sortKey = function(version)
    local major, minor, patch, letter = string.match(version, "^v?(%d+)%.(%d+)%.?(%d*)(%a?)")
    if not major then return nil end
    return ("%04d%04d%04d%s"):format(major, minor, tonumber(patch) or 0, letter)
end

local OWN_KEY = sortKey(VERSION)
if not OWN_KEY then return end

local pendingReplies = {}
local notified = false
local groupChannel

---@param distribution string
---@return boolean
local sendVersion = function(distribution)
    if InChatMessagingLockdown() then return false end
    AceCom:SendCommMessage(VERSION_PREFIX, VERSION, distribution)
    return true
end

AceCom:RegisterComm(VERSION_PREFIX, function(prefix, message, distribution, sender)
    if InChatMessagingLockdown() or issecretvalue(message) then return end
    local key = sortKey(message)
    if not key then return end
    if key >= OWN_KEY then
        if pendingReplies[distribution] then
            pendingReplies[distribution]:Cancel()
            pendingReplies[distribution] = nil
        end
        if key > OWN_KEY and not notified and not private.db.profile.disableVersionCheckMessage then
            notified = true
            private.Print(private.getLocalisation("NewVersionAvailableMessage"):format(message, VERSION))
        end
    elseif not pendingReplies[distribution] then
        -- everyone newer would answer at once, the first answer cancels the others since it already informs everyone older
        pendingReplies[distribution] = C_Timer.NewTimer(1 + math.random() * 4, function()
            pendingReplies[distribution] = nil
            sendVersion(distribution)
        end)
    end
end)

---sends the version to the guild, delayed since the guild is not always known yet right after login
private.announceGuildVersion = function()
    C_Timer.After(10, function()
        if IsInGuild() then
            sendVersion("GUILD")
        end
    end)
end

---sends the version to the group whenever the group channel changed
private.announceGroupVersion = function()
    local channel = private.FindComChannel()
    if channel ~= groupChannel and (not channel or sendVersion(channel)) then
        groupChannel = channel
    end
end
