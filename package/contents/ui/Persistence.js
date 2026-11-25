// Loading and saving of the layout file.
//
// The applet has no C++ part, so all file access goes through Plasma's
// "executable" data source. This module owns the two shell commands and the
// interpretation of their result, so the Runtime and the tests agree on:
//
//   * what a missing file is (a normal first run) and what a failure is
//     (an unreadable or malformed file that must never be overwritten),
//   * how a path is quoted for the shell (it may contain spaces or quotes),
//   * that a save creates the parent directory, writes to a temporary file and
//     renames it, so a half written file can never be read,
//   * that a pin is only allowed once the file state is known.
.pragma library

// State of the layout file.
var loading = "loading"
var missing = "missing"
var loaded = "loaded"
var error = "error"

// Exit code of the load command for "the file is not there".
var missingExitCode = 3

// Quote one shell word. Single quotes keep everything literal; an embedded
// quote is closed, escaped and reopened ('\'').
function shellQuote(value) {
    return "'" + String(value).replace(/'/g, "'\\''") + "'"
}

// Directory part of a path ("" when there is none).
function directoryOf(path) {
    var p = String(path)
    var i = p.lastIndexOf("/")
    return i > 0 ? p.substring(0, i) : ""
}

// Read the layout file. Exit code 3 means "not there"; every other non-zero
// code is a read failure, which the caller must not mistake for a first run.
function loadCommand(path) {
    var p = shellQuote(path)
    return "if [ ! -e " + p + " ]; then exit " + missingExitCode + "; fi\n"
           + "cat " + p
}

// Interpret the data source result of loadCommand().
// Returns { state, config, error }.
function parseLoad(data, path) {
    var result = { state: error, config: null, error: "" }
    if (!data || data["exit code"] === undefined) {
        result.error = "no result from the shell"
        return result
    }
    var code = Number(data["exit code"])
    if (code === missingExitCode) {
        result.state = missing
        return result
    }
    if (code !== 0) {
        var stderr = String(data.stderr || "").trim()
        result.error = stderr !== "" ? stderr : ("exit code " + code)
        return result
    }
    var text = String(data.stdout || "")
    if (text.trim() === "") {
        result.error = "the layout file is empty"
        return result
    }
    try {
        result.config = JSON.parse(text)
    } catch (e) {
        result.error = "cannot parse " + path + ": " + e
        return result
    }
    result.state = loaded
    return result
}

// A layout nothing has been pinned to yet. Callers run it through
// Edit.prepare() to add ids.
function emptyLayout() {
    return { version: 2, columns: [] }
}

// Write the layout file: create the parent directory, write a temporary file
// next to the target, then rename it into place. `set -e` stops the script
// before the rename if anything fails, so an existing layout is never
// replaced by a partial write.
function saveCommand(path, text) {
    var p = shellQuote(path)
    var temp = shellQuote(String(path) + ".tmp")
    var dir = directoryOf(path)
    var mkdir = dir !== "" ? "mkdir -p " + shellQuote(dir) + "\n" : ""
    return "set -e\n"
           + mkdir
           + "cat > " + temp + " <<'METROSTART_LAYOUT_EOF'\n"
           + String(text) + "\n"
           + "METROSTART_LAYOUT_EOF\n"
           + "mv " + temp + " " + p
}

// Interpret the data source result of saveCommand(): { ok, error }.
function parseSave(data) {
    if (!data || data["exit code"] === undefined)
        return { ok: false, error: "no result from the shell" }
    var code = Number(data["exit code"])
    if (code === 0)
        return { ok: true, error: "" }
    var stderr = String(data.stderr || "").trim()
    return { ok: false, error: stderr !== "" ? stderr : ("exit code " + code) }
}

// Whether the layout may be edited at all: while the file is still being read
// or unreadable, a pin would either be lost or overwrite unknown data.
function isEditable(state) {
    return state === loaded || state === missing
}

// The layout a pin starts from, or null when a pin must be refused.
//
//   * still loading, or the read failed -> null, never invent a layout,
//   * a layout is already there          -> that layout, untouched,
//   * the file is confirmed missing      -> `empty` (the first-run seed).
function pinBase(config, state, empty) {
    if (!isEditable(state))
        return null
    if (config !== null && config !== undefined)
        return config
    if (state === missing)
        return empty
    return null
}
