// The Fluent "Reveal" rectangle shared by every interactive surface of the
// menu: tiles, sidebar buttons, application list entries/letters and the
// capital view cells.
//
// It draws, bottom to top:
//   1. an optional flat fill (inset by the frame width while pressed),
//   2. an optional interior glow around the pointer (when hovered),
//   3. a 2 px border whose brightness follows the 2D distance to the pointer,
//      so only the part of the outline near the pointer is visible (a flat
//      frame while pressed),
//   4. the press ripple, a radial glow blooming out of the press point.
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

    // --- press ------------------------------------------------------------
    // The reference answers a press by turning the pointer-driven reveal into
    // a flat frame, insetting the surface by the frame width and blooming a
    // ripple out of the press point; on release the frame and the ripple fade
    // and the reveal stays off until the pointer leaves (the reference does not
    // re-light a control that was just clicked).
    property bool pressed: false
    property real pressX: -1        // press point, local coordinates
    property real pressY: -1
    // The pressed look is *not* the hover look: the bright reveal frame drops to
    // the faint searchlight shade of an untouched tile (same width, pointer
    // falloff) and a ripple blooms out of the press point until it covers the
    // control. The surface itself keeps its normal shade everywhere the ripple
    // has not reached yet.
    property real pressFramePeak: Metrics.pressFramePeak
    property real pressRipple: Metrics.pressRippleStrength
    // The ripple fills the control: its full radius is half the diagonal, so
    // `rippleT == 1` just covers the surface. Pressing starts at 40 % of that
    // (about a quarter of the tile's area) and releasing throws it a little
    // past the edges.
    property real pressRippleRadius: Math.hypot(width, height) / 2
    property bool hoverSuppressed: false

    readonly property bool showHover: isHovered && !hoverSuppressed && !pressedFrame
    readonly property bool pressedFrame: pressLevel > 0.004

    property real pressAmount: 0
    onPressedChanged: {
        pressAmount = pressed ? 1 : 0
        if (pressed) {
            // Freeze the press point: the ripple keeps blooming from where the
            // button went down even if the pointer moves afterwards.
            pressX = pointerX
            pressY = pointerY
            rippleFadeOut.stop()
            rippleRelease.stop()
            rippleT = Metrics.pressRippleStart
            rippleFade = 1
            rippleHold.restart()
        } else {
            // Letting go of the button throws the wave out the rest of the way
            // and fades it, which is the fast bloom of the reference.
            rippleHold.stop()
            rippleRelease.restart()
            rippleFadeOut.restart()
            // Released: the reveal stays off until the pointer leaves (see
            // onIsHoveredChanged), like the reference after a click.
            hoverSuppressed = true
        }
    }
    // A control that was just clicked stays unlit until the pointer leaves it.
    onIsHoveredChanged: if (!isHovered) hoverSuppressed = false
    Behavior on pressAmount {
        NumberAnimation { duration: root.pressed ? Metrics.pressInDuration : Metrics.pressOutDuration
                          easing.type: Easing.OutCubic }
    }
    // Ripple: the radial texture of the hover glow, scaled from the press point.
    // While the button is held `rippleT` crawls towards the control's size; on
    // release it runs the rest of the way fast. `rippleFade` drops the whole
    // thing once the button is up, and the strength falls as the wave grows, so
    // the ripple gets bigger and fainter at the same time.
    property real rippleT: 0
    // 0 until the first press; the release lets it fall back to 0 once the wave
    // has crossed the control.
    property real rippleFade: 0
    // Harness overrides (-1 keeps the animated values), used by the render
    // tools to capture a single frame of the press.
    property real debugPressAmount: -1
    property real debugRippleScale: -1
    readonly property real pressLevel: debugPressAmount >= 0 ? debugPressAmount : pressAmount
    readonly property real rippleLevel: debugRippleScale >= 0 ? debugRippleScale : rippleT
    readonly property real rippleRadiusNow: pressRippleRadius * rippleLevel
    readonly property real rippleStrengthNow: pressRipple * rippleFade
                                              * (1 - 0.35 * Math.min(rippleLevel, 1.2))
    NumberAnimation {
        id: rippleHold
        target: root
        property: "rippleT"
        to: Metrics.pressRippleHoldEnd
        duration: Metrics.pressRippleHoldDuration
        easing.type: Easing.Linear
    }
    NumberAnimation {
        id: rippleRelease
        target: root
        property: "rippleT"
        to: Metrics.pressRippleReleaseEnd
        duration: Metrics.pressRippleReleaseDuration
        easing.type: Easing.OutCubic
    }
    // The wave stays at full strength while it crosses the control (the release
    // bloom) and only fades once it has arrived.
    SequentialAnimation {
        id: rippleFadeOut
        PauseAnimation { duration: Metrics.pressRippleHoldFadeDelay }
        NumberAnimation { target: root
                          property: "rippleFade"
                          to: 0.0
                          duration: Metrics.pressRippleFadeDuration
                          easing.type: Easing.OutCubic }
    }

    property color fillColor: "#FFFFFF"
    property real fillOpacity: 0            // always-on fill (tiles)
    property real hoverFillOpacity: 0       // extra fill while hovered
    property real glowStrength: 0           // interior glow while hovered
    property real glowRadius: 240

    property real hoverPeak: 0.30           // border alpha when hovered
    property real nearPeak: 0.10            // border alpha while only near
    property real borderRadius: 115         // falloff radius of the border light
    property int borderWidth: 2
    // Tiles get a flat outline while hovered; other surfaces keep the radial
    // falloff (Windows draws the tile selection as a solid frame).
    property bool hoverBorderUniform: false

    // Only controls close to the pointer get a border instance at all. The
    // list can hold hundreds of entries, so creating the gradient edges for
    // every one of them would make pointer tracking crawl.
    property real nearRadius: 160

    readonly property real centerX: width / 2
    readonly property real centerY: height / 2
    readonly property bool nearPointer: !hoverSuppressed && pointerInside
                                        && Math.abs(pointerX - centerX) < nearRadius + width / 2
                                        && Math.abs(pointerY - centerY) < nearRadius + height / 2

    readonly property bool lit: showHover || pointerInside
    readonly property bool borderWanted: borderWidth > 0
                                        && (pressedFrame
                                            || ((showHover ? hoverPeak > 0 : nearPeak > 0)
                                                && (showHover || nearPointer)))

    // Hover transitions: the highlight reaches ~76 % one frame (16.7 ms) after
    // it starts and ~96 % after two, i.e. a ~45 ms ease-out cubic.
    Rectangle {
        anchors.fill: parent
        color: root.fillColor
        // Pressing does not tint a tile: only the ripple brightens it, so the part
        // the wave has not reached keeps its normal shade.
        opacity: root.fillOpacity + (root.showHover ? root.hoverFillOpacity : 0)
        Behavior on opacity {
            NumberAnimation { duration: Metrics.hoverDuration; easing.type: Easing.OutCubic }
        }
    }

    RevealGlow {
        anchors.fill: parent
        radius: root.glowRadius
        localX: root.pointerX
        localY: root.pointerY
        strength: root.showHover ? root.glowStrength : 0
        Behavior on strength {
            NumberAnimation { duration: Metrics.hoverDuration; easing.type: Easing.OutCubic }
        }
    }

    // Press ripple: blooms out of the press point while the control is held and
    // fades with the press.
    RevealGlow {
        anchors.fill: parent
        radius: root.rippleRadiusNow
        localX: root.pressX >= 0 ? root.pressX : root.centerX
        localY: root.pressY >= 0 ? root.pressY : root.centerY
        // Not gated by pressLevel: the wave keeps going after the button is up.
        strength: root.rippleStrengthNow
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
            peak: root.pressedFrame ? root.pressFramePeak * root.pressLevel
                                    : (root.showHover ? root.hoverPeak : root.nearPeak)
            Behavior on peak {
                NumberAnimation { duration: Metrics.hoverDuration; easing.type: Easing.OutCubic }
            }
            radius: root.borderRadius
            thickness: root.borderWidth
            // Pressed keeps the searchlight falloff of an untouched tile: only
            // the part of the outline near the pointer lights up, faintly.
            uniform: root.pressedFrame ? false : (root.showHover && root.hoverBorderUniform)
            visible: true
        }
    }

}