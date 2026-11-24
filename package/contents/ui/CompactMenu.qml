// Non-fullscreen ("windowed") Start menu.
//
// Layout (design space 2560x1380, measured on
// screenshots/windows-reference/non-fullscreen-start/):
//   sidebar 0..74 (383 when expanded), app list 75..479, tiles from 486,
//   the panel's right edge is 486 + 486 * columns - 1 and its bottom edge
//   sits on the taskbar. The panel's top edge belongs to the user: it can be
//   dragged between half the screen and the top (see panelHeight).
//
// The tile area is the *same* TilesView as the fullscreen menu, driven by the
// compact metrics (CompactMetrics.js); hover, press, ripple, drag, context
// menu, rename and size change therefore behave identically.
import QtQuick
import QtQuick.Effects
import "metrics.js" as Metrics
import "CompactMetrics.js" as Compact
import "motion.js" as Motion

Item {
    id: root

    // The owning MetroMenu: the views read their shared state (pointer,
    // entrance, drag) from it.
    property var menu: null
    property string wallpaperUrl: ""

    // Columns of groups the tile area shows (1..4), and the panel height.
    property int columns: 3
    property real panelHeight: 1124
    // Geometry while a resize drag is in progress: the panel follows the
    // pointer, but the *layout* (which reflows on a column change) only
    // updates on release, otherwise the reflow feeds back into the pointer
    // position and the panel flickers.
    // Animation: nothing scales and nothing moves sideways. The panel fades in
    // while every row of content (tiles, groups, list rows) is pushed up from
    // below on its own staggered timeline - the same motion as the fullscreen
    // tiles/apps switch (see Motion.switchRise).
    property real openLinear: 1
    readonly property real openProgress: openLinear
    // The backdrop arrives much faster than the push (~5 frames vs ~20).
    // Opacity arrives in ~5 frames; the upward growth keeps a long tail.
    readonly property real fadeProgress: Motion.expoEase(Motion.compactFadeK,
                                                         Math.min(1, openLinear
                                                         * Motion.compactOpenDuration
                                                         / Motion.compactOpenFadeDuration))
    readonly property real expandProgress: Motion.expoEase(Motion.compactExpandK,
                                                           Math.min(1, openLinear
                                                           * Motion.compactOpenDuration
                                                           / Motion.compactOpenExpandDuration))
    // Design rect of the desktop wallpaper (see main.qml).
    property rect wallpaperRect: Qt.rect(0, 0, Metrics.canvasWidth, 1440)
    // Share of the icon box the theme's artwork fills (applet setting).
    property real iconFillRatio: Metrics.iconFillRatio
    // Columns the panel can still hold on this canvas (the user setting is
    // clamped to it, the right edge drag stops there).
    property int maxColumns: Compact.columnsMax
    property real previewWidth: -1
    property real previewHeight: -1
    // True while an edge is being dragged: the tiles must not react to it.
    property bool resizeActive: false
    readonly property real panelMinHeight: 690
    // The panel may grow up to the top of the menu canvas (60 design px below
    // it), which is 1320 on the reference canvas.
    readonly property real panelMaxHeight: Math.max(panelMinHeight, panelBottom - 60)
    readonly property real panelWidth: previewWidth > 0 ? previewWidth
                                                        : Compact.panelWidth(columns)
    // The panel's bottom edge sits on the taskbar, i.e. on the menu's bottom
    // edge (the canvas is the work area, see main.qml).
    property real panelBottom: parent ? parent.height : Metrics.canvasHeight
    readonly property real shownHeight: previewHeight > 0 ? previewHeight : panelHeight
    readonly property real panelTop: panelBottom - shownHeight

    readonly property var cm: Compact.values()

    // The expanded sidebar and the power / user flyout own the pointer inside
    // their rect: what is behind them must not highlight or take clicks.
    readonly property real sidebarBlockWidth: sidebar.openAmount > 0.001 ? sidebar.width : 0
    readonly property real localPointerX: root.menu ? root.menu.effectivePointerX : -1
    readonly property real localPointerY: root.menu ? root.menu.panelPointerY : -1
    readonly property bool pointerOverSidebar: root.menu !== null
                                               && root.menu.effectivePointerInside
                                               && sidebarBlockWidth > 0
                                               && localPointerX >= 0
                                               && localPointerX < sidebarBlockWidth
                                               && localPointerY >= 0 && localPointerY < root.shownHeight
    // Rect of the power / user flyout in menu coordinates.
    readonly property string flyoutKind: root.menu ? root.menu.flyout : ""
    readonly property real flyoutHeight: flyoutKind === "power" ? 165
                                       : (flyoutKind === "user" ? 237 : 0)
    // The flyout opens above its button: its bottom edge sits on the row's top
    // edge (minus the 6 px gap the fullscreen menu uses).
    readonly property real flyoutAnchorY: flyoutKind === "power"
                                          ? root.panelBottom - 78
                                          : root.panelBottom - 150
    readonly property var flyoutGeom: flyoutKind === "" ? null
                                     : ({ x: 0, y: flyoutAnchorY - flyoutHeight,
                                          w: 386, h: flyoutHeight })
    readonly property bool pointerOverFlyout: {
        const f = flyoutGeom
        if (!f || root.menu === null || !root.menu.effectivePointerInside)
            return false
        const px = localPointerX
        const py = localPointerY + root.panelTop
        return px >= f.x && px < f.x + f.w && py >= f.y && py < f.y + f.h
    }
    readonly property bool pointerOverOverlay: pointerOverSidebar || pointerOverFlyout
    // The tile view and list MetroMenu drives (drag, rename, scrolling).
    readonly property alias tilesView: compactTilesView
    readonly property alias appList: compactAppList

    function resetScroll() {
        // Both the tile area and the application list scroll independently, so
        // reopening the windowed Start has to put both back to the top (the
        // fullscreen menu resets its tile view the same way).
        compactTilesView.resetScroll()
        compactAppList.resetScroll()
    }

    function cancelScrollDrag() {
        // nothing to do: the list has no external drag state
    }

    // Columns changed by the user: the layout has to be rebuilt, so the owner
    // is told (it re-renders its groups).
    signal columnsRequested(int columns)
    signal panelHeightRequested(real height)
    signal sidebarExpandedRequested(bool expanded)

    // --- panel ---------------------------------------------------------

    // Clicks anywhere outside the panel close the menu (the window covers the
    // whole screen, so without this the transparent area would swallow them).
    MouseArea {
        objectName: "compactOutsideCatcher"
        anchors.fill: parent
        z: -1
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onPressed: (mouse) => {
            if (!root.menu)
                return
            const px = mouse.x
            const py = mouse.y
            if (px < root.panelWidth && py >= root.panelTop)
                return                      // inside the panel: handled above
            root.menu.closeRequested()
        }
    }

    // --- content -------------------------------------------------------
    // Full menu size: the sidebar's acrylic captures this layer 1:1, so it must
    // not be smaller than the menu (a MultiEffect scales its source).
    Item {
        id: menuContent
        x: 0
        y: 0
        width: 2560
        height: 1380
        visible: false
    }
    Item {
        id: contentLayer
        x: 0
        y: root.panelTop
        width: root.panelWidth
        height: root.shownHeight
        clip: true

            // Backdrop of the panel: wallpaper blurred + tint. It lives inside
            // the content layer so the sidebar's acrylic blurs *this* (the
            // reference frost is the blurred backdrop + content).
            Item {
                id: panel
                objectName: "compactPanel"
                opacity: root.fadeProgress
                // The backdrop is anchored on the taskbar: it fades in while
                // its top edge travels up (no horizontal change).
                transform: Scale {
                    origin.y: root.shownHeight
                    yScale: Motion.compactPanelScaleFrom
                            + (1 - Motion.compactPanelScaleFrom) * root.expandProgress
                }
                x: 0
                y: 0
                width: root.panelWidth
                height: root.shownHeight
                clip: true

            // Acrylic: the wallpaper behind the panel, blurred, then tinted.
            // MultiEffect captures the whole design-space wallpaper and the panel
            // clips it to its own rect (a blur needs the pixels outside the panel).
            Item {
                id: blurLayer
                x: root.wallpaperRect.x
                width: root.wallpaperRect.width
                height: root.wallpaperRect.height
                y: root.wallpaperRect.y - root.panelTop
                visible: root.wallpaperUrl !== ""
                Image {
                    id: panelWallpaper
                    anchors.fill: parent
                    source: root.wallpaperUrl
                    fillMode: Image.PreserveAspectCrop
                    smooth: true
                }
            }
            MultiEffect {
                // Same size and offset as the captured wallpaper: a MultiEffect
                // scales its source into its own bounds, so an effect the size of
                // the panel would squeeze the whole wallpaper into it.
                x: root.wallpaperRect.x
                y: root.wallpaperRect.y - root.panelTop
                width: root.wallpaperRect.width
                height: root.wallpaperRect.height
                source: blurLayer
                blurEnabled: true
                blur: Compact.backdropBlurAmount
                blurMax: Compact.backdropBlurMax
                saturation: 0.0
                brightness: 0.0
                contrast: 0.0
            }
            Rectangle {
                anchors.fill: parent
                color: Compact.backdropColor
                opacity: Compact.backdropOpacity
            }
            Image {
                anchors.fill: parent
                source: Qt.resolvedUrl("../assets/ui/noise.png")
                fillMode: Image.Tile
                smooth: false
                opacity: Compact.backdropNoise
            }
        }

        CompactAppList {
            id: compactAppList
            objectName: "compactAppList"
            iconFillRatio: root.iconFillRatio
            x: Compact.sidebarWidth
            y: 0
            width: Compact.appListWidth
            height: parent.height
            sections: root.menu ? root.menu.compactSections : []
            pointerX: root.menu ? root.menu.effectivePointerX - x : -1
            pointerY: root.menu ? root.menu.panelPointerY : -1
            pointerInside: root.menu ? root.menu.effectivePointerInside : false
            hoverInjected: root.menu ? root.menu.debugPointerActive : false
            openProgress: root.openProgress
            pointerBlocked: root.pointerOverOverlay
            accentColor: root.menu ? root.menu.accentColor : Metrics.accentColorDefault
            onEntryActivated: (entry) => {
                if (root.menu) {
                    root.menu.launchEntry(entry)
                    root.menu.closeRequested()
                }
            }
            onEntryContextRequested: (entry, sx, sy) => {
                if (root.menu)
                    root.menu.openEntryContextMenu(entry, sx, sy)
            }
        }

        // Tile area: the fullscreen view with the compact metrics.
        TilesView {
            id: compactTilesView
            objectName: "compactTilesView"
            m: root.cm
            iconFillRatio: root.iconFillRatio
            tileSkin: root.menu ? root.menu.tileSkin : "modern"
            tilePalette: root.menu ? root.menu.tilePalette : "default"
            forceAppColor: root.menu ? root.menu.forceAppColor : true
            themedIcon: root.menu ? root.menu.themedIcon : "auto"
            liveTilesEnabled: root.menu ? root.menu.liveTilesEnabled : false
            liveTileCycle: root.menu ? root.menu.liveTileCycle : true
            moreLiveAni: root.menu ? root.menu.moreLiveAni : true
            // Same staggered row rise as the fullscreen tiles/apps switch.
            switchProgress: root.openProgress
            windowedAnimation: true
            // The tile area starts where the columns do: the app list's
            // scrollbar (461..478) must stay outside it.
            x: Compact.panelBaseWidth
            y: 0
            width: root.panelWidth - Compact.panelBaseWidth
                   - Compact.tilesGapToPanelRight
            height: parent.height
            groups: root.menu && root.menu.activeConfig ? root.menu.compactLayout.groups : []
            contentHeight: root.menu ? root.menu.compactLayout.contentHeight : 0
            accentColor: root.menu ? root.menu.accentColor : Metrics.accentColorDefault
            dragging: root.menu ? (root.menu.dragTileId !== "" || root.menu.dragGroupId !== "") : false
            titlesVisible: root.menu ? root.menu.groupTitles : true
            pointerX: root.menu ? root.menu.effectivePointerX - x : -1
            pointerY: root.menu ? root.menu.panelPointerY : -1
            pointerInside: root.menu ? root.menu.effectivePointerInside : false
            debugHoverTile: root.menu ? root.menu.debugHoverTile : -1
            contextHoverTile: root.menu ? root.menu.contextHoverTile : ""
            pointerBlocked: root.resizeActive || root.pointerOverOverlay
                            || (root.menu ? root.menu.pointerOverContextMenu : false)
            hoverBlocked: root.menu ? root.menu.contextMenuOpen : false
            debugHoverGroupId: root.menu ? root.menu.debugHoverGroupId : ""
            onTileActivated: (entry) => {
                if (root.menu) {
                    root.menu.launchEntry(entry)
                    root.menu.closeRequested()
                }
            }
            onTileContextRequested: (entry, sx, sy) => {
                if (root.menu)
                    root.menu.openTileContextMenu(entry, sx, sy)
            }
            onGroupContextRequested: (groupId, sx, sy) => {
                if (root.menu)
                    root.menu.openGroupContextMenu(groupId, sx, sy)
            }
            onGroupRenamed: (groupId, title) => {
                if (root.menu)
                    root.menu.renameGroup(groupId, title)
            }
            onSizeChangeRequested: (tileId, size) => {
                if (root.menu)
                    root.menu.requestTileSize(tileId, size)
            }
            onTileDragStarted: (tileId, px, py) => {
                if (root.menu)
                    root.menu.beginTileDrag(tileId, px, py)
            }
            onTileDragMoved: (tileId, px, py) => {
                if (root.menu)
                    root.menu.updateTileDrag(px, py)
            }
            onTileDragFinished: (tileId, px, py) => {
                if (root.menu)
                    root.menu.finishTileDrag(tileId, px, py)
            }
            onTileDragCanceled: (tileId) => {
                if (root.menu)
                    root.menu.cancelDrag()
            }
            onGroupDragStarted: (groupId, px, py) => {
                if (root.menu)
                    root.menu.beginGroupDrag(groupId, px, py)
            }
            onGroupDragMoved: (groupId, px, py) => {
                if (root.menu)
                    root.menu.updateGroupDrop(px, py)
            }
            onGroupDragFinished: (groupId, px, py) => {
                if (root.menu)
                    root.menu.finishGroupDrag(groupId, px, py)
            }
            onGroupDragCanceled: (groupId) => {
                if (root.menu)
                    root.menu.cancelDrag()
            }
        }

    }

    // Sidebar above the content: its acrylic blurs that content.
        // Swallow clicks that would otherwise reach the content below.
        MouseArea {
            objectName: "sidebarClickBlocker"
            // Always on while the sidebar is up: a click must never reach the
            // items behind it (the sidebar's own buttons are drawn above this).
            visible: root.sidebarBlockWidth > 0
            x: 0
            y: root.panelTop
            width: root.sidebarBlockWidth
            height: root.shownHeight
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        }
        MouseArea {
            objectName: "flyoutClickBlocker"
            visible: root.flyoutKind !== ""
            x: 0
            y: root.flyoutGeom ? root.flyoutGeom.y : 0
            width: root.flyoutGeom ? root.flyoutGeom.w : 0
            height: root.flyoutGeom ? root.flyoutGeom.h : 0
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        }

        Sidebar {
            id: sidebar
            objectName: "compactSidebar"
            compact: true
            height: root.shownHeight
            expanded: root.menu ? root.menu.sidebarExpanded : false
            selected: ""
            wallpaperUrl: root.wallpaperUrl
            userName: root.menu ? root.menu.userNameData : ""
            avatar: root.menu ? root.menu.avatarData : ""
            pointerX: root.menu ? root.menu.effectivePointerX : -1
            pointerY: root.menu ? root.menu.panelPointerY : -1
            pointerInside: root.menu ? root.menu.effectivePointerInside : false
            accentColor: root.menu ? root.menu.accentColor : Metrics.accentColorDefault
            y: root.panelTop
            blurSourceItem: contentLayer
            blurSourceWidth: root.panelWidth
            panelAlpha: Compact.sidebarPanelAlpha
            panelColor: Compact.sidebarPanelColor
            blurMax: Compact.sidebarBlurMax
            blurAmount: Compact.sidebarBlurAmount
            // The panel's own backdrop already carries the grain (same texture,
            // see CompactMetrics.backdropNoise), and the sidebar sits on top of
            // it: a second layer would add the same noise twice instead of
            // once, which is not how acrylic composites.
            noiseOpacity: 0.03
            menuWidth: 2560
            hoverInjected: root.menu ? root.menu.debugPointerActive : false
            debugHoverControl: root.menu ? root.menu.debugHoverControl : ""
            onSectionActivated: (id) => {
                if (id === "toggle" && root.menu)
                    root.menu.toggleSidebar()
            }
            onUserActivated: if (root.menu) root.menu.openFlyout("user")
            onPowerActivated: if (root.menu) root.menu.openFlyout("power")
        }

    // --- edge resize ---------------------------------------------------
    // Left edge: height. Right edge: width (1..4 columns).
    MouseArea {
        objectName: "compactResizeTop"
        x: 0
        y: root.panelTop
        width: root.panelWidth
        height: Compact.edgeResizeGrab
        cursorShape: Qt.SizeVerCursor
        property real pressSceneY: 0
        property real startHeight: 0
        // The strip itself moves while dragging, so the pointer is tracked in
        // scene coordinates (item position + local offset) rather than local.
        preventStealing: true
        onPressed: (mouse) => {
            pressSceneY = y + mouse.y
            startHeight = root.panelHeight
            root.resizeActive = true
        }
        onPositionChanged: (mouse) => {
            if (!pressed)
                return
            const dy = (y + mouse.y) - pressSceneY
            root.previewHeight = Math.max(root.panelMinHeight,
                                          Math.min(root.panelMaxHeight, startHeight - dy))
        }
        onReleased: {
            if (root.previewHeight > 0)
                root.panelHeightRequested(Math.round(root.previewHeight))
            root.previewHeight = -1
            root.resizeActive = false
        }
        onCanceled: {
            root.previewHeight = -1
            root.resizeActive = false
        }
    }
    MouseArea {
        objectName: "compactResizeRight"
        x: root.panelWidth - Compact.edgeResizeGrab
        y: root.panelTop
        width: Compact.edgeResizeGrab
        height: root.shownHeight
        cursorShape: Qt.SizeHorCursor
        property real pressSceneX: 0
        property real startWidth: 0
        preventStealing: true
        onPressed: (mouse) => {
            pressSceneX = x + mouse.x
            startWidth = Compact.panelWidth(root.columns)
            root.resizeActive = true
        }
        onPositionChanged: (mouse) => {
            if (!pressed)
                return
            const dx = (x + mouse.x) - pressSceneX
            root.previewWidth = Math.max(Compact.panelWidth(Compact.columnsMin),
                                         Math.min(Compact.panelWidth(root.maxColumns),
                                                  startWidth + dx))
        }
        onReleased: {
            if (root.previewWidth > 0) {
                let n = Math.round((root.previewWidth - Compact.panelBaseWidth)
                                   / Compact.panelPitch)
                n = Math.max(Compact.columnsMin, Math.min(root.maxColumns, n))
                if (n !== root.columns)
                    root.columnsRequested(n)
            }
            root.previewWidth = -1
            root.resizeActive = false
        }
        onCanceled: {
            root.previewWidth = -1
            root.resizeActive = false
        }
    }
}
