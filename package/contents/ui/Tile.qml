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
    property bool forceHover: false
    signal activated(var entry)

    width: tileData ? tileData.w : 0
    height: tileData ? tileData.h : 0
    x: tileData ? tileData.x : 0
    y: tileData ? tileData.y : 0

    readonly property var labelLines: {
        if (!tileData || !tileData.label)
            return []
        return typeof tileData.label === "string" ? [tileData.label] : tileData.label
    }
    readonly property bool twoLines: labelLines.length > 1

    readonly property bool hovered: forceHover || hover.hovered
    readonly property real localX: pointerX - x
    readonly property real localY: pointerY - y

    // Tile surface: translucent fill, interior reveal glow and the 3 px border.
    RevealRect {
        anchors.fill: parent
        pointerX: tile.localX
        pointerY: tile.localY
        pointerInside: tile.pointerInside
        hovered: tile.hovered
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
    readonly property int fallbackIconSize: Math.round(Math.min(width, height)
                                                       * (labelLines.length > 0 ? 0.42 : 0.5))

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
        onTapped: tile.activated(tile.tileData)
    }
}
