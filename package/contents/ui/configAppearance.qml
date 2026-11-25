// Applet settings: pick the accent colour. On Windows the tile menu takes the
// system accent colour; here it is a free choice, defaulting to the colour the
// reference capture used (#4A78A4).
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.kquickcontrols as KQuickControls
import org.kde.iconthemes as KIconThemes
import "metrics.js" as Metrics

KCM.SimpleKCM {
    id: page

    // Palette ids, matching the JSON assets in TilePalettes.js.
    readonly property var iconValues: ["auto", "letter", "color"]
    readonly property var variantValues: ["auto", "slide", "flip"]
    readonly property var paletteValues: ["default", "vivid", "pastel", "dark",
        "transparent", "red", "pink", "purple", "indigo", "blue", "teal",
        "green", "lime", "yellow", "orange", "brown", "grey"]

    property alias cfg_accentColor: accentButton.color
    // Panel button icon: an icon theme name or a path; empty = the applet's own
    // "grid" glyph (see main.qml).
    property string cfg_icon: ""
    property alias cfg_compactMode: compactCheck.checked
    // Set by the menu when its edges are dragged; the page only exposes the
    // layout switch, but the properties must exist for the dialog.
    property int cfg_compactColumns: 3
    property int cfg_compactHeight: 1124
    // Everything except the accent colour, the menu layout and the icon fill
    // ratio is an experimental option. Off (the default) leaves all of them at
    // their defaults, and the page hides them.
    property bool cfg_experimentalEnabled: false
    readonly property bool experimentalOn: page.cfg_experimentalEnabled
    // Tile skin (see plans/EARLY-STYLE-INTEGRATION.md).
    property string cfg_tileSkin: "modern"
    property string cfg_tilePalette: "default"
    property bool cfg_forceAppColor: true
    property string cfg_themedIcon: "auto"
    // Percent of an icon theme's bitmap that is artwork rather than padding
    // (40..100). Stored as an int so the config file keeps a round number.
    property int cfg_iconFillPercent: 85
    property alias cfg_liveTilesEnabled: liveCheck.checked
    property alias cfg_liveTileCycle: cycleCheck.checked
    property alias cfg_moreLiveAni: moreAniCheck.checked
    property string cfg_weatherSource: ""
    property string cfg_liveTileVariant: "auto"
    property bool cfg_pulseOnUpdate: false

    // Turning the switch off resets the experimental options to their defaults,
    // so what is stored always matches what the applet actually renders.
    function resetExperimentalDefaults() {
        page.cfg_tileSkin = Metrics.defaultTileSkin
        page.cfg_tilePalette = Metrics.defaultTilePalette
        page.cfg_forceAppColor = Metrics.defaultForceAppColor
        page.cfg_themedIcon = Metrics.defaultThemedIcon
        page.cfg_weatherSource = Metrics.defaultWeatherSource
        page.cfg_liveTilesEnabled = Metrics.defaultLiveTilesEnabled
        page.cfg_liveTileCycle = Metrics.defaultLiveTileCycle
        page.cfg_moreLiveAni = Metrics.defaultMoreLiveAni
        page.cfg_liveTileVariant = Metrics.defaultLiveTileVariant
        page.cfg_pulseOnUpdate = Metrics.defaultPulseOnUpdate
    }

    KIconThemes.IconDialog {
        id: iconDialog
        onIconNameChanged: (name) => page.cfg_icon = name || ""
    }

    Kirigami.FormLayout {
        // The panel button icon, laid out like the Application Launcher's
        // settings: one large button showing the current icon; clicking it
        // opens the chooser, right next to the reset entry.
        RowLayout {
            Kirigami.FormData.label: "图标"
            spacing: Kirigami.Units.largeSpacing

            Button {
                id: iconButton
                Layout.minimumWidth: Kirigami.Units.iconSizes.large + Kirigami.Units.smallSpacing * 2
                Layout.maximumWidth: Layout.minimumWidth
                Layout.minimumHeight: Layout.minimumWidth
                Layout.maximumHeight: Layout.minimumWidth
                display: AbstractButton.IconOnly
                icon.width: Kirigami.Units.iconSizes.large
                icon.height: Kirigami.Units.iconSizes.large
                // A theme name picks the icon by name, an absolute path (set by
                // hand in the config file) is loaded as a file.
                icon.name: page.cfg_icon
                icon.source: page.cfg_icon === ""
                             ? Qt.resolvedUrl("../assets/ui/grid.png")
                             : (page.cfg_icon.indexOf("/") === 0 ? page.cfg_icon : "")
                checkable: true
                onClicked: {
                    // Keep the button pressed while the menu is up, the way the
                    // launcher's icon button does.
                    checked = Qt.binding(() => iconMenu.visible)
                    iconMenu.popup(iconButton)
                }
                ToolTip.visible: hovered
                ToolTip.text: page.cfg_icon === "" ? "默认（Windows 网格）" : page.cfg_icon
                ToolTip.delay: Kirigami.Units.toolTipDelay
            }

            Menu {
                id: iconMenu
                MenuItem {
                    text: "选择…"
                    icon.name: "document-open-folder"
                    onTriggered: iconDialog.open()
                }
                MenuItem {
                    text: "恢复默认图标"
                    icon.name: "edit-clear"
                    enabled: page.cfg_icon !== ""
                    onTriggered: page.cfg_icon = ""
                }
            }
        }

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

        // The slider and its read-out share one row; the value is a sibling
        // rather than a child, because a Slider does not lay out children.
        RowLayout {
            Kirigami.FormData.label: "图标填充率"
            spacing: Kirigami.Units.smallSpacing
            Slider {
                id: fillSlider
                Layout.fillWidth: true
                Layout.minimumWidth: Kirigami.Units.gridUnit * 12
                from: 40
                to: 100
                stepSize: 1
                value: page.cfg_iconFillPercent
                onMoved: page.cfg_iconFillPercent = Math.round(value)
            }
            Label {
                Layout.alignment: Qt.AlignVCenter
                Layout.minimumWidth: Kirigami.Units.gridUnit * 2
                horizontalAlignment: Text.AlignRight
                text: Math.round(fillSlider.value) + "%"
                opacity: 0.7
            }
        }
        Label {
            Layout.fillWidth: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 24
            text: "图标主题的图形只占图标框的一部分，其余是留白。这项配置图标可见部分的比例，"
                  + "补偿界面，让可见图标保持设计尺寸。图标视觉上偏小就调低，反之就调高。默认 85%。"
            font.pointSize: 9
            opacity: 0.7
            wrapMode: Text.WordWrap
        }

        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: "实验性内容"
        }
        CheckBox {
            id: experimentalCheck
            text: "启用实验性选项（磁贴颜色、动态磁贴、图标样式）"
            checked: page.cfg_experimentalEnabled
            onToggled: {
                page.cfg_experimentalEnabled = checked
                // Off means "as shipped": put every experimental option back
                // to its default so the stored config matches what is drawn.
                if (!checked)
                    page.resetExperimentalDefaults()
            }
        }
        Label {
            visible: page.experimentalOn
            Layout.fillWidth: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 24
            text: "关闭时磁贴始终按参考样式绘制，布局文件里的颜色与动态内容记录不会生效，"
                  + "磁贴右键菜单也不显示这两项。"
            font.pointSize: 9
            opacity: 0.7
            wrapMode: Text.WordWrap
        }

        ComboBox {
            id: skinBox
            visible: page.experimentalOn
            Kirigami.FormData.label: "磁贴风格"
            model: ["现代（半透明磁贴）", "早期 Windows（彩色磁贴）"]
            currentIndex: page.cfg_tileSkin === "early" ? 1 : 0
            onActivated: (index) => page.cfg_tileSkin = index === 1 ? "early" : "modern"
        }
        Label {
            visible: page.experimentalOn
            text: "彩色磁贴需要配对调色板；选择「早期」后磁贴会用其样式槽的底色。"
            font.pointSize: 9
            opacity: 0.7
            wrapMode: Text.WordWrap
        }

        ComboBox {
            id: paletteBox
            visible: page.experimentalOn
            Kirigami.FormData.label: "调色板"
            model: ["默认", "vivid", "pastel", "dark", "transparent",
                    "red", "pink", "purple", "indigo", "blue", "teal",
                    "green", "lime", "yellow", "orange", "brown", "grey"]
            currentIndex: Math.max(0, page.paletteValues.indexOf(page.cfg_tilePalette))
            onActivated: (index) => page.cfg_tilePalette = page.paletteValues[index]
        }
        TextField {
            id: weatherField
            visible: page.experimentalOn
            Kirigami.FormData.label: "天气源"
            placeholderText: "bbcukmet|weather|Beijing"
            text: page.cfg_weatherSource
            onTextChanged: page.cfg_weatherSource = text
        }
        CheckBox {
            id: cycleCheck
            visible: page.experimentalOn
            Kirigami.FormData.label: "动态磁贴轮播"
            text: "在图标与动态内容之间循环（每 4–6 秒，Windows 动态磁贴行为）"
            checked: true
        }
        ComboBox {
            id: variantBox
            visible: page.experimentalOn
            Kirigami.FormData.label: "切换动画"
            model: ["自动（滑入 + 翻转）", "只用滑入", "只用翻转"]
            currentIndex: Math.max(0, page.variantValues.indexOf(page.cfg_liveTileVariant))
            onActivated: (index) => page.cfg_liveTileVariant = page.variantValues[index]
        }
        CheckBox {
            id: pulseCheck
            visible: page.experimentalOn
            Kirigami.FormData.label: "内容更新"
            text: "动态内容切换时轻微脉冲（1 → 1.1 → 0.91，600 ms）"
            checked: page.cfg_pulseOnUpdate
            onToggled: page.cfg_pulseOnUpdate = checked
        }
        CheckBox {
            id: moreAniCheck
            visible: page.experimentalOn
            text: "使用全部 12 种切换动画（否则只有 4 种滑入）"
            checked: true
        }
        CheckBox {
            id: liveCheck
            visible: page.experimentalOn
            Kirigami.FormData.label: "动态磁贴"
            text: "显示磁贴上标记的动态内容（时钟 / 电池 / 日期）"
            checked: true
        }
        ComboBox {
            id: iconBox
            visible: page.experimentalOn
            Kirigami.FormData.label: "图标"
            model: ["自动（白色剪影）", "字母占位", "保留彩色图标"]
            currentIndex: Math.max(0, page.iconValues.indexOf(page.cfg_themedIcon))
            onActivated: (index) => page.cfg_themedIcon = page.iconValues[index]
        }
        CheckBox {
            id: appColorCheck
            visible: page.experimentalOn
            Kirigami.FormData.label: "应用主色"
            text: "应用自身颜色满足饱和度/亮度时用作磁贴底色"
            checked: page.cfg_forceAppColor
            onToggled: page.cfg_forceAppColor = checked
        }
    }
}
