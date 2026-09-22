import QtQuick
import Quickshell
import "Plugin" as Plugin

ShellRoot {
  id: root

  property bool started: false
  property bool sawTimeout: false
  property string failures: ""

  function expect(condition, label) {
    if (!condition) failures += (failures === "" ? "" : ", ") + label
  }

  Plugin.Service {
    id: service
    systemctlCommand: Quickshell.env("FAKE_SYSTEMCTL_COMMAND")
  }

  Connections {
    target: service
    function onErrorChanged() {
      if (service.error === "Sunshine command timed out. Refreshing status.")
        root.sawTimeout = true
    }
  }

  Timer {
    interval: 10
    repeat: true
    running: true
    onTriggered: {
      if (!root.started) {
        if (!service.statusKnown || service.operation.running) return
        service.pollTimer.stop()
        service.timeoutTimer.interval = 100
        root.expect(service.setRunning(true), "start accepted")
        root.started = true
        return
      }
      if (!root.sawTimeout || service.operation.running || service.currentKind !== "") return
      root.expect(!service.timedOut, "timeout exit drained")
      console.log(root.failures === "" ? "SERVICE_TIMEOUT_SMOKE_OK"
        : "SERVICE_TIMEOUT_SMOKE_FAILED: " + root.failures)
      Qt.quit()
    }
  }

  Timer {
    interval: 2000
    running: true
    onTriggered: {
      console.log("SERVICE_TIMEOUT_SMOKE_TIMEOUT")
      Qt.quit()
    }
  }
}
