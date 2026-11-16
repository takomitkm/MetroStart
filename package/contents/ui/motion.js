// Motion constants copied from the reference recordings.
//
// Motion constants fitted against screenshots/windows-reference/videos/
// menu_open_close.mp4 (2560x1440, 60 fps) with dev/tools/compare_model.py.
//
// The wallpaper + backdrop and the sidebar only fade: they never scale, on
// open or on close. Only the tiles animate, each row on its own timeline
// (bottom rows first) and every tile scaling about the screen centre.
//
// Backdrop: measured on a wallpaper-only region (no content): alpha 0.089 at
// frame 7 rising to 1.0 at frame 23 -> linear, ~255 ms.
var fadeOpenDuration = 255
var fadeCloseDuration = 225
var closeDelay = 30
// The menu content fades in after the backdrop and takes a little longer.
var contentFadeDelay = 0
var contentFadeDuration = 255
// Tiles: per-row scale + fade, bottom rows first. Each row animates inside its
// own window (TilesView.entranceRowWindow), so the rows also finish at
// different times instead of stopping together.
var tileEntranceDelay = 0
var tileEntranceDuration = 560

// Switching between the pinned tiles and the all applications list, fitted
// against switch_app_tile.mp4 (2560x1440, 60 fps, the switches are at frames
// 196 and 410). The reference swaps on a single frame: the outgoing view is
// gone and all that is left is the empty surface (the acrylic itself stays,
// only the tiles were darkening it). The incoming items are then pushed up
// from below while they fade in, and they are settled ~20 frames later.
//
// Every row runs the same curve; the *distance* grows with the row's height on
// screen (measured 48 px at the top of the stack, ~105 px at the bottom), which
// is what reads as the whole stack being pushed up. The lower rows therefore
// still creep while the top ones have settled, which is the "top rows first,
// bottom rows last" of the reference. The fade runs on a separate, much more
// staggered timeline than the travel: see switchFade().
var switchDuration = 333
var switchStagger = 0.03      // share of the timeline the bottom row lags the top by
var switchWindow = 0.98       // each row animates inside this share of the timeline
var switchCurve = 5           // ease-out power: fast in, slow settle
var switchRiseBase = 40       // px of downward offset at y = 0
var switchRiseSlope = 0.05    // extra px per px of y
// The fade is *not* uniform and is not tied to the travel: measured per row it
// starts ~1 frame after the switch at the top of the stack and reaches the
// bottom row ~4 frames later, each row then taking ~6 frames to come up. So the
// top rows are already solid while the bottom ones are still invisible
// (reference frame 201: 0.75 at the top, 0.00 at the bottom). `switchFade*` are
// shares of the timeline, the stagger spreads over the content, not the screen.
var switchFadeDelay = 0.05
var switchFadeStagger = 0.2
var switchFadeWindow = 0.40
var switchFadeCurve = 1

function clamp01(v) {
    return v < 0 ? 0 : (v > 1 ? 1 : v)
}

function switchEase(p) {
    return 1 - Math.pow(1 - clamp01(p), switchCurve)
}

// Position of a row inside the switch timeline, 0 = not moving yet, 1 = done.
// `bottom` is the y of the lowest row, so rank 0 is the top of the stack.
function switchRowProgress(timeline, y, bottom) {
    const rank = bottom > 0 ? clamp01(y / bottom) : 0
    return clamp01((timeline - rank * switchStagger) / switchWindow)
}

// Downward offset of a row: it starts below its final position and is pushed up.
function switchRise(timeline, y, bottom) {
    if (timeline >= 1)
        return 0
    const p = switchRowProgress(timeline, y, bottom)
    return (switchRiseBase + switchRiseSlope * y) * (1 - switchEase(p))
}

// Fade-in of a row. It runs on its own, staggered timeline: the top row is
// almost solid while the bottom one has not started yet. `top`/`bottom` are the
// extent of the incoming content (rank 0 = its first row).
function switchFade(timeline, y, top, bottom) {
    if (timeline >= 1)
        return 1
    const span = bottom - top
    const rank = span > 0 ? clamp01((y - top) / span) : 0
    const p = clamp01((timeline - (switchFadeDelay + rank * switchFadeStagger)) / switchFadeWindow)
    return 1 - Math.pow(1 - p, switchFadeCurve)
}
