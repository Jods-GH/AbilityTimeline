local addonName, private = ...

private.modernize = function()
    if not private.db.profile.timeline_frame then
        private.db.profile.timeline_frame = {}
    end
    if not private.db.profile.timeline_frame[private.ACTIVE_EDITMODE_LAYOUT] then
        private.db.profile.timeline_frame[private.ACTIVE_EDITMODE_LAYOUT] = {}
    end
    if private.db.profile.timeline_frame[private.ACTIVE_EDITMODE_LAYOUT].height then
        private.db.profile.timeline_frame[private.ACTIVE_EDITMODE_LAYOUT].travelSize = private.db.profile.timeline_frame
        [private.ACTIVE_EDITMODE_LAYOUT].height
        private.db.profile.timeline_frame[private.ACTIVE_EDITMODE_LAYOUT].height = nil
    end
    if not private.db.profile.timeline_frame[private.ACTIVE_EDITMODE_LAYOUT].otherSize then
        private.db.profile.timeline_frame[private.ACTIVE_EDITMODE_LAYOUT].otherSize = private.db.profile.timeline_frame
        [private.ACTIVE_EDITMODE_LAYOUT].width
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

    if not private.db.profile.text_settings.defaultColor then
        private.db.profile.text_settings.defaultColor = { r = 1, g = 1, b = 1 }
    end

    if not private.db.profile.cooldown_settings then
        private.db.profile.cooldown_settings = {}
    end

    if not private.db.profile.cooldown_settings.fontSize then
        private.db.profile.cooldown_settings.fontSize = 24
    end
    if not private.db.profile.cooldown_settings.font then
        private.db.profile.cooldown_settings.font = "Friz Quadrata TT"
    end

    if not private.db.profile.cooldown_settings.cooldown_color then
        private.db.profile.cooldown_settings.cooldown_color = {
            r = 1,
            g = 1,
            b = 1,
        }
    end

    if not private.db.profile.cooldown_settings.color_highlight then
        private.db.profile.cooldown_settings.color_highlight = {}
    end

    if not private.db.profile.cooldown_settings.color_highlight.enabled then
        private.db.profile.cooldown_settings.color_highlight.enabled = true
    end

    if not private.db.profile.cooldown_settings.color_highlight.highlights then
        private.db.profile.cooldown_settings.color_highlight.highlights = {
            {
                time = 3,
                color = { r = 1, g = 0, b = 0 },
            },
            {
                time = 5,
                color = { r = 1, g = 1, b = 0 },
            },
        }
    end
end
