// MetroStart menu surface: backdrop, tiles or app list, sidebar and flyouts.
import QtQuick
import "metrics.js" as Metrics
import "CompactMetrics.js" as Compact
import "motion.js" as Motion
import "Layout.js" as Layout
import "Edit.js" as Edit

Item {
    id: root
    objectName: "metroMenu"

    // Injected by the preview harness; when null the applet uses its own data.
    property var context: null
    // Design pixels -> device-independent pixels (see main.qml): the menu is
    // laid out in design px and the whole surface is scaled by this factor, so
    // Qt maps it to the display with the window's device pixel ratio. The
    // render harness keeps 1, i.e. a 2560x1380 canvas renders 1:1.
    property real uiScale: 1
    transform: Scale {
        origin.x: 0
        origin.y: 0
        xScale: root.uiScale
        yScale: root.uiScale
    }
    // "fullscreen" (the reference Start) or "windowed" (the non-fullscreen
    // Start of non-fullscreen-start/). Both share the tile components.
    property string menuMode: "fullscreen"
    // Bottom inset of the windowed menu (its panel ends above this strip).
    property real windowBottomInset: 0
    // Non-fullscreen layout state: columns of the tile area (1..4) and the
    // panel height (drag it between half the screen and the top edge).
    // Skin of the tiles: "modern" (translucent, the reference screenshots) or
    // "early" (coloured tiles, see plans/EARLY-STYLE-INTEGRATION.md).
    property string tileSkin: "modern"
    property string tilePalette: "default"
    property bool forceAppColor: true
    property string themedIcon: "auto"
    property bool liveTilesEnabled: false
    property bool liveTileCycle: true
    property string liveTileVariant: "auto"
    property bool pulseOnUpdate: false
    readonly property string homeDir: runtime && runtime.homeDir ? runtime.homeDir : ""
    property string weatherSource: ""
    property bool moreLiveAni: true
    // Linear 0..1 driver of the windowed menu's scale-in animation.
    property real compactOpenLinear: 1
    property int compactColumns: 3
    property real compactPanelHeight: 1124
    // Design rect of the desktop wallpaper (see main.qml): the canvas starts
    // at the work area, the wallpaper stays aligned 1:1 with the screen.
    property rect wallpaperRect: Qt.rect(0, 0, Metrics.canvasWidth, 1440)
    // The canvas is wider than the reference design when it has to hold more
    // tile columns; the application list and the letter grid stay centred on
    // the reference design instead of drifting left.
    readonly property real contentOffsetX: Math.round((width - Metrics.canvasWidth) / 2)
    // Recently launched applications, shown as "最近添加" in the list.
    property var recentApps: context !== null && context.recentApps !== undefined
                             ? context.recentApps : []
    readonly property var compactMetrics: Compact.values()
    // Columns the windowed panel can still hold on this canvas (the user picks
    // 1..4, the screen limits the upper bound).
    readonly property int compactColumnsMax: Layout.compactCapacity(width, compactMetrics)
    readonly property int compactColumnsFit: Math.max(1, Math.min(compactColumns,
                                                          compactColumnsMax))
    // Columns the fullscreen canvas holds: the reference canvas fits exactly
    // three, a wider one more, a narrower one fewer.
    readonly property int fullscreenCapacity: Layout.columnsCapacity(width, Metrics)
    readonly property real compactPanelWidth: Compact.panelWidth(compactColumnsFit)
    readonly property real compactTilesX: Compact.panelBaseWidth
    readonly property real compactTilesWidth: compactPanelWidth - compactTilesX
                                              - Compact.tilesGapToPanelRight
    readonly property var compactLayout: Layout.resolve(activeConfig, appsData || [],
                                                        { width: compactTilesWidth },
                                                        compactMetrics, compactColumnsFit)
    readonly property var compactSections: Layout.compactSections(appsData || [],
                                                                  recentApps)
    // Rect of the power / user flyout in menu coordinates (used to keep the
    // pointer away from what is behind it).
    readonly property var flyoutGeom: {
        if (flyout === "")
            return null
        const h = flyout === "power" ? 165 : 237
        const ay = menuMode === "windowed"
                   ? (flyout === "power" ? compactPanelTop + compactPanelHeightFit - 78
                                         : compactPanelTop + compactPanelHeightFit - 150)
                   : (flyout === "power" ? height - 78 : height - 150)
        return { x: 0, y: ay - h, w: 386, h: h }
    }

    // The panel is never taller than the canvas it sits in (a small screen
    // needs the same 60 design px of headroom as the reference).
    readonly property real compactPanelHeightFit: Math.max(690,
        Math.min(compactPanelHeight, height - 60))
    // Pointer position inside the windowed panel (its top edge moves). The
    // panel's bottom edge sits on the menu's bottom edge.
    readonly property real compactPanelTop: height - compactPanelHeightFit
    readonly property real panelPointerY: effectivePointerY - compactPanelTop
    readonly property real sidebarWidthNow: sidebarExpanded
                                                 ? Compact.sidebarExpanded
                                                 : Compact.sidebarWidth
    // The view the tile code drives: the fullscreen one or the windowed one.
    // Both are lazily loaded (see the Loaders below), so the one that is not in
    // use is null and every caller has to tolerate that.
    readonly property var activeTileView: menuMode === "windowed"
                                          ? (compactLoader.item
                                             ? compactLoader.item.tilesView : null)
                                          : (tilesLoader.item || null)

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
    // Group rename lives in the title block itself (see TilesView): the block
    // turns into the editor, so there is no geometry to keep in sync here.
    readonly property bool renaming: activeTileView !== null
                                     && activeTileView.renamingGroupId !== ""

    function beginGroupRename(groupId) {
        if (activeTileView !== null)
            activeTileView.beginGroupRename(groupId)
    }

    // Is the point (menu coordinates) inside the block that is being renamed?
    function renameHit(px, py) {
        if (!renaming || activeTileView === null)
            return false
        const r = activeTileView.renameRect
        const p = activeTileView.mapToItem(root, r.x, r.y)
        return px >= p.x && px <= p.x + r.width && py >= p.y && py <= p.y + r.height
    }
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

    // Centre of the canvas: the entrance animation scales about it. At the
    // reference canvas it is the measured 1280 / 690. The render harness can
    // override both to replay the measured motion.
    property real contentAnchorX: Math.round(width / 2)
    property real contentAnchorY: Math.round(height / 2)
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
        // runtime behind it, so only reload in the applet itself. Runtime
        // throttles the lookup (it forks qdbus6), so calling it per open is
        // still cheap.
        if (context === null)
            runtime.loadWallpaper(false)
    }

    // The menu keeps its item tree while the overlay is hidden, so every state
    // the user can leave behind has to be put back: the reference always opens
    // on the pinned tiles with the list at the top, no flyout and the rail
    // collapsed. Called when the overlay is hidden and again before it is shown.
    function reset() {
        closeContextMenu()
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
        if (activeTileView !== null) activeTileView.renamingGroupId = ""
        pointerInside = false
        pointerX = -1
        pointerY = -1
        if (tilesLoader.item) tilesLoader.item.resetScroll()
        if (compactLoader.item) compactLoader.item.resetScroll()
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
    // Native SystemAccentColor, configurable in the applet settings.
    property color accentColor: Metrics.accentColorDefault
    property string dragTileId: ""
    // What the dragged tile would hit: an existing group cell or a new group
    // slot (the preview of the latter shows only the candidate bar).
    property var tileTarget: null
    // Geometry snapshot taken when a tile is picked up: the drop target is
    // computed against it, so the preview cannot feed back into the hit test.
    property var tileDragLayout: null
    // Group drag: the grabbed group id, the placeholder config shown while
    // dragging and the drop position it stands for.
    property string dragGroupId: ""
    property var groupPreview: null
    property var groupTarget: null
    property var groupDragLayout: null
    onConfigDataChanged: reloadConfig()
    // A canvas that holds another number of columns reflows the config (see
    // reflowToCanvas); the menu itself follows the screen.
    onWidthChanged: reflowToCanvas()
    onMenuModeChanged: reflowToCanvas()

    function reloadConfig() {
        draftConfig = configData ? Edit.prepare(configData) : null
        dragPreview = null
        dragTileId = ""
        reflowToCanvas()
    }

    // The tile columns follow the canvas width: the config was written for one
    // column count, so when the display holds another one the groups are
    // reflowed into the columns that fit (as the Windows Start does). At the
    // reference canvas this is a no-op, and what the user sees is what gets
    // written back.
    function reflowToCanvas() {
        // Before Plasma reports the work area the canvas width is still 0; the
        // reflow waits for the real width so the stored arrangement is
        // rebalanced once, not twice.
        if (draftConfig === null || menuMode === "windowed" || width <= 0)
            return
        const reflowed = Layout.reflow(draftConfig, appsData || [],
                                       { width: width, height: height }, Metrics)
        if (reflowed !== null)
            draftConfig = Edit.prepare(reflowed)
    }
    readonly property var activeConfig: dragPreview !== null ? dragPreview
                                       : (groupPreview !== null ? groupPreview : draftConfig)
    readonly property var layout: Layout.resolve(activeConfig, appsData || [], { width: width, height: height })
    // The layout the tile code works on (the fullscreen or the windowed one).
    readonly property var activeLayout: menuMode === "windowed" ? compactLayout : layout
    // Harness hook: the edited layout as JSON (ids included).
    readonly property string debugConfigJson: JSON.stringify(draftConfig || { columns: [] })
    readonly property string debugActiveJson: JSON.stringify(activeConfig || { columns: [] })

    // --- tile drag (M2: a tile inside its own group) ----------------------
    // Group under the point (content coordinates). `below` extends the hit
    // area downwards: a group drag accepts a little below the tiles (appending
    // a row), a tile drop does not (that is empty space, i.e. a new group).
    function groupAtIn(lay, px, py, below, above) {
        const groups = lay ? lay.groups : []
        const margin = below === undefined ? 0 : below
        const top = above === undefined ? 6 : above
        for (var i = 0; i < groups.length; ++i) {
            const g = groups[i]
            if (px >= g.x && px < g.x + g.w && py >= g.y - top && py < g.y + g.h + margin)
                return g
        }
        return null
    }

    function groupAt(px, py, below) {
        return root.groupAtIn(root.activeLayout, px, py, below)
    }

    // A new column only fits when the fixed canvas can still hold it.
    function canAddColumn() {
        // The column count follows the canvas now: only a canvas that still
        // has room for another column (i.e. a wider screen) accepts one.
        return layout.columns.length < root.fullscreenCapacity
    }

    function beginTileDrag(tileId, px, py) {
        root.dragTileId = tileId
        root.tileDragLayout = menuMode === "windowed"
                ? Layout.resolve(root.draftConfig, root.appsData || [],
                                 { width: compactTilesWidth }, compactMetrics, compactColumnsFit)
                : Layout.resolve(root.draftConfig, root.appsData || [],
                                 { width: root.width, height: root.height })
        root.updateTileDrag(px, py)
    }

    // Preview of where the dragged tile lands, in content coordinates:
    //   * on a group: the cell under the tile (same group = reorder, another
    //     group = move it there),
    //   * between/below groups: a new group at that spot (candidate bar),
    //   * in the empty area right of the last column: a new column when the
    //     canvas can still hold it, otherwise a new group at the end.
    function updateTileDrag(px, py) {
        root.tileTarget = null
        if (root.draftConfig === null || root.dragTileId === "") {
            root.dragPreview = null
            return
        }
        const where = Edit.findTile(root.draftConfig, root.dragTileId)
        if (where === null) {
            root.dragPreview = null
            return
        }
        const sourceGroup = root.draftConfig.columns[where.column].groups[where.group]
        const pitch = Metrics.pitch
        const lay = root.tileDragLayout !== null ? root.tileDragLayout : root.activeLayout
        // A group answers for its tiles, its title block above them and a
        // strip under the last row, so reaching the first or last row is easy;
        // a new group only starts clearly outside that (see metrics.js).
        const group = root.groupAtIn(lay, px, py, Metrics.tileDropBelowGroup,
                                     Metrics.tileDropAboveGroup)
        const view = activeTileView
        if (group !== null && view !== null) {
            const col = Math.round((view.dragLeftX - group.x) / pitch)
            const row = Math.round((view.dragLeftY + view.scrollY - group.y) / pitch)
            root.tileTarget = { kind: "group", groupId: group.id, col: col, row: row }
            root.dragPreview = group.id === sourceGroup.id
                    ? Edit.moveTileWithinGroup(root.draftConfig, root.dragTileId, col, row)
                    : Edit.moveTileToGroup(root.draftConfig, root.dragTileId, group.id, col, row)
            return
        }
        if (lay.columns.length === 0) {
            root.dragPreview = null
            return
        }
        const last = lay.columns[lay.columns.length - 1]
        const beyondRight = px > last.x + last.width + Metrics.groupGapX / 2
        if (beyondRight && root.canAddColumn()) {
            root.tileTarget = { kind: "new", column: lay.columns.length, index: 0 }
            root.dragPreview = Edit.previewNewGroup(root.draftConfig, root.dragTileId,
                                                    lay.columns.length, 0)
            return
        }
        // otherwise: a new group at the nearest column, at the matching slot
        var column = 0
        var best = 1e9
        for (var i = 0; i < lay.columns.length; ++i) {
            const d = Math.abs(px - (lay.columns[i].x + lay.columns[i].width / 2))
            if (d < best) {
                best = d
                column = i
            }
        }
        var groups = []
        for (var g = 0; g < lay.groups.length; ++g) {
            if (lay.groups[g].column === column)
                groups.push(lay.groups[g])
        }
        var index = groups.length
        for (var k = 0; k < groups.length; ++k) {
            if (py < groups[k].y + groups[k].h / 2) {
                index = k
                break
            }
        }
        root.tileTarget = { kind: "new", column: column, index: index }
        root.dragPreview = Edit.previewNewGroup(root.draftConfig, root.dragTileId, column, index)
    }

    function finishTileDrag(tileId, px, py) {
        root.updateTileDrag(px, py)
        const target = root.tileTarget
        if (target !== null && target.kind === "new") {
            // the preview only holds the candidate bar: create the group with
            // the tile in it now
            const next = Edit.newGroupWithTile(root.draftConfig, root.dragTileId,
                                               target.column, target.index)
            if (next !== null) {
                // the candidate bar is only a preview: committed layouts must
                // not keep the placeholder marker
                root.draftConfig = Edit.finalize(next)
                root.persistConfig()
            }
        } else if (root.dragPreview !== null) {
            root.draftConfig = Edit.finalize(root.dragPreview)
            root.persistConfig()
        }
        root.dragPreview = null
        root.tileTarget = null
        root.dragTileId = ""
        root.tileDragLayout = null
    }

    function cancelDrag() {
        root.dragPreview = null
        root.tileTarget = null
        root.dragTileId = ""
        root.tileDragLayout = null
        if (tilesLoader.item) tilesLoader.item.cancelDrag()
        if (compactLoader.item) compactLoader.item.cancelScrollDrag()
        if (root.dragGroupId !== "") {
            root.endGroupDragState()
            if (activeTileView !== null)
                activeTileView.cancelGroupDrag()
        }
    }

    // --- group drag -------------------------------------------------------
    function beginGroupDrag(groupId, px, py) {
        if (root.draftConfig === null)
            return
        root.dragGroupId = groupId
        // Snapshot of the pre-drag geometry: the drop position is computed
        // against it, so the moving preview cannot feed back into the target.
        root.groupDragLayout = menuMode === "windowed"
                ? Layout.resolve(root.draftConfig, root.appsData || [],
                                 { width: compactTilesWidth }, compactMetrics, compactColumnsFit)
                : Layout.resolve(root.draftConfig, root.appsData || [],
                                 { width: root.width, height: root.height })
        root.updateGroupDrop(px, py)
    }

    function updateGroupDrop(px, py) {
        if (root.draftConfig === null || root.dragGroupId === ""
                || root.groupDragLayout === null) {
            root.groupPreview = null
            return
        }
        const lay = root.groupDragLayout
        if (lay.columns.length === 0) {
            root.groupPreview = null
            return
        }
        // target column: the one whose centre is closest to the pointer
        var column = 0
        var best = 1e9
        for (var i = 0; i < lay.columns.length; ++i) {
            const d = Math.abs(px - (lay.columns[i].x + lay.columns[i].width / 2))
            if (d < best) {
                best = d
                column = i
            }
        }
        // insertion index inside that column, ignoring the dragged group
        var groups = []
        for (var g = 0; g < lay.groups.length; ++g) {
            if (lay.groups[g].column === column && lay.groups[g].id !== root.dragGroupId)
                groups.push(lay.groups[g])
        }
        var index = groups.length
        for (var k = 0; k < groups.length; ++k) {
            if (py < groups[k].y + groups[k].h / 2) {
                index = k
                break
            }
        }
        // Only rebuild the preview when the drop position changes: rebuilding
        // on every pixel re-flows the whole tile area (and re-evaluates every
        // delegate) sixty times a second.
        const previous = root.groupTarget
        if (previous !== null && previous.column === column && previous.index === index)
            return
        root.groupTarget = { column: column, index: index }
        root.groupPreview = Edit.previewGroupDrop(root.draftConfig, root.dragGroupId,
                                                  column, index)
    }

    function finishGroupDrag(groupId, px, py) {
        root.updateGroupDrop(px, py)
        if (root.groupTarget !== null) {
            const next = Edit.moveGroup(root.draftConfig, root.dragGroupId,
                                        root.groupTarget.column, root.groupTarget.index)
            if (next !== null) {
                root.draftConfig = next
                root.persistConfig()
            }
        }
        root.endGroupDragState()
    }

    function endGroupDragState() {
        root.dragGroupId = ""
        root.groupPreview = null
        root.groupTarget = null
        root.groupDragLayout = null
    }

    // --- context menu (right click) --------------------------------------
    property var contextMenuModel: []
    property bool contextMenuOpen: false
    property real contextMenuX: 0
    property real contextMenuY: 0
    property bool contextMenuGrowUp: false
    property bool contextMenuGrowLeft: false
    // What the open menu acts on: { kind: "tile"|"entry"|"group", ... }.
    property var contextMenuTarget: null
    // The tile (id) / list entry whose menu is open: it keeps its highlight
    // while the popup is up, everything else behind the menu stays dark.
    property string contextHoverTile: ""
    property var contextMenuEntry: null
    // While the popup is up the pointer only belongs to it inside its own rect:
    // outside, the tiles and entries behind keep working (they just do not
    // highlight, see hoverBlocked).
    readonly property bool pointerOverContextMenu:
        contextMenuOpen && effectivePointerInside
        && effectivePointerX >= 0 && effectivePointerY >= 0
        && contextMenu.containsPoint(effectivePointerX, effectivePointerY)
    // Harness hooks for the render tools (-1 / "" = live values).
    property real debugContextProgress: -1
    property int debugContextHoverRow: -1
    property int debugContextOpenRow: -1
    property real debugContextSubmenuProgress: -1
    property bool debugContextPointerActive: false
    property real debugContextPointerX: -1
    property real debugContextPointerY: -1
    // Harness: pretend the screen is shorter (-1 = the menu's own height).
    property real debugContextBoundsHeight: -1
    // Harness: force the title-block hover of one group ("*" = all).
    property string debugHoverGroupId: ""
    // Read-only view of the context menu's opening progress (sample tools).
    readonly property real debugContextAmount: contextMenu.openAmount
    readonly property real debugContextTime: contextMenu.openTime

    readonly property string iconUnpin: Qt.resolvedUrl("../assets/ui/menu-unpin.png")
    readonly property string iconPin: Qt.resolvedUrl("../assets/ui/menu-pin.png")
    readonly property string iconShield: Qt.resolvedUrl("../assets/ui/menu-shield.png")
    readonly property string iconFolder: Qt.resolvedUrl("../assets/ui/menu-folder.png")

    // "More" submenu of the shell: the commands the applet can really run.
    function moreMenuItems(entry) {
        const items = [
            { label: "以管理员身份运行", icon: iconShield, action: "runAsAdmin", data: entry },
            { label: "打开文件位置", icon: iconFolder, action: "openLocation", data: entry }
        ]
        return items
    }

    function sizeMenuItems(entry) {
        // Only the two sizes the reference menu shows for an ordinary tile;
        // wide/large stay in the model but are not offered yet.
        const sizes = [["1x1", "小"], ["2x2", "中"]]
        const current = entry && entry.size ? entry.size : "2x2"
        const items = []
        for (let i = 0; i < sizes.length; ++i) {
            items.push({ label: sizes[i][1], sizeGlyph: sizes[i][0],
                         checked: sizes[i][0] === current,
                         action: "resize:" + sizes[i][0], data: entry })
        }
        return items
    }

    // The tile menu of the reference: unpin / resize / more (+ uninstall, which
    // has no meaning for a .desktop entry and is left out).
    // Tile style slots of the early skin (see TileColors.js).
    readonly property var styleNames: ["蓝", "橙", "青", "红", "黄", "靛蓝",
        "粉", "绿", "紫", "黑", "深灰", "中灰", "浅灰", "半透明", "透明"]

    function styleMenuItems(entry) {
        const current = entry && entry.style !== undefined && entry.style !== null
                        ? Number(entry.style) : -1
        const items = [{ label: "自动（按应用）", checked: current < 0,
                         action: "style:-1", data: entry }]
        for (let i = 0; i < styleNames.length; ++i) {
            items.push({ label: "样式 " + (i + 1) + "（" + styleNames[i] + "）",
                         checked: current === i, action: "style:" + i, data: entry })
        }
        return items
    }

    // Live content kinds offered by the early skin (see LiveTile.qml).
    readonly property var liveKinds: [["", "无"], ["clock", "时钟"],
                                      ["battery", "电池"], ["date", "日期"],
                                      ["calendar", "月历"], ["weather", "天气"],
                                      ["photos", "图片轮播"]]

    function liveMenuItems(entry) {
        const current = entry && entry.live ? String(entry.live.type || "") : ""
        const items = []
        for (let i = 0; i < liveKinds.length; ++i) {
            items.push({ label: liveKinds[i][1], checked: current === liveKinds[i][0],
                         action: "live:" + liveKinds[i][0], data: entry })
        }
        return items
    }

    function tileMenuModel(entry) {
        return [
            { label: "从\"开始\"屏幕取消固定", icon: iconUnpin, action: "unpinTile", data: entry },
            { label: "调整大小", chevron: true, submenu: sizeMenuItems(entry) },
            { label: "磁贴颜色", chevron: true, submenu: styleMenuItems(entry) },
            { label: "动态磁贴", chevron: true, submenu: liveMenuItems(entry) },
            { label: "更多", chevron: true, submenu: moreMenuItems(entry) }
        ]
    }

    function entryMenuModel(entry) {
        return [
            { label: "固定到\"开始\"屏幕", icon: iconPin, action: "pinApp", data: entry },
            { label: "更多", chevron: true, submenu: moreMenuItems(entry) }
        ]
    }

    function groupMenuModel(groupId) {
        return [
            { label: "从\"开始\"菜单中取消固定组", icon: iconUnpin,
              action: "unpinGroup", data: { groupId: groupId } }
        ]
    }

    function contextMenuHeight(model) {
        return contextMenu.contentHeightFor(model)
    }

    // The panel always opens from a corner at the pointer: down-right by
    // default, mirrored to the left when it does not fit on the right and
    // mirrored upwards when it does not fit below.
    function openContextMenuAt(model, target, px, py) {
        root.contextMenuModel = model
        root.contextMenuTarget = target
        const h = contextMenuHeight(model)
        const w = Metrics.contextMenuWidth
        const x = Math.round(px)
        const y = Math.round(py)
        let left = x + w > root.width
        let up = y + h > root.height
        // Neither side is wide/tall enough: fall back to the screen's edges.
        if (left && x - w < 0)
            left = false
        if (up && y - h < 0)
            up = false
        root.contextMenuX = left ? x : Math.min(x, Math.max(0, root.width - w))
        root.contextMenuY = up ? y : Math.min(y, Math.max(0, root.height - h))
        root.contextMenuGrowLeft = left
        root.contextMenuGrowUp = up
        root.contextMenuOpen = true
    }

    function closeContextMenu() {
        root.contextMenuOpen = false
        root.contextMenuModel = []
        root.contextMenuTarget = null
        root.contextHoverTile = ""
        root.contextMenuEntry = null
    }

    function openTileContextMenu(entry, sx, sy) {
        const p = root.mapFromItem(null, sx, sy)
        root.contextHoverTile = entry && entry.id ? entry.id : ""
        root.contextMenuEntry = null
        openContextMenuAt(tileMenuModel(entry), { kind: "tile", entry: entry }, p.x, p.y)
    }

    function openEntryContextMenu(entry, sx, sy) {
        const p = root.mapFromItem(null, sx, sy)
        root.contextHoverTile = ""
        root.contextMenuEntry = entry
        openContextMenuAt(entryMenuModel(entry), { kind: "entry", entry: entry }, p.x, p.y)
    }

    function openGroupContextMenu(groupId, sx, sy) {
        const p = root.mapFromItem(null, sx, sy)
        root.contextHoverTile = ""
        root.contextMenuEntry = null
        openContextMenuAt(groupMenuModel(groupId), { kind: "group", groupId: groupId }, p.x, p.y)
    }

    // Run the command of an activated row.
    function contextMenuAction(row) {
        const target = root.contextMenuTarget
        const action = row.action || ""
        closeContextMenu()
        if (action.indexOf("live:") === 0) {
            if (target === null || root.draftConfig === null)
                return
            const entry = row.data || {}
            const next = Edit.setTileLive(root.draftConfig, entry.id,
                                         action.substring(5))
            if (next !== null) {
                root.draftConfig = next
                root.persistConfig()
            }
            return
        }
        if (action.indexOf("style:") === 0) {
            if (target === null || root.draftConfig === null)
                return
            const entry = row.data || {}
            const next = Edit.setTileStyle(root.draftConfig, entry.id,
                                          parseInt(action.substring(6), 10))
            if (next !== null) {
                root.draftConfig = next
                root.persistConfig()
            }
            return
        }
        if (action.indexOf("resize:") === 0) {
            if (target === null || root.draftConfig === null)
                return
            const entry = row.data || {}
            // The view fades the tile out first and asks for the change once it
            // is invisible (see TilesView.beginSizeChange).
            if (activeTileView !== null)
                activeTileView.beginSizeChange(entry.id, action.slice(7))
            return
        }
        switch (action) {
        case "unpinTile": {
            if (root.draftConfig === null || target === null)
                return
            const entry = row.data || {}
            const next = Edit.removeTile(root.draftConfig, entry.id)
            if (next !== null) {
                root.draftConfig = next
                root.persistConfig()
            }
            break
        }
        case "pinApp": {
            if (root.draftConfig === null)
                return
            const entry = row.data || {}
            const next = Edit.addTile(root.draftConfig, entry.desktopId || entry.id, "2x2")
            if (next !== null) {
                root.draftConfig = next
                root.persistConfig()
            }
            break
        }
        case "unpinGroup": {
            if (root.draftConfig === null || target === null)
                return
            const data = row.data || {}
            const next = Edit.removeGroup(root.draftConfig, data.groupId)
            if (next !== null) {
                root.draftConfig = next
                root.persistConfig()
            }
            break
        }
        case "openLocation": {
            const entry = row.data || {}
            const path = entry.desktopPath || entry.path || ""
            if (path === "")
                return
            const dir = path.substring(0, path.lastIndexOf("/"))
            if (root.context !== null) {
                if (root.context.openLocation)
                    root.context.openLocation(dir)
            } else {
                runtime.run("xdg-open \"" + dir + "\"")
            }
            break
        }
        case "runAsAdmin": {
            const entry = row.data || {}
            const path = entry.desktopPath || entry.path || ""
            if (path === "")
                return
            const id = path.split("/").pop().replace(/\.desktop$/, "")
            if (root.context !== null) {
                if (root.context.runAsAdmin)
                    root.context.runAsAdmin(id)
            } else {
                runtime.run("pkexec gtk-launch \"" + id + "\"")
            }
            break
        }
        }
    }

    function openFlyout(kind) {
        flyout = flyout === kind ? "" : kind
    }

    function renameGroup(groupId, title) {
        if (draftConfig === null)
            return
        const next = Edit.setGroupTitle(draftConfig, groupId, title)
        if (next !== null) {
            draftConfig = next
            persistConfig()
        }
    }

    function requestTileSize(tileId, size) {
        if (draftConfig === null)
            return
        const next = Edit.resizeTile(draftConfig, tileId, size)
        if (next !== null) {
            draftConfig = next
            persistConfig()
        }
    }

    function launchAndRemember(entry) {
        launchEntry(entry)
        if (entry) {
            var list = recentApps.slice(0)
            var copy = { id: entry.desktopId || entry.id || "",
                         name: entry.name || entry.label || "",
                         icon: entry.icon || "", path: entry.path || "" }
            for (var i = list.length - 1; i >= 0; --i) {
                if (list[i].name === copy.name)
                    list.splice(i, 1)
            }
            list.unshift(copy)
            recentApps = list.slice(0, 3)
        }
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
    readonly property var flyoutRect: flyout === "power"
                                      ? { x: 0, y: height - 78 - 165, w: 386, h: 165 }
                                      : (flyout === "user"
                                         ? { x: 0, y: height - 150 - 237, w: 383, h: 237 }
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
    // Non-fullscreen Start menu (see CompactMenu.qml).
    // The windowed Start owns a second tile view and app list of its own, so it
    // is loaded only while that mode is on. `compactMode` is a setting, not an
    // animation state, so swapping it reloads the menu once and never mid-open.
    Loader {
        id: compactLoader
        anchors.fill: parent
        active: root.menuMode === "windowed"
        sourceComponent: CompactMenu {
            objectName: "compactMenu"
            anchors.fill: parent
            menu: root
            openLinear: root.compactOpenLinear
            wallpaperUrl: root.wallpaperData || ""
            wallpaperRect: root.wallpaperRect
            columns: root.compactColumnsFit
            maxColumns: root.compactColumnsMax
            panelHeight: root.compactPanelHeightFit
            opacity: root.contentOpacity
            onColumnsRequested: (n) => root.compactColumns = Math.min(n, root.compactColumnsMax)
            onPanelHeightRequested: (h) => root.compactPanelHeight = h
            onSidebarExpandedRequested: (v) => root.sidebarExpanded = v
        }
    }

    // Wallpaper + backdrop + tiles: everything the sidebar's acrylic blurs.
    Item {
        id: menuBackdrop
        anchors.fill: parent
        visible: root.menuMode !== "windowed"

    // The menu paints the desktop wallpaper itself, aligned 1:1 with the
    // screen (see wallpaperRect), so no compositor backdrop is needed.
    Image {
        id: wallpaperImage
        x: root.wallpaperRect.x
        y: root.wallpaperRect.y
        width: root.wallpaperRect.width
        height: root.wallpaperRect.height
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
    //
    // The view is loaded lazily: the fullscreen and the windowed Start own one
    // each, and keeping both instantiated meant two full tile trees (every
    // tile delegate, its live content and its timers) alive at the same time
    // while only one is ever visible.
    Item {
        id: tilesLayer
        anchors.fill: parent
        visible: root.menuMode !== "windowed"
        Loader {
            id: tilesLoader
            anchors.fill: parent
            active: root.menuMode !== "windowed"
            visible: root.view === "tiles"
            sourceComponent: TilesView {
                objectName: "tilesView"
                anchors.fill: parent
                tileSkin: root.tileSkin
                tilePalette: root.tilePalette
                forceAppColor: root.forceAppColor
                themedIcon: root.themedIcon
                liveTilesEnabled: root.liveTilesEnabled
                liveTileCycle: root.liveTileCycle
                pulseOnUpdate: root.pulseOnUpdate
                liveTileVariant: root.liveTileVariant
                homeDir: root.homeDir
                weatherSource: root.weatherSource
                moreLiveAni: root.moreLiveAni
                accentColor: root.accentColor
                contentHeight: root.layout.contentHeight
                dragging: root.dragTileId !== ""
                backdropWhite: root.backdropWhiteOpacity
                backdropBlack: 0.6666667 * root.backdropOpacity
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
                entranceCentreX: root.contentAnchorX
                entranceCentreY: root.contentAnchorY
                switchProgress: root.switchProgress
                debugHoverTile: root.debugHoverTile
                hoverInjected: root.debugPointerActive
                onTileActivated: (entry) => {
                    root.launchEntry(entry)
                    root.closeRequested()
                }
                contextHoverTile: root.contextHoverTile
                pointerBlocked: root.pointerOverContextMenu
                hoverBlocked: root.contextMenuOpen
                debugHoverGroupId: root.debugHoverGroupId
                onSizeChangeRequested: (tileId, size) => {
                    const next = Edit.resizeTile(root.draftConfig, tileId, size)
                    if (next !== null) {
                        root.draftConfig = next
                        root.persistConfig()
                    }
                }
                onTileContextRequested: (entry, sx, sy) => root.openTileContextMenu(entry, sx, sy)
                onGroupContextRequested: (groupId, sx, sy) => root.openGroupContextMenu(groupId, sx, sy)
                onGroupRenamed: (groupId, title) => {
                    if (root.draftConfig === null)
                        return
                    const next = Edit.setGroupTitle(root.draftConfig, groupId, title)
                    if (next !== null) {
                        root.draftConfig = next
                        root.persistConfig()
                    }
                }
                onTileDragStarted: (tileId, px, py) => root.beginTileDrag(tileId, px, py)
                onTileDragMoved: (tileId, px, py) => root.updateTileDrag(px, py)
                onTileDragFinished: (tileId, px, py) => root.finishTileDrag(tileId, px, py)
                onTileDragCanceled: (tileId) => root.cancelDrag()
                onGroupDragStarted: (groupId, px, py) => root.beginGroupDrag(groupId, px, py)
                onGroupDragMoved: (groupId, px, py) => root.updateGroupDrop(px, py)
                onGroupDragFinished: (groupId, px, py) => root.finishGroupDrag(groupId, px, py)
                onGroupDragCanceled: (groupId) => root.cancelDrag()
            }
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
            contentOffsetX: root.contentOffsetX
            // Stays visible while it shrinks away into the capital view.
            visible: root.view === "apps" && root.capitalScaleProgress < 1
                     && root.menuMode !== "windowed"
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
            pointerBlocked: root.pointerOverContextMenu
            hoverBlocked: root.contextMenuOpen
            forcedEntry: root.contextMenuEntry
            onEntryContextRequested: (entry, sx, sy) => root.openEntryContextMenu(entry, sx, sy)
        }

        CapitalView {
            anchors.fill: parent
            contentOffsetX: root.contentOffsetX
            z: 1
            // Visible from the first frame of the transition until it is gone.
            visible: root.capitalScaleProgress > 0.001
                     && root.menuMode !== "windowed"
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
            visible: root.menuMode !== "windowed"
            menuWidth: root.width
            accentColor: root.accentColor
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

        // Right-click menu. Clicking anywhere else in the menu closes it, as
        // does Escape (see main.qml); there is no close animation.
        ContextMenu {
            id: contextMenu
            objectName: "contextMenu"
            z: 50
            visible: root.contextMenuOpen
            open: root.contextMenuOpen
            model: root.contextMenuModel
            accentColor: root.accentColor
            anchorX: root.contextMenuX
            anchorY: root.contextMenuY
            growUp: root.contextMenuGrowUp
            growLeft: root.contextMenuGrowLeft
            boundsWidth: root.width
            boundsHeight: root.debugContextBoundsHeight >= 0
                          ? root.debugContextBoundsHeight : root.height
            debugPointerActive: root.debugContextPointerActive
            debugPointerX: root.debugContextPointerX
            debugPointerY: root.debugContextPointerY
            debugHoverRow: root.debugContextHoverRow
            debugOpenRow: root.debugContextOpenRow
            debugOpenProgress: root.debugContextProgress
            debugSubmenuProgress: root.debugContextSubmenuProgress
            onActivated: (row) => root.contextMenuAction(row)
        }

        // A press anywhere outside the rename field ends the edit at once: it
        // takes the focus away from the field, which commits it (see the
        // TextInput in TilesView).
        MouseArea {
            objectName: "renameCatcher"
            z: 44
            anchors.fill: parent
            visible: root.renaming
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            onPressed: (mouse) => {
                if (root.renameHit(mouse.x, mouse.y)) {
                    mouse.accepted = false
                    return
                }
                forceActiveFocus()
            }
        }

        MouseArea {
            z: 40
            anchors.fill: parent
            visible: root.contextMenuOpen
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            // Close on the press: the release then belongs to whatever is under
            // the pointer (a tile click still activates it, a right click opens
            // that tile's own menu).
            onPressedChanged: if (pressed) root.closeContextMenu()
        }

        Flyout {
            kind: root.flyout
            // In the windowed Start the flyout opens above its own button.
            anchorY: root.menuMode === "windowed"
                     // Open above the button, not over it: the row's top edge
                     // minus the same 6 px gap the fullscreen menu uses.
                     ? (kind === "power" ? root.compactPanelTop + root.compactPanelHeightFit - 78
                                         : root.compactPanelTop + root.compactPanelHeightFit - 150)
                     : (kind === "power" ? root.height - 78 : root.height - 150)
            userName: root.userNameData || ""
            avatar: root.avatarData || ""
            onPowerAction: (action) => {
                if (root.runtimeActive)
                    runtime.powerAction(action)
                root.closeRequested()
            }
        }
    }
}
