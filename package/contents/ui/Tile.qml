// A single tile: translucent fill, icon, labels and the Fluent reveal
// border/glow that follows the pointer.
import QtQuick
import "metrics.js" as Metrics
import "TileColors.js" as TileColors
import "motion.js" as Motion

Item {
    id: tile
    // Metrics of the layout this tile belongs to: the fullscreen design (the
    // Metrics module) or the compact one (see CompactMetrics.js).
    property var m: Metrics
    // Share of the icon box the theme's artwork fills (applet setting, see
    // metrics.js). The box is enlarged by it so the visible icon keeps its
    // design size whatever padding the icon theme ships.
    property real iconFillRatio: Metrics.iconFillRatio
    property var tileData: null
    // "modern" = the translucent fill of the reference screenshots,
    // "early" = the coloured tile of Windows RTM (see TileColors.js).
    property string skin: "modern"
    property string palette: "default"
    property bool forceAppColor: true
    // Icon rendering of the early skin: auto (white silhouette), letter or color.
    property string themedIcon: "auto"
    // Live content of the early skin: clock / battery / date (stage 4).
    property bool liveTilesEnabled: false
    // An explicit per-tile assignment wins: the master switch only drives the
    // *animation* options, not whether the content exists.
    readonly property string liveType: tile.tileData && tile.tileData.live
        ? String(tile.tileData.live.type || "") : ""
    readonly property bool hasLive: tile.liveType !== ""
    // Live tile cycle (Windows alternates between the tile's icon and its live
    // content, see plans/EARLY-STYLE-INTEGRATION.md §4).
    property string homeDir: ""
    property string weatherSource: ""
    // Set by the view while a tile is being dragged: the live-tile cycle stops
    // so the drag stays smooth.
    property bool dragActive: false
    property bool liveTileCycle: true
    property string liveTileVariant: "auto"
    property bool pulseOnUpdate: false
    property bool moreLiveAni: true
    property int cycleVariant: 0
    property real cycleT: 1          // 0..1 of one content swap
    property bool cyclePhase: false  // false = icon, true = live content
    readonly property bool cycleActive: tile.hasLive && tile.liveTileCycle
    readonly property bool showLive: tile.cycleActive ? tile.cyclePhase : tile.hasLive
    readonly property bool showGlyph: tile.cycleActive ? !tile.cyclePhase : !tile.hasLive

    // Geometry of the swap, D1 easing from motion.js.
    readonly property real cycleExtent: tile.height
    // 0 = slide (0..3), 1 = flip (4..7). Only flips rotate; only slides move.
    readonly property int cycleKind: tile.cycleVariant < 4 ? 0 : 1
    // Variants 5 and 7 flip about the vertical axis; 4 and 6 about the
    // horizontal one (see SQUARE-HOME-ANALYSIS.md §8.2).
    // Which content was on screen when the swap started (0 = glyph, 1 = live):
    // the slide moves that one out and the other one in.
    property int swapFrom: 0

    // Direction the outgoing content travels, per slide variant.
    readonly property point slideDirection: {
        switch (tile.cycleVariant % 4) {
        case 0: return Qt.point(0, -1)     // bottom: leaves upwards
        case 1: return Qt.point(1, 0)      // left: leaves to the right
        case 2: return Qt.point(-1, 0)     // right: leaves to the left
        default: return Qt.point(0, 1)     // top: leaves downwards
        }
    }

    // Offset of one layer during a slide. `isLive` picks the layer; the outgoing
    // one runs from 0 to the edge while the incoming one runs from the opposite
    // edge back to 0, both on the same atan curve.
    function layerOffset(isLive) {
        if (!tile.cycleActive || tile.cycleKind !== 0)
            return Qt.point(0, 0)
        const ext = tile.height
        if (tile.cycleT >= 1) {
            // idle: the visible layer sits still, the other waits off-tile
            if (isLive === tile.cyclePhase)
                return Qt.point(0, 0)
            return Qt.point(-tile.slideDirection.x * ext,
                            -tile.slideDirection.y * ext)
        }
        const e = Motion.tileSlideProgress(tile.cycleT)
        const outgoing = (tile.swapFrom === 1) === isLive
        if (outgoing)
            return Qt.point(tile.slideDirection.x * ext * e,
                            tile.slideDirection.y * ext * e)
        return Qt.point(-tile.slideDirection.x * ext * (1 - e),
                        -tile.slideDirection.y * ext * (1 - e))
    }

    // During a flip the tile turns as a whole, so only the current content is
    // painted (the switch happens while the tile is edge-on).
    function layerOpacity(isLive) {
        if (!tile.cycleActive || tile.cycleKind !== 1 || tile.cycleT >= 1)
            return 1
        return (isLive === tile.cyclePhase) ? 1 : 0
    }

    readonly property bool cycleYAxis: tile.cycleVariant === 5 || tile.cycleVariant === 7
        || tile.cycleVariant === 9 || tile.cycleVariant === 11
    // Variants 8..11 rotate about an edge and slide by half a tile (hv2's
    // pre/postTranslate pivot trick).
    readonly property bool cycleEdge: tile.cycleVariant >= 8
    readonly property real cycleOriginX: {
        if (!tile.cycleEdge) return tile.width / 2
        return (tile.cycleVariant === 9) ? 0 : (tile.cycleVariant === 11 ? tile.width : tile.width / 2)
    }
    readonly property real cycleOriginY: {
        if (!tile.cycleEdge) return tile.height / 2
        return (tile.cycleVariant === 8) ? tile.height : (tile.cycleVariant === 10 ? 0 : tile.height / 2)
    }
    readonly property real cycleEdgeShift: tile.cycleEdge && tile.cycleT < 0.5
        ? Math.round(tile.height / 2 * Motion.tileAccel(tile.cycleT * 2, 3)) : 0
    readonly property real cycleAngle: tile.cycleActive && tile.cycleKind === 1
        && tile.cycleT < 1
        ? Motion.tileFlipAngle(tile.cycleT, (tile.cycleVariant % 2 === 0) ? 1 : -1) : 0
    readonly property real cycleScale: tile.cycleActive && tile.cycleKind === 1
        && tile.cycleT < 1 ? Motion.tileFlipScale(tile.cycleT) : 1
    readonly property var cycleOffsetLegacy: {
        if (!tile.cycleActive || tile.cycleKind !== 0 || tile.cycleT >= 1)
            return Qt.point(0, 0)
        const v = Math.min(3, tile.cycleVariant % 4)
        const e = tile.cycleT < 0.5 ? tile.cycleT * 2 : (tile.cycleT - 0.5) * 2
        const d = Motion.tileSlideProgress(e)   // 0..1 atan S curve
        const ext = tile.cycleExtent
        // leaving towards one edge, returning from the opposite one
        if (v === 0) return Qt.point(0, tile.cycleT < 0.5 ? -ext * d : ext * (1 - d))
        if (v === 1) return Qt.point(tile.cycleT < 0.5 ? ext * d : -ext * (1 - d), 0)
        if (v === 2) return Qt.point(tile.cycleT < 0.5 ? -ext * d : ext * (1 - d), 0)
        return Qt.point(0, tile.cycleT < 0.5 ? ext * d : -ext * (1 - d))
    }
    property real pointerX: -1
    property real pointerY: -1
    property bool pointerInside: false
    // 0 = hidden below and small, 1 = in place.
    property real entrance: 1
    // Harness overrides: -1 keeps the animated value.
    property real debugScale: -1
    property real debugOpacity: -1
    property real debugRise: -1
    // Per-row entrance: the tile scales about the menu's centre, not about its
    // own centre, so the whole row grows together.
    property real entranceScale: 1
    property real entranceCentreX: 1280
    property real entranceCentreY: 690
    property real entranceCurve: 5
    property real entranceScaleSlope: 0
    property real entranceOpacityLead: 1.0
    property real entranceOpacityFloor: 0.0
    // Switch entrance (tiles <-> all applications): the tile sits `riseY` below
    // its final position and is pushed up while `switchOpacity` fades it in.
    property real riseY: 0
    property real switchOpacity: 1
    // Press (see RevealRect).
    property bool pressed: false
    // Scroll offset of the tile area: the tiles are shifted up by it, so the
    // pointer has to be moved down by the same amount to stay in tile space.
    property real scrollOffset: 0

    // Ease-out quintic: the velocity keeps falling all the way to the end, so
    // each tile coasts into its final size instead of stopping abruptly.
    function ease(t) {
        const v = Math.max(0, Math.min(1, t))
        return 1 - Math.pow(1 - v, entranceCurve)
    }
    readonly property real entranceEase: ease(entrance)

    // Target geometry. The renderer sets these from the layout; a changed
    // target is animated, which is what makes the tiles glide when a group is
    // rearranged (see TilesView.syncModels).
    property real targetX: tileData ? tileData.x : 0
    property real targetY: tileData ? tileData.y : 0
    property bool animatePosition: true
    Behavior on targetX {
        enabled: tile.animatePosition
        NumberAnimation { duration: m.reflowDuration; easing.type: Easing.OutCubic }
    }
    Behavior on targetY {
        enabled: tile.animatePosition
        NumberAnimation { duration: m.reflowDuration; easing.type: Easing.OutCubic }
    }

    // Drag (see TilesView): the tile only reports the gesture, the view tracks
    // the pointer and moves the ghost.
    property bool dragging: false
    // Drag look: `flat` drops the border/glow (uniform fill), `dim` fades the
    // tile back while another one is being dragged and `shrink` pulls every
    // other tile a little towards its own centre (the reference lets the tiles
    // recede while one is held).
    property bool flat: false
    property real dim: 1
    property real shrink: 1
    // Size change (see TilesView.beginSizeChange): the tile fades out while it
    // shrinks a little, then fades back in at the new size.
    property real resizeFade: 1
    property real resizeShrink: 1
    // The dim fades in and out with the same curve as the shrink, so picking a
    // tile up dims and pulls the others back in one motion.
    Behavior on dim {
        NumberAnimation { duration: m.dragDimDuration; easing.type: Easing.OutCubic }
    }
    Behavior on shrink {
        NumberAnimation { duration: m.dragShrinkDuration; easing.type: Easing.OutCubic }
    }
    // Input is switched off for the drag ghost without disabling the item:
    // Kirigami.Icon draws a disabled icon in grey, and the ghost must keep its
    // colours.
    property bool interactive: true
    signal dragStarted()
    signal dragPointer(real sceneX, real sceneY)
    signal dragFinished()

    // Scaling happens about the menu centre (not the tile's own centre), so all
    // the tiles of a row grow together and drift out from the centre.
    scale: debugScale >= 0 ? debugScale : entranceScale
    transformOrigin: Item.TopLeft
    x: entranceCentreX + (targetX - entranceCentreX) * scale
    y: entranceCentreY + (targetY - entranceCentreY) * scale
       + (debugRise >= 0 ? debugRise : riseY)
    opacity: (debugOpacity >= 0 ? debugOpacity
                                : entranceOpacityFloor
                                  + (1 - entranceOpacityFloor) * ease(Math.min(1, entrance * entranceOpacityLead)))
             * switchOpacity * dim * resizeFade
    property bool forceHover: false
    signal activated(var entry)
    // Right click: the menu opens at the pointer (Windows anchors the flyout
    // there, not at the tile's corner).
    signal contextRequested(var entry, real sceneX, real sceneY)
    property point contextPoint: Qt.point(0, 0)

    width: tileData ? tileData.w : 0
    height: tileData ? tileData.h : 0

    // Pressed: the whole tile (surface, icon and label) shrinks by a couple of
    // percent about its own centre and grows back over a few frames. While
    // another tile is dragged every tile recedes a little the same way.
    transform: [
        // Press and drag-recede share one transform: one matrix per tile instead
        // of two, which matters when 60 tiles are on screen.
        Scale {
            origin.x: tile.width / 2
            origin.y: tile.height / 2
            readonly property real pressFactor: 1 - m.pressScale * surface.pressLevel
            xScale: pressFactor * tile.shrink * tile.resizeShrink
            yScale: pressFactor * tile.shrink * tile.resizeShrink
        },
        // Live tile flip: the *whole* tile turns like a card (background and
        // content together), then the camera gives it perspective.
        Rotation {
            origin.x: tile.cycleOriginX
            origin.y: tile.cycleOriginY
            axis {
                x: tile.cycleYAxis ? 0 : 1
                y: tile.cycleYAxis ? 1 : 0
                z: 0
            }
            angle: tile.cycleAngle
        },
        Scale {
            origin.x: tile.cycleOriginX
            origin.y: tile.cycleOriginY
            xScale: tile.cycleScale * tile.pulseScale
            yScale: tile.cycleScale * tile.pulseScale
        },
        Matrix4x4 {
            matrix: (tile.cycleKind === 1 && tile.cycleT < 1)
                    ? Qt.matrix4x4(1, 0, 0, 0,
                                   0, 1, 0, 0,
                                   0, 0, 1, -1 / Math.max(12, tile.width * 0.14),
                                   0, 0, 0, 1)
                    : Qt.matrix4x4(1, 0, 0, 0,
                                   0, 1, 0, 0,
                                   0, 0, 1, 0,
                                   0, 0, 0, 1)
        }
    ]

    // Small (1x1) tiles carry no label: the icon sits in the middle instead.
    readonly property var skinColors: TileColors.resolve(tileData || {}, {
        palette: tile.palette,
        forceAppColor: tile.forceAppColor,
        appId: tileData ? (tileData.desktopId || tileData.id || "") : "",
        appName: tile.labelLines.length > 0 ? String(tile.labelLines[0]) : ""
    })
    readonly property bool earlySkin: tile.skin === "early"

    readonly property bool compact: m.cell * 1.5 > width && width > 0
    readonly property var labelLines: {
        if (compact || !tileData || !tileData.label)
            return []
        return typeof tileData.label === "string" ? [tileData.label] : tileData.label
    }
    readonly property bool twoLines: labelLines.length > 1

    // While a context menu is open the popup owns the pointer: the handlers
    // below stand down and the reveal stays dark. The item itself keeps
    // `enabled` (disabling it would grey out a Kirigami icon); the tile the
    // menu belongs to keeps its hover through forceHover, set by TilesView.
    property bool pointerBlocked: false
    // The popup is open somewhere else: no hover, but clicks still land.
    property bool hoverBlocked: false
    readonly property real localX: pointerX - x
    readonly property real localY: pointerY - y + scrollOffset
    // Hover is derived from the shared pointer position instead of a
    // HoverHandler per tile: the view already tracks the pointer, and one
    // handler per tile made pointer tracking crawl over a full page (the same
    // reason RevealRect has a `pointerDriven` mode).
    readonly property bool pointerHere: pointerInside && !pointerBlocked
                                        && localX >= 0 && localY >= 0
                                        && localX < width && localY < height
    readonly property bool hovered: forceHover
                                     || (pointerHere && !hoverBlocked)

    // Tile surface: translucent fill, interior reveal glow and the 3 px border.
    RevealRect {
        id: surface
        anchors.fill: parent
        pointerX: tile.localX
        pointerY: tile.localY
        pointerInside: tile.pointerInside && !tile.pointerBlocked
        hovered: tile.flat ? false : tile.hovered
        showHoverForced: tile.flat ? false : tile.forceHover
        pressed: tile.pressed
        fillColor: tile.earlySkin ? tile.skinColors.bg : m.tileFill
        fillOpacity: tile.earlySkin ? 1.0 : m.tileFillOpacity
        glowRadius: 160
        glowStrength: tile.flat ? 0 : 0.107
        hoverPeak: tile.flat ? 0 : 0.50
        nearPeak: tile.flat ? 0 : 0.25
        borderWidth: tile.flat ? 0 : 3
        borderRadius: 115
        hoverBorderUniform: true
    }

    readonly property var iconRect: {
        if (!tileData || !tileData.iconRect)
            return null
        const r = tileData.iconRect
        return Array.isArray(r) ? { x: r[0], y: r[1], w: r[2], h: r[3] }
                                : { x: r.x, y: r.y, w: r.w, h: r.h }
    }
    // The small (1x1) tiles show a larger icon relative to their size than the
    // labelled ones. Both are fixed sizes of the mode's design (metrics.js),
    // not a fraction of the tile: a 2x2 tile is two cells plus the gap, so a
    // ratio would be off by that gap. The box handed to the renderer is
    // enlarged by the artwork's fill ratio, because icon themes pad their
    // bitmaps; a tile that carries a measured iconRect is drawn exactly as
    // measured and is not affected.
    readonly property int fallbackIconSize: m.iconBox
                                             ? m.iconBox(compact ? m.tileIconSizeSmall
                                                                 : m.tileIconSize,
                                                         iconFillRatio)
                                             : (compact ? m.tileIconSizeSmall
                                                        : m.tileIconSize)

    // The animated content lives inside a clipping box the size of the tile, so
    // nothing slides out of the tile (Windows clips its live content the same
    // way).
    Item {
        id: contentClip
        width: tile.width
        height: tile.height
        // Clipping is only needed while the content moves; keeping it off when
        // idle lets the scene graph batch all tiles into one draw call group.
        clip: tile.cycleActive && tile.cycleT < 1

        // The two contents are separate layers so a slide can move both at the
        // same time: the old one leaves while the new one follows right behind
        // it, with no empty gap in between (as Square Home's TranslateAnimation
        // pair does).
        Item {
            id: glyphLayer
            width: tile.width
            height: tile.height
            x: tile.layerOffset(false).x
            y: tile.layerOffset(false).y
            opacity: tile.layerOpacity(false)
            visible: tile.cycleActive
                     ? (!tile.cyclePhase || (tile.cycleKind === 0 && tile.cycleT < 1))
                     : !tile.hasLive

            // The two skins are mutually exclusive, so only the glyph of the
            // active skin is created: an early tile used to carry a modern
            // AppIcon too (and vice versa), each with its own icon items.
            Loader {
                // No anchors: the loaded glyph carries its own geometry
                // (iconRect or the fallback centre), and an anchored loader
                // would override it.
                active: tile.earlySkin && !!(tile.tileData && tile.tileData.icon)
                sourceComponent: TileGlyph {
                    iconSource: (tile.tileData && tile.tileData.icon) ? tile.tileData.icon : ""
                    // 1x1 tiles carry no visible label: fall back to the app id so the
                    // letter glyph still has something to show.
                    label: tile.labelLines.length > 0
                           ? String(tile.labelLines[0])
                           : (tileData ? String(tileData.desktopId || tileData.id || "") : "")
                    mode: tile.themedIcon === "color" ? "color"
                          : (tile.themedIcon === "letter" ? "letter" : "mono")
                    tint: tile.skinColors.fg
                    x: tile.iconRect ? tile.iconRect.x : Math.round((tile.width - tile.fallbackIconSize) / 2)
                    y: tile.iconRect ? tile.iconRect.y
                                     : Math.round((tile.height - tile.fallbackIconSize) / 2)
                    width: tile.iconRect ? tile.iconRect.w : tile.fallbackIconSize
                    height: tile.iconRect ? tile.iconRect.h : tile.fallbackIconSize
                }
            }
            Loader {
                active: !tile.earlySkin && !!(tile.tileData && tile.tileData.icon)
                sourceComponent: AppIcon {
                    source: (tile.tileData && tile.tileData.icon) ? tile.tileData.icon : ""
                    // The icon is centred in the tile whether or not it carries a label:
                    // measured on the reference, a labelled 150 px tile has its icon ink at
                    // 383..426 (centre 404.5) in a tile 330..479 (centre 404.5).
                    x: tile.iconRect ? tile.iconRect.x : Math.round((tile.width - tile.fallbackIconSize) / 2)
                    y: tile.iconRect ? tile.iconRect.y
                                     : Math.round((tile.height - tile.fallbackIconSize) / 2)
                    width: tile.iconRect ? tile.iconRect.w : tile.fallbackIconSize
                    height: tile.iconRect ? tile.iconRect.h : tile.fallbackIconSize
                }
            }
    
        }

        Item {
            id: liveLayer
            width: tile.width
            height: tile.height
            x: tile.layerOffset(true).x
            y: tile.layerOffset(true).y
            opacity: tile.layerOpacity(true)
            visible: tile.cycleActive
                     ? (tile.cyclePhase || (tile.cycleKind === 0 && tile.cycleT < 1))
                     : tile.hasLive

            // Only a tile that really carries live content owns a LiveTile:
            // its FolderListModel would hold an inotify instance and a thread
            // even for a tile that never shows one. `cycleActive` also keeps it
            // alive while the tile alternates between glyph and content.
            Loader {
                anchors.fill: parent
                active: tile.hasLive
                sourceComponent: LiveTile {
                    type: tile.liveType
                    homeDir: tile.homeDir
                    weatherSource: tile.weatherSource
                    textColor: tile.skinColors.fg
                    family: tile.m.fontFamily
                    bigSize: Math.round(Math.min(tile.width, tile.height) * 0.28)
                    smallSize: Math.round(Math.min(tile.width, tile.height) * 0.11)
                }
            }
        }
    }


    // The tile label does not move with the content: Windows keeps it pinned to
    // the tile while the live content cycles behind it.
    BaseText {
        visible: !tile.compact
        x: m.labelX
        baselineY: (tile.twoLines ? m.labelBaseline - m.labelLineGap : m.labelBaseline) - (hasCjk ? m.cjkBaselineShift : 0)
        text: tile.labelLines.length > 0 ? tile.labelLines[0] : ""
        color: tile.earlySkin ? tile.skinColors.fg : "#FFFFFF"
        pixelSize: m.labelSize
        family: m.fontFamily
        letterSpacing: hasCjk ? m.cjkLetterSpacing : 0
        maxWidth: tile.width - 2 * m.labelX
        elide: tile.twoLines ? Text.ElideNone : Text.ElideRight
    }

    BaseText {
        visible: !tile.compact
        x: m.labelX
        baselineY: m.labelBaseline - (hasCjk ? m.cjkBaselineShift : 0)
        text: tile.twoLines ? tile.labelLines[1] : ""
        color: tile.earlySkin ? tile.skinColors.fg : "#FFFFFF"
        pixelSize: m.labelSize
        family: m.fontFamily
        letterSpacing: hasCjk ? m.cjkLetterSpacing : 0
    }

    // Square Home's "pulse": a short pop when the live content changes.
    property real pulseLevel: 0
    NumberAnimation on pulseLevel {
        id: pulseAnim
        running: false
        from: 0; to: 1
        duration: 600
    }
    onCyclePhaseChanged: if (tile.pulseOnUpdate && tile.hasLive) {
        pulseLevel = 0
        pulseAnim.restart()
    }
    readonly property real pulseScale: {
        // 1 -> 1.1 in the first half, 1 -> 0.91 in the second
        if (!tile.pulseOnUpdate || tile.pulseLevel <= 0)
            return 1
        const t = tile.pulseLevel
        return t < 0.5 ? 1 + 0.1 * (t * 2) : 1 - 0.09 * ((t - 0.5) * 2)
    }

    // Dwell 4-6 s (Square Home's x() = rand(0..2500) + 3750), then a 2000 ms
    // swap on the D1 timeline.
    Timer {
        id: dwellTimer
        running: tile.cycleActive && !swapAnim.running && tile.visible
                 && !tile.dragActive
        repeat: true
        interval: 4000 + Math.random() * 2000
        onTriggered: {
            interval = 4000 + Math.random() * 2000
            var base = Math.floor(Math.random() * 8)
            if (tile.liveTileVariant === "slide")
                base = base % 4
            else if (tile.liveTileVariant === "flip")
                base = 4 + (base % 4)
            else if (tile.liveTileVariant === "persp")
                base = 8 + (base % 4)
            tile.cycleVariant = Motion.tileVariant(base, tile.width, tile.height,
                                                  tile.moreLiveAni)

            tile.swapFrom = tile.cyclePhase ? 1 : 0
            tile.cycleT = 0
            swapAnim.restart()
            midTimer.restart()
        }
    }
    Timer {
        id: midTimer
        interval: 1000
        onTriggered: tile.cyclePhase = !tile.cyclePhase
    }
    NumberAnimation {
        id: swapAnim
        target: tile
        property: "cycleT"
        from: 0
        to: 1
        duration: 2000
        easing.type: Easing.Linear
    }

    // No HoverHandler here: see the `hovered` property above. Hover follows the
    // pointer the view already tracks, which keeps the per-tile object count
    // down and the pointer tracking cheap.

    TapHandler {
        enabled: tile.interactive && !tile.pointerBlocked
        onPressedChanged: tile.pressed = pressed
        onCanceled: tile.pressed = false
        onTapped: tile.activated(tile.tileData)
    }

    TapHandler {
        acceptedButtons: Qt.RightButton
        enabled: tile.interactive && !tile.pointerBlocked
        onPressedChanged: {
            // The reference answers a right press exactly like a left one:
            // highlight, frame, ripple, then the menu on release.
            tile.pressed = pressed
            if (pressed)
                tile.contextPoint = Qt.point(point.scenePosition.x, point.scenePosition.y)
        }
        onCanceled: tile.pressed = false
        onTapped: tile.contextRequested(tile.tileData,
                                        tile.contextPoint.x, tile.contextPoint.y)
    }

    DragHandler {
        id: tileDrag
        enabled: tile.interactive && !tile.pointerBlocked
        // Never let the handler move the tile itself: its position belongs to
        // the layout (an assigned x/y would break the binding for good).
        target: null
        dragThreshold: 6
        grabPermissions: PointerHandler.CanTakeOverFromAnything
        onActiveChanged: {
            if (active) {
                tile.dragging = true
                tile.dragStarted()
            } else if (tile.dragging) {
                tile.dragging = false
                tile.dragFinished()
            }
        }
        // The handler owns the pointer during the drag, so it is the reliable
        // source for the ghost position (the hover handler may not follow).
        onCentroidChanged: {
            if (tile.dragging)
                tile.dragPointer(tileDrag.centroid.scenePosition.x,
                                 tileDrag.centroid.scenePosition.y)
        }
    }
}
