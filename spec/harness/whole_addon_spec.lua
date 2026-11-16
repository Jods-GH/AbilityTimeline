-- The released addon loads and starts on every client its TOC supports (spec/helpers/whole_addon.lua).
local Docs = require("spec.helpers.api_docs")
local WholeAddon = require("spec.helpers.whole_addon")

describe("the whole addon", function()
    for _, client in ipairs(Docs.CLIENT_ORDER) do
        it("loads and starts on " .. client .. " without errors", function()
            local handle = WholeAddon.Load({ client = client }):Start()
            assert.same({}, handle.errors)
            assert.is_table(handle.private.db)
            assert.equals(Docs.CLIENTS[client].retail == true, handle.private.isRetail)
        end)
    end

    it("starts on Retail while every documented secret condition applies", function()
        local handle = WholeAddon.Load({ client = "retail", restricted = true }):Start()
        assert.same({}, handle.errors)
    end)
end)
