// Windows 10 "capital view": the letter grid that replaces the application
// list when the letter column is clicked. Four columns of 90 px cells on a
// 96 px pitch, centred in the menu; letters without a matching section are
// dimmed and do nothing.
import QtQuick
import "metrics.js" as Metrics

Item {
    id: root
    property var letters: []            // section letters that exist
    property real pointerX: -1
    property real pointerY: -1
    property bool pointerInside: false
    property string hoveredKey: ""
    property bool hoverInjected: false
    property string debugHoverControl: ""
    // Horizontal shift of the grid (see AppListView.contentOffsetX) and the
    // cell origin below it, both so the grid stays centred on a canvas that
    // is wider or taller than the reference design.
    property real contentOffsetX: 0
    readonly property real originY: Math.round((height - Metrics.capitalRows
                                                * Metrics.capitalPitch) / 2)

    // "clock" jumps to the top, "globe" is the language entry (dimmed for now).
    readonly property var keys: {
        var list = ["clock", "&", "#"]
        for (var i = 0; i < 26; ++i)
            list.push(String.fromCharCode(65 + i))
        list.push("globe")
        return list
    }

    function enabled(key) {
        if (key === "clock")
            return true
        if (key === "globe")
            return false
        return letters.indexOf(key) >= 0
    }

    signal letterActivated(string key)
    signal dismissed()

    // Transparent catcher: a click outside the cells closes the view.
    MouseArea {
        anchors.fill: parent
        onClicked: root.dismissed()
    }

    Repeater {
        model: root.keys
        delegate: Item {
            required property var modelData
            required property int index

            readonly property string key: modelData
            readonly property int column: index % 4
            readonly property int row: Math.floor(index / 4)
            readonly property bool live: root.enabled(key)

            x: root.contentOffsetX + Metrics.capitalOriginX
               + column * Metrics.capitalPitch
            y: root.originY + row * Metrics.capitalPitch
            width: Metrics.capitalCell
            height: Metrics.capitalCell

            RevealRect {
                anchors.fill: parent
                pointerX: root.pointerX - parent.x
                pointerY: root.pointerY - parent.y
                pointerInside: root.pointerInside
                pointerDriven: true
                hovered: parent.live && root.debugHoverControl === "capital:" + parent.key
                hoverFillOpacity: 0.0
                glowRadius: 150
                glowStrength: 0.085
                hoverPeak: 0.22
                nearPeak: 0.10
                borderRadius: 150
                opacity: parent.live ? 1 : 0.45
            }

            BaseText {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: Metrics.capitalInkOffset
                text: parent.key === "clock" || parent.key === "globe" ? "" : parent.key
                color: "#FFFFFF"
                family: Metrics.fontFamily
                pixelSize: Metrics.capitalLetterSize
                opacity: parent.live ? 1 : 0.45
            }

            // One icon slot: letters have no source, so no stray images load.
            Image {
                readonly property bool isGlobe: parent.key === "globe"
                anchors.centerIn: parent
                width: Metrics.capitalIconSize
                height: Metrics.capitalIconSize
                visible: parent.key === "clock" || isGlobe
                source: parent.key === "clock" ? Qt.resolvedUrl("../assets/ui/clock.svg")
                      : (isGlobe ? Qt.resolvedUrl("../assets/ui/globe.svg") : "")
                smooth: true
            }

            TapHandler {
                enabled: parent.live
                onTapped: root.letterActivated(parent.key)
            }
        }
    }
}