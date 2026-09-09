import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

// Headless half of the plugin: playback state, the source list, and the IPC
// surface the media keys talk to. Separate from the widget because a bar
// widget is instantiated once per monitor and an IpcHandler must register
// exactly once.
Item {
  id: root

  property var shell: null

  // Opening the picker is deliberately not handled here. A service is a
  // singleton but bar widgets are instantiated once per monitor, so a signal
  // from here would open a popup on every screen at once. The keybinding
  // calls `omarchy-shell shell toggle <plugin-id>` instead, which routes
  // through the bar to the widget on the focused monitor.

  readonly property var players: Mpris.players ? Mpris.players.values : []

  // cliamp publishes org.mpris.MediaPlayer2.cliamp with an Identity of
  // "Cliamp". Unlike a browser, which calls itself "Chrome" whatever it is
  // playing, that is unambiguous — this needs no heuristics at all.
  readonly property var player: {
    for (var i = 0; i < players.length; i++) {
      var candidate = players[i]
      if (candidate && String(candidate.dbusName || "").toLowerCase().indexOf("cliamp") >= 0)
        return candidate
    }
    return null
  }

  readonly property bool running: player !== null
  readonly property bool isPlaying: running && player.isPlaying
  readonly property string title: running ? (player.trackTitle || "") : ""
  readonly property string artist: running ? (player.trackArtist || "") : ""

  // cliamp puts the stream or file location in xesam:url, which is what lets
  // the picker highlight the source that is actually playing.
  readonly property string url: {
    if (!running || !player.metadata)
      return ""
    return String(player.metadata["xesam:url"] || "")
  }

  property var favorites: []
  property var playlists: []

  // cliamp's MPRIS interface errors on Shuffle and LoopStatus (Input/output
  // error), so these come from `cliamp status --json` instead. They are only
  // visible in the popup, so they are refreshed when it opens and after a
  // toggle rather than polled continuously.
  property bool shuffle: false
  property string repeat: "Off"

  // The station name is not in the MPRIS metadata, so it is recovered by
  // matching the playing URL against the favourites list. Cheaper and more
  // reactive than polling `cliamp status --json` on a timer.
  readonly property string station: {
    for (var i = 0; i < favorites.length; i++) {
      if (favorites[i].path === url && url !== "")
        return favorites[i].title
    }
    return ""
  }

  function isCurrent(path) {
    return path !== "" && path === url
  }

  // ------------------------------------------------------------- sources

  function applySources(text) {
    try {
      var parsed = JSON.parse(text || "{}")
      favorites = Array.isArray(parsed.favorites) ? parsed.favorites : []
      playlists = Array.isArray(parsed.playlists) ? parsed.playlists : []
    } catch (e) {
      console.warn("satal.cliamp: could not parse sources:", e)
    }
  }

  function refreshSources() {
    if (!sourcesProc.running)
      sourcesProc.running = true
  }

  function applyModes(text) {
    try {
      var parsed = JSON.parse(text || "{}")
      shuffle = parsed.shuffle === true
      repeat = String(parsed.repeat || "Off")
    } catch (e) {
      // cliamp not running: leave the last known values alone.
    }
  }

  function refreshModes() {
    if (!modesProc.running)
      modesProc.running = true
  }

  property Process modesProc: Process {
    command: ["omarchy-cliamp", "status"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyModes(text)
    }
  }

  // The toggle runs as a separate process, so the new state is not readable
  // the instant it returns.
  property Timer modeSettle: Timer {
    interval: 700
    onTriggered: root.refreshModes()
  }

  function toggleShuffle() {
    modeHelper.exec(["omarchy-cliamp", "shuffle", "toggle"])
    modeSettle.restart()
    return "ok"
  }

  function cycleRepeat() {
    modeHelper.exec(["omarchy-cliamp", "repeat", "cycle"])
    modeSettle.restart()
    return "ok"
  }

  // Kept separate from `helper` so a mode toggle never cancels an in-flight
  // source switch.
  property Process modeHelper: Process {
    id: modeHelper
    function exec(args) {
      running = false
      command = args
      running = true
    }
  }

  property Process sourcesProc: Process {
    command: ["omarchy-cliamp", "sources"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applySources(text)
    }
  }

  // Favouriting a stream inside the TUI rewrites this file, so watching it
  // keeps the picker current without the user reopening anything.
  property FileView favoritesFile: FileView {
    path: Quickshell.env("HOME") + "/.config/cliamp/favorites.toml"
    watchChanges: true
    printErrors: false
    onFileChanged: root.refreshSources()
  }

  Component.onCompleted: {
    refreshSources()
    refreshModes()
  }

  // Re-read the sources when cliamp starts or stops, since playlists only
  // exist as far as a running cliamp is concerned.
  onRunningChanged: {
    refreshSources()
    refreshModes()
  }

  // ------------------------------------------------------------- actions

  function canDo(action) {
    if (!running || !player.canControl)
      return false
    if (action === "next")
      return player.canGoNext
    if (action === "previous")
      return player.canGoPrevious
    return player.canTogglePlaying || player.canPlay || player.canPause
  }

  // MPRIS when cliamp is up, because it is instant and needs no process
  // spawn. The helper script only gets involved when there is nothing on the
  // bus to talk to — which is also the case where it has to start cliamp.
  function runAction(action) {
    if (running && canDo(action)) {
      if (action === "next")
        player.next()
      else if (action === "previous")
        player.previous()
      else if (action === "pause")
        player.pause()
      else
        player.togglePlaying()
      return "ok"
    }

    if (action === "playPause" || action === "play") {
      helper.exec(["omarchy-cliamp", "toggle"])
      return "starting"
    }
    return "not-running"
  }

  function playSource(path) {
    helper.exec(["omarchy-cliamp", "source", path])
    return "ok"
  }

  function playPlaylist(name) {
    helper.exec(["omarchy-cliamp", "playlist", name])
    return "ok"
  }

  function showWindow() {
    helper.exec(["omarchy-cliamp", "show"])
    return "ok"
  }

  // One reusable process. Starting cliamp can take seconds, so nothing here
  // waits on the result; the MPRIS bindings light up on their own when the
  // player appears.
  property Process helper: Process {
    id: helper
    function exec(args) {
      running = false
      command = args
      running = true
    }
  }

  function statusJson() {
    return JSON.stringify({
      running: running,
      playing: isPlaying,
      title: title,
      artist: artist,
      station: station,
      url: url,
      shuffle: shuffle,
      repeat: repeat,
      favorites: favorites.length,
      playlists: playlists.length
    })
  }

  IpcHandler {
    target: "cliamp"

    function status(): string { return root.statusJson() }
    function playPause(): string { return root.runAction("playPause") }
    function pause(): string { return root.runAction("pause") }
    function next(): string { return root.runAction("next") }
    function previous(): string { return root.runAction("previous") }
    function window(): string { return root.showWindow() }
    function refresh(): string { root.refreshSources(); root.refreshModes(); return "ok" }
    function shuffle(): string { return root.toggleShuffle() }
    function repeat(): string { return root.cycleRepeat() }
  }
}
