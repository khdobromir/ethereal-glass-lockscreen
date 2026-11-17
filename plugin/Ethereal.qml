import QtQuick

QtObject {
  id: root
  readonly property string fontFamily: Qt.fontFamilies().indexOf("JetBrainsMono Nerd Font") >= 0 ? "JetBrainsMono Nerd Font" : "monospace"
  readonly property color peach: "#FFCEAD"
  readonly property color background: "#060B1E"
  readonly property color secondary: "#C9B8A6"
  readonly property color clock: "#F0E4DC"
  readonly property color error: "#ED5B5A"
  readonly property int greetingFontSize: 40
  readonly property int timeFontSize: 32
  readonly property int dateFontSize: 13
  readonly property int cardWidth: 520
  readonly property int cardRadius: 24
  readonly property int cardPadding: 40
  readonly property real cardOpacity: 0.58
  readonly property int cardBorderWidth: 1
  readonly property real cardBorderOpacity: 0.18
  readonly property real backgroundDimOpacity: 0.10
  readonly property int passwordFieldWidth: 240
  readonly property int passwordUnderlineHeight: 2
  readonly property int revealDuration: 280
  readonly property int collapseDelay: 450
  readonly property int bloomGlowRadius: 14
  readonly property real bloomGlowOpacity: 0.60
  readonly property int bloomGlowDuration: 220
  readonly property int rippleDuration: 300
  readonly property int rippleInitialDiameter: 10
  readonly property int rippleFinalDiameter: 42
  readonly property real rippleBorderWidth: 1.5
  readonly property real rippleInitialOpacity: 0.75
  readonly property int entryDuration: 240
  readonly property int errorShakeDuration: 240
  readonly property int errorColorReturnDuration: 350
}
