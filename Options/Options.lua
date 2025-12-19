local appName, private = ...
local SharedMedia = LibStub("LibSharedMedia-3.0")
---@type AceConfigOptionsTable
private.options = {
  name = private.getLocalisation("addonOptions"),
  type = "group",
  args = {
    reminderBrowser = {
      name = private.getLocalisation("reminderBrowser"),
      desc = private.getLocalisation("reminderBrowserDescription"),
      type = "group",
      order = 10,
      args = {
        recent_encounters = {
          name = private.getLocalisation("CreatedReminders"),
          desc = private.getLocalisation("CreatedRemindersDescription"),
          type = "select",
          order = 21,
          values = function()
            local out = {}
            if private.db and private.db.profile and private.db.profile.reminders then
              for id, stored in pairs(private.db.profile.reminders) do
                local encName = nil
                local instName = nil
                -- Prefer explicit reminderMeta mapping if present
                if private.db.profile.reminderMeta and private.db.profile.reminderMeta[id] then
                  local m = private.db.profile.reminderMeta[id]
                  if m.name then
                    encName = m.name
                  elseif m.journalEncounterID then
                    encName = EJ_GetEncounterInfo(m.journalEncounterID)
                  end
                  if m.journalInstanceID then
                    instName = EJ_GetInstanceInfo(m.journalInstanceID)
                  end
                end
                -- Fallback to stored reminder entries if needed
                if not encName and type(stored) == "table" and #stored > 0 then
                  local first = stored[1]
                  if first and first.journalEncounterID then
                    encName = EJ_GetEncounterInfo(first.journalEncounterID)
                  end
                  if first and first.journalInstanceID then
                    instName = EJ_GetInstanceInfo(first.journalInstanceID)
                  end
                end
                local display = encName or ("Encounter " .. tostring(id))
                if instName and instName ~= "" then
                  display = string.format("%s — %s", instName, display)
                end
                out[tostring(id)] = display
              end
            end
            return out
          end,
          set = function(info, val) private._recentSelected = tonumber(val) end,
          get = function(info) return tostring(private._recentSelected or "") end,
          width = "full",
        },
        open_recent = {
          name = private.getLocalisation("OpenSelectedReminderEditor"),
          desc = private.getLocalisation("OpenSelectedReminderEditorDescription"),
          type = "execute",
          order = 22,
          disabled = function() return not private._recentSelected end,
          func = function()
            local sel = private._recentSelected
            -- Open the selected saved encounter (keyed by dungeonEncounterID)
            private.RegisterEncounter(sel, nil, false)
            if private.openTimingsEditor then
              local params = nil
              -- Prefer stored reminderMeta if available
              if private.db.profile.reminderMeta and private.db.profile.reminderMeta[sel] then
                local m = private.db.profile.reminderMeta[sel]
                params = { journalEncounterID = m.journalEncounterID, journalInstanceID = m.journalInstanceID, dungeonEncounterID = tonumber(sel), name = m.name }
              else
                local stored = private.db.profile.reminders[sel]
                if type(stored) == "table" and #stored > 0 then
                  local first = stored[1]
                  if first and (first.journalEncounterID or first.journalInstanceID) then
                    params = { journalEncounterID = first.journalEncounterID, journalInstanceID = first.journalInstanceID, dungeonEncounterID = tonumber(sel) }
                  end
                end
              end
              if params then
                private.openTimingsEditor(params)
              end
            end
          end,
        },
      },
    },
    debugMode = {
      name = private.getLocalisation("debugMode"),
      desc = private.getLocalisation("debugModeDescription"),
      order = 30,
      width = "full",
      type = "toggle",
      set = function(info, val) private.db.profile.debugMode = val end, --Sets value of SavedVariables depending on toggles
      get = function(info)
        return private.db.profile.debugMode                                                 --Sets value of toggles depending on SavedVariables
      end,
    },
    useAudioCountdowns = {
      name = private.getLocalisation("useAudioCountdowns"),
      desc = private.getLocalisation("useAudioCountdownsDescription"),
      order = 40,
      width = "full",
      type = "toggle",
      set = function(info, val) private.db.profile.useAudioCountdowns = val end, --Sets value of SavedVariables depending on toggles
      get = function(info)
        return private.db.profile.useAudioCountdowns  --Sets value of toggles depending on SavedVariables
      end,
    },
    enableKeyRerollTimer = {
      name = private.getLocalisation("enableKeyRerollTimer"),
      desc = private.getLocalisation("enableKeyRerollTimerDescription"),
      order = 40,
      width = "full",
      type = "toggle",
      set = function(info, val) private.db.profile.enableKeyRerollTimer = val end, --Sets value of SavedVariables depending on toggles
      get = function(info)
        return private.db.profile.enableKeyRerollTimer  --Sets value of toggles depending on SavedVariables
      end,
    },
    encounterOptions = {
      name = private.getLocalisation("reminderOptions"),
      desc = private.getLocalisation("reminderOptionsDescription"),
      type = "group",
      args = {

      },
    },

  }
}
OPTIONS_INITIALIZED = false
private.buildInstanceOptions = function()
  if OPTIONS_INITIALIZED then return end
  for dungeonId, dungeonValue in pairs(private.Instances) do
    EJ_SelectInstance(dungeonId)
    local Instancename, Instancedescription, _, InstanceImage, _, _, _, _, _ = EJ_GetInstanceInfo()
    private.options.args.encounterOptions.args["dungeon" .. dungeonId] = {
      name = Instancename,
      -- description = Instancedescription,
      -- image = InstanceImage,
      type = "group",
      order = dungeonId,
      args = {}
    }
    for encounterNumber, encounterID in pairs(dungeonValue.encounters) do
      local EncounterName, Encounterdescription, journalEncounterID, rootSectionID, link, journalInstanceID, dungeonEncounterID, instanceID =
      EJ_GetEncounterInfoByIndex(encounterNumber, dungeonId)
      private.options.args.encounterOptions.args["dungeon" .. dungeonId].args["encounter" .. encounterNumber] = {
        name = EncounterName,
        -- description = Encounterdescription,
        -- image = InstanceImage,
        type = "group",
        order = encounterNumber,
        args = {
          OptionsButton = {
            name = private.getLocalisation("EditTimingsForEncounter") .. ": " .. EncounterName,
            type = "execute",
            order = 0,
            func = function() 
              local encounterID = private.Instances[dungeonId] and private.Instances[dungeonId].encounters and private.Instances[dungeonId].encounters[encounterNumber]
              private.openTimingsEditor(dungeonId, encounterNumber, encounterID) 
            end
          },
        }
      }
    end
  end
  OPTIONS_INITIALIZED = true
end
