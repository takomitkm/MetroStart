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

    P5Support.DataSource {
        id: power
        engine: "powermanagement"
        connectedSources: root.visible && root.type === "battery" ? ["Battery"] : []
    }

    readonly property int batteryPercent: {
        if (root.type !== "battery")
            return -1
        var d = power.data["Battery"] || {}
        var p = d.Percent !== undefined ? d.Percent : d.percent
        return p === undefined ? -1 : Math.round(p)
    }

    // ---- photo slideshow (F2): images from a folder, one every 8 s --------
    property var photoTimer: photoClock
    property int photoIndex: 0
    readonly property int photoCount: photoFolder.count
    Timer {
        id: photoClock
        interval: 8000
        running: root.visible && root.type === "photos"
        repeat: true
        onTriggered: root.photoIndex = (root.photoIndex + 1) % Math.max(1, photoFolder.count)
    }
    FolderModel.FolderListModel {
        id: photoFolder
        folder: root.type === "photos"
                ? (root.folder !== "" ? root.folder
                  : (root.homeDir !== "" ? "file://" + root.homeDir + "/Pictures" : ""))
                : ""
        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.bmp"]
        showDirs: false
        sortField: FolderModel.FolderListModel.Name
        onCountChanged: root.photoIndex = 0
    }
    Image {
        anchors.fill: parent
        visible: root.type === "photos" && photoFolder.count > 0
        source: photoFolder.count > 0
                ? "file:///" + photoFolder.get(Math.min(root.photoIndex, photoFolder.count - 1), "filePath") : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
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
    P5Support.DataSource {
        id: weather
        engine: "weather"
        connectedSources: root.type === "weather" && root.weatherSource !== ""
                          ? [root.weatherSource] : []
    }
    readonly property var weatherData: {
        if (root.type !== "weather" || root.weatherSource === "")
            return ({})
        return weather.data[root.weatherSource] || ({})
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
