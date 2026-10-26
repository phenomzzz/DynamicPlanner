#!/usr/bin/env bash
# Rebuild the clean addon, mirror it here, leak-scan, refuse on any hit.
set -euo pipefail
SRC="${SRC:?set SRC to the addon source folder}"
HERE="$(cd "$(dirname "$0")/.." && pwd)"
NAMES="$SRC/tools/leak-names.private.txt"
(cd "$SRC" && py.exe tools/package.py)
rm -rf "$HERE/DynamicPlanner"; mkdir -p "$HERE/DynamicPlanner"
cp -r "$SRC/dist/DynamicPlanner/." "$HERE/DynamicPlanner/"
fail=0
if [ -f "$NAMES" ]; then
  grep -rIiFn -f <(tr -d '\r' < "$NAMES" | grep -v '^\s*$') "$HERE" --exclude-dir=.git --exclude=publish.sh && fail=1
else echo "missing private names file"; fail=1; fi
for p in '/mnt/' 'E:\\' 'C:\\Users' '@gmail' 'warcraftlogs.com/reports'; do
  grep -rIin -e "$p" "$HERE" --exclude-dir=.git --exclude=publish.sh && fail=1
done
[ $fail = 0 ] || { echo "LEAK SCAN FAILED, nothing to publish"; exit 1; }
VER=$(grep -m1 '^## Version:' "$HERE/DynamicPlanner/DynamicPlanner.toc" | tr -d '\r' | awk '{print $3}')
echo "Clean. Next:"
echo "  git add -A && git commit -m 'Update $VER' && git push"
echo "  git tag v$VER && git push origin v$VER"
echo "  gh release create v$VER <addon>/dist/DynamicPlanner-$VER.zip --title v$VER --notes ..."
