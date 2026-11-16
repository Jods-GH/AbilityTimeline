std = "lua51+wow"
max_line_length = false
codes = true
exclude_files = {
    "Libs/**", "tools/**", "openwiki/**", "wow ui source/**",
    ".claude/**", ".codex/**", ".vscode/**", ".git/**",
}

-- API names verified against Blizzard_APIDocumentationGenerated and Blizzard UI source.
-- UI globals and optional integrations follow existing addon contracts; see openwiki/operations/testing-and-release.md.
stds.wow = {
    globals = { "AbilityTimeline_AddonCompartmentFunction" },
    read_globals = {
        "AbilityTimelineEJAddButton",
        "AddOnSkins",
        "Ambiguate",
        "BigWigs",
        "BigWigsLoader",
        "bit",
        "CANCEL",
        "COMBAT_WARNINGS_HIDE_QUEUED_COUNTDOWNS_LABEL",
        "COMBAT_WARNINGS_HIDE_QUEUED_COUNTDOWNS_TOOLTIP",
        "CopyTable",
        "CreateColor",
        "CreateFont",
        "CreateFrame",
        "CreateVector2D",
        "DAMAGE_TEXT_FONT",
        "DBM",
        "DBT",
        "DEFAULT_CHAT_FRAME",
        "DevTool",
        "EditModeManagerFrame",
        "EJ_GetCreatureInfo",
        "EJ_GetEncounterInfo",
        "EJ_GetInstanceInfo",
        "EJMicroButton",
        "EllesmereUI",
        "EllesmereUIDB",
        "ElvUI",
        "EncounterJournal",
        "EncounterJournal_OpenJournal",
        "EncounterJournalEncounterFrameInfoModelTab",
        "EncounterTimeline",
        "Enum",
        "EUI_CLIENT_BLOCKED",
        "EventRegistry",
        "GameFontHighlight",
        "GameTooltip",
        "GameTooltip_SetDefaultAnchor",
        "GetBuildInfo",
        "GetClassColor",
        "GetCursorPosition",
        "GetDifficultyInfo",
        "geterrorhandler",
        "GetFileIDFromPath",
        "GetGameTime",
        "GetLocale",
        "GetMouseFoci",
        "GetMouseFocus",
        "GetNormalizedRealmName",
        "GetNumGroupMembers",
        "GetNumSubgroupMembers",
        "GetRaidRosterInfo",
        "GetSpecializationInfoByID",
        "GetTime",
        "GW2_ADDON",
        "HideUIPanel",
        "hooksecurefunc",
        "InCombatLockdown",
        "InterfaceOptions_AddCategory",
        "IsControlKeyDown",
        "IsEncounterInProgress",
        "IsInGroup",
        "IsInGuild",
        "IsInInstance",
        "IsInRaid",
        "IsMouseButtonDown",
        "issecretvalue",
        "IsShiftKeyDown",
        "LE_PARTY_CATEGORY_INSTANCE",
        "LibStub",
        "LOCALIZED_CLASS_NAMES_MALE",
        "MenuUtil",
        "NineSliceUtil",
        "OKAY",
        "PANEL_BACKGROUND_COLOR",
        "PlaySoundFile",
        "RAID_CLASS_COLORS",
        "ReloadUI",
        "RELOADUI",
        "SetCVar",
        "Settings",
        "SettingsPanel",
        "ShowUIPanel",
        "STANDARD_TEXT_FONT",
        "StaticPopup_Show",
        "StaticPopupDialogs",
        "StopSound",
        "strsplit",
        "strtrim",
        "tContains",
        "tDeleteItem",
        "time",
        "tIndexOf",
        "UIParent",
        "UISpecialFrames",
        "UnitClass",
        "UnitInParty",
        "UnitInRaid",
        "UnitIsGroupAssistant",
        "UnitIsGroupLeader",
        "UnitName",
        "UnitNameUnmodified",
        "wipe",
        "WOW_PROJECT_ID",
        "WOW_PROJECT_MAINLINE",
        "WrapTextInColorCode",
    },
}

