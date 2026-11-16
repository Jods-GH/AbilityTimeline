-- The test world against the sources it is generated from (spec/helpers/world.lua).
local Docs = require("spec.helpers.api_docs")
local World = require("spec.helpers.world")
local Blizzard = require("spec.helpers.blizzard_lua")

describe("world generation", function()
    for _, client in ipairs(Docs.CLIENT_ORDER) do
        describe(client, function()
            local world
            before_each(function() world = World.Build({ client = client, libraries = false }) end)

            it("has every function, namespace and enumeration the client documents", function()
                for fullName in pairs(world.docs.functions) do
                    local namespace, name = fullName:match("^([^%.]+)%.(.+)$")
                    local value = namespace and _G[namespace] and _G[namespace][name] or not namespace and _G[fullName]
                    assert.is_not_nil(value, fullName)
                end
                for name in pairs(world.docs.enums) do assert.is_table(Enum[name], name) end
            end)

            it("defines every global the addon reads that the client has", function()
                local dump = world.dump
                -- Without a runtime dump (Titan) the C constants are missing, so Blizzard files that need them stop
                -- early; their later globals are a known gap of that client's world, not a failure of the addon.
                local missingData = {}
                if not dump.runtime then
                    for _, entry in ipairs(world.blizzardPlan.files) do
                        if world.blizzardFailures[entry.path] then
                            for name in pairs(entry.defines) do missingData[name] = true end
                        end
                    end
                end
                for _, name in ipairs(Blizzard.AddonGlobals(World.ROOT .. "/.luacheckrc")) do
                    local clientHas = world.docs.functions[name] or world.blizzardPlan.byGlobal[name]
                        or dump.strings[name] or (dump.runtime and dump.globalAPI[name])
                    if clientHas and not missingData[name] then assert.is_not_nil(_G[name], name) end
                end
            end)

            it("sets WOW_PROJECT_ID to the client's project", function()
                assert.is_number(WOW_PROJECT_ID)
                assert.equals(Docs.CLIENTS[client].retail == true, WOW_PROJECT_ID == WOW_PROJECT_MAINLINE)
            end)

            it("creates the client's global colors with Blizzard's CreateColor", function()
                assert.is_table(NORMAL_FONT_COLOR)
                assert.is_function(NORMAL_FONT_COLOR.GetRGB)
            end)
        end)
    end

    it("leaves functions out that a client does not document", function()
        World.Build({ client = "vanilla", libraries = false })
        assert.is_nil(C_Weather and C_Weather.GetCurrentWeather)
        World.Build({ client = "retail", libraries = false })
        assert.is_function(C_Weather.GetCurrentWeather)
    end)

    it("refuses to override a function the client does not have", function()
        local world = World.Build({ client = "retail", libraries = false })
        assert.has_error(function() world.api.set("C_NotAThing.Missing", function() end) end)
    end)
end)

describe("documented functions", function()
    local world
    before_each(function() world = World.Build({ libraries = false }) end)

    it("raise the client's error for an argument of the wrong type", function()
        -- ChallengeModeInfoDocumentation.lua: GetSpecificDungeonOverallScoreRarityColor(specificDungeonOverallScore: number)
        assert.has_error(function() C_ChallengeMode.GetSpecificDungeonOverallScoreRarityColor({}) end)
        assert.has_no_error(function() C_ChallengeMode.GetSpecificDungeonOverallScoreRarityColor("12") end)
    end)

    it("convert like Lua's C API: a numeric string is a number argument", function()
        world.game.spells[123] = { name = "Test Spell" }
        assert.equals("Test Spell", C_Spell.GetSpellName("123"))
    end)

    it("return values shaped by their documented returns until a spec sets a behaviour", function()
        local layouts = C_EditMode.GetLayouts()
        assert.is_table(layouts.layouts)
    end)
end)

