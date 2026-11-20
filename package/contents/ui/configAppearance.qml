// Applet settings: pick the accent colour. On Windows the tile menu takes the
// system accent colour; here it is a free choice, defaulting to the colour the
// reference capture used (#4A78A4).
import QtQuick
import QtQuick.Controls
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.kquickcontrols as KQuickControls
import "metrics.js" as Metrics

KCM.SimpleKCM {
    id: page

    property alias cfg_accentColor: accentButton.color
    property alias cfg_compactMode: compactCheck.checked

    Kirigami.FormLayout {
        KQuickControls.ColorButton {
            id: accentButton
            Kirigami.FormData.label: "强调色"
            dialogTitle: "选择强调色"
            showAlphaChannel: false
            color: Metrics.accentColorDefault
        }

        Button {
            text: "恢复默认（" + Metrics.accentColorDefault + "）"
            onClicked: accentButton.color = Metrics.accentColorDefault
        }

        CheckBox {
            id: compactCheck
            Kirigami.FormData.label: "开始菜单布局"
            text: "非全屏（窗口式）开始菜单"
            checked: false
        }
    }
}
