#!/usr/bin/env bash
# Take the specification and the proposals from a checkout of cesiumlang/cesium
# into content/spec/ and content/proposals/, as Skein renders them
# (`skein render --format markdown`; cesiumlang/cesium#106), and the catalog of
# diagnostics into content/compiler/diagnostics.md. The pages are generated:
# edit them in cesium, never here.
#
# usage: bash tools/take-spec.sh [CESIUM_DIR]   (default: ../cesium-src)
#
# Skein comes from cesium's tools/fetch-skein.sh, as cesium's CI gets it. Each
# page gets the front matter the site reads: its first heading as the title
# (taken out of the text), tags, its place, and the URLs it also answers.
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cesium=$(cd "${1:-$ROOT/../cesium-src}" && pwd)

bash "$cesium/tools/fetch-skein.sh"
skein=$cesium/.skein-bin/bin/skein
[ -x "$skein" ] || skein=$skein.exe

out=$(mktemp -d)
trap 'rm -rf "$out"' EXIT
"$skein" render --root "$cesium" --format markdown --out "$out" > /dev/null

# PATH TAGS SORTORDER ALIASES: the pages, in their order; an alias is a URL the
# page had before it came from Skein
pages='spec/index.md|spec|1|
spec/lexical.md|spec, lexical|2|
spec/s0.md|spec, grammar, s0|3|/spec/s0-grammar/index.html'

rm -rf "$ROOT/content/spec" "$ROOT/content/proposals"
take () { # SOURCE TARGET TAGS SORTORDER ALIASES
  local title body
  # an item file's own front matter (title: its ID) gives way to the site's
  body=$(awk 'NR == 1 && $0 == "---" { skip = 1; next } skip && $0 == "---" { skip = 0; next } !skip' "$1")
  title=$(printf '%s\n' "$body" | sed -n 's/^# //p' | head -n 1)
  mkdir -p "$(dirname "$2")"
  {
    printf -- '---\ntitle: "%s"\n' "${title//\"/\\\"}"
    printf 'tags: [%s]\n' "$(printf '%s' "$3" | sed 's/[^, ][^,]*/"&"/g')"
    [ -n "$4" ] && printf 'sortorder: %s\n' "$4"
    [ -n "$5" ] && printf 'aliases: ["%s"]\n' "$5"
    printf -- '---\n\n'
    printf '%s\n' "$body" | awk '!done && /^# / { done = 1; getline; if ($0 != "") print; next } { print }'
  } > "$2"
}
while IFS='|' read -r path tags order aliases; do
  take "$out/$path" "$ROOT/content/$path" "$tags" "$order" "$aliases"
done <<< "$pages"
# the rest of spec/, and every proposal
for f in "$out"/spec/*.md "$out"/proposals/*.md; do
  rel=${f#"$out"/}
  [ -e "$ROOT/content/$rel" ] && continue
  case $rel in proposals/*) tags=proposal ;; *) tags=spec ;; esac
  take "$f" "$ROOT/content/$rel" "$tags" "" ""
done
# the compilers' diagnostic codes, from their catalog (cesiumlang/cesium#82);
# each code's heading is its anchor (#e0304)
take "$cesium/bootstrap/diagnostics.md" "$ROOT/content/compiler/diagnostics.md" "compiler, diagnostics" "" ""
echo "took $(find "$ROOT/content/spec" "$ROOT/content/proposals" -name '*.md' | wc -l | tr -d ' ') pages from $cesium"
