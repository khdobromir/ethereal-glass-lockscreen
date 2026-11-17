pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import qs.Commons

Item {
  id: root
  required property Ethereal config
  required property TextInput input
  property int nextPulse: 0
  clip: true
  Accessible.ignored: true

  function dotPosition(position) {
    if (position < 0 || position >= root.input.length || root.input.cursorRectangle.height <= 0)
      return Qt.point(-1, -1)
    const before = root.input.positionToRectangle(position)
    const after = root.input.positionToRectangle(position + 1)
    const direction = after.x >= before.x ? 1 : -1
    const x = (before.x + after.x - direction * root.input.font.letterSpacing) / 2
    if (x < 0 || x > root.input.width)
      return Qt.point(-1, -1)
    const ink = maskMetrics.tightBoundingRect
    return Qt.point(x, root.input.baselineOffset + ink.y + ink.height / 2 + (root.height - root.input.height) / 2)
  }

  function stop() {
    if (!pulses)
      return
    for (let i = 0; i < pulses.count; ++i) {
      const pulse = pulses.itemAt(i) as BloomPulse
      if (pulse)
        pulse.stop()
    }
  }

  // Rebase live effects after edits; password text stays in the original input.
  function edit(cursor, delta) {
    const start = delta > 0 ? cursor - delta : cursor
    for (let i = 0; i < pulses.count; ++i) {
      const pulse = pulses.itemAt(i) as BloomPulse
      if (!pulse || !pulse.running || pulse.dotIndex < start)
        continue
      if (delta < 0 && pulse.dotIndex < start - delta)
        pulse.stop()
      else
        pulse.dotIndex += delta
    }
    if (delta <= 0 || !enabled || Style.duration(1) === 0)
      return
    const pulse = pulses.itemAt(nextPulse) as BloomPulse
    if (!pulse)
      return
    pulse.play(cursor - 1)
    nextPulse = (nextPulse + 1) % pulses.count
  }

  onEnabledChanged: {
    if (!enabled)
      stop()
  }
  onVisibleChanged: {
    if (!visible)
      stop()
  }

  Connections {
    target: Style
    function onReduceMotionChanged() {
      if (Style.reduceMotion)
        root.stop()
    }
  }

  TextMetrics {
    id: maskMetrics
    font: root.input.font
    text: root.input.passwordCharacter
  }

  Repeater {
    id: pulses
    model: 4
    delegate: BloomPulse {}
  }

  component BloomPulse: Item {
    id: pulse
    property int dotIndex: -1
    property real progress: 1
    property real glow: 0
    property alias running: animation.running
    readonly property point center: dotIndex >= 0 ? root.dotPosition(dotIndex) : Qt.point(-1, -1)
    readonly property real diameter: Math.max(0, Math.min(root.config.rippleFinalDiameter, 2 * Math.min(center.x, root.width - center.x, center.y, root.height - center.y)))
    visible: running && center.x >= 0 && center.y >= 0

    function play(position) {
      animation.stop()
      dotIndex = position
      animation.start()
    }
    function stop() {
      animation.stop()
      dotIndex = -1
    }

    RectangularShadow {
      width: root.config.bloomGlowRadius
      height: width
      x: pulse.center.x - width / 2
      y: pulse.center.y - height / 2
      radius: width / 2
      blur: root.config.bloomGlowRadius
      color: Qt.alpha(root.config.peach, pulse.glow)
    }
    Rectangle {
      width: Math.min(root.config.rippleInitialDiameter, pulse.diameter) + (pulse.diameter - Math.min(root.config.rippleInitialDiameter, pulse.diameter)) * pulse.progress
      height: width
      x: pulse.center.x - width / 2
      y: pulse.center.y - height / 2
      radius: width / 2
      color: Qt.alpha(root.config.peach, 0)
      border.width: root.config.rippleBorderWidth
      border.color: Qt.alpha(root.config.peach, root.config.rippleInitialOpacity * (1 - pulse.progress))
    }
    ParallelAnimation {
      id: animation
      NumberAnimation {
        target: pulse
        property: "progress"
        from: 0
        to: 1
        duration: Style.duration(root.config.rippleDuration)
        easing.type: Easing.OutCubic
      }
      SequentialAnimation {
        NumberAnimation {
          target: pulse
          property: "glow"
          from: 0
          to: root.config.bloomGlowOpacity
          duration: Style.duration(Math.min(70, root.config.bloomGlowDuration))
          easing.type: Easing.OutCubic
        }
        NumberAnimation {
          target: pulse
          property: "glow"
          to: 0
          duration: Style.duration(Math.max(0, root.config.bloomGlowDuration - 70))
          easing.type: Easing.OutCubic
        }
      }
    }
  }
}
