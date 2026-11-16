-- secrets.lua: secret values as Retail gives them to addon (tainted) code. warcraft.wiki.gg/wiki/Secret_Values:
-- - "type(secret) returns its real type"
-- - tainted code may store secrets in variables and as table values, concatenate secret strings and numbers and pass
--   them to string.format, string.join and string.concat
-- - tainted code may not do arithmetic on, compare, index, call or take the length of a secret, nor store one as a
--   table key; "the result will be an immediate Lua error"
-- - a C function takes secrets from tainted callers only when its documentation says SecretArguments =
--   "AllowedWhenTainted" ("an API must be explicitly marked up as accepting secrets from tainted callers")
-- The wiki gives no error texts, so the messages below are the mock's own.
--
-- Plain Lua 5.1 cannot see every misuse: comparing a secret with a non-table (secret == nil) and # on a table do not
-- reach metamethods, a table is always truthy (a secret false tests true), and a plain table accepts any key. Specs
-- guard the tables the addon indexes with API values with SecretKeyGuard.
local M = {}

local secretMeta = {}

local function forbidden(operation)
    return function()
        error("attempt to " .. operation .. " a secret value (execution tainted by 'AbilityTimeline')", 2)
    end
end
for event, operation in pairs({
    __add = "perform arithmetic on", __sub = "perform arithmetic on", __mul = "perform arithmetic on",
    __div = "perform arithmetic on", __mod = "perform arithmetic on", __pow = "perform arithmetic on",
    __unm = "perform arithmetic on", __lt = "compare", __le = "compare", __eq = "compare",
    __index = "index", __newindex = "index", __call = "call", __len = "get the length of",
}) do
    secretMeta[event] = forbidden(operation)
end

local function isSecret(value)
    return type(value) == "table" and getmetatable(value) == secretMeta
end
M.IsSecret = isSecret

---the value a secret hides (for assertions only; addon code never sees this)
function M.Reveal(value)
    if isSecret(value) then return rawget(value, "value") end
    return value
end

local function concatenable(value)
    local valueType = type(M.Reveal(value))
    return valueType == "string" or valueType == "number"
end

secretMeta.__concat = function(a, b)
    if not concatenable(a) or not concatenable(b) then
        error("attempt to concatenate a secret value that is not a string or number", 2)
    end
    return M.Secret(tostring(M.Reveal(a)) .. tostring(M.Reveal(b)))
end
secretMeta.__tostring = function() return "<secret>" end

---a secret holding value
function M.Secret(value)
    return setmetatable({ value = value, type = type(value) }, secretMeta)
end

---makes t refuse secret keys, as the client's tables do for tainted code
function M.KeyGuard(t)
    return setmetatable(t, {
        __index = function(_, key)
            if isSecret(key) then error("attempt to use a secret value as a table key", 2) end
            return nil
        end,
        __newindex = function(tbl, key, value)
            if isSecret(key) then error("attempt to use a secret value as a table key", 2) end
            rawset(tbl, key, value)
        end,
    })
end

---puts in globals what the client changes for secrets: type gives the real type, and string.format, string.join and
---string.concat take secrets and return secrets. Returns a function that puts the originals back.
---@param env table the global environment
function M.Install(env)
    local originals = { type = env.type, format = string.format, join = string.join, concat = string.concat }
    local rawType = originals.type
    env.type = function(value)
        if rawType(value) == "table" and getmetatable(value) == secretMeta then
            return rawget(value, "type")
        end
        return rawType(value)
    end
    local function wrap(original)
        if not original then return nil end
        return function(...)
            local count = select("#", ...)
            local args, secret = { ... }, false
            for i = 1, count do
                if isSecret(args[i]) then
                    secret = true
                    args[i] = rawget(args[i], "value")
                end
            end
            if not secret then return original(...) end
            return M.Secret(original(unpack(args, 1, count)))
        end
    end
    string.format = wrap(originals.format)
    string.join = wrap(originals.join)
    string.concat = wrap(originals.concat)
    return function()
        env.type = originals.type
        string.format, string.join, string.concat = originals.format, originals.join, originals.concat
    end
end

return M
