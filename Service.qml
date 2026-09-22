import QtQuick
import Quickshell
import Quickshell.Io
import "Model.js" as Model

// Quickshell exposes QProcess signal parameters that qmllint cannot resolve.
// qmllint disable signal-handler-parameters

QtObject {
  id: root

  property var shell: null
  property var manifest: null
  property bool statusKnown: false
  property bool packageMissing: false
  property bool installed: false
  property string runtimeState: "unavailable"
  property bool autoStartKnown: false
  property bool autoStartEnabled: false
  property string error: ""
  property string actionMessage: ""
  property string currentKind: ""
  property var currentTarget: null
  property var queuedActions: []
  property bool queuedStatus: false
  property bool timedOut: false
  property int basePort: Model.DEFAULT_BASE_PORT
  property string systemctlCommand: "/usr/bin/systemctl"

  readonly property string unitName: "app-dev.lizardbyte.app.Sunshine.service"
  readonly property bool running: runtimeState === "on"
  readonly property bool transitioning: runtimeState === "starting" || runtimeState === "stopping"
  readonly property bool failed: runtimeState === "failed"
  readonly property bool busy: currentKind !== "" && currentKind !== "status"
  readonly property string queuedRuntimeKind: queuedKind("runtime")
  readonly property string queuedAutoStartKind: queuedKind("auto-start")
  readonly property bool runtimeBusy: currentKind === "start" || currentKind === "stop"
    || queuedRuntimeKind !== ""
  readonly property bool autoStartBusy: currentKind === "enable" || currentKind === "disable"
    || queuedAutoStartKind !== ""
  readonly property bool runtimeChecked: queuedRuntimeKind !== ""
    ? queuedRuntimeKind === "start"
    : (currentKind === "start" || currentKind === "stop" ? currentTarget === true
      : runtimeState === "on" || runtimeState === "starting")
  readonly property bool autoStartChecked: queuedAutoStartKind !== ""
    ? queuedAutoStartKind === "enable"
    : (currentKind === "enable" || currentKind === "disable" ? currentTarget === true
      : autoStartEnabled)
  readonly property int webUiPort: basePort + 1
  readonly property string webUiUrl: "https://localhost:" + webUiPort
  readonly property string statusText: Model.statusLabel(runtimeState)
  readonly property string tooltipText: Model.tooltip(runtimeState, autoStartKnown,
    autoStartEnabled, error)

  function boundedDiagnostic(value, fallback) {
    var text = String(value || "").trim()
    if (text.length > 512) text = text.slice(0, 509) + "..."
    return text || fallback
  }

  function applyStatus(raw) {
    var result = Model.parseSystemctl(raw)
    statusKnown = true
    packageMissing = result.missing
    installed = result.installed
    runtimeState = result.runtimeState
    autoStartKnown = result.autoStartKnown
    autoStartEnabled = result.autoStartEnabled
    error = result.error
  }

  function refresh() {
    if (operation.running) {
      queuedStatus = true
      return
    }
    launch("status", null, ["show", unitName, "--property=LoadState",
      "--property=ActiveState", "--property=SubState", "--property=UnitFileState"])
  }

  function queuedKind(family) {
    for (var i = queuedActions.length - 1; i >= 0; i--)
      if (queuedActions[i].family === family) return queuedActions[i].kind
    return ""
  }

  function queueAction(family, kind, target, args) {
    if (!installed || operation.running) {
      if (!installed) return false
      var next = []
      for (var i = 0; i < queuedActions.length; i++)
        if (queuedActions[i].family !== family) next.push(queuedActions[i])
      next.push({ family: family, kind: kind, target: target, args: args })
      queuedActions = next
      return true
    }
    return launch(kind, target, args)
  }

  function setRunning(enabled) {
    if (!installed || transitioning) return false
    if (enabled === runtimeChecked) return true
    return queueAction("runtime", enabled ? "start" : "stop", enabled,
      [enabled ? "start" : "stop", unitName])
  }

  function toggleRuntime() {
    return setRunning(!runtimeChecked)
  }

  function setAutoStart(enabled) {
    if (!installed || !autoStartKnown) return false
    if (enabled === autoStartChecked) return true
    return queueAction("auto-start", enabled ? "enable" : "disable", enabled,
      [enabled ? "enable" : "disable", unitName])
  }

  function launch(kind, target, args) {
    if (operation.running) return false
    currentKind = kind
    currentTarget = target
    timedOut = false
    operation.command = [systemctlCommand, "--user"].concat(args)
    timeoutTimer.restart()
    operation.running = true
    return true
  }

  function drainQueue() {
    if (operation.running) return
    if (queuedStatus) {
      queuedStatus = false
      refresh()
    } else if (queuedActions.length > 0) {
      if (!installed) {
        queuedActions = []
        error = boundedDiagnostic(error + " Pending requests were cancelled.",
          "Sunshine status is unavailable. Pending requests were cancelled.")
        return
      }
      var action = queuedActions[0]
      queuedActions = queuedActions.slice(1)
      var stateKnown = action.family === "runtime"
        ? runtimeState !== "unavailable" : autoStartKnown
      var alreadyApplied = stateKnown && (action.family === "runtime"
        ? action.target === (runtimeState === "on" || runtimeState === "starting")
        : action.target === autoStartEnabled)
      if (alreadyApplied) Qt.callLater(drainQueue)
      else launch(action.kind, action.target, action.args)
    }
  }

  Component.onCompleted: refresh()
  Component.onDestruction: {
    if (pollTimer) pollTimer.stop()
    if (timeoutTimer) timeoutTimer.stop()
    if (actionMessageTimer) actionMessageTimer.stop()
    if (operation && operation.running) operation.running = false
  }

  property FileView sunshineConfig: FileView {
    path: (Quickshell.env("HOME") || "") + "/.config/sunshine/sunshine.conf"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.basePort = Model.parseBasePort(text())
    onLoadFailed: root.basePort = Model.DEFAULT_BASE_PORT
  }

  property Timer pollTimer: Timer {
    interval: 2000
    repeat: true
    running: true
    onTriggered: if (!root.operation.running && root.queuedActions.length === 0) root.refresh()
  }

  property Timer timeoutTimer: Timer {
    interval: 20000
    onTriggered: {
      root.timedOut = true
      root.error = "Sunshine command timed out. Refreshing status."
      root.queuedStatus = true
      if (root.operation.running) root.operation.running = false
    }
  }

  property Timer actionMessageTimer: Timer {
    interval: 3000
    onTriggered: root.actionMessage = ""
  }

  property Process operation: Process {
    running: false
    command: []
    stdout: StdioCollector { id: commandOut; waitForEnd: true }
    stderr: StdioCollector { id: commandErr; waitForEnd: true }

    onExited: function(exitCode) {
      root.timeoutTimer.stop()
      var kind = root.currentKind
      root.currentKind = ""
      root.currentTarget = null
      if (!root.timedOut) {
        if (kind === "status") {
          if (exitCode === 0) root.applyStatus(commandOut.text)
          else if (commandOut.text !== "") root.applyStatus(commandOut.text)
          else {
            root.statusKnown = true
            root.packageMissing = false
            root.installed = false
            root.runtimeState = "unavailable"
            root.autoStartKnown = false
            root.error = root.boundedDiagnostic(commandErr.text,
              "Sunshine service status is unavailable.")
          }
        } else {
          if (exitCode === 0) {
            root.error = ""
            root.actionMessage = kind === "start" ? "Sunshine started."
              : kind === "stop" ? "Sunshine stopped."
              : kind === "enable" ? "Auto-start enabled." : "Auto-start disabled."
          } else {
            root.error = root.boundedDiagnostic(commandErr.text, "Sunshine command failed.")
            root.actionMessage = root.error
          }
          root.actionMessageTimer.restart()
          root.queuedStatus = true
        }
      }
      root.timedOut = false
      Qt.callLater(root.drainQueue)
    }
  }
}
