-- api_mocks.lua: the client's documented API, generated from Blizzard_APIDocumentationGenerated (spec/helpers/
-- api_docs.lua) for the world's client:
-- - Enum.* and Constants.* from the documented enumerations and constants
-- - every documented function (C_* namespaces and documented globals), which:
--   - checks the type of each argument given, as Lua's C API converts it (a number param takes a numeric string, a
--     string param takes a number); a missing argument is not checked, since the docs do not describe overloads
--   - raises an error when addon (tainted) code passes a secret to a function not documented as SecretArguments =
--     "AllowedWhenTainted" (warcraft.wiki.gg/wiki/Secret_Values)
--   - returns what world.api.set gave it, or values shaped by the documented returns (nothing if MayReturnNothing)
--   - makes returns secret as documented: always for SecretReturns, and for ConditionalSecret and every
--     SecretWhen*/SecretIn* condition while world.restrictions has that condition (or world.restricted is set);
--     NeverSecret fields and ReturnsNeverSecret functions stay plain
-- Functions the client has but no documentation file describes come from spec/helpers/legacy_api.lua.
local Secrets = require("spec.helpers.secrets")

local M = {}

local NUMBER_TYPES = {
    number = true, luaIndex = true, fileID = true, uiUnit = true, time_t = true, normalizedValue = true,
    size = true, SingleColorValue = true, BigInteger = true, BigUInteger = true, WOWMONEY = true,
}
local STRING_TYPES = { string = true, cstring = true, stringView = true, textureAtlas = true, textureKit = true }

local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, inner in pairs(value) do result[key] = copy(inner) end
    return result
end

---what kind of Lua value a documented type is: "number", "string", "boolean", "table", "function" or nil (unknown)
function M.Kind(docs, typeName)
    if NUMBER_TYPES[typeName] or docs.enums[typeName] then return "number" end
    if STRING_TYPES[typeName] then return "string" end
    if typeName == "bool" then return "boolean" end
    if typeName == "table" or typeName == "LuaValueVariant" then return typeName == "table" and "table" or nil end
    local documented = docs.types[typeName]
    if documented and documented.Type == "Structure" then return "table" end
    if documented and documented.Type == "CallbackType" or typeName == "luaFunction" then return "function" end
    return nil
end

local function accepts(kind, value)
    if kind == "number" then return tonumber(value) ~= nil end
    if kind == "string" then return type(value) == "string" or type(value) == "number" end
    if kind == "table" then return type(value) == "table" end
    if kind == "function" then return type(value) == "function" end
    return true
end

---a value shaped like a documented type
function M.DefaultValue(docs, field, depth)
    if field.Nilable then return nil end
    local default = field.Default
    if default ~= nil then
        local enum = docs.enums[field.Type]
        if enum and type(default) == "string" and enum[default] ~= nil then return enum[default] end
        return default
    end
    local kind = M.Kind(docs, field.Type)
    if kind == "number" then
        local enum = docs.enums[field.Type]
        if enum then
            local lowest
            for _, value in pairs(enum) do
                if lowest == nil or value < lowest then lowest = value end
            end
            return lowest or 0
        end
        return 0
    end
    if kind == "string" then return "" end
    if kind == "boolean" then return false end
    if kind == "function" then return function() end end
    if kind == "table" then
        local documented = docs.types[field.Type]
        local value = {}
        if documented and documented.Fields and (depth or 0) < 4 then
            for _, inner in ipairs(documented.Fields) do
                value[inner.Name] = M.DefaultValue(docs, inner, (depth or 0) + 1)
            end
        end
        return value
    end
    return nil
end

---whether a function's or event's returns are secret in the world right now
function M.IsSecretNow(world, doc)
    if doc.ReturnsNeverSecret then return false end
    if doc.SecretReturns or doc.SecretPayloads then return true end
    for key, value in pairs(doc) do
        if value == true and (key == "ConditionalSecret" or key:find("^SecretWhen") or key:find("^SecretIn")) then
            if world.restricted or world.restrictions[key] then return true end
        end
    end
    return false
end

