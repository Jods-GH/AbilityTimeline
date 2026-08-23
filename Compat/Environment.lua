-- Compatibility environment for WoW Classic Era clients.
-- Polyfills retail-only globals so the shared addon code can run unmodified.
-- This file must be listed before everything else in AbilityTimeline_Vanilla.toc.

local appName, app = ...

local _, _, _, interfaceVersion = GetBuildInfo()
app.IS_CLASSIC = interfaceVersion < 100000

---Older clients lack the retail portrait frame template; probe for it once
---so templates can pick a safe fallback.
local probeFrame = CreateFrame("Frame", nil, UIParent)
probeFrame:Hide()
local portraitTemplateWorks = pcall(CreateFrame, "Frame", nil, probeFrame, "PortraitFrameTemplateNoCloseButton")
app.PORTRAIT_FRAME_TEMPLATE = portraitTemplateWorks and "PortraitFrameTemplateNoCloseButton" or
    "BasicFrameTemplateWithClose"

---Sets a frame title across template variants.
function app.ApplyFrameTitle(frame, title)
    if frame.SetTitle then
        frame:SetTitle(title)
    elseif frame.TitleText then
        frame.TitleText:SetText(title)
    end
end

---Title bar offset used when anchoring content frames; falls back to the
---retail title container height when the region is missing.
function app.GetTitleBarHeight(frame)
    if frame.TitleContainer then
        return frame.TitleContainer:GetHeight()
    end
    return 30
end

if not app.IS_CLASSIC then
    return -- retail client: everything below already exists natively
end

-- Secret value validation does not exist on classic; nothing is a secret there.
issecretvalue = issecretvalue or function() return false end

-- Texture file IDs were introduced later; classic uses raw paths everywhere.
GetFileIDFromPath = GetFileIDFromPath or function(filePath) return filePath end

if not C_AddOns then
    C_AddOns = {
        IsAddOnLoaded = function(...) return IsAddOnLoaded(...) end,
        LoadAddOn = function(...) return LoadAddOn(...) end,
        GetAddOnMetadata = function(...) return GetAddOnMetadata(...) end,
    }
end

if not C_Spell then
    local oldGetSpellInfo = _G.GetSpellInfo
    C_Spell = {
        GetSpellInfo = function(spellIdentifier)
            local name, _, iconFileID = oldGetSpellInfo(spellIdentifier)
            if not name then
                return nil
            end
            return { name = name, iconID = iconFileID }
        end,
        GetSpellTexture = function(spellIdentifier)
            return select(3, oldGetSpellInfo(spellIdentifier))
        end,
    }
end

if not C_ChatInfo then
    C_ChatInfo = {
        SendChatMessage = function(message, chatType, language, channel)
            SendChatMessage(message, chatType, language, channel)
        end,
        InChatMessagingLockdown = function() return false end,
    }
end

UnitNameUnmodified = UnitNameUnmodified or UnitName

-- Font alias used by templates that does not exist on classic clients.
SystemFont_Shadow_Med3 = SystemFont_Shadow_Med3 or GameFontHighlight

Enum = Enum or {}
Enum.EncounterTimelineEventState = Enum.EncounterTimelineEventState or {
    Active = 0,
    Paused = 1,
    Finished = 2,
    Canceled = 3,
}
Enum.EncounterTimelineEventSource = Enum.EncounterTimelineEventSource or {
    Encounter = 1,
    Script = 2,
    EditMode = 3,
}
Enum.EncounterTimelineTrackType = Enum.EncounterTimelineTrackType or {
    Standard = 0,
    Hidden = 1,
}
-- Referenced by AbilityTimeline.lua track filtering; the shim only ever
-- reports the standard track, so Indeterminate just needs a non-matching value.
Enum.EncounterTimelineTrack = Enum.EncounterTimelineTrack or {
    Standard = 0,
    Indeterminate = -1,
}
Enum.Track = Enum.Track or {}
Enum.Track.Indeterminate = Enum.Track.Indeterminate or -1
Enum.EncounterEventsTooltipAnchor = Enum.EncounterEventsTooltipAnchor or {
    Hidden = 0,
    Default = 1,
    Cursor = 2,
}
Enum.EncounterEventColorTrigger = Enum.EncounterEventColorTrigger or {
    TimelineEvent = 0,
}

if not Enum.EncounterTimelineEvent then
    -- Icon mask constants are opaque on retail; hand out unique power-of-two
    -- values so bitmask checks behave sensibly for locally created events.
    local nextIconBit = 1
    Enum.EncounterTimelineEvent = setmetatable({}, {
        __index = function(self, key)
            local bitValue = nextIconBit
            nextIconBit = nextIconBit * 2
            rawset(self, key, bitValue)
            return bitValue
        end,
    })
end
