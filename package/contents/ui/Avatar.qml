// Circular avatar with a graceful fallback when the account has no photo.
//
// The circle is cut by a fragment shader (assets/ui/circle.frag.qsb) instead of
// a mask texture: a mask is applied as a 1-bit compare by the scene graph, so
// the rim came out jagged at 30 px. The shader measures the distance to the
// centre per pixel and feathers the last pixel, which stays smooth at any size.
import QtQuick
import QtQuick.Window

Item {
    id: root
    property url source: ""
    property int size: 30

    width: size
    height: size

    Image {
        id: photo
        anchors.fill: parent
        source: root.source
        visible: false
        smooth: true
        fillMode: Image.PreserveAspectCrop
    }

    ShaderEffectSource {
        id: photoTexture
        sourceItem: photo
        hideSource: true
        live: true
    }

    ShaderEffect {
        anchors.fill: parent
        visible: root.source != ""
        fragmentShader: Qt.resolvedUrl("../assets/ui/circle.frag.qsb")
        property variant source: photoTexture
        // `diameter` is in device pixels so the 1 px feather stays 1 px.
        property real diameter: root.width * Screen.devicePixelRatio
        property real feather: 1.0
    }

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: "#F2F2F2"
        visible: root.source == ""
    }
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.22
        width: parent.width * 0.30
        height: width
        radius: width / 2
        color: "#8A8A8A"
        visible: root.source == ""
    }
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.56
        width: parent.width * 0.56
        height: parent.height * 0.32
        radius: width / 2
        color: "#8A8A8A"
        visible: root.source == ""
    }
}
