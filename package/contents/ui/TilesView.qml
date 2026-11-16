// The pinned tiles: groups of tiles, optionally with editable group titles.
//
// The tile area renders from two ListModels (tiles and group titles) that are
// updated in place from the resolved layout, so a tile keeps its item while it
// moves and its position change can be animated (see Edit.js for the editing
// side).
import QtQuick
import "metrics.js" as Metrics
import "motion.js" as Motion

Item {
    id: root
    property var groups: []
    property bool titlesVisible: false
    property real pointerX: -1
    property real pointerY: -1
    property bool pointerInside: false
    property int debugHoverTile: -1
    property bool hoverInjected: false
    // Tile entrance timeline: 0 = not started, 1 = tiles in place. Rows enter
    // from the bottom up, so the delay grows towards the top of the menu.
    property real entrance: 1
    property real entranceStagger: 0.35   // share of the timeline used for the stagger

    // Delay rank of each tile: 0 = starts first, 1 = starts last.
    // The reference sweeps up from the bottom-left (where the Start button is),
    // so the default is the distance from that corner.
    property string entranceOrigin: "bottomLeft"
    // Every tile scales about the same point (the menu centre); rows only
    // differ in *when* they animate, which produces the bottom-up reveal.
    property real entranceScaleFrom: 0.80
    // Optional: let the amplitude depend on the row (rank 0 = bottom row).
    // A negative slope means the upper rows travel less than the lower ones.
    property real entranceScaleSlope: 0.0
    // Tiles fade in a little ahead of (or behind) their scale, so the rows can
    // be visible while they are still growing.
    property real entranceOpacityLead: 1.0
    // Small floor so a row that has not started yet is still faintly visible
    // (the reference never lets the upper rows vanish completely).
    // The floor can grow with the row rank, so the upper rows stay visible
    // longer while they wait for their turn.
    property real entranceOpacityFloor: 0.0
    property real entranceOpacityFloorSlope: 0.0
    // Each row animates inside its own window, so the rows also *finish* at
    // different times instead of all stopping together.
    property real entranceRowWindow: 0.55
    property real entranceCurve: 5      // ease-out power
    property real entranceCentreX: 1280
    property real entranceCentreY: 690
    // Harness overrides: -1 keeps the animated value.
    property real debugTileScale: -1
    property real debugTileOpacity: -1
    property real debugTileRise: -1

    // Switch entrance (tiles <-> all applications): every row is pushed up from
    // below while it fades in, the top rows leading. See motion.js.
    property real switchProgress: 1

    // Scrolling. The tile area has a fixed width but grows downwards with the
    // groups (Layout.js); whatever does not fit is scrolled. The list uses a
    // Flickable for the same job, which is also the path that reliably receives
    // wheel events here (a WheelHandler did not), so the tiles get one too.
    property real contentHeight: 0
    readonly property real scrollY: flick.contentY
    readonly property real maxScroll: Math.max(0, Math.max(contentHeight, height) - height)
    function scrollTo(y) {
        flick.contentY = Math.max(0, Math.min(maxScroll, y))
    }
    // Back to the top, used when the menu is reopened (see MetroMenu.reset).
    function resetScroll() {
        flick.contentY = 0
    }

    // --- drag (M2: a tile inside its own group) ----------------------------
    property bool dragging: false
    property string dragTileId: ""
    property var dragTileData: null
    property real dragX: 0            // pointer, in this item's coordinates
    property real dragY: 0
    property real dragGrabX: 0        // pointer offset inside the dragged tile
    property real dragGrabY: 0
    property real dragWidth: 0
    property real dragHeight: 0
    // Where the dragged tile's top left corner is: the drop cell follows the
    // tile, not the pointer (the pointer keeps the grab offset inside it).
    readonly property real dragLeftX: dragX - dragGrabX
    readonly property real dragLeftY: dragY - dragGrabY
    property bool dragAborted: false
    // Insertion line from the menu: { x, y, w, h } in content coordinates.
    property var dropLine: null
    signal tileDragStarted(string tileId, real px, real py)
    signal tileDragMoved(string tileId, real px, real py)
    signal tileDragFinished(string tileId, real px, real py)
    signal tileDragCanceled(string tileId)

    function startTileDrag(tileId, data, px, py, originX, originY, w, h) {
        root.dragTileId = tileId
        root.dragTileData = data
        root.dragGrabX = px - originX
        root.dragGrabY = py - originY
        root.dragWidth = w
        root.dragHeight = h
        root.dragX = px
        root.dragY = py
        root.dragAborted = false
        root.dragging = true
        flick.interactive = false
        root.tileDragStarted(tileId, px, py)
    }

    function moveTileDrag(px, py) {
        if (!root.dragging)
            return
        root.dragX = px
        root.dragY = py
        root.tileDragMoved(root.dragTileId, px, py)
    }

    function endTileDrag(px, py) {
        if (!root.dragging && !root.dragAborted)
            return
        const id = root.dragTileId
        root.dragging = false
        flick.interactive = true
        root.dropLine = null
        if (root.dragAborted)
            root.dragAborted = false
        else
            root.tileDragFinished(id, px, py)
        root.dragTileId = ""
        root.dragTileData = null
    }

    // Esc / menu closed: put the preview back and stop following the pointer.
    function cancelDrag() {
        if (!root.dragging)
            return
        root.dragAborted = true
        root.dragging = false
        flick.interactive = true
        root.dropLine = null
        root.tileDragCanceled(root.dragTileId)
    }

    // --- rendering models --------------------------------------------------
    // Roles carry the geometry so the delegates can animate towards it.
    ListModel { id: tileModel }
    ListModel { id: groupModel }
    property var tileDataById: ({})

    function syncModels() {
        var seen = {}
        var data = {}
        var tiles = []
        var titleGroups = []
        for (var g = 0; g < groups.length; ++g) {
            var group = groups[g]
            titleGroups.push(group)
            for (var t = 0; t < group.tiles.length; ++t) {
                var tile = group.tiles[t]
                seen[tile.id] = true
                data[tile.id] = tile
                tiles.push({ tile: tile, groupId: group.id })
            }
        }
        // drop tiles that are gone
        for (var i = tileModel.count - 1; i >= 0; --i) {
            if (!seen[tileModel.get(i).tid])
                tileModel.remove(i)
        }
        // update or append the rest
        var index = {}
        for (var j = 0; j < tileModel.count; ++j)
            index[tileModel.get(j).tid] = j
        for (var k = 0; k < tiles.length; ++k) {
            var item = tiles[k]
            var row = index[item.tile.id]
            if (row === undefined) {
                tileModel.append({ tid: item.tile.id, gid: item.groupId,
                                   tx: item.tile.x, ty: item.tile.y,
                                   tw: item.tile.w, th: item.tile.h })
            } else {
                if (tileModel.get(row).tx !== item.tile.x)
                    tileModel.setProperty(row, "tx", item.tile.x)
                if (tileModel.get(row).ty !== item.tile.y)
                    tileModel.setProperty(row, "ty", item.tile.y)
                if (tileModel.get(row).tw !== item.tile.w)
                    tileModel.setProperty(row, "tw", item.tile.w)
                if (tileModel.get(row).th !== item.tile.h)
                    tileModel.setProperty(row, "th", item.tile.h)
            }
        }

        // group titles
        for (var r = groupModel.count - 1; r >= 0; --r) {
            var gid = groupModel.get(r).gid
            var alive = false
            for (var n = 0; n < titleGroups.length && !alive; ++n)
                alive = titleGroups[n].id === gid
            if (!alive)
                groupModel.remove(r)
        }
        var gindex = {}
        for (var m = 0; m < groupModel.count; ++m)
            gindex[groupModel.get(m).gid] = m
        for (var q = 0; q < titleGroups.length; ++q) {
            var tg = titleGroups[q]
            var grow = gindex[tg.id]
            if (grow === undefined) {
                groupModel.append({ gid: tg.id, gx: tg.x, gy: tg.y, gtitle: tg.title })
            } else {
                if (groupModel.get(grow).gx !== tg.x)
                    groupModel.setProperty(grow, "gx", tg.x)
                if (groupModel.get(grow).gy !== tg.y)
                    groupModel.setProperty(grow, "gy", tg.y)
                if (groupModel.get(grow).gtitle !== tg.title)
                    groupModel.setProperty(grow, "gtitle", tg.title)
            }
        }
        root.tileDataById = data
    }

    onGroupsChanged: syncModels()
    Component.onCompleted: syncModels()
    // While dragging the ghost follows the pointer; the tile reports it from
    // its DragHandler, the menu's hover position is the fallback.
    onPointerXChanged: if (dragging) moveTileDrag(pointerX, pointerY)
    onPointerYChanged: if (dragging) moveTileDrag(pointerX, pointerY)

    // --- layout helpers (entrance / switch) --------------------------------
    function switchRise(y) {
        return Motion.switchRise(switchProgress, y, tileExtent.y1)
    }

    function switchFade(y) {
        return Motion.switchFade(switchProgress, y, tileExtent.y0, tileExtent.y1)
    }

    readonly property var tileExtent: {
        var x0 = 1e9, y0 = 1e9, x1 = -1e9, y1 = -1e9
        for (var g = 0; g < groups.length; ++g) {
            for (var t = 0; t < groups[g].tiles.length; ++t) {
                var tile = groups[g].tiles[t]
                x0 = Math.min(x0, tile.x); y0 = Math.min(y0, tile.y)
                x1 = Math.max(x1, tile.x + tile.w); y1 = Math.max(y1, tile.y + tile.h)
            }
        }
        return { x0: x0, y0: y0, x1: x1, y1: y1 }
    }

    function rankOf(tileX, tileY) {
        var e = tileExtent
        var dx = tileX - e.x0, dy = tileY - e.y0
        if (entranceOrigin === "bottomLeft") {
            var dist = Math.hypot(dx, e.y1 - tileY)
            var maxDist = Math.hypot(e.x1 - e.x0, e.y1 - e.y0) * 0.6
            return Math.min(1, dist / maxDist)
        }
        // default: purely vertical, bottom rows first
        return e.y1 > e.y0 ? (e.y1 - tileY) / (e.y1 - e.y0) : 0
    }

    function tileProgress(tileX, tileY) {
        if (entrance >= 1)
            return 1
        if (entrance <= 0)
            return 0
        const delay = rankOf(tileX, tileY) * entranceStagger
        return Math.max(0, Math.min(1, (entrance - delay) / entranceRowWindow))
    }

    // Per-row scale: the rows animate independently, each growing about the
    // screen centre, so the lower rows are already large while the upper rows
    // are still small.
    function tileScale(tileX, tileY) {
        const p = tileProgress(tileX, tileY)
        const e = 1 - Math.pow(1 - p, entranceCurve)
        const s0 = Math.max(0.2, Math.min(1.0, entranceScaleFrom + entranceScaleSlope * rankOf(tileX, tileY)))
        return s0 + (1 - s0) * e
    }
    signal tileActivated(var entry)

    // Everything in here lives in content coordinates: the Flickable moves the
    // whole tile area up by `contentY` when it scrolls.
    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: Math.max(root.contentHeight, root.height)
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        clip: true

        Repeater {
            model: tileModel
            delegate: Tile {
                id: tileItem
                required property string tid
                required property string gid
                required property int index
                required property real tx
                required property real ty
                required property real tw
                required property real th

                tileData: root.tileDataById[tid]
                // The ghost stands in for the tile while it is being dragged,
                // so the tile itself leaves an empty slot behind.
                visible: !(root.dragging && root.dragTileId === tid)
                width: tw
                height: th
                targetX: tx
                targetY: ty
                pointerX: root.pointerX
                pointerY: root.pointerY
                pointerInside: root.pointerInside
                scrollOffset: flick.contentY
                forceHover: index === root.debugHoverTile
                hoverInjected: root.hoverInjected
                entrance: root.tileProgress(tx, ty)
                entranceScale: root.tileScale(tx, ty)
                entranceCentreX: root.entranceCentreX
                entranceCentreY: root.entranceCentreY
                entranceCurve: root.entranceCurve
                entranceScaleSlope: root.entranceScaleSlope
                entranceOpacityLead: root.entranceOpacityLead
                entranceOpacityFloor: root.entranceOpacityFloor
                                      + root.entranceOpacityFloorSlope * root.rankOf(tx, ty)
                debugScale: root.debugTileScale
                debugOpacity: root.debugTileOpacity
                debugRise: root.debugTileRise
                riseY: root.switchRise(ty)
                switchOpacity: root.switchFade(ty)
                onActivated: (entry) => root.tileActivated(entry)

                onDragStarted: {
                    const o = tileItem.mapToItem(root, 0, 0)
                    root.startTileDrag(tid, tileItem.tileData, root.pointerX, root.pointerY,
                                       o.x, o.y, tw, th)
                }
                onDragPointer: (sx, sy) => {
                    const p = root.mapFromItem(null, sx, sy)
                    root.moveTileDrag(p.x, p.y)
                }
                onDragFinished: root.endTileDrag(root.dragX, root.dragY)
            }
        }

        // Group titles ride along with the tiles: same row progress, same scale
        // about the menu centre and the same fade.
        Repeater {
            model: groupModel
            delegate: Item {
                id: titleItem
                required property string gid
                required property real gx
                required property real gy
                required property string gtitle
                // Copies of the model roles so the reflow animation can run on
                // them (a Behavior on the role itself breaks the binding).
                property real px: gx
                property real py: gy
                Behavior on px { NumberAnimation { duration: Metrics.reflowDuration; easing.type: Easing.OutCubic } }
                Behavior on py { NumberAnimation { duration: Metrics.reflowDuration; easing.type: Easing.OutCubic } }
                readonly property real titleBaselineY: py + Metrics.groupTitleOffsetY
                // rank against the tiles of the same row
                readonly property real scaleFactor: root.tileScale(gx, titleBaselineY)
                visible: root.titlesVisible && gtitle !== ""
                width: titleText.width
                height: titleText.height
                transformOrigin: Item.TopLeft
                scale: titleItem.scaleFactor
                x: root.entranceCentreX + (px - root.entranceCentreX) * scale
                y: root.entranceCentreY + (titleBaselineY - root.entranceCentreY) * scale
                   + root.switchRise(titleBaselineY)
                opacity: (root.entranceOpacityFloor
                          + (1 - root.entranceOpacityFloor) * titleItem.ease(Math.min(1, root.tileProgress(px, titleBaselineY) * root.entranceOpacityLead)))
                         * root.switchFade(titleBaselineY)

                function ease(p) {
                    return 1 - Math.pow(1 - Math.max(0, Math.min(1, p)), root.entranceCurve)
                }

                BaseText {
                    id: titleText
                    x: 0
                    baselineY: 0
                    text: titleItem.gtitle
                    family: Metrics.fontFamily
                    pixelSize: Metrics.groupTitleSize
                }
            }
        }

        // Insertion line for the drop target (content coordinates).
        Rectangle {
            visible: root.dragging && root.dropLine !== null
            x: root.dropLine ? root.dropLine.x : 0
            y: root.dropLine ? root.dropLine.y : 0
            width: root.dropLine ? root.dropLine.w : 0
            height: root.dropLine ? root.dropLine.h : 0
            radius: Math.min(width, height) / 2
            color: Metrics.insertionColor
            z: 50
        }
    }

    // The tile that follows the pointer while dragging (above the scroller, so
    // it does not move when the list scrolls).
    Tile {
        id: ghost
        visible: root.dragging
        width: root.dragWidth
        height: root.dragHeight
        tileData: root.dragTileData
        targetX: root.dragLeftX
        targetY: root.dragLeftY
        animatePosition: false
        enabled: false
        entrance: 1
        hoverInjected: false
        opacity: 0.9
        z: 100
    }
}