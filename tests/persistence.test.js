// Tests for the layout persistence path: first-run pinning, load states and
// the save command.
//
// Run with:  node tests/persistence.test.js
//
// The QML JS libraries are loaded verbatim (only `.pragma` / `.import`
// directives are stripped, they are QML-only syntax) into a Node VM context,
// so the tests exercise the real Edit/Layout/Persistence code. The shell
// commands those modules build are executed for real in a temporary directory
// through `sh -c`, which is exactly what Runtime.qml's "executable" data source
// does. No filesystem behaviour is stubbed.
'use strict';

const assert = require('node:assert');
const { spawnSync } = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const vm = require('node:vm');

const UI = path.join(__dirname, '..', 'package', 'contents', 'ui');

function loadLibrary(fileName, context) {
    const source = fs.readFileSync(path.join(UI, fileName), 'utf8')
        .replace(/^\s*\.(?:pragma|import)\b.*$/gm, '');
    vm.runInNewContext(source, context, { filename: fileName });
    return context;
}

const metrics = loadLibrary('metrics.js', { console });
const layout = loadLibrary('Layout.js', { console, Metrics: metrics });
const persistence = loadLibrary('Persistence.js', { console });
const edit = loadLibrary('Edit.js', { console, Metrics: metrics, Layout: layout });

const isRoot = typeof process.getuid === 'function' && process.getuid() === 0;

// ---------------------------------------------------------------------------
// Helpers

const tests = [];
function test(name, fn, options) {
    tests.push({ name, fn, skip: (options && options.skip) || false });
}

function mkTempDir() {
    return fs.mkdtempSync(path.join(os.tmpdir(), 'metrostart-'));
}

function cleanup(dir) {
    // Undo restrictive modes first: rm -rf cannot descend into a 0500 directory.
    for (const name of fs.existsSync(dir) ? fs.readdirSync(dir) : []) {
        try { fs.chmodSync(path.join(dir, name), 0o700); } catch (e) {}
    }
    try { fs.chmodSync(dir, 0o700); } catch (e) {}
    fs.rmSync(dir, { recursive: true, force: true });
}

// What Runtime.qml's executable data source returns for a command.
function exec(command) {
    const r = spawnSync('sh', ['-c', command], { encoding: 'utf8' });
    return { 'exit code': r.status === null ? -1 : r.status,
             stdout: r.stdout || '', stderr: r.stderr || '' };
}

function loadFile(p) {
    return persistence.parseLoad(exec(persistence.loadCommand(p)), p);
}

function saveFile(p, text) {
    return persistence.parseSave(exec(persistence.saveCommand(p, text)));
}

// The pin sequence MetroMenu performs: pick the base layout, add the tile,
// serialise it through Edit.forStorage and write it.
function pin(state, config, appId, target) {
    const empty = edit.prepare(persistence.emptyLayout());
    const base = persistence.pinBase(config, state, empty);
    if (base === null)
        return { config: null, saved: false, error: 'pin refused' };
    const next = edit.addTile(base, appId, '2x2');
    if (next === null)
        return { config: null, saved: false, error: 'addTile failed' };
    const text = JSON.stringify(edit.forStorage(next), null, 1);
    const result = saveFile(target, text);
    return { config: next, text, saved: result.ok, error: result.error };
}

function tilesOf(config) {
    const out = [];
    for (const column of config.columns)
        for (const group of column.groups)
            for (const tile of group.tiles)
                out.push({ app: tile.app, col: tile.col, row: tile.row, size: tile.size });
    return out;
}

// ---------------------------------------------------------------------------
// 1. First launch, no configuration directory at all

test('first launch without a configuration directory reports "missing"', () => {
    const dir = mkTempDir();
    try {
        const file = path.join(dir, 'metrostart', 'layout.json');
        assert.equal(fs.existsSync(path.dirname(file)), false);
        const result = loadFile(file);
        assert.equal(result.state, persistence.missing);
        assert.equal(result.config, null);
        assert.equal(result.error, '');
    } finally { cleanup(dir); }
});

// ---------------------------------------------------------------------------
// 2. First launch, the directory exists but is empty

test('first launch with an empty configuration directory reports "missing"', () => {
    const dir = mkTempDir();
    try {
        const file = path.join(dir, 'metrostart', 'layout.json');
        fs.mkdirSync(path.dirname(file), { recursive: true });
        assert.deepEqual(fs.readdirSync(path.dirname(file)), []);
        const result = loadFile(file);
        assert.equal(result.state, persistence.missing);
    } finally { cleanup(dir); }
});

// ---------------------------------------------------------------------------
// 3. The first pin creates the first column and group

