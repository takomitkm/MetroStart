// Configuration pages of the applet: a single page with the accent colour.
import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.configuration
import "../ui"

ConfigModel {
    ConfigCategory {
        name: Translations.t("Appearance")
        icon: "preferences-desktop-color"
        source: "configAppearance.qml"
    }
    ConfigCategory {
        name: Translations.t("Language")
        icon: "preferences-desktop-locale"
        source: "configLanguage.qml"
    }
}
