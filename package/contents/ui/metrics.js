// Geometry, colours and typography of the Windows 10 style Start menu.
// Design constants of the Windows 10 style menu (reference: 2560x1440 at scale 1.0)
// and cross-checked against ExplorerPatcher / ep_starttiledata constants.
.pragma library

var cell = 90
var gap = 6
var pitch = 96
var groupWidth = 570
var groupGapX = 205
var groupGapY = 96

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

// Sidebar
var sidebarCollapsedWidth = 76
var sidebarExpandedWidth = 386
var sidebarAccentWidth = 6
var sidebarAccentColor = "#6C91B5"
var sidebarItemHeight = 72
var sidebarItemsTop = 78
var sidebarHeaderHeight = 78
var sidebarUserY = 1236
var sidebarUserHeight = 70
var sidebarPowerY = 1306
var sidebarPowerHeight = 74
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