test('first pin creates the first column and group', () => {
    const dir = mkTempDir();
    try {
        const file = path.join(dir, 'metrostart', 'layout.json');
        const r = pin(persistence.missing, null, 'org.kde.dolphin.desktop', file);
        assert.equal(r.saved, true);
        assert.equal(r.config.columns.length, 1);
        assert.equal(r.config.columns[0].groups.length, 1);
        assert.equal(r.config.columns[0].groups[0].tiles.length, 1);
        assert.equal(r.config.columns[0].groups[0].tiles[0].app, 'org.kde.dolphin.desktop');
        assert.equal(fs.existsSync(file), true);
        // The directory had to be created by the save command.
        assert.equal(fs.existsSync(path.dirname(file)), true);
    } finally { cleanup(dir); }
});

// ---------------------------------------------------------------------------
// 4. A pin keeps the tiles that are already there

test('pin preserves existing tiles', () => {
    const dir = mkTempDir();
    try {
        const file = path.join(dir, 'metrostart', 'layout.json');
        const existing = edit.prepare({ version: 2, columns: [{ groups: [{
            title: '', tiles: [{ app: 'a.desktop', size: '2x2', col: 0, row: 0 }]
        }] }] });
        const r = pin(persistence.loaded, existing, 'b.desktop', file);
        assert.equal(r.saved, true);
        const tiles = tilesOf(r.config);
        assert.equal(tiles.length, 2);
        assert.deepEqual(tiles.map(t => t.app).sort(), ['a.desktop', 'b.desktop']);
    } finally { cleanup(dir); }
});

// ---------------------------------------------------------------------------
// 5. Pin is refused while the layout is still loading

test('pin is blocked while the configuration is loading', () => {
    const empty = edit.prepare(persistence.emptyLayout());
    assert.equal(persistence.pinBase(null, persistence.loading, empty), null);
    assert.equal(persistence.isEditable(persistence.loading), false);
    const refused = pin(persistence.loading, null, 'a.desktop', '/nonexistent/layout.json');
    assert.equal(refused.config, null);
    assert.equal(refused.saved, false);
});

// ---------------------------------------------------------------------------
// 6. A malformed layout file is an error, not a first run

test('malformed JSON does not seed an empty layout', () => {
    const dir = mkTempDir();
    try {
        const file = path.join(dir, 'layout.json');
        fs.writeFileSync(file, '{ "columns": [ { "groups": [ } ] }');
        const result = loadFile(file);
        assert.equal(result.state, persistence.error);
        assert.equal(result.config, null);
        assert.match(result.error, /cannot parse|empty/);
        // The refused pin must not replace the (possibly salvageable) file.
        const refused = pin(result.state, result.config, 'a.desktop', file);
        assert.equal(refused.config, null);
        assert.equal(fs.readFileSync(file, 'utf8'), '{ "columns": [ { "groups": [ } ] }');
    } finally { cleanup(dir); }
});

// ---------------------------------------------------------------------------
// 7. An unreadable layout file is an error, not a first run

test('read permission errors do not seed an empty layout',
     () => {
         const dir = mkTempDir();
         try {
             const file = path.join(dir, 'layout.json');
             fs.writeFileSync(file, JSON.stringify({ version: 2, columns: [] }));
             fs.chmodSync(file, 0o000);
             const result = loadFile(file);
             assert.notEqual(result.state, persistence.missing,
                             'an unreadable file must not look like a first run');
             assert.notEqual(result.state, persistence.loaded);
             assert.equal(result.state, persistence.error);
             assert.equal(persistence.pinBase(null, result.state, {}), null);
         } finally { cleanup(dir); }
     }, { skip: isRoot });

// ---------------------------------------------------------------------------
// 8. Save creates the parent directory

test('save creates the parent directory', () => {
    const dir = mkTempDir();
    try {
        const file = path.join(dir, 'nested', 'deeper', 'layout.json');
        const ok = saveFile(file, '{ "version": 2, "columns": [] }');
        assert.equal(ok.ok, true, ok.error);
        assert.equal(fs.existsSync(file), true);
        assert.match(fs.readFileSync(file, 'utf8'), /"version": 2/);
        assert.equal(fs.existsSync(file + '.tmp'), false, 'the temporary file must be gone');
    } finally { cleanup(dir); }
});

// ---------------------------------------------------------------------------
// 9. A failed write is reported and leaves the previous layout alone

