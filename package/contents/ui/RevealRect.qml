// The Fluent "Reveal" rectangle shared by every interactive surface of the
// menu: tiles, sidebar buttons, application list entries/letters and the
// capital view cells.
//
// It draws, bottom to top:
//   1. an optional flat fill,
//   2. an optional interior glow around the pointer (when hovered),
//   3. a 3 px border whose brightness follows the 2D distance to the pointer,
//      so only the part of the outline near the pointer is visible.
//
// Controls only differ in the numbers they pass, never in the drawing code.
import QtQuick
import "metrics.js" as Metrics

Item {
    id: root

    // Pointer position in this item's local coordinates.
    property real pointerX: -1
    property real pointerY: -1
    property bool pointerInside: false
    // Hovering can be derived from the pointer position alone: the list holds
    // hundreds of entries and a HoverHandler per entry makes pointer tracking
    // crawl. Controls that cannot use the pointer (e.g. keyboard focus) set
    // `hovered` explicitly. `pointerDriven` controls compute it themselves.
    property bool pointerDriven: false
    property bool hovered: false
    readonly property bool isHovered: pointerDriven
                                      ? (pointerInside && pointerX >= 0 && pointerY >= 0
                                         && pointerX < width && pointerY < height)
                                      : hovered

    property color fillColor: "#FFFFFF"
    property real fillOpacity: 0            // always-on fill (tiles)
    property real hoverFillOpacity: 0       // extra fill while hovered
    property real glowStrength: 0           // interior glow while hovered
    property real glowRadius: 240

    property real hoverPeak: 0.30           // border alpha when hovered
    property real nearPeak: 0.10            // border alpha while only near
    property real borderRadius: 115         // falloff radius of the border light
    property int borderWidth: 3
    // Tiles get a flat outline while hovered; other surfaces keep the radial
    // falloff (Windows draws the tile selection as a solid frame).
    property bool hoverBorderUniform: false

    // Only controls close to the pointer get a border instance at all. The
    // list can hold hundreds of entries, so creating the gradient edges for
    // every one of them would make pointer tracking crawl.
    property real nearRadius: 160

    readonly property real centerX: width / 2
    readonly property real centerY: height / 2
    readonly property bool nearPointer: pointerInside
                                        && Math.abs(pointerX - centerX) < nearRadius + width / 2
                                        && Math.abs(pointerY - centerY) < nearRadius + height / 2

    readonly property bool lit: hovered || pointerInside
    readonly property bool borderWanted: borderWidth > 0 && (isHovered ? hoverPeak > 0 : nearPeak > 0)
                                        && (isHovered || nearPointer)

    // Hover transitions: the highlight reaches ~76 % one frame (16.7 ms) after
    // it starts and ~96 % after two, i.e. a ~45 ms ease-out cubic.
    Rectangle {
        anchors.fill: parent
        color: root.fillColor
        opacity: root.fillOpacity + (root.isHovered ? root.hoverFillOpacity : 0)
        Behavior on opacity {
            NumberAnimation { duration: Metrics.hoverDuration; easing.type: Easing.OutCubic }
        }
    }

    RevealGlow {
        anchors.fill: parent
        radius: root.glowRadius
        localX: root.pointerX
        localY: root.pointerY
        strength: root.isHovered ? root.glowStrength : 0
        Behavior on strength {
            NumberAnimation { duration: Metrics.hoverDuration; easing.type: Easing.OutCubic }
        }
    }

    Loader {
        anchors.fill: parent
        active: root.borderWanted
        sourceComponent: borderComponent
    }

    Component {
        id: borderComponent
        RevealBorder {
            pointerX: root.pointerX
            pointerY: root.pointerY
            peak: root.isHovered ? root.hoverPeak : root.nearPeak
            Behavior on peak {
                NumberAnimation { duration: Metrics.hoverDuration; easing.type: Easing.OutCubic }
            }
            radius: root.borderRadius
            thickness: root.borderWidth
            uniform: root.isHovered && root.hoverBorderUniform
            visible: true
        }
    }

}