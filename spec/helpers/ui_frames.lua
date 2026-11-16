-- ui_frames.lua: the UI the client creates before addons load and the globals no fetched file defines. Frames are
-- built with the world's widget engine (their methods are the documented ones); what the client's own addons add to
-- them is kept to the members the addon uses, each with its warcraft.wiki.gg or Blizzard source reference.
local M = {}

-- Localized global strings the addon reads (GlobalStrings.lua is not part of the UI source), set to their enUS text.
M.GLOBAL_STRINGS = {
    CANCEL = "Cancel",
    OKAY = "Okay",
    RELOADUI = "Reload UI",
    COMBAT_WARNINGS_HIDE_QUEUED_COUNTDOWNS_LABEL = "Hide Queued Countdowns",
    COMBAT_WARNINGS_HIDE_QUEUED_COUNTDOWNS_TOOLTIP = "Hides countdowns of queued events.",
}

function M.Install(world, env)
    local widgets = world.widgets

    -- UIParent and WorldFrame: the screen, 1920x1080 at the bottom left (API_UIParent)
    local function screen(name)
        if env[name] then return env[name] end
        local frame = widgets.New("Frame", name)
        widgets.State(frame).screen = { width = 1920, height = 1080 }
        return frame
    end
    screen("WorldFrame")
    screen("UIParent")

    for name, text in pairs(M.GLOBAL_STRINGS) do
        if env[name] == nil then env[name] = text end
    end

    -- FrameXML/Fonts.xml font paths and font objects (Blizzard_SharedXML Fonts.xml)
    env.STANDARD_TEXT_FONT = env.STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
    env.DAMAGE_TEXT_FONT = env.DAMAGE_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
    for _, name in ipairs({ "GameFontNormal", "GameFontHighlight", "GameFontHighlightSmall", "GameFontNormalSmall",
        "GameFontNormalLarge", "GameFontDisable", "GameFontHighlightLarge", "ChatFontNormal", "NumberFontNormal" }) do
        if not env[name] then
            local font = widgets.CreateFont(name)
            font:SetFont(env.STANDARD_TEXT_FONT, 12, "")
        end
    end

    -- API_IsInGroup: LE_PARTY_CATEGORY_INSTANCE is the instance group (2)
    env.LE_PARTY_CATEGORY_HOME = env.LE_PARTY_CATEGORY_HOME or 1
    env.LE_PARTY_CATEGORY_INSTANCE = env.LE_PARTY_CATEGORY_INSTANCE or 2

    -- Blizzard_StaticPopup/StaticPopup.lua: StaticPopupDialogs and StaticPopup_Show; shown popups are recorded
    env.StaticPopupDialogs = env.StaticPopupDialogs or {}
    world.popups = {}
    env.StaticPopup_Show = env.StaticPopup_Show or function(which, text1, text2, data)
        local info = env.StaticPopupDialogs[which]
        if not info then return nil end
        local popup = { which = which, info = info, text1 = text1, text2 = text2, data = data }
        world.popups[#world.popups + 1] = popup
        return popup
    end

    -- Blizzard_UIParentPanelManager: UISpecialFrames, ShowUIPanel, HideUIPanel
    env.UISpecialFrames = env.UISpecialFrames or {}
    env.ShowUIPanel = env.ShowUIPanel or function(frame) if frame then frame:Show() end end
    env.HideUIPanel = env.HideUIPanel or function(frame) if frame then frame:Hide() end end

    -- GameTooltip (Blizzard_SharedXML GameTooltip): a GameTooltip frame
    if not env.GameTooltip then widgets.CreateFrame("GameTooltip", "GameTooltip", env.UIParent) end

    -- DEFAULT_CHAT_FRAME: the chat frame AddMessage writes to (recorded in world.chat)
    world.chat = {}
    if not env.DEFAULT_CHAT_FRAME then
        local chat = widgets.CreateFrame("Frame", "ChatFrame1", env.UIParent)
        function chat:AddMessage(text) world.chat[#world.chat + 1] = text end
        env.DEFAULT_CHAT_FRAME = chat
    end

    -- Blizzard_EditMode: EditModeManagerFrame with AccountSettings, Enter/ExitEditMode
    if not env.EditModeManagerFrame then
        local manager = widgets.CreateFrame("Frame", "EditModeManagerFrame", env.UIParent)
        manager:Hide()
        manager.AccountSettings = widgets.CreateFrame("Frame", nil, manager)
        function manager:IsEditModeActive() return self:IsShown() end
        function manager:EnterEditMode() self:Show() end
        function manager:ExitEditMode() self:Hide() end
    end

    -- Blizzard_EncounterTimeline (Retail): the EncounterTimeline frame the addon hides when it shows its own timeline
    if world.info.retail and not env.EncounterTimeline then
        widgets.CreateFrame("Frame", "EncounterTimeline", env.UIParent)
    end

    -- Blizzard_Settings_Shared: Settings and SettingsPanel, the members the addon uses
    if not env.SettingsPanel then widgets.CreateFrame("Frame", "SettingsPanel", env.UIParent):Hide() end
    if not env.Settings then
        world.settingsCategories = {}
        env.Settings = {
            RegisterCanvasLayoutCategory = function(frame, name)
                local category = { frame = frame, name = name, ID = name }
                function category:GetID() return self.ID end
                world.settingsCategories[#world.settingsCategories + 1] = category
                return category
            end,
            RegisterCanvasLayoutSubcategory = function(parent, frame, name)
                local category = { frame = frame, name = name, ID = name, parent = parent }
                function category:GetID() return self.ID end
                world.settingsCategories[#world.settingsCategories + 1] = category
                return category
            end,
            RegisterAddOnCategory = function(category) category.registered = true end,
            OpenToCategory = function(id) world.openedCategory = id end,
        }
    end

    -- Blizzard_Menu MenuUtil: CreateContextMenu records the menu the generator builds
    if not env.MenuUtil then
        world.menus = {}
        env.MenuUtil = {
            CreateContextMenu = function(owner, generator)
                local menu = { owner = owner, entries = {} }
                local root = {}
                function root:CreateButton(text, callback, data)
                    local entry = { kind = "button", text = text, callback = callback, data = data }
                    menu.entries[#menu.entries + 1] = entry
                    return entry
                end
                function root:CreateTitle(text) menu.entries[#menu.entries + 1] = { kind = "title", text = text } end
                function root:CreateDivider() menu.entries[#menu.entries + 1] = { kind = "divider" } end
                generator(owner, root)
                world.menus[#world.menus + 1] = menu
                return menu
            end,
        }
    end

    -- Blizzard_EncounterJournal: the journal frame, the micro button and EncounterJournal_OpenJournal
    if not env.EJMicroButton then widgets.CreateFrame("Button", "EJMicroButton", env.UIParent) end
    env.EncounterJournal_OpenJournal = env.EncounterJournal_OpenJournal or function(...)
        world.openedJournal = { ... }
    end
end

return M
