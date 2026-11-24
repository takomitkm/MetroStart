// The applet's live data: home directory, layout file, applications, user.
import QtQuick
import org.kde.plasma.plasma5support as P5Support
import org.kde.coreaddons as KCoreAddons
import "Paths.js" as Paths
import "Layout.js" as Layout

Item {
    id: runtime

    property string homeDir: ""
    property var config: null
    property bool configLoaded: false
    property string configPath: ""
    property string wallpaperUrl: ""
    property var apps: appIndex.apps
    property bool ready: appIndex.ready

    readonly property string userName: (kuser.fullName !== undefined && kuser.fullName !== "")
                                        ? kuser.fullName
                                        : (kuser.loginName !== undefined ? kuser.loginName : "")
    readonly property string fullName: kuser.fullName !== undefined ? kuser.fullName : ""
    readonly property url avatarUrl: kuser.faceIconUrl !== undefined ? kuser.faceIconUrl : ""

    KCoreAddons.KUser {
        id: kuser
    }

    AppIndex {
        id: appIndex
        homeDir: runtime.homeDir
    }

    // HOME is needed before the applications directories can be listed.
    P5Support.DataSource {
        id: shell
        engine: "executable"
        onNewData: (sourceName, data) => {
            shell.disconnectSource(sourceName)
        }
    }

    function run(command, onDone) {
        const cb = function (sourceName, data) {
            if (sourceName !== command)
                return
            shell.newData.disconnect(cb)
            if (onDone)
                onDone(data)
        }
        shell.newData.connect(cb)
        shell.connectSource(command)
    }

    // The desktop wallpaper changes when the user changes it, not when the
    // menu opens. Asking PlasmaShell means forking qdbus6 (and a PlasmaShell
    // script evaluation) on every open, so the answer is remembered and only
    // re-asked once it is stale. `force` re-reads it immediately.
    property bool wallpaperAsked: false
    property double wallpaperFetchedAt: 0
    readonly property int wallpaperRefreshInterval: 60000
    function loadWallpaper(force) {
        const nowMs = Date.now()
        if (wallpaperAsked && !force
                && nowMs - wallpaperFetchedAt < wallpaperRefreshInterval)
            return
        wallpaperAsked = true
        const script = 'var d=desktops()[0]; d.currentConfigGroup=["Wallpaper",d.wallpaperPlugin,"General"]; print(d.readConfig("Image"));'
        run("qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript '" + script + "'", function (data) {
            if (data && data["exit code"] === 0 && data.stdout) {
                const url = data.stdout.trim()
                if (url !== "") {
                    runtime.wallpaperUrl = url
                    runtime.wallpaperFetchedAt = Date.now()
                    return
                }
            }
            // Let the next open try again instead of caching a failure.
            runtime.wallpaperAsked = false
        })
    }

    function loadConfig() {
        const path = Paths.configPath()
        runtime.configPath = path
        if (path === "")
            return
        run("cat \"" + path + "\"", function (data) {
            if (data && data["exit code"] === 0 && data.stdout) {
                try {
                    runtime.config = JSON.parse(data.stdout)
                } catch (e) {
                    console.warn("MetroStart: cannot parse " + path + ": " + e)
                }
            }
            runtime.configLoaded = true
        })
    }

    // Write the (edited) layout back. The JSON goes through a quoted heredoc so
    // no quoting of the content is needed; the temp file keeps a half written
    // file from ever being read.
    function saveConfig(text) {
        const path = Paths.configPath()
        if (path === "")
            return
        const temp = path + ".tmp"
        const command = "cat > '" + temp + "' <<'METROSTART_LAYOUT_EOF'\n"
                        + text + "\nMETROSTART_LAYOUT_EOF\nmv '" + temp + "' '" + path + "'"
        run(command)
    }

    function launch(entry) {
        if (!entry)
            return
        // Prefer the .desktop file itself; launching it through the file
        // manager (kioclient) would open the desktop entry as a document.
        const target = entry.path || entry.desktopPath || ""
        if (target !== "" && target.endsWith(".desktop")) {
            // gtk-launch takes the .desktop id and really starts the app;
            // gio launch is the more portable fallback.
            const id = target.split("/").pop().replace(/\.desktop$/, "")
            run("gtk-launch \"" + id + "\" 2>/dev/null || gio launch \"" + target + "\""
                + " 2>/dev/null || kde-open5 \"" + target + "\"")
            return
        }
        if (entry.exec && entry.exec !== "")
            run(entry.exec)
    }

    function powerAction(action) {
        switch (action) {
        case "suspend": run("systemctl suspend"); break
        case "poweroff": run("systemctl poweroff"); break
        case "reboot": run("systemctl reboot"); break
        case "logout": run("qdbus6 org.kde.ksmserver /KSMServer logout 0 0 0 2>/dev/null || qdbus org.kde.ksmserver /KSMServer logout 0 0 0"); break
        }
    }

    Component.onCompleted: {
        run("printf %s \"$HOME\"", function (data) {
            runtime.homeDir = (data && data.stdout) ? data.stdout.trim() : ""
            Paths.setHome(runtime.homeDir)
            runtime.loadConfig()
            runtime.loadWallpaper()
        })
    }
}
