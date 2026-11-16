-- Every WoW global and C_* function the addon reads (.luacheckrc lists all of them, so lint keeps the list complete)
-- either exists on each client the TOC supports, or is listed below with what makes its use safe there. A new use of
-- something a client lacks fails here until its guard is reviewed and recorded.
local Docs = require("spec.helpers.api_docs")
local Toc = require("spec.helpers.toc")
local World = require("spec.helpers.world")
local WholeAddon = require("spec.helpers.whole_addon")

-- name -> why the addon may read it although a client lacks it
local MAY_BE_MISSING = {
    -- other addons' globals, read only when that addon is loaded (Plugins/, Themes/, Util/Debug.lua)
    AddOnSkins = "Plugins/Dbm.lua checks it before skinning DBM bars",
    BigWigs = "Plugins/BigWigs.lua loads only with BigWigs",
    BigWigsLoader = "Plugins/BigWigs.lua loads only with BigWigs",
    DBM = "Plugins/Dbm.lua loads only with DBM-Core",
    DBT = "Plugins/Dbm.lua, which loads only with DBM-Core (DBM defines DBT)",
    DevTool = "Util/Debug.lua checks it before handing tables over",
    ElvUI = "Themes/ElvUI.lua is available only with ElvUI",
    EllesmereUI = "Themes/EllesmereUI.lua is available only with EllesmereUI",
    EllesmereUIDB = "Themes/EllesmereUI.lua reads it only with EllesmereUI",
    EUI_CLIENT_BLOCKED = "Themes/EllesmereUI.lua: not EUI_CLIENT_BLOCKED and EllesmereUI",
    GW2_ADDON = "Themes/GW2UI.lua is available only with GW2_UI",
    -- created by the addon itself
    AbilityTimelineEJAddButton = "created by Util/EncounterBrowser.lua",
    -- Blizzard_EncounterJournal is load on demand
    EncounterJournal = "Util/EncounterBrowser.lua and Options/Tour.lua check it or run once the journal loaded",
    EncounterJournalEncounterFrameInfoModelTab = "Util/EncounterBrowser.lua uses it once the journal loaded",
    -- Retail only
    EncounterTimeline = "Plugins/EncounterTimeline.lua returns unless private.isRetail",
    COMBAT_WARNINGS_HIDE_QUEUED_COUNTDOWNS_LABEL = "Options/Pages/Elements.lua hides the row unless private.isRetail",
    COMBAT_WARNINGS_HIDE_QUEUED_COUNTDOWNS_TOOLTIP = "Options/Pages/Elements.lua hides the row unless private.isRetail",
    ["C_ChallengeMode.GetActiveKeystoneInfo"] = "Main.lua registers CHALLENGE_MODE_START only when private.isRetail",
    ["C_SpellBook.GetNumSpellBookSkillLines"] = "Templates/AtTimingsEditorDataFrame.lua: C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines",
    ["C_SpellBook.GetSpellBookSkillLineInfo"] = "Templates/AtTimingsEditorDataFrame.lua, inside the GetNumSpellBookSkillLines guard",
    ["C_SpellBook.GetSpellBookItemInfo"] = "Templates/AtTimingsEditorDataFrame.lua, inside the GetNumSpellBookSkillLines guard",
    ["C_Weather.GetCurrentWeather"] = "Util/Theme.lua checks C_Weather first",
    -- fallbacks for older clients
    GetMouseFocus = "Util/Debug.lua: GetMouseFoci and GetMouseFoci() or { GetMouseFocus() }",
    InterfaceOptions_AddCategory = "Options/Options.lua uses it only when Settings.RegisterCanvasLayoutCategory is missing",
    -- Titan has no runtime dump, so Blizzard's Constants.lua stops before defining it (spec/helpers/client_dump.lua)
    LOCALIZED_CLASS_NAMES_MALE = "a gap of the Titan test world, not of the client",
}

local function referencedNames()
    local rc = assert(Toc.Read(World.ROOT .. "/.luacheckrc"))
    local names = {}
    for name in rc:match("read_globals = (%b{})"):gmatch('"([%w_]+)"') do names[#names + 1] = name end
    for namespace, fields in rc:gmatch("read_globals%.([%w_]+) = { fields = (%b{})") do
        for field in fields:gmatch("([%w_]+) = {}") do names[#names + 1] = namespace .. "." .. field end
    end
    return names
end

local function exists(name)
    local namespace, field = name:match("^([^%.]+)%.(.+)$")
    if namespace then return type(_G[namespace]) == "table" and _G[namespace][field] ~= nil end
    return _G[name] ~= nil
end

describe("APIs the addon reads", function()
    -- client -> names it lacks once the whole addon is loaded
    local missing, missingSomewhere = {}, {}
    setup(function()
        for _, client in ipairs(Docs.CLIENT_ORDER) do
            WholeAddon.Load({ client = client })
            missing[client] = {}
            for _, name in ipairs(referencedNames()) do
                if not exists(name) then
                    table.insert(missing[client], name)
                    missingSomewhere[name] = true
                end
            end
        end
    end)

    for _, client in ipairs(Docs.CLIENT_ORDER) do
        it("exist on " .. client .. " or are known to be guarded", function()
            for _, name in ipairs(missing[client]) do
                assert.is_string(MAY_BE_MISSING[name], name .. " is missing on " .. client .. " and its use is not reviewed")
            end
        end)
    end

    -- CVar_loadDeprecationFallbacks: Blizzard_Deprecated* addons provide removed APIs only while it is on, and are
    -- removed at the next expansion, so the addon must not need them
    for _, client in ipairs(Docs.CLIENT_ORDER) do
        it("starts on " .. client .. " without Blizzard's deprecated API fallbacks", function()
            local handle = WholeAddon.Load({ client = client, cvars = { loadDeprecationFallbacks = "0" } }):Start()
            assert.is_nil(rawget(_G, "IsEncounterInProgress"))
            assert.same({}, handle.errors)
        end)
    end

    it("lists only names that some client lacks", function()
        for name in pairs(MAY_BE_MISSING) do
            assert.is_true(missingSomewhere[name] == true, name .. " exists on every client: remove it from the list")
        end
    end)
end)
