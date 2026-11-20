# Tubeist Scorer website

The site is ready for `https://www.uptochange.com/tubeist-scorer/`. It matches the
Tubeist site’s colours and typography and includes the product page, support
and privacy policy. The theme preview uses native radio controls and CSS.

## Upload

Extract `AppStore/Website.zip` into the web server’s `tubeist-scorer/` directory.
Keep `assets/` next to `index.html`, `support.html` and `privacy-policy.html`.
These files need ordinary static HTTPS hosting and standard PNG, WebP, JPEG,
HTML and CSS MIME types. The app works offline for scoring and preview.

Open each URL after upload and check the images, theme controls and support
email link.

| App Store Connect field | URL |
| --- | --- |
| Marketing URL | `https://www.uptochange.com/tubeist-scorer/` |
| Support URL | `https://www.uptochange.com/tubeist-scorer/support.html` |
| Privacy Policy URL | `https://www.uptochange.com/tubeist-scorer/privacy-policy.html` |

Use the same privacy policy URL for the in-app privacy link. Once the Scorer
App Store listing has a public URL, add its link to the product page. If the
hosting path changes, update the canonical and social URLs in all three HTML
files and rebuild the ZIP.

## Assets and local preview

The phone image is a capture of the current Scorer interface on the iPhone
simulator with sample teams and scores. The six scoreboard images come from
Scorer’s WebKit overlay. The social card uses the app icon and those captures.
All assets are included in the ZIP.

From the Scorer repository root, run

```sh
python3 -m http.server 8769 --bind 127.0.0.1 --directory AppStore/Website
```

Open `http://127.0.0.1:8769/` to test local edits.

Rebuild the upload ZIP from the Scorer repository root after editing public files.

```sh
python3 - <<'PY'
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile

website = Path('AppStore/Website')
with ZipFile('AppStore/Website.zip', 'w', ZIP_DEFLATED) as archive:
    for path in sorted(website.rglob('*')):
        if path.is_file() and path.name != 'README.md':
            archive.write(path, path.relative_to(website))
PY
```