test('save failure is reported and keeps the previous layout',
     () => {
         const dir = mkTempDir();
         try {
             const file = path.join(dir, 'layout.json');
             const original = '{ "version": 2, "columns": [] }';
             fs.writeFileSync(file, original);
             fs.chmodSync(dir, 0o500);       // read + execute, no write
             const result = saveFile(file, '{ "version": 2, "columns": [ 1 ] }');
             assert.equal(result.ok, false);
             assert.notEqual(result.error, '');
             assert.equal(fs.readFileSync(file, 'utf8'), original,
                          'a failed write must not replace the existing layout');
         } finally { cleanup(dir); }
     }, { skip: isRoot });

// ---------------------------------------------------------------------------
// 10. Two pins keep both applications, at separate cells

test('two consecutive pins keep both applications', () => {
    const dir = mkTempDir();
    try {
        const file = path.join(dir, 'metrostart', 'layout.json');
        const first = pin(persistence.missing, null, 'a.desktop', file);
        assert.equal(first.saved, true);
        const reloaded = loadFile(file);
        assert.equal(reloaded.state, persistence.loaded);
        const second = pin(persistence.loaded, reloaded.config, 'b.desktop', file);
        assert.equal(second.saved, true);
        const tiles = tilesOf(second.config);
        assert.equal(tiles.length, 2);
        assert.deepEqual(tiles.map(t => t.app).sort(), ['a.desktop', 'b.desktop']);
        // Explicit cells: without them the resolver would place both at (0,0).
        for (const tile of tiles) {
            assert.equal(typeof tile.col, 'number');
            assert.equal(typeof tile.row, 'number');
        }
        const cells = tiles.map(t => t.col + ':' + t.row);
        assert.equal(new Set(cells).size, 2, 'pinned tiles must not share a cell');
    } finally { cleanup(dir); }
});

// ---------------------------------------------------------------------------
// 11. The saved file can be loaded again (a restart)

test('saved configuration can be loaded again after a restart', () => {
    const dir = mkTempDir();
    try {
        const file = path.join(dir, 'metrostart', 'layout.json');
        const r = pin(persistence.missing, null, 'org.kde.dolphin.desktop', file);
        assert.equal(r.saved, true);

        // Restart: read the file back exactly like Runtime.loadConfig does.
        const loaded = loadFile(file);
        assert.equal(loaded.state, persistence.loaded);
        assert.equal(loaded.config.version, 2);
        // prepare() adds the ids the renderer needs, and the tile survives.
        const prepared = edit.prepare(loaded.config);
        const tiles = tilesOf(prepared);
        assert.equal(tiles.length, 1);
        assert.equal(tiles[0].app, 'org.kde.dolphin.desktop');
        assert.equal(tiles[0].size, '2x2');
        // Round trip through storage must be stable.
        const again = JSON.parse(JSON.stringify(edit.forStorage(prepared)));
        assert.deepEqual(again, JSON.parse(JSON.stringify(loaded.config)));
    } finally { cleanup(dir); }
});

// ---------------------------------------------------------------------------
// Paths are shell-quoted (the layout lives under the user's home, which may
// contain spaces or quotes)

test('paths with spaces and quotes survive save and load', () => {
    const dir = mkTempDir();
    try {
        const file = path.join(dir, "it's a dir", 'layout.json');
        const text = JSON.stringify({ version: 2, columns: [] });
        const saved = saveFile(file, text);
        assert.equal(saved.ok, true, saved.error);
        // The heredoc adds one trailing newline, the JSON itself is unchanged.
        assert.equal(fs.readFileSync(file, 'utf8'), text + '\n');
        const loaded = loadFile(file);
        assert.equal(loaded.state, persistence.loaded);
        assert.deepEqual(loaded.config, { version: 2, columns: [] });
    } finally { cleanup(dir); }
});

// ---------------------------------------------------------------------------
// The entry menu only offers a usable pin

test('the pin entry is disabled unless the layout is editable', () => {
    assert.equal(persistence.isEditable(persistence.loading), false);
    assert.equal(persistence.isEditable(persistence.error), false);
    assert.equal(persistence.isEditable(persistence.missing), true);
    assert.equal(persistence.isEditable(persistence.loaded), true);
});

// ---------------------------------------------------------------------------

let passed = 0;
let failed = 0;
let skipped = 0;
for (const t of tests) {
    if (t.skip) {
        skipped += 1;
        console.log(`SKIP  ${t.name}  (read-only tests need a non-root user)`);
        continue;
    }
    try {
        t.fn();
        passed += 1;
        console.log(`PASS  ${t.name}`);
    } catch (e) {
        failed += 1;
        console.log(`FAIL  ${t.name}`);
        console.log('      ' + String(e.message).split('\n').join('\n      '));
    }
}
console.log(`\n${passed} passed, ${failed} failed` + (skipped ? `, ${skipped} skipped` : ''));
process.exit(failed === 0 ? 0 : 1);
