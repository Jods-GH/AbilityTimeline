local appName, app = ...
---@class AbilityTimeline
local private = app
---validates the encounter ID before opening its reminders
---@param encounterID number|string
---@return boolean
private.RegisterEncounter = function(encounterID)
    encounterID = tonumber(encounterID)
    if not encounterID then return false end
    return true
end

-- Hook Encounter Journal display to add a button for adding the displayed encounter to AbilityTimeline
local createdBtn = false
local lastDisplayedEncounter = nil

local function ensureEJButton()
    if createdBtn then return end
    if not EncounterJournal or not hooksecurefunc then
        return
    end
    -- Hook the display call so we can show a button for the currently shown encounter
    hooksecurefunc("EncounterJournal_DisplayEncounter", function(encounterIndexOrID)
        -- Try to resolve passed value as either a journalEncounterID, a dungeonEncounterID, or an encounter index.
        -- Prefer the dungeonEncounterID (the numeric id fired by ENCOUNTER_START) when available.
        local name, _, journalEncounterID, _, _, journalInstanceID, dungeonEncounterID = EJ_GetEncounterInfo(
        encounterIndexOrID)
        if not journalEncounterID then
            -- get currently selected instance in EJ
            name, _, journalEncounterID, _, _, journalInstanceID, dungeonEncounterID = EJ_GetInstanceInfo()
        end
        -- Update module-level lastDisplayedEncounter so the persistent button's OnClick reads fresh values
        lastDisplayedEncounter = {
            name = name,
            journalEncounterID = journalEncounterID,
            journalInstanceID = journalInstanceID,
            dungeonEncounterID = dungeonEncounterID,
            raw = encounterIndexOrID,
        }
        if not EncounterJournal or not EncounterJournal.encounter then return end
        local infoFrame = EncounterJournal.encounter.info or _G["EncounterJournalEncounterFrameInfo"]
        if not infoFrame then return end
        if not infoFrame.AbilityTimelineAddButton then
            local btn = CreateFrame("Button", "AbilityTimelineEJAddButton", infoFrame, "EncounterTabTemplate")
            btn:SetPoint("TOP", EncounterJournalEncounterFrameInfoModelTab, "BOTTOM", 0, 0)
            btn:SetSize(EncounterJournalEncounterFrameInfoModelTab:GetWidth(), EncounterJournalEncounterFrameInfoModelTab:GetHeight())

            btn.texture = btn:CreateTexture(nil, "OVERLAY")
            btn.texture:SetAllPoints()

            -- for some reason the texture sometimes randomly vanishes so we just reset it on show TODO fix properly
            local function applyTexture()
                btn.texture:SetTexture("Interface\\AddOns\\AbilityTimeline\\Media\\Textures\\logo_transparent.png")
                btn.texture:Show()

                -- match skinning of EJ tabs if relevant for elvui
                if C_AddOns.IsAddOnLoaded("ElvUI") and ElvUI then
                    btn:CreateBackdrop('Transparent')
                    btn.backdrop:SetInside(nil, 1, 1)
                    btn:SetNormalTexture(0)
                    btn:SetPushedTexture(0)
                    btn:SetDisabledTexture(0)
                    local E, L, V, P, G = unpack(ElvUI)
                    local HighlightTexture = btn:GetHighlightTexture()
                    local r, g, b = unpack(E.media.rgbvaluecolor)
                    HighlightTexture:SetColorTexture(r, g, b, .2)
                    HighlightTexture:SetInside(btn.backdrop)
                end

            end
            
            applyTexture()
            btn:HookScript("OnShow", applyTexture)

            btn.tooltip = private.getLocalisation("EditRemindersForEncounter")
            btn:SetText(private.getLocalisation("EditRemindersForEncounter"))
            btn:SetScript("OnClick", function()
                local entry = lastDisplayedEncounter
                if not entry or (not entry.journalEncounterID and not entry.dungeonEncounterID and not entry.raw) then
                    StaticPopupDialogs["ABILITYTIMELINE_CANNOT_RESOLVE"] = StaticPopupDialogs
                    ["ABILITYTIMELINE_CANNOT_RESOLVE"] or {
                        text = private.getLocalisation and private.getLocalisation("CannotResolveEncounter") or
                        "Could not resolve encounter",
                        button1 = OKAY,
                        timeout = 0,
                        whileDead = true,
                        hideOnEscape = true,
                    }
                    StaticPopup_Show("ABILITYTIMELINE_CANNOT_RESOLVE")
                    return
                end
                -- Register encounter and open editor using explicit EJ ids
                local key = entry.dungeonEncounterID or entry.journalEncounterID or entry.raw
                key = tonumber(key) or key
                private.RegisterEncounter(key)
                local params = {
                    journalEncounterID = entry.journalEncounterID,
                    journalInstanceID = entry.journalInstanceID,
                    dungeonEncounterID = entry.dungeonEncounterID or key,
                }
                private.openTimingsEditor(params)
                HideUIPanel(EncounterJournal)
            end)
            EncounterJournalEncounterFrameInfoModelTab:HookScript("OnDisable", function(self)
                btn:DesaturateHierarchy(100)
                btn:Disable()
            end)
            EncounterJournalEncounterFrameInfoModelTab:HookScript("OnEnable", function(self)
                btn:DesaturateHierarchy(0)
                btn:Enable()
                -- Reapply texture after desaturation
                applyTexture()
            end)
            infoFrame.AbilityTimelineAddButton = btn
        else
            infoFrame.AbilityTimelineAddButton:Show()
        end
    end)

    createdBtn = true
end


local ejListener = CreateFrame("Frame")
ejListener:RegisterEvent("ADDON_LOADED")
ejListener:SetScript("OnEvent", function(self, event, name)
    if name == "Blizzard_EncounterJournal" then
        ensureEJButton()
    end
end)
