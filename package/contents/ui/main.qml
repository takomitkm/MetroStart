// Plasma applet entry point. The panel button opens a full-screen overlay
// window (layer-shell) so the menu has no dialog padding and can cover the
// whole work area.
import QtQuick
import QtQuick.Window
import org.kde.plasma.plasmoid
import org.kde.layershell as LayerShell
import "motion.js" as Motion
import "metrics.js" as Metrics

PlasmoidItem {
    id: root

    // Native SystemAccentColor drives the pressed group title, the group drag
    // placeholder and the sidebar marker. Defaults to the reference colour.
    readonly property color accentColor: Plasmoid.configuration.accentColor
    // Fullscreen (the classic Start) or the windowed, non-fullscreen layout.
    readonly property bool compactMode: Plasmoid.configuration.compactMode === true
    readonly property string tileSkin: Plasmoid.configuration.tileSkin || "modern"
    readonly property string tilePalette: Plasmoid.configuration.tilePalette || "default"
    readonly property bool forceAppColor: Plasmoid.configuration.forceAppColor !== false
    readonly property string themedIcon: Plasmoid.configuration.themedIcon || "auto"
    // How much of an icon theme's bitmap is artwork rather than padding
    // (percent). Tile icons are drawn in a box enlarged by it, so the visible
    // icon keeps its design size across themes that pad differently.
    readonly property real iconFillRatio: Math.max(40, Math.min(100,
        Plasmoid.configuration.iconFillPercent || Math.round(100 * Metrics.iconFillRatio))) / 100
    readonly property bool liveTilesEnabled: Plasmoid.configuration.liveTilesEnabled === true
    readonly property string weatherSource: Plasmoid.configuration.weatherSource || ""
    readonly property bool liveTileCycle: Plasmoid.configuration.liveTileCycle !== false
    readonly property string liveTileVariant: Plasmoid.configuration.liveTileVariant || "auto"
    readonly property bool pulseOnUpdate: Plasmoid.configuration.pulseOnUpdate === true
    readonly property bool moreLiveAni: Plasmoid.configuration.moreLiveAni !== false
    readonly property int compactColumnsSetting: Math.max(1, Math.min(4,
        Plasmoid.configuration.compactColumns || 3))
    readonly property int compactHeightSetting: Math.max(690, Math.min(1320,
        Plasmoid.configuration.compactHeight || 1124))

    // Work area of the screen the panel is on, in device-independent pixels:
    // the menu stops above the panel wherever the panel sits. Plasma reports
    // both rects already in logical pixels, the same pixels Qt Quick uses.
    readonly property rect workRect: {
        const r = root.availableScreenRect
        if (r && r.width > 0 && r.height > 0)
            return r
        return Qt.rect(0, 0, Screen.width > 0 ? Screen.width : 2560,
                       Screen.height > 0 ? Screen.height : 1440)
    }
    readonly property rect screenRect: {
        const r = root.screenGeometry
        if (r && r.width > 0 && r.height > 0)
            return r
        return Qt.rect(0, 0, Screen.width > 0 ? Screen.width : 2560,
                       Screen.height > 0 ? Screen.height : 1440)
    }
    // Insets of the work area inside the screen (i.e. the panel's thickness on
    // each side), used to place the layer-shell surface on the work area.
    readonly property int insetLeft: Math.round(workRect.x)
    readonly property int insetTop: Math.round(workRect.y)
    readonly property int insetRight: Math.round(screenRect.width - workRect.x - workRect.width)
    readonly property int insetBottom: Math.round(screenRect.height - workRect.y - workRect.height)
    // Design pixels per device-independent pixel: the design was measured at
    // 150% scaling, so 1.5 design px make one logical px. The whole menu is
    // laid out in design pixels (see metrics.js) and Qt scales it with the
    // window's device pixel ratio, which keeps its size relative to the rest
    // of the UI the same at every display scale.
    readonly property real designScale: 1.0 / Metrics.referenceDpr
    // The overlay canvas is the work area in design pixels: it fills the
    // screen at every scale and the screen size only decides how much of it is
    // there (and how many tile columns fit).
    readonly property real canvasWidth: workRect.width / designScale
    readonly property real canvasHeight: workRect.height / designScale
    // Design rect of the desktop wallpaper: the canvas starts at the work
    // area, the wallpaper stays aligned 1:1 with the screen behind it.
    readonly property rect wallpaperRect: Qt.rect(-workRect.x / designScale,
                                                  -workRect.y / designScale,
                                                  screenRect.width / designScale,
                                                  screenRect.height / designScale)

    implicitWidth: 32
    implicitHeight: 32
    activationTogglesExpanded: false

    // Plasma needs a full representation to instantiate the compact one in the
    // panel; the menu itself is the overlay window below.
    fullRepresentation: Item {
        implicitWidth: 32
        implicitHeight: 32
    }

    // The menu fades in place: the reference recording shows no slide or
    // scale, only a ~250 ms cross-fade of the whole surface.
    function openMenu() {
        if (overlay.visible && overlay.contentOpacity >= 1)
            return
        // Always the same starting point: pinned tiles, list at the top, no
        // flyout (the menu item tree survives between openings).
        menu.reset()
        overlay.backdropOpacity = 0
        overlay.contentOpacity = 0
        overlay.tileEntrance = 0
        overlay.compactOpenLinear = 0
        // The tiles scale per row (see TilesView); the layer scale is only
        // used to pull the background/sidebar in while closing.
        overlay.visible = true
        overlay.requestActivate()
        openBackdrop.restart()
        if (root.compactMode) {
            // The windowed Start shows its content at full opacity from the
            // first frame (only the backdrop fades), so the row push is what
            // the eye sees; fading the content would hide it.
            overlay.contentOpacity = 1
            openCompact.restart()
        } else {
            contentStartTimer.restart()
            tileStartTimer.restart()
        }
    }

    function closeMenu() {
        if (!overlay.visible)
            return
        // Closing mirrors the open: everything fades out while the content
        // scales back down towards the screen centre, tiles leaving from the
        // top rows downwards.
        if (root.compactMode) {
            compactClose.restart()
            return
        }
        closeStartTimer.restart()
    }

    // The content follows the backdrop; see Motion.contentFadeDelay.
    Timer {
        id: contentStartTimer
        interval: Motion.contentFadeDelay
        onTriggered: openContent.restart()
    }

    Timer {
        id: tileStartTimer
        interval: Motion.tileEntranceDelay
        onTriggered: openTiles.restart()
    }

    NumberAnimation {
        id: openBackdrop
        target: overlay
        property: "backdropOpacity"
        to: 1
        duration: Motion.fadeOpenDuration
        easing.type: Easing.Linear
    }

    NumberAnimation {
        id: openContent
        target: overlay
        property: "contentOpacity"
        to: 1
        duration: Motion.contentFadeDuration
        easing.type: Easing.Linear
    }

    NumberAnimation {
        id: openTiles
        target: overlay
        property: "tileEntrance"
        to: 1
        duration: Motion.tileEntranceDuration
        easing.type: Easing.Linear
    }

    NumberAnimation {
        id: compactClose
        target: overlay
        property: "contentOpacity"
        to: 0
        duration: Motion.compactCloseDuration
        easing.type: Easing.Linear
        onFinished: overlay.visible = false
    }

    NumberAnimation {
        id: openCompact
        target: overlay
        property: "compactOpenLinear"
        to: 1
        duration: Motion.compactOpenDuration
        easing.type: Easing.Linear
    }

    NumberAnimation {
        id: closeContent
        target: overlay
        property: "contentOpacity"
        to: 0
        duration: Motion.fadeCloseDuration
        easing.type: Easing.Linear
    }

    NumberAnimation {
        id: closeTiles
        target: overlay
        property: "tileEntrance"
        to: 0
        duration: Motion.fadeCloseDuration
        easing.type: Easing.Linear
    }

    // The recording shows the close waiting a moment before it starts moving.
    Timer {
        id: closeStartTimer
        interval: Motion.closeDelay
        onTriggered: {
            closeAnimation.restart()
            closeContent.restart()
            closeTiles.restart()
        }
    }

    NumberAnimation {
        id: closeAnimation
        target: overlay
        property: "contentOpacity"
        to: 0
        duration: Motion.fadeCloseDuration
        easing.type: Easing.Linear
        onFinished: overlay.visible = false
    }

    onExpandedChanged: {
        if (expanded) {
            openMenu()
            expanded = false
        }
    }

    compactRepresentation: Item {
        implicitWidth: 32
        implicitHeight: 32
        width: 32
        height: 32

        Rectangle {
            anchors.fill: parent
            radius: 3
            color: mouse.containsMouse ? "#30FFFFFF" : "transparent"
        }

        Image {
            anchors.centerIn: parent
            width: 22
            height: 22
            source: Qt.resolvedUrl("../assets/ui/grid.png")
            smooth: true
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: overlay.visible ? closeMenu() : openMenu()
        }
    }

    // Full-screen layer-shell surface, exactly as before; the open/close
    // transition is drawn inside it (the menu item is faded), so the window is
    // mapped once at its final geometry and never resized or transformed.
    Window {
        id: overlay
        objectName: "metroOverlay"
        visible: false
        flags: Qt.FramelessWindowHint
        color: "transparent"
        title: "MetroStart"

        // The window covers the work area: the layer-shell margins are the
        // panel's thickness, so the menu never overlaps the panel whatever
        // edge it is on. Both sizes are in logical pixels, which is what the
        // compositor expects.
        width: Math.max(1, Math.round(root.workRect.width))
        height: Math.max(1, Math.round(root.workRect.height))
        x: 0
        y: 0

        // Panel level, not overlay: panel context menus and other overlay-layer
        // surfaces are allowed to stay above the Start menu.
        LayerShell.Window.layer: LayerShell.Window.LayerTop
        LayerShell.Window.anchors: LayerShell.Window.AnchorTop
                                    | LayerShell.Window.AnchorLeft
                                    | LayerShell.Window.AnchorRight
                                    | LayerShell.Window.AnchorBottom
        LayerShell.Window.margins: ({ left: root.insetLeft, top: root.insetTop,
                                     right: root.insetRight,
                                     bottom: root.insetBottom })
        LayerShell.Window.exclusionZone: -1
        LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityOnDemand
        LayerShell.Window.activateOnShow: true
        LayerShell.Window.scope: "metrostart"

        // Set once the window has been mapped and activated; only then does
        // losing focus close the menu.
        property bool armed: false
        // 0 = menu fully transparent, 1 = fully drawn. The wallpaper+backdrop
        // arrive first; the content follows and also scales up.
        property real backdropOpacity: 0
        property real contentOpacity: 0
        // The reference also scales the whole menu up slightly while fading in.
        property real tileEntrance: 1
        // Linear 0..1 driver of the windowed menu's scale-in.
        property real compactOpenLinear: 1

        // Sidebar / list layer: only scales on close (they do not move on open).


        MetroMenu {
            id: menu
            // Dragging the windowed panel's edges is persisted (the settings
            // dialog only flips the layout on/off).
            onCompactColumnsChanged: if (root.compactMode)
                                         Plasmoid.configuration.compactColumns = compactColumns
            onCompactPanelHeightChanged: if (root.compactMode)
                                             Plasmoid.configuration.compactHeight = Math.round(compactPanelHeight)
            tileSkin: root.tileSkin
            tilePalette: root.tilePalette
            forceAppColor: root.forceAppColor
            themedIcon: root.themedIcon
            iconFillRatio: root.iconFillRatio
            liveTilesEnabled: root.liveTilesEnabled
            liveTileCycle: root.liveTileCycle
            pulseOnUpdate: root.pulseOnUpdate
            liveTileVariant: root.liveTileVariant
            moreLiveAni: root.moreLiveAni
            menuMode: root.compactMode ? "windowed" : "fullscreen"
            compactColumns: root.compactColumnsSetting
            compactPanelHeight: root.compactHeightSetting
            accentColor: root.accentColor
            // The canvas is the work area in design pixels; one design pixel
            // is designScale logical pixels (see metrics.js), and Qt scales
            // that by the display's device pixel ratio.
            width: root.canvasWidth
            height: root.canvasHeight
            uiScale: root.designScale
            wallpaperRect: root.wallpaperRect
            backdropOpacity: overlay.backdropOpacity
            contentOpacity: overlay.contentOpacity
            // The whole menu is only scaled for the design-space fit; the
            // entrance animation lives inside the menu (tiles only).
            tileEntrance: overlay.tileEntrance
            compactOpenLinear: overlay.compactOpenLinear
            onCloseRequested: root.closeMenu()
        }

        Shortcut {
            sequence: "Escape"
            enabled: overlay.visible
            // A drag in progress is cancelled first; Escape then closes the menu.
            onActivated: menu.contextMenuOpen ? menu.closeContextMenu()
                         : ((menu.dragTileId !== "" || menu.dragGroupId !== "")
                            ? menu.cancelDrag() : root.closeMenu())
        }

        // Grace period: the window reports a transient loss of activation
        // while it is being mapped, which must not close the menu.
        Timer {
            id: armTimer
            interval: 250
            onTriggered: overlay.armed = true
        }

        onActiveChanged: {
            if (!active && armed && contentOpacity > 0)
                root.closeMenu()
        }
        onVisibleChanged: {
            if (visible) {
                armed = false
                armTimer.restart()
                menu.reloadWallpaper()
                requestActivate()
            } else {
                armTimer.stop()
                armed = false
                // Put the menu back to its default state while it is off screen,
                // so the reset's animations are never visible.
                menu.reset()
            }
        }
    }
}
