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
		difficultyReminders = {},
		timerRules = {},
		editor = {
			difficulty = "mythic",
			defaultEncounterDuration = 300,
			replaySpeed = 1,
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
