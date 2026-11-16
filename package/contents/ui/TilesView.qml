// The pinned tiles: groups of tiles, optionally with editable group titles.
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
            model: root.groups
            delegate: Item {
                required property var modelData
                Repeater {
                    model: modelData.tiles
                    delegate: Tile {
                        required property var modelData
                        required property int index
                        tileData: modelData
                        pointerX: root.pointerX
                        pointerY: root.pointerY
                        pointerInside: root.pointerInside
                        scrollOffset: flick.contentY
                        forceHover: index === root.debugHoverTile
                        hoverInjected: root.hoverInjected
                        entrance: root.tileProgress(modelData.x, modelData.y)
                        entranceScale: root.tileScale(modelData.x, modelData.y)
                        entranceCentreX: root.entranceCentreX
                        entranceCentreY: root.entranceCentreY
                        entranceCurve: root.entranceCurve
                        entranceScaleSlope: root.entranceScaleSlope
                        entranceOpacityLead: root.entranceOpacityLead
                        entranceOpacityFloor: root.entranceOpacityFloor
                                              + root.entranceOpacityFloorSlope * root.rankOf(modelData.x, modelData.y)
                        debugScale: root.debugTileScale
                        debugOpacity: root.debugTileOpacity
                        debugRise: root.debugTileRise
                        riseY: root.switchRise(modelData.y)
                        switchOpacity: root.switchFade(modelData.y)
                        onActivated: (entry) => root.tileActivated(entry)
                    }
                }
            }
        }

        // Group titles ride along with the tiles: same row progress, same scale
        // about the menu centre and the same fade.
        Repeater {
            model: root.groups
            delegate: Item {
                id: titleItem
                required property var modelData
                readonly property real titleBaselineY: modelData.y + Metrics.groupTitleOffsetY
                // rank against the tiles of the same row
                readonly property real scaleFactor: root.tileScale(modelData.x, titleBaselineY)
                visible: root.titlesVisible && modelData.title !== ""
                width: titleText.width
                height: titleText.height
                transformOrigin: Item.TopLeft
                scale: titleItem.scaleFactor
                x: root.entranceCentreX + (modelData.x - root.entranceCentreX) * scale
                y: root.entranceCentreY + (titleItem.titleBaselineY - root.entranceCentreY) * scale
                   + root.switchRise(titleItem.titleBaselineY)
                opacity: (root.entranceOpacityFloor
                          + (1 - root.entranceOpacityFloor)
                            * titleItem.ease(Math.min(1, root.tileProgress(modelData.x,
                                                                         titleItem.titleBaselineY)
                                                      * root.entranceOpacityLead)))
                         * root.switchFade(titleItem.titleBaselineY)

                function ease(p) {
                    return 1 - Math.pow(1 - Math.max(0, Math.min(1, p)), root.entranceCurve)
                }

                BaseText {
                    id: titleText
                    x: 0
                    baselineY: 0
                    text: titleItem.modelData.title
                    family: Metrics.fontFamily
                    pixelSize: Metrics.groupTitleSize
                }
            }
        }
    }
}
