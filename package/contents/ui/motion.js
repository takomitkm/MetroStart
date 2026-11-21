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

// Windowed (non-fullscreen) Start: the whole panel scales up from the bottom
// left corner while fading in. Measured on non-fullscreen-open-close.mp4:
// the panel top edge travels 153 -> 78 in ~15 frames (250 ms) and the scale
// decays very fast at the start (about 78 % of the remaining distance per
// frame), i.e. an aggressive ease-out.
var compactOpenDuration = 420          // the push keeps gliding until the end
var compactOpenFadeDuration = 60       // its opacity is ~1 after ~3 frames
// While it fades the backdrop also grows upwards (it is anchored on the
// taskbar), which the recording shows over the same first frames.
// Fitted to the measured top edge of the backdrop (rmse 0.4 px):
// 106 -> 97 -> 87 -> 83 -> 80 -> 79 at 67/100/167/233/300/400 ms.
var compactPanelScaleFrom = 0.956
var compactOpenExpandDuration = 460
var compactRiseBase = 140       // px of downward offset at y = 0
var compactRiseSlope = 0.05    // extra px per px of y
var compactRiseStagger = 0.12  // share of the timeline the bottom row lags by
var compactRiseWindow = 0.88
var compactRiseCurve = 2
// Exponential ease-out: the remaining distance decays like exp(-k * p), i.e.
// the motion keeps slowing down instead of stopping abruptly.
var compactRiseK = 3.6      // exponential decay: long tail, never stops early
var compactFadeK = 2.2          // opacity: fast in, no tail
var compactExpandK = 4.9        // the top edge keeps travelling the whole time
// Exponential ease-out on 0..1: fast at the start, then a long tail.
function expoEase(k, p) {
    const x = clamp01(p)
    return 1 - (Math.exp(-k * x) - Math.exp(-k)) / (1 - Math.exp(-k))
}

// Per-row rise of the windowed Start. Same idea as switchRise (rows start
// below and are pushed up, staggered by y) but the easing is much gentler so
// the movement is visible for the whole animation instead of the first frames.
function compactRise(timeline, y, bottom) {
    if (timeline >= 1)
        return 0
    const rank = bottom > 0 ? clamp01(y / bottom) : 0
    const p = clamp01((timeline - rank * compactRiseStagger) / compactRiseWindow)
    // 1 at p = 0 and 0 at p = 1, but the remaining distance decays
    // exponentially, so the last part of the move is a long slow glide.
    return (compactRiseBase + compactRiseSlope * y) * (1 - expoEase(compactRiseK, p))
}
// The recording shows the windowed menu closing almost instantly (the content
// is gone within two frames), so the close is a short fade with no scale.
var compactCloseDuration = 80
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

// Value of a cubic bezier easing curve at x (0..1). Qt drops
// `easing.bezierCurve` in this version (the list arrives empty and the
// animation falls back to linear), so curves are evaluated here and the
// animations only run a linear clock.
function bezierValue(curve, x) {
    if (!curve || curve.length < 4 || x <= 0)
        return 0
    if (x >= 1)
        return 1
    const x1 = curve[0], y1 = curve[1], x2 = curve[2], y2 = curve[3]
    let lo = 0, hi = 1, t = 0.5
    for (let i = 0; i < 20; ++i) {
        t = (lo + hi) / 2
        const bx = 3 * (1 - t) * (1 - t) * t * x1 + 3 * (1 - t) * t * t * x2 + t * t * t
        if (bx < x)
            lo = t
        else
            hi = t
    }
    t = (lo + hi) / 2
    return 3 * (1 - t) * (1 - t) * t * y1 + 3 * (1 - t) * t * t * y2 + t * t * t
}


// ---------------------------------------------------------------------------
// Live tile content swap (Square Home 4.1.5, faithful "D1" easing).
//
// 12 variants: 0..3 slide in from bottom/left/right/top, 4..7 flip 90 degrees
// about the centre (X/Y axis, both directions), 8..11 flip about an edge with a
// half-tile slide. Timings come from the APK (2000 ms per swap, phases of
// 1000 ms) and Android's interpolators: Accelerate(factor) = t^(2*factor),
// Decelerate(factor) = 1-(1-t)^(2*factor), Overshoot(tension 2).
function tileAccel(t, factor) { return Math.pow(Math.max(0, t), factor * 2) }
function tileDecel(t, factor) { return 1 - Math.pow(1 - Math.min(1, t), factor * 2) }
function tileOvershoot(t) {
    var u = Math.max(0, Math.min(1, t)) - 1
    return u * u * ((2 + 1) * u + 2) + 1
}

// Angle of a flip: phase 1 rotates 0 -> ±90 (accel 4), phase 2 comes back
// from ∓90 -> 0 with an overshoot.
function tileFlipAngle(timeline, sign) {
    if (timeline < 0.5)
        return sign * 90 * tileAccel(timeline * 2, 4)
    return sign * (-90 + 90 * tileOvershoot((timeline - 0.5) * 2))
}

// Scale of the flipping content: 1 -> 0.85 (accel 3), then 0.85 -> 1 (decel 3).
function tileFlipScale(timeline) {
    if (timeline < 0.5)
        return 1 - 0.15 * tileAccel(timeline * 2, 3)
    return 0.85 + 0.15 * tileDecel((timeline - 0.5) * 2, 3)
}

// Offset of a slide-in variant, in pixels, at timeline 0..1.
function tileSlideOffset(timeline, extent) {
    var d = Math.atan(Math.min(1, timeline) * 15 - 7.5) / 2.9 + 0.5
    return (1 - d) * extent
}

// Variant parity: wide tiles flip vertically, tall tiles horizontally, so the
// animation always runs along the tile's long axis (as Square Home does).
function tileVariant(index, width, height, advanced) {
    // 4 slides, or 12 variants (4 slides + 4 centre flips + 4 edge flips).
    var count = advanced ? 12 : 4
    var v = index % count
    if (!advanced)
        return v
    // A flip's axis follows the tile shape: wide tiles turn about the horizontal
    // axis (even variants), tall ones about the vertical axis (odd). Slides are
    // left alone so 0..3 always stay slides.
    if (v >= 4 && v < 8) {
        var odd = (v % 2 === 1)
        if (height >= 2 * width && !odd)
            v += 1
        else if (width >= 2 * height && odd)
            v -= 1
    }
    return v
}


// 0..1 progress of Square Home's atan slide curve (used by the tile cycle).
function tileSlideProgress(t) {
    var u = Math.max(0, Math.min(1, t))
    return Math.atan(u * 15 - 7.5) / 2.9 + 0.5
}
