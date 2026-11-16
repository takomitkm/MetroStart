// Layout editing: the mutable side of the tile layout.
//
// The config keeps explicit cell coordinates (col/row) so that groups can have
// holes, but a group must never contain a completely empty row and never end
// with one: `normalizeGroup()` removes those rows and shifts the rest up. Tile
// and group ids are added on load; they only exist in memory and give the
// renderer a stable identity to animate between two layouts.
.pragma library
.import "metrics.js" as Metrics
.import "Layout.js" as Layout

function clone(value) {
    return JSON.parse(JSON.stringify(value))
}

function tileCells(tile) {
    return Layout.sizeToCells(tile.size)
}

// ---------------------------------------------------------------------------
// Normalising

function occupancy(tiles) {
    var used = {}
    for (var i = 0; i < tiles.length; ++i) {
        var cells = tileCells(tiles[i])
        for (var r = tiles[i].row; r < tiles[i].row + cells.rows; ++r)
            for (var c = tiles[i].col; c < tiles[i].col + cells.cols; ++c)
                used[r + ":" + c] = true
    }
    return used
}

function hasOverlap(tiles) {
    var used = {}
    for (var i = 0; i < tiles.length; ++i) {
        var cells = tileCells(tiles[i])
        for (var r = tiles[i].row; r < tiles[i].row + cells.rows; ++r)
            for (var c = tiles[i].col; c < tiles[i].col + cells.cols; ++c) {
                if (used[r + ":" + c])
                    return true
                used[r + ":" + c] = true
            }
    }
    return false
}

function maxRowOf(tiles) {
    var maxRow = 0
    for (var i = 0; i < tiles.length; ++i) {
        var cells = tileCells(tiles[i])
        maxRow = Math.max(maxRow, tiles[i].row + cells.rows)
    }
    return maxRow
}

function maxColOf(tiles) {
    var maxCol = 0
    for (var i = 0; i < tiles.length; ++i) {
        var cells = tileCells(tiles[i])
        maxCol = Math.max(maxCol, tiles[i].col + cells.cols)
    }
    return maxCol
}

// Drop every row that no tile touches; the rows below move up. A row that a
// 2x2 tile only clips counts as used (the tile is in it).
function normalizeGroup(group) {
    if (!group.tiles)
        group.tiles = []
    for (;;) {
        var used = occupancy(group.tiles)
        var maxRow = maxRowOf(group.tiles)
        var empty = -1
        for (var r = 0; r < maxRow && empty < 0; ++r) {
            var any = false
            for (var c = 0; c < 16 && !any; ++c)
                any = used[r + ":" + c] === true
            if (!any)
                empty = r
        }
        if (empty < 0)
            return group
        for (var i = 0; i < group.tiles.length; ++i) {
            if (group.tiles[i].row > empty)
                group.tiles[i].row -= 1
        }
    }
}

// Reading order: top row first, then left to right.
function sortReadingOrder(tiles) {
    tiles.sort(function (a, b) {
        return a.row !== b.row ? a.row - b.row : a.col - b.col
    })
    return tiles
}

// ---------------------------------------------------------------------------
// Identity

function prepare(config) {
    var copy = clone(config && config.columns ? config : { columns: [] })
    var groupSeq = 0
    var tileSeq = 0
    for (var c = 0; c < copy.columns.length; ++c) {
        var column = copy.columns[c]
        column.id = "c" + c
        if (!column.groups)
            column.groups = []
        for (var g = 0; g < column.groups.length; ++g) {
            var group = column.groups[g]
            group.id = group.id || ("g" + (groupSeq++))
            if (!group.tiles)
                group.tiles = []
            for (var t = 0; t < group.tiles.length; ++t) {
                var tile = group.tiles[t]
                tile.id = tile.id || ("t" + (tileSeq++))
            }
            normalizeGroup(group)
        }
    }
    return copy
}

// Copy without the in-memory ids: what gets written to layout.json.
function forStorage(config) {
    var copy = clone(config)
    for (var c = 0; c < copy.columns.length; ++c) {
        delete copy.columns[c].id
        var groups = copy.columns[c].groups
        for (var g = 0; g < groups.length; ++g) {
            delete groups[g].id
            for (var t = 0; t < groups[g].tiles.length; ++t)
                delete groups[g].tiles[t].id
        }
    }
    return copy
}

