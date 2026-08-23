-- Minimal Edit Mode replacement for Classic Era clients, where Blizzard's
-- Edit Mode (and therefore the real LibEditMode) is not available.
-- Registers itself under the "LibEditMode" name with just enough API surface
-- for this addon: layout callbacks and drag-to-move frame positioning.
-- The per-frame settings panels from retail are not available on classic;
-- configure the frames through the addon options instead.

local MAJOR = "LibEditMode"

if LibStub:GetLibrary(MAJOR, true) then
    return -- a LibEditMode implementation is already present
end

local lib = LibStub:NewLibrary(MAJOR, 1)
if not lib then
    return
end

lib.SettingType = {
    Checkbox = "Checkbox",
    Dropdown = "Dropdown",
    Slider = "Slider",
    Expander = "Expander",
    ColorPicker = "ColorPicker",
}

local registrations = lib.registrations or {}
lib.registrations = registrations

-- Callback listeners keyed by event name. Deliberately NOT CallbackHandler:
-- CBH passes the event name as the first dispatch argument, while consumers
-- of this library expect handler(layoutName, ...) exactly like the real
-- LibEditMode delivers it.
local listeners = lib.listeners or {}
lib.listeners = listeners

local activeLayout = nil -- stays unset until the first FireLayout
local pendingLayoutFire = false

function lib:GetActiveLayoutName()
    return activeLayout
end

---Fires the 'layout' callback for every registered listener. Used by the
---addon after initialization (the real library does this automatically at
---login) and whenever a new frame is registered so late-created frames get
---their saved position applied.
function lib:FireLayout(layoutName)
    activeLayout = layoutName or activeLayout
    for _, fn in ipairs(listeners.layout or {}) do
        fn(activeLayout)
    end
end

local function scheduleLayoutFire()
    if pendingLayoutFire then
        return
    end
    pendingLayoutFire = true
    C_Timer.After(0, function()
        pendingLayoutFire = false
        lib:FireLayout(activeLayout)
    end)
end

---Register a callback ('layout', 'rename', 'create', 'delete', 'exit').
---Handlers receive their payload without the event name prefix.
function lib:RegisterCallback(eventname, fn)
    if type(eventname) ~= "string" or type(fn) ~= "function" then
        return
    end
    listeners[eventname] = listeners[eventname] or {}
    local list = listeners[eventname]
    for _, existing in ipairs(list) do
        if existing == fn then
            return -- already registered (idempotent across reload-less re-init)
        end
    end
    list[#list + 1] = fn
end

function lib:UnregisterCallback(eventname, fn)
    local list = eventname and listeners[eventname]
    if not list then
        return
    end
    for index, existing in ipairs(list) do
        if existing == fn then
            table.remove(list, index)
            return
        end
    end
end

function lib:UnregisterAllCallbacks(eventname)
    if eventname then
        listeners[eventname] = nil
    else
        for key in pairs(listeners) do
            listeners[key] = nil
        end
    end
end

---Registers a frame for dragging. onPositionChanged is called with
---(frame, layoutName, point, x, y) whenever the user drops the frame somewhere.
function lib:AddFrame(frame, onPositionChanged, defaultPosition, label)
    if not frame or registrations[frame] then
        return
    end
    registrations[frame] = {
        handler = onPositionChanged,
        defaultPosition = defaultPosition,
        label = label,
    }

    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:HookScript("OnDragStart", function(dragFrame)
        dragFrame:StartMoving()
    end)
    frame:HookScript("OnDragStop", function(dragFrame)
        dragFrame:StopMovingOrSizing()
        local registration = registrations[dragFrame]
        if registration and registration.handler and dragFrame:GetNumPoints() > 0 then
            local point, _, _, x, y = dragFrame:GetPoint(1)
            registration.handler(dragFrame, activeLayout, point, x, y)
        end
    end)

    -- Apply saved/default positions to frames that were created after login.
    scheduleLayoutFire()
end

---Retail-only per-frame settings; intentionally a no-op on classic.
function lib:AddFrameSettings()
end

---Retail-only per-frame setting buttons; intentionally a no-op on classic.
function lib:AddFrameSettingsButtons()
end
