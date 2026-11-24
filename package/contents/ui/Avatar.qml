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

    // The photo path only exists while there is a photo, and the texture is
    // captured on demand instead of being `live`: an avatar does not animate,
    // and a live ShaderEffectSource re-renders its source item and re-uploads
    // the texture every frame the scene graph draws. That cost was paid by
    // every avatar in the menu (sidebar and flyouts) for a picture that never
    // changes.
    Loader {
        anchors.fill: parent
        active: root.source != ""
        sourceComponent: Item {
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
                // Not `live`: an avatar does not animate, and a live source
                // re-renders its item and re-uploads the texture on every
                // frame. The capture is taken once the picture is decodable.
                live: false
            }

            // A cached image can already be Ready when this component is
            // created, in which case no status change is ever emitted, so the
            // capture is also requested on completion. Without it the texture
            // would stay empty for a picture that never reloads.
            function captureIfReady() {
                if (photo.status === Image.Ready)
                    photoTexture.scheduleUpdate()
            }
            Component.onCompleted: captureIfReady()
            Connections {
                target: photo
                function onStatusChanged() { if (photo.status === Image.Ready) photoTexture.scheduleUpdate() }
            }

            ShaderEffect {
                anchors.fill: parent
                fragmentShader: Qt.resolvedUrl("../assets/ui/circle.frag.qsb")
                property variant source: photoTexture
                // `diameter` is in device pixels so the 1 px feather stays 1 px.
                property real diameter: root.width * Screen.devicePixelRatio
                property real feather: 1.0
            }
        }
    }

    // Fallback drawn only when the account has no photo.
    Loader {
        anchors.fill: parent
        active: root.source == ""
        sourceComponent: Item {
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: "#F2F2F2"
            }
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height * 0.22
                width: parent.width * 0.30
                height: width
                radius: width / 2
                color: "#8A8A8A"
            }
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height * 0.56
                width: parent.width * 0.56
                height: parent.height * 0.32
                radius: width / 2
                color: "#8A8A8A"
            }
        }
    }
}
