-- lua_extensions.lua: what the WoW client adds to Lua 5.1 in C, which no documentation file describes. Blizzard's own
-- Compat.lua (Blizzard_SharedXMLBase, loaded by spec/helpers/blizzard_lua.lua) then aliases them (wipe, strtrim,
-- strjoin, ...), as in the client. Each follows its warcraft.wiki.gg page.
local M = {}

---puts the extensions into env; world.errors collects what reaches the error handler
function M.Install(world, env)
    -- API_string.split: every byte of delimiter splits; pieces caps the count, the last piece keeps the rest
    function string.split(delimiter, str, pieces)
        local result, count, start = {}, 0, 1
        local set = "[" .. delimiter:gsub("[%]%[%^%-%%]", "%%%0") .. "]"
        while true do
            if pieces and count == pieces - 1 then break end
            local first = str:find(set, start)
            if not first then break end
            count = count + 1
            result[count] = str:sub(start, first - 1)
            start = first + 1
        end
        result[count + 1] = str:sub(start)
        return unpack(result, 1, count + 1)
    end
    env.strsplit = string.split

    -- API_string.join (string.join is the 3.1.0 alias): the strings joined by delimiter
    function string.join(delimiter, ...)
        return table.concat({ ... }, delimiter)
    end

    -- API_string.trim: chars defaults to " \t\r\n"
    function string.trim(str, chars)
        local set = "[" .. (chars or " \t\r\n"):gsub("[%]%[%^%-%%]", "%%%0") .. "]"
        return (str:gsub("^" .. set .. "+", ""):gsub(set .. "+$", ""))
    end

    -- API_table.wipe: empties the table, keeping its identity and metatable, and returns it
    function table.wipe(t)
        for key in pairs(t) do t[key] = nil end
        return t
    end

    -- The client's bit library (BitLib): 32-bit operations on numbers.
    local function toUnsigned(value)
        value = math.floor(value) % 4294967296
        return value
    end
    local function toSigned(value)
        value = toUnsigned(value)
        if value >= 2147483648 then value = value - 4294967296 end
        return value
    end
    local function bitwise(a, b, operation)
        a, b = toUnsigned(a), toUnsigned(b)
        local result, bitValue = 0, 1
        for _ = 1, 32 do
            local x, y = a % 2, b % 2
            if operation(x, y) then result = result + bitValue end
            a, b, bitValue = (a - x) / 2, (b - y) / 2, bitValue * 2
        end
        return toSigned(result)
    end
    local function fold(operation)
        return function(a, ...)
            local result = toSigned(a)
            for i = 1, select("#", ...) do result = bitwise(result, (select(i, ...)), operation) end
            return result
        end
    end
    env.bit = {
        band = fold(function(x, y) return x == 1 and y == 1 end),
        bor = fold(function(x, y) return x == 1 or y == 1 end),
        bxor = fold(function(x, y) return x ~= y end),
        bnot = function(a) return toSigned(4294967295 - toUnsigned(a)) end,
        lshift = function(a, n) return toSigned(toUnsigned(a) * 2 ^ n) end,
        rshift = function(a, n) return toSigned(math.floor(toUnsigned(a) / 2 ^ n)) end,
        arshift = function(a, n) return math.floor(toSigned(a) / 2 ^ n) end,
        mod = function(a, b) return toSigned(math.fmod(a, b)) end,
    }

    -- API_xpcall: the client's xpcall(f, handler, ...) passes its extra arguments to f (Lua 5.1's drops them);
    -- AceAddon-3.0's safecall depends on it
    local luaXpcall = xpcall
    env.xpcall = function(f, handler, ...)
        local args, count = { ... }, select("#", ...)
        return luaXpcall(function() return f(unpack(args, 1, count)) end, handler)
    end

    -- API_geterrorhandler: errors reported to the handler go to world.errors.
    local handler = function(message)
        world.errors[#world.errors + 1] = tostring(message)
    end
    env.geterrorhandler = function() return handler end
    env.seterrorhandler = function(newHandler) handler = newHandler end

    -- API_securecall: an error goes to the error handler and the call returns nothing. The traceback of each error
    -- is kept in world.errorTraces for the spec that reports it.
    world.errorTraces = {}
    local function securecall(func, ...)
        if type(func) == "string" then func = env[func] end
        local args, count = { ... }, select("#", ...)
        local results = { xpcall(function() return func(unpack(args, 1, count)) end, function(message)
            world.errorTraces[#world.errorTraces + 1] = debug.traceback(tostring(message), 2)
            return message
        end) }
        if not results[1] then
            handler(results[2])
            return
        end
        return unpack(results, 2, table.maxn(results))
    end
    env.securecall = securecall
    env.securecallfunction = securecall

    -- API_secureexecuterange: calls func(key, value, ...) for each pair of tbl; an error goes to the error handler
    env.secureexecuterange = function(tbl, func, ...)
        for key, value in pairs(tbl) do securecall(func, key, value, ...) end
    end

    -- API_hooksecurefunc: ([table,] name, hook); the hook runs after the original with the same arguments and its
    -- returns are dropped.
    env.hooksecurefunc = function(tbl, name, hook)
        if type(tbl) == "string" then
            tbl, name, hook = env, tbl, name
        end
        local original = tbl[name]
        assert(type(original) == "function", "hooksecurefunc(): " .. tostring(name) .. " is not a function")
        tbl[name] = function(...)
            local results = { original(...) }
            hook(...)
            return unpack(results, 1, table.maxn(results))
        end
    end

    -- (the documented FrameScript functions get their behaviour in M.InstallDocumented)

    -- API_GetCurrentEnvironment: the global environment of the calling function
    env.GetCurrentEnvironment = function() return getfenv(2) end

    -- API_debugstack and API_debugprofilestop
    env.debugstack = function(start) return debug.traceback("", (start or 1) + 1) end
    env.debugprofilestop = function() return world.clock.now * 1000 end
end

---behaviour of the documented FrameScript functions (FrameScriptDocumentation.lua), once api_mocks.lua generated them
function M.InstallDocumented(world, env)
    local secrets = world.secrets
    local function set(name, implementation)
        if world.api.has(name) then world.api.set(name, implementation) end
    end
    -- API_Mixin: copies every key of each mixin into object and returns object
    local function mixin(object, ...)
        for i = 1, select("#", ...) do
            for key, value in pairs((select(i, ...))) do object[key] = value end
        end
        return object
    end
    set("Mixin", mixin)
    -- API_CreateFromMixins: a new table with the mixins' keys
    set("CreateFromMixins", function(...) return mixin({}, ...) end)
    -- CreateSecureDelegate(func): a function that runs func securely and returns its results (FrameScript); this
    -- world has no taint, so it calls func
    set("CreateSecureDelegate", function(func) return function(...) return func(...) end end)
    -- API_securecallmethod: securecall of object[method](object, ...)
    set("securecallmethod", function(object, method, ...) return env.securecallfunction(object[method], object, ...) end)
    -- warcraft.wiki.gg/wiki/Secret_Values: the predicates tainted code may use
    set("canaccessvalue", function(value) return not secrets.IsSecret(value) end)
    set("canaccesssecrets", function() return false end)
    set("canaccesstable", function() return true end)
    set("issecrettable", function() return false end)
    set("canaccessallvalues", function(...)
        for i = 1, select("#", ...) do
            if secrets.IsSecret((select(i, ...))) then return false end
        end
        return true
    end)
    set("hasanysecretvalues", function(...)
        for i = 1, select("#", ...) do
            if secrets.IsSecret((select(i, ...))) then return true end
        end
        return false
    end)
    -- API_scrubsecretvalues: the values, secrets replaced by nil
    local function scrub(...)
        local values = { ... }
        local count = select("#", ...)
        for i = 1, count do
            if secrets.IsSecret(values[i]) then values[i] = nil end
        end
        return unpack(values, 1, count)
    end
    set("scrubsecretvalues", scrub)
    set("scrub", scrub)
    set("debugprofilestop", function() return world.clock.now * 1000 end)
end

return M
