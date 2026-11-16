-- clock.lua: the world's time. Nothing moves until a spec advances it, then due timers run and every shown frame's
-- OnUpdate runs once per step, as the client runs them once per frame.
-- - API_GetTime: seconds of uptime; API_time / API_date: Lua's os.time/os.date at the world's wall clock
-- - API_C_Timer.After, C_Timer.NewTimer, C_Timer.NewTicker (UITimerDocumentation.lua): a timer handle with Cancel and
--   IsCancelled; a ticker repeats until cancelled or its iterations run out
-- - API_GetGameTime: the realm's hours and minutes, from world.game.gameTime
local M = {}

function M.New(world)
    local clock = { now = 1000, epoch = 1700000000, timers = {}, sequence = 0 }

    local function schedule(seconds, callback, iterations)
        clock.sequence = clock.sequence + 1
        local handle = { due = clock.now + math.max(seconds, 0), interval = seconds, callback = callback,
            remaining = iterations, order = clock.sequence, cancelled = false }
        function handle:Cancel() self.cancelled = true end
        function handle:IsCancelled() return self.cancelled end
        clock.timers[#clock.timers + 1] = handle
        return handle
    end
    clock.Schedule = schedule

    ---runs the timers due by now, oldest first; a timer scheduled while running waits for the next pass
    local function runDue()
        local due = {}
        for _, handle in ipairs(clock.timers) do
            if not handle.cancelled and handle.due <= clock.now + 1e-9 then due[#due + 1] = handle end
        end
        table.sort(due, function(a, b)
            if a.due ~= b.due then return a.due < b.due end
            return a.order < b.order
        end)
        for _, handle in ipairs(due) do
            if not handle.cancelled then
                if handle.remaining then
                    handle.remaining = handle.remaining - 1
                    if handle.remaining <= 0 then handle.cancelled = true end
                elseif not handle.repeating then
                    handle.cancelled = true
                end
                handle.due = handle.due + math.max(handle.interval, 0.001)
                world.call(handle.callback, handle)
            end
        end
        local kept = {}
        for _, handle in ipairs(clock.timers) do
            if not handle.cancelled then kept[#kept + 1] = handle end
        end
        clock.timers = kept
    end

    ---advances time by seconds in steps of step (default 1/60), running timers and OnUpdate scripts each step
    function clock.Advance(seconds, step)
        step = step or 1 / 60
        local remaining = seconds
        repeat
            local delta = math.min(step, remaining)
            clock.now = clock.now + delta
            remaining = remaining - delta
            runDue()
            world.widgets.RunOnUpdate(delta)
        until remaining <= 1e-9
    end

    ---runs one frame without moving time: due timers and OnUpdate(0)
    function clock.Frame()
        runDue()
        world.widgets.RunOnUpdate(0)
    end

    function clock.Install()
        world.api.set("GetTime", function() return clock.now end)
        world.api.set("time", function(t)
            if t then return os.time(t) end
            return math.floor(clock.epoch + clock.now)
        end)
        world.api.set("date", function(format, t)
            return os.date(format, t or math.floor(clock.epoch + clock.now))
        end)
        world.api.set("GetGameTime", function()
            local gameTime = world.game.gameTime
            return gameTime.hour, gameTime.minute
        end)
        world.api.set("C_Timer.After", function(seconds, callback)
            schedule(seconds, callback, 1)
        end)
        world.api.set("C_Timer.NewTimer", function(seconds, callback)
            return schedule(seconds, callback, 1)
        end)
        world.api.set("C_Timer.NewTicker", function(seconds, callback, iterations)
            local handle = schedule(seconds, callback, iterations)
            handle.repeating = true
            return handle
        end)
    end

    return clock
end

return M
