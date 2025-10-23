local appName, private = ...
local AceLocale = LibStub ('AceLocale-3.0')
local L = AceLocale:NewLocale(appName, "zhTW")

if L then


-- LocalisationData[""] =
--@localization(locale="zhTW", format="lua_additive_table", handle-subnamespaces="concat")@


private.localisation = L
end