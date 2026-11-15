// MetroStart menu surface: backdrop, tiles or app list, sidebar and flyouts.
import QtQuick
import "metrics.js" as Metrics
import "Layout.js" as Layout

Item {
    id: root

    // Injected by the preview harness; when null the applet uses its own data.
    property var context: null

    property string view: "tiles"          // "tiles" | "apps"
    property bool sidebarExpanded: false
    property bool sidebarBottomLabels: false
    property bool sidebarHover: false
    property bool bottomSeparators: false
    property bool groupTitles: false
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
    property real entranceOpacityFloorSlope: 0.3
    property real entranceStagger: 0.3
    property string entranceOrigin: "vertical"
    property real debugTileScale: -1
    property real debugTileOpacity: -1
    property real debugTileRise: -1
    property string capitalHovered: ""
    readonly property bool expandedSidebar: sidebarExpanded
    signal closeRequested()

    function reloadWallpaper() {
        if (runtimeActive)
            runtime.loadWallpaper()
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

    readonly property var layout: Layout.resolve(configData, appsData || [], { width: width, height: height })
    readonly property var sections: (appLayoutData && appLayoutData.sections)
                                     ? appLayoutData.sections
                                     : Layout.appSections(appsData || [])

    property bool runtimeActive: context === null

    Runtime {
        id: runtime
        visible: false
    }

    clip: true

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
        anchors.fill: parent
        TilesView {
            anchors.fill: parent
            visible: root.view === "tiles"
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
            debugHoverTile: root.debugHoverTile
            hoverInjected: root.debugPointerActive
            onTileActivated: (entry) => {
                root.launchEntry(entry)
                root.closeRequested()
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
            visible: root.view === "apps" && !root.capitalView
            sections: root.sections
            pointerX: root.effectivePointerX
            pointerY: root.effectivePointerY
            pointerInside: root.effectivePointerInside
            hoverInjected: root.debugPointerActive
            debugHoverControl: root.debugHoverControl
            scrollY: root.debugScrollY
            onLettersRequested: root.capitalView = true
            onEntryActivated: (entry) => {
                root.launchEntry(entry)
                root.closeRequested()
            }
        }

        CapitalView {
            anchors.fill: parent
            z: 1
            visible: root.capitalView
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
                    root.sidebarExpanded = !root.sidebarExpanded
                else
                    root.view = id
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