---a value made secret as its documented field allows: a structure's fields one by one
function M.Secretize(docs, field, value, depth)
    if value == nil or field.NeverSecret or Secrets.IsSecret(value) then return value end
    local documented = docs.types[field.Type]
    if type(value) == "table" and documented and documented.Type == "Structure" then
        if (depth or 0) > 4 then return value end
        local byName = {}
        for _, inner in ipairs(documented.Fields or {}) do byName[inner.Name] = inner end
        for key, inner in pairs(value) do
            if byName[key] then value[key] = M.Secretize(docs, byName[key], inner, (depth or 0) + 1) end
        end
        return value
    end
    if type(value) == "table" then return value end
    return Secrets.Secret(value)
end

---raises the client's argument errors for the arguments given to a documented function. secretsOnly checks only the
---secret rule: widget method docs type arguments more narrowly than the client accepts (SimpleFrameAPI documents
---SetAttribute's value as cstring, while Blizzard's CallbackRegistry.lua stores tables with it).
function M.CheckArguments(world, doc, name, ...)
    return M.CheckArgumentsOf(world, doc, name, false, ...)
end

-- The helpers that exist to inspect secrets take them from addon code although FrameScriptDocumentation.lua marks them
-- AllowedWhenUntainted (warcraft.wiki.gg/wiki/API_issecretvalue: "Returns true if a supplied value is a secret value").
M.SECRET_PREDICATES = {
    issecretvalue = true, canaccessvalue = true, canaccessallvalues = true, hasanysecretvalues = true,
    issecrettable = true, canaccesstable = true, scrubsecretvalues = true, scrub = true,
}

function M.CheckArgumentsOf(world, doc, name, secretsOnly, ...)
    local docs = world.docs
    local acceptsSecrets = doc.SecretArguments == "AllowedWhenTainted" or M.SECRET_PREDICATES[name] == true
    for i = 1, select("#", ...) do
        local value = select(i, ...)
        if Secrets.IsSecret(value) then
            if not acceptsSecrets then
                error(("bad argument #%d to '%s' (secret value given to an API that does not take secrets from tainted callers)"):format(i, name), 4)
            end
        elseif value ~= nil and not secretsOnly then
            local argument = doc.Arguments and doc.Arguments[i]
            local kind = argument and M.Kind(docs, argument.Type)
            if kind and not accepts(kind, value) then
                error(("bad argument #%d to '%s' (%s expected, got %s)"):format(i, name, kind, type(value)), 4)
            end
        end
    end
end

---the documented returns, made secret where documented
function M.ShapeReturns(world, doc, ...)
    if not M.IsSecretNow(world, doc) then return ... end
    local count = math.max(select("#", ...), #(doc.Returns or {}))
    local values = { ... }
    for i = 1, count do
        local field = doc.Returns and doc.Returns[i] or { Type = "unknown" }
        values[i] = M.Secretize(world.docs, field, values[i])
    end
    return unpack(values, 1, count)
end

local function defaultImplementation(world, doc)
    return function()
        if doc.MayReturnNothing or not doc.Returns then return end
        local values = {}
        for i, field in ipairs(doc.Returns) do
            values[i] = M.DefaultValue(world.docs, field)
        end
        return unpack(values, 1, #doc.Returns)
    end
end

local function place(env, fullName, value)
    local namespace, name = fullName:match("^([^%.]+)%.(.+)$")
    if namespace then
        env[namespace] = env[namespace] or {}
        env[namespace][name] = value
    else
        env[fullName] = value
    end
end
M.Place = place

---installs Enum, Constants and every documented function of world.docs into env
function M.Install(world, env)
    local docs = world.docs
    env.Enum = copy(docs.enums)
    env.Constants = copy(docs.constants)
    for namespace in pairs(docs.namespaces) do env[namespace] = env[namespace] or {} end
    for fullName, doc in pairs(docs.functions) do
        -- The docs also describe functions the world already has (the string.* extensions of lua_extensions.lua):
        -- those keep their implementation and get the documented argument and secret rules around it.
        local namespace, name = fullName:match("^([^%.]+)%.(.+)$")
        local existing
        if namespace then
            existing = type(env[namespace]) == "table" and env[namespace][name]
        else
            existing = env[fullName]
        end
        world.implementations[fullName] = type(existing) == "function" and existing or defaultImplementation(world, doc)
        world.documented[fullName] = doc
        place(env, fullName, function(...)
            M.CheckArguments(world, doc, fullName, ...)
            return M.ShapeReturns(world, doc, world.implementations[fullName](...))
        end)
    end
end

return M
