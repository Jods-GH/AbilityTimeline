local appName, app = ...
---@class AbilityTimeline
local private = app

private.OptionDefaults = {
	profile = {
		debugMode = false,
		useTimelineModule = true,
		useAudioCountdowns = false,
		audioCountdownTime = 5,
		enableKeyRerollTimer = true,
		reminders = {},
		timerRules = {},
		editor = {
			defaultEncounterDuration = 300,
		},
		disableAllOnEncounterEnd = true,
		showRemindersInDisabledDisplays = true,
		enableDNDMessage = true,
		disableLoginMessage = false,
		disableVersionCheckMessage = false,
		disableReadyCheck = false,
		disableBreakTimer = false,
		disableAllBlizzTimers = false,
	}
}
