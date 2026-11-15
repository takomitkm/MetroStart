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