"""Run headless integration checks with a Luau CLI (no Roblox client required)."""
import argparse
import subprocess
from pathlib import Path

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--luau', default='luau')
args = parser.parse_args()
sources = ['vendor/Tokyo.lua', 'src/Engine.lua', 'main.lua']
bundle = 'SOURCES = {}\n'
for name in sources:
    text = (root / name).read_text(encoding='utf-8')
    assert ']====]' not in text
    bundle += f'SOURCES["{name}"] = [====[{text}]====]\n'
bundle += (root / 'tests/roblox_mock.luau').read_text(encoding='utf-8')
bundle += (root / 'tests/integration.luau').read_text(encoding='utf-8')
directory = root / '.test-work'
directory.mkdir(exist_ok=True)
script = directory / 'integration.luau'
script.write_text(bundle, encoding='utf-8')
subprocess.run([args.luau, str(script)], check=True)
