local addonName, private = ...
local LibEditMode = LibStub("LibEditMode")

LibEditMode:RegisterCallback('layout', function(layoutName)
    private.ACTIVE_EDITMODE_LAYOUT = layoutName
    private.modernize() --modernize any old settings to new ones
end)


LibEditMode:RegisterCallback('rename', function(oldLayoutName, newLayoutName)
	-- this will be called every time an Edit Mode layout is renamed
	if private.db.profile.timeline_frame and private.db.profile.timeline_frame[oldLayoutName] then
		local layout = CopyTable(private.db.profile.timeline_frame[oldLayoutName])
        private.db.profile.timeline_frame[newLayoutName] = layout
        private.db.profile.timeline_frame[oldLayoutName] = nil
	end

    if private.db.profile.text_highlight_frame and private.db.profile.text_highlight_frame[oldLayoutName] then
        local layout = CopyTable(private.db.profile.text_highlight_frame[oldLayoutName])
        private.db.profile.text_highlight_frame[newLayoutName] = layout
        private.db.profile.text_highlight_frame[oldLayoutName] = nil
    end

    if private.db.profile.bigicon_frame and private.db.profile.bigicon_frame[oldLayoutName] then
        local layout = CopyTable(private.db.profile.bigicon_frame[oldLayoutName])
        private.db.profile.bigicon_frame[newLayoutName] = layout
        private.db.profile.bigicon_frame[oldLayoutName] = nil
    end
end)

LibEditMode:RegisterCallback('create', function(layoutName)
	if not  private.db.profile.timeline_frame then
		private.db.profile.timeline_frame = {}
	end

    if not private.db.profile.text_highlight_frame then
        private.db.profile.text_highlight_frame = {}
    end
    if not private.db.profile.bigicon_frame then
        private.db.profile.bigicon_frame = {}
    end
end)

LibEditMode:RegisterCallback('delete', function(layoutName)

    if private.db.profile.timeline_frame and private.db.profile.timeline_frame[layoutName] then
        private.db.profile.timeline_frame[layoutName] = nil
    end

    if private.db.profile.text_highlight_frame and private.db.profile.text_highlight_frame[layoutName] then
        private.db.profile.text_highlight_frame[layoutName] = nil
    end

    if private.db.profile.bigicon_frame and private.db.profile.bigicon_frame[layoutName] then
        private.db.profile.bigicon_frame[layoutName] = nil
    end
end)