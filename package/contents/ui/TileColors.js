// Tile colour system of the "early Windows" skin.
//
// The model comes from Square Home 4.1.5 (app_analyse/SQUARE-HOME-ANALYSIS.md
// §2): 15 numbered style slots with a background and a text colour, 16
// selectable palettes, a "use the app's own colour" mode that validates the
// colour in HSV, and an automatic contrast fallback.
//
// Everything is pure data here; Tile.qml only asks for `resolve()`.
.pragma library
.import "TilePalettes.js" as Palettes

// 15 default slots: [background, text, name].
var slots = [
    ["#2196F3", "#FFFFFF", "blue"],
    ["#FF9800", "#FFFFFF", "orange"],
    ["#009688", "#FFFFFF", "teal"],
    ["#F44336", "#FFFFFF", "red"],
    ["#FBC02D", "#FFFFFF", "yellow"],
    ["#3F51B5", "#FFFFFF", "indigo"],
    ["#E91E63", "#FFFFFF", "pink"],
    ["#4CAF50", "#FFFFFF", "green"],
    ["#673AB7", "#FFFFFF", "purple"],
    ["#000000", "#FFFFFF", "black"],
    ["#424242", "#FFFFFF", "grey800"],
    ["#9E9E9E", "#030303", "grey500"],
    ["#F5F5F5", "#030303", "grey100"],
    ["#77000000", "#FFFFFF", "translucent"],
    ["#00000000", "#FFFFFF", "transparent"]
]

// Brand colours of well-known applications (C1: bundled table). Keyed by the
// .desktop basename without ".desktop" and by the display name, so both
// `org.kde.dolphin` and "Dolphin" resolve.
var brand = {
    "firefox": "#FF7139", "firefox-esr": "#FF7139",
    "chromium": "#4285F4", "google-chrome": "#4285F4",
    "microsoft-edge": "#0F6CBD", "opera": "#FF1B2D", "vivaldi": "#EF5C4B",
    "brave-browser": "#FB542B",
    "thunderbird": "#0A84FF", "evolution": "#3584E4",
    "code": "#007ACC", "code-oss": "#007ACC", "vscodium": "#007ACC",
    "jetbrains-toolbox": "#000000", "pycharm": "#21D789",
    "android-studio": "#3DDC84", "intellij": "#FE315D",
    "kicad": "#0B6FA8", "libreoffice-calc": "#0F9D58",
    "libreoffice-writer": "#4285F4", "libreoffice-impress": "#F4B400",
    "onlyoffice": "#FF6F3D", "wps-office": "#1F7AE0",
    "vlc": "#FF8800", "mpv": "#691F69", "spotify": "#1DB954",
    "steam": "#1B2838", "discord": "#5865F2", "telegram": "#229ED9",
    "gimp": "#5C5543", "inkscape": "#231F20", "blender": "#EA7600",
    "krita": "#3BDAFF", "obs": "#302E31",
    "dolphin": "#1D99F3", "konsole": "#232629", "kate": "#1D99F3",
    "okular": "#1D99F3", "gwenview": "#1D99F3", "ark": "#1D99F3",
    "kdenlive": "#1D99F3", "krita-1": "#3BDAFF",
    "telegram-desktop": "#229ED9", "wechat": "#07C160",
    "qq": "#12B7F5", "vlc-1": "#FF8800",
    "systemsettings": "#1D99F3", "discover": "#1D99F3",
    "org.kde.dolphin": "#1D99F3", "org.kde.konsole": "#232629",
    "org.kde.kate": "#1D99F3", "org.kde.okular": "#1D99F3",
    "org.kde.discover": "#1D99F3"
}

var colourNames = ["blue", "orange", "teal", "red", "yellow", "indigo",
                   "pink", "green", "purple", "black", "grey800", "grey500",
                   "grey100", "translucent", "transparent"]

function clamp01(v) { return Math.max(0, Math.min(1, v)) }

// Stable per-application slot: keeps the out-of-the-box early skin colourful
// without touching the saved layout. Explicit `tile.style` always wins.
function hashedSlot(key) {
    var h = 5381
    var text = String(key || "")
    for (var i = 0; i < text.length; ++i)
        h = ((h * 33) ^ text.charCodeAt(i)) >>> 0
    return h % 9
}

// "#RRGGBB" / "#AARRGGBB" -> {r,g,b,a} (0..1)
function parseColor(value) {
    if (!value)
        return null
    var s = String(value).trim()
    if (s.charAt(0) !== "#")
        s = "#" + s
    var hex = s.substring(1)
    var a = 1.0, r, g, b
    if (hex.length === 8) {
        a = parseInt(hex.substring(0, 2), 16) / 255
        hex = hex.substring(2)
    } else if (hex.length === 3) {
        hex = hex.charAt(0) + hex.charAt(0) + hex.charAt(1) + hex.charAt(1)
                 + hex.charAt(2) + hex.charAt(2)
    }
    if (hex.length !== 6)
        return null
    r = parseInt(hex.substring(0, 2), 16) / 255
    g = parseInt(hex.substring(2, 4), 16) / 255
    b = parseInt(hex.substring(4, 6), 16) / 255
    return { r: r, g: g, b: b, a: a }
}

function rgbToHsv(r, g, b) {
    var max = Math.max(r, g, b), min = Math.min(r, g, b)
    var v = max, s = max === 0 ? 0 : (max - min) / max
    var h = 0
    if (max !== min) {
        var d = max - min
        if (max === r) h = (g - b) / d + (g < b ? 6 : 0)
        else if (max === g) h = (b - r) / d + 2
        else h = (r - g) / d + 4
        h /= 6
    }
    return { h: h, s: s, v: v }
}

// Square Home's m(color): a usable app colour needs some saturation and
// brightness and must not be a pure grey.
function appColorUsable(value) {
    var c = parseColor(value)
    if (!c)
        return false
    var hsv = rgbToHsv(c.r, c.g, c.b)
    if (hsv.s <= 0.35 || hsv.v <= 0.35)
        return false
    if (Math.abs(c.r - c.g) < 0.02 && Math.abs(c.g - c.b) < 0.02)
        return false
    return true
}

function luminance(value) {
    var c = parseColor(value)
    if (!c)
        return 0
    return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
}

// Text colour with a sane contrast for a given background.
function contrastText(background) {
    var c = parseColor(background)
    if (!c)
        return "#FFFFFF"
    var l = 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
    return l > 0.55 ? "#030303" : "#FFFFFF"
}

// Contrast ratio (WCAG) between two colours, used to reject odd combinations.
function contrastRatio(a, b) {
    function relLum(v) {
        var c = parseColor(v)
        if (!c)
            return 0
        function ch(x) { return x <= 0.03928 ? x / 12.92 : Math.pow((x + 0.055) / 1.055, 2.4) }
        return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b)
    }
    var la = relLum(a), lb = relLum(b)
    var hi = Math.max(la, lb), lo = Math.min(la, lb)
    return (hi + 0.05) / (lo + 0.05)
}

// Palette lookup: "default" -> the built-in slots, otherwise the extracted set.
function palette(name, index) {
    if (!name || name === "default")
        return null
    var p = Palettes.palettes[name]
    if (!p || !p.bg || index < 0 || index >= p.bg.length)
        return null
    return { bg: p.bg[index], fg: p.fg[index] }
}

function appBrandKey(id, name) {
    var keys = []
    if (id) {
        keys.push(String(id).toLowerCase())
        keys.push(String(id).toLowerCase().replace(/\.desktop$/, ""))
        keys.push(String(id).toLowerCase().replace(/\.desktop$/, "").split(".").pop())
    }
    if (name)
        keys.push(String(name).toLowerCase())
    for (var i = 0; i < keys.length; ++i) {
        if (brand[keys[i]] !== undefined)
            return brand[keys[i]]
    }
    return ""
}

// Resolve the colours of one tile.
//
//   tile      { style, color, fgColor, ... }   (style -1 = custom colour)
//   options   { palette, forceAppColor, appColor, appId, appName }
//
// Returns { bg, fg, custom }.
function resolve(tile, options) {
    var opt = options || {}
    var styleIndex = (tile && tile.style !== undefined && tile.style !== null)
                     ? Number(tile.style) : -1
    if (styleIndex < 0)
        styleIndex = hashedSlot(opt.appId || opt.appName || "")
    var custom = tile ? tile.color : ""
    if (custom && parseColor(custom)) {
        var fgCustom = (tile.fgColor && parseColor(tile.fgColor))
                       ? tile.fgColor : contrastText(custom)
        return { bg: custom, fg: fgCustom, custom: true }
    }

    // The app's own colour wins when the user asked for it and it is usable.
    var appColour = opt.appColor || ""
    if (!appColour && opt.forceAppColor)
        appColour = appBrandKey(opt.appId, opt.appName)
    if (opt.forceAppColor && appColour && appColorUsable(appColour)) {
        return { bg: appColour, fg: contrastText(appColour), custom: false }
    }

    var p = palette(opt.palette, styleIndex)
    if (p)
        return { bg: p.bg, fg: p.fg, custom: false }

    var slot = slots[Math.min(slots.length - 1, Math.max(0, styleIndex))]
    var fg = slot[1]
    if (contrastRatio(slot[0], fg) < 4.5)
        fg = contrastText(slot[0])
    return { bg: slot[0], fg: fg, custom: false }
}
