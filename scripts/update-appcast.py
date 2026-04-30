#!/usr/bin/env python3
import sys

appcast_path, version, download_url, length, signature, pubdate = sys.argv[1:7]

new_entry = f'''    <item>
      <title>{version}</title>
      <pubDate>{pubdate}</pubDate>
      <sparkle:minimumSystemVersion>13.0</sparkle:minimumSystemVersion>
      <enclosure
        url="{download_url}"
        sparkle:version="{version}"
        sparkle:shortVersionString="{version}"
        sparkle:edSignature="{signature}"
        length="{length}"
        type="application/octet-stream" />
    </item>
'''

with open(appcast_path) as f:
    content = f.read()

marker = '<language>en</language>'
if marker not in content:
    sys.exit(f"marker {marker!r} not found in appcast")
content = content.replace(marker, marker + '\n' + new_entry, 1)

with open(appcast_path, 'w') as f:
    f.write(content)
