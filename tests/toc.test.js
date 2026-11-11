'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const addon = path.join(__dirname, '..', 'addons', 'BanzaiSland');

function readToc(name) {
  const fields = {};
  const files = [];
  for (const raw of fs.readFileSync(path.join(addon, name), 'utf8').split(/\r?\n/)) {
    const line = raw.trim();
    const metadata = line.match(/^##\s*([^:]+):\s*(.*)$/);
    if (metadata) fields[metadata[1]] = metadata[2];
    else if (line && !line.startsWith('#')) files.push(line);
  }
  return { fields, files };
}

test('the selected Mainline TOC and fallback support Retail and Forever', () => {
  const mainline = readToc('BanzaiSland_Mainline.toc');
  const fallback = readToc('BanzaiSland.toc');
  for (const toc of [mainline, fallback]) {
    assert.deepEqual(toc.fields.Interface.split(',').map(s => Number(s.trim())).sort(),
      [120105, 16001]);
    assert.equal(toc.fields.Version, '1.0.1');
    assert.equal(toc.fields['X-Curse-Project-ID'], '1793377');
    assert.equal(toc.fields['X-Wago-ID'], 'QN5JMd6B');
    assert.equal(toc.fields.Dependencies, undefined);
    assert.equal(toc.fields.RequiredDeps, undefined);
    assert.equal(toc.fields.AllowLoadGameType, undefined);
    assert.equal(toc.fields.ExcludeLoadGameType, undefined);
    assert.equal(toc.fields.SavedVariables, 'BanzaiSlandDB');
    assert.equal(toc.fields.SavedVariablesPerCharacter, 'BanzaiSlandCharDB');
    for (const file of toc.files) {
      assert.ok(fs.statSync(path.join(addon, file)).isFile(), `missing TOC entry: ${file}`);
    }
  }
  assert.deepEqual(mainline.files, fallback.files);
  assert.ok(mainline.files.includes('FontBakeoff.lua'));
});
