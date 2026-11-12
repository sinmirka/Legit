"""Run headless integration checks with a Luau CLI (no Roblox client required)."""
import argparse
import re
import subprocess
from pathlib import Path

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--luau', default='luau')
args = parser.parse_args()
sources = ['src/NativeUI.lua', 'src/Engine.lua', 'src/GuiDrawing.lua', 'main.lua', 'loader.lua', 'loader-xeno.lua', 'Legit.lua']
main = (root / 'main.lua').read_text(encoding='utf-8')
transport = main[main.index('-- BEGIN HTTP TRANSPORT'):main.index('-- END HTTP TRANSPORT')]
assert transport in (root / 'loader.lua').read_text(encoding='utf-8'), 'Rebuild loader.lua with tools/build_loader.py'
assert transport in (root / 'loader-xeno.lua').read_text(encoding='utf-8'), 'Rebuild loader-xeno.lua'
extras = {'HTTP_TRANSPORT': transport + '\nreturn download',
          'README_BOOTSTRAP': re.search(r'```lua\n(.*?)\n```', (root / 'README.md').read_text(encoding='utf-8'), re.S).group(1)}
generated = (root / 'Legit.lua').read_text(encoding='utf-8')
for name in ['src/NativeUI.lua', 'src/Engine.lua', 'src/GuiDrawing.lua', 'main.lua']:
    assert (root / name).read_text(encoding='utf-8') in generated, 'Rebuild Legit.lua with tools/build_bundle.py'
bundle = 'SOURCES = {}\n'
def literal(text):
    equals = '===='
    while ']' + equals + ']' in text:
        equals += '='
    return '[' + equals + '[' + text + ']' + equals + ']'

for name in sources:
    text = (root / name).read_text(encoding='utf-8')
    bundle += f'SOURCES["{name}"] = {literal(text)}\n'
for name, text in extras.items():
    bundle += f'SOURCES["{name}"] = {literal(text)}\n'
bundle += (root / 'tests/roblox_mock.luau').read_text(encoding='utf-8')
directory = root / '.test-work'
directory.mkdir(exist_ok=True)
for name in ['integration', 'native_ui', 'bundle']:
    script = directory / (name + '.luau')
    script.write_text(bundle + (root / 'tests' / (name + '.luau')).read_text(encoding='utf-8'), encoding='utf-8')
    subprocess.run([args.luau, str(script)], check=True)
