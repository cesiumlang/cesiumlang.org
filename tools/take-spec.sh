#!/usr/bin/env bash
# Take the specification and the proposals from a checkout of cesiumlang/cesium
# into content/spec/ and content/proposals/, as Skein renders them
# (`skein render --format markdown`; cesiumlang/cesium#106), and the catalog of
# diagnostics into content/compiler/diagnostics.md. The pages are generated:
# edit them in cesium, never here.
#
# usage: bash tools/take-spec.sh [CESIUM_DIR [EDITION]]   (default: ../cesium-src)
#
# With EDITION (a released version, 0.1.0), the pages go under
# content/vEDITION/ instead, with a front page of their own and no tags or
# aliases: an edition of the site per compiler release
# (cesiumlang/cesiumlang.org#43; tools/take-editions.sh takes them all).
#
# Skein comes from cesium's tools/fetch-skein.sh, as cesium's CI gets it. Each
# page gets the front matter the site reads: its first heading as the title
# (taken out of the text), tags, its place, and the URLs it also answers.
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cesium=$(cd "${1:-$ROOT/../cesium-src}" && pwd)
edition=${2:-}

bash "$cesium/tools/fetch-skein.sh"
skein=$cesium/.skein-bin/bin/skein
[ -x "$skein" ] || skein=$skein.exe

out=$(mktemp -d)
trap 'rm -rf "$out"' EXIT
"$skein" render --root "$cesium" --format markdown --out "$out" > /dev/null

if [ -n "$edition" ]; then
  dest=$ROOT/content/v$edition
else
  dest=$ROOT/content
  # the compiler version the pages are of, which every page's footer shows
  # (cesiumlang/cesiumlang.org#42): a released one by its number, else the
  # development version with its branch and commit
  version=$(sed -nE 's/^\s*\.version = "([^"]+)",/\1/p' "$cesium/build.zig.zon")
  commit=$(git -C "$cesium" rev-parse --short HEAD 2> /dev/null || echo unknown)
  branch=$(git -C "$cesium" rev-parse --abbrev-ref HEAD 2> /dev/null || echo HEAD)
  [ "$branch" = HEAD ] && branch=commit
  released=false
  if git -C "$cesium" rev-parse -q --verify "refs/tags/v$version" > /dev/null 2>&1; then
    released=true
    printf 'Cesium %s\n' "$version" > "$ROOT/content/cesium-version.txt"
  else
    printf 'Cesium %s, in development (%s at %s)\n' "$version" "$branch" "$commit" > "$ROOT/content/cesium-version.txt"
  fi
  # the released versions, newest first, for the edition selector: whether
  # this site is a release (cesiumlang.org) or the development (cesiumlang.dev)
  releases=$(git -C "$cesium" tag --list 'v[0-9]*' --sort=-version:refname 2> /dev/null | sed -nE 's/^v([0-9]+\.[0-9]+\.[0-9]+)$/"\1"/p' | paste -sd, -)
  printf '{"development":%s,"releases":[%s]}\n' "$([ $released = true ] && echo false || echo true)" "$releases" > "$ROOT/content/cesium-editions.json"
fi

# PATH TAGS SORTORDER ALIASES: the pages, in their order; an alias is a URL the
# page had before it came from Skein
pages='spec/index.md|spec|1|
spec/lexical.md|spec, lexical|2|
spec/s0.md|spec, grammar, s0|3|/spec/s0-grammar/index.html'

rm -rf "$dest/spec" "$dest/proposals"
take () { # SOURCE TARGET TAGS SORTORDER ALIASES
  local title body tags=$3 aliases=$5
  # an edition repeats the pages of the site: no tags (the tag pages list the
  # site's own pages) and no old URLs
  [ -n "$edition" ] && tags="" aliases=""
  # an item file's own front matter (title: its ID) gives way to the site's
  body=$(awk 'NR == 1 && $0 == "---" { skip = 1; next } skip && $0 == "---" { skip = 0; next } !skip' "$1")
  title=$(printf '%s\n' "$body" | sed -n 's/^# //p' | head -n 1)
  mkdir -p "$(dirname "$2")"
  {
    printf -- '---\ntitle: "%s"\n' "${title//\"/\\\"}"
    printf 'tags: [%s]\n' "$(printf '%s' "$tags" | sed 's/[^, ][^,]*/"&"/g')"
    [ -n "$4" ] && printf 'sortorder: %s\n' "$4"
    [ -n "$aliases" ] && printf 'aliases: ["%s"]\n' "$aliases"
    printf -- '---\n\n'
    printf '%s\n' "$body" | awk '!done && /^# / { done = 1; getline; if ($0 != "") print; next } { print }'
  } > "$2"
}
while IFS='|' read -r path tags order aliases; do
  take "$out/$path" "$dest/$path" "$tags" "$order" "$aliases"
done <<< "$pages"
# the rest of spec/, and every proposal
for f in "$out"/spec/*.md "$out"/proposals/*.md; do
  rel=${f#"$out"/}
  [ -e "$dest/$rel" ] && continue
  case $rel in proposals/*) tags=proposal ;; *) tags=spec ;; esac
  take "$f" "$dest/$rel" "$tags" "" ""
done
# the compilers' diagnostic codes, from their catalog (cesiumlang/cesium#82);
# each code's heading is its anchor (#e0304)
take "$cesium/bootstrap/diagnostics.md" "$dest/compiler/diagnostics.md" "compiler, diagnostics" "" ""

# an edition's front page
if [ -n "$edition" ]; then
  cat > "$dest/index.md" << EOF
---
title: "Cesium $edition"
tags: []
---

The specification, the proposals and the diagnostics of Cesium $edition, as that release has them. The other pages of the site are about the latest release.

- [The specification](spec/index.md)
- [The proposals](proposals/0000-documentation-system.md)
- [The diagnostics](compiler/diagnostics.md)
EOF
fi
echo "took $(find "$dest/spec" "$dest/proposals" -name '*.md' | wc -l | tr -d ' ') pages from $cesium${edition:+ for v$edition}"
