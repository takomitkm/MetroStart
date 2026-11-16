// MetroStart menu surface: backdrop, tiles or app list, sidebar and flyouts.
import QtQuick
import "metrics.js" as Metrics
import "motion.js" as Motion
import "Layout.js" as Layout
import "Edit.js" as Edit

Item {
    id: root
    objectName: "metroMenu"

    // Injected by the preview harness; when null the applet uses its own data.
    property var context: null

    property string view: "tiles"          // "tiles" | "apps"
    property bool sidebarExpanded: false
    // Acrylic tuning (fitted against the reference sidebar capture).
    property real sidebarPanelAlpha: 0.42
    property real sidebarBlurMax: Metrics.sidebarBlurMax
    property real sidebarBlurSaturation: Metrics.sidebarBlurSaturation
    property real sidebarBlurBrightness: Metrics.sidebarBlurBrightness
    property real sidebarBlurContrast: Metrics.sidebarBlurContrast
    property real sidebarNoiseOpacity: Metrics.sidebarNoiseOpacity
    property real sidebarBlurDownscale: Metrics.sidebarBlurDownscale
    property real sidebarBlurAmount: Metrics.sidebarBlurAmount
    property bool sidebarBottomLabels: false
    property bool sidebarHover: false
    property bool bottomSeparators: false
    property bool groupTitles: true
    property bool renaming: false
    property real pointerX: -1
    property real pointerY: -1
    property bool pointerInside: false
    // Hooks used by the offscreen render harness to place the pointer (and the
    // hovered control) at a fixed position. They are off in the applet itself.
    property bool debugPointerActive: false
    property bool debugPointerInside: true
    property real debugPointerX: 0
    property real debugPointerY: 0
    property int debugHoverTile: -1
    property real debugScrollY: -1
    property alias debugScrollPosition: appList.scrollPosition
    property string debugHoverControl: ""

    readonly property real effectivePointerX: debugPointerActive ? debugPointerX : pointerX
    readonly property real effectivePointerY: debugPointerActive ? debugPointerY : pointerY
    readonly property bool effectivePointerInside: debugPointerActive ? debugPointerInside : pointerInside
    property string flyout: ""             // "" | "power" | "user"
    property bool capitalView: false
    // Capital view transition: the list shrinks away while the letter grid comes
    // in from a larger scale (see Metrics.capital*). The two layers have their
    // own opacity because the reference cross fade overlaps: the incoming view
    // is opaque after ~180 ms while the outgoing one needs ~250 ms to clear.
    property real capitalProgress: 0        // scale timeline, 0 = list, 1 = grid
    property real capitalListOpacity: 1
    property real capitalGridOpacity: 0
    // Off while reset() writes the values back, so the menu does not replay the
    // zoom it was left in.
    property bool capitalAnimations: true
    // Harness overrides (-1 keeps the animated values).
    property real debugCapitalProgress: -1
    property real debugCapitalListOpacity: -1
    property real debugCapitalGridOpacity: -1
    readonly property real capitalScaleProgress: debugCapitalProgress >= 0
                                                  ? debugCapitalProgress : capitalProgress
    readonly property real capitalListFade: debugCapitalListOpacity >= 0
                                            ? debugCapitalListOpacity : capitalListOpacity
    readonly property real capitalGridFade: debugCapitalGridOpacity >= 0
                                            ? debugCapitalGridOpacity : capitalGridOpacity
    onCapitalViewChanged: {
        capitalProgress = capitalView ? 1 : 0
        if (capitalView) {
            capitalGridOpacity = 1
            capitalListOpacity = 0
        } else {
            capitalListOpacity = 1
            capitalGridOpacity = 0
        }
    }
    Behavior on capitalProgress {
        enabled: root.capitalAnimations
        NumberAnimation {
            duration: Metrics.capitalScaleDuration
            easing.type: Easing.OutCubic
        }
    }
    // Arriving view: 180 ms OutQuad. Leaving view: 250 ms linear.
    Behavior on capitalListOpacity {
        enabled: root.capitalAnimations
        NumberAnimation {
            duration: root.capitalView ? Metrics.capitalFadeOutDuration
                                       : Metrics.capitalFadeInDuration
            easing.type: root.capitalView ? Easing.Linear : Easing.OutQuad
        }
    }
    Behavior on capitalGridOpacity {
        enabled: root.capitalAnimations
        NumberAnimation {
            duration: root.capitalView ? Metrics.capitalFadeInDuration
                                       : Metrics.capitalFadeOutDuration
            easing.type: root.capitalView ? Easing.OutQuad : Easing.Linear
        }
    }
    // Open/close animation state: the wallpaper+backdrop and the menu content
    // fade in independently (the reference has the backdrop arrive first).
    property real backdropOpacity: 1
    readonly property real backdropWhiteOpacity: {
        const a = root.backdropOpacity
        if (a >= 1)
            return 0.4
        return 0.1333333 * a / Math.max(1e-3, 1 - 0.6666667 * a)
    }
    property real contentOpacity: 1

    property real contentAnchorX: 1280
    property real contentAnchorY: 690
    // 0..1 timeline of the tile entrance (tiles animate, the rest only fades).
    property real tileEntrance: 1
    property real tileEntranceScaleFrom: 0.80
    property real entranceRowWindow: 0.75
    property real entranceCurve: 5
    property real entranceScaleSlope: 0
    property real entranceOpacityLead: 1.0
    property real entranceOpacityFloor: 0.0
    property real entranceOpacityFloorSlope: 0.0
    property real entranceStagger: 0.3
    property string entranceOrigin: "vertical"
    property real debugTileScale: -1
    property real debugTileOpacity: -1
    property real debugTileRise: -1
    property string capitalHovered: ""
    readonly property bool expandedSidebar: sidebarExpanded

    signal closeRequested()

    function reloadWallpaper() {
        // `runtimeActive` was never a real property here: it threw a
        // ReferenceError on every open. The injected harness context has no
        // runtime behind it, so only reload in the applet itself.
        if (context === null)
            runtime.loadWallpaper()
    }

    // The menu keeps its item tree while the overlay is hidden, so every state
    // the user can leave behind has to be put back: the reference always opens
    // on the pinned tiles with the list at the top, no flyout and the rail
    // collapsed. Called when the overlay is hidden and again before it is shown.
    function reset() {
        cancelDrag()
        flyout = ""
        capitalView = false
        capitalAnimations = false
        capitalProgress = 0
        capitalListOpacity = 1
        capitalGridOpacity = 0
        capitalAnimations = true
        capitalHovered = ""
        view = "tiles"
        switchProgress = 1
        sidebarExpanded = false
        sidebarHoverLocked = false
        renaming = false
        pointerInside = false
        pointerX = -1
        pointerY = -1
        tilesView.resetScroll()
        appList.resetScroll()
    }

    function jumpToLetter(letter) {
        capitalView = false
        appList.scrollToLetter(letter)
    }

    function launchEntry(entry) {
        if (context !== null) {
            if (context.launch)
                context.launch(entry)
        } else {
            runtime.launch(entry)
        }
    }

    // Switching views is not a cross-fade. The reference (switch_app_tile.mp4)
    // drops the outgoing view on the same frame the button is pressed (the tiles
    // are what darkens the surface, so it goes "transparent" at once while the
    // acrylic stays), collapses the sidebar and then pushes the incoming items
    // up from below while they fade in; see motion.js.
    property real switchProgress: 1
    // The pointer is still on the sidebar strip after a switch: hovering must
    // not re-open the panel until it leaves the strip and comes back.
    property bool sidebarHoverLocked: false

    // Hamburger: open/close the panel by hand. Collapsing it this way must not
    // be undone by the dwell while the pointer still rests on the button.
    function toggleSidebar() {
        root.sidebarExpanded = !root.sidebarExpanded
        if (!root.sidebarExpanded) {
            sidebarOpenTimer.stop()
            root.sidebarHoverLocked = root.pointerInSidebarStrip
        }
    }

    function setView(id) {
        if (root.view === id) {
            if (id === "apps")
                root.capitalView = false
            return
        }
        root.capitalView = false
        root.flyout = ""
        root.view = id
        // The panel collapses and stays collapsed while the pointer rests on it.
        // A press also cancels the dwell that arrived here in the first place:
        // pressing inside the first 500 ms must not expand it a moment later.
        root.sidebarExpanded = false
        sidebarOpenTimer.stop()
        root.sidebarHoverLocked = root.pointerInSidebarStrip
        root.switchProgress = 0
        switchAnimation.restart()
    }

    readonly property var appsData: context !== null ? context.apps : runtime.apps
    readonly property var configData: context !== null ? context.config : runtime.config
    readonly property var appLayoutData: context !== null ? context.appLayout : null
    readonly property string wallpaperData: context !== null
                                             ? (context.wallpaper || "")
                                             : runtime.wallpaperUrl
    readonly property string userNameData: context !== null
                                            ? (context.userName || "")
                                            : runtime.userName
    readonly property string avatarData: context !== null
                                         ? (context.avatar || "")
                                         : runtime.avatarUrl

    // The editable copy of the config: ids for stable identity, groups
    // normalised (no empty rows). While a drag is in progress `dragPreview`
    // holds the trial layout that is shown instead.
    property var draftConfig: null
    property var dragPreview: null
    property string dragTileId: ""
    property var dropLine: null
    onConfigDataChanged: {
        draftConfig = configData ? Edit.prepare(configData) : null
        dragPreview = null
        dragTileId = ""
        dropLine = null
    }
    readonly property var activeConfig: dragPreview !== null ? dragPreview : draftConfig
    readonly property var layout: Layout.resolve(activeConfig, appsData || [], { width: width, height: height })
    // Harness hook: the edited layout as JSON (ids included).
    readonly property string debugConfigJson: JSON.stringify(draftConfig || { columns: [] })
    readonly property string debugActiveJson: JSON.stringify(activeConfig || { columns: [] })

    // --- tile drag (M2: a tile inside its own group) ----------------------
    function groupAt(px, py) {
        const groups = layout.groups
        for (var i = 0; i < groups.length; ++i) {
            const g = groups[i]
            // one pitch below the tiles still counts: dropping there appends a
            // row at the end of that group
            if (px >= g.x && px < g.x + g.w && py >= g.y - 6 && py < g.y + g.h + Metrics.pitch)
                return g
        }
        return null
    }

    function beginTileDrag(tileId, px, py) {
        root.dragTileId = tileId
        root.updateTileDrag(px, py)
    }

    // Preview: the cell under the pointer (the drop position itself, clamped to
    // the group), applied to the config as "move this tile there" (see
    // Edit.moveTileWithinGroup). Runs on every move.
    function updateTileDrag(px, py) {
        if (root.draftConfig === null || root.dragTileId === "") {
            root.dragPreview = null
            root.dropLine = null
            return
        }
        const where = Edit.findTile(root.draftConfig, root.dragTileId)
        const group = root.groupAt(px, py)
        if (where === null || group === null
                || group.id !== root.draftConfig.columns[where.column].groups[where.group].id) {
            root.dragPreview = null
            root.dropLine = null
            return
        }
        const pitch = Metrics.pitch
        // The tile's own top left decides the cell, so a tile dropped in the
        // middle of a cell does not drift a column to the right.
        const col = Math.round((tilesView.dragLeftX - group.x) / pitch)
        const row = Math.round((tilesView.dragLeftY - group.y) / pitch)
        root.dragPreview = Edit.moveTileWithinGroup(root.draftConfig, root.dragTileId, col, row)
        // No insertion line for tiles: the empty slot left by the hidden tile
        // (and the row that opens up) already shows where it lands. The line is
        // only used while dragging a whole group.
        root.dropLine = null
    }

    function finishTileDrag(tileId, px, py) {
        root.updateTileDrag(px, py)
        if (root.dragPreview !== null) {
            root.draftConfig = root.dragPreview
            root.persistConfig()
        }
        root.dragPreview = null
        root.dropLine = null
        root.dragTileId = ""
    }

    function cancelDrag() {
        root.dragPreview = null
        root.dropLine = null
        root.dragTileId = ""
        tilesView.cancelDrag()
    }

    function persistConfig() {
        if (root.context !== null || root.draftConfig === null)
            return
        runtime.saveConfig(JSON.stringify(Edit.forStorage(root.draftConfig), null, 1))
    }
    readonly property var sections: (appLayoutData && appLayoutData.sections)
                                     ? appLayoutData.sections
                                     : Layout.appSections(appsData || [])


    // Hovering the sidebar opens it, leaving closes it .A short grace period keeps
    // it open while the pointer moves between the panel and its flyouts.
    // The flyouts hang off the sidebar, so they keep it open too.
    readonly property bool pointerOverFlyout: flyout !== "" && pointerInside
                                              && pointerX > Metrics.sidebarExpandedWidth
                                              && pointerX <= Metrics.sidebarExpandedWidth + 420
    // The strip is where the panel is collapsed to; leaving it re-arms the
    // hover (see sidebarHoverLocked).
    readonly property bool pointerInSidebarStrip: pointerInside && pointerX >= 0
                                                  && pointerX <= Metrics.sidebarCollapsedWidth
    // The panel stays open while the pointer is anywhere over the open panel.
    readonly property bool pointerInSidebarOpen: pointerOverFlyout
                                                 || (pointerInside && pointerX >= 0
                                                     && pointerX <= Metrics.sidebarExpandedWidth)

    // Auto-expand needs the pointer to rest *on a button*, not just inside the
    // panel: the blank parts of the strip do not count, and any movement (within
    // a button as well as from one button to the next) resets the dwell.
    readonly property string sidebarHoverButton: (pointerInside && !sidebarExpanded)
                                                 ? sidebar.buttonAt(pointerX, pointerY) : ""

    function restartSidebarDwell() {
        if (root.sidebarHoverButton === "" || root.sidebarHoverLocked) {
            sidebarOpenTimer.stop()
            return
        }
        sidebarOpenTimer.restart()
    }

    onSidebarHoverButtonChanged: root.restartSidebarDwell()
    onPointerXChanged: root.restartSidebarDwell()
    onPointerYChanged: root.restartSidebarDwell()

    onPointerInSidebarStripChanged: {
        if (pointerInSidebarStrip) {
            sidebarCollapseTimer.stop()
        } else {
            sidebarOpenTimer.stop()
            root.sidebarHoverLocked = false
        }
    }
    onPointerInSidebarOpenChanged: {
        if (pointerInSidebarOpen)
            sidebarCollapseTimer.stop()
        else
            sidebarCollapseTimer.restart()
    }

    // Switching views: see setView.
    NumberAnimation {
        id: switchAnimation
        target: root
        property: "switchProgress"
        from: 0
        to: 1
        duration: Motion.switchDuration
        easing.type: Easing.Linear
    }

    Timer {
        id: sidebarOpenTimer
        interval: Metrics.sidebarHoverDelay
        onTriggered: if (root.sidebarHoverButton !== "" && !root.sidebarHoverLocked)
                         root.sidebarExpanded = true
    }

    Timer {
        id: sidebarCollapseTimer
        interval: 260
        onTriggered: if (!root.pointerInSidebarOpen) root.sidebarExpanded = false
    }

    Runtime {
        id: runtime
        objectName: "runtime"
        visible: false
    }

    clip: true

    // The user / power flyout is a popup: like the reference, a click anywhere
    // outside it closes it instead of waiting for the button to be pressed
    // again. The handler only sees clicks no control below consumed (a tile or
    // an entry click does its own thing, and the menu closes anyway).
    readonly property var flyoutRect: flyout === "power" ? { x: 0, y: 1137, w: 386, h: 165 }
                                    : (flyout === "user" ? { x: 0, y: 993, w: 383, h: 237 }
                                                         : null)
    function closeFlyoutOutside(px, py) {
        const r = flyoutRect
        if (r === null)
            return
        if (px < r.x || px >= r.x + r.w || py < r.y || py >= r.y + r.h)
            flyout = ""
    }
    TapHandler {
        enabled: root.flyout !== ""
        // Close on the press, not on release: the reference closes the popup as
        // soon as the click lands somewhere else.
        onPressedChanged: if (pressed)
                              root.closeFlyoutOutside(point.position.x, point.position.y)
    }

    HoverHandler {
        id: menuHover
        enabled: context === null
        onPointChanged: {
            if (hovered) {
                root.pointerX = point.position.x
                root.pointerY = point.position.y
            }
        }
        onHoveredChanged: root.pointerInside = hovered
    }
    // Wallpaper + backdrop + tiles: everything the sidebar's acrylic blurs.
    Item {
        id: menuBackdrop
        anchors.fill: parent

    // The menu paints the desktop wallpaper itself, aligned 1:1 with the
    // screen (2560x1440 design space), so no compositor backdrop is needed.
    Image {
        id: wallpaperImage
        x: 0
        y: 0
        width: 2560
        height: 1440
        source: root.wallpaperData || ""
        fillMode: Image.PreserveAspectCrop
        smooth: true
        visible: source !== ""
    }

    // 80 % backdrop: the reference composite is exactly 0.2 * wallpaper + 34.
    //
    // While fading in, the backdrop has to be *composited* over the wallpaper,
    // not each layer faded separately: with a = backdropOpacity the target is
    //   (1 - a) * wallpaper + a * (0.2 * wallpaper + 34) = wallpaper * (1 - 0.8a) + 34a
    // Fading both rectangles by `a` would instead give a flat grey wash
    // (const 34 from the very start), which is why the menu looked grey while
    // it was still fading in. Solving for the two opacities gives:
    //   black = 0.6667a, white = 0.1333a / (1 - 0.6667a)
    Rectangle {
        anchors.fill: parent
        color: "#FFFFFF"
        opacity: root.backdropWhiteOpacity
    }
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: 0.6666667 * root.backdropOpacity
    }

    // The tiles layer gets its own scale: the recording shows the tiles
    // sliding towards their final position while they grow.
    Item {
        id: tilesLayer
        anchors.fill: parent
        TilesView {
            id: tilesView
            objectName: "tilesView"
            anchors.fill: parent
            visible: root.view === "tiles"
            contentHeight: root.layout.contentHeight
            dragging: root.dragTileId !== ""
            dropLine: root.dropLine
            groups: root.layout.groups
            titlesVisible: root.groupTitles
            pointerX: root.effectivePointerX
            pointerY: root.effectivePointerY
            pointerInside: root.effectivePointerInside
            entrance: root.tileEntrance
            entranceStagger: root.entranceStagger
            entranceOrigin: root.entranceOrigin
            entranceScaleFrom: root.tileEntranceScaleFrom
            entranceRowWindow: root.entranceRowWindow
            entranceCurve: root.entranceCurve
            entranceScaleSlope: root.entranceScaleSlope
            entranceOpacityLead: root.entranceOpacityLead
            entranceOpacityFloor: root.entranceOpacityFloor
            entranceOpacityFloorSlope: root.entranceOpacityFloorSlope
            entranceCentreX: 1280
            entranceCentreY: 690
            switchProgress: root.switchProgress
            debugHoverTile: root.debugHoverTile
            hoverInjected: root.debugPointerActive
            onTileActivated: (entry) => {
                root.launchEntry(entry)
                root.closeRequested()
            }
            onTileDragStarted: (tileId, px, py) => root.beginTileDrag(tileId, px, py)
            onTileDragMoved: (tileId, px, py) => root.updateTileDrag(px, py)
            onTileDragFinished: (tileId, px, py) => root.finishTileDrag(tileId, px, py)
            onTileDragCanceled: (tileId) => root.cancelDrag()
        }

        // Drop shadow at the panel's right edge (measured on the reference:
        // ~20 % black right next to the panel, fading out over ~21 px).
        Rectangle {
            // follows the animated panel edge and fades in with it
            x: sidebar.x + sidebar.width
            opacity: sidebar.openAmount
            y: 0
            width: 26
            height: parent.height
            visible: sidebar.openAmount > 0.001 || root.sidebarBottomLabels
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "#38000000" }
                GradientStop { position: 1.0; color: "#00000000" }
            }
        }
    }


    }

    // Everything else that belongs to the menu content: animated separately
    // from the wallpaper + backdrop so the backdrop can arrive first.
    Item {
        id: contentLayer
        anchors.fill: parent
        opacity: root.contentOpacity

        AppListView {
            id: appList
            anchors.fill: parent
            // Stays visible while it shrinks away into the capital view.
            visible: root.view === "apps" && root.capitalScaleProgress < 1
            enabled: !root.capitalView
            opacity: root.capitalListFade
            transform: Scale {
                origin.x: appList.width / 2
                origin.y: appList.height / 2
                xScale: 1 - (1 - Metrics.capitalListScale) * root.capitalScaleProgress
                yScale: xScale
            }
            sections: root.sections
            pointerX: root.effectivePointerX
            pointerY: root.effectivePointerY
            pointerInside: root.effectivePointerInside
            hoverInjected: root.debugPointerActive
            debugHoverControl: root.debugHoverControl
            scrollY: root.debugScrollY
            switchProgress: root.switchProgress
            onLettersRequested: root.capitalView = true
            onEntryActivated: (entry) => {
                root.launchEntry(entry)
                root.closeRequested()
            }
        }

        CapitalView {
            anchors.fill: parent
            z: 1
            // Visible from the first frame of the transition until it is gone.
            visible: root.capitalScaleProgress > 0.001
            enabled: root.capitalView
            opacity: root.capitalGridFade
            transform: Scale {
                // The grid scales about its own centre, not the menu's
                // (measured: 1313, 687 in the reference clip).
                origin.x: Metrics.capitalOriginX + (3 * Metrics.capitalPitch + Metrics.capitalCell) / 2
                origin.y: Metrics.capitalOriginY + (7 * Metrics.capitalPitch + Metrics.capitalCell) / 2
                xScale: Metrics.capitalGridScale
                        - (Metrics.capitalGridScale - 1) * root.capitalScaleProgress
                yScale: xScale
            }
            letters: appList.lettersList()
            pointerX: root.effectivePointerX
            pointerY: root.effectivePointerY
            pointerInside: root.effectivePointerInside
            hoveredKey: root.capitalHovered
            hoverInjected: root.debugPointerActive
            debugHoverControl: root.debugHoverControl
            onLetterActivated: (key) => {
                root.capitalView = false
                appList.scrollToLetter(key)
            }
            onDismissed: root.capitalView = false
        }

        Sidebar {
            id: sidebar
            expanded: root.sidebarExpanded
            bottomLabels: root.sidebarBottomLabels
            hovered: root.sidebarHover
            separators: root.bottomSeparators
            selected: root.view === "apps" ? "apps" : "tiles"
            wallpaperUrl: root.wallpaperData || ""
            panelAlpha: root.sidebarPanelAlpha
            blurMax: root.sidebarBlurMax
            blurSaturation: root.sidebarBlurSaturation
            blurBrightness: root.sidebarBlurBrightness
            blurContrast: root.sidebarBlurContrast
            noiseOpacity: root.sidebarNoiseOpacity
            blurAmount: root.sidebarBlurAmount
            blurSourceItem: menuBackdrop
            blurDownscale: root.sidebarBlurDownscale
            pointerX: root.effectivePointerX
            pointerY: root.effectivePointerY
            pointerInside: root.effectivePointerInside
            debugHoverControl: root.debugHoverControl
            hoverInjected: root.debugPointerActive
            userName: root.userNameData || ""
            avatar: root.avatarData || ""
            onSectionActivated: (id) => {
                root.capitalView = false
                if (id === "toggle")
                    root.toggleSidebar()
                else
                    root.setView(id)
            }
            onPowerActivated: root.flyout = (root.flyout === "power" ? "" : "power")
            onUserActivated: root.flyout = (root.flyout === "user" ? "" : "user")
        }

        Flyout {
            kind: root.flyout
            userName: root.userNameData || ""
            avatar: root.avatarData || ""
            onPowerAction: (action) => {
                if (root.runtimeActive)
                    runtime.powerAction(action)
                root.closeRequested()
            }
        }

        // Group rename overlay
        Item {
            visible: root.renaming
            x: 995
            y: 837
            width: 569
            height: 84

            Rectangle { anchors.fill: parent; color: "#4A78A4" }
            Rectangle { x: 12; y: 21; width: 483; height: 41; color: "#FFFFFF" }
            Rectangle { x: 21; y: 27; width: 2; height: 30; color: "#000000" }
            Rectangle { x: 522; y: 39; width: 23; height: 2; color: "#FFFFFF" }
            Rectangle { x: 522; y: 43; width: 23; height: 2; color: "#FFFFFF" }
        }
    }
}
