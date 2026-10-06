#!/usr/bin/env python3
"""Pack generated PNG iconset sizes into an .icns without Icon Services."""

import pathlib
import struct
import sys


source = pathlib.Path(sys.argv[1])
destination = pathlib.Path(sys.argv[2])
entries = (
    ("icp4", "icon_16x16.png"),
    ("icp5", "icon_32x32.png"),
    ("icp6", "icon_32x32@2x.png"),
    ("ic07", "icon_128x128.png"),
    ("ic08", "icon_256x256.png"),
    ("ic09", "icon_512x512.png"),
    ("ic10", "icon_512x512@2x.png"),
)
chunks = []
for kind, filename in entries:
    data = (source / filename).read_bytes()
    if not data.startswith(b"\x89PNG\r\n\x1a\n"):
        raise ValueError(f"Not a PNG: {filename}")
    chunks.append(kind.encode("ascii") + struct.pack(">I", len(data) + 8) + data)

payload = b"".join(chunks)
destination.write_bytes(b"icns" + struct.pack(">I", len(payload) + 8) + payload)
