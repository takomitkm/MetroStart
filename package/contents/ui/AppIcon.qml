// Renders an application or menu icon from either a theme name or a file path.
import QtQuick
import org.kde.kirigami as Kirigami

Item {
    id: root
    property string source: ""
    property int size: 48

    width: size
    height: size

    readonly property bool isFile: source.indexOf("/") === 0
                                    || source.indexOf("file:") === 0
                                    || source.indexOf("image:") === 0

    Image {
        anchors.fill: parent
        visible: root.source !== "" && root.isFile
        source: root.isFile ? root.source : ""
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
    }

    Kirigami.Icon {
        anchors.fill: parent
        visible: root.source !== "" && !root.isFile
        source: root.isFile ? "" : root.source
        smooth: true
        // Kirigami snaps the requested size down to an icon size the theme
        // actually ships (48 and 60 both became 32 px here), which made a tile
        // icon smaller than the size the design asks for. Draw at the given
        // size instead; the theme's closest bitmap is still scaled to it.
        roundToIconSize: false
    }
}
