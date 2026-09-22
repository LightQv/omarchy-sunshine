pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "Plugin" as Plugin

ShellRoot {
  id: root

  property string failures: ""
  property int phase: 0

  function expect(condition, label) {
    if (!condition) failures += (failures === "" ? "" : ", ") + label
  }

  QtObject {
    id: fakeService

    property bool statusKnown: true
    property bool packageMissing: false
    property bool installed: true
    property string runtimeState: "off"
    property string statusText: "Off"
    property bool running: false
    property bool failed: false
    property bool transitioning: false
    property bool runtimeChecked: false
    property bool runtimeBusy: false
    property bool autoStartKnown: true
    property bool autoStartEnabled: true
    property bool autoStartChecked: true
    property bool autoStartBusy: false
    property string error: ""
    property string actionMessage: ""
    property string webUiUrl: "https://invalid.example.test:49001"
    property int refreshCount: 0
    property int runtimeToggleCount: 0
    property int autoStartCount: 0
    property bool lastAutoStartTarget: true

    function refresh() { refreshCount++ }
    function toggleRuntime() { runtimeToggleCount++; return true }
    function setAutoStart(enabled) {
      autoStartCount++
      lastAutoStartTarget = enabled
      return true
    }
  }

  QtObject {
    id: fakeShell
    property int updateCount: 0
    function updateEntryInline(moduleName, settings) {
      root.expect(moduleName === "lightqv.sunshine", "settings module")
      root.expect(settings.hideWhenOff === true, "settings payload")
      updateCount++
    }
  }

  QtObject {
    id: fakeBar
    property color barForeground: "white"
    property color urgent: "red"
    property string fontFamily: "sans-serif"
    property var shell: fakeShell
    property int switchCount: 0
    property int lastDirection: 0
    function switchPanelFrom(owner, direction) {
      root.expect(owner === panel, "panel identity")
      switchCount++
      lastDirection = direction
      return true
    }
  }

  Item {
    id: anchor
    width: 20
    height: 20
  }

  Plugin.Panel {
    id: panel
    bar: fakeBar
    anchorItem: anchor
    service: fakeService
    settings: ({})
  }

  Component.onCompleted: panel.open()

  Timer {
    interval: 20
    repeat: true
    running: true
    onTriggered: {
      if (root.phase === 0) {
        if (!panel.opened) return
        root.expect(!panel.manageIpc, "nested panel IPC disabled")
        root.expect(fakeService.refreshCount >= 1, "open refresh")
        panel.moveCursor(-20)
        root.expect(panel.cursorIndex === 0 && panel.cursorActive, "cursor lower bound")
        panel.activateCursor()
        root.expect(fakeService.runtimeToggleCount === 1, "runtime activation")
        panel.cursorIndex = 2
        panel.activateCursor()
        root.expect(panel.setting("hideWhenOff", false) === true, "setting activation")
        root.expect(fakeShell.updateCount === 1, "setting persistence")
        panel.cursorIndex = 3
        panel.activateCursor()
        root.expect(fakeService.autoStartCount === 1 && !fakeService.lastAutoStartTarget,
          "auto-start activation")
        panel.moveCursor(20)
        root.expect(panel.cursorIndex === 3, "cursor upper bound")
        root.expect(panel.switchPanel(-1), "panel switch")
        root.expect(fakeBar.switchCount === 1 && fakeBar.lastDirection === -1,
          "panel switch direction")
        panel.close()
        root.phase = 1
        return
      }
      if (root.phase === 1) {
        if (panel.opened) return
        panel.toggle()
        root.phase = 2
        return
      }
      if (!panel.opened) return
      panel.toggle()
      root.expect(!panel.opened, "toggle close")
      fakeService.installed = false
      panel.cursorIndex = 2
      panel.cursorActive = false
      panel.moveCursor(1)
      root.expect(panel.cursorIndex === 2 && !panel.cursorActive,
        "hidden controls ignore navigation")
      console.log(root.failures === "" ? "PANEL_LIFECYCLE_SMOKE_OK"
        : "PANEL_LIFECYCLE_SMOKE_FAILED: " + root.failures)
      Qt.quit()
    }
  }

  Timer {
    interval: 3000
    running: true
    onTriggered: {
      console.log("PANEL_LIFECYCLE_SMOKE_TIMEOUT")
      Qt.quit()
    }
  }
}
