-- ui_frames.lua: the UI the client creates before addons load and the globals no fetched file defines. Frames are
-- built with the world's widget engine (their methods are the documented ones); what the client's own addons add to
-- them is kept to the members the addon uses, each with its warcraft.wiki.gg or Blizzard source reference.
local M = {}


---UIParent and WorldFrame, which exist before any UI file loads: the screen, 1920x1080 at the bottom left
function M.InstallScreen(world, env)
    for _, name in ipairs({ "WorldFrame", "UIParent" }) do
        if not env[name] then
            local frame = world.widgets.New("Frame", name)
            world.widgets.State(frame).screen = { width = 1920, height = 1080 }
        end
    end
end

function M.Install(world, env)
    local widgets = world.widgets

    -- Font paths the client sets in C before the UI loads (warcraft.wiki.gg/wiki/STANDARD_TEXT_FONT); the font
    -- objects themselves come from Blizzard's font XML (spec/helpers/xml_templates.lua)
    env.STANDARD_TEXT_FONT = env.STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
    env.DAMAGE_TEXT_FONT = env.DAMAGE_TEXT_FONT or "Fonts\\FRIZQT__.TTF"

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

    -- GameTooltip (Blizzard_GameTooltip GameTooltip.xml): a GameTooltip widget; its methods are the documented ones
    if not env.GameTooltip then widgets.CreateFrame("GameTooltip", "GameTooltip", env.UIParent):Hide() end

    -- Blizzard_EditMode EditModeManager.lua: showing the manager enters Edit Mode (OnShow -> EnterEditMode ->
    -- EventRegistry "EditMode.Enter"), hiding it leaves (OnHide -> ExitEditMode -> "EditMode.Exit"); SelectSystem and
    -- ClearSelectedSystem select Edit Mode systems; AccountSettings holds the account setting check buttons. The
    -- client's EditMode UI needs GlobalStrings, which the UI source lacks, so it cannot load here.
    if not env.EditModeManagerFrame then
        local manager = widgets.CreateFrame("Frame", "EditModeManagerFrame", env.UIParent)
        manager:Hide()
        manager.AccountSettings = widgets.CreateFrame("Frame", nil, manager)
        manager.AccountSettings.settingsCheckButtons = {}
        function manager.AccountSettings.RefreshEncounterEvents() end
        function manager:IsEditModeActive() return self.editModeActive == true end
        function manager:EnterEditMode()
            self.editModeActive = true
            if env.EventRegistry then env.EventRegistry:TriggerEvent("EditMode.Enter") end
        end
        function manager:ExitEditMode()
            self.editModeActive = false
            if env.EventRegistry then env.EventRegistry:TriggerEvent("EditMode.Exit") end
        end
        function manager:SelectSystem(systemFrame) self.selectedSystem = systemFrame end
        function manager:ClearSelectedSystem() self.selectedSystem = nil end
        function manager:ShowNewLayoutDialog() self.newLayoutDialogShown = true end
        manager:SetScript("OnShow", manager.EnterEditMode)
        manager:SetScript("OnHide", manager.ExitEditMode)
    end
    -- Blizzard_EditMode EditModeDialogs.xml: the settings dialog of the selected system
    if not env.EditModeSystemSettingsDialog then
        widgets.CreateFrame("Frame", "EditModeSystemSettingsDialog", env.UIParent):Hide()
    end
    -- Blizzard_FrameXML ColorPickerFrame (ColorPickerFrame.lua): SetupColorPickerAndShow(info) shows the picker for
    -- info's color and callbacks; GetColorRGB/GetColorAlpha read the picked color
    if not env.ColorPickerFrame then
        local picker = widgets.CreateFrame("Frame", "ColorPickerFrame", env.UIParent)
        picker:Hide()
        picker.color = { r = 1, g = 1, b = 1, a = 1 }
        function picker:SetupColorPickerAndShow(info)
            self.info = info
            self.func, self.opacityFunc, self.cancelFunc = info.swatchFunc, info.opacityFunc, info.cancelFunc
            self.hasOpacity, self.opacity = info.hasOpacity, info.opacity
            self.color = { r = info.r or 1, g = info.g or 1, b = info.b or 1, a = info.opacity or 1 }
            self:Show()
        end
        function picker:SetColorRGB(r, g, b) self.color.r, self.color.g, self.color.b = r, g, b end
        function picker:GetColorRGB() return self.color.r, self.color.g, self.color.b end
        function picker:GetColorAlpha() return self.color.a end
    end

    -- DEFAULT_CHAT_FRAME: the chat frame AddMessage writes to (recorded in world.chat)
    world.chat = {}
    if not env.DEFAULT_CHAT_FRAME then
        local chat = widgets.CreateFrame("Frame", "ChatFrame1", env.UIParent)
        function chat.AddMessage(_, text) world.chat[#world.chat + 1] = text end
        env.DEFAULT_CHAT_FRAME = chat
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
            GetCategory = function(id)
                for _, category in ipairs(world.settingsCategories) do
                    if category.ID == id then return category end
                end
            end,
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
                function root.CreateButton(_, text, callback, data)
                    local entry = { kind = "button", text = text, callback = callback, data = data }
                    menu.entries[#menu.entries + 1] = entry
                    return entry
                end
                function root.CreateTitle(_, text) menu.entries[#menu.entries + 1] = { kind = "title", text = text } end
                function root.CreateDivider() menu.entries[#menu.entries + 1] = { kind = "divider" } end
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
