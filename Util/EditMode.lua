local addonName, private = ...
local LibEditMode = LibStub("LibEditMode")

LibEditMode:RegisterCallback('layout', function(layoutName)
    private.ACTIVE_EDITMODE_LAYOUT = layoutName
end)


-- -- LibEditMode:RegisterCallback('rename', function(oldLayoutName, newLayoutName)
-- -- 	-- this will be called every time the Edit Mode layout is changed (which also happens at login),
-- -- 	-- use it to load the saved button position from savedvariables and position it
-- -- 	if not  private.db.profile.timeline_frame then
-- -- 		private.db.profile.timeline_frame = {}
-- -- 	end
-- --    local layout = private.db.profile.timeline_frame[oldLayoutName]
-- -- 	if not private.db.profile.timeline_frame[oldLayoutName] then
-- -- 		layout = CopyTable(defaultPosition)
-- -- 	end
-- --    private.db.profile.timeline_frame[newLayoutName] = layout
-- -- 	private.TIMELINE_FRAME:ClearAllPoints()
-- -- 	private.TIMELINE_FRAME:SetPoint(private.db.profile.timeline_frame[newLayoutName].point, private.db.profile.timeline_frame[newLayoutName].x, private.db.profile.timeline_frame[newLayoutName].y)
-- -- end)

-- LibEditMode:RegisterCallback('create', function(layoutName)
-- 	if not  private.db.profile.timeline_frame then
-- 		private.db.profile.timeline_frame = {}
-- 	end

--    private.db.profile.timeline_frame[layoutName] = CopyTable(defaultPosition)
-- end)

-- LibEditMode:RegisterCallback('delete', function(layoutName)
-- 	if not private.db.profile.timeline_frame then
-- 		return
-- 	end

--    private.db.profile.timeline_frame[layoutName] = {}
-- end)