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
    // Metrics of the layout: fullscreen (Metrics) or compact (CompactMetrics).
    property var m: Metrics
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
    property real backdropWhite: 0.4
    property real backdropBlack: 0.667
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
    // Accent colour (native SystemAccentColor): pressed group title, the group
    // drag placeholder and the dragged block.
    property color accentColor: m.accentColorDefault

    // Group drag: the grabbed title block follows the pointer, the group itself
    // collapses into the placeholder bar the menu puts at the drop position.
    property string groupDragId: ""
    property string groupDragTitle: ""
    property real groupDragWidth: 0
    property real groupDragX: 0
    property real groupDragY: 0
    property real groupGrabX: 0
    property real groupGrabY: 0

    function startGroupDrag(gid, title, width, px, py, originX, originY) {
        root.groupDragId = gid
        root.groupDragTitle = title
        root.groupDragWidth = width
        root.groupGrabX = px - originX
        root.groupGrabY = py - originY
        root.groupDragX = px
        root.groupDragY = py
        root.dragScrollLocked = true
        root.groupDragStarted(gid, px, py)
    }

    function moveGroupDrag(px, py) {
        if (root.groupDragId === "")
            return
        root.groupDragX = px
        root.groupDragY = py
        root.groupDragMoved(root.groupDragId, px, py + root.scrollY)
    }

    // The title block reports the pointer from its DragHandler (the hover
    // position stops updating once the handler grabs the mouse).
    function moveGroupDragScene(sx, sy) {
        const p = root.mapFromItem(null, sx, sy)
        moveGroupDrag(p.x, p.y)
    }

    function endGroupDrag(px, py) {
        if (root.groupDragId === "")
            return
        const id = root.groupDragId
        root.groupDragId = ""
        root.dragScrollLocked = false
        root.groupDragFinished(id, px, py)
    }

    function cancelGroupDrag() {
        if (root.groupDragId === "")
            return
        const id = root.groupDragId
        root.groupDragId = ""
        root.dragScrollLocked = false
        root.groupDragCanceled(id)
    }

    // Dragging near the top/bottom edge scrolls the tile area, so a group can
    // be dropped at the very end of the scrollable content (and back up when
    // the area is already scrolled down).
    Timer {
        id: dragAutoScroll
        interval: 16
        repeat: true
        running: (root.dragging || root.groupDragId !== "") && root.maxScroll > 0
        onTriggered: {
            const pointerY = root.dragging ? root.dragY : root.groupDragY
            const margin = m.dragAutoScrollMargin
            const step = m.dragAutoScrollStep
            var delta = 0
            if (pointerY < margin)
                delta = -step * Math.min(1, (margin - pointerY) / margin)
            else if (pointerY > root.height - margin)
                delta = step * Math.min(1, (pointerY - (root.height - margin)) / margin)
            if (delta === 0)
                return
            const before = root.scrollY
            root.scrollTo(before + delta)
            if (root.scrollY === before)
                return
            // the target depends on the scrolled position: recompute it
            if (root.dragging)
                root.moveTileDrag(root.dragX, root.dragY)
            else if (root.groupDragId !== "")
                root.moveGroupDrag(root.groupDragX, root.groupDragY)
        }
    }

    signal tileDragStarted(string tileId, real px, real py)
    signal tileDragMoved(string tileId, real px, real py)
    signal tileDragFinished(string tileId, real px, real py)
    signal tileDragCanceled(string tileId)
    signal groupDragStarted(string groupId, real px, real py)
    signal groupDragMoved(string groupId, real px, real py)
    signal groupDragFinished(string groupId, real px, real py)
    signal groupDragCanceled(string groupId)

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
        root.dragScrollLocked = true
        root.tileDragStarted(tileId, px, py)
    }

    // The menu works in content coordinates (the layout is not scrolled); the
    // ghost stays in view coordinates.
    function moveTileDrag(px, py) {
        if (!root.dragging)
            return
        root.dragX = px
        root.dragY = py
        root.tileDragMoved(root.dragTileId, px, py + root.scrollY)
    }

    function endTileDrag(px, py) {
        if (!root.dragging && !root.dragAborted)
            return
        const id = root.dragTileId
        root.dragging = false
        root.dragScrollLocked = false
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
        root.dragScrollLocked = false
        root.tileDragCanceled(root.dragTileId)
    }

    // --- rendering models --------------------------------------------------
    // Roles carry the geometry so the delegates can animate towards it.
    ListModel { id: tileModel }
    ListModel { id: groupModel }
    property var tileDataById: ({})
    // Bumped whenever the map is rebuilt: the delegates depend on it so
    // a replaced tile object (e.g. a new `live` field) always arrives.
    property int dataRevision: 0

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
                groupModel.append({ gid: tg.id, gx: tg.x, gy: tg.y, gw: tg.w,
                                    gtitle: tg.title, gplaceholder: tg.placeholder === true })
            } else {
                if (groupModel.get(grow).gx !== tg.x)
                    groupModel.setProperty(grow, "gx", tg.x)
                if (groupModel.get(grow).gy !== tg.y)
                    groupModel.setProperty(grow, "gy", tg.y)
                if (groupModel.get(grow).gw !== tg.w)
                    groupModel.setProperty(grow, "gw", tg.w)
                if (groupModel.get(grow).gplaceholder !== (tg.placeholder === true))
                    groupModel.setProperty(grow, "gplaceholder", tg.placeholder === true)
                if (groupModel.get(grow).gtitle !== tg.title)
                    groupModel.setProperty(grow, "gtitle", tg.title)
            }
        }
        root.tileDataById = data
        root.dataRevision += 1
    }

    onGroupsChanged: syncModels()
    Component.onCompleted: syncModels()
    // While dragging the ghost follows the pointer; the tile reports it from
    // its DragHandler, the menu's hover position is the fallback.
    onPointerXChanged: if (dragging) moveTileDrag(pointerX, pointerY)
    onPointerYChanged: if (dragging) moveTileDrag(pointerX, pointerY)

    // --- layout helpers (entrance / switch) --------------------------------
    // The windowed Start pushes its rows up with the gentler compactRise curve;
    // the fullscreen tiles/apps switch keeps the snappy one.
    property bool windowedAnimation: false
    // "early" paints every tile with its slot colour, "modern" keeps the
    // translucent fill the reference screenshots show.
    property string tileSkin: "modern"
    property string tilePalette: "default"
    property bool forceAppColor: true
    property string themedIcon: "auto"
    property bool liveTilesEnabled: false
    property string homeDir: ""
    property string weatherSource: ""
    property bool liveTileCycle: true
    property string liveTileVariant: "auto"
    property bool pulseOnUpdate: false
    property bool moreLiveAni: true

    function switchRise(y) {
        if (windowedAnimation)
            return Motion.compactRise(switchProgress, y, tileExtent.y1)
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
    signal tileContextRequested(var entry, real sceneX, real sceneY)
    // The size change asks the owner to apply the new size once the tile has
    // faded out (see beginSizeChange).
    signal sizeChangeRequested(string tileId, string size)
    // A click (press and release without a drag) on a group's title block turns
    // the block itself into the rename field; the new title comes back here.
    signal groupRenamed(string groupId, string title)
    // Group whose title block is being renamed ("" = none).
    property string renamingGroupId: ""
    // Rect of the block being renamed, in this view's coordinates.
    property rect renameRect: Qt.rect(0, 0, 0, 0)

    function beginGroupRename(groupId) {
        renamingGroupId = groupId
    }
    // The tile whose context menu is open keeps its hover highlight; while a
    // menu is up the pointer belongs to the popup, so nothing behind it reacts.
    property string contextHoverTile: ""
    // `pointerBlocked`: the popup is under the pointer, nothing behind reacts.
    // `hoverBlocked`: the popup is merely open, so no tile highlights - but the
    // tiles still answer clicks and still show the reveal frame.
    property bool pointerBlocked: false
    property bool hoverBlocked: false
    // Harness: force the title-block hover look ("*" = every group).
    property string debugHoverGroupId: ""
    // Set while a drag owns the pointer; the tile area must not scroll then.
    property bool dragScrollLocked: false
    // Size change animation: only the tile being resized reacts to these.
    property string resizingTileId: ""
    property string resizingSize: ""
    property real resizeFade: 1
    property real resizeShrink: 1

    function beginSizeChange(tileId, size) {
        resizingTileId = tileId
        resizingSize = size
        resizeFade = 1
        resizeShrink = 1
        sizeChangeAnimation.restart()
    }

    SequentialAnimation {
        id: sizeChangeAnimation
        ParallelAnimation {
            NumberAnimation { target: root; property: "resizeFade"
                              to: 0; duration: m.tileResizeFadeOutDuration
                              easing.type: Easing.Linear }
            NumberAnimation { target: root; property: "resizeShrink"
                              to: m.tileResizeShrink
                              duration: m.tileResizeFadeOutDuration
                              easing.type: Easing.Linear }
        }
        // The tile is invisible now: apply the new size and let the layout
        // reflow (the groups below glide down).
        ScriptAction { script: root.sizeChangeRequested(root.resizingTileId, root.resizingSize) }
        PauseAnimation { duration: m.tileResizeGap }
        ParallelAnimation {
            NumberAnimation { target: root; property: "resizeFade"
                              to: 1; duration: m.tileResizeFadeInDuration
                              easing.type: Easing.Linear }
            NumberAnimation { target: root; property: "resizeShrink"
                              to: 1; duration: m.tileResizeFadeInDuration
                              easing.type: Easing.Linear }
        }
        ScriptAction { script: root.resizingTileId = "" }
    }
    signal groupContextRequested(string groupId, real sceneX, real sceneY)

    // Everything in here lives in content coordinates: the Flickable moves the
    // whole tile area up by `contentY` when it scrolls.
    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: Math.max(root.contentHeight, root.height)
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        // A drag or an open popup owns the pointer: no scrolling then.
        interactive: !root.pointerBlocked && !root.dragScrollLocked
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

                m: root.m
                tileData: (root.dataRevision, root.tileDataById[tid])
                skin: root.tileSkin
                palette: root.tilePalette
                forceAppColor: root.forceAppColor
                themedIcon: root.themedIcon
                liveTilesEnabled: root.liveTilesEnabled
                liveTileCycle: root.liveTileCycle
                pulseOnUpdate: root.pulseOnUpdate
                liveTileVariant: root.liveTileVariant
                homeDir: root.homeDir
                weatherSource: root.weatherSource
                moreLiveAni: root.moreLiveAni
                // The ghost stands in for the tile while it is being dragged,
                // so the tile itself leaves an empty slot behind; everything
                // else fades back and loses its border while dragging.
                visible: !(root.dragging && root.dragTileId === tid)
                flat: root.dragging
                dim: root.dragging ? m.dragDim : 1
                shrink: root.dragging ? m.dragShrink : 1
                width: tw
                height: th
                targetX: tx
                targetY: ty
                pointerX: root.pointerX
                pointerY: root.pointerY
                pointerInside: root.pointerInside
                scrollOffset: flick.contentY
                forceHover: index === root.debugHoverTile
                            || (root.contextHoverTile !== "" && tid === root.contextHoverTile)
                pointerBlocked: root.pointerBlocked
                hoverBlocked: root.hoverBlocked
                resizeFade: root.resizingTileId !== "" && tid === root.resizingTileId
                            ? root.resizeFade : 1
                resizeShrink: root.resizingTileId !== "" && tid === root.resizingTileId
                              ? root.resizeShrink : 1
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
                onContextRequested: (entry, sx, sy) => root.tileContextRequested(entry, sx, sy)

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

        // Group title blocks: the grab area of a group. They ride along with
        // the tiles (same row progress, scale and fade) and carry the drag
        // affordances of group_tile/*.png: the handle appears on hover, the
        // block turns accent-coloured while pressed and, once the group is
        // dragged, only a placeholder bar is left at the drop position.
        Repeater {
            model: groupModel
            delegate: Item {
                id: titleBlock
                required property string gid
                required property real gx
                required property real gy
                required property real gw
                required property string gtitle
                required property bool gplaceholder

                // Copies of the model roles so the reflow animation can run on
                // them (a Behavior on the role itself breaks the binding).
                property real px: gx
                property real py: gy
                Behavior on px { NumberAnimation { duration: m.reflowDuration; easing.type: Easing.OutCubic } }
                Behavior on py { NumberAnimation { duration: m.reflowDuration; easing.type: Easing.OutCubic } }

                readonly property real blockTop: py + m.groupTitleBlockTop
                readonly property real baselineAbs: py + m.groupTitleOffsetY
                readonly property real scaleFactor: root.tileScale(px, baselineAbs)
                readonly property bool collapsed: root.groupDragId !== "" && root.groupDragId === gid

                readonly property bool hovered: blockHover.hovered
                                                 || (root.debugHoverGroupId !== ""
                                                     && (root.debugHoverGroupId === "*"
                                                         || root.debugHoverGroupId === gid))
                property bool pressed: false
                property bool dragActive: false

                width: gw
                height: m.groupTitleBlockHeight
                transformOrigin: Item.TopLeft
                scale: titleBlock.scaleFactor
                x: root.entranceCentreX + (px - root.entranceCentreX) * scale
                y: root.entranceCentreY + (blockTop - root.entranceCentreY) * scale
                   + root.switchRise(baselineAbs)
                opacity: (root.entranceOpacityFloor
                          + (1 - root.entranceOpacityFloor) * titleBlock.ease(Math.min(1, root.tileProgress(px, baselineAbs) * root.entranceOpacityLead)))
                         * root.switchFade(baselineAbs)

                function ease(p) {
                    return 1 - Math.pow(1 - Math.max(0, Math.min(1, p)), root.entranceCurve)
                }

                // pressed (and while the rename field is up): the whole block
                // turns accent coloured
                Rectangle {
                    anchors.fill: parent
                    color: root.accentColor
                    visible: (titleBlock.pressed || titleBlock.editing) && !titleBlock.collapsed
                }

                // Rename field: the block itself becomes the editor
                // (group rename.png: accent block, white field at 12,21 and the
                // grab handle on the right).
                readonly property bool editing: root.renamingGroupId === gid

                function commitRename() {
                    if (!editing)
                        return
                    const text = renameText.text
                    root.renamingGroupId = ""
                    root.groupRenamed(gid, text)
                }

                Item {
                    anchors.fill: parent
                    visible: titleBlock.editing && !titleBlock.collapsed
                    z: 1

                    Rectangle {
                        x: m.renameFieldX
                        y: m.renameFieldY
                        width: Math.max(1, parent.width - m.renameFieldX
                                           - m.renameFieldRight)
                        height: m.renameFieldHeight
                        color: "#FFFFFF"
                    }
                    TextInput {
                        id: renameText
                        x: m.renameFieldX + m.renameTextInset
                        y: m.renameFieldY
                        width: Math.max(1, parent.width - m.renameFieldX
                                           - m.renameTextInset - m.renameFieldRight)
                        height: m.renameFieldHeight
                        verticalAlignment: TextInput.AlignVCenter
                        color: "#000000"
                        selectionColor: root.accentColor
                        selectedTextColor: "#FFFFFF"
                        font.family: m.fontFamily
                        font.pixelSize: m.renameTextSize
                        clip: true
                        onAccepted: titleBlock.commitRename()
                        onActiveFocusChanged: if (!activeFocus && titleBlock.editing)
                                                  titleBlock.commitRename()
                        Keys.onEscapePressed: root.renamingGroupId = ""
                    }
                    Rectangle {
                        x: parent.width - m.renameHandleRight - m.groupHandleWidth
                        y: m.renameHandleY
                        width: m.groupHandleWidth
                        height: 2
                        color: "#FFFFFF"
                    }
                    Rectangle {
                        x: parent.width - m.renameHandleRight - m.groupHandleWidth
                        y: m.renameHandleY + 3
                        width: m.groupHandleWidth
                        height: 2
                        color: "#FFFFFF"
                    }
                }

                onEditingChanged: {
                    if (!editing)
                        return
                    const origin = titleBlock.mapToItem(root, 0, 0)
                    root.renameRect = Qt.rect(origin.x, origin.y, titleBlock.width, titleBlock.height)
                    renameText.text = titleBlock.gtitle
                    renameText.forceActiveFocus()
                    renameText.selectAll()
                }

                // a "new group" slot while a tile is dragged, or the group
                // itself being dragged: only a candidate bar in the title block
                Rectangle {
                    visible: titleBlock.collapsed || titleBlock.gplaceholder
                    x: 0
                    y: titleBlock.height - m.groupPlaceholderInset - m.groupPlaceholderHeight
                    width: titleBlock.width
                    height: m.groupPlaceholderHeight
                    color: root.accentColor
                    opacity: m.groupPlaceholderOpacity
                }

                // An unnamed group shows a grey hint instead of a title while
                // the block is hovered (group_tile/unamed-group-hover.png).
                BaseText {
                    visible: root.titlesVisible && titleBlock.gtitle === ""
                             && (titleBlock.hovered || titleBlock.editing)
                             && !titleBlock.collapsed && !titleBlock.gplaceholder
                             && !titleBlock.editing
                    x: m.groupTitleHintX
                    baselineY: -m.groupTitleBlockTop + m.groupTitleOffsetY
                    text: "命名组"
                    family: m.fontFamily
                    pixelSize: m.groupTitleSize
                    letterSpacing: hasCjk ? m.cjkLetterSpacing : 0
                    color: m.groupTitleHintColor
                }

                BaseText {
                    id: titleText
                    visible: root.titlesVisible && titleBlock.gtitle !== ""
                             && !titleBlock.collapsed && !titleBlock.gplaceholder
                             && !titleBlock.editing
                    x: titleBlock.pressed ? m.groupTitlePressInset : 0
                    // the block starts 90 px above the tiles, the title baseline
                    // sits 42 px above them (see metrics.js)
                    baselineY: -m.groupTitleBlockTop + m.groupTitleOffsetY
                    text: titleBlock.gtitle
                    family: m.fontFamily
                    pixelSize: m.groupTitleSize
                }

                // grab handle: two short lines, right aligned
                Item {
                    visible: titleBlock.hovered && !titleBlock.collapsed
                             && !titleBlock.gplaceholder
                    x: titleBlock.width - m.groupHandleRight - m.groupHandleWidth
                    y: titleBlock.height / 2 - m.groupHandleGap / 2
                    width: m.groupHandleWidth
                    height: m.groupHandleGap + 1
                    Rectangle { x: 0; y: 0; width: parent.width; height: 1; color: "#FFFFFF" }
                    Rectangle { x: 0; y: m.groupHandleGap; width: parent.width; height: 1; color: "#FFFFFF" }
                }

                HoverHandler {
                    id: blockHover
                    enabled: !root.pointerBlocked && !root.hoverBlocked
                }
                TapHandler {
                    enabled: !root.pointerBlocked
                    onPressedChanged: titleBlock.pressed = pressed
                    onCanceled: titleBlock.pressed = false
                    // Click (press and release, not a drag): open the rename
                    // field on the group's title block.
                    // Press and release without dragging: rename the group.
                    onTapped: root.beginGroupRename(titleBlock.gid)
                }
                property point contextPoint: Qt.point(0, 0)
                TapHandler {
                    acceptedButtons: Qt.RightButton
                    enabled: !root.pointerBlocked
                    onPressedChanged: {
                        if (pressed)
                            titleBlock.contextPoint = Qt.point(point.scenePosition.x,
                                                               point.scenePosition.y)
                    }
                    onTapped: root.groupContextRequested(titleBlock.gid,
                                                         titleBlock.contextPoint.x,
                                                         titleBlock.contextPoint.y)
                }
                DragHandler {
                    id: blockDrag
                    target: null
                    enabled: !root.pointerBlocked && !titleBlock.editing
                    dragThreshold: 6
                    grabPermissions: PointerHandler.CanTakeOverFromAnything
                    onActiveChanged: {
                        if (active) {
                            const p = root.mapFromItem(null, blockDrag.centroid.scenePosition)
                            const o = titleBlock.mapToItem(root, 0, 0)
                            titleBlock.dragActive = true
                            root.startGroupDrag(titleBlock.gid, titleBlock.gtitle,
                                                titleBlock.gw, p.x, p.y, o.x, o.y)
                        } else if (titleBlock.dragActive) {
                            titleBlock.dragActive = false
                            titleBlock.pressed = false
                            root.endGroupDrag(root.groupDragX, root.groupDragY)
                        }
                    }
                    onCentroidChanged: {
                        if (titleBlock.dragActive) {
                            const sp = blockDrag.centroid.scenePosition
                            root.moveGroupDragScene(sp.x, sp.y)
                        }
                    }
                }
            }
        }
    }

    // The grabbed title block follows the pointer: accent bar with the group's
    // title and the handle, exactly like the pressed block in the reference.
    Rectangle {
        visible: root.groupDragId !== ""
        x: root.groupDragX - root.groupGrabX
        y: root.groupDragY - root.groupGrabY
        width: root.groupDragWidth
        height: m.groupTitleBlockHeight
        color: root.accentColor
        opacity: m.groupGhostOpacity
        z: 120

        BaseText {
            x: m.groupTitlePressInset
            baselineY: -m.groupTitleBlockTop + m.groupTitleOffsetY
            text: root.groupDragTitle
            family: m.fontFamily
            pixelSize: m.groupTitleSize
        }
        Item {
            x: parent.width - m.groupHandleRight - m.groupHandleWidth
            y: parent.height / 2 - m.groupHandleGap / 2
            width: m.groupHandleWidth
            height: m.groupHandleGap + 1
            Rectangle { x: 0; y: 0; width: parent.width; height: 1; color: "#FFFFFF" }
            Rectangle { x: 0; y: m.groupHandleGap; width: parent.width; height: 1; color: "#FFFFFF" }
        }
    }

    // The tile that follows the pointer while dragging, drawn above the
    // scroller so it does not move when the list scrolls. It is a normal tile:
    // translucent like the others (the reference lets the blue drop band and
    // the tiles underneath show through it), only without the dim.
    Tile {
        id: ghost
        visible: root.dragging
        x: root.dragLeftX
        y: root.dragLeftY
        width: root.dragWidth
        height: root.dragHeight
        z: 100
        // native: ListViewItemDragThemeOpacity
        opacity: m.dragTileOpacity
        tileData: root.dragTileData
        animatePosition: false
        // not `enabled: false`: a disabled Kirigami.Icon (theme icons) would be
        // drawn grey
        interactive: false
        entrance: 1
        hoverInjected: false
        flat: true
    }
    // Thin indicator: only while the tile area is being scrolled.
    ScrollBar {
        objectName: "tilesScrollBar"
        // Sit in the panel's right margin instead of over the last tile column.
        edgeInset: 20
        contentY: root.scrollY
        contentHeight: root.contentHeight
        viewHeight: root.height
    }

}