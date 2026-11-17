// Windows 10 style start sidebar: hamburger, two sections, user and power.
import QtQuick
import QtQuick.Effects
import "metrics.js" as Metrics

Item {
    id: root
    property bool expanded: false
    property bool bottomLabels: false
    property bool hovered: false
    property bool separators: false
    property string selected: "tiles"
    property string wallpaperUrl: ""
    property real pointerX: -1
    property real pointerY: -1
    property bool pointerInside: false
    property string debugHoverControl: ""
    property bool hoverInjected: false
    property string userName: ""
    property string avatar: ""
    property var ui: null
    property real blurFactor: 48
    // Item the acrylic samples: the menu content behind the panel.
    property var blurSourceItem: null
    property real panelX: 0
    property real blurDownscale: 10
    property real menuWidth: 2560
    property color accentColor: Metrics.accentColorDefault
    // Light shade of the accent (native "accent light"): same hue, half the
    // saturation, full value. Used by the selected sidebar glyph.
    readonly property color accentLight: Qt.hsva(accentColor.hsvHue,
                                                 accentColor.hsvSaturation / 2,
                                                 1.0, 1.0)
    property color panelColor: "#32363C"
    property real panelAlpha: 0.42
    property real blurMax: Metrics.sidebarBlurMax
    property real blurSaturation: Metrics.sidebarBlurSaturation
    property real blurBrightness: Metrics.sidebarBlurBrightness
    property real blurContrast: Metrics.sidebarBlurContrast
    property real noiseOpacity: Metrics.sidebarNoiseOpacity
    property real blurAmount: Metrics.sidebarBlurAmount
    // Geometry of every sidebar button. All buttons share the same hover look:
    // a fill, an interior glow and a border glow that only lights the part of
    // the outline close to the pointer.
    readonly property var buttons: [
        { id: "header", y: Metrics.sidebarHeaderTop, h: Metrics.sidebarHeaderHeight },
        { id: "tiles",  y: Metrics.sidebarItemsTop, h: Metrics.sidebarItemHeight },
        { id: "apps",   y: Metrics.sidebarItemsTop + Metrics.sidebarItemHeight, h: Metrics.sidebarItemHeight },
        { id: "user",   y: Metrics.sidebarUserY, h: Metrics.sidebarUserHeight },
        { id: "power",  y: Metrics.sidebarPowerY, h: Metrics.sidebarPowerHeight }
    ]
    property string hoveredControl: ""

    function isHovered(id) {
        if (debugHoverControl !== "")
            return debugHoverControl === id
        return hoveredControl === id
    }

    // Which button covers a point in menu coordinates, "" when the point lands
    // on the panel's blank space (the gaps between the buttons, the empty run
    // below "all applications"). Used by the auto-expand dwell: only a button
    // counts as a resting place.
    function buttonAt(x, y) {
        if (x < 0 || x > root.width || y < 0)
            return ""
        for (var i = 0; i < buttons.length; ++i) {
            const b = buttons[i]
            if (y >= b.y && y < b.y + b.h)
                return b.id
        }
        return ""
    }

    function enterControl(id) {
        if (!hoverInjected)
            hoveredControl = id
    }

    function leaveControl(id) {
        if (!hoverInjected && hoveredControl === id)
            hoveredControl = ""
    }

    // True when the pointer is close enough to a control for its border to
    // light up even without hovering it.
    function isNear(x, y, w, h) {
        if (!pointerInside)
            return false
        const dx = Math.max(x - pointerX, 0, pointerX - (x + w))
        const dy = Math.max(y - pointerY, 0, pointerY - (y + h))
        return Math.hypot(dx, dy) < nearRadius
    }

    signal sectionActivated(string id)
    signal powerActivated()
    signal userActivated()

    readonly property bool labelsVisible: expanded
    // 0 = collapsed, 1 = fully open. The width grows with it, which also acts
    // as the mask that reveals the labels (this item clips its children).
    property real openAmount: 0
    // Both durations live in metrics.js; falling back keeps a missing constant
    // from leaving the panel with an undefined duration (that logs an error and
    // makes the panel snap instead of sliding).
    readonly property int collapseDuration: Metrics.sidebarCloseDuration > 0
                                            ? Metrics.sidebarCloseDuration
                                            : Metrics.sidebarOpenDuration
    Behavior on openAmount {
        NumberAnimation { duration: root.expanded ? Metrics.sidebarOpenDuration
                                                  : root.collapseDuration
                          easing.type: Easing.OutQuint }
    }
    Connections {
        target: root
        function onExpandedChanged() { root.openAmount = root.expanded ? 1 : 0 }
    }
    // The panel background is drawn when expanded (or when the labels are).
    readonly property bool shadowVisible: expanded || bottomLabels
    readonly property bool userLabels: expanded || bottomLabels
    width: Metrics.sidebarCollapsedWidth
           + (Metrics.sidebarExpandedWidth - Metrics.sidebarCollapsedWidth) * openAmount
    height: parent ? parent.height : 1380
    clip: true

    Item {
        anchors.fill: parent
        visible: openAmount > 0.001 || bottomLabels
        opacity: openAmount
        // Acrylic: the menu content behind the panel, blurred, then tinted.
        // MultiEffect captures its source itself; the item spans the whole
        // menu and the sidebar's clip keeps only the part behind the panel.
        Item {
            width: root.menuWidth
            height: root.height
            visible: root.blurSourceItem !== null
            MultiEffect {
                anchors.fill: parent
                source: root.blurSourceItem
                blurEnabled: true
                blur: root.blurAmount
                blurMax: root.blurMax
                saturation: root.blurSaturation
                brightness: root.blurBrightness
                contrast: root.blurContrast
            }
        }
        Rectangle {
            anchors.fill: parent
            color: root.panelColor
            opacity: root.panelAlpha
        }
        // Windows' acrylic has a fine grain on top; without it the panel looks
        // too smooth compared with the reference.
        Image {
            anchors.fill: parent
            source: Qt.resolvedUrl("../assets/ui/noise.png")
            fillMode: Image.Tile
            smooth: false
            opacity: root.noiseOpacity
        }
    }

    Item {
        id: headerButton
        x: 0
        y: Metrics.sidebarHeaderTop
        width: root.width
        height: Metrics.sidebarHeaderHeight

        RevealRect {
            anchors.fill: parent
            pointerX: root.pointerX - headerButton.x
            pointerY: root.pointerY - headerButton.y
            pointerInside: root.pointerInside
            hovered: root.isHovered("header")
            hoverFillOpacity: 0.13
            glowRadius: 320
            glowStrength: 0.04
            hoverPeak: Metrics.sidebarBorderPeak
            nearPeak: Metrics.sidebarBorderPeak
            borderRadius: Metrics.sidebarBorderRadius
            borderWidth: Metrics.sidebarBorderWidth
            fillInset: Metrics.sidebarBorderWidth
        }

        Image {
            // Absolute y 33: the button itself now starts at 6.
            x: 26; y: 33 - Metrics.sidebarHeaderTop
            width: 24; height: 17
            source: Qt.resolvedUrl("../assets/ui/hamburger.png")
            smooth: true
        }
        BaseText {
            visible: root.labelsVisible
            x: 73
            baselineY: 50 - Metrics.sidebarHeaderTop
            text: "开始"
            family: Metrics.fontFamily
            pixelSize: Metrics.sidebarTitleSize
        }

        HoverHandler {
            enabled: !root.hoverInjected
            onHoveredChanged: hovered ? root.enterControl("header") : root.leaveControl("header")
        }
        TapHandler { onTapped: root.sectionActivated("toggle") }
    }

    Repeater {
        model: [
            { id: "tiles", label: "已固定的磁贴", icon: "grid" },
            { id: "apps", label: "所有应用", icon: "list" }
        ]
        delegate: Item {
            required property var modelData
            required property int index
            y: Metrics.sidebarItemsTop + index * Metrics.sidebarItemHeight
            width: root.width
            height: Metrics.sidebarItemHeight

            readonly property bool isSelected: root.selected === modelData.id
            // The reference glyphs ship as white PNG masks; the selected one is
            // tinted with the light shade of the accent (native accent light),
            // the other stays white.
            readonly property url glyphSource: Qt.resolvedUrl("../assets/ui/"
                    + (modelData.id === "apps" ? "list" : "grid-normal") + ".png")
            readonly property color glyphColor: isSelected ? root.accentLight : "#FFFFFF"

            Rectangle {
                visible: root.expanded && parent.isSelected && root.hovered
                anchors.fill: parent
                color: "#FFFFFF"
                opacity: 0.09
            }

            Rectangle {
                visible: parent.isSelected
                x: 0; y: 0
                width: Metrics.sidebarAccentWidth
                height: parent.height
                // native accent; the hover shade is the same colour, lighter
                color: (parent.isSelected && root.isHovered(modelData.id))
                       ? Qt.lighter(root.accentColor, 1.22) : root.accentColor
            }

            Image {
                id: glyphImage
                x: 27; y: 25
                width: 22; height: 22
                source: parent.glyphSource
                sourceSize: Qt.size(44, 44)
                smooth: true
                visible: false
            }

            MultiEffect {
                x: glyphImage.x; y: glyphImage.y
                width: glyphImage.width; height: glyphImage.height
                source: glyphImage
                colorization: 1.0
                colorizationColor: parent.glyphColor
            }

            RevealRect {
                anchors.fill: parent
                pointerX: root.pointerX
                pointerY: root.pointerY - parent.y
                pointerInside: root.pointerInside
                hovered: root.isHovered(modelData.id)
                hoverFillOpacity: 0.13
                glowRadius: 240
                glowStrength: 0.04
                hoverPeak: Metrics.sidebarBorderPeak
                nearPeak: Metrics.sidebarBorderPeak
                borderRadius: Metrics.sidebarBorderRadius
                borderWidth: Metrics.sidebarBorderWidth
                fillInset: Metrics.sidebarBorderWidth
            }

            BaseText {
                visible: root.labelsVisible
                x: 73
                baselineY: index === 0 ? 42.5 : 43.5
                text: modelData.label
                color: parent.isSelected ? Metrics.sidebarSelectedColor : "#FFFFFF"
                family: Metrics.fontFamily
                pixelSize: Metrics.sidebarItemSize
            }

            HoverHandler {
                enabled: !root.hoverInjected
                onHoveredChanged: hovered ? root.enterControl(modelData.id) : root.leaveControl(modelData.id)
            }
            TapHandler { onTapped: root.sectionActivated(modelData.id) }
        }
    }

    Rectangle {
        visible: root.separators
        x: 0; y: Metrics.sidebarUserY; width: root.width; height: 2
        color: "#434445"
    }

    Rectangle {
        visible: root.separators
        x: 0; y: Metrics.sidebarPowerY; width: root.width; height: 2
        color: "#3C3D3E"
    }

    Item {
        id: userButton
        x: 0
        y: Metrics.sidebarUserY
        width: root.width
        height: Metrics.sidebarUserHeight

        RevealRect {
            anchors.fill: parent
            pointerX: root.pointerX - userButton.x
            pointerY: root.pointerY - userButton.y
            pointerInside: root.pointerInside
            hovered: root.isHovered("user")
            hoverFillOpacity: 0.13
            glowRadius: 240
            glowStrength: 0.04
            hoverPeak: Metrics.sidebarBorderPeak
            nearPeak: Metrics.sidebarBorderPeak
            borderRadius: Metrics.sidebarBorderRadius
            borderWidth: Metrics.sidebarBorderWidth
            fillInset: Metrics.sidebarBorderWidth
        }

        Avatar {
            x: 23; y: 21
            size: 30
            source: root.avatar
        }

        BaseText {
            visible: root.userLabels && root.userName !== ""
            x: 74
            baselineY: 44
            text: root.userName
            family: Metrics.fontFamily
            pixelSize: 21
        }

        HoverHandler {
            enabled: !root.hoverInjected
            onHoveredChanged: hovered ? root.enterControl("user") : root.leaveControl("user")
        }
        TapHandler { onTapped: root.userActivated() }
    }

    Item {
        id: powerButton
        x: 0
        y: Metrics.sidebarPowerY
        width: root.width
        height: Metrics.sidebarPowerHeight

        RevealRect {
            anchors.fill: parent
            pointerX: root.pointerX - powerButton.x
            pointerY: root.pointerY - powerButton.y
            pointerInside: root.pointerInside
            hovered: root.isHovered("power")
            hoverFillOpacity: 0.13
            glowRadius: 240
            glowStrength: 0.04
            hoverPeak: Metrics.sidebarBorderPeak
            nearPeak: Metrics.sidebarBorderPeak
            borderRadius: Metrics.sidebarBorderRadius
            borderWidth: Metrics.sidebarBorderWidth
            fillInset: Metrics.sidebarBorderWidth
        }

        Image {
            // Absolute y 26 was fitted with the button at 1306; the button now
            // starts at 1308, so keep the glyph where it was.
            x: 26; y: 24
            width: 24; height: 24
            source: Qt.resolvedUrl("../assets/ui/power.png")
            smooth: true
        }

        BaseText {
            visible: root.userLabels
            x: 72
            baselineY: 43
            text: "电源"
            family: Metrics.fontFamily
            pixelSize: Metrics.sidebarItemSize
        }

        HoverHandler {
            enabled: !root.hoverInjected
            onHoveredChanged: hovered ? root.enterControl("power") : root.leaveControl("power")
        }
        TapHandler { onTapped: root.powerActivated() }
    }

}
