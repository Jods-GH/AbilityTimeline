local appName, app = ...
local private = app

-- Capture before AceDB strips defaults and removes empty character sections.
local windows = {}
private.RegisterWindowState = function(key, capture, restore)
    windows[#windows + 1] = { key = key, capture = capture, restore = restore }
end

private.saveOpenWindows = function()
    local saved = {}
    for _, window in ipairs(windows) do
        saved[window.key] = window.capture()
    end
    private.db.char.openWindows = saved
    private.db.char.timingsEditorEncounter = nil
end

private.restoreOpenWindows = function()
    local saved = private.db.char.openWindows or {}
    for _, key in ipairs({ "settings", "editor", "picker", "import", "export", "copyLink" }) do
        for _, window in ipairs(windows) do
            if window.key == key and saved[key] then
                window.restore(saved[key])
            end
        end
    end
end
