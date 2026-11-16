// A single tile: translucent fill, icon, labels and the Fluent reveal
// border/glow that follows the pointer.
import QtQuick
import "metrics.js" as Metrics

Item {
    id: tile
    property var tileData: null
    property real pointerX: -1
    property real pointerY: -1
    property bool pointerInside: false
    property bool hoverInjected: false
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
        NumberAnimation { duration: Metrics.reflowDuration; easing.type: Easing.OutCubic }
    }
    Behavior on targetY {
        enabled: tile.animatePosition
        NumberAnimation { duration: Metrics.reflowDuration; easing.type: Easing.OutCubic }
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
    // The dim fades in and out with the same curve as the shrink, so picking a
    // tile up dims and pulls the others back in one motion.
    Behavior on dim {
        NumberAnimation { duration: Metrics.dragDimDuration; easing.type: Easing.OutCubic }
    }
    Behavior on shrink {
        NumberAnimation { duration: Metrics.dragShrinkDuration; easing.type: Easing.OutCubic }
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
             * switchOpacity * dim
    property bool forceHover: false
    signal activated(var entry)

    width: tileData ? tileData.w : 0
    height: tileData ? tileData.h : 0

    // Pressed: the whole tile (surface, icon and label) shrinks by a couple of
    // percent about its own centre and grows back over a few frames. While
    // another tile is dragged every tile recedes a little the same way.
    transform: [
        Scale {
            origin.x: tile.width / 2
            origin.y: tile.height / 2
            xScale: 1 - Metrics.pressScale * surface.pressLevel
            yScale: 1 - Metrics.pressScale * surface.pressLevel
        },
        Scale {
            origin.x: tile.width / 2
            origin.y: tile.height / 2
            xScale: tile.shrink
            yScale: tile.shrink
        }
    ]

    // Small (1x1) tiles carry no label: the icon sits in the middle instead.
    readonly property bool compact: Metrics.cell * 1.5 > width && width > 0
    readonly property var labelLines: {
        if (compact || !tileData || !tileData.label)
            return []
        return typeof tileData.label === "string" ? [tileData.label] : tileData.label
    }
    readonly property bool twoLines: labelLines.length > 1

    readonly property bool hovered: forceHover || hover.hovered
    readonly property real localX: pointerX - x
    readonly property real localY: pointerY - y + scrollOffset

    // Tile surface: translucent fill, interior reveal glow and the 3 px border.
    RevealRect {
        id: surface
        anchors.fill: parent
        pointerX: tile.localX
        pointerY: tile.localY
        pointerInside: tile.pointerInside
        hovered: tile.flat ? false : tile.hovered
        pressed: tile.pressed
        fillColor: Metrics.tileFill
        fillOpacity: Metrics.tileFillOpacity
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
    // 1x1 tiles have no label, so the icon fills about two thirds of the tile
    // (matches the reference), the labelled tiles keep their smaller icon.
    readonly property int fallbackIconSize: Math.round(Math.min(width, height)
                                                       * (compact ? 0.66
                                                                  : (labelLines.length > 0 ? 0.42 : 0.5)))

    AppIcon {
        visible: !!(tile.tileData && tile.tileData.icon)
        source: (tile.tileData && tile.tileData.icon) ? tile.tileData.icon : ""
        x: tile.iconRect ? tile.iconRect.x : Math.round((tile.width - tile.fallbackIconSize) / 2)
        y: tile.iconRect ? tile.iconRect.y
                         : (tile.labelLines.length > 0
                            ? Math.round((tile.height - 34 - tile.fallbackIconSize) / 2)
                            : Math.round((tile.height - tile.fallbackIconSize) / 2))
        width: tile.iconRect ? tile.iconRect.w : tile.fallbackIconSize
        height: tile.iconRect ? tile.iconRect.h : tile.fallbackIconSize
    }

    BaseText {
        visible: !tile.compact
        x: Metrics.labelX
        baselineY: (tile.twoLines ? Metrics.labelBaseline - Metrics.labelLineGap : Metrics.labelBaseline) - (hasCjk ? Metrics.cjkBaselineShift : 0)
        text: tile.labelLines.length > 0 ? tile.labelLines[0] : ""
        pixelSize: Metrics.labelSize
        family: Metrics.fontFamily
        letterSpacing: hasCjk ? Metrics.cjkLetterSpacing : 0
        maxWidth: tile.width - 2 * Metrics.labelX
        elide: tile.twoLines ? Text.ElideNone : Text.ElideRight
    }

    BaseText {
        visible: !tile.compact
        x: Metrics.labelX
        baselineY: Metrics.labelBaseline - (hasCjk ? Metrics.cjkBaselineShift : 0)
        text: tile.twoLines ? tile.labelLines[1] : ""
        pixelSize: Metrics.labelSize
        family: Metrics.fontFamily
        letterSpacing: hasCjk ? Metrics.cjkLetterSpacing : 0
    }

    HoverHandler {
        id: hover
        enabled: tile.interactive && !tile.hoverInjected
    }

    TapHandler {
        enabled: tile.interactive
        onPressedChanged: tile.pressed = pressed
        onCanceled: tile.pressed = false
        onTapped: tile.activated(tile.tileData)
    }

    DragHandler {
        id: tileDrag
        enabled: tile.interactive
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
