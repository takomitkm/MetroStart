// "All applications": three columns, letter sections, scrolling.
import QtQuick
import "metrics.js" as Metrics
import "motion.js" as Motion

Item {
    id: root
    property var sections: []
    property real pointerX: -1
    property real pointerY: -1
    // Horizontal shift of the whole list: the canvas is wider than the
    // reference design when it has to hold more tile columns, the list stays
    // centred on the design instead of drifting left.
    property real contentOffsetX: 0
    property bool pointerInside: false
    property bool hoverInjected: false
    property string hoveredEntry: ""
    property string debugHoverControl: ""
    // Harness hook: scroll position in content coordinates (-1 = untouched).
    property real scrollY: -1
    onScrollYChanged: if (scrollY >= 0) flick.contentY = scrollY
    // Current scroll offset, exposed for tests and the capital view.
    readonly property real scrollPosition: flick.contentY
    signal entryActivated(var entry)
    signal entryContextRequested(var entry, real sceneX, real sceneY)
    // While a context menu is open the popup owns the pointer: no entry reacts,
    // except the one whose menu it is (it keeps the shared highlight).
    property bool pointerBlocked: false
    // The popup is open: entries stop highlighting, but keep answering clicks.
    property bool hoverBlocked: false
    property var forcedEntry: null
    signal lettersRequested()

    // The row that was just clicked: its highlight stays off until the pointer
    // moves to another row (a pressed control is not re-lit, see RevealRect).
    property var pressedEntry: null
    // Press progress of the row under the finger. The shared highlight covers the
    // same rect as the entry, so scaling both by the same factor keeps the fill
    // inside the shrunken entry.
    property real pressedRowLevel: 0
    onHoverInfoChanged: if (pressedEntry !== null
                            && (hoverInfo === null || hoverInfo.entry !== pressedEntry))
                            pressedEntry = null

    // Switch entrance (all applications <-> tiles): every row is pushed up from
    // below while it fades in, the top rows leading. See motion.js.
    property real switchProgress: 1

    function switchRise(y) {
        return Motion.switchRise(switchProgress, y, contentHeight)
    }

    function switchFade(y) {
        return Motion.switchFade(switchProgress, y, Metrics.appTop, contentHeight)
    }

    // Back to the state the menu always opens in: top of the list, nothing
    // pressed. Called when the menu is closed (see MetroMenu.reset).
    function resetScroll() {
        flick.contentY = 0
        pressedEntry = null
        pressedRowLevel = 0
    }

    // Put the section for `letter` at the top of the viewport (used by the
    // capital view). "clock" means "top of the list".
    function scrollToLetter(letter) {
        if (letter === "clock") {
            flick.contentY = 0
            return
        }
        for (var i = 0; i < sections.length; ++i) {
            if (sections[i].letter === letter) {
                const top = Math.max(0, sections[i].y - Metrics.appTop)
                const target = Math.min(top, Math.max(0, flick.contentHeight - flick.height))
                flick.contentY = isFinite(target) ? target : 0
                return
            }
        }
    }

    function lettersList() {
        var out = []
        for (var i = 0; i < sections.length; ++i)
            out.push(sections[i].letter)
        return out
    }

    // Which row or letter cell is under the pointer (rect in content space). A single highlight is
    // drawn for it, so the cost stays constant no matter how many entries the
    // list holds (one reveal item per entry made pointer tracking crawl).
    readonly property var hoverInfo: {
        if (root.pointerBlocked || root.hoverBlocked)
            return root.forcedEntry !== null ? entryAt(root.forcedEntry) : null
        if (!pointerInside || pointerX < 0 || pointerY < 0)
            return null
        const contentY = flick.contentY
        const cy = pointerY + contentY
        for (var i = 0; i < sections.length; ++i) {
            const section = sections[i]
            const rows = Math.max(1, Math.ceil(section.entries.length / 3))
            const bottom = section.y + rows * 66
            if (cy < section.y - 9 || cy > bottom)
                continue
            if (debugHoverControl !== "")
                break
            if (pointerX >= Metrics.appLetterCellX + contentOffsetX
                    && pointerX < Metrics.appLetterCellX + contentOffsetX
                                   + Metrics.appLetterCellWidth) {
                return { kind: "letter", letter: section.letter,
                         x: Metrics.appLetterCellX + contentOffsetX, y: section.y - 9 ,
                         w: Metrics.appLetterCellWidth, h: Metrics.appRowPitch, entry: null }
            }
            for (var c = 0; c < Metrics.appColumns.length; ++c) {
                // The frame, not the icon slot: see Metrics.appItemInsetX.
                const colX = Metrics.appColumns[c] - Metrics.appItemInsetX
                             + contentOffsetX
                if (pointerX < colX || pointerX >= colX + Metrics.appItemWidth)
                    continue
                const row = Math.floor((cy - section.y) / 66)
                const index = c * rows + row
                if (row < 0 || index >= section.entries.length)
                    return null
                return { kind: "entry", letter: section.letter,
                         x: colX, y: section.y - 9 + row * 66 ,
                         w: Metrics.appItemWidth, h: Metrics.appRowPitch,
                         entry: section.entries[index] }
            }
            return null
        }
        return null
    }

    // Rect of one entry (content coordinates), used to keep the entry that
    // owns an open context menu highlighted.
    function entryAt(entry) {
        if (entry === null || entry === undefined)
            return null
        for (var i = 0; i < sections.length; ++i) {
            var section = sections[i]
            for (var k = 0; k < section.entries.length; ++k) {
                var e = section.entries[k]
                if (e !== entry)
                    continue
                var col = e.col !== undefined ? e.col : 0
                return { kind: "entry", letter: section.letter,
                         x: Metrics.appColumns[col] - Metrics.appItemInsetX
                            + contentOffsetX,
                         y: section.y - 9 + (e.row !== undefined ? e.row : 0) * 66,
                         w: Metrics.appItemWidth, h: Metrics.appRowPitch, entry: e }
            }
        }
        return null
    }

    readonly property real contentHeight: {
        var h = 0
        for (var i = 0; i < sections.length; ++i) {
            var n = sections[i].entries.length
            var rows = Math.max(1, Math.ceil(n / 3))
            h = Math.max(h, sections[i].y + rows * 66)
        }
        return h + Metrics.appSectionGap
    }

    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: Math.max(root.contentHeight, root.height)
        boundsBehavior: Flickable.StopAtBounds
        // The popup owns the pointer while it is up.
        interactive: !root.pointerBlocked
        clip: true

        // One highlight for the row or letter under the pointer, drawn under
        // the entries. Constant cost regardless of the number of entries.
        RevealRect {
            id: rowHighlight
            // Letters draw their own fill, so the shared highlight is only for
            // the application rows.
            visible: root.hoverInfo !== null && root.hoverInfo.kind !== "letter"
                     && root.pressedEntry === null
            x: root.hoverInfo ? root.hoverInfo.x : 0
            y: root.hoverInfo ? root.hoverInfo.y : 0
            width: root.hoverInfo ? root.hoverInfo.w : 0
            height: root.hoverInfo ? root.hoverInfo.h : 0
            // Shrinks with the entry, so no ring of fill stays outside its border.
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
            hoverFillOpacity: root.hoverInfo && root.hoverInfo.kind === "entry" ? 0.13 : 0.09
            glowRadius: root.hoverInfo && root.hoverInfo.kind === "entry" ? 220 : 200
            glowStrength: root.hoverInfo && root.hoverInfo.kind === "entry" ? 0.08 : 0.07
            hoverPeak: 0
            nearPeak: 0
            borderWidth: 0
            z: -1
        }

        Repeater {
            model: root.sections
            delegate: Item {
                id: sectionItem
                required property var modelData
                y: modelData.y
                readonly property real sectionY: modelData.y

                Item {
                    id: letterCell
                    x: Metrics.appLetterCellX + root.contentOffsetX
                    y: -9 + root.switchRise(sectionItem.sectionY)
                    opacity: root.switchFade(sectionItem.sectionY)
                    width: Metrics.appLetterCellWidth
                    height: Metrics.appRowPitch
                    transform: Scale {
                        origin.x: letterCell.width / 2
                        origin.y: letterCell.height / 2
                        xScale: 1 - Metrics.pressScale * letterReveal.pressLevel
                        yScale: 1 - Metrics.pressScale * letterReveal.pressLevel
                    }


                    RevealRect {
                        id: letterReveal
                        anchors.fill: parent
                        pointerX: root.pointerX - letterCell.x
                        pointerY: root.pointerY + flick.contentY - parent.parent.y - letterCell.y
                        pointerInside: root.pointerInside
                        pointerDriven: true
                        hoverPeak: Metrics.appBorderPeak
                        nearPeak: 0
                        borderRadius: Metrics.appBorderRadius
                        borderWidth: Metrics.appBorderWidth
                        // The cell draws its own fill and frame (it is not part
                        // of the shared row highlight), so a press only has to
                        // shrink it. The fill stays on while pressed, so the cell
                        // does not darken compared with its hover look.
                        fillOpacity: (letterReveal.isHovered || letterCell.pressed) ? 0.09 : 0
                        pressed: letterCell.pressed
                    }

                    BaseText {
                        x: Metrics.appLetterX - Metrics.appLetterCellX
                        baselineY: 42
                        text: modelData.letter
                        family: Metrics.fontFamily
                        pixelSize: Metrics.appLetterSize
                    }

                    // Press: same behaviour as a tile (see RevealRect). The letter
                    // block carries its own fill, so scaling the block is enough.
                    property bool pressed: false

                    TapHandler {
                        enabled: !root.pointerBlocked
                        onPressedChanged: letterCell.pressed = pressed
                        onTapped: root.lettersRequested()
                    }
                }

                Repeater {
                    model: modelData.entries
                    delegate: Item {
                        id: entryItem
                        required property var modelData

                        readonly property int column: modelData.col !== undefined ? modelData.col : 0
                        readonly property string key: (modelData.desktopId || modelData.name) + "@" + column
                                                                            + ":" + (modelData.row !== undefined ? modelData.row : 0)
                        // Row position in menu coordinates: the switch entrance
                        // moves the rows, not the individual entries.
                        readonly property real rowY: sectionItem.sectionY
                                                     + (modelData.row !== undefined ? modelData.row : 0) * 66
                        x: Metrics.appColumns[column] - Metrics.appItemInsetX
                           + root.contentOffsetX
                        y: (modelData.row !== undefined ? modelData.row : 0) * 66 - 9
                           + root.switchRise(rowY)
                        opacity: root.switchFade(rowY)
                        width: Metrics.appItemWidth
                        height: Metrics.appRowPitch
                        transform: Scale {
                            origin.x: entryItem.width / 2
                            origin.y: entryItem.height / 2
                            xScale: 1 - Metrics.pressScale * entryReveal.pressLevel
                            yScale: 1 - Metrics.pressScale * entryReveal.pressLevel
                        }

                        // Border-only reveal, hovered row only: entries around
                        // the pointer stay dark (the reference does not light
                        // them), unlike tiles. Fill and interior glow come from
                        // the single highlight above, so this stays cheap.
                        RevealRect {
                            id: entryReveal
                            anchors.fill: parent
                            pointerX: root.pointerX - parent.x
                            pointerY: root.pointerY + flick.contentY - parent.parent.y - parent.y
                            pointerInside: root.pointerInside && !root.pointerBlocked
                            pointerDriven: true
                            hoverPeak: Metrics.appBorderPeak
                            nearPeak: 0
                            borderRadius: Metrics.appBorderRadius
                            borderWidth: Metrics.appBorderWidth
                            pressed: entryItem.pressed
                        }

                        AppIcon {
                            x: Metrics.appItemIconX
                            y: 9
                            size: Metrics.appIconSize
                            source: modelData.icon || ""
                        }

                        BaseText {
                            x: Metrics.appNameOffsetX
                            baselineY: 41
                            text: modelData.name
                            family: Metrics.fontFamily
                            pixelSize: Metrics.appNameSize
                            letterSpacing: hasCjk ? 1 : 0
                            maxWidth: 290
                            elide: Text.ElideRight
                        }

                        Image {
                            visible: !!modelData.folder
                            x: 330; y: 24
                            width: 15; height: 8
                            source: Qt.resolvedUrl("../assets/ui/chevron.png")
                            smooth: true
                        }

                        // Press: same behaviour as a tile (see RevealRect).
                        property bool pressed: false

                        // Keeps the shared row highlight in step with the pressed
                        // entry (see pressedRowLevel).
                        Binding {
                            target: root
                            property: "pressedRowLevel"
                            value: entryReveal.pressLevel
                            when: entryItem.pressed
                            restoreMode: Binding.RestoreNone
                        }

                        property point contextPoint: Qt.point(0, 0)

                        TapHandler {
                            acceptedButtons: Qt.RightButton
                            enabled: !root.pointerBlocked
                            onPressedChanged: {
                                // Same highlight / ripple feedback as a left
                                // press, then the menu on release.
                                entryItem.pressed = pressed
                                if (pressed)
                                    entryItem.contextPoint = Qt.point(point.scenePosition.x,
                                                                      point.scenePosition.y)
                            }
                            onTapped: root.entryContextRequested(modelData,
                                                                 entryItem.contextPoint.x,
                                                                 entryItem.contextPoint.y)
                        }

                        TapHandler {
                            enabled: !root.pointerBlocked
                            onPressedChanged: {
                                entryItem.pressed = pressed
                                if (!pressed) {
                                    // Release (or cancel): the row stays unlit while
                                    // the pointer is still on it.
                                    root.pressedRowLevel = 0
                                    root.pressedEntry = modelData
                                }
                            }
                            onTapped: root.entryActivated(modelData)
                        }
                    }
                }
            }
        }
    }

    // thin scrollbar on the right edge
    Rectangle {
        visible: flick.contentHeight > flick.height
        x: parent.width - 6
        y: Math.max(0, Math.min(flick.height - height, flick.contentY / Math.max(1, flick.contentHeight) * flick.height))
        width: 3
        height: Math.max(40, flick.height * flick.height / Math.max(1, flick.contentHeight))
        color: "#5A5A5A"
        opacity: 0.7
    }
    // Thin indicator: only while the list is being scrolled.
    ScrollBar {
        objectName: "appListScrollBar"
        contentY: root.scrollPosition
        contentHeight: flick.contentHeight
        viewHeight: root.height
    }

}
