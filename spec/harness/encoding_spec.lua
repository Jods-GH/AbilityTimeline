-- C_EncodingUtil's encodings (spec/helpers/encoding_util.lua) against their standards' test vectors.
local Encoding = require("spec.helpers.encoding_util")
local World = require("spec.helpers.world")

local function hex(bytes)
    return (bytes:gsub(".", function(c) return ("%02x"):format(c:byte()) end))
end
local function unhex(text)
    return (text:gsub("%x%x", function(h) return string.char(tonumber(h, 16)) end))
end

describe("Base64 (RFC 4648 section 10)", function()
    local vectors = { [""] = "", f = "Zg==", fo = "Zm8=", foo = "Zm9v", foob = "Zm9vYg==", fooba = "Zm9vYmE=", foobar = "Zm9vYmFy" }
    for plain, encoded in pairs(vectors) do
        it("encodes and decodes '" .. plain .. "'", function()
            assert.equals(encoded, Encoding.EncodeBase64(plain))
            assert.equals(plain, Encoding.DecodeBase64(encoded))
        end)
    end
    it("uses - and _ for the URL safe variant", function()
        assert.equals("-_8=", Encoding.EncodeBase64("\251\255", 1))
    end)
    it("refuses characters outside the alphabet", function()
        assert.is_nil(Encoding.DecodeBase64("Zm9v!"))
    end)
end)

describe("CBOR (RFC 8949 appendix A)", function()
    local vectors = {
        { 0, "00" }, { 1, "01" }, { 10, "0a" }, { 23, "17" }, { 24, "1818" }, { 25, "1819" }, { 100, "1864" },
        { 1000, "1903e8" }, { 1000000, "1a000f4240" }, { -1, "20" }, { -10, "29" }, { -100, "3863" }, { -1000, "3903e7" },
        { 1.1, "fb3ff199999999999a" }, { -4.1, "fbc010666666666666" }, { 1.0e300, "fb7e37e43c8800759c" },
        { false, "f4" }, { true, "f5" }, { "", "60" }, { "a", "6161" }, { "IETF", "6449455446" },
        { { 1, 2, 3 }, "83010203" }, { { 1, { 2, 3 }, { 4, 5 } }, "8301820203820405" },
    }
    for _, vector in ipairs(vectors) do
        it("encodes and decodes " .. hex(unhex(vector[2])), function()
            assert.equals(vector[2], hex(Encoding.SerializeCBOR(vector[1])))
            assert.same(vector[1], Encoding.DeserializeCBOR(unhex(vector[2])))
        end)
    end
    it("decodes half and single precision floats", function()
        assert.equals(1.5, Encoding.DeserializeCBOR(unhex("f93e00")))
        assert.equals(100000.0, Encoding.DeserializeCBOR(unhex("fa47c35000")))
        assert.equals(math.huge, Encoding.DeserializeCBOR(unhex("f97c00")))
    end)
    it("round-trips maps with string and number keys", function()
        local value = { a = 1, b = { "x", "y" }, [5] = false, nested = { deep = 2.5 } }
        assert.same(value, Encoding.DeserializeCBOR(Encoding.SerializeCBOR(value)))
    end)
    it("gives nil for malformed input", function()
        assert.is_nil(Encoding.DeserializeCBOR(unhex("83")))
    end)
end)

describe("Deflate (RFC 1951), Zlib (RFC 1950) and Gzip (RFC 1952)", function()
    local text = {}
    for i = 0, 39 do text[#text + 1] = ("AbilityTimeline reminder %d at 1:%d for the boss; "):format(i, i) end
    text = table.concat(text)

    -- gzip -9 -n of "a" (a fixed Huffman block) and of text (a dynamic Huffman block), from Alpine's gzip
    local fixed = "H4sIAAAAAAACA0sEAEO+t+gBAAAA"
    local dynamic = "H4sIAAAAAAACA43UO2pDQRSD4a3MEizJz6TyHrwBm0zIgB9wfZvs3sXRbQwG9X/3IR0v4zrm/9O49eu49zb127j/9Kmt2nlu+Fq138fU5r/eLo/n87sdP/WoHmnP6pn2ql5pv65+nfab6jdpv61+m/a76ndpv69+n/aH6g+xl4GRCy/EsTGMjFgZZkbsDEMjloapEVvD2Ii1YW7E3jA4YnGYHLE5bc7YnDZnvutl2LE5bc7YnDZnbE6bMzanzRmb0+aMzWlzxua0OWNz2VyxuWyu2Fw2V/7my53H5rK5YnPZXLG5bK7YXDZXbC6bKzaXzfVu/gIFCaldvAcAAA=="

    it("inflates a fixed Huffman block", function()
        assert.equals("a", Encoding.DecompressString(Encoding.DecodeBase64(fixed), 2))
    end)
    it("inflates a dynamic Huffman block", function()
        assert.equals(text, Encoding.DecompressString(Encoding.DecodeBase64(dynamic), 2))
    end)
    for method, name in pairs({ [0] = "Deflate", [1] = "Zlib", [2] = "Gzip" }) do
        it("round-trips " .. name, function()
            assert.equals(text, Encoding.DecompressString(Encoding.CompressString(text, method), method))
            assert.equals("", Encoding.DecompressString(Encoding.CompressString("", method), method))
        end)
    end
    it("splits data longer than one stored block", function()
        local long = ("x"):rep(70000)
        assert.equals(long, Encoding.DecompressString(Encoding.CompressString(long)))
    end)
    it("writes the RFC 1950 Adler-32 and RFC 1952 CRC-32 checksums", function()
        World.Build({ libraries = false })
        assert.equals(0x11E60398, Encoding.Adler32("Wikipedia"))
        assert.equals(0xCBF43926, Encoding.Crc32("123456789"))
    end)
    it("gives nil for malformed input", function()
        assert.is_nil(Encoding.DecompressString("\7\0"))
    end)
end)

describe("JSON (RFC 8259)", function()
    it("reads the RFC's example object", function()
        local value = Encoding.DeserializeJSON('{"Image":{"Width":800,"Height":600,"Title":"View from 15th Floor",'
            .. '"Thumbnail":{"Url":"http://www.example.com/image/481989943","Height":125,"Width":100},'
            .. '"Animated":false,"IDs":[116,943,234,38793]}}')
        assert.equals(800, value.Image.Width)
        assert.is_false(value.Image.Animated)
        assert.same({ 116, 943, 234, 38793 }, value.Image.IDs)
    end)
    it("reads escapes and surrogate pairs", function()
        assert.equals('a"b\\c\n\226\130\172\240\157\132\158', Encoding.DeserializeJSON('"a\\"b\\\\c\\n\\u20ac\\ud834\\udd1e"'))
    end)
    it("round-trips strings with quotes, backslashes, control characters and braces", function()
        local value = { text = 'say "hi" {now}\\ \n\t', list = { 1, 2.5, true }, empty = {} }
        local read = Encoding.DeserializeJSON(Encoding.SerializeJSON(value))
        assert.equals(value.text, read.text)
        assert.same(value.list, read.list)
    end)
    it("gives nil for malformed input", function()
        assert.is_nil(Encoding.DeserializeJSON('{"a":}'))
        assert.is_nil(Encoding.DeserializeJSON('[1,2'))
    end)
end)
