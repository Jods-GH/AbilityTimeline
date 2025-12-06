local addonName, private = ...

private.modernize = function()
    if private.db.profile.timeline_frame[private.ACTIVE_EDITMODE_LAYOUT].height then
        private.db.profile.timeline_frame[private.ACTIVE_EDITMODE_LAYOUT].travelSize = private.db.profile.timeline_frame[private.ACTIVE_EDITMODE_LAYOUT].height
        private.db.profile.timeline_frame[private.ACTIVE_EDITMODE_LAYOUT].height = nil
    end
    if not private.db.profile.timeline_frame[private.ACTIVE_EDITMODE_LAYOUT].otherSize then
        private.db.profile.timeline_frame[private.ACTIVE_EDITMODE_LAYOUT].otherSize = private.db.profile.timeline_frame[private.ACTIVE_EDITMODE_LAYOUT].width
    end
    if not private.db.profile.icon_settings then
        private.db.profile.icon_settings = {}
    end
    if not private.db.profile.icon_settings.size then
        private.db.profile.icon_settings.size = 44
    end
    if not private.db.profile.icon_settings.TextOffset then
        private.db.profile.icon_settings.TextOffset = { x = 10, y = 0 }
    end
    if not private.db.profile.text_settings then
        private.db.profile.text_settings = {}
    end
    if not private.db.profile.text_settings.fontSize then
        private.db.profile.text_settings.fontSize = 14
    end
    if not private.db.profile.text_settings.font then
        private.db.profile.text_settings.font = "Friz Quadrata TT"
    end
end