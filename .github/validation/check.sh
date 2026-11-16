#!/bin/sh
# check.sh fetch       fetch the latest libraries and Blizzard UI source into /deps (needs network)
# check.sh test [spec] lint, then run the specs with coverage and its gate (offline, /deps read-only)
set -u

lua5.1 -e 'assert(_VERSION == "Lua 5.1", "Validation requires Lua 5.1")' || exit 1

mode="${1:-test}"
[ $# -gt 0 ] && shift

if [ "$mode" = "fetch" ]; then
    exec sh .github/validation/fetch_deps.sh /deps
fi

if [ ! -f /deps/manifest.txt ]; then
    echo "No dependencies in /deps: run the fetch step first (.github/validation/check.ps1 does both)." >&2
    exit 1
fi
echo "Dependencies:"
cat /deps/manifest.txt

# Run every check even when one fails, but never turn a failure into success.
status=0
luacheck --config .luacheckrc --no-cache --no-color --codes . || status=1
if [ $# -gt 0 ]; then
    busted --lua=lua5.1 --config-file=.busted "$@" || status=1
else
    rm -f /tmp/luacov.stats.out
    busted --lua=lua5.1 --config-file=.busted --coverage || status=1
    lua5.1 spec/tools/coverage_gate.lua /tmp/luacov.stats.out || status=1
fi
exit "$status"
