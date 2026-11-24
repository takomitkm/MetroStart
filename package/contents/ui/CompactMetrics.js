// Design constants of the non-fullscreen ("windowed") Start menu.
//
// Measured on screenshots/windows-reference/non-fullscreen-start/ (2560x1380
// design space, taskbar 60): the compact menu keeps the fullscreen components
// and only changes the tile rhythm and the app list.
//
//   panel        x 0..(486 + 486 * columns - 1), bottom edge on the taskbar
//   sidebar      0..74 (collapsed), 0..382 (expanded)
//   app list     75..479, rows 54 px, hover rect 92..458
//   tiles        486.., 3 columns of 462 on a 486 pitch at the default width
//
// Tile grid: cell 72 (90 * 0.8), gap 6 (unchanged), 2x2 tile 150,
// group width 462 (six cells), group gap 24 (fullscreen: 205), first tile row
// 74 px below the panel top, title baseline 25 px above it, stacked groups
// keep 162 px between their tile areas.
.pragma library
.import "metrics.js" as Base

var columnsMin = 1
var columnsMax = 4
// Panel geometry: the panel is `panelBaseWidth` wide plus one `panelPitch` per
// tile column (sidebar + application list + the tile columns).
var panelBaseWidth = 486
var panelPitch = 486
var tileIconScale = 0.475
var tileIconScaleNoLabel = 0.66
var cell = 72
var gap = 6
var pitch = 78
var groupMinCells = 6
var groupGapX = 24
var groupGapY = 85  // reference: a group ends at 791, the next starts at 876 (85 + the 74 title block = 11 px box gap)
var groupHeader = 74
var groupsTop = 74
var groupsBottom = 42
// The group box starts at the tiles view top, so the title block covers the
// whole run above the first tile row (74 px). The title text sits 25 px above
// the tiles (measured: ink 293..305 with tiles at 330).
var groupTitleBlockTop = -74
var groupTitleBlockHeight = 74
var groupTitleOffsetY = -25
var groupTitleSize = 17
var groupTitlePressInset = 6
var groupTitleHintX = 2
var groupPlaceholderHeight = 38
var groupPlaceholderInset = 5
var groupHandleWidth = 19
var groupHandleRight = 20
var groupHandleGap = 3

// Tile labels: 150 px tile, label ink bottom 12 px above the tile bottom,
// left inset 13 (measured "PowerPoint" ink 499..588 in a 486..635 tile).
var labelSize = 17
var labelX = 13
var labelBaseline = 138
var labelLineGap = 18

// Rename field scaled into the 74 px title block (fullscreen: 84 tall).
var renameHeight = 74
var renameFieldX = 10
var renameFieldY = 17
var renameFieldHeight = 34
var renameFieldRight = 62
var renameTextInset = 8
var renameTextSize = 16
var renameHandleRight = 20
var renameHandleY = 32

// Panel and layout of the windowed menu.
var sidebarWidth = 75
var sidebarExpanded = 383
var appListWidth = 405
var listRowHeight = 54
var listTextBaseline = 38
var listHeaderBaseline = 41
var listRowInsetLeft = 17
var listRowInsetRight = 21
var listIconX = 13      // icon box centred on x=113.5, 51 px (glyph ~34)
var listIconSize = 51
var listTextX = 70      // 17 + 53
var listTextSize = 19
var listLetterX = 33    // 17 + 16
var listHeaderX = 23    // 17 + 6
var scrollBarWidth = 18
var scrollBarThinWidth = 2
var scrollBarRightInset = 3
var scrollBarInsetY = 0
var panelTopPadding = 8
var panelGap = 6
var tilesGapToPanelRight = 24
var edgeResizeGrab = 8

// Sidebar rows (measured from the panel's bottom edge: avatar ink 122..93
// above it, power ink 47..24 above it, hamburger 33 below the panel top).
var sidebarHeaderTop = 11
var hamburgerY = 33
var titleBaseline = 53
var rowHeight = 54
var userRowBottom = 81
var powerRowBottom = 9

// Backdrop: obs ≈ k * blur(wallpaper) + c (fit on the empty strips of
// default-open.png, MAE 2.2). Expressed as a tint layer over the blurred
// wallpaper: opacity = 1 - k, colour = c / (1 - k).
var backdropOpacity = 0.91
var backdropColor = "#232827"
var backdropBlurMax = 96
var backdropBlurAmount = 1.0
var backdropNoise = 0.0
// Sidebar acrylic of the windowed Start (see the expanded reference
// side-bar.png: the app list behind it is smeared to a flat frost).
var sidebarPanelAlpha = 0.42
var sidebarPanelColor = "#32363C"
var sidebarBlurMax = 96
var sidebarBlurAmount = 1.0

// Build the metrics object the tile components expect: every key of the
// fullscreen module, with the compact geometry on top.
function values() {
    var m = {}
    for (var k in Base)
        m[k] = Base[k]
    // tile icon sizing has to be overridden explicitly: without this the
    // loop above leaves the fullscreen ratios in place.
    m.columnsMin = columnsMin
    m.columnsMax = columnsMax
    m.panelBaseWidth = panelBaseWidth
    m.panelPitch = panelPitch
    m.tileIconScale = tileIconScale
    m.tileIconScaleNoLabel = tileIconScaleNoLabel
    m.listIconSize = listIconSize
    m.listIconX = listIconX
    m.cell = cell
    m.gap = gap
    m.pitch = pitch
    m.groupMinCells = groupMinCells
    m.groupGapX = groupGapX
    m.groupGapY = groupGapY
    m.groupHeader = groupHeader
    m.groupsTop = groupsTop
    m.groupsBottom = groupsBottom
    m.groupTitleBlockTop = groupTitleBlockTop
    m.groupTitleBlockHeight = groupTitleBlockHeight
    m.groupTitleOffsetY = groupTitleOffsetY
    m.groupTitleSize = groupTitleSize
    m.groupTitlePressInset = groupTitlePressInset
    m.groupTitleHintX = groupTitleHintX
    m.groupPlaceholderHeight = groupPlaceholderHeight
    m.groupPlaceholderInset = groupPlaceholderInset
    m.groupHandleWidth = groupHandleWidth
    m.groupHandleRight = groupHandleRight
    m.groupHandleGap = groupHandleGap
    m.labelSize = labelSize
    m.labelX = labelX
    m.labelBaseline = labelBaseline
    m.labelLineGap = labelLineGap
    m.renameHeight = renameHeight
    m.renameFieldX = renameFieldX
    m.renameFieldY = renameFieldY
    m.renameFieldHeight = renameFieldHeight
    m.renameFieldRight = renameFieldRight
    m.renameTextInset = renameTextInset
    m.renameTextSize = renameTextSize
    m.renameHandleRight = renameHandleRight
    m.renameHandleY = renameHandleY
    return m
}

// Panel width for a column count: 486 + 486 * n (972 / 1458 / 1944 / 2430).
function panelWidth(n) {
    return panelBaseWidth + panelPitch * n
}
