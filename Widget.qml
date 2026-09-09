import QtQuick
import Quickshell
import qs.Ui
import qs.Commons

// Icon-only bar presence with a popup holding the transport and a picker for
// favourite streams and local playlists. Unlike a browser-based player,
// cliamp may not be running at all, so the icon is always present: it is the
// way to start music, not just to control it.
BarWidget {
  id: root
  moduleName: "satal.cliamp"

  readonly property var service: bar && bar.shell ? bar.shell.serviceFor("satal.cliamp") : null

  readonly property bool running: service ? service.running : false
  readonly property bool playing: service ? service.isPlaying : false
  readonly property string title: service ? service.title : ""
  readonly property string artist: service ? service.artist : ""
  readonly property string station: service ? service.station : ""
  readonly property var favorites: service ? service.favorites : []
  readonly property var playlists: service ? service.playlists : []
  readonly property bool shuffleOn: service ? service.shuffle : false
  readonly property string repeatMode: service ? service.repeat : "Off"

  property bool popupOpen: false

  // The shortcuts are worth having but not worth permanent space, so they
  // take over the picker's area rather than making the popup taller.
  property bool showHelp: false

  readonly property var globalHelp: [
    { keys: "Super+Alt+M", action: "Open this picker" },
    { keys: "Super+Shift+Alt+M", action: "Open the cliamp TUI" },
    { keys: "Play / Pause", action: "Play / pause, starts cliamp" },
    { keys: "Next / Prev", action: "Skip track" }
  ]

  readonly property var keyHelp: [
    { keys: "1 – 9", action: "Play that numbered source" },
    { keys: "0", action: "Open cliamp" },
    { keys: "↑ ↓", action: "Move selection" },
    { keys: "⏎", action: "Play selected" },
    { keys: "← →", action: "Previous / next track" },
    { keys: "s", action: "Shuffle" },
    { keys: "r", action: "Repeat: off / all / one" },
    { keys: "p", action: "Play / pause" },
    { keys: "?", action: "This help" },
    { keys: "esc", action: "Close" }
  ]

  readonly property var mouseHelp: [
    { keys: "click", action: "Open this picker" },
    { keys: "middle", action: "Play / pause" },
    { keys: "right", action: "Next track" },
    { keys: "scroll", action: "Previous / next track" }
  ]

  // Keyboard selection. The cursor stays hidden until an arrow key is
  // pressed, so opening the popup with the mouse does not paint a selection
  // the user did not ask for.
  property bool cursorActive: false
  property int cursorIndex: 0

  // Index ranges for the flat, keyboard-navigable list. Favourites first,
  // then playlists, then the row that opens cliamp itself.
  readonly property int playlistOffset: favorites.length
  readonly property int windowIndex: favorites.length + playlists.length
  readonly property int itemCount: windowIndex + 1

  function close() { popupOpen = false }

  function openPopup() {
    if (service) {
      service.refreshSources()
      service.refreshModes()
    }
    cursorActive = false
    cursorIndex = 0
    showHelp = false
    popupOpen = true
  }

  function togglePopup() {
    if (popupOpen) popupOpen = false
    else openPopup()
  }

  function act(action) {
    if (service)
      service.runAction(action)
  }

  function moveCursor(delta) {
    // The first arrow press reveals the cursor where it already is rather
    // than jumping a row, matching how Omarchy's own panels behave.
    if (!cursorActive) {
      cursorActive = true
      return
    }
    if (itemCount < 1)
      return
    cursorIndex = (cursorIndex + delta + itemCount) % itemCount
  }

  // Sources are numbered 1-9 in the order they appear. "Open cliamp" is a
  // fixed action rather than a source, so it keeps a fixed key of its own and
  // does not shift as favourites and playlists come and go.
  function shortcutFor(index) {
    if (index === windowIndex)
      return "0"
    return index < 9 ? String(index + 1) : ""
  }

  function activateShortcut(digit) {
    if (digit === "0") {
      activateIndex(windowIndex)
      return
    }
    var index = parseInt(digit, 10) - 1
    if (index >= 0 && index < windowIndex)
      activateIndex(index)
  }

  function activateIndex(index) {
    if (!service)
      return
    if (index < playlistOffset) {
      service.playSource(favorites[index].path)
    } else if (index < windowIndex) {
      service.playPlaylist(playlists[index - playlistOffset].name)
    } else {
      service.showWindow()
    }
    popupOpen = false
  }

  readonly property string tooltip: {
    if (!running)
      return "cliamp — not running"
    if (title === "")
      return "cliamp"
    return artist === "" ? title : title + " — " + artist
  }

  readonly property string repeatGlyph: {
    if (repeatMode === "All") return "󰑖"
    if (repeatMode === "One") return "󰑘"
    return "󰑗"
  }

  Connections {
    target: root.service
    function onPopupToggleRequested() { root.togglePopup() }
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar

    // Playing and paused read as state; a music note means cliamp is not
    // running and the popup is where you start it.
    text: !root.running ? "󰝚" : (root.playing ? "󰐊" : "󰏤")
    dimmed: !root.playing
    tooltipText: root.popupOpen ? "" : root.tooltip

    onPressed: function(b) {
      if (b === Qt.MiddleButton)
        root.act("playPause")
      else if (b === Qt.RightButton)
        root.act("next")
      else
        root.togglePopup()
    }

    onWheelMoved: function(delta) {
      root.act(delta > 0 ? "previous" : "next")
    }
  }

  // KeyboardPanel rather than PopupCard: it primes layer-shell keyboard
  // focus, which an xdg-popup does not get, so the picker can be driven
  // entirely from the keyboard after SUPER+ALT+M.
  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.popupOpen
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(root.showHelp ? 350 : 300))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent

      onMoveRequested: function(dx, dy) {
        if (dy !== 0) {
          // Reaching for the list is a clear signal the help has been read.
          root.showHelp = false
          root.moveCursor(dy)
        } else if (dx > 0) {
          root.act("next")
        } else if (dx < 0) {
          root.act("previous")
        }
      }
      onActivateRequested: if (root.cursorActive && !root.showHelp) root.activateIndex(root.cursorIndex)
      onCloseRequested: {
        if (root.showHelp) root.showHelp = false
        else root.close()
      }
      onTextKey: function(t) {
        if (t >= "0" && t <= "9") root.activateShortcut(t)
        else if (t === "?") root.showHelp = !root.showHelp
        else if (t === "s" && root.service) root.service.toggleShuffle()
        else if (t === "r" && root.service) root.service.cycleRepeat()
        else if (t === "p") root.act("playPause")
      }

      // Sits above the content in the corner, so it costs no layout height.
      Button {
        anchors.top: parent.top
        anchors.right: parent.right
        z: 10
        iconText: root.showHelp ? "󰅖" : "󰋗"
        tooltipText: root.showHelp ? "Back to sources" : "Keyboard shortcuts (?)"
        foreground: root.bar.foreground
        horizontalPadding: Style.space(4)
        verticalPadding: Style.space(2)
        iconSize: Style.font.bodySmall
        opacity: root.showHelp ? 1.0 : 0.5
        onClicked: root.showHelp = !root.showHelp
      }

      Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(10)

        // ------------------------------------------------- now playing

        Row {
          width: parent.width
          spacing: Style.space(10)

          // cliamp publishes no artwork in its MPRIS metadata, so a glyph
          // stands in rather than an empty frame.
          BorderSurface {
            width: Style.space(52)
            height: Style.space(52)
            radius: Style.spacing.labelGap
            color: Style.normalFillFor(root.bar.foreground, Color.accent)
            borderSpec: Border.controlSpec("normal", root.bar.foreground, Color.accent)

            Text {
              anchors.centerIn: parent
              text: root.playing ? "󰝚" : "󰝛"
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.display
            }
          }

          Column {
            // Narrowed so the title never runs under the help button.
            width: parent.width - Style.space(62) - Style.space(22)
            spacing: Style.space(3)

            Text {
              textFormat: Text.PlainText
              width: parent.width
              text: root.running ? (root.title || "Nothing playing") : "cliamp is not running"
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.subtitle
              font.bold: true
              elide: Text.ElideRight
              maximumLineCount: 2
              wrapMode: Text.WordWrap
            }

            Text {
              textFormat: Text.PlainText
              width: parent.width
              text: root.artist
              color: Qt.darker(root.bar.foreground, 1.3)
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.bodySmall
              elide: Text.ElideRight
              visible: text !== ""
            }

            Text {
              textFormat: Text.PlainText
              width: parent.width
              text: root.station
              color: Qt.darker(root.bar.foreground, 1.6)
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
              visible: text !== ""
            }
          }
        }

        // --------------------------------------------------- transport

        Row {
          anchors.horizontalCenter: parent.horizontalCenter
          spacing: Style.space(4)

          Button {
            iconText: "󰒝"
            tooltipText: "Shuffle (s)"
            foreground: root.bar.foreground
            horizontalPadding: Style.spacing.controlPaddingX
            verticalPadding: Style.spacing.controlPaddingY
            opacity: root.shuffleOn ? 1.0 : 0.4
            onClicked: if (root.service) root.service.toggleShuffle()
          }

          Button {
            iconText: "󰒮"
            foreground: root.bar.foreground
            horizontalPadding: Style.spacing.controlPaddingX
            verticalPadding: Style.spacing.controlPaddingY
            enabled: root.service ? root.service.canDo("previous") : false
            opacity: enabled ? 1.0 : 0.4
            onClicked: root.act("previous")
          }

          Button {
            iconText: root.playing ? "󰏤" : "󰐊"
            foreground: root.bar.foreground
            horizontalPadding: Style.spacing.panelGap
            verticalPadding: Style.spacing.controlPaddingY
            iconSize: Style.font.iconLarge
            onClicked: root.act("playPause")
          }

          Button {
            iconText: "󰒭"
            foreground: root.bar.foreground
            horizontalPadding: Style.spacing.controlPaddingX
            verticalPadding: Style.spacing.controlPaddingY
            enabled: root.service ? root.service.canDo("next") : false
            opacity: enabled ? 1.0 : 0.4
            onClicked: root.act("next")
          }

          Button {
            iconText: root.repeatGlyph
            tooltipText: "Repeat: " + root.repeatMode + " (r)"
            foreground: root.bar.foreground
            horizontalPadding: Style.spacing.controlPaddingX
            verticalPadding: Style.spacing.controlPaddingY
            opacity: root.repeatMode === "Off" ? 0.4 : 1.0
            onClicked: if (root.service) root.service.cycleRepeat()
          }
        }

        PanelSeparator { foreground: root.bar.foreground }

        // -------------------------------------------------------- help

        Column {
          id: helpBlock
          width: parent.width
          spacing: Style.space(2)
          visible: root.showHelp

          Repeater {
            model: [
              { heading: "ANYWHERE", rows: root.globalHelp },
              { heading: "IN THIS POPUP", rows: root.keyHelp },
              { heading: "ON THE BAR ICON", rows: root.mouseHelp }
            ]

            Column {
              required property var modelData
              width: helpBlock.width
              spacing: Style.space(2)

              Text {
                text: parent.modelData.heading
                color: Qt.darker(root.bar.foreground, 1.8)
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.caption
                topPadding: Style.space(6)
                bottomPadding: Style.space(2)
              }

              Repeater {
                model: parent.modelData.rows

                Row {
                  required property var modelData
                  width: helpBlock.width
                  spacing: Style.space(8)

                  // Key caps are right-aligned in a fixed column so the
                  // action text lines up regardless of key length.
                  Text {
                    textFormat: Text.PlainText
                    width: Style.space(112)
                    horizontalAlignment: Text.AlignRight
                    text: parent.modelData.keys
                    color: root.bar.foreground
                    font.family: root.bar.fontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    elide: Text.ElideLeft
                  }

                  Text {
                    textFormat: Text.PlainText
                    width: helpBlock.width - Style.space(120)
                    text: parent.modelData.action
                    color: Qt.darker(root.bar.foreground, 1.4)
                    font.family: root.bar.fontFamily
                    font.pixelSize: Style.font.caption
                    elide: Text.ElideRight
                  }
                }
              }
            }
          }
        }

        // ------------------------------------------------ source picker

        Column {
          id: sourceList
          width: parent.width
          spacing: Style.space(3)
          visible: !root.showHelp

          Text {
            text: "FAVOURITES"
            color: Qt.darker(root.bar.foreground, 1.8)
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.caption
            visible: root.favorites.length > 0
            bottomPadding: Style.space(2)
          }

          Repeater {
            model: root.favorites

            SourceRow {
              required property var modelData
              required property int index

              width: sourceList.width
              bar: root.bar
              label: modelData.title
              detail: modelData.realtime ? "Stream" : ""
              glyph: modelData.realtime ? "󰐹" : "󰎈"
              playing: root.service ? root.service.isCurrent(modelData.path) : false
              cursored: root.cursorActive && root.cursorIndex === index
              shortcut: root.shortcutFor(index)
              onActivated: root.activateIndex(index)
              onHovered: root.cursorActive = false
            }
          }

          Text {
            text: "PLAYLISTS"
            color: Qt.darker(root.bar.foreground, 1.8)
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.caption
            visible: root.playlists.length > 0
            topPadding: Style.space(6)
            bottomPadding: Style.space(2)
          }

          Repeater {
            model: root.playlists

            SourceRow {
              required property var modelData
              required property int index

              width: sourceList.width
              bar: root.bar
              label: modelData.name
              detail: modelData.count + (modelData.count === 1 ? " track" : " tracks")
              glyph: "󰲸"
              playing: false
              cursored: root.cursorActive && root.cursorIndex === root.playlistOffset + index
              shortcut: root.shortcutFor(root.playlistOffset + index)
              onActivated: root.activateIndex(root.playlistOffset + index)
              onHovered: root.cursorActive = false
            }
          }
        }

        // Hidden alongside the row it divides, or it dangles under the help.
        PanelSeparator {
          foreground: root.bar.foreground
          visible: !root.showHelp
        }

        SourceRow {
          width: parent.width
          visible: !root.showHelp
          bar: root.bar
          label: root.running ? "Open cliamp" : "Start cliamp"
          glyph: "󰆍"
          playing: false
          cursored: root.cursorActive && root.cursorIndex === root.windowIndex
          shortcut: root.shortcutFor(root.windowIndex)
          onActivated: root.activateIndex(root.windowIndex)
          onHovered: root.cursorActive = false
        }
      }
    }
  }
}
