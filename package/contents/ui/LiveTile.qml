// Live content of a tile (early skin, stage 4 of
// plans/EARLY-STYLE-INTEGRATION.md).
//
//   clock   - digital time + date, aligned to the next minute
//   battery - charge level from the powermanagement data engine
//   date    - day of month
//
// The content is laid out like Windows' live tiles: a large value in the middle
// and a small caption underneath. The caller decides when to swap between this
// and the tile's ordinary glyph (see the tile cycle in motion.js).
import QtQuick
import org.kde.plasma.plasma5support as P5Support
import Qt.labs.folderlistmodel as FolderModel

Item {
    id: root

    property string type: "clock"
    property color textColor: "#FFFFFF"
    property string family: "Noto Sans"
    property int bigSize: 28
    property int smallSize: 12
    property var batterySource: null
    property string userName: ""
    property string homeDir: ""
    property string folder: ""    // photo folder; "" = <home>/Pictures

    // The components below are all created on demand: a FolderListModel holds
    // an inotify instance and a thread of its own even when it watches nothing
    // (an empty `folder` falls back to the process working directory), and the
    // data engines register their sources with plasmashell. A tile that shows
    // no live content must not own any of them.
    readonly property bool wantsPhotos: root.type === "photos"
    readonly property bool wantsBattery: root.type === "battery"
    readonly property bool wantsWeather: root.type === "weather"
                                       && root.weatherSource !== ""

    readonly property date now: clockTimer.tick ? clockTimer.stamp : new Date()

    Timer {
        id: clockTimer
        // aligned to the next minute, like Square Home's digital clock tile
        interval: 60000 - (Date.now() % 60000)
        running: root.visible && root.type === "clock"
        repeat: true
        property var stamp: new Date()
        property bool tick: false
        onTriggered: {
            stamp = new Date()
            tick = !tick
            interval = 60000 - (Date.now() % 60000)
        }
    }

    Loader {
        id: powerLoader
        active: root.wantsBattery
        sourceComponent: P5Support.DataSource {
            engine: "powermanagement"
            connectedSources: ["Battery"]
        }
    }

    readonly property int batteryPercent: {
        if (!root.wantsBattery || powerLoader.item === null)
            return -1
        var d = powerLoader.item.data["Battery"] || {}
        var p = d.Percent !== undefined ? d.Percent : d.percent
        return p === undefined ? -1 : Math.round(p)
    }

    // ---- photo slideshow (F2): images from a folder, one every 8 s --------
    property var photoTimer: photoClock
    property int photoIndex: 0
    readonly property int photoCount: photoFolder.item !== null
                                        ? photoFolder.item.count : 0
    Timer {
        id: photoClock
        interval: 8000
        running: root.wantsPhotos && root.photoCount > 0
        repeat: true
        onTriggered: root.photoIndex = root.nextPhoto(root.photoIndex)
    }
    // Created only for a photo tile: the model is what holds the inotify watch.
    Loader {
        id: photoFolder
        active: root.wantsPhotos
        sourceComponent: FolderModel.FolderListModel {
            folder: root.folder !== ""
                    ? root.folder
                    : (root.homeDir !== "" ? "file://" + root.homeDir + "/Pictures" : "")
            nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.bmp"]
            showDirs: false
            sortField: FolderModel.FolderListModel.Name
            onCountChanged: root.photoIndex = 0
        }
    }
    // A file the image plugin cannot decode (a mis-named PNG, a truncated
    // download) would otherwise be retried on every slide change and log an
    // error each time.
    property var brokenPhotos: ({})
    function photoFile(index) {
        if (photoFolder.item === null || root.photoCount === 0)
            return ""
        const f = photoFolder.item.get(Math.min(index, root.photoCount - 1), "filePath")
        return (typeof f === "string" && !root.brokenPhotos[f]) ? f : ""
    }
    function nextPhoto(from) {
        const n = root.photoCount
        if (n === 0)
            return from
        for (var i = 1; i <= n; ++i) {
            const candidate = (from + i) % n
            if (root.brokenPhotos[photoFolder.item.get(candidate, "filePath")] !== true)
                return candidate
        }
        return from
    }
    readonly property string photoSource: {
        if (!root.wantsPhotos || photoFolder.item === null)
            return ""
        const f = root.photoFile(root.photoIndex)
        // Every file failed to decode: show nothing rather than retry them.
        if (f === "")
            return ""
        return "file://" + f
    }
    onPhotoIndexChanged: if (photoFolder.item !== null && !root.brokenPhotos[photoFile(root.photoIndex)]) {
        const fixed = photoFile(root.photoIndex) !== "" ? root.photoIndex
                                                        : nextPhoto(root.photoIndex)
        if (fixed !== root.photoIndex)
            root.photoIndex = fixed
    }
    Image {
        anchors.fill: parent
        visible: root.photoSource !== ""
        source: root.photoSource
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        onStatusChanged: {
            if (status !== Image.Error || root.photoSource === "")
                return
            var bad = {}
            for (var k in root.brokenPhotos)
                bad[k] = true
            bad[root.photoFile(root.photoIndex)] = true
            root.brokenPhotos = bad
            root.photoIndex = root.nextPhoto(root.photoIndex)
        }
    }

    // ---- month calendar (F2) -------------------------------------------
    Grid {
        visible: root.type === "calendar"
        anchors.centerIn: parent
        columns: 7
        spacing: Math.max(1, Math.round(root.bigSize / 14))
        Repeater {
            model: root.type === "calendar" ? root.dayModel : []
            Text {
                required property var modelData
                text: modelData.day
                color: root.textColor
                opacity: modelData.today ? 1.0 : (modelData.header ? 0.85 : 0.68)
                font.bold: modelData.today
                font.pixelSize: Math.round(root.smallSize * 1.05)
                font.family: root.family
                width: Math.round(root.smallSize * 1.9)
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }
    readonly property var dayModel: {
        if (root.type !== "calendar")
            return []
        const base = root.now
        const first = new Date(base.getFullYear(), base.getMonth(), 1)
        const days = new Date(base.getFullYear(), base.getMonth() + 1, 0).getDate()
        const lead = (first.getDay() + 6) % 7     // Monday-first
        const out = []
        for (let i = 0; i < 7; ++i)
            out.push({ day: ["M", "T", "W", "T", "F", "S", "S"][i], header: true, today: false })
        for (let i = 0; i < lead; ++i)
            out.push({ day: "", header: false, today: false })
        for (let d = 1; d <= days; ++d)
            out.push({ day: String(d), header: false,
                       today: d === base.getDate() })
        return out
    }

    // ---- weather (F2, Plasma weather engine) ---------------------------
    property string weatherSource: ""
    property string place: ""
    Loader {
        id: weatherLoader
        active: root.wantsWeather
        sourceComponent: P5Support.DataSource {
            engine: "weather"
            connectedSources: [root.weatherSource]
        }
    }
    readonly property var weatherData: {
        if (!root.wantsWeather || weatherLoader.item === null)
            return ({})
        return weatherLoader.item.data[root.weatherSource] || ({})
    }
    readonly property string weatherTemp: {
        const d = root.weatherData
        if (d["Temperature"] !== undefined)
            return Math.round(Number(d["Temperature"])) + "°"
        return "—"
    }

    readonly property string bigText: {
        if (root.type === "clock")
            return Qt.formatTime(root.now, "HH:mm")
        if (root.type === "date")
            return String(root.now.getDate())
        if (root.type === "battery")
            return root.batteryPercent >= 0 ? root.batteryPercent + "%" : "—"
        if (root.type === "weather")
            return root.weatherTemp
        return ""
    }
    readonly property string smallText: {
        if (root.type === "clock")
            return Qt.formatDate(root.now, "yyyy/MM/dd")
        if (root.type === "date")
            return Qt.formatDate(root.now, "MMM")
        if (root.type === "battery")
            return "电池"
        if (root.type === "weather")
            return root.weatherData["Condition"] !== undefined
                   ? String(root.weatherData["Condition"]) : (root.place || "天气")
        return ""
    }

    Column {
        anchors.centerIn: parent
        spacing: 2
        visible: root.bigText !== "" && root.type !== "photos" && root.type !== "calendar"
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.bigText
            color: root.textColor
            font.family: root.family
            font.pixelSize: root.bigSize
            font.bold: true
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.smallText
            color: root.textColor
            opacity: 0.72
            font.family: root.family
            font.pixelSize: root.smallSize
        }
    }
}