describe("Lua extensions", function()
    before_each(function() World.Build({ libraries = false }) end)

    it("split on every delimiter byte (API_string.split)", function()
        assert.same({ "1", "2", "3" }, { strsplit("ab", "1a2b3") })
        assert.same({ "1", "", "2" }, { strsplit("ab", "1ab2") })
        assert.same({ "a", "b-c" }, { strsplit("-", "a-b-c", 2) })
    end)

    it("trim spaces, tabs and line breaks by default (API_string.trim)", function()
        assert.equals("x", strtrim(" \t x\r\n"))
        assert.equals(" x ", strtrim("-- x --", "-"))
    end)

    it("pass xpcall's extra arguments on (API_xpcall)", function()
        assert.same({ true, 3 }, { xpcall(function(a, b) return a + b end, print, 1, 2) })
    end)

    it("send an error in securecallfunction to the error handler and return nothing", function()
        local world = World.current
        assert.same({}, { securecallfunction(function() error("boom") end) })
        assert.matches("boom", world.errors[#world.errors])
    end)

    it("do 32-bit bit operations", function()
        assert.equals(4, bit.band(12, 6))
        assert.equals(14, bit.bor(12, 6))
        assert.equals(-1, bit.bnot(0))
    end)
end)

describe("widgets", function()
    local world
    before_each(function() world = World.Build({ libraries = false }) end)

    it("have only the methods the client documents", function()
        local frame = CreateFrame("Frame")
        assert.is_function(frame.SetPoint)
        assert.is_nil(frame.NotAMethod)
        assert.is_nil(CreateFrame("Frame"):CreateTexture().RegisterEvent)
    end)

    it("run OnUpdate only while visible", function()
        local frame, runs = CreateFrame("Frame"), 0
        frame:SetScript("OnUpdate", function() runs = runs + 1 end)
        world.clock.Advance(0.05)
        local shownRuns = runs
        frame:Hide()
        world.clock.Advance(0.05)
        assert.is_true(shownRuns > 0)
        assert.equals(shownRuns, runs)
    end)

    it("fire OnAttributeChanged and keep attributes per name", function()
        local frame, changed = CreateFrame("Frame"), {}
        frame:SetScript("OnAttributeChanged", function(_, name, value) changed[name] = value end)
        frame:SetAttribute("a", { 1 })
        assert.same({ 1 }, frame:GetAttribute("a"))
        assert.same({ 1 }, changed.a)
        assert.is_nil(frame:GetAttribute("b"))
    end)

    it("lay out anchors against UIParent", function()
        local frame = CreateFrame("Frame", nil, UIParent)
        frame:SetSize(100, 50)
        frame:SetPoint("CENTER")
        assert.same({ 960, 540 }, { frame:GetCenter() })
        local child = CreateFrame("Frame", nil, frame)
        child:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -10)
        child:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 10)
        assert.same({ 80, 30 }, { child:GetSize() })
    end)

    it("refuse an event the client does not have", function()
        assert.has_error(function() CreateFrame("Frame"):RegisterEvent("NOT_AN_EVENT") end)
    end)

    it("apply Blizzard's XML templates and fonts", function()
        local button = CreateFrame("Button", nil, UIParent, "UIPanelButtonTemplate")
        button:SetText("Go")
        assert.equals("Go", button:GetText())
        assert.is_table(GameFontNormal)
        assert.has_error(function() CreateFrame("Frame", nil, UIParent, "NotATemplate") end)
    end)

    it("play animation groups on the clock", function()
        local frame = CreateFrame("Frame")
        local group = frame:CreateAnimationGroup()
        group:CreateAnimation("Alpha"):SetDuration(0.5)
        local finished = false
        group:SetScript("OnFinished", function() finished = true end)
        group:Play()
        world.clock.Advance(0.4)
        assert.is_false(finished)
        world.clock.Advance(0.2)
        assert.is_true(finished)
    end)
end)

describe("clock", function()
    local world
    before_each(function() world = World.Build({ libraries = false }) end)

    it("runs C_Timer callbacks when time reaches them", function()
        local ran = {}
        C_Timer.After(1.05, function() ran[#ran + 1] = "after" end)
        local ticker = C_Timer.NewTicker(0.5, function() ran[#ran + 1] = "tick" end, 2)
        local start = GetTime()
        world.clock.Advance(0.9)
        assert.same({ "tick" }, ran)
        world.clock.Advance(0.2)
        assert.same({ "tick", "tick", "after" }, ran)
        assert.is_true(ticker:IsCancelled())
        assert.is_true(GetTime() - start > 1.09)
    end)
end)