function findTile(config, tileId) {
    for (var c = 0; c < config.columns.length; ++c) {
        var groups = config.columns[c].groups
        for (var g = 0; g < groups.length; ++g) {
            for (var t = 0; t < groups[g].tiles.length; ++t) {
                if (groups[g].tiles[t].id === tileId)
                    return { column: c, group: g, tile: t }
            }
        }
    }
    return null
}

// ---------------------------------------------------------------------------
// Placing tiles

// First cell at or after (startCol, startRow) where a `cols` x `rows` block
// fits (the block never splits across rows).
function firstFit(used, width, cols, rows, startCol, startRow, limitRow) {
    for (var r = startRow; r <= limitRow; ++r) {
        var from = r === startRow ? startCol : 0
        for (var c = from; c + cols <= width; ++c) {
            var fits = true
            for (var rr = r; rr < r + rows && fits; ++rr)
                for (var cc = c; cc < c + cols && fits; ++cc)
                    fits = used[rr + ":" + cc] !== true
            if (fits)
                return { col: c, row: r }
        }
    }
    return null
}

function mark(used, col, row, cols, rows) {
    for (var r = row; r < row + rows; ++r)
        for (var c = col; c < col + cols; ++c)
            used[r + ":" + c] = true
}

// Move a tile inside its group to the cell under the pointer.
//
// Windows keeps the grid absolute: a tile is dropped into the cell it was
// dropped on, holes stay where they are (nothing slides left or up to fill
// them, small tiles do not nestle into the gaps of large ones) and when the
// target is taken the group opens a row underneath the tiles in the way and
// pushes everything below it down. Dropping past the last row appends a row.
function moveTileWithinGroup(config, tileId, col, row) {
    var where = findTile(config, tileId)
    if (where === null)
        return null
    var next = clone(config)
    var group = next.columns[where.column].groups[where.group]
    var tile = null
    for (var i = 0; i < group.tiles.length; ++i) {
        if (group.tiles[i].id === tileId) {
            tile = group.tiles.splice(i, 1)[0]
            break
        }
    }
    if (tile === null)
        return null
    // The tile leaves its cells behind; only rows that became completely empty
    // disappear (a group must not contain an empty row).
    normalizeGroup(group)

    var cells = tileCells(tile)
    var width = Math.max(Metrics.groupMinCells, maxColOf(group.tiles))
    var fromRow = tile.row
    var fromCol = tile.col
    col = Math.max(0, Math.min(col, width - cells.cols))
    row = Math.max(0, Math.min(row, maxRowOf(group.tiles)))

    // Which tile is in the way of this footprint?
    var occupant = null
    for (var k = 0; k < group.tiles.length; ++k) {
        var other = group.tiles[k]
        var size = tileCells(other)
        var overlapX = col < other.col + size.cols && other.col < col + cells.cols
        var overlapY = row < other.row + size.rows && other.row < row + cells.rows
        if (overlapX && overlapY && occupant === null)
            occupant = other
    }

    if (occupant !== null && occupant.row === fromRow) {
        // Same row: swap the two tiles, so the row is reordered left/right and
        // nothing is pushed into another row.
        var oldCol = occupant.col, oldRow = occupant.row
        occupant.col = fromCol
        occupant.row = fromRow
        tile.col = col
        tile.row = row
        group.tiles.push(tile)
        if (!hasOverlap(group.tiles) && maxColOf(group.tiles) <= Math.max(width, 8)) {
            normalizeGroup(group)
            return next
        }
        // does not fit (mixed sizes): take the tile back and open a row below
        occupant.col = oldCol
        occupant.row = oldRow
        group.tiles.splice(group.tiles.indexOf(tile), 1)
    }

    if (occupant !== null) {
        // Different row (or the swap did not fit): open a row right below the
        // tile in the way and push everything below it down.
        var insertRow = occupant.row + tileCells(occupant).rows
        for (var t = 0; t < group.tiles.length; ++t) {
            if (group.tiles[t].row >= insertRow)
                group.tiles[t].row += cells.rows
        }
        row = insertRow
    }

    tile.col = col
    tile.row = row
    group.tiles.push(tile)
    normalizeGroup(group)
    return next
}