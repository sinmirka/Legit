"""Download PNGs and Markdown-linked PNG previews. Python 3.9+, no dependencies."""

import argparse
from concurrent.futures import ThreadPoolExecutor
from hashlib import sha256
from html import escape, unescape
from io import BytesIO
import json
from pathlib import Path, PurePosixPath
import re
import sys
from urllib.parse import quote, urlsplit
from urllib.request import Request, urlopen
from zipfile import ZipFile

REPOSITORY = "GhostDuckyy/UI-Libraries"
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"


def fetch(url, timeout):
    request = Request(url, headers={"User-Agent": "UI-Preview-Downloader/1.0"})
    with urlopen(request, timeout=timeout) as response:
        return response.read()


def save_png(root, relative, data):
    if not data.startswith(PNG_SIGNATURE):
        raise ValueError("Response is not a PNG image")
    target = (root / relative).resolve()
    if root not in target.parents:
        raise ValueError("Image path escapes output directory")
    target.parent.mkdir(parents=True, exist_ok=True)
    temporary = target.with_suffix(target.suffix + ".part")
    temporary.write_bytes(data)
    temporary.replace(target)


def collect(archive, output):
    """Save repository PNGs and discover external PNG URLs in Markdown files."""
    saved, external = [], {}
    for member in archive.infolist():
        parts = PurePosixPath(member.filename).parts[1:]
        if not parts or member.is_dir():
            continue
        relative = PurePosixPath(*parts)
        if ".." in parts or "\\" in str(relative) or ":" in str(relative):
            raise ValueError(f"Unsafe archive path: {relative}")
        if relative.suffix.lower() == ".png":
            save_png(output, relative, archive.read(member))
            saved.append(relative.as_posix())
        elif relative.suffix.lower() == ".md":
            markdown = archive.read(member).decode("utf-8", errors="replace")
            for match in re.finditer(r'https?://[^\s<>"\)\]]+', markdown):
                url = unescape(match.group()).rstrip("'.,;")
                if not urlsplit(url).path.lower().endswith(".png"):
                    continue
                key = (relative.parent.as_posix(), url)
                # Keep identical image.png names distinct and stable across runs.
                digest = sha256(url.encode()).hexdigest()[:16]
                external[key] = (relative.parent / "linked-previews" / f"{digest}.png").as_posix()
    return saved, external


def write_gallery(output, saved, failures):
    cards = []
    for name in sorted(set(saved), key=str.casefold):
        url = quote(name, safe="/")
        cards.append(f'<figure><a href="{url}"><img loading="lazy" src="{url}" '
                     f'alt="{escape(name, quote=True)}"></a><figcaption>{escape(name)}</figcaption></figure>')
    errors = "".join(f'<li>{escape(item["folder"])}: <a href="{escape(item["url"], quote=True)}">'
                     f'{escape(item["url"])}</a> — {escape(item["error"])}</li>' for item in failures)
    page = '''<!doctype html><html lang="ru"><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>UI Libraries — PNG</title><style>
body{margin:24px;background:#181a20;color:#eee;font:16px system-ui}
main{display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,380px),1fr));gap:20px}
figure{margin:0;padding:16px;background:#242731;border-radius:12px}
img{width:100%;height:300px;object-fit:contain}figcaption{overflow-wrap:anywhere;margin-top:12px}
a{color:#9cc6ff}li{overflow-wrap:anywhere;margin:12px 0}</style>
'''
    page += f'<h1>UI Libraries — {len(set(saved))} PNG</h1><p>Нажми на картинку, чтобы открыть оригинал.</p>'
    page += '<main>' + "\n".join(cards) + '</main>'
    if failures:
        page += f'<h2>Не удалось скачать: {len(failures)}</h2><ul>{errors}</ul>'
    (output / "index.html").write_text(page + '</html>', encoding="utf-8")
    (output / "failed-downloads.json").write_text(
        json.dumps(failures, ensure_ascii=False, indent=2), encoding="utf-8")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=Path("ui-previews"))
    parser.add_argument("--local-only", action="store_true", help="Skip external Markdown links")
    parser.add_argument("--timeout", type=float, default=15, help="Network timeout in seconds")
    args = parser.parse_args()
    if args.timeout <= 0:
        parser.error("--timeout must be positive")
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    print(f"Downloading {REPOSITORY} archive...", flush=True)
    data = fetch(f"https://codeload.github.com/{REPOSITORY}/zip/refs/heads/main", max(60, args.timeout))
    with ZipFile(BytesIO(data)) as archive:
        saved, external = collect(archive, output)
    print(f"Repository PNGs: {len(saved)}; linked PNGs: {len(external)}", flush=True)
    failures = []

    def download(item):
        (folder, url), relative = item
        try:
            save_png(output, relative, fetch(url, args.timeout))
            return relative, None
        except (OSError, ValueError) as error:
            return None, {"folder": folder, "url": url, "error": str(error)}

    if not args.local_only:
        with ThreadPoolExecutor(max_workers=8) as pool:
            for index, (relative, error) in enumerate(pool.map(download, external.items()), 1):
                if error:
                    failures.append(error)
                else:
                    saved.append(relative)
                print(f"[{index}/{len(external)}] {'FAILED: ' + error['folder'] if error else relative}", flush=True)
    write_gallery(output, saved, failures)
    print(f"Saved: {len(saved)} PNG; failed: {len(failures)}")
    print(f"Gallery: {output / 'index.html'}")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError) as error:
        print(f"Download failed: {error}", file=sys.stderr)
        sys.exit(1)
