-- encoding_util.lua: C_EncodingUtil (EncodingUtilDocumentation.lua) implemented to the standards it names, so import
-- and export strings round-trip for real:
-- - EncodeBase64/DecodeBase64: RFC 4648, Enum.Base64Variant Standard and StandardUrlSafe
-- - CompressString/DecompressString: RFC 1951 Deflate (written as stored blocks, read in full: stored, fixed and
--   dynamic Huffman blocks), wrapped as RFC 1950 Zlib or RFC 1952 Gzip by Enum.CompressionMethod
-- - SerializeCBOR/DeserializeCBOR: RFC 8949 for Lua values (a table with keys 1..n is an array, else a map)
-- - SerializeJSON/DeserializeJSON: RFC 8259
-- - EncodeHex/DecodeHex
local M = {}

local byte, char, floor = string.byte, string.char, math.floor

-- Base64 -------------------------------------------------------------------------------------------------------------

local ALPHABETS = {
    [0] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/",
    [1] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_",
}

function M.EncodeBase64(source, variant)
    local alphabet = ALPHABETS[variant or 0]
    local out = {}
    for i = 1, #source, 3 do
        local a, b, c = byte(source, i, i + 2)
        local n = a * 65536 + (b or 0) * 256 + (c or 0)
        local chars = {}
        for j = 3, 0, -1 do
            local index = floor(n / 64 ^ j) % 64
            chars[#chars + 1] = alphabet:sub(index + 1, index + 1)
        end
        if not b then chars[3], chars[4] = "=", "=" elseif not c then chars[4] = "=" end
        out[#out + 1] = table.concat(chars)
    end
    return table.concat(out)
end

function M.DecodeBase64(source, variant)
    local alphabet = ALPHABETS[variant or 0]
    local lookup = {}
    for i = 1, 64 do lookup[alphabet:sub(i, i)] = i - 1 end
    source = source:gsub("[%s=]", "")
    local out = {}
    for i = 1, #source, 4 do
        local n, count = 0, 0
        for j = i, math.min(i + 3, #source) do
            local value = lookup[source:sub(j, j)]
            if not value then return nil end
            n = n * 64 + value
            count = count + 1
        end
        n = n * 64 ^ (4 - count)
        local bytes = { floor(n / 65536) % 256, floor(n / 256) % 256, n % 256 }
        for j = 1, count - 1 do out[#out + 1] = char(bytes[j]) end
    end
    return table.concat(out)
end

function M.EncodeHex(source)
    return (source:gsub(".", function(c) return ("%02x"):format(byte(c)) end))
end

function M.DecodeHex(source)
    if #source % 2 == 1 or source:find("[^%x]") then return nil end
    return (source:gsub("%x%x", function(h) return char(tonumber(h, 16)) end))
end

-- Checksums ----------------------------------------------------------------------------------------------------------

local function adler32(data)
    local a, b = 1, 0
    for i = 1, #data do
        a = (a + byte(data, i)) % 65521
        b = (b + a) % 65521
    end
    return b * 65536 + a
end
M.Adler32 = adler32

local crcTable
local function crc32(data)
    if not crcTable then
        crcTable = {}
        for i = 0, 255 do
            local c = i
            for _ = 1, 8 do
                if c % 2 == 1 then c = bit.bxor(floor(c / 2), 0xEDB88320) % 4294967296 else c = floor(c / 2) end
            end
            crcTable[i] = c
        end
    end
    local crc = 4294967295
    for i = 1, #data do
        crc = bit.bxor(floor(crc / 256), crcTable[bit.bxor(crc, byte(data, i)) % 256]) % 4294967296
    end
    return bit.bxor(crc, 4294967295) % 4294967296
end
M.Crc32 = crc32

local function bigEndian(n, count)
    local bytes = {}
    for i = count, 1, -1 do bytes[i] = char(n % 256) n = floor(n / 256) end
    return table.concat(bytes)
end
local function littleEndian(n, count)
    local bytes = {}
    for i = 1, count do bytes[i] = char(n % 256) n = floor(n / 256) end
    return table.concat(bytes)
end

-- Deflate ------------------------------------------------------------------------------------------------------------

---raw RFC 1951 deflate of data, as stored blocks
function M.Deflate(data)
    local out = {}
    local position = 1
    repeat
        local chunk = data:sub(position, position + 65534)
        position = position + #chunk
        local final = position > #data and 1 or 0
        out[#out + 1] = char(final) .. littleEndian(#chunk, 2) .. littleEndian(65535 - #chunk, 2) .. chunk
    until position > #data
    return table.concat(out)
end

local LENGTH_BASE = { 3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227, 258 }
local LENGTH_EXTRA = { 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0 }
local DIST_BASE = { 1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385, 513, 769, 1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289, 16385, 24577 }
local DIST_EXTRA = { 0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13 }
local CODE_ORDER = { 17, 18, 19, 1, 9, 8, 10, 7, 11, 6, 12, 5, 13, 4, 14, 3, 15, 2, 16 }

---a Huffman decoding table from code lengths (RFC 1951 3.2.2): counts per length and symbols in code order
local function huffman(lengths, count)
    local counts, offsets, symbols = {}, {}, {}
    for i = 0, 15 do counts[i] = 0 end
    for symbol = 0, count - 1 do counts[lengths[symbol] or 0] = counts[lengths[symbol] or 0] + 1 end
    counts[0] = 0
    offsets[1] = 0
    for i = 1, 14 do offsets[i + 1] = offsets[i] + counts[i] end
    for symbol = 0, count - 1 do
        local length = lengths[symbol] or 0
        if length ~= 0 then
            symbols[offsets[length]] = symbol
            offsets[length] = offsets[length] + 1
        end
    end
    return { counts = counts, symbols = symbols }
end

---raw RFC 1951 inflate; nil on malformed data
function M.Inflate(data)
    local position, bitBuffer, bitCount = 1, 0, 0
    local out = {}
    local function bits(n)
        while bitCount < n do
            local b = byte(data, position)
            if not b then error("inflate: out of input") end
            position = position + 1
            bitBuffer = bitBuffer + b * 2 ^ bitCount
            bitCount = bitCount + 8
        end
        local value = bitBuffer % 2 ^ n
        bitBuffer = floor(bitBuffer / 2 ^ n)
        bitCount = bitCount - n
        return value
    end
    local function decode(tableInfo)
        local code, first, index = 0, 0, 0
        for length = 1, 15 do
            code = code + bits(1)
            local count = tableInfo.counts[length]
            if code - count < first then return tableInfo.symbols[index + (code - first)] end
            index = index + count
            first = (first + count) * 2
            code = code * 2
        end
        error("inflate: bad code")
    end
    local fixedLiteral, fixedDistance
    repeat
        local final = bits(1)
        local blockType = bits(2)
        if blockType == 0 then
            bitBuffer, bitCount = 0, 0
            local length = byte(data, position) + byte(data, position + 1) * 256
            position = position + 4
            for i = 0, length - 1 do out[#out + 1] = data:sub(position + i, position + i) end
            position = position + length
        elseif blockType == 1 or blockType == 2 then
            local literal, distance
            if blockType == 1 then
                if not fixedLiteral then
                    local lengths = {}
                    for i = 0, 143 do lengths[i] = 8 end
                    for i = 144, 255 do lengths[i] = 9 end
                    for i = 256, 279 do lengths[i] = 7 end
                    for i = 280, 287 do lengths[i] = 8 end
                    fixedLiteral = huffman(lengths, 288)
                    local distances = {}
                    for i = 0, 29 do distances[i] = 5 end
                    fixedDistance = huffman(distances, 30)
                end
                literal, distance = fixedLiteral, fixedDistance
            else
                local literalCount, distanceCount, codeCount = bits(5) + 257, bits(5) + 1, bits(4) + 4
                local codeLengths = {}
                for i = 1, codeCount do codeLengths[CODE_ORDER[i] - 1] = bits(3) end
                local codeTable = huffman(codeLengths, 19)
                local lengths, index = {}, 0
                while index < literalCount + distanceCount do
                    local symbol = decode(codeTable)
                    if symbol < 16 then
                        lengths[index] = symbol
                        index = index + 1
                    else
                        local repeatValue, times = 0
                        if symbol == 16 then repeatValue, times = lengths[index - 1], 3 + bits(2)
                        elseif symbol == 17 then times = 3 + bits(3)
                        else times = 11 + bits(7) end
                        for _ = 1, times do lengths[index] = repeatValue index = index + 1 end
                    end
                end
                local literalLengths, distanceLengths = {}, {}
                for i = 0, literalCount - 1 do literalLengths[i] = lengths[i] end
                for i = 0, distanceCount - 1 do distanceLengths[i] = lengths[literalCount + i] end
                literal, distance = huffman(literalLengths, literalCount), huffman(distanceLengths, distanceCount)
            end
            while true do
                local symbol = decode(literal)
                if symbol < 256 then
                    out[#out + 1] = char(symbol)
                elseif symbol == 256 then
                    break
                else
                    symbol = symbol - 256
                    local length = LENGTH_BASE[symbol] + bits(LENGTH_EXTRA[symbol])
                    local distanceSymbol = decode(distance) + 1
                    local back = DIST_BASE[distanceSymbol] + bits(DIST_EXTRA[distanceSymbol])
                    local start = #out - back + 1
                    if start < 1 then error("inflate: distance too far") end
                    for i = 0, length - 1 do out[#out + 1] = out[start + i] end
                end
            end
        else
            error("inflate: bad block type")
        end
    until final == 1
    return table.concat(out), position
end

function M.CompressString(source, method)
    method = method or 0
    local deflated = M.Deflate(source)
    if method == 1 then return "\120\1" .. deflated .. bigEndian(adler32(source), 4) end
    if method == 2 then
        return "\31\139\8\0\0\0\0\0\0\255" .. deflated .. littleEndian(crc32(source), 4) .. littleEndian(#source % 4294967296, 4)
    end
    return deflated
end

function M.DecompressString(source, method)
    method = method or 0
    local ok, result = pcall(function()
        if method == 1 then
            local output = M.Inflate(source:sub(3))
            return output
        elseif method == 2 then
            local flags = byte(source, 4)
            local position = 11
            if flags % 8 >= 4 then position = position + 2 + byte(source, position) + byte(source, position + 1) * 256 end
            if flags % 16 >= 8 then position = source:find("\0", position, true) + 1 end
            if flags % 32 >= 16 then position = source:find("\0", position, true) + 1 end
            if flags % 4 >= 2 then position = position + 2 end
            return (M.Inflate(source:sub(position)))
        end
        return (M.Inflate(source))
    end)
    if ok then return result end
    return nil
end

-- CBOR ---------------------------------------------------------------------------------------------------------------

local function packDouble(value)
    if value ~= value then return "\127\248\0\0\0\0\0\0" end
    local sign = 0
    if value < 0 or (value == 0 and 1 / value < 0) then sign, value = 128, -value end
    if value == math.huge then return char(sign + 127, 240, 0, 0, 0, 0, 0, 0) end
    if value == 0 then return char(sign, 0, 0, 0, 0, 0, 0, 0) end
    local mantissa, exponent = math.frexp(value)
    exponent = exponent + 1022
    if exponent <= 0 then
        mantissa = mantissa * 2 ^ (52 + exponent)
        exponent = 0
    else
        mantissa = (mantissa * 2 - 1) * 2 ^ 52
    end
    local bytes = {}
    for i = 8, 3, -1 do bytes[i] = mantissa % 256 mantissa = floor(mantissa / 256) end
    bytes[2] = (exponent % 16) * 16 + mantissa % 16
    bytes[1] = sign + floor(exponent / 16)
    return char(unpack(bytes))
end

local function unpackFloat(data, position, size)
    local b = { byte(data, position, position + size - 1) }
    local sign = b[1] >= 128 and -1 or 1
    local exponentBits, mantissaBits = size == 2 and 5 or size == 4 and 8 or 11, size == 2 and 10 or size == 4 and 23 or 52
    local bias = 2 ^ (exponentBits - 1) - 1
    -- the exponent sits in the first two bytes; the mantissa is summed byte by byte so no bit is lost
    local high = (b[1] % 128) * 256 + b[2]
    local exponent = floor(high / 2 ^ (16 - 1 - exponentBits))
    local mantissa = high % 2 ^ (16 - 1 - exponentBits)
    for i = 3, size do mantissa = mantissa * 256 + b[i] end
    if exponent == 2 ^ exponentBits - 1 then
        if mantissa == 0 then return sign * math.huge end
        return 0 / 0
    end
    if exponent == 0 then return sign * mantissa * 2 ^ (1 - bias - mantissaBits) end
    return sign * (1 + mantissa / 2 ^ mantissaBits) * 2 ^ (exponent - bias)
end

local function head(major, n)
    local prefix = major * 32
    if n < 24 then return char(prefix + n) end
    if n < 256 then return char(prefix + 24, n) end
    if n < 65536 then return char(prefix + 25) .. bigEndian(n, 2) end
    if n < 4294967296 then return char(prefix + 26) .. bigEndian(n, 4) end
    return char(prefix + 27) .. bigEndian(n, 8)
end

local function isSequence(t)
    local count = 0
    for _ in pairs(t) do count = count + 1 end
    for i = 1, count do if t[i] == nil then return false end end
    return true, count
end

function M.SerializeCBOR(value)
    local valueType = type(value)
    if value == nil then return "\246" end
    if valueType == "boolean" then return value and "\245" or "\244" end
    if valueType == "number" then
        if value == floor(value) and value >= -2 ^ 53 and value <= 2 ^ 53 then
            if value >= 0 then return head(0, value) end
            return head(1, -1 - value)
        end
        return "\251" .. packDouble(value)
    end
    if valueType == "string" then return head(3, #value) .. value end
    if valueType == "table" then
        local sequence, count = isSequence(value)
        if sequence and count > 0 then
            local parts = { head(4, count) }
            for i = 1, count do parts[#parts + 1] = M.SerializeCBOR(value[i]) end
            return table.concat(parts)
        end
        local keys = {}
        for key in pairs(value) do keys[#keys + 1] = key end
        table.sort(keys, function(a, b)
            if type(a) == type(b) then return a < b end
            return type(a) < type(b)
        end)
        local parts = { head(5, #keys) }
        for _, key in ipairs(keys) do
            parts[#parts + 1] = M.SerializeCBOR(key)
            parts[#parts + 1] = M.SerializeCBOR(value[key])
        end
        return table.concat(parts)
    end
    error("SerializeCBOR: unsupported value of type " .. valueType)
end

function M.DeserializeCBOR(source)
    local position = 1
    local function read()
        local initial = byte(source, position)
        if not initial then error("cbor: out of input") end
        position = position + 1
        local major, info = floor(initial / 32), initial % 32
        local function argument()
            if info < 24 then return info end
            local size = info == 24 and 1 or info == 25 and 2 or info == 26 and 4 or info == 27 and 8
            if not size then error("cbor: indefinite lengths are not supported") end
            local n = 0
            for i = 0, size - 1 do n = n * 256 + byte(source, position + i) end
            position = position + size
            return n
        end
        if major == 0 then return argument() end
        if major == 1 then return -1 - argument() end
        if major == 2 or major == 3 then
            local length = argument()
            local text = source:sub(position, position + length - 1)
            position = position + length
            return text
        end
        if major == 4 then
            local result = {}
            for i = 1, argument() do result[i] = read() end
            return result
        end
        if major == 5 then
            local result = {}
            for _ = 1, argument() do
                local key = read()
                result[key] = read()
            end
            return result
        end
        if major == 6 then argument() return read() end
        if info == 20 then return false end
        if info == 21 then return true end
        if info == 22 or info == 23 then return nil end
        local size = info == 25 and 2 or info == 26 and 4 or info == 27 and 8
        if not size then error("cbor: unsupported simple value") end
        local value = unpackFloat(source, position, size)
        position = position + size
        return value
    end
    local ok, value = pcall(read)
    if ok then return value end
    return nil
end

-- JSON ---------------------------------------------------------------------------------------------------------------

local ESCAPES = { ['"'] = '\\"', ["\\"] = "\\\\", ["\b"] = "\\b", ["\f"] = "\\f", ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t" }

function M.SerializeJSON(value)
    local valueType = type(value)
    if value == nil then return "null" end
    if valueType == "boolean" then return tostring(value) end
    if valueType == "number" then
        if value ~= value or value == math.huge or value == -math.huge then error("SerializeJSON: number not representable") end
        if value == floor(value) and math.abs(value) < 1e15 then return ("%d"):format(value) end
        return ("%.17g"):format(value)
    end
    if valueType == "string" then
        return '"' .. value:gsub('[%c"\\]', function(c) return ESCAPES[c] or ("\\u%04x"):format(byte(c)) end) .. '"'
    end
    if valueType == "table" then
        local sequence, count = isSequence(value)
        if sequence and count > 0 then
            local parts = {}
            for i = 1, count do parts[i] = M.SerializeJSON(value[i]) end
            return "[" .. table.concat(parts, ",") .. "]"
        end
        local keys = {}
        for key in pairs(value) do keys[#keys + 1] = tostring(key) end
        table.sort(keys)
        local parts = {}
        for _, key in ipairs(keys) do
            local inner = value[key]
            if inner == nil then inner = value[tonumber(key)] end
            parts[#parts + 1] = M.SerializeJSON(key) .. ":" .. M.SerializeJSON(inner)
        end
        return "{" .. table.concat(parts, ",") .. "}"
    end
    error("SerializeJSON: unsupported value of type " .. valueType)
end

local function utf8(code)
    if code < 128 then return char(code) end
    if code < 2048 then return char(192 + floor(code / 64), 128 + code % 64) end
    if code < 65536 then return char(224 + floor(code / 4096), 128 + floor(code / 64) % 64, 128 + code % 64) end
    return char(240 + floor(code / 262144), 128 + floor(code / 4096) % 64, 128 + floor(code / 64) % 64, 128 + code % 64)
end

function M.DeserializeJSON(source)
    local position = 1
    local function skip() position = source:find("[^ \t\r\n]", position) or #source + 1 end
    local read
    local function readString()
        position = position + 1
        local parts = {}
        while true do
            local c = source:sub(position, position)
            if c == "" then error("json: unterminated string") end
            if c == '"' then position = position + 1 break end
            if c == "\\" then
                local e = source:sub(position + 1, position + 1)
                local simple = { b = "\b", f = "\f", n = "\n", r = "\r", t = "\t", ['"'] = '"', ["\\"] = "\\", ["/"] = "/" }
                if simple[e] then
                    parts[#parts + 1] = simple[e]
                    position = position + 2
                elseif e == "u" then
                    local code = tonumber(source:sub(position + 2, position + 5), 16)
                    position = position + 6
                    if code >= 0xD800 and code < 0xDC00 and source:sub(position, position + 1) == "\\u" then
                        local low = tonumber(source:sub(position + 2, position + 5), 16)
                        code = 0x10000 + (code - 0xD800) * 1024 + (low - 0xDC00)
                        position = position + 6
                    end
                    parts[#parts + 1] = utf8(code)
                else
                    error("json: bad escape")
                end
            else
                parts[#parts + 1] = c
                position = position + 1
            end
        end
        return table.concat(parts)
    end
    function read()
        skip()
        local c = source:sub(position, position)
        if c == "{" then
            position = position + 1
            local result = {}
            skip()
            if source:sub(position, position) == "}" then position = position + 1 return result end
            while true do
                skip()
                if source:sub(position, position) ~= '"' then error("json: expected key") end
                local key = readString()
                skip()
                if source:sub(position, position) ~= ":" then error("json: expected colon") end
                position = position + 1
                result[key] = read()
                skip()
                local separator = source:sub(position, position)
                position = position + 1
                if separator == "}" then return result end
                if separator ~= "," then error("json: expected comma") end
            end
        elseif c == "[" then
            position = position + 1
            local result, index = {}, 0
            skip()
            if source:sub(position, position) == "]" then position = position + 1 return result end
            while true do
                index = index + 1
                result[index] = read()
                skip()
                local separator = source:sub(position, position)
                position = position + 1
                if separator == "]" then return result end
                if separator ~= "," then error("json: expected comma") end
            end
        elseif c == '"' then
            return readString()
        elseif source:sub(position, position + 3) == "true" then
            position = position + 4
            return true
        elseif source:sub(position, position + 4) == "false" then
            position = position + 5
            return false
        elseif source:sub(position, position + 3) == "null" then
            position = position + 4
            return nil
        else
            local number = source:match("^-?%d+%.?%d*[eE]?[-+]?%d*", position)
            if not number or number == "" then error("json: unexpected character") end
            position = position + #number
            return tonumber(number)
        end
    end
    local ok, value = pcall(function()
        local result = read()
        skip()
        if position <= #source then error("json: trailing characters") end
        return result
    end)
    if ok then return value end
    return nil
end

---gives the world's C_EncodingUtil these implementations (only the functions its client documents)
function M.Install(world)
    for name, implementation in pairs({
        EncodeBase64 = M.EncodeBase64, DecodeBase64 = M.DecodeBase64, EncodeHex = M.EncodeHex, DecodeHex = M.DecodeHex,
        CompressString = M.CompressString, DecompressString = M.DecompressString,
        SerializeCBOR = M.SerializeCBOR, DeserializeCBOR = M.DeserializeCBOR,
        SerializeJSON = M.SerializeJSON, DeserializeJSON = M.DeserializeJSON,
    }) do
        if world.api.has("C_EncodingUtil." .. name) then world.api.set("C_EncodingUtil." .. name, implementation) end
    end
end

return M
