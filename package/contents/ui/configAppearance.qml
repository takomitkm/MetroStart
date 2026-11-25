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
import "."

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
            Kirigami.FormData.label: Translations.t("@label", "Icon")
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
                ToolTip.text: page.cfg_icon === ""
                              ? Translations.t("@info:tooltip", "Default (Windows grid)") : page.cfg_icon
                ToolTip.delay: Kirigami.Units.toolTipDelay
            }

            Menu {
                id: iconMenu
                MenuItem {
                    text: Translations.t("@action:button", "Choose…")
                    icon.name: "document-open-folder"
                    onTriggered: iconDialog.open()
                }
                MenuItem {
                    text: Translations.t("@action:button", "Reset to default icon")
                    icon.name: "edit-clear"
                    enabled: page.cfg_icon !== ""
                    onTriggered: page.cfg_icon = ""
                }
            }
        }

        KQuickControls.ColorButton {
            id: accentButton
            Kirigami.FormData.label: Translations.t("@label:color", "Accent colour")
            dialogTitle: Translations.t("@title:dialog", "Choose accent colour")
            showAlphaChannel: false
            color: Metrics.accentColorDefault
        }

        Button {
            text: Translations.t("@action:button Restores the default accent colour", "Restore default (%1)",
                        String(Metrics.accentColorDefault))
            onClicked: accentButton.color = Metrics.accentColorDefault
        }

        CheckBox {
            id: compactCheck
            Kirigami.FormData.label: Translations.t("@label", "Start menu layout")
            text: Translations.t("@option:check", "Windowed (non full screen) Start menu")
            checked: false
        }

        // The slider and its read-out share one row; the value is a sibling
        // rather than a child, because a Slider does not lay out children.
        RowLayout {
            Kirigami.FormData.label: Translations.t("@label:slider", "Icon fill ratio")
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
            text: Translations.t("@info:label",
                        "An icon theme's artwork fills only part of its box, the rest is padding. "
                        + "This sets how much of the box counts as artwork, so the visible icon keeps "
                        + "its designed size. Lower it if icons look too small, raise it if they "
                        + "overflow. Default 85%.")
            font.pointSize: 9
            opacity: 0.7
            wrapMode: Text.WordWrap
        }

        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: Translations.t("@title:group", "Experimental options")
        }
        CheckBox {
            id: experimentalCheck
            text: Translations.t("@option:check",
                        "Enable the experimental options (tile colours, live tiles, icon style)")
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
            text: Translations.t("@info:label",
                        "While this is off, tiles are always drawn the reference way: the colour and "
                        + "live content records in the layout file are ignored and the tile context "
                        + "menu hides both entries.")
            font.pointSize: 9
            opacity: 0.7
            wrapMode: Text.WordWrap
        }

        ComboBox {
            id: skinBox
            visible: page.experimentalOn
            Kirigami.FormData.label: Translations.t("@label", "Tile style")
            model: [Translations.t("@item:inlistbox", "Modern (translucent tiles)"),
                    Translations.t("@item:inlistbox", "Early Windows (coloured tiles)")]
            currentIndex: page.cfg_tileSkin === "early" ? 1 : 0
            onActivated: (index) => page.cfg_tileSkin = index === 1 ? "early" : "modern"
        }
        Label {
            visible: page.experimentalOn
            text: Translations.t("@info:label",
                        "Coloured tiles need a matching palette: with \"early\" a tile takes the "
                        + "background of its style slot.")
            font.pointSize: 9
            opacity: 0.7
            wrapMode: Text.WordWrap
        }

        ComboBox {
            id: paletteBox
            visible: page.experimentalOn
            Kirigami.FormData.label: Translations.t("@label:listbox", "Palette")
            // Palette ids stay untranslated (they are the stored value); only
            // the first entry has a translatable name.
            model: [Translations.t("@item:inlistbox", "Default"), "vivid", "pastel", "dark", "transparent",
                    "red", "pink", "purple", "indigo", "blue", "teal",
                    "green", "lime", "yellow", "orange", "brown", "grey"]
            currentIndex: Math.max(0, page.paletteValues.indexOf(page.cfg_tilePalette))
            onActivated: (index) => page.cfg_tilePalette = page.paletteValues[index]
        }
        TextField {
            id: weatherField
            visible: page.experimentalOn
            Kirigami.FormData.label: Translations.t("@label", "Weather source")
            placeholderText: "bbcukmet|weather|Beijing"
            text: page.cfg_weatherSource
            onTextChanged: page.cfg_weatherSource = text
        }
        CheckBox {
            id: cycleCheck
            visible: page.experimentalOn
            Kirigami.FormData.label: Translations.t("@label:check", "Live tile cycling")
            text: Translations.t("@option:check",
                        "Cycle between the icon and the live content (every 4–6 s, like Windows)")
            checked: true
        }
        ComboBox {
            id: variantBox
            visible: page.experimentalOn
            Kirigami.FormData.label: Translations.t("@label:listbox", "Content swap animation")
            model: [Translations.t("@item:inlistbox", "Automatic (slide + flip)"),
                    Translations.t("@item:inlistbox", "Slide only"), Translations.t("@item:inlistbox", "Flip only")]
            currentIndex: Math.max(0, page.variantValues.indexOf(page.cfg_liveTileVariant))
            onActivated: (index) => page.cfg_liveTileVariant = page.variantValues[index]
        }
        CheckBox {
            id: pulseCheck
            visible: page.experimentalOn
            Kirigami.FormData.label: Translations.t("@label:check", "Content update")
            text: Translations.t("@option:check", "Pulse slightly when the live content swaps (1 → 1.1 → 0.91, 600 ms)")
            checked: page.cfg_pulseOnUpdate
            onToggled: page.cfg_pulseOnUpdate = checked
        }
        CheckBox {
            id: moreAniCheck
            visible: page.experimentalOn
            text: Translations.t("@option:check", "Use all 12 swap animations (otherwise only the 4 slides)")
            checked: true
        }
        CheckBox {
            id: liveCheck
            visible: page.experimentalOn
            Kirigami.FormData.label: Translations.t("@label:check", "Live tiles")
            text: Translations.t("@option:check", "Show the live content a tile is marked with (clock, battery, date)")
            checked: true
        }
        ComboBox {
            id: iconBox
            visible: page.experimentalOn
            Kirigami.FormData.label: Translations.t("@label:listbox", "Icon style")
            model: [Translations.t("@item:inlistbox", "Automatic (white silhouette)"),
                    Translations.t("@item:inlistbox", "Letter placeholder"),
                    Translations.t("@item:inlistbox", "Keep the coloured icon")]
            currentIndex: Math.max(0, page.iconValues.indexOf(page.cfg_themedIcon))
            onActivated: (index) => page.cfg_themedIcon = page.iconValues[index]
        }
        CheckBox {
            id: appColorCheck
            visible: page.experimentalOn
            Kirigami.FormData.label: Translations.t("@label:check", "Application colour")
            text: Translations.t("@option:check",
                        "Use the application's own colour as the tile background when it is saturated and bright enough")
            checked: page.cfg_forceAppColor
            onToggled: page.cfg_forceAppColor = checked
        }
    }
}
