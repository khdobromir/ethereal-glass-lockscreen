import QtQuick
import qs.Commons

Item {
  id: root
  required property Ethereal config
  property bool deleting: false
  property alias running: pulseAnimation.running
  clip: true
  Accessible.ignored: true

  function pulse(removing) {
    pulseAnimation.stop()
    deleting = removing
    if (Style.duration(1) > 0)
      pulseAnimation.start()
  }

  onVisibleChanged: {
    if (!visible)
      pulseAnimation.stop()
  }

  Rectangle {
    id: trail
    width: Math.min(root.width, root.config.trailLength)
    height: parent.height
    visible: root.running
    gradient: Gradient {
      orientation: Gradient.Horizontal
      GradientStop {
        position: 0
        color: "transparent"
      }
      GradientStop {
        position: 0.65
        color: root.config.peach
      }
      GradientStop {
        position: 1
        color: "transparent"
      }
    }
  }

  ParallelAnimation {
    id: pulseAnimation
    NumberAnimation {
      target: trail
      property: "x"
      from: root.deleting ? root.width : -trail.width
      to: root.deleting ? -trail.width : root.width
      duration: Style.duration(root.deleting ? 160 : root.config.trailDuration)
      easing.type: Easing.OutCubic
    }
    SequentialAnimation {
      NumberAnimation {
        target: trail
        property: "opacity"
        from: 0
        to: root.deleting ? 0.3 : root.config.trailPeakOpacity
        duration: Style.duration(root.deleting ? 40 : 55)
      }
      NumberAnimation {
        target: trail
        property: "opacity"
        to: 0
        duration: Style.duration(root.deleting ? 120 : root.config.trailDuration - 55)
        easing.type: Easing.OutCubic
      }
    }
  }
}
