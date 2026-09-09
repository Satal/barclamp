import QtQuick
import qs.Ui
import qs.Commons

// One clickable row in the source picker. Extracted because favourites,
// playlists and the "open cliamp" action render identically and differ only
// in what they do.
//
// Two highlights that mean different things: `playing` is the source you are
// listening to, `cursored` is where the keyboard cursor sits. Both can be
// visible at once, so they must not look the same.
BorderSurface {
  id: row

  property QtObject bar: null
  property string label: ""
  property string detail: ""
  property string glyph: ""
  property bool playing: false
  property bool cursored: false

  // Number key that plays this row, shown as a dim hint on the right. Empty
  // past the ninth row, where there is no single key left to offer.
  property string shortcut: ""

  signal activated()
  signal hovered()

  readonly property color fg: bar ? bar.foreground : Color.foreground

  height: inner.implicitHeight + Style.space(9)
  radius: Style.spacing.labelGap

  color: playing
    ? Style.selectedFillFor(fg, Color.accent)
    : (cursored || mouse.containsMouse ? Style.normalFillFor(fg, Color.accent) : "transparent")

  borderSpec: cursored
    ? Border.controlSpec("focus", fg, Color.accent)
    : (playing ? Border.controlSpec("normal", fg, Color.accent) : Border.none())

  Row {
    id: inner
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    anchors.leftMargin: row.borderLeft + Style.space(8)
    anchors.rightMargin: row.borderRight + Style.space(8)
    spacing: Style.space(8)

    Text {
      text: row.glyph
      color: row.fg
      font.family: row.bar ? row.bar.fontFamily : Style.font.family
      font.pixelSize: Style.font.body
      width: Style.space(16)
      horizontalAlignment: Text.AlignHCenter
      anchors.verticalCenter: parent.verticalCenter
    }

    Column {
      // Leaves room for the glyph on the left and the number hint on the right.
      width: parent.width - Style.space(24) - Style.space(16)
      spacing: Style.space(1)
      anchors.verticalCenter: parent.verticalCenter

      Text {
        textFormat: Text.PlainText
        width: parent.width
        text: row.label
        color: row.fg
        font.family: row.bar ? row.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.bodySmall
        font.bold: row.playing
        elide: Text.ElideRight
      }

      Text {
        textFormat: Text.PlainText
        width: parent.width
        text: row.detail
        color: Qt.darker(row.fg, 1.5)
        font.family: row.bar ? row.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.caption
        elide: Text.ElideRight
        visible: text !== ""
      }
    }

    Text {
      text: row.shortcut
      color: Qt.darker(row.fg, row.cursored || row.playing ? 1.3 : 2.0)
      font.family: row.bar ? row.bar.fontFamily : Style.font.family
      font.pixelSize: Style.font.caption
      width: Style.space(10)
      horizontalAlignment: Text.AlignRight
      anchors.verticalCenter: parent.verticalCenter
      visible: text !== ""
    }
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: row.activated()
    // Reaching for the mouse retires the keyboard cursor, so only one
    // selection is ever showing.
    onEntered: row.hovered()
  }
}
