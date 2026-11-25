// Power and user flyouts anchored at the bottom left of the sidebar.
//
// They open upwards from their button, with the same motion as the context
// menu: the panel's bottom edge is the anchor and never moves, the panel grows
// upwards while its content slides with the moving top edge, so the first row
// shows up first and the rest follow from below. Closing has no animation.
//
// Rows share the context menu's hover: the same RevealRect (fill, pointer glow
// and 2 px frame) with the same fill margins.
import QtQuick
import "metrics.js" as Metrics
import "motion.js" as Motion

Item {
    id: root
    property string kind: ""            // "power" | "user"
    property string userName: ""
    property string avatar: ""
    signal powerAction(string action)

    readonly property bool isPower: kind === "power"
    readonly property bool open: kind !== ""
    visible: open
    width: 386
    height: parent ? parent.height : Metrics.canvasHeight

    // Geometry of the panel at full height, measured on the reference
    // screenshots: the power menu sits on the power button, the user menu on
    // the account button.
    readonly property real panelWidth: isPower ? 387 : 383
    readonly property real contentHeight: isPower ? 165 : 237
    // Bottom edge the flyout opens up from (the button it belongs to):
    // measured from the menu's bottom edge, which is the panel's edge.
    property real anchorY: (parent ? parent.height : Metrics.canvasHeight)
                           - (isPower ? 78 : 150)
    readonly property real rowPitch: Metrics.contextMenuRowPitch

    // Opening timeline: a linear 0..1 clock through the fitted curve.
    property real openTime: 0
    readonly property real progress: Motion.bezierValue(Metrics.contextMenuOpenCurve, openTime)
    readonly property real panelHeight: contentHeight * progress

    onOpenChanged: {
        if (open) {
            openTime = 0
            openAnim.restart()
        } else {
            openAnim.stop()
            openTime = 0
        }
    }
    NumberAnimation {
        id: openAnim
        target: root
        property: "openTime"
        from: 0
        to: 1
        duration: Metrics.contextMenuOpenDuration
        easing.type: Easing.Linear
    }

    Item {
        id: panel
        x: 0
        y: root.anchorY - root.panelHeight
        width: root.panelWidth
        height: root.panelHeight
        clip: true

        Rectangle {
            anchors.fill: parent
            color: Metrics.menuPanelColor
            border.width: Metrics.contextMenuBorder
            border.color: Metrics.contextMenuBorderColor
        }

        Item {
            id: content
            width: panel.width
            height: root.contentHeight
            // Glued to the moving (top) edge: the mirror of the context menu's
            // bottom-glued content.
            y: 0

            Repeater {
                // `action` is dispatched by MetroMenu.performPowerAction; every
                // row needs one, otherwise a click does nothing at all.
                model: root.isPower
                    ? [{ icon: "hibernate", label: "休眠", action: "hibernate" },
                       { icon: "shutdown", label: "关机", action: "poweroff" },
                       { icon: "restart", label: "重启", action: "reboot" }]
                    : [{ icon: "account", label: "更改帐户设置", action: "account" },
                       { icon: "lock", label: "锁定", action: "lock" },
                       { icon: "logout", label: "注销", action: "logout" }]
                delegate: Item {
                    id: row
                    required property var modelData
                    required property int index
                    // The rows sit below the panel's top padding, so the
                    // hover fill lines up with the icon and the label.
                    y: Metrics.flyoutRowTop + index * root.rowPitch
                    width: panel.width
                    height: root.rowPitch

                    property bool pressed: false

                    // Same hover as the context menu rows.
                    RevealRect {
                        id: reveal
                        x: Metrics.contextMenuFillLeft
                        y: Metrics.contextMenuFillY
                        width: parent.width - Metrics.contextMenuFillLeft
                               - Metrics.contextMenuFillRight
                        height: parent.height - 2 * Metrics.contextMenuFillY
                        pointerX: rowHover.point.position.x - x
                        pointerY: rowHover.point.position.y - y
                        pointerInside: rowHover.hovered
                        hovered: rowHover.hovered
                        hoverFillOpacity: 0.13
                        glowRadius: 220
                        glowStrength: 0.08
                        hoverPeak: Metrics.appBorderPeak
                        nearPeak: 0
                        borderRadius: Metrics.appBorderRadius
                        borderWidth: Metrics.appBorderWidth
                        pressed: row.pressed
                    }

                    HoverHandler {
                        id: rowHover
                    }

                    Image {
                        x: 23; y: 21 - Metrics.flyoutRowTop
                        width: 26; height: 26
                        source: Qt.resolvedUrl("../assets/ui/" + modelData.icon + ".png")
                        smooth: true
                    }
                    BaseText {
                        x: 66
                        baselineY: 39 - Metrics.flyoutRowTop
                        text: modelData.label
                        family: Metrics.fontFamily
                        pixelSize: 18
                        letterSpacing: hasCjk ? 1 : 0
                    }

                    TapHandler {
                        onPressedChanged: row.pressed = pressed
                        onCanceled: row.pressed = false
                        onTapped: if (modelData.action !== "")
                                      root.powerAction(modelData.action)
                    }
                }
            }

            Rectangle {
                visible: !root.isPower
                x: 22; y: 163
                width: 345; height: 2
                color: "#7A7A7B"
            }

            Avatar {
                visible: !root.isPower
                x: 23; y: 175
                size: 50
                source: root.avatar
            }

            BaseText {
                visible: !root.isPower && root.userName !== ""
                x: 84
                baselineY: 207
                text: root.userName
                family: Metrics.fontFamily
                pixelSize: 17
            }
        }
    }
}