// Windows 10 context menu (the shell's MenuFlyout).
//
// Geometry and motion are measured on the reference clips:
//   * right_click_menu.mp4  tile menu with a jump-list section
//   * menu-tile.mp4         same menu, resize submenu
//   * menu-app-entry.mp4    application list entry with its "more" submenu
//   * 屏幕截图 ... 160427    group title menu
//
// A menu is a 384 px wide presenter with a 2 px border, 8 px of padding and
// 49 px rows. Opening grows the panel downwards from the anchor while the
// content slides down with it (the content's bottom stays glued to the panel's
// bottom edge, so the last row appears first at the anchor and everything else
// follows from above). Closing has no animation.
//
// Rows share the application list's hover and press behaviour: the same
// RevealRect (fill + pointer glow + border, ripple on press). A row that owns a
// submenu turns into the accent's dark shade while that submenu is open.
import QtQuick
import "metrics.js" as Metrics
import "motion.js" as Motion

Item {
    id: menu

    // Rows, top to bottom:
    //   { kind: "item", label, icon, chevron, submenu, checked, enabled,
    //     action, data }
    //   { kind: "header", label }        section label ("任务")
    //   { kind: "separator" }
    // Submenu rows may carry `sizeGlyph` instead of `icon`.
    property var model: []
    property color accentColor: Metrics.accentColorDefault
    // Submenus that hold check marks reserve the check column.
    property bool checkColumn: false

    // True while the menu is on screen; the opening animation starts when it
    // flips to true, closing just hides the menu (the reference has no close
    // animation).
    property bool open: false
    // The opening animation belongs to the menu that owns the motion; a
    // submenu is driven by its parent (see the Loader at the end).
    property bool animate: true
    readonly property real openProgress: openAmount
    // Qt 6.10 drops `easing.bezierCurve` (the list arrives empty and the
    // animation falls back to linear), so the fitted curve is evaluated here
    // and the animations only run a 0..1 clock.
    property real openTime: 0
    property real drivenAmount: 0
    readonly property real openAmount: animate
                                        ? Motion.bezierValue(Metrics.contextMenuOpenCurve, openTime)
                                        : drivenAmount


    // Screen bounds, used to keep submenus on screen.
    property real boundsWidth: 2560
    property real boundsHeight: 1380
    // The anchor is the corner the panel opens from: (anchorX, anchorY) is its
    // top-left when neither flag is set, its top-right when `growLeft`, its
    // bottom-left when `growUp` and its bottom-right when both. The opening
    // motion mirrors with it (the panel unrolls away from that corner).
    property real anchorX: 0
    property real anchorY: 0
    property bool growUp: false
    property bool growLeft: false
    // Depth of this menu in the submenu chain (0 = top level).
    property int depth: 0

    // Harness hooks for the render tools: drive the pointer and the submenu
    // without a real mouse.
    property bool debugPointerActive: false
    property real debugPointerX: -1
    property real debugPointerY: -1
    property int debugHoverRow: -1
    property int debugOpenRow: -1
    property real debugOpenProgress: -1
    property real debugSubmenuProgress: -1

    signal activated(var row)
    signal submenuOpened(int row)


    // --- geometry ---------------------------------------------------------
    // Rows are laid out in panel coordinates (border included) so submenus can
    // be placed without another conversion.
    readonly property var layout: {
        const rows = []
        let y = Metrics.contextMenuBorder + Metrics.contextMenuPadY
        for (let i = 0; i < model.length; ++i) {
            const it = model[i] || {}
            const kind = it.kind || "item"
            const h = kind === "header" ? Metrics.contextMenuHeaderPitch
                    : kind === "separator" ? Metrics.contextMenuSeparatorPitch
                    : Metrics.contextMenuRowPitch
            rows.push({ index: i, kind: kind, label: it.label || "",
                        icon: it.icon || "", chevron: !!it.chevron,
                        submenu: it.submenu || null, checked: !!it.checked,
                        sizeGlyph: it.sizeGlyph || "",
                        enabled: it.enabled !== false, action: it.action || "",
                        data: it.data === undefined ? null : it.data,
                        y: y, h: h })
            y += h
        }
        return { rows: rows,
                 height: y + Metrics.contextMenuPadBottom + Metrics.contextMenuBorder }
    }
    readonly property var rows: layout.rows
    readonly property real contentHeight: layout.height
    readonly property real panelHeight: contentHeight * Math.max(0, Math.min(1, progress))
    readonly property real progress: debugOpenProgress >= 0 ? debugOpenProgress : openAmount
    // Content offset: the last row stays on the panel's bottom edge, so the
    // content slides down while the panel grows.
    readonly property real contentOffset: growUp ? 0 : panelHeight - contentHeight

    width: Metrics.contextMenuWidth
    height: panelHeight
    x: growLeft ? anchorX - width : anchorX
    y: growUp ? anchorY - panelHeight : anchorY

    onOpenChanged: {
        if (!animate)
            return
        if (open) {
            openTime = 0
            openAnim.restart()
        } else {
            openAnim.stop()
            openTime = 0
            activateTimer.stop()
            pendingRow = null
            closeChildren()
        }
    }
    NumberAnimation {
        id: openAnim
        target: menu
        property: "openTime"
        from: 0
        to: 1
        duration: Metrics.contextMenuOpenDuration
        easing.type: Easing.Linear
    }

    // --- pointer ----------------------------------------------------------
    HoverHandler {
        id: panelHover
    }

    readonly property real pointerX: debugPointerActive ? debugPointerX
                                                        : (panelHover.hovered ? panelHover.point.position.x : -1)
    readonly property real pointerY: debugPointerActive ? debugPointerY
                                                        : (panelHover.hovered ? panelHover.point.position.y : -1)
    readonly property bool pointerInside: debugPointerActive ? (debugPointerX >= 0) : panelHover.hovered
    // Exposed so a parent can tell whether the pointer is over this menu or
    // over the submenu it opened.
    readonly property bool hovered: panelHover.hovered

    // The row under the pointer, in the visible part of the panel.
    readonly property int hoverRow: {
        if (debugPointerActive)
            return debugHoverRow
        if (!panelHover.hovered)
            return -1
        const py = panelHover.point.position.y
        for (let i = 0; i < rows.length; ++i) {
            const r = rows[i]
            if (r.kind !== "item")
                continue
            const top = r.y + contentOffset
            if (py >= top && py < top + r.h)
                return r.enabled ? i : -1
        }
        return -1
    }

    // --- submenus ---------------------------------------------------------
    property int openRow: -1
    readonly property int submenuRow: debugOpenRow >= 0 ? debugOpenRow : openRow
    readonly property var submenuRows: submenuRow >= 0 && rows[submenuRow]
                                       ? (rows[submenuRow].submenu || []) : []
    readonly property bool submenuCheckColumn: {
        const items = submenuRows
        for (let i = 0; i < items.length; ++i) {
            if (items[i] && items[i].checked !== undefined)
                return true
        }
        return false
    }

    // Activating a row waits for the press ripple to bloom (the shell closes
    // the flyout a moment after the click, see Metrics.contextMenuActivateDelay).
    property var pendingRow: null
    function activateLater(row) {
        pendingRow = row
        activateTimer.restart()
    }
    Timer {
        id: activateTimer
        interval: Metrics.contextMenuActivateDelay
        repeat: false
        onTriggered: {
            const row = menu.pendingRow
            menu.pendingRow = null
            if (row !== null)
                menu.activated(row)
        }
    }

    function closeChildren() {
        openRow = -1
        dwell.stop()
    }

    function openSubmenuAt(row) {
        const r = rows[row]
        if (!r || !r.submenu || r.submenu.length === 0)
            return
        openRow = row
        submenuOpened(row)
    }

    // Pointer left the menu without entering the submenu: drop the submenu.
    Timer {
        id: leaveTimer
        interval: 300
        repeat: false
        onTriggered: {
            const sub = submenuLoader.item
            if (menu.hovered || (sub && sub.hovered))
                return
            menu.openRow = -1
            menu.subTime = 0
        }
    }
    onHoveredChanged: {
        if (hovered) {
            leaveTimer.stop()
        } else if (!debugPointerActive && openRow >= 0) {
            leaveTimer.restart()
        }
    }

    Timer {
        id: dwell
        interval: Metrics.contextMenuSubmenuDelay
        repeat: false
        onTriggered: menu.openSubmenuAt(menu.hoverRow)
    }

    onHoverRowChanged: {
        if (debugPointerActive)
            return
        // Leaving the panel (typically into the open submenu) keeps the
        // submenu alive; resting on another row drops it at once.
        if (hoverRow < 0)
            return
        if (hoverRow === openRow) {
            dwell.stop()
            return
        }
        if (openRow >= 0) {
            openRow = -1
            subTime = 0
        }
        const r = rows[hoverRow]
        if (r && r.submenu && r.submenu.length > 0)
            dwell.restart()
        else
            dwell.stop()
    }

    // --- drawing ----------------------------------------------------------
    // The panel follows the animation (top edge fixed, bottom grows).
    Rectangle {
        id: panel
        x: 0
        y: 0
        width: menu.width
        height: menu.panelHeight
        color: Metrics.menuPanelColor
        border.width: Metrics.contextMenuBorder
        border.color: Metrics.contextMenuBorderColor
    }

    Item {
        id: clip
        width: menu.width
        height: menu.panelHeight
        clip: true

        Item {
            id: content
            width: menu.width
            height: menu.contentHeight
            y: menu.contentOffset

            Repeater {
                model: menu.rows
                delegate: Item {
                    id: rowItem
                    required property var modelData
                    y: modelData.y
                    width: menu.width
                    height: modelData.h
                    visible: modelData.kind !== "separator"

                    // A separator is a single line, as in MenuFlyoutSeparator.
                    Rectangle {
                        visible: modelData.kind === "separator"
                        x: Metrics.contextMenuSeparatorInsetX
                        y: 0
                        width: parent.width - 2 * Metrics.contextMenuSeparatorInsetX
                        height: 1
                        color: Metrics.contextMenuSeparatorColor
                    }

                    // MenuFlyoutItem: same reveal as the application list rows.
                    RevealRect {
                        id: reveal
                        // The shell insets the row highlight: 4 px more on the
                        // left than on the right, and 2 px top/bottom.
                        x: Metrics.contextMenuFillLeft
                        y: Metrics.contextMenuFillY
                        width: parent.width - Metrics.contextMenuFillLeft
                               - Metrics.contextMenuFillRight
                        height: parent.height - 2 * Metrics.contextMenuFillY
                        visible: modelData.kind === "item"
                        pointerX: menu.pointerX
                        pointerY: menu.pointerY - menu.contentOffset - rowItem.y
                        pointerInside: menu.pointerInside
                        pointerDriven: true
                        hoverFillOpacity: 0.13
                        glowRadius: 220
                        glowStrength: 0.08
                        hoverPeak: Metrics.appBorderPeak
                        nearPeak: 0
                        borderRadius: Metrics.appBorderRadius
                        borderWidth: Metrics.appBorderWidth
                        pressed: rowItem.pressed
                    }

                    // Row that owns the open submenu: the shell fills it with
                    // AccentDark3 (see Metrics.accentDeep).
                    Rectangle {
                        x: Metrics.contextMenuFillLeft
                        y: Metrics.contextMenuFillY
                        width: parent.width - Metrics.contextMenuFillLeft
                               - Metrics.contextMenuFillRight
                        height: parent.height - 2 * Metrics.contextMenuFillY
                        visible: modelData.kind === "item"
                                 && menu.submenuRow === modelData.index
                        color: Metrics.accentDeep(menu.accentColor)
                    }

                    Image {
                        visible: modelData.kind === "item" && modelData.icon !== ""
                        x: Metrics.contextMenuIconX
                        y: Metrics.contextMenuIconY
                        width: Metrics.contextMenuIconSize
                        height: Metrics.contextMenuIconSize
                        source: modelData.icon
                        smooth: true
                        fillMode: Image.PreserveAspectFit
                    }

                    // Tile size preview (resize submenu): the group cell
                    // outline with the tile's footprint filled in at its
                    // bottom-left corner, as the shell draws it.
                    Item {
                        visible: modelData.kind === "item" && modelData.sizeGlyph !== ""
                        x: menu.checkColumn ? Metrics.contextMenuSubmenuIconX
                                            : Metrics.contextMenuIconX
                        // 24 x 24 box centred on the row (the 48 px icon
                        // sprites start at the row's top, this one does not).
                        y: Metrics.contextMenuGlyphY
                        width: 24
                        height: 24

                        readonly property var block: {
                            switch (modelData.sizeGlyph) {
                            case "1x1": return { w: 10, h: 10 }
                            case "4x2": return { w: 20, h: 10 }
                            case "4x4": return { w: 20, h: 20 }
                            default:    return { w: 13, h: 13 }
                            }
                        }
                        Rectangle {
                            anchors.fill: parent
                            color: "transparent"
                            border.width: 2
                            border.color: "#FFFFFF"
                        }
                        Rectangle {
                            x: 2
                            y: parent.height - 2 - parent.block.h
                            width: parent.block.w
                            height: parent.block.h
                            color: "#FFFFFF"
                        }
                    }

                    // Check mark of the resize submenu (reserved column).
                    Image {
                        visible: modelData.kind === "item" && menu.checkColumn
                                 && modelData.checked === true
                        x: Metrics.contextMenuSubmenuCheckX
                        y: Metrics.contextMenuSubmenuCheckY
                        width: 24
                        height: 26
                        source: Qt.resolvedUrl("../assets/ui/menu-check.png")
                        smooth: true
                    }

                    BaseText {
                        visible: modelData.kind === "item"
                        x: menu.checkColumn ? Metrics.contextMenuSubmenuTextX
                                            : Metrics.contextMenuTextX
                        baselineY: Metrics.contextMenuTextBaseline
                        text: modelData.label
                        family: Metrics.fontFamily
                        pixelSize: Metrics.contextMenuTextSize
                        letterSpacing: hasCjk ? Metrics.contextMenuLetterSpacing : 0
                        color: modelData.enabled ? "#FFFFFF" : Metrics.contextMenuDisabledColor
                        // The shell elides labels at the panel's right edge.
                        maxWidth: menu.width - x - 10
                        elide: Text.ElideRight
                    }

                    // Section header of a jump list ("任务").
                    BaseText {
                        visible: modelData.kind === "header"
                        x: Metrics.contextMenuHeaderTextX
                        baselineY: Metrics.contextMenuHeaderBaseline
                        text: modelData.label
                        family: Metrics.fontFamily
                        pixelSize: Metrics.contextMenuHeaderSize
                        letterSpacing: hasCjk ? Metrics.contextMenuLetterSpacing : 0
                        color: Metrics.contextMenuHeaderColor
                    }

                    Image {
                        visible: modelData.kind === "item" && modelData.chevron
                        x: Metrics.contextMenuChevronX
                        y: Metrics.contextMenuChevronY
                        width: 16
                        height: 20
                        source: Qt.resolvedUrl("../assets/ui/menu-chevron.png")
                        smooth: true
                    }

                    property bool pressed: false

                    TapHandler {
                        enabled: modelData.kind === "item" && modelData.enabled
                        onPressedChanged: rowItem.pressed = pressed
                        onTapped: {
                            // A row that owns a submenu opens it instead of
                            // emitting an action: clicking 更多/调整大小 must
                            // reveal the next level (and leave it open), not
                            // close the whole menu. Re-clicking the same row
                            // keeps it open.
                            const sub = rowItem.modelData.submenu
                            if (sub && sub.length > 0) {
                                menu.openSubmenuAt(rowItem.modelData.index)
                                return
                            }
                            menu.activateLater(rowItem.modelData)
                        }
                    }
                }
            }
        }
    }

    // --- submenu ----------------------------------------------------------
    property real subTime: 0
    readonly property real submenuAmount: Motion.bezierValue(Metrics.contextMenuOpenCurve, subTime)
    // The submenu opens from the row's top edge, 4 px inside the panel's right
    // side. When it does not fit there it mirrors: to the parent's left side
    // (same row, right edge 4 px inside the parent's left edge) and/or upwards
    // from the same point.
    readonly property var submenuGeom: {
        const r = submenuRow >= 0 ? rows[submenuRow] : null
        if (!r)
            return { x: 0, y: 0, left: false, up: false }
        const w = Metrics.contextMenuWidth
        const overlap = Metrics.contextMenuSubmenuOverlap
        const natural = menu.width - overlap
        const left = menu.x + natural + w > menu.boundsWidth
        const x = left ? overlap : natural
        const ownContent = submenuContentHeight(submenuRows)
        const up = menu.anchorYOffset + r.y + ownContent > menu.boundsHeight
        return { x: x, y: r.y, left: left, up: up }
    }
    // Panel top in screen coordinates (the anchor's own top), used to keep
    // submenus on screen.
    readonly property real anchorYOffset: growUp ? anchorY - contentHeight : anchorY

    // Height of a menu described by `items` (used by the owner to decide
    // whether the panel fits below the pointer).
    // Does the point (in this item's parent coordinates) land on the panel or
    // on the submenu it owns? The owner uses it to decide whether the popup
    // owns the pointer.
    function containsPoint(px, py) {
        if (px >= x && px < x + width && py >= y && py < y + height)
            return true
        const sub = submenuLoader.item
        if (sub !== null && sub.visible)
            return sub.containsPoint(px - x, py - y)
        return false
    }

    function contentHeightFor(items) {
        return submenuContentHeight(items || [])
    }

    function submenuContentHeight(items) {
        let y = 0
        for (let i = 0; i < items.length; ++i) {
            const it = items[i] || {}
            y += it.kind === "header" ? Metrics.contextMenuHeaderPitch
               : it.kind === "separator" ? Metrics.contextMenuSeparatorPitch
               : Metrics.contextMenuRowPitch
        }
        return y + Metrics.contextMenuPadY + Metrics.contextMenuPadBottom
                 + 2 * Metrics.contextMenuBorder
    }

    NumberAnimation {
        id: submenuOpenAnim
        target: menu
        property: "subTime"
        from: 0
        to: 1
        duration: Metrics.contextMenuOpenDuration
        easing.type: Easing.Linear
    }
    onOpenRowChanged: {
        if (openRow >= 0) {
            subTime = 0
            submenuOpenAnim.restart()
        }
    }

    Loader {
        id: submenuLoader
        active: menu.submenuRow >= 0 && menu.submenuRows.length > 0
        source: "ContextMenu.qml"
        onLoaded: {
            item.animate = false
            item.depth = menu.depth + 1
            item.model = menu.submenuRows
            item.checkColumn = menu.submenuCheckColumn
            item.accentColor = menu.accentColor
            item.boundsWidth = menu.boundsWidth
            item.boundsHeight = menu.boundsHeight
            item.open = true
            item.activated.connect(function (row) { menu.activated(row) })
            item.submenuOpened.connect(function (row) { menu.submenuOpened(row) })
        }
    }
    // The submenu's corner and its opening motion belong to this menu, so they
    // are bound (not assigned) - the geometry is only known once the row is
    // resolved.
    Binding {
        target: submenuLoader.item
        property: "anchorX"
        value: menu.submenuGeom.x
        when: submenuLoader.item !== null
        restoreMode: Binding.RestoreNone
    }
    Binding {
        target: submenuLoader.item
        property: "anchorY"
        value: menu.submenuGeom.y
        when: submenuLoader.item !== null
        restoreMode: Binding.RestoreNone
    }
    Binding {
        target: submenuLoader.item
        property: "growLeft"
        value: menu.submenuGeom.left
        when: submenuLoader.item !== null
        restoreMode: Binding.RestoreNone
    }
    Binding {
        target: submenuLoader.item
        property: "growUp"
        value: menu.submenuGeom.up
        when: submenuLoader.item !== null
        restoreMode: Binding.RestoreNone
    }
    Binding {
        target: submenuLoader.item
        property: "drivenAmount"
        value: menu.submenuAmount
        when: submenuLoader.item !== null
        restoreMode: Binding.RestoreNone
    }
    Binding {
        target: submenuLoader.item
        property: "debugOpenProgress"
        value: menu.debugSubmenuProgress
        when: submenuLoader.item !== null
        restoreMode: Binding.RestoreNone
    }
}
