"""Remove unlisted pages from the built site's sitemap.xml.

A page is unlisted when its front matter sets `robots: noindex...`; the
template override in overrides/main.html then writes <meta name="robots">.
Such pages are reachable only by a direct link, so they must not be listed
in sitemap.xml either. Usage: python eng/docs/remove-unlisted-from-sitemap.py site
"""

import pathlib
import re
import sys

site = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "site")
sitemap = site / "sitemap.xml"
text = sitemap.read_text(encoding="utf-8")

unlisted = []
for page in site.rglob("index.html"):
    html = page.read_text(encoding="utf-8")
    if re.search(r'<meta name="robots" content="[^"]*noindex', html):
        unlisted.append(page.parent.relative_to(site).as_posix() + "/")

removed = 0
for path in unlisted:
    pattern = re.compile(r"\s*<url>\s*<loc>[^<]*/" + re.escape(path) + r"</loc>.*?</url>", re.S)
    text, count = pattern.subn("", text)
    removed += count

sitemap.write_text(text, encoding="utf-8")
print(f"Unlisted pages: {', '.join(unlisted) or 'none'}; removed from sitemap: {removed}")
if removed != len(unlisted):
    sys.exit("Not every unlisted page was found in sitemap.xml")
