#!/usr/bin/env bash
set -euo pipefail

BASE="Assets/AppIconBase.png"
ICONSET="Assets/AppIcon.iconset"
ICNS="Assets/AppIcon.icns"

if [[ ! -f "$BASE" ]]; then
  echo "Missing base icon at $BASE. Run: swift -module-cache-path .build/ModuleCache Scripts/generate_icon.swift" >&2
  exit 1
fi

mkdir -p "$ICONSET"
cat > "$ICONSET/Contents.json" <<'JSON'
{
  "images": [
    { "idiom": "mac", "size": "16x16", "scale": "1x", "filename": "icon_16x16.png" },
    { "idiom": "mac", "size": "16x16", "scale": "2x", "filename": "icon_16x16@2x.png" },
    { "idiom": "mac", "size": "32x32", "scale": "1x", "filename": "icon_32x32.png" },
    { "idiom": "mac", "size": "32x32", "scale": "2x", "filename": "icon_32x32@2x.png" },
    { "idiom": "mac", "size": "128x128", "scale": "1x", "filename": "icon_128x128.png" },
    { "idiom": "mac", "size": "128x128", "scale": "2x", "filename": "icon_128x128@2x.png" },
    { "idiom": "mac", "size": "256x256", "scale": "1x", "filename": "icon_256x256.png" },
    { "idiom": "mac", "size": "256x256", "scale": "2x", "filename": "icon_256x256@2x.png" },
    { "idiom": "mac", "size": "512x512", "scale": "1x", "filename": "icon_512x512.png" },
    { "idiom": "mac", "size": "512x512", "scale": "2x", "filename": "icon_512x512@2x.png" }
  ],
  "info": { "version": 1, "author": "codex" }
}
JSON

declare -a sizes=(
  "16 icon_16x16.png"
  "32 icon_16x16@2x.png"
  "32 icon_32x32.png"
  "64 icon_32x32@2x.png"
  "128 icon_128x128.png"
  "256 icon_128x128@2x.png"
  "256 icon_256x256.png"
  "512 icon_256x256@2x.png"
  "512 icon_512x512.png"
  "1024 icon_512x512@2x.png"
)

for entry in "${sizes[@]}"; do
  read -r size name <<<"$entry"
  echo "- Generating $name ($size x $size)"
  sips -z "$size" "$size" "$BASE" --out "$ICONSET/$name" >/dev/null
done

python3 - <<'PY'
import pathlib
import struct
import sys

iconset = pathlib.Path("Assets/AppIcon.iconset")
output = pathlib.Path("Assets/AppIcon.icns")

entries = [
    ("icp4", "icon_16x16.png"),
    ("ic11", "icon_16x16@2x.png"),
    ("icp5", "icon_32x32.png"),
    ("ic12", "icon_32x32@2x.png"),
    ("icp6", "icon_32x32@2x.png"),
    ("ic07", "icon_128x128.png"),
    ("ic13", "icon_128x128@2x.png"),
    ("ic08", "icon_256x256.png"),
    ("ic14", "icon_256x256@2x.png"),
    ("ic09", "icon_512x512.png"),
    ("ic10", "icon_512x512@2x.png"),
]

parts = []
total_length = 8  # header

for icon_type, filename in entries:
    data = (iconset / filename).read_bytes()
    chunk = icon_type.encode("ascii") + struct.pack(">I", len(data) + 8) + data
    parts.append(chunk)
    total_length += len(chunk)

with output.open("wb") as f:
    f.write(b"icns")
    f.write(struct.pack(">I", total_length))
    for chunk in parts:
        f.write(chunk)

print(f"Wrote {output}")
PY

echo "Wrote $ICNS"
