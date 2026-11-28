#!/usr/bin/env bash
# An edition of the site for each release of the compiler
# (cesiumlang/cesiumlang.org#43): for each tag vX.Y.Z of the cesium checkout,
# its specification, proposals and diagnostics under content/vX.Y.Z/, taken
# by tools/take-spec.sh from that tag's tree (with the Skein its
# skein-version names). The latest release is also the site's root, which
# take-spec.sh takes from a checkout of that tag.
#
# usage: bash tools/take-editions.sh [CESIUM_DIR]   (default: ../cesium-src)
#
# The checkout needs its tags (`git fetch --tags`).
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cesium=$(cd "${1:-$ROOT/../cesium-src}" && pwd)

# editions of tags that are gone, and of earlier runs
find "$ROOT/content" -maxdepth 1 -type d -regex '.*/v[0-9]+\.[0-9]+\.[0-9]+' -exec rm -rf {} +

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
n=0
for tag in $(git -C "$cesium" tag --list 'v[0-9]*' --sort=-version:refname); do
  [[ $tag =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || continue
  tree=$work/$tag
  mkdir -p "$tree"
  git -C "$cesium" archive "$tag" | tar -x -C "$tree"
  bash "$ROOT/tools/take-spec.sh" "$tree" "${tag#v}"
  rm -rf "$tree"
  n=$((n + 1))
done
echo "took $n editions from $cesium"
