// Thin scroll indicator: invisible by default, shown while the content is
// scrolling, faded out shortly after it stops (Windows behaves the same for the
// tile area and both application lists).
import QtQuick
import "metrics.js" as Metrics

Item {
    id: root

    // Geometry of the scrolled content (set by the view).
    property real contentY: 0
    property real contentHeight: 1
    property real viewHeight: 1
    // Height of the scrolling area on screen (`height` is bound to it too).
    property real thinWidth: 2
    property real wideWidth: 18
    property real rightInset: 3
    property color color: "#FFFFFF"

    // Show-on-scroll state: 1 right after a scroll, 0 after the idle delay.
    property real activity: 0
    // Easing shared with the sidebar open/close.
    readonly property int morphDuration: Metrics.sidebarOpenDuration > 0
                                         ? Metrics.sidebarOpenDuration : 260
    // Pointer resting on the scrollbar (makes it wide, as in the reference).
    property bool hovered: false

    readonly property bool scrollable: contentHeight > viewHeight + 1
    readonly property real maxScroll: Math.max(1, contentHeight - viewHeight)
    readonly property real thumbHeight: Math.max(40, viewHeight * viewHeight
                                                  / Math.max(1, contentHeight))
    readonly property real thumbY: Math.min(viewHeight - thumbHeight,
                                            Math.max(0, contentY / maxScroll
                                                     * (viewHeight - thumbHeight)))
    readonly property bool shown: scrollable && (activity > 0.001 || hovered)

    visible: shown
    // 0 = thin indicator, 1 = wide draggable bar. Animated with the same easing
    // as the sidebar so the change is an expand/contract, never a jump.
    property real wide: hovered ? 1 : 0
    Behavior on wide {
        NumberAnimation { duration: root.morphDuration; easing.type: Easing.OutQuint }
    }
    // `wide` also carries the opacity change (0.60 thin / 0.41 wide), while
    // `activity` fades the indicator out - the two must not fight each other,
    // so opacity is a single binding and only `activity` is animated.
    opacity: (0.6 - 0.19 * wide) * (hovered ? 1 : activity)
    width: thinWidth + (wideWidth - thinWidth) * wide
    // `edgeInset` pushes the bar outside the view (into the panel's margin) so
    // it never sits on top of the last tile column.
    property real edgeInset: 0
    x: parent ? parent.width + edgeInset - rightInset - width : 0
    height: parent ? parent.height : 0
    z: 10

    // Gutter behind the thumb while the pointer rests on the scrollbar.
    Rectangle {
        anchors.fill: parent
        visible: root.hovered
        color: "#FFFFFF"
        opacity: 0.10
    }
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        y: root.thumbY
        height: root.thumbHeight
        color: root.color
    }

    onContentYChanged: {
        if (!scrollable)
            return
        activity = 1
        idleTimer.restart()
    }
    // Leaving the bar after a drag: shrink back to the thin indicator and only
    // fade out after the idle delay (never disappear on the spot).
    onHoveredChanged: {
        if (!hovered && scrollable) {
            activity = 1
            idleTimer.restart()
        }
    }

    Timer {
        id: idleTimer
        interval: 1300
        onTriggered: fadeOut.restart()
    }
    NumberAnimation {
        id: fadeOut
        target: root
        property: "activity"
        to: 0
        duration: 150
        easing.type: Easing.OutQuad
    }
}