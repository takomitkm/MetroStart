pragma Singleton
// Translations of the applet, looked up from a table that ships inside the
// package (see i18n/<language>.js, generated from po/<language>.po).
//
// Why not Ki18n: Plasma injects i18n() with the language chosen once for the
// whole process, so an applet-scoped language switch is impossible with it
// (and switching would also need a plasmashell restart). A table plus one
// reactive property gives an instant, applet-only switch.
//
// Performance notes, because every label in the menu reads this:
//   * `table` is resolved once per language change, never per call;
//   * `t()` is at most two object lookups and allocates no key string;
//   * placeholder substitution only runs when arguments are passed;
//   * the system language is walked once (inside `resolveTable`), not per call.
import QtQuick
import "i18n/zh_CN.js" as Zh

QtObject {
    id: root

    // "system" or a concrete language we ship a table for ("zh_CN", "en").
    property string language: "system"

    // The table of the language in use, or null for English (the source
    // language: an unresolved message is already the English text).
    readonly property var table: root.resolveTable(root.language)

    // "system" follows the session: the first language of Qt's UI language
    // list that we actually ship a table for, which is what Ki18n did before
    // (a language without a catalogue is skipped, not a reason to stop).
    function resolveTable(language) {
        if (language === "" || language === "system")
            return root.systemTable()
        return language === "zh_CN" ? Zh.table : null
    }

    function systemTable() {
        // Any Chinese entry wins, wherever it sits in the list: a language we
        // have no table for is skipped, not a reason to stop (that is what
        // Ki18n did with the catalogue, and a session configured as
        // "English, Chinese fallback" has to keep showing Chinese).
        const languages = Qt.locale().uiLanguages
        for (var i = 0; i < languages.length; ++i) {
            if (String(languages[i]).toLowerCase().indexOf("zh") === 0)
                return Zh.table
        }
        return null
    }

    // t("Message") / t("@context", "Message"), with optional %1..%N arguments.
    function t(contextOrMessage, message) {
        const context = message === undefined ? "" : contextOrMessage
        const msgid = message === undefined ? contextOrMessage : message
        var text = msgid
        const group = root.table !== null ? root.table[context] : undefined
        if (group !== undefined) {
            const translated = group[msgid]
            if (translated !== undefined)
                text = translated
        }
        const count = arguments.length
        if (count > 2) {
            for (var i = 2; i < count; ++i)
                text = text.replace("%" + (i - 1), String(arguments[i]))
        }
        return text
    }
}
