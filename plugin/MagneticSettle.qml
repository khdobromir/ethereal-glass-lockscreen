pragma ComponentBehavior: Bound
import QtQuick
import qs.Commons

Item {
  id: root
  required property Ethereal config
  required property TextInput input
  property int nextPulse: 0
  property int selectionStart: 0
  property int selectionEnd: 0
  // Only instantiate visible masks, even when a long password scrolls.
  readonly property point visibleRange: {
    const left = input.positionAt(0, input.cursorRectangle.y)
    const right = input.positionAt(input.width, input.cursorRectangle.y)
    return Qt.point(Math.max(0, Math.min(left, right) - 1), Math.min(input.length, Math.max(left, right) + 1))
  }
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

  function pulseFor(position) {
    for (let i = 0; i < pulses.count; ++i) {
      const pulse = pulses.itemAt(i) as SettlePulse
      if (pulse && pulse.running && pulse.dotIndex === position)
        return pulse
    }
    return null
  }

  function stop() {
    if (!pulses)
      return
    for (let i = 0; i < pulses.count; ++i) {
      const pulse = pulses.itemAt(i) as SettlePulse
      if (pulse)
        pulse.stop()
    }
  }

  // Qt emits textEdited before selection notifications; retain only indices.
  function edit(cursor, delta) {
    const removed = Math.max(selectionEnd - selectionStart, Math.max(0, -delta))
    const added = delta + removed
    const start = removed > 0 && selectionEnd > selectionStart ? selectionStart : added > 0 ? cursor - added : cursor
    selectionStart = cursor
    selectionEnd = cursor
    for (let i = 0; i < pulses.count; ++i) {
      const pulse = pulses.itemAt(i) as SettlePulse
      if (!pulse || !pulse.running || pulse.dotIndex < start)
        continue
      if (pulse.dotIndex < start + removed)
        pulse.stop()
      else
        pulse.dotIndex += delta
    }
    if (added <= 0 || !enabled || Style.duration(1) === 0)
      return
    const pulse = pulses.itemAt(nextPulse) as SettlePulse
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
    target: root.input
    function onSelectionStartChanged() {
      root.selectionStart = root.input.selectionStart
      root.selectionEnd = root.input.selectionEnd
    }
    function onSelectionEndChanged() {
      root.selectionStart = root.input.selectionStart
      root.selectionEnd = root.input.selectionEnd
    }
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
    model: Math.max(0, root.visibleRange.y - root.visibleRange.x)
    delegate: Text {
      id: dot
      required property int index
      readonly property int dotIndex: root.visibleRange.x + index
      readonly property point center: root.dotPosition(dotIndex)
      readonly property SettlePulse pulse: root.pulseFor(dotIndex)
      readonly property real originX: maskMetrics.tightBoundingRect.x + maskMetrics.tightBoundingRect.width / 2
      readonly property real originY: baselineOffset + maskMetrics.tightBoundingRect.y + maskMetrics.tightBoundingRect.height / 2
      x: center.x - originX
      y: center.y - originY
      visible: center.x >= 0 && center.y >= 0
      opacity: pulse ? pulse.alpha : 1
      color: root.config.peach
      font: root.input.font
      text: root.input.passwordCharacter
      textFormat: Text.PlainText
      Accessible.ignored: true
      transform: [
        Scale {
          origin.x: dot.originX
          origin.y: dot.originY
          xScale: dot.pulse ? dot.pulse.size : 1
          yScale: dot.pulse ? dot.pulse.size * dot.pulse.squash : 1
        },
        Translate { y: dot.pulse ? dot.pulse.offsetY : 0 }
      ]
    }
  }

  Repeater {
    id: pulses
    model: 4
    delegate: SettlePulse {}
  }

  component SettlePulse: Item {
    id: pulse
    property int dotIndex: -1
    property real offsetY: 0
    property real size: 1
    property real squash: 1
    property real alpha: 1
    property alias running: animation.running

    function play(position) {
      animation.stop()
      dotIndex = position
      animation.start()
    }
    function stop() {
      animation.stop()
      dotIndex = -1
    }

    SequentialAnimation {
      id: animation
      PropertyAction { target: pulse; property: "squash"; value: 1 }
      ParallelAnimation {
        NumberAnimation {
          target: pulse
          property: "offsetY"
          from: root.config.settleStartY
          to: root.config.settleOvershootY
          duration: Style.duration(Math.round(root.config.settleDuration * 3 / 8))
          easing.type: Easing.OutCubic
        }
        NumberAnimation {
          target: pulse
          property: "alpha"
          from: 0
          to: 1
          duration: Style.duration(Math.round(root.config.settleDuration * 3 / 8))
          easing.type: Easing.OutCubic
        }
        NumberAnimation {
          target: pulse
          property: "size"
          from: root.config.settleInitialScale
          to: 1
          duration: Style.duration(Math.round(root.config.settleDuration * 3 / 8))
          easing.type: Easing.OutCubic
        }
      }
      ParallelAnimation {
        NumberAnimation {
          target: pulse
          property: "offsetY"
          from: root.config.settleOvershootY
          to: 0
          duration: Style.duration(root.config.settleDuration - Math.round(root.config.settleDuration * 3 / 8))
          easing.type: Easing.OutCubic
        }
        NumberAnimation {
          target: pulse
          property: "squash"
          from: root.config.settleSquashY
          to: 1
          duration: Style.duration(root.config.settleDuration - Math.round(root.config.settleDuration * 3 / 8))
          easing.type: Easing.OutCubic
        }
      }
    }
  }
}
