-- Load the actual addon chunk with its TOC namespace, without sharing test globals.
return function(path, private, globals)
    local environment = {
        ipairs = ipairs,
        tonumber = tonumber,
        type = type,
    }
    for key, value in pairs(globals or {}) do
        environment[key] = value
    end
    local chunk = assert(loadfile(path))
    setfenv(chunk, environment)
    chunk("AbilityTimeline", private)
    return private
end
