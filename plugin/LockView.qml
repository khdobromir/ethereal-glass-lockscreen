pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui

Item {
  id: root

  property bool authenticatingPassword: false
  property string backgroundPath: ""
  property int backgroundVersion: 0
  readonly property bool compact: height < 480
  property real entryProgress: 0
  property bool errorHighlight: false
  property int failedAttempts: 0
  property string failureMessage: ""
  readonly property int fieldFontSize: 20
  property bool fingerprintConfigured: false
  readonly property real fingerprintReserve: fingerprintConfigured ? 30 : 0
  property bool fingerprintUnavailable: false
  property bool inputEnabled: true
  property int lastEditedLength: 0
  property bool loadBackground: true
  property date now: new Date()
  readonly property int padding: width < 600 || compact ? 24 : design.cardPadding
  readonly property int passwordDotFontSize: 20
  readonly property int passwordDotLetterSpacing: 4
  readonly property real passwordDotScale: dotMetrics.advanceWidth > 0 ? Math.min(1, Math.max(1, passwordInput.width - 4) / dotMetrics.advanceWidth) : 1
  property string passwordText: ""
  property real shakeOffset: 0
  readonly property bool showPasswordCursor: inputEnabled && !authenticatingPassword && failureMessage.length === 0
  property bool syncingPasswordText: false
  property bool passwordRevealed: false
  property bool submitting: false
  property string userName: ""
  readonly property bool video: Util.isVideoPath(root.backgroundPath)
  property string videoPosterPath: ""
  readonly property string visualState: !inputEnabled ? "preview" : authenticatingPassword ? "checking" : failureMessage.length > 0 ? "error" : passwordText.length > 0 ? "typing" : "idle"

  signal clearFailureRequested
  signal passwordTextEdited(string password)
  signal submitPassword(string password)
  signal wakeRequested

  function updatePasswordReveal() {
    if (passwordInput.length > 0 || authenticatingPassword || failureMessage.length > 0 || submitting) {
      collapseTimer.stop()
      passwordRevealed = true
    } else if (passwordRevealed && !collapseTimer.running) {
      collapseTimer.start()
    }
  }

  function clearPassword() {
    passwordTextEdited("")
  }

  // Waking a DPMS-blanked display can stall the compositor for seconds while
  // the monitor modesets, so the wake key's release arrives late and client-side
  // key repeat floods the field with that character. A held key has no business
  // typing a password; only holding Backspace/Delete to clear stays useful.
  function dropsAutoRepeat(key) {
    return key !== Qt.Key_Backspace && key !== Qt.Key_Delete
  }
  function forcePasswordFocus() {
    root.now = new Date()
    passwordInput.forceActiveFocus()
  }
  function processSleepSignal(line) {
    if (line.trim() !== "boolean false")
      return
    root.now = new Date()
    Qt.callLater(root.restorePasswordFocus)
  }

  // The field loses focus while a password is checked (it is disabled then),
  // and forcing focus onto it would not stick until the check ends.
  function restorePasswordFocus() {
    if (inputEnabled && passwordInput.enabled && !passwordInput.activeFocus)
      forcePasswordFocus()
  }
  function syncPasswordText() {
    if (passwordInput.text === passwordText)
      return
    syncingPasswordText = true
    passwordInput.text = passwordText
    syncingPasswordText = false
    lastEditedLength = passwordInput.text.length
  }

  Component.onCompleted: {
    syncPasswordText()
    updatePasswordReveal()
    if (inputEnabled)
      Qt.callLater(forcePasswordFocus)
  }
  Window.onActiveChanged: {
    root.now = new Date()
    Qt.callLater(restorePasswordFocus)
  }

  // A VT switch, which the NVIDIA driver forces around every suspend, takes the
  // keyboard away and Qt drops the field's focus with it. Nothing gives it back
  // when the keyboard returns, so typing went nowhere until the field was clicked.
  Window.onActiveFocusItemChanged: Qt.callLater(restorePasswordFocus)
  onFailureMessageChanged: {
    if (failureMessage.length > 0) submitting = false
    updatePasswordReveal()
    if (!failureMessage.length)
      return
    errorHighlight = true
    errorHold.restart()
    shakeAnimation.restart()
  }
  onInputEnabledChanged: {
    updatePasswordReveal()
    if (!inputEnabled) {
      submitting = false
      peachBloom.stop()
    }
    if (inputEnabled)
      Qt.callLater(forcePasswordFocus)
  }
  onLoadBackgroundChanged: {
    root.now = new Date()
    if (loadBackground)
      entryAnimation.restart()
    else {
      entryAnimation.stop()
      entryProgress = 0
      collapseTimer.stop()
      passwordRevealed = false
      submitting = false
      peachBloom.stop()
    }
  }
  onPasswordTextChanged: {
    syncPasswordText()
    updatePasswordReveal()
  }
  onSubmittingChanged: updatePasswordReveal()
  onAuthenticatingPasswordChanged: {
    if (authenticatingPassword) submitting = false
    updatePasswordReveal()
  }
  onWakeRequested: root.now = new Date()

  Ethereal {
    id: design
  }
  // logind resumes independently of input/focus and the 15-second clock tick.
  Process {
    command: ["dbus-monitor", "--system", "type='signal',sender='org.freedesktop.login1',interface='org.freedesktop.login1.Manager',member='PrepareForSleep'"]
    running: root.loadBackground

    stdout: SplitParser {
      onRead: data => root.processSleepSignal(data)
    }

    onExited: function (exitCode) {
      if (root.loadBackground && exitCode !== 0)
        console.warn("Ethereal resume watch unavailable; clock timer remains active")
    }
  }
  Timer {
    interval: 15000
    repeat: true
    running: root.loadBackground

    onTriggered: root.now = new Date()
  }
  Timer {
    id: collapseTimer
    interval: design.collapseDelay
    onTriggered: {
      if (passwordInput.length === 0 && !root.authenticatingPassword && !root.failureMessage.length && !root.submitting) {
        peachBloom.stop()
        root.passwordRevealed = false
      }
    }
  }
  Timer {
    id: errorHold

    interval: 250

    onTriggered: root.errorHighlight = false
  }
  NumberAnimation {
    id: entryAnimation

    duration: Style.duration(design.entryDuration)
    easing.type: Easing.OutCubic
    from: 0
    property: "entryProgress"
    running: root.loadBackground
    target: root
    to: 1
  }
  SequentialAnimation {
    id: shakeAnimation

    NumberAnimation {
      duration: Style.duration(design.errorShakeDuration / 5)
      property: "shakeOffset"
      target: root
      to: 5
    }
    NumberAnimation {
      duration: Style.duration(design.errorShakeDuration / 5)
      property: "shakeOffset"
      target: root
      to: -5
    }
    NumberAnimation {
      duration: Style.duration(design.errorShakeDuration / 5)
      property: "shakeOffset"
      target: root
      to: 3
    }
    NumberAnimation {
      duration: Style.duration(design.errorShakeDuration / 5)
      property: "shakeOffset"
      target: root
      to: -3
    }
    NumberAnimation {
      duration: Style.duration(design.errorShakeDuration / 5)
      property: "shakeOffset"
      target: root
      to: 0
    }
  }
  TextMetrics {
    id: dotMetrics

    text: "●".repeat(passwordInput.text.length)

    font {
      family: design.fontFamily
      letterSpacing: root.passwordDotLetterSpacing
      pixelSize: root.passwordDotFontSize
    }
  }
  Rectangle {
    anchors.fill: parent
    color: design.background

    BackgroundMedia {
      id: wallpaper

      anchors.fill: parent
      cached: true
      constrainDecode: true
      decodeSize: Qt.size(width, height)
      objectName: "lockWallpaper"
      path: root.loadBackground ? (root.video ? root.videoPosterPath : root.backgroundPath) : ""
      version: root.backgroundVersion
    }
    MultiEffect {
      anchors.fill: wallpaper
      autoPaddingEnabled: false
      blur: 1.0
      blurEnabled: root.loadBackground && wallpaper.ready
      blurMax: 128
      blurMultiplier: 1.25
      contrast: -0.08
      source: wallpaper
    }
    Rectangle {
      Accessible.ignored: true
      anchors.fill: parent
      color: Qt.alpha(design.background, design.backgroundDimOpacity)
    }
    MouseArea {
      anchors.fill: parent
      hoverEnabled: true

      onClicked: {
        root.wakeRequested()
        root.forcePasswordFocus()
      }
      onPositionChanged: root.wakeRequested()
    }
    Rectangle {
      id: card

      anchors.centerIn: parent
      border.color: Qt.alpha(design.peach, design.cardBorderOpacity)
      border.width: design.cardBorderWidth
      color: Qt.alpha(design.background, design.cardOpacity)
      height: Math.max(root.compact ? 0 : 350 - passwordArea.implicitHeight + passwordArea.height, content.height + root.padding * 2)
      objectName: "glassCard"
      opacity: root.entryProgress
      radius: design.cardRadius
      width: Math.min(design.cardWidth, Math.max(0, root.width - 48))

      transform: Translate {
        x: root.shakeOffset
        y: (1 - root.entryProgress) * 12
      }

      RectangularShadow {
        Accessible.ignored: true
        anchors.fill: parent
        blur: 36
        color: Qt.alpha("black", 0.3)
        offset: Qt.vector2d(0, 12)
        radius: design.cardRadius
        z: -1
      }
      Column {
        id: content

        anchors.centerIn: parent
        width: Math.max(0, parent.width - root.padding * 2)

        Text {
          color: design.peach
          elide: Text.ElideRight
          fontSizeMode: Text.HorizontalFit
          horizontalAlignment: Text.AlignHCenter
          minimumPixelSize: 22
          objectName: "greeting"
          text: "HI, " + (root.userName || "USER").toUpperCase()
          textFormat: Text.PlainText
          width: parent.width

          font {
            bold: true
            family: design.fontFamily
            pixelSize: root.compact ? 28 : design.greetingFontSize
          }
        }
        Item {
          height: root.compact ? 12 : 24
          width: 1
        }
        Text {
          color: design.clock
          horizontalAlignment: Text.AlignHCenter
          objectName: "clock"
          text: root.now.toLocaleTimeString(Qt.locale("en_US"), "HH:mm")
          textFormat: Text.PlainText
          width: parent.width

          font {
            family: design.fontFamily
            pixelSize: root.compact ? 26 : design.timeFontSize
          }
        }
        Item {
          height: 6
          width: 1
        }
        Text {
          color: design.secondary
          fontSizeMode: Text.HorizontalFit
          horizontalAlignment: Text.AlignHCenter
          minimumPixelSize: 10
          objectName: "date"
          text: root.now.toLocaleDateString(Qt.locale("en_US"), "dddd, MMMM d").toUpperCase()
          textFormat: Text.PlainText
          width: parent.width

          font {
            family: design.fontFamily
            pixelSize: design.dateFontSize
            weight: Font.Medium
          }
        }
        Item {
          height: root.compact ? 20 : 40
          width: 1
        }
        Item {
          id: passwordArea
          readonly property real bloomInset: Math.max(0, (design.rippleFinalDiameter - inputField.height) / 2)
          width: parent.width
          implicitHeight: passwordContent.height + bloomInset
          // Collapse only the painted area; the original input keeps focus.
          height: root.passwordRevealed ? implicitHeight : 0
          opacity: root.passwordRevealed ? 1 : 0
          clip: true

          Behavior on height {
            NumberAnimation { duration: Style.duration(design.revealDuration); easing.type: Easing.OutCubic }
          }
          Behavior on opacity {
            NumberAnimation { duration: Style.duration(design.revealDuration); easing.type: Easing.OutCubic }
          }

          Column {
            id: passwordContent
            width: parent.width
            y: passwordArea.bloomInset
            Item {
              id: inputField

              anchors.horizontalCenter: parent.horizontalCenter
              height: 30
              width: Math.min(parent.width, design.passwordFieldWidth)

              PeachBloom {
                id: peachBloom
                x: passwordInput.x
                y: passwordInput.y - passwordArea.bloomInset
                width: passwordInput.width
                height: passwordInput.height + passwordArea.bloomInset * 2
                config: design
                input: passwordInput
                enabled: root.inputEnabled && root.loadBackground && !root.authenticatingPassword && !root.submitting && root.failureMessage.length === 0
              }

              TextInput {
                id: passwordInput

                Accessible.name: "Password"
                activeFocusOnPress: true
                activeFocusOnTab: true
                anchors.fill: parent
                anchors.leftMargin: root.fingerprintReserve
                // Reserve the fingerprint icon's width on both sides so the centered
                // dots stay symmetric and never slide under the icon as they grow.
                anchors.rightMargin: root.fingerprintReserve
                clip: true
                color: design.peach
                cursorVisible: activeFocus && root.showPasswordCursor && text.length > 0
                echoMode: TextInput.Password
                enabled: root.inputEnabled && !root.authenticatingPassword
                horizontalAlignment: TextInput.AlignHCenter
                objectName: "passwordInput"
                passwordCharacter: "\u25CF"
                passwordMaskDelay: 0
                readOnly: root.authenticatingPassword
                selectedTextColor: design.peach
                selectionColor: Qt.alpha(design.peach, 0.25)
                verticalAlignment: TextInput.AlignVCenter

                cursorDelegate: Rectangle {
                  color: design.peach
                  visible: passwordInput.cursorVisible
                  width: 2
                }

                Keys.onPressed: function (event) {
                  root.wakeRequested()
                  if (event.isAutoRepeat && root.dropsAutoRepeat(event.key)) {
                    event.accepted = true
                    return
                  }
                  if (event.key === Qt.Key_Escape || (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_U)) {
                    root.passwordTextEdited("")
                    event.accepted = true
                  }
                }
                onAccepted: {
                  const submitted = root.passwordText
                  // The service clears the buffer before it reports checking/error.
                  root.submitting = submitted.length > 0
                  root.passwordTextEdited("")
                  if (submitted.length > 0)
                    root.submitPassword(submitted)
                }
                onTextChanged: {
                  if (!root.syncingPasswordText)
                    root.passwordTextEdited(text)
                  if (text.length > 0) {
                    root.wakeRequested()
                  }
                  if (text.length > 0 && root.failureMessage.length > 0)
                    root.clearFailureRequested()
                  if (text.length === 0) peachBloom.stop()
                  root.updatePasswordReveal()
                }

                // A selection replacement invalidates the old dots' indices.
                onSelectedTextChanged: {
                  if (selectionStart !== selectionEnd) peachBloom.stop()
                }

                // textEdited excludes service synchronization and programmatic clears.
                onTextEdited: {
                  if (!root.syncingPasswordText)
                    peachBloom.edit(cursorPosition, length - root.lastEditedLength)
                  root.lastEditedLength = length
                }

                font {
                  family: design.fontFamily
                  letterSpacing: passwordInput.text.length > 0 ? root.passwordDotLetterSpacing * root.passwordDotScale : 0
                  pixelSize: passwordInput.text.length > 0 ? Math.max(1, Math.floor(root.passwordDotFontSize * root.passwordDotScale)) : root.fieldFontSize
                }
              }
              Text {
                id: fingerprintIcon

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                color: root.fingerprintUnavailable ? design.error : design.secondary
                objectName: "fingerprintIndicator"
                text: root.fingerprintUnavailable ? "󰺱" : "󰈷"
                textFormat: Text.PlainText
                visible: root.fingerprintConfigured

                font {
                  family: design.fontFamily
                  pixelSize: 20
                }
              }
            }
            Item {
              height: 12
              width: 1
            }
            Rectangle {
              anchors.horizontalCenter: parent.horizontalCenter
              color: root.errorHighlight ? design.error : Qt.alpha(design.peach, root.passwordText.length ? 0.65 : 0.25)
              height: design.passwordUnderlineHeight
              width: inputField.width

              Behavior on color {
                ColorAnimation {
                  duration: Style.duration(root.errorHighlight ? 0 : design.errorColorReturnDuration)
                }
              }
            }
            Item {
              height: 12
              width: 1
            }
          }
        }
        Text {
          color: root.failureMessage.length ? design.error : Qt.alpha(design.secondary, 0.8)
          horizontalAlignment: Text.AlignHCenter
          objectName: "statusText"
          text: root.authenticatingPassword ? "CHECKING..." : root.failureMessage.length ? "INCORRECT PASSWORD" : root.passwordRevealed ? "ENTER PASSWORD" : "START TYPING TO UNLOCK"
          textFormat: Text.PlainText
          width: parent.width

          font {
            family: design.fontFamily
            pixelSize: 12
            weight: Font.Medium
          }
        }
        Text {
          color: design.error
          horizontalAlignment: Text.AlignHCenter
          objectName: "fingerprintUnavailableNotice"
          text: Commons.I18n.t("lock.fingerprintUnavailable")
          textFormat: Text.PlainText
          topPadding: 12
          visible: root.fingerprintConfigured && root.fingerprintUnavailable
          width: parent.width
          wrapMode: Text.WordWrap

          font {
            family: design.fontFamily
            pixelSize: 12
          }
        }
      }
    }
  }
}
