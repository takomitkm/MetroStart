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

    // Ease-out quintic: the velocity keeps falling all the way to the end, so
    // each tile coasts into its final size instead of stopping abruptly.
    function ease(t) {
        const v = Math.max(0, Math.min(1, t))
        return 1 - Math.pow(1 - v, entranceCurve)
    }
    readonly property real entranceEase: ease(entrance)

    readonly property real targetX: tileData ? tileData.x : 0
    readonly property real targetY: tileData ? tileData.y : 0

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
             * switchOpacity
    property bool forceHover: false
    signal activated(var entry)

    width: tileData ? tileData.w : 0
    height: tileData ? tileData.h : 0

    // Pressed: the whole tile (surface, icon and label) shrinks by a couple of
    // percent about its own centre and grows back over a few frames.
    transform: Scale {
        origin.x: tile.width / 2
        origin.y: tile.height / 2
        xScale: 1 - Metrics.pressScale * surface.pressLevel
        yScale: 1 - Metrics.pressScale * surface.pressLevel
    }

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
    readonly property real localY: pointerY - y

    // Tile surface: translucent fill, interior reveal glow and the 3 px border.
    RevealRect {
        id: surface
        anchors.fill: parent
        pointerX: tile.localX
        pointerY: tile.localY
        pointerInside: tile.pointerInside
        hovered: tile.hovered
        pressed: tile.pressed
        fillColor: Metrics.tileFill
        fillOpacity: Metrics.tileFillOpacity
        glowRadius: 160
        glowStrength: 0.107
        hoverPeak: 0.50
        nearPeak: 0.25
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
        enabled: !tile.hoverInjected
    }

    TapHandler {
        onPressedChanged: tile.pressed = pressed
        onCanceled: tile.pressed = false
        onTapped: tile.activated(tile.tileData)
    }
}
