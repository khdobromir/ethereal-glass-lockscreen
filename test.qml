import QtQuick
import QtTest
import Quickshell
import qs.Commons
import "plugin" as Plugin

ShellRoot {
  FloatingWindow {
    id: window
    visible: true
    implicitWidth: 1440
    implicitHeight: 810
    Plugin.LockView {
      id: view
      anchors.fill: parent
      loadBackground: true
      onPasswordTextEdited: function(password) { passwordText = password }
      onClearFailureRequested: failureMessage = ""
    }
    TestCase {
      id: tests
      name: "EtherealLockView"
      when: window.visible
      onCompletedChanged: {
        if (completed) {
          console.log("ETHEREAL TESTS: " + qtest_results.passCount + " passed, " + qtest_results.failCount + " failed")
          if (qtest_results.failCount) Qt.exit(1)
        }
      }
      TextInput { id: clipboardSource; visible: false; text: "fictional pasted input" }
      SignalSpy { id: submitted; target: view; signalName: "submitPassword" }
      function check(condition, message) {
        if (!condition) console.error("ASSERT " + qtest_results.functionName + ": " + (message || "condition failed"))
        verify(condition, message)
      }
      function equal(actual, expected) {
        if (actual !== expected) console.error("ASSERT " + qtest_results.functionName + ": " + actual + " != " + expected)
        compare(actual, expected)
      }
      function init() {
        console.log("TEST " + qtest_results.functionName)
        window.implicitWidth = 1440
        window.implicitHeight = 810
        view.passwordText = ""
        view.failureMessage = ""
        view.inputEnabled = true
        view.authenticatingPassword = false
        view.fingerprintConfigured = false
        view.fingerprintUnavailable = false
        Style.reduceMotion = false
        submitted.clear()
        view.forcePasswordFocus()
        wait(300)
      }
      function test_greetingIsPlainAndFits() {
        var greeting = findChild(view, "greeting")
        check(greeting !== null, "The glass lock must display its user greeting")
        view.userName = "<img src='https://example.invalid/tracker'>"
        equal(greeting.textFormat, Text.PlainText)
        equal(greeting.text, "HI, <IMG SRC='HTTPS://EXAMPLE.INVALID/TRACKER'>")
        view.userName = "a".repeat(128)
        check(greeting.width <= findChild(view, "glassCard").width)
        equal(greeting.elide, Text.ElideRight)
        view.userName = ""
        equal(greeting.text, "HI, USER")
      }
      function test_realTypingDeletionAndClear() {
        var input = findChild(view, "passwordInput")
        var trail = findChild(view, "lightTrail")
        keyClick(Qt.Key_Shift)
        check(!trail.running,"trail should be stopped")
        keyClick(Qt.Key_A)
        equal(view.passwordText, "a")
        check(trail.running,"typing should start trail")
        equal(input.echoMode, TextInput.Password)
        equal(input.passwordCharacter, "●")
        equal(input.passwordMaskDelay, 0)
        keyClick(Qt.Key_Backspace)
        equal(view.passwordText, "")
        check(trail.deleting,"backspace should reverse trail")
        keyClick(Qt.Key_B)
        keyClick(Qt.Key_Escape)
        equal(view.passwordText, "")
        keyClick(Qt.Key_C)
        keyClick(Qt.Key_U, Qt.ControlModifier)
        equal(view.passwordText, "")
        wait(300)
        check(!trail.running,"trail should be stopped")
      }
      function test_programmaticSyncDoesNotPulse() {
        var trail = findChild(view, "lightTrail")
        view.passwordText = "fictional-test-input"
        check(!trail.running,"trail should be stopped")
        view.passwordText = ""
        check(!trail.running,"trail should be stopped")
      }
      function test_submitEmptyAndBusy() {
        keyClick(Qt.Key_Return)
        equal(submitted.count, 0)
        keyClick(Qt.Key_A)
        keyClick(Qt.Key_Return)
        equal(submitted.count, 1)
        equal(submitted.signalArguments[0][0], "a")
        equal(view.passwordText, "")
        view.authenticatingPassword = true
        keyClick(Qt.Key_A)
        keyClick(Qt.Key_Return)
        equal(submitted.count, 1)
        equal(view.passwordText, "")
        view.authenticatingPassword = false
        wait(30)
        check(findChild(view, "passwordInput").activeFocus)
      }
      function test_longPasswordAndSmallScreens() {
        view.passwordText = "x".repeat(512)
        var input = findChild(view, "passwordInput")
        check(input.font.pixelSize < 20)
        check(view.passwordDotScale > 0 && view.passwordDotScale <= 1)
        var sizes = [[683,384],[960,540],[1366,768],[1920,1080],[2560,1440],[3840,2160],[3440,1440],[480,360],[320,300]]
        for (var i = 0; i < sizes.length; ++i) {
          window.implicitWidth = sizes[i][0]
          window.implicitHeight = sizes[i][1]
          wait(20)
          var card = findChild(view, "glassCard")
          check(card.width <= view.width - 48)
          check(card.height <= view.height - 48)
          check(input.mapToItem(view,0,0).y >= 0)
          check(input.mapToItem(view,0,input.height).y <= view.height)
        }
      }
      function test_errorAndReducedMotion() {
        view.failureMessage = "fictional PAM failure"
        equal(view.visualState, "error")
        equal(findChild(view,"statusText").text, "INCORRECT PASSWORD")
        keyClick(Qt.Key_A)
        equal(view.failureMessage, "")
        equal(view.visualState, "typing")
        Style.reduceMotion = true
        wait(400)
        keyClick(Qt.Key_B)
        check(!findChild(view,"lightTrail").running,"reduced motion must not pulse")
        view.authenticatingPassword = true
        equal(findChild(view,"statusText").text, "CHECKING...")
      }
      function test_pasteFastTypingAndDelete() {
        var input = findChild(view,"passwordInput")
        clipboardSource.selectAll()
        clipboardSource.copy()
        input.paste()
        equal(view.passwordText,"fictional pasted input")
        check(findChild(view,"lightTrail").running)
        keyClick(Qt.Key_U, Qt.ControlModifier)
        for (var i = 0; i < 30; ++i) keyClick(Qt.Key_A, Qt.NoModifier, 0)
        equal(view.passwordText.length,30)
        keyClick(Qt.Key_Home)
        keyClick(Qt.Key_Delete)
        equal(view.passwordText.length,29)
        wait(300)
        check(!findChild(view,"lightTrail").running,"rapid input must not queue pulses")
      }
      function test_missingWallpaperKeepsInput() {
        view.backgroundPath = "/tmp/ethereal-deliberately-missing-wallpaper.png"
        tryCompare(findChild(view,"lockWallpaper"),"failed",true,2000)
        keyClick(Qt.Key_A)
        equal(view.passwordText,"a")
        view.backgroundPath = ""
      }
      function test_resumeRefreshesWithoutClockTick() {
        view.now = new Date(2000,0,1)
        view.processSleepSignal("   boolean true")
        equal(view.now.getFullYear(),2000)
        view.processSleepSignal("signal sender=org.freedesktop.login1")
        equal(view.now.getFullYear(),2000)
        view.processSleepSignal("   boolean false")
        check(Math.abs(view.now.getTime() - Date.now()) < 1000)
      }
      function test_clockAndFingerprint() {
        view.now = new Date(2026,10,17,11,29,0)
        equal(findChild(view,"clock").text,"11:29")
        equal(findChild(view,"date").text,"TUESDAY, NOVEMBER 17")
        view.now = new Date(2026,11,31,23,59,0)
        equal(findChild(view,"date").text,"THURSDAY, DECEMBER 31")
        view.now = new Date(2027,0,1,0,0,0)
        equal(findChild(view,"clock").text,"00:00")
        equal(findChild(view,"date").text,"FRIDAY, JANUARY 1")
        view.fingerprintConfigured = true
        view.fingerprintUnavailable = true
        check(findChild(view,"fingerprintIndicator").visible)
        check(findChild(view,"fingerprintUnavailableNotice").visible)
      }
    }
  }
}
