// Application list of the non-fullscreen Start menu: one column with a
// "最近添加" section followed by one section per letter. Rows are 54 px tall,
// the hover highlight matches the fullscreen list (RevealRect: fill, interior
// glow and a 2 px frame) and the scrollbar expands under the pointer.
import QtQuick
import "metrics.js" as Metrics
import "CompactMetrics.js" as Compact

Item {
    id: root

    // [{ key: "recent", title: "最近添加" }, { key: "letter", letter: "A" },
    //  ... ] with `entries` on each section.
    property var sections: []
    property real pointerX: -1
    property real pointerY: -1
    property bool pointerInside: false
    property bool hoverInjected: false
    // The sidebar / flyout own the pointer while they are up.
    property bool pointerBlocked: false
    property color accentColor: Metrics.accentColorDefault
    property var pressedEntry: null
    property real pressedRowLevel: 0

    readonly property real scrollPosition: flick.contentY
    signal entryActivated(var entry)
    signal entryContextRequested(var entry, real sceneX, real sceneY)

    readonly property real rowHeight: Compact.listRowHeight
    readonly property real listTop: Compact.panelTopPadding
    readonly property real rowX: Compact.listRowInsetLeft
    readonly property real rowWidth: width - Compact.listRowInsetLeft
                                          - Compact.listRowInsetRight

    // Flattened rows: header rows and entry rows share one list so scrolling
    // and hit testing stay simple.
    readonly property var rows: {
        var out = []
        for (var i = 0; i < sections.length; ++i) {
            var s = sections[i]
            if (s.title !== undefined && s.title !== "")
                out.push({ kind: "header", title: s.title, section: i })
            else if (s.letter !== undefined)
                out.push({ kind: "letter", title: s.letter, section: i })
            var entries = s.entries || []
            for (var k = 0; k < entries.length; ++k)
                out.push({ kind: "entry", entry: entries[k], section: i })
        }
        return out
    }
    readonly property real contentHeight: listTop + rows.length * rowHeight

    function rowAt(y) {
        var local = y - listTop
        if (local < 0)
            return -1
        var i = Math.floor(local / rowHeight)
        return (i >= 0 && i < rows.length) ? i : -1
    }

    readonly property int hoverRow: {
        // The pointer must be inside the list itself: hovering the tile area
        // (right of the list) must not highlight a row, and an expanded sidebar
        // or an open flyout takes the pointer away.
        if (pointerBlocked || !pointerInside || pointerX < 0 || pointerX >= width
                || pointerY === undefined || pointerY < 0)
            return -1
        return rowAt(flick.contentY + pointerY)
    }

    // Scrollbar state: the gutter only shows while the pointer is inside the
    // list; the thumb is thin unless the pointer is on the scrollbar itself.
    property bool barHovered: pointerInside && pointerX >= width - 19 && pointerX <= width
    readonly property bool barActive: pointerInside && contentHeight > height + 1

    function resetScroll() {
        flick.contentY = 0
        pressedEntry = null
        pressedRowLevel = 0
    }

    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: Math.max(root.contentHeight, root.height)
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        // One highlight for the row under the pointer, drawn under the rows
        // (same look as the fullscreen application list).
        RevealRect {
            id: rowHighlight
            visible: root.hoverRow >= 0 && root.rows[root.hoverRow]
                     && root.rows[root.hoverRow].kind === "entry"
                     && root.pressedEntry === null
            x: root.rowX
            y: root.listTop + (root.hoverRow >= 0 && root.rows[root.hoverRow]
               ? root.hoverRow * root.rowHeight : 0)
            width: root.rowWidth
            height: root.rowHeight
            transform: Scale {
                origin.x: rowHighlight.width / 2
                origin.y: rowHighlight.height / 2
                xScale: 1 - Metrics.pressScale * root.pressedRowLevel
                yScale: 1 - Metrics.pressScale * root.pressedRowLevel
            }
            pointerX: root.pointerX - x
            pointerY: root.pointerY + flick.contentY - y
            pointerInside: root.pointerInside
            hovered: true
            hoverFillOpacity: 0.13
            glowRadius: 220
            glowStrength: 0.08
            hoverPeak: 0
            nearPeak: 0
            borderWidth: 0
            z: -1
        }

        Repeater {
            model: root.rows
            delegate: Item {
                id: rowItem
                required property var modelData
                required property int index
                y: root.listTop + index * root.rowHeight
                width: root.width
                height: root.rowHeight

                // Section title ("最近添加") and the letter headers.
                BaseText {
                    visible: modelData.kind === "header" || modelData.kind === "letter"
                    x: modelData.kind === "header" ? Compact.listHeaderX
                                                   : Compact.listLetterX
                    baselineY: Compact.listHeaderBaseline
                    text: modelData.title !== undefined ? modelData.title : ""
                    family: Metrics.fontFamily
                    pixelSize: Compact.listTextSize
                    letterSpacing: hasCjk ? Metrics.cjkLetterSpacing : 0
                    color: "#FFFFFF"
                }

                AppIcon {
                    visible: modelData.kind === "entry"
                    x: Compact.listIconX
                    y: Math.round((parent.height - Compact.listIconSize) / 2)
                    width: Compact.listIconSize
                    height: Compact.listIconSize
                    size: Compact.listIconSize
                    source: modelData.kind === "entry" && modelData.entry ? modelData.entry.icon : ""
                }

                BaseText {
                    visible: modelData.kind === "entry"
                    x: Compact.listTextX
                    baselineY: Compact.listTextBaseline
                    text: modelData.kind === "entry" && modelData.entry ? modelData.entry.name : ""
                    family: Metrics.fontFamily
                    pixelSize: Compact.listTextSize
                    letterSpacing: hasCjk ? Metrics.cjkLetterSpacing : 0
                    color: "#FFFFFF"
                    maxWidth: root.rowWidth - Compact.listTextX - 30
                    elide: Text.ElideRight
                }

                Image {
                    visible: modelData.kind === "entry" && modelData.entry
                             && !!modelData.entry.folder
                    x: root.rowWidth - 24
                    y: Math.round((parent.height - 8) / 2)
                    width: 15
                    height: 8
                    source: Qt.resolvedUrl("../assets/ui/chevron.png")
                    smooth: true
                    opacity: 0.6
                }

                property bool pressed: false
                TapHandler {
                    // Pointer handlers are passive: an item below the pointer
                    // still gets the click, so the rows have to switch off while
                    // the sidebar or a flyout owns that area.
                    enabled: modelData.kind === "entry" && !root.pointerBlocked
                    onPressedChanged: rowItem.pressed = pressed
                    onCanceled: rowItem.pressed = false
                    onTapped: if (modelData.kind === "entry")
                                  root.entryActivated(modelData.entry)
                }
                TapHandler {
                    acceptedButtons: Qt.RightButton
                    enabled: modelData.kind === "entry" && !root.pointerBlocked
                    property point scenePoint: Qt.point(0, 0)
                    onPressedChanged: if (pressed)
                                          scenePoint = Qt.point(point.scenePosition.x,
                                                                point.scenePosition.y)
                    onTapped: if (modelData.kind === "entry")
                                  root.entryContextRequested(modelData.entry,
                                                             scenePoint.x, scenePoint.y)
                }
            }
        }
    }

    // --- scrollbar -----------------------------------------------------
    // The gutter only appears while the pointer is on the scrollbar; otherwise
    // the list shows just the thin indicator (measured on app-entry-hover.png
    // vs all-app-scroll-bar.png).
    Rectangle {
        objectName: "scrollGutter"
        visible: root.barActive && root.barHovered
        x: root.width - 19
        y: 0
        width: 18
        height: root.height
        color: "#FFFFFF"
        opacity: 0.10
    }
    Rectangle {
        objectName: "scrollThumb"
        visible: root.barActive
        x: root.width - 6
        y: Math.max(0, flick.contentY / Math.max(1, root.contentHeight) * root.height)
        width: 2
        height: Math.max(40, flick.height * flick.height / Math.max(1, root.contentHeight))
        color: "#FFFFFF"
        opacity: 0.6
        // Expanded while the pointer is on the scrollbar (all-app-scroll-bar.png).
        property bool wide: root.barHovered
        states: State {
            name: "wide"
            when: rowThumb.wide
            PropertyChanges {
                target: rowThumb
                x: root.width - 19
                width: 18
                opacity: 0.41
            }
        }
        transitions: Transition {
            NumberAnimation { properties: "x,width,opacity"; duration: 150
                              easing.type: Easing.OutCubic }
        }
        id: rowThumb
    }
    MouseArea {
        objectName: "scrollGrab"
        visible: root.barActive
        enabled: !root.pointerBlocked
        x: root.width - 19
        y: 0
        width: 18
        height: root.height
        acceptedButtons: Qt.LeftButton
        onPressed: (mouse) => {
            if (rowThumb.y <= mouse.y && mouse.y <= rowThumb.y + rowThumb.height) {
                dragStart = mouse.y - rowThumb.y
            } else {
                dragStart = rowThumb.height / 2
                scrollTo(mouse.y - dragStart)
            }
        }
        onPositionChanged: (mouse) => {
            if (pressed)
                scrollTo(mouse.y - dragStart)
        }
        property real dragStart: 0
        function scrollTo(thumbY) {
            var span = Math.max(1, root.height - rowThumb.height)
            var maxContent = Math.max(1, root.contentHeight - flick.height)
            flick.contentY = Math.max(0, Math.min(maxContent,
                                                  thumbY / span * maxContent))
        }
    }
}
