#!/bin/sh
set -u

lua5.1 -e 'assert(_VERSION == "Lua 5.1", "Validation requires Lua 5.1")' || exit 1

# Run both checks even when lint fails, but never turn a failure into success.
status=0
luacheck --config .luacheckrc --no-cache --no-color --codes . || status=1
busted --lua=lua5.1 --config-file=.busted || status=1
exit "$status"
