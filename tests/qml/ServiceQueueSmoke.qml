import QtQuick
import Quickshell
import "Plugin" as Plugin

ShellRoot {
  id: root

  property int phase: 0
  property bool sawFailure: false
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
      if (service.error.indexOf("synthetic disable failure") !== -1)
        root.sawFailure = true
    }
  }

  Timer {
    interval: 10
    repeat: true
    running: true
    onTriggered: {
      if (root.phase === 0) {
        if (!service.statusKnown || service.operation.running) return
        service.pollTimer.stop()
        root.expect(service.installed, "installed status")
        root.expect(service.runtimeState === "off", "inactive status")
        root.expect(service.autoStartKnown && service.autoStartEnabled, "enablement status")
        root.expect(service.webUiUrl === "https://localhost:49001", "isolated config")

        root.expect(service.setRunning(true), "start accepted")
        root.expect(service.setAutoStart(false), "disable queued")
        root.expect(service.setRunning(false), "stop queued")
        root.expect(service.setRunning(true), "latest start queued")
        root.expect(service.queuedRuntimeKind === "start", "latest runtime target")
        root.phase = 1
        return
      }

      if (!root.sawFailure || service.operation.running || service.currentKind !== ""
          || service.queuedActions.length !== 0 || service.queuedStatus) return
      root.expect(service.runtimeState === "on", "started status")
      root.expect(service.actionMessage.indexOf("synthetic disable failure") !== -1,
        "failure diagnostic")
      console.log(root.failures === "" ? "SERVICE_QUEUE_SMOKE_OK"
        : "SERVICE_QUEUE_SMOKE_FAILED: " + root.failures)
      Qt.quit()
    }
  }

  Timer {
    interval: 4000
    running: true
    onTriggered: {
      console.log("SERVICE_QUEUE_SMOKE_TIMEOUT")
      Qt.quit()
    }
  }
}
