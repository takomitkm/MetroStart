// Geometry, colours and typography of the Windows 10 style Start menu.
// Design constants of the Windows 10 style menu (reference: 2560x1440 at scale 1.0)
// and cross-checked against ExplorerPatcher / ep_starttiledata constants.
.pragma library

var cell = 90
var gap = 6
var pitch = 96

// Group layout, see the flow in Layout.js. Groups are arranged in columns
// inside a canvas of fixed width: a group is at least three 2x2 tiles (six
// cells) wide, neighbouring groups keep a 205 px horizontal gap, and two
// groups stacked in one column keep 102 px between their tile areas (measured
// on the reference: 831-729, 927-825, 1023-921). That gap holds the 57 px title
// block of the lower group, so the group boxes themselves are 45 px apart; a
// group without a title reserves the same block, which keeps the rhythm. The
// row of columns is centred (3 x 570 + 2 x 205 = 2120 leaves 220 on both
// sides) and the first tile row starts at 159.
var groupMinCells = 6
var groupGapX = 205
var groupGapY = 102
var groupHeader = 57
var groupsTop = 159
// Reordering a group (drag and drop) glides every tile and title to its new
// cell; all of them move at the same time (measured on the reference video).
var reflowDuration = 180
// Accent colour used by the native shell (SystemAccentColor). It is
// configurable in the applet settings; this is the value of the reference
// capture and the fallback when no configuration is loaded.
var accentColorDefault = "#4A78A4"
// While a tile is dragged everything else fades back and no tile draws a
// reveal border. Native: ListViewItemPresenter's Reordering state fades the
// other items to ListViewItemReorderThemeOpacity (0.8) over 0.240 s and the
// drag visual itself sits at ListViewItemDragThemeOpacity (0.8).
var dragDim = 0.8
var dragTileOpacity = 0.8
// While a tile is held every other tile recedes towards its own centre (the
// reference pulls the tiles in a little and lets them grow back on drop).
var dragShrink = 0.97
// Both the fade and the shrink run with the native reorder storyboard (0.240 s).
var dragShrinkDuration = 240
var dragDimDuration = 240

// Group dragging (screenshots in group_tile/). The title block is the grab
// area: it starts 90 px above the group's tiles and is 84 px tall; hovering it
// shows the two-line handle on the right, pressing turns it into the accent bar.
var groupTitleBlockTop = -90
var groupTitleBlockHeight = 84
var groupHandleWidth = 24
var groupHandleRight = 25
var groupHandleGap = 4
// While a group is dragged it collapses to a placeholder bar inside its title
// block (48 px tall, 6 px above the tiles) and the same bar marks the drop
// position (measured: 570 x 48, accent at ~40-50 %).
var groupPlaceholderHeight = 48
var groupPlaceholderInset = 6
// TileGrid_GroupIndicatorTemplate: SystemAccentColor, no stroke, Opacity 0.5.
var groupPlaceholderOpacity = 0.5
// InteractionState_Drag: accent fill with Opacity 0.8.
var groupGhostOpacity = 0.8
// InteractionState_Pressed moves the title by Metrics_GroupHeader_TextBlockMargin
// (8,0,0,0).
var groupTitlePressInset = 8


// Dragging near an edge of the tile area scrolls it: the margin where the
// auto scroll starts and how far one 16 ms tick moves it (faster the closer
// the pointer is to the edge).
var dragAutoScrollMargin = 90
var dragAutoScrollStep = 22
// Breathing room below the last group: the tile area scrolls this far past the
// last tiles, so they do not end flush with the bottom edge (45 = the gap
// between two group boxes, i.e. groupGapY without the title block).
var groupsBottom = 45

var backdropColor = "#2A2A2A"
var backdropOpacity = 0.8

var tileFill = "#FFFFFF"
var tileFillOpacity = 0.10

var fontFamily = "Noto Sans"

var labelSize = 17
var labelX = 12
var labelBaseline = 173
var labelLineGap = 23

var groupTitleSize = 20
var groupTitleOffsetY = -42

// Sidebar. Every button is a 72 x 72 box with the 2 px reveal frame inside it;
// they are stacked without gaps, so two neighbouring frames add up to 4 px. The
// rail is 72 wide and the hamburger button starts 6 px below the top edge.
var sidebarCollapsedWidth = 72
var sidebarExpandedWidth = 386
var sidebarAccentWidth = 6
var sidebarAccentColor = "#6C91B5"
var sidebarItemHeight = 72
var sidebarItemsTop = 78
var sidebarHeaderTop = 6
var sidebarHeaderHeight = 72
var sidebarBorderWidth = 2
// The reveal frame is not a hover effect: it is lit by the pointer distance
// alone, identical whether the button is hovered or only nearby. Fitted on the
// reference: the light fades to nothing ~106 px away and its brightest point is
// a little brighter than the hover fill.
var sidebarBorderPeak = 0.27
var sidebarBorderRadius = 106
// The two bottom buttons are 72 tall as well: 1236 + 72 + 72 = 1380, the menu
// height, so the power button ends exactly on the bottom edge.
var sidebarUserY = 1236
var sidebarUserHeight = 72
var sidebarPowerY = 1308
var sidebarPowerHeight = 72
var sidebarTitleSize = 24
var sidebarItemSize = 23
var sidebarSelectedColor = "#B8D6E8"
var sidebarItemColor = "#9FB6C4"
var sidebarPanelColor = "#222222"

// Application list
var appTop = 48
// Letter block: 130 x 66, ending where the first item column starts (766). The
// glyph is centred in it: ink 691-707 x 173-191 inside the 150-215 row.
var appLetterX = 691
var appLetterCellX = 636
var appLetterCellWidth = 130
var appLetterSize = 26
// Icons, not item frames: a frame starts appItemInsetX before its icon and is
// appItemWidth wide, so the icon keeps a 13 px inset on the left and 15 px on
// the right, and neighbouring frames leave a 2 px gap (as in the reference).
var appColumns = [779, 1145, 1513]
var appItemInsetX = 13
var appItemWidth = 364
var appItemIconX = 13
// Reveal frame of list entries and letter blocks: 2 px, one thinner than the
// 3 px frame the tiles use (fitted on all applications.png). Like the tiles it
// keeps a wide falloff (170 px), so the frame is visible around the whole
// control while it is hovered.
var appBorderWidth = 2
var appBorderRadius = 170
var appBorderPeak = 0.18
var appIconSize = 48
var appRowPitch = 66
// Name offset from the item frame (icon inset 13 + 63 from the icon).
var appNameOffsetX = 76
var appNameSize = 21

// Flyouts
var menuPanelColor = "#232323"
var menuItemSize = 19
var menuItemHeight = 49
// Vertical offset from an ink box top to the corresponding Text item top.
var titleInkOffset = 5
var appNameInkOffset = 5
var letterInkOffset = 6
var menuItemInkOffset = 5

// The reference renders CJK label glyphs 1 px higher and 1 px wider per glyph
// than the Latin text of the same nominal size.
var cjkBaselineShift = 1
var cjkLetterSpacing = 1

var appSectionGap = 48

// Sidebar acrylic: the menu content behind the panel is captured at 1/downscale
// resolution and blurred, then tinted by the panel colour.
var sidebarBlurDownscale = 10
// Hover highlight transition (~45 ms ease-out).
var hoverDuration = 45
// Press (fitted against long_press_tile.mp4): the pointer-driven reveal turns
// into a flat frame, the surface is inset by the frame width and a ripple
// blooms out of the press point over ~250 ms.
var pressInDuration = 70
var pressOutDuration = 110
// Pressed look: the bright hover frame drops to the faint searchlight shade of
// an untouched tile (same width, pointer falloff), and the control shrinks a
// couple of percent (see RevealRect / Tile).
var pressFramePeak = 0.12
// Ripple: a soft glow that keeps growing out of the press point. While the
// button is held it crawls (measured: it is still spreading after 0.8 s); on
// release it blooms out fast and fades. It grows while it fades, so the older
// part of the wave is dimmer than the front.
var pressRippleStrength = 0.16
// The press starts with a ripple already covering about a quarter of the
// control and it fills the control while the button is held.
var pressRippleStart = 0.40
var pressRippleHoldEnd = 1.0
var pressRippleReleaseEnd = 1.2
var pressRippleHoldDuration = 1600
// Releasing throws the wave across the whole control in ~10 frames (167 ms) and
// it only fades after it has arrived.
var pressRippleReleaseDuration = 167
var pressRippleHoldFadeDelay = 110
var pressRippleFadeDuration = 420
var pressScale = 0.03
// Sidebar auto-expand: rest still on one button for this long, then the panel
// opens over sidebarOpenDuration (movement resets the dwell, see MetroMenu).
var sidebarHoverDelay = 500
// Hover-open and switch-collapse, both read by Sidebar.qml (keep the pair
// together: dropping one makes the panel's Behavior log "assign undefined").
var sidebarOpenDuration = 250
var sidebarCloseDuration = 150
var sidebarBlurMax = 96
var sidebarBlurAmount = 1.0
// The reference acrylic is noticeably more colourful than a plain blur.
var sidebarBlurSaturation = 1.0
var sidebarBlurBrightness = 0.0
// The reference acrylic has a little more contrast than a plain blur.
var sidebarBlurContrast = 0.0
// Fine grain over the acrylic, as in the reference capture.
var sidebarNoiseOpacity = 0.06

// Capital view transition (app_list_capital_view.mp4): clicking the letter
// column shrinks the list to 0.55 while it fades out and brings the letter grid
// in from 1.8 about its own centre; the reverse click plays it backwards. Both
// scales take 400 ms with an OutCubic curve (fitted rms 0.016 / 0.037), the
// cross fade overlaps: the arriving layer is done in 180 ms, the leaving one
// in 250 ms.
var capitalScaleDuration = 400
// Arriving view fades in over 180 ms (OutQuad), the leaving one clears over
// 250 ms: at 67 ms the reference still shows both at ~2/3 opacity.
var capitalFadeInDuration = 180
var capitalFadeOutDuration = 250
var capitalListScale = 0.55
var capitalGridScale = 1.8

// Capital view (letter grid shown after clicking the letter column).
// Cell 90 on a 96 pitch, grid 4 x 8, centred in the menu.
var capitalCell = 90
var capitalPitch = 96
var capitalColumns = 4
var capitalRows = 8
var capitalOriginX = 1124
var capitalOriginY = 306
var capitalLetterSize = 36
var capitalIconSize = 47
// Ink-box centre sits 1 px below the cell centre.
var capitalInkOffset = 3
