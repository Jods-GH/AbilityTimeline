local appName, private = ...
local SharedMedia = LibStub("LibSharedMedia-3.0")
---@type AceConfigOptionsTable
private.options = {
  name = private.getLocalisation("addonOptions"),
  type = "group",
  args = {
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
    encounterOptions = {
      name = private.getLocalisation("encounterOptions"),
      type = "group",
      args = {

      },
    },

  }
}
OPTIONS_INITIALIZED = false
private.buildInstanceOptions = function()
  if OPTIONS_INITIALIZED then return end
  for dungeonId, dungeonValue in pairs(private.encounterTable) do
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
    for encounterNumber, encounterValue in pairs(dungeonValue) do
      local EncounterName, Encounterdescription, journalEncounterID, rootSectionID, link, journalInstanceID, dungeonEncounterID, instanceID =
      EJ_GetEncounterInfoByIndex(encounterNumber)
      local id, name, description, displayInfo, iconImage, uiModelSceneID = EJ_GetCreatureInfo(1,
        encounterValue.journalId)

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
            func = function() private.openTimingsEditor(dungeonId, encounterNumber) end
          },
        }
      }
    end
  end
  OPTIONS_INITIALIZED = true
end
