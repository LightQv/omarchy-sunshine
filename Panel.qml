pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui as Ui

Ui.Panel {
  id: root
  moduleName: "lightqv.sunshine"
  manageIpc: false

  property var shell: null
  property var manifest: null
  property var service: null
  property var anchorItem: null
  property var hostWidget: null
  property int cursorIndex: 1
  property bool cursorActive: false

  readonly property var svc: service || (shell && typeof shell.serviceFor === "function"
    ? shell.serviceFor(moduleName) : null)
  readonly property var barIdentity: hostWidget || root
  readonly property color foreground: bar ? bar.barForeground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.45)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property bool packageMissing: svc && svc.statusKnown && svc.packageMissing
  readonly property bool controlsVisible: svc && svc.statusKnown && svc.installed

  function resolveHost() {
    if (!bar && shell && shell.bar) bar = shell.bar
    if (!hostWidget && bar && typeof bar.moduleWidgets === "function") {
      var widgets = bar.moduleWidgets(moduleName)
      if (widgets.length > 0) hostWidget = widgets[0]
    }
    if (!anchorItem && hostWidget && hostWidget.panelAnchor) anchorItem = hostWidget.panelAnchor
  }

  function open() {
    resolveHost()
    controller.show()
    if (svc) svc.refresh()
  }
  function close() { controller.hide() }
  function toggle() { opened ? close() : open() }
  function switchPanel(direction) {
    return bar && typeof bar.switchPanelFrom === "function"
      ? bar.switchPanelFrom(barIdentity, direction) : false
  }

  function moveCursor(dy) {
    if (!controlsVisible) return
    cursorActive = true
    cursorIndex = Math.max(0, Math.min(3, cursorIndex + dy))
  }

  function activateCursor() {
    if (!controlsVisible || !svc) return
    if (cursorIndex === 0) svc.toggleRuntime()
    else if (cursorIndex === 1) Qt.openUrlExternally(svc.webUiUrl)
    else if (cursorIndex === 2) saveSetting("hideWhenOff", !setting("hideWhenOff", false))
    else if (cursorIndex === 3) svc.setAutoStart(!svc.autoStartChecked)
  }

  function saveSetting(key, value) {
    var next = {}
    for (var name in settings) if (name !== "id") next[name] = settings[name]
    next[key] = value
    root.settings = next
    if (bar && bar.shell && typeof bar.shell.updateEntryInline === "function")
      bar.shell.updateEntryInline(moduleName, next)
  }

  Component.onCompleted: resolveHost()
  onShellChanged: resolveHost()
  onOpenedChanged: if (opened) {
    cursorIndex = controlsVisible ? 1 : 0
    cursorActive = false
    if (svc) svc.refresh()
    Qt.callLater(keyCatcher.forceActiveFocus)
  }

  Ui.KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(content.implicitHeight)

    Ui.PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function(dx, dy) { if (dy !== 0) root.moveCursor(dy) }
      onActivateRequested: root.activateCursor()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(text) {
        if ((text === "o" || text === "O") && root.cursorIndex === 1
            && root.controlsVisible && root.svc) Qt.openUrlExternally(root.svc.webUiUrl)
      }

      Column {
        id: content
        width: parent.width
        spacing: Style.space(12)

        Item {
          id: header
          width: parent.width
          implicitHeight: hero.implicitHeight
          readonly property var panelService: root.svc

          Ui.PanelHero {
            id: hero
            width: parent.width
            title: "Sunshine"
            meta: root.svc ? root.svc.statusText : "Unavailable"
            foreground: root.foreground
            fontFamily: root.fontFamily
            iconOpacity: root.svc && root.svc.running ? 1.0 : 0.5
            iconComponent: Component {
              Text {
                text: "󱟿"
                color: header.panelService && header.panelService.failed
                  ? root.urgent : root.foreground
                font.family: root.fontFamily
                font.pixelSize: hero.iconSize
              }
            }
            trailingControl: Component {
              Ui.ToggleSwitch {
                id: powerSwitch
                visible: root.controlsVisible
                enabled: root.controlsVisible && !root.svc.transitioning
                checked: root.svc ? root.svc.runtimeChecked : false
                busy: root.svc ? root.svc.runtimeBusy : false
                hasCursor: root.cursorActive && root.cursorIndex === 0
                foreground: root.foreground
                onHovered: function(value) { if (value) { root.cursorActive = true; root.cursorIndex = 0 } }
                onToggled: if (root.svc) root.svc.toggleRuntime()
                Accessible.role: Accessible.CheckBox
                Accessible.name: checked ? "Stop Sunshine" : "Start Sunshine"
                Accessible.checked: checked
                Accessible.onPressAction: if (root.svc) root.svc.toggleRuntime()
                Ui.PanelToolTip {
                  visible: powerSwitch.containsMouse
                  text: powerSwitch.checked ? "Stop Sunshine" : "Start Sunshine"
                  fontFamily: root.fontFamily
                }
              }
            }
          }
        }

        Ui.PanelSeparator { foreground: root.foreground }

        Column {
          visible: !root.svc || !root.svc.statusKnown
          width: parent.width
          spacing: Style.space(8)
          Text {
            width: parent.width
            text: "Checking Sunshine…"
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            horizontalAlignment: Text.AlignHCenter
          }
        }

        Column {
          visible: root.packageMissing
          width: parent.width
          spacing: Style.space(8)
          Text {
            width: parent.width
            text: "Sunshine is not installed"
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
            textFormat: Text.PlainText
          }
          Text {
            width: parent.width
            text: "Install the Sunshine package to use runtime controls and the Web UI."
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            textFormat: Text.PlainText
          }
        }

        Column {
          visible: root.svc && root.svc.statusKnown && !root.svc.installed
            && !root.svc.packageMissing
          width: parent.width
          spacing: Style.space(8)
          Text {
            width: parent.width
            text: "Sunshine status is unavailable"
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
            textFormat: Text.PlainText
          }
          Text {
            width: parent.width
            text: root.svc ? root.svc.error : "Unable to query the Sunshine user service."
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            textFormat: Text.PlainText
          }
        }

        Column {
          visible: root.controlsVisible
          width: parent.width
          spacing: Style.space(8)

          Ui.CursorSurface {
            id: webRow
            width: parent.width
            implicitHeight: webContent.implicitHeight + Style.spacing.rowPaddingX
            hasCursor: root.cursorActive && root.cursorIndex === 1
            foreground: root.foreground
            Accessible.role: Accessible.Button
            Accessible.name: "Open Sunshine Web UI"
            Accessible.description: root.svc ? root.svc.webUiUrl : ""
            Accessible.onPressAction: if (root.svc) Qt.openUrlExternally(root.svc.webUiUrl)

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onEntered: { root.cursorActive = true; root.cursorIndex = 1 }
              onClicked: if (root.svc) Qt.openUrlExternally(root.svc.webUiUrl)
            }
            RowLayout {
              id: webContent
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              anchors.leftMargin: Style.space(10)
              anchors.rightMargin: Style.space(10)
              spacing: Style.space(10)
              ColumnLayout {
                Layout.fillWidth: true
                spacing: Style.space(1)
                Text {
                  text: "Web UI"
                  color: root.foreground; font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                }
                Text {
                  Layout.fillWidth: true
                  text: root.svc ? root.svc.webUiUrl : ""
                  color: root.dim; font.family: root.fontFamily
                  font.pixelSize: Style.font.caption; elide: Text.ElideRight
                }
              }
              Text {
                text: "󰏌"
                color: root.dim; font.family: root.fontFamily
                font.pixelSize: Style.font.icon
              }
            }
          }

          ToggleRow {
            label: "Hide icon when off"
            detail: "Keep the bar clear until Sunshine starts"
            checked: root.setting("hideWhenOff", false) === true
            rowIndex: 2
            onActivated: root.saveSetting("hideWhenOff", !checked)
          }

          ToggleRow {
            label: "Auto-start on login"
            detail: "Does not start or stop Sunshine now"
            checked: root.svc ? root.svc.autoStartChecked : false
            busy: root.svc ? root.svc.autoStartBusy : false
            enabled: root.svc ? root.svc.autoStartKnown : false
            rowIndex: 3
            onActivated: if (root.svc) root.svc.setAutoStart(!checked)
          }

          Text {
            width: parent.width
            visible: root.svc && (root.svc.error !== "" || root.svc.actionMessage !== "")
            text: root.svc ? (root.svc.error || root.svc.actionMessage) : ""
            color: root.svc && root.svc.error !== "" ? root.urgent : root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
            textFormat: Text.PlainText
          }

          Text {
            width: parent.width
            text: "Arrows/jk move  ·  Enter/Space select  ·  O opens Web UI  ·  Tab changes panel  ·  Esc closes"
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            textFormat: Text.PlainText
          }
        }
      }
    }
  }

  component ToggleRow: Ui.CursorSurface {
    id: toggleRow
    property string label: ""
    property string detail: ""
    property bool checked: false
    property bool busy: false
    property int rowIndex: 0
    signal activated()

    width: parent ? parent.width : 0
    implicitHeight: toggleContent.implicitHeight + Style.spacing.rowPaddingX
    hasCursor: root.cursorActive && root.cursorIndex === rowIndex
    foreground: root.foreground
    Accessible.role: Accessible.CheckBox
    Accessible.name: label
    Accessible.description: detail
    Accessible.checked: checked
    Accessible.onPressAction: if (enabled && !busy) activated()

    MouseArea {
      anchors.fill: parent
      enabled: toggleRow.enabled
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onEntered: { root.cursorActive = true; root.cursorIndex = toggleRow.rowIndex }
      onClicked: if (!toggleRow.busy) toggleRow.activated()
    }
    RowLayout {
      id: toggleContent
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(10)
      anchors.rightMargin: Style.space(10)
      spacing: Style.space(8)
      ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.space(1)
        Text {
          Layout.fillWidth: true
          text: toggleRow.label
          color: toggleRow.enabled ? root.foreground : root.dim
          font.family: root.fontFamily; font.pixelSize: Style.font.body
          elide: Text.ElideRight
        }
        Text {
          Layout.fillWidth: true
          text: toggleRow.detail
          color: root.dim; font.family: root.fontFamily
          font.pixelSize: Style.font.caption; elide: Text.ElideRight
        }
      }
      Ui.ToggleSwitch {
        checked: toggleRow.checked
        busy: toggleRow.busy
        interactive: false
        foreground: root.foreground
        Layout.alignment: Qt.AlignVCenter
      }
    }
  }
}
