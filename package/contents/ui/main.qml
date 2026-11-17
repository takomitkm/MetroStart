// Plasma applet entry point. The panel button opens a full-screen overlay
// window (layer-shell) so the menu has no dialog padding and can cover the
// whole work area.
import QtQuick
import QtQuick.Window
import org.kde.plasma.plasmoid
import org.kde.layershell as LayerShell
import "motion.js" as Motion

PlasmoidItem {
    id: root

    // Native SystemAccentColor drives the pressed group title, the group drag
    // placeholder and the sidebar marker. Defaults to the reference colour.
    readonly property color accentColor: Plasmoid.configuration.accentColor

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
        // The tiles scale per row (see TilesView); the layer scale is only
        // used to pull the background/sidebar in while closing.
        overlay.visible = true
        overlay.requestActivate()
        openBackdrop.restart()
        contentStartTimer.restart()
        tileStartTimer.restart()
    }

    function closeMenu() {
        if (!overlay.visible)
            return
        // Closing mirrors the open: everything fades out while the content
        // scales back down towards the screen centre, tiles leaving from the
        // top rows downwards.
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

        readonly property int screenWidth: Screen.width > 0 ? Screen.width : 2560
        readonly property int screenHeight: Screen.height > 0 ? Screen.height : 1440
        // The reference layout assumes a 60 px taskbar at 2560 px wide.
        // Screen reports logical pixels, so scale the panel with the menu.
        readonly property int panelHeight: Math.round(60 * screenWidth / 2560)

        width: screenWidth
        height: Math.max(1, screenHeight - panelHeight)
        x: 0
        y: 0

        // Panel level, not overlay: panel context menus and other overlay-layer
        // surfaces are allowed to stay above the Start menu.
        LayerShell.Window.layer: LayerShell.Window.LayerTop
        LayerShell.Window.anchors: LayerShell.Window.AnchorTop
                                    | LayerShell.Window.AnchorLeft
                                    | LayerShell.Window.AnchorRight
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

        // Sidebar / list layer: only scales on close (they do not move on open).


        MetroMenu {
            id: menu
            accentColor: root.accentColor
            width: 2560
            height: 1380
            backdropOpacity: overlay.backdropOpacity
            contentOpacity: overlay.contentOpacity
            // The whole menu is only scaled for the design-space fit; the
            // entrance animation lives inside the menu (tiles only).
            tileEntrance: overlay.tileEntrance
            transform: Scale {
                xScale: overlay.width / 2560
                yScale: overlay.height / 1380
            }
            onCloseRequested: root.closeMenu()
        }

        Shortcut {
            sequence: "Escape"
            enabled: overlay.visible
            // A drag in progress is cancelled first; Escape then closes the menu.
            onActivated: (menu.dragTileId !== "" || menu.dragGroupId !== "")
                         ? menu.cancelDrag() : root.closeMenu()
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
