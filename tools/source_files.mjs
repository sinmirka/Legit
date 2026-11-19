import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { resolve } from 'node:path';

export const root = fileURLToPath(new URL('../', import.meta.url));
export const read = path => readFileSync(resolve(root, path), 'utf8').replace(/\r\n/g, '\n');
export const sources = [
  'vendor/Obsidian/Lucide.lua', 'vendor/Obsidian/Library.lua', 'src/ObsidianUI.lua',
  'src/Engine.lua', 'src/GuiDrawing.lua', 'src/MeleeAura.lua', 'src/SilentAim.lua',
  'src/UniversalTools.lua', 'src/ObjectESP.lua', 'src/Diagnostics.lua', 'main.lua',
];
export function literal(text) {
  let equals = '====';
  while (text.includes(`]${equals}]`)) equals += '=';
  return `[${equals}[${text}]${equals}]`;
}
export function transport() {
  const main = read('main.lua');
  return main.slice(main.indexOf('-- BEGIN HTTP TRANSPORT'),
    main.indexOf('-- END HTTP TRANSPORT') + '-- END HTTP TRANSPORT'.length);
}
