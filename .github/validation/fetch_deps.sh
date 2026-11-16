#!/bin/sh
# Fetch what the tests load but the repository does not hold, at its latest revision, into $1 (default /deps):
# - the .pkgmeta externals, the way BigWigsMods/packager fetches them, so tests run the libraries users get
# - Blizzard's UI source (github.com/Gethe/wow-ui-source) of every client the TOC supports, which the WoW mocks are
#   generated from (spec/helpers/api_docs.lua)
# Nothing is written inside the repository.
set -euf

deps="${1:-/deps}"
pkgmeta="${PKGMETA:-.pkgmeta}"
ui_repo="https://github.com/Gethe/wow-ui-source.git"
ui_branches="live ptr forever classic classic_titan classic_anniversary classic_era"
ui_paths="/version.txt /Interface/AddOns/Blizzard_APIDocumentationGenerated/ /Interface/AddOns/Blizzard_SharedXMLBase/ /Interface/AddOns/Blizzard_SharedXML/ /Interface/AddOns/Blizzard_FrameXMLBase/ /Interface/AddOns/Blizzard_Deprecated*/"

rm -rf "$deps/Libs" "$deps/ui" "$deps/manifest.txt"
mkdir -p "$deps/Libs" "$deps/ui"
manifest="$deps/manifest.txt"
: > "$manifest"

# .pkgmeta "externals:" entries are "    <path>: <url>" until the next top-level key.
externals=$(awk '
    /^[^[:space:]#]/ { inside = ($0 ~ /^externals:/); next }
    inside && /^[[:space:]]+[^[:space:]#][^:]*:[[:space:]]*[^[:space:]]/ {
        line = $0
        sub(/^[[:space:]]+/, "", line)
        path = substr(line, 1, index(line, ":") - 1)
        url = substr(line, index(line, ":") + 1)
        gsub(/[[:space:]]/, "", url)
        print path " " url
    }' "$pkgmeta")

echo "$externals" | while read -r path url; do
    [ -n "$path" ] || continue
    target="$deps/$path"
    mkdir -p "$(dirname "$target")"
    # BigWigsMods/packager release.sh process_external: old svn hosts become repos.<host>/wow/<slug>/trunk, and a
    # repos.curseforge.com or repos.wowace.com path under trunk is subversion; anything else is git.
    case "$url" in
        svn://svn.curseforge.com/*|svn://svn.wowace.com/*)
            url="https://repos$(echo "${url#*://svn}" | sed 's#/mainline##')"
            ;;
    esac
    case "$url" in
        https://repos.curseforge.com/wow/*/trunk*|https://repos.wowace.com/wow/*/trunk*|svn:*)
            kind=svn
            ;;
        *)
            kind=git
            ;;
    esac
    case "$kind" in
        git)
            git clone --quiet --depth 1 "$url" "$target"
            echo "$path git $(git -C "$target" rev-parse HEAD)" >> "$manifest"
            rm -rf "$target/.git"
            ;;
        *)
            svn export --quiet --non-interactive --force "$url" "$target"
            echo "$path svn $(svn info --non-interactive --show-item last-changed-revision "$url")" >> "$manifest"
            ;;
    esac
done

for branch in $ui_branches; do
    target="$deps/ui/$branch"
    git clone --quiet --depth 1 --filter=blob:none --sparse --branch "$branch" "$ui_repo" "$target"
    # shellcheck disable=SC2086
    git -C "$target" sparse-checkout set --no-cone $ui_paths
    echo "ui/$branch git $(git -C "$target" rev-parse HEAD)" >> "$manifest"
    rm -rf "$target/.git"
done

cat "$manifest"
