// Applet settings: interface language.
//
// The applet carries its own translation tables (see ui/Translations.qml), so
// this page can change the language of this applet alone, without touching the
// rest of the desktop and without restarting plasmashell: the table the
// singleton resolves is a reactive property, so every label re-renders at once.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import "."

KCM.SimpleKCM {
    id: page

    // "system" or one of the languages we ship a table for (see ui/i18n/).
    property string cfg_language: "system"
    readonly property var languages: ["system", "en", "zh_CN"]

    // Preview the choice in the dialog itself: the singleton is shared by every
    // page of this dialog, so the labels below follow immediately.
    onCfg_languageChanged: Translations.language = page.cfg_language
    Component.onCompleted: Translations.language = page.cfg_language

    Kirigami.FormLayout {
        RowLayout {
            Kirigami.FormData.label: Translations.t("@label:listbox", "Language")
            spacing: Kirigami.Units.smallSpacing

            ComboBox {
                id: languageBox
                Layout.minimumWidth: Kirigami.Units.gridUnit * 12
                model: [
                    Translations.t("@item:inlistbox", "Follow the session language"),
                    // Language names are shown in their own language on purpose:
                    // a translator should recognise their language even when the
                    // interface is in a language they do not read.
                    "English",
                    "简体中文" // i18n-gate: allow
                ]
                currentIndex: Math.max(0, page.languages.indexOf(page.cfg_language))
                onActivated: (index) => page.cfg_language = page.languages[index]
            }
        }

        Label {
            Layout.fillWidth: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 24
            text: Translations.t("@info:label",
                                "Only this applet is translated: the rest of the desktop keeps "
                                + "its own language. The choice applies immediately, no restart "
                                + "needed.")
            font.pointSize: 9
            opacity: 0.7
            wrapMode: Text.WordWrap
        }
    }
}
