// Headless integration checks with a Luau CLI and Node.js built-ins.
import assert from 'node:assert/strict';
import { mkdirSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { spawnSync } from 'node:child_process';
import { root, read, sources, literal, transport } from '../tools/source_files.mjs';

const options = { '--luau': 'luau' };
for (let i = 2; i < process.argv.length; i += 2) {
  const name = process.argv[i], value = process.argv[i + 1];
  assert(['--luau', '--compiler'].includes(name) && value, 'Usage: node tests/run.mjs [--luau path] [--compiler path]');
  options[name] = value;
}
function run(command, args) {
  const result = spawnSync(command, args, { stdio: 'inherit' });
  if (result.error) throw result.error;
  if (result.status !== 0) process.exit(result.status ?? 1);
}
const runtime = [...sources, 'loader.lua', 'Legit.lua'];
if (options['--compiler']) {
  run(options['--compiler'], ['--null', ...runtime.map(path => resolve(root, path))]);
  console.log(`PASS compilation of ${runtime.length} runtime files, including actual Obsidian`);
}
const http = transport().replace('-- END HTTP TRANSPORT', '');
assert(read('loader.lua').includes(http), 'Rebuild loader.lua with node tools/build.mjs');
const generated = read('Legit.lua');
for (const path of sources) assert(generated.includes(read(path)), `Rebuild Legit.lua: ${path}`);
const bootstrap = read('README.md').match(/```lua\n([\s\S]*?)\n```/);
assert(bootstrap, 'README bootstrap is missing');
const extras = { HTTP_TRANSPORT: http + '\nreturn download', README_BOOTSTRAP: bootstrap[1] };
const bundle = 'SOURCES = {}\n' + runtime.map(path => `SOURCES["${path}"] = ${literal(read(path))}\n`).join('') +
  Object.entries(extras).map(([name, text]) => `SOURCES["${name}"] = ${literal(text)}\n`).join('') +
  read('tests/roblox_mock.luau') + read('tests/obsidian_mock.luau');
const directory = resolve(root, '.test-work');
mkdirSync(directory, { recursive: true });
for (const name of ['integration', 'obsidian_ui', 'bundle', 'melee', 'melee_remotes', 'universal', 'spin',
  'jump_limit', 'diagnostics', 'silent', 'silent_visualize', 'silent_universal', 'silent_autofire', 'silent_cycle', 'objects', 'dealer_stock', 'projectiles', 'toy_tools', 'cleanup', 'wallbang']) {
  const script = resolve(directory, name + '.luau');
  writeFileSync(script, bundle + read(`tests/${name}.luau`), 'utf8');
  run(options['--luau'], [script]);
}
