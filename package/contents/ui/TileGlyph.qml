// Glyph of a tile in the "early Windows" skin.
//
// Windows tiles show a white monochrome logo on a coloured background. KDE
// applications ship coloured icons, so this component offers three modes
// (plans/EARLY-STYLE-INTEGRATION.md §3):
//
//   mono   (default) - white silhouette: the symbolic variant when the theme
//                      has one (Kirigami falls back to the plain icon), colorised
//                      to white otherwise - the same MultiEffect trick the
//                      sidebar buttons already use
//   letter           - first letter of the app name (Square Home's generated
//                      themed icon for apps without a mono icon)
//   color            - the application's own coloured icon
//
// Only one of the four branches below is ever built. Each of them used to be
// instantiated for every tile and merely hidden, which cost four icon items
// and an off-screen MultiEffect pass per tile even though a tile only ever
// shows one of them.
import QtQuick
import QtQuick.Effects
import org.kde.kirigami as Kirigami

Item {
    id: root

    property string iconSource: ""     // theme name or absolute path
    property string label: ""          // app name, used by the letter fallback
    property string mode: "mono"       // mono | letter | color
    property color tint: "#FFFFFF"
    property int size: 60

    width: size
    height: size

    readonly property bool isFile: iconSource.indexOf("/") === 0
                                   || iconSource.indexOf("file:") === 0
                                   || iconSource.indexOf("image:") === 0
    readonly property bool mono: mode === "mono" && iconSource !== ""
    readonly property bool letter: mode === "letter"
                                  || (mode === "mono" && iconSource === "")
    readonly property bool colour: mode === "color" && iconSource !== ""
    // Kirigami.Icon falls back to the regular icon when "-symbolic" is missing,
    // so asking for it is safe and gives the mono variant when it exists.
    readonly property string symbolicName: isFile || iconSource === ""
                                           ? "" : iconSource + "-symbolic"

    // ---- mono: white silhouette ---------------------------------------
    // Both sources stay hidden (the sidebar's pattern): MultiEffect captures
    // them itself.
    Loader {
        anchors.fill: parent
        active: root.mono
        sourceComponent: Item {
            Image {
                id: monoFileIcon
                anchors.fill: parent
                visible: false
                source: root.isFile ? root.iconSource : ""
                fillMode: Image.PreserveAspectFit
                smooth: true
            }
            Kirigami.Icon {
                id: monoThemeIcon
                anchors.fill: parent
                visible: false
                source: root.isFile ? "" : root.symbolicName
                smooth: true
                // Draw at the glyph's own size: Kirigami would otherwise snap it
                // down to a size the theme ships (see AppIcon.qml).
                roundToIconSize: false
            }
            MultiEffect {
                anchors.fill: parent
                source: root.isFile ? monoFileIcon : monoThemeIcon
                colorization: 1.0
                colorizationColor: root.tint
                blurEnabled: false
                shadowEnabled: false
                // no extra FBO margin and no padding pass: cheaper per-tile effect
                autoPaddingEnabled: false
            }
        }
    }

    // ---- colour: the application's own icon ---------------------------
    Loader {
        anchors.fill: parent
        active: root.colour && !root.isFile
        sourceComponent: Kirigami.Icon {
            source: root.iconSource
            smooth: true
            roundToIconSize: false
        }
    }
    Loader {
        anchors.fill: parent
        active: root.colour && root.isFile
        sourceComponent: Image {
            source: root.iconSource
            fillMode: Image.PreserveAspectFit
            smooth: true
        }
    }

    // ---- letter fallback ----------------------------------------------
    Loader {
        anchors.fill: parent
        active: root.letter
        sourceComponent: Item {
            Rectangle {
                anchors.centerIn: parent
                width: Math.round(root.size * 0.62)
                height: width
                radius: width / 2
                color: "transparent"
                border.color: root.tint
                border.width: Math.max(1, Math.round(root.size / 30))
                opacity: 0.35
            }
            Text {
                anchors.centerIn: parent
                text: root.label !== "" ? root.label.charAt(0).toUpperCase() : "?"
                color: root.tint
                font.pixelSize: Math.round(root.size * 0.46)
                font.bold: true
            }
        }
    }
}
