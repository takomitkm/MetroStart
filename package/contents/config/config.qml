// Configuration pages of the applet: a single page with the accent colour.
import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.configuration

ConfigModel {
    ConfigCategory {
        name: "外观"
        icon: "preferences-desktop-color"
        source: "configAppearance.qml"
    }
}