-- Restrict namespace fields so misspelled API members remain errors.
stds.wow.read_globals.C_AddOns = { fields = {
    GetAddOnMetadata = {},
    IsAddOnLoaded = {},
    LoadAddOn = {},
} }
-- Blizzard_ChatFrameBase/Shared/ChatFrameUtil.lua and ChatFrameFilters.lua (every client)
stds.wow.read_globals.ChatFrameUtil = { fields = {
    ActivateChat = {},
    AddMessageEventFilter = {},
} }
stds.wow.read_globals.C_ChallengeMode = { fields = {
    GetActiveChallengeMapID = {},
    GetActiveKeystoneInfo = {},
    GetChallengeCompletionInfo = {},
    GetMapUIInfo = {},
} }
stds.wow.read_globals.C_ChatInfo = { fields = {
    InChatMessagingLockdown = {},
    RegisterAddonMessagePrefix = {},
    SendAddonMessage = {},
    SendChatMessage = {},
} }
stds.wow.read_globals.C_CVar = { fields = {
    GetCVar = {},
    SetCVar = {},
} }
stds.wow.read_globals.C_DateAndTime = { fields = {
    AdjustTimeByMinutes = {},
    GetCurrentCalendarTime = {},
} }
stds.wow.read_globals.C_EncodingUtil = { fields = {
    CompressString = {},
    DecodeBase64 = {},
    DecompressString = {},
    DeserializeCBOR = {},
    DeserializeJSON = {},
    EncodeBase64 = {},
    SerializeCBOR = {},
} }
stds.wow.read_globals.C_EncounterEvents = { fields = {
    GetEventColor = {},
    GetEventInfo = {},
    GetEventList = {},
    SetEventColor = {},
} }
stds.wow.read_globals.C_EncounterJournal = { fields = {
    GetSectionInfo = {},
} }
stds.wow.read_globals.C_EncounterTimeline = { fields = {
    AddEditModeEvents = {},
    CancelEditModeEvents = {},
    GetEventColor = {},
    GetEventInfo = {},
    GetEventState = {},
    GetEventTimeElapsed = {},
    GetEventTimeRemaining = {},
    GetEventTrack = {},
    GetTrackType = {},
    IsEventBlocked = {},
    IsFeatureAvailable = {},
    IsFeatureEnabled = {},
    SetEventIconTextures = {},
} }
stds.wow.read_globals.C_InstanceEncounter = { fields = {
    IsEncounterInProgress = {},
} }
stds.wow.read_globals.C_PartyInfo = { fields = {
    DoCountdown = {},
} }
stds.wow.read_globals.C_SpecializationInfo = { fields = {
    GetNumSpecializationsForClassID = {},
    GetSpecialization = {},
    GetSpecializationInfo = {},
} }
stds.wow.read_globals.C_Spell = { fields = {
    GetSpellInfo = {},
    GetSpellName = {},
    GetSpellTexture = {},
} }
stds.wow.read_globals.C_SpellBook = { fields = {
    GetNumSpellBookSkillLines = {},
    GetSpellBookItemInfo = {},
    GetSpellBookSkillLineInfo = {},
} }
stds.wow.read_globals.C_Texture = { fields = {
    GetAtlasInfo = {},
} }
stds.wow.read_globals.C_Timer = { fields = {
    After = {},
    NewTicker = {},
    NewTimer = {},
} }
stds.wow.read_globals.C_TTSSettings = { fields = {
    GetSpeechRate = {},
    GetSpeechVolume = {},
    GetVoiceOptionID = {},
} }
stds.wow.read_globals.C_VoiceChat = { fields = {
    SpeakText = {},
} }
stds.wow.read_globals.C_Weather = { fields = {
    GetCurrentWeather = {},
} }

-- Specs and the test world (spec/helpers/world.lua) run against the client the world builds: they read its globals,
-- and the world defines WoW's extensions of the string and table libraries (spec/helpers/lua_extensions.lua) and
-- makes string.format, string.join and string.concat take secrets (spec/helpers/secrets.lua).
stds.testworld = {
    read_globals = {
        "bit", "C_ChallengeMode", "C_EditMode", "C_EncounterTimeline", "C_Spell", "C_Timer", "C_Weather",
        "CreateFrame", "Enum", "GameFontNormal", "GetTime", "issecretvalue", "LibStub", "NORMAL_FONT_COLOR",
        "securecallfunction", "strsplit", "strtrim", "UIParent", "WOW_PROJECT_ID", "WOW_PROJECT_MAINLINE",
    },
    globals = {
        string = { fields = {
            split = { read_only = false }, join = { read_only = false }, trim = { read_only = false },
            concat = { read_only = false }, format = { read_only = false },
        } },
        table = { fields = { wipe = { read_only = false } } },
    },
}
files["spec/**/*.lua"] = { std = "lua51+busted+testworld" }

-- Addon-owned popup entries and DBM's documented option are mutable.
stds.wow.read_globals.StaticPopupDialogs = { other_fields = true, fields = {
    ABILITYTIMELINE_RELOAD = { read_only = false },
    ABILITYTIMELINE_CANNOT_RESOLVE = { read_only = false },
} }
stds.wow.read_globals.DBM = { other_fields = true, fields = {
    Options = { other_fields = true, fields = { HideDBMBars = { read_only = false } } },
} }
