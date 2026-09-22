pragma ComponentBehavior: Bound

import QtQuick
import qs.Ui as Ui

Ui.BarWidget {
  id: root
  moduleName: "lightqv.sunshine"

  readonly property var service: bar && bar.shell ? bar.shell.serviceFor(moduleName) : null
  readonly property var panelAnchor: button
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item
    ? panelLoader.item.popoutSwitchClosing === true : false
  readonly property bool hideWhenOff: setting("hideWhenOff", false) === true
  readonly property bool concealed: hideWhenOff && !opened && service && service.statusKnown
    && service.installed && service.runtimeState === "off"

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    target.bar = root.bar
    target.settings = root.settings
    target.anchorItem = button
    target.hostWidget = root
    target.service = root.service
  }

  function open() { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function togglePanel() { if (panelLoader.item) panelLoader.item.toggle() }
  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  implicitWidth: concealed ? 0 : button.implicitWidth
  implicitHeight: button.implicitHeight
  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()
  onServiceChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  Ui.BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󱟿"
    concealed: root.concealed
    keepSpace: false
    dimmed: !root.service || !root.service.statusKnown
      || root.service.runtimeState === "off" || root.service.runtimeState === "stopping"
      || root.service.runtimeState === "unavailable"
    active: root.service && root.service.failed
    tooltipText: root.service ? root.service.tooltipText : "Sunshine service unavailable"
    Accessible.role: Accessible.Button
    Accessible.name: tooltipText
    Accessible.onPressAction: root.togglePanel()
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton) {
        if (root.service) root.service.toggleRuntime()
      } else if (buttonCode === Qt.LeftButton) root.togglePanel()
    }
  }
}
