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
    Image {
        id: monoFileIcon
        anchors.fill: parent
        visible: false
        source: root.mono && root.isFile ? root.iconSource : ""
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
    }
    Kirigami.Icon {
        id: monoThemeIcon
        anchors.fill: parent
        visible: false
        source: root.mono && !root.isFile ? root.symbolicName : ""
        smooth: true
    }
    MultiEffect {
        anchors.fill: parent
        visible: root.mono
        source: root.isFile ? monoFileIcon : monoThemeIcon
        colorization: 1.0
        colorizationColor: root.tint
        blurEnabled: false
        shadowEnabled: false
    }

    // ---- colour: the application's own icon ---------------------------
    Kirigami.Icon {
        anchors.fill: parent
        visible: root.colour && !root.isFile
        source: root.colour && !root.isFile ? root.iconSource : ""
        smooth: true
    }
    Image {
        anchors.fill: parent
        visible: root.colour && root.isFile
        source: root.colour && root.isFile ? root.iconSource : ""
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
    }

    // ---- letter fallback ----------------------------------------------
    Item {
        anchors.fill: parent
        visible: root.letter

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
