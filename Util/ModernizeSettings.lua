local addonName, private = ...
local LibEditMode = LibStub("LibEditMode")


private.modernize = function()
    if private.db.profile.timeline_frame[private.ACTIVE_EDITMODE_LAYOUT].height then
        private.db.profile.timeline_frame[private.ACTIVE_EDITMODE_LAYOUT].travelSize = private.db.profile.timeline_frame[private.ACTIVE_EDITMODE_LAYOUT].height
        private.db.profile.timeline_frame[private.ACTIVE_EDITMODE_LAYOUT].height = nil
    end
    if not private.db.profile.timeline_frame[private.ACTIVE_EDITMODE_LAYOUT].otherSize then
        private.db.profile.timeline_frame[private.ACTIVE_EDITMODE_LAYOUT].otherSize = private.db.profile.timeline_frame[private.ACTIVE_EDITMODE_LAYOUT].width
    end
end