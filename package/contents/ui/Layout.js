// Tile layout: a JSON description is turned into absolute pixel geometry.
//
// Config format (see README). The user defines the columns and which groups
// they hold; no group carries a position.
//   { "version": 2,
//     "columns": [
//       { "groups": [ { "title": "",
//                       "tiles": [ { "app": "org.kde.dolphin.desktop", "size": "2x2" },
//                                  { "label": "KiCad", "icon": "/path/kicad.png",
//                                    "exec": "kicad", "size": "2x2", "col": 0, "row": 2 } ] } ] },
//       { "groups": [ ... ] } ] }
//
// Tiles are packed left to right, top to bottom inside a group; `col`/`row`
// pin a tile to an explicit cell (used by the reference layouts). A group is as
// wide as its tiles, but never narrower than three 2x2 tiles (Metrics.
// groupMinCells cells). A column is as wide as its widest group and the other
// groups of the column keep the left edge; the columns stand side by side with
// a fixed gap, are centred in the fixed canvas width and stack their groups
// downwards without a height limit (the tile area scrolls instead).
//
// Older files keep a flat "groups" list with an `x` (or a `column` index) per
// group; `configColumns()` groups those so the arrangement does not change.
.pragma library
.import "metrics.js" as Metrics

function sizeToCells(size) {
    switch (size) {
    case "1x1": return { cols: 1, rows: 1 }
    case "4x2": return { cols: 4, rows: 2 }
    case "4x4": return { cols: 4, rows: 4 }
    case "2x2":
    default:    return { cols: 2, rows: 2 }
    }
}

function pixelWidth(cols) {
    return cols * Metrics.cell + (cols - 1) * Metrics.gap
}

function pixelHeight(rows) {
    return rows * Metrics.cell + (rows - 1) * Metrics.gap
}

function findApp(apps, id) {
    for (var i = 0; i < apps.length; ++i) {
        if (apps[i].id === id)
            return apps[i]
    }
    return null
}

function newGrid() {
    return { used: {}, maxRow: 0, maxCol: 0 }
}

function isFree(grid, col, row, cols, rows) {
    for (var r = row; r < row + rows; ++r) {
        for (var c = col; c < col + cols; ++c) {
            if (grid.used[r + ":" + c])
                return false
        }
    }
    return true
}

function occupy(grid, col, row, cols, rows) {
    for (var r = row; r < row + rows; ++r) {
        for (var c = col; c < col + cols; ++c)
            grid.used[r + ":" + c] = true
    }
    if (row + rows > grid.maxRow)
        grid.maxRow = row + rows
    if (col + cols > grid.maxCol)
        grid.maxCol = col + cols
}

function firstFree(grid, cols, rows) {
    for (var row = 0; row < 64; ++row) {
        for (var col = 0; col + cols <= Metrics.groupMinCells; ++col) {
            if (isFree(grid, col, row, cols, rows))
                return { col: col, row: row }
        }
    }
    return { col: 0, row: 0 }
}

// Resolve one tile description into a positioned tile, relative to its group.
function resolveTile(tile, apps, grid) {
    var size = sizeToCells(tile.size)
    var pos
    if (tile.col !== undefined && tile.row !== undefined) {
        pos = { col: tile.col, row: tile.row }
    } else {
        pos = firstFree(grid, size.cols, size.rows)
    }
    occupy(grid, pos.col, pos.row, size.cols, size.rows)

    var app = tile.app ? findApp(apps, tile.app) : null
    return {
        // identity for the renderer (see Edit.js)
        id: tile.id || "",
        size: tile.size || "2x2",
        x: pos.col * Metrics.pitch,
        y: pos.row * Metrics.pitch,
        w: pixelWidth(size.cols),
        h: pixelHeight(size.rows),
        label: tile.label !== undefined ? tile.label : (app ? app.name : ""),
        icon: tile.icon !== undefined ? tile.icon : (app ? app.icon : ""),
        exec: tile.exec !== undefined ? tile.exec : (app ? app.exec : ""),
        desktopId: app ? app.id : "",
        // path of the .desktop file, needed to launch it reliably
        desktopPath: app ? (app.path || "") : "",
        iconRect: tile.iconRect ? { x: tile.iconRect[0], y: tile.iconRect[1],
                                    w: tile.iconRect[2], h: tile.iconRect[3] } : null
    }
}

// ---------------------------------------------------------------------------
// Group flow
//
// The arrangement is groups -> columns -> screen: the columns and the order of
// the groups inside them belong to the user (they are dragged into place), so
// nothing is redistributed. The layout only
//   * measures every group (tiles + title block),
//   * makes a column as wide as its widest group and left-aligns the others,
//   * stacks the groups of a column tightly, one fixed gap below the previous
//     group's tiles,
//   * puts the columns side by side with a fixed gap and centres them, and
//   * lets the tile area grow downwards without a limit.

// The tiles of one group, measured: the group is as wide as the furthest cell
// its tiles reach, but at least three 2x2 tiles wide.
function measureGroup(group, apps) {
    var grid = newGrid()
    var tiles = []
    for (var i = 0; i < group.tiles.length; ++i) {
        var spec = group.tiles[i]
        // an entry that names an unknown application is skipped
        if (spec.app && !findApp(apps, spec.app))
            continue
        tiles.push(resolveTile(spec, apps, grid))
    }
    return {
        id: group.id || "",
        title: group.title || "",
        placeholder: group.placeholder === true,
        tiles: tiles,
        w: pixelWidth(Math.max(grid.maxCol, Metrics.groupMinCells)),
        h: grid.maxRow > 0 ? pixelHeight(grid.maxRow) : 0
    }
}

