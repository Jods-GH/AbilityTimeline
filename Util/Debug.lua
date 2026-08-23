local appName, app = ...
---@class AbilityTimeline
local private = app

---Prints debug value to chat or adds table to Devtool (when installed) when debugmode is enabled
---@param debugValue any --value to print to chat or add to DevTool
---@param tableName string? --optional name for the table when using DevTool
private.Debug = function(debugValue, tableName)
    -- Boss mod plugins can fire events before AceDB has initialized; don't crash on early events.
    if not (private.db and private.db.profile and private.db.profile.debugMode) then
        return
    end
    if type(debugValue) == "table" then
        if DevTool then
            DevTool:AddData(debugValue, tableName or "DebugTable")
            return
        else
            print("AbilityTimeline DEBUG (" .. tableName .. "):")
            for k, v in pairs(debugValue) do
                print("  " .. tostring(k) .. " = " .. tostring(v))
            end
        end
    else
        print("AbilityTimeline DEBUG: " .. tostring(debugValue))
    end
end
