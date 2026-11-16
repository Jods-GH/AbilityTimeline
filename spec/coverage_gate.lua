-- coverage_gate.lua <statsfile> [--suggest]: line coverage of every Lua file the addon's TOC loads on any client,
-- counted the way luacov's reporter counts it (luacov.linescanner), checked against spec/coverage_floors.lua. Fails
-- when the total or a file falls below its floor. Generated per-edition encounter data is not counted (it is data, not
-- code paths). --suggest prints floors at this run's coverage (whole percent, rounded down) to put in the floors file.
package.path = "./?.lua;" .. package.path
local LineScanner = require("luacov.linescanner")
local Stats = require("luacov.stats")
local Toc = require("spec.helpers.toc")
local Floors = dofile("spec/coverage_floors.lua")

local statsfile = assert(arg[1], "usage: coverage_gate.lua <statsfile>")
local stats = assert(Stats.load(statsfile), "no coverage stats in " .. statsfile)
local byFile = {}
for name, data in pairs(stats) do byFile[(name:gsub("^%./", ""))] = data end

local files, seen = {}, {}
for gameType in pairs(Toc.GAME_TYPES) do
    for _, file in ipairs(Toc.Files("./AbilityTimeline.toc", gameType, function(path)
        path = path:gsub("^%./", "")
        if path:find("^Libs/") or path:find("^embeds%.xml$") then return nil end
        return path
    end)) do
        if file.path:find("%.lua$") and not file.path:find("^Data/Encounters/") and not seen[file.path] then
            seen[file.path] = true
            files[#files + 1] = file.path
        end
    end
end
table.sort(files)

local totalLines, totalHits, failures, suggested = 0, 0, {}, {}
print(("%-52s %7s %7s %7s %7s"):format("File", "Lines", "Hit", "Cover", "Floor"))
for _, path in ipairs(files) do
    local data = byFile[path] or {}
    local scanner = LineScanner:new()
    local lines, hits, number = 0, 0, 0
    for line in (Toc.Read(path) .. "\n"):gmatch("([^\n]*)\n") do
        number = number + 1
        local count = data[number] or 0
        local alwaysExcluded, excludedWhenNotHit = scanner:consume(line)
        if not alwaysExcluded and (not excludedWhenNotHit or count ~= 0) then
            lines = lines + 1
            if count > 0 then hits = hits + 1 end
        end
    end
    totalLines, totalHits = totalLines + lines, totalHits + hits
    local percent = lines > 0 and hits / lines * 100 or 100
    local floor = Floors.files[path] or 0
    if math.floor(percent) > 0 then suggested[#suggested + 1] = ('        ["%s"] = %d,'):format(path, math.floor(percent)) end
    print(("%-52s %7d %7d %6.1f%% %6.1f%%"):format(path, lines, hits, percent, floor))
    if percent + 1e-9 < floor then failures[#failures + 1] = ("%s: %.1f%% is below its floor of %.1f%%"):format(path, percent, floor) end
end
local total = totalLines > 0 and totalHits / totalLines * 100 or 100
print(("%-52s %7d %7d %6.1f%% %6.1f%%"):format("Total", totalLines, totalHits, total, Floors.total))
if total + 1e-9 < Floors.total then failures[#failures + 1] = ("total: %.1f%% is below its floor of %.1f%%"):format(total, Floors.total) end

if #failures > 0 then
    print("\nCoverage below its floor:")
    for _, failure in ipairs(failures) do print("  " .. failure) end
    os.exit(1)
end
print("\nCoverage floors met.")

if arg[2] == "--suggest" then
    print("\nreturn {\n    total = " .. math.floor(total) .. ",\n    files = {")
    for _, line in ipairs(suggested) do print(line) end
    print("    },\n}")
end