// The columns of the config: an array of group lists.
//
// Current format:  { "columns": [ { "groups": [ ... ] }, ... ] }
// Older files keep a flat "groups" list and pin every group with an x position
// (or a column index); those are grouped here so they keep their arrangement.
function configColumns(config) {
    var columns = []
    if (!config)
        return columns
    if (config.columns && config.columns.length !== undefined) {
        for (var c = 0; c < config.columns.length; ++c) {
            var column = config.columns[c]
            columns.push(column && column.groups ? column.groups : [])
        }
        return columns
    }
    var groups = config.groups || []
    var keys = []
    var byKey = {}
    for (var g = 0; g < groups.length; ++g) {
        var group = groups[g]
        var key = group.column
        if (key === undefined)
            key = group.x !== undefined ? group.x : 0
        key = String(key)
        if (!byKey[key]) {
            byKey[key] = []
            keys.push(key)
        }
        byKey[key].push(group)
    }
    // x positions and column indices both sort numerically
    keys.sort(function (a, b) { return parseFloat(a) - parseFloat(b) })
    for (var k = 0; k < keys.length; ++k)
        columns.push(byKey[keys[k]])
    return columns
}

// Resolve the whole layout. `canvas` is the fixed tile area: the columns are
// centred in its width, while the height only grows with the content.
function resolve(config, apps, canvas) {
    var result = { groups: [], columns: [], columnsCount: 0, width: 0, height: 0,
                   contentHeight: 0, left: 0, top: Metrics.groupsTop,
                   headerHeight: Metrics.groupHeader, bottomPadding: Metrics.groupsBottom,
                   gapX: Metrics.groupGapX, gapY: Metrics.groupGapY }
    var source = configColumns(config)
    if (source.length === 0)
        return result

    var canvasWidth = (canvas && canvas.width > 0) ? canvas.width : 2560
    var allApps = apps || []

    // Measure every column: its width is the widest group in it.
    var columns = []
    for (var c = 0; c < source.length; ++c) {
        var measured = []
        var width = 0
        for (var g = 0; g < source[c].length; ++g) {
            var group = measureGroup(source[c][g], allApps)
            measured.push(group)
            if (group.w > width)
                width = group.w
        }
        if (measured.length > 0)
            columns.push({ width: width, groups: measured })
    }
    if (columns.length === 0)
        return result
    result.columnsCount = columns.length

    result.width = Metrics.groupGapX * (columns.length - 1)
    for (var i = 0; i < columns.length; ++i)
        result.width += columns[i].width
    result.left = Math.round((canvasWidth - result.width) / 2)

    var x = result.left
    for (var col = 0; col < columns.length; ++col) {
        var columnWidth = columns[col].width
        var groups = columns[col].groups
        result.columns.push({ x: x, width: columnWidth, groups: groups.length })
        // The title block belongs to the group, so the box starts one block
        // above the first tile row even when the group has no title.
        var boxY = Metrics.groupsTop - Metrics.groupHeader
        for (var k = 0; k < groups.length; ++k) {
            var item = groups[k]
            var tileY = boxY + Metrics.groupHeader
            for (var t = 0; t < item.tiles.length; ++t) {
                item.tiles[t].x += x
                item.tiles[t].y += tileY
            }
            result.groups.push({
                id: item.id || "",
                title: item.title,
                placeholder: item.placeholder === true,
                tiles: item.tiles,
                // left aligned in the column, as the reference does
                x: x, y: tileY, w: item.w, h: item.h,
                boxY: boxY, boxW: item.w, boxH: Metrics.groupHeader + item.h,
                // where it lives: result.groups is in placement order, so the
                // drag code can map a box back to its column and row
                column: col, index: k
            })
            if (tileY + item.h > result.height)
                result.height = tileY + item.h
            boxY += item.h + Metrics.groupGapY
        }
        x += columnWidth + Metrics.groupGapX
    }
    // The scrollable content is the tiles plus the tail below the last group.
    result.contentHeight = result.height + Metrics.groupsBottom
    return result
}

// ---------------------------------------------------------------------------
// "All applications": three columns of entries grouped by first letter.
var appTop = 48
var appRowPitch = 66
var appSectionGap = 48
var appColumns = 3

function letterOf(name) {
    var c = name.length > 0 ? name.charAt(0).toUpperCase() : "#"
    return /[A-Z]/.test(c) ? c : "#"
}

function appSections(apps) {
    var sorted = apps.slice(0)
    sorted.sort(function (a, b) { return a.name.localeCompare(b.name) })
    var order = []
    var byLetter = {}
    for (var i = 0; i < sorted.length; ++i) {
        var letter = letterOf(sorted[i].name)
        if (!byLetter[letter]) {
            byLetter[letter] = []
            order.push(letter)
        }
        byLetter[letter].push(sorted[i])
    }
    order.sort()
    var cursor = appTop
    var sections = []
    for (var j = 0; j < order.length; ++j) {
        var entries = byLetter[order[j]]
        var rows = Math.ceil(entries.length / appColumns)
        var placed = []
        for (var k = 0; k < entries.length; ++k) {
            placed.push({
                name: entries[k].name,
                icon: entries[k].icon,
                path: entries[k].path,
                desktopId: entries[k].id,
                col: Math.floor(k / rows),
                row: k % rows
            })
        }
        sections.push({ letter: order[j], y: cursor, entries: placed })
        cursor += rows * appRowPitch + appSectionGap
    }
    return sections
}