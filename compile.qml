import QtQuick
import Quickshell
import "plugin" as Plugin
ShellRoot {
  // Compile the actual service without creating any session lock or PAM context.
  Component { id: serviceComponent; Plugin.Service {} }
  Timer {
    interval: 100
    running: true
    onTriggered: {
      if (serviceComponent.status !== Component.Ready) Qt.exit(1)
      console.log("ETHEREAL SERVICE COMPILE: PASS")
      Qt.quit()
    }
  }
}
