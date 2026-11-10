import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray
import qs.Commons
import qs.Ui

// Ícone do BApet na barra. Não fala com o app por nenhum canal próprio: lê o
// item de bandeja (StatusNotifierItem) que o BApet já publica e desenha o menu
// dele aqui. Se o app ganhar itens novos no menu, eles aparecem sozinhos.
//   clique esquerdo: inicia o app ou, se já está rodando, abre "Add Pet"
//   clique direito:  menu do app (pausar, esconder, settings, sair...)
BarWidget {
  id: root
  moduleName: "bapet.desktop-pets"

  readonly property string trayId: "BlueArchiveDesktopPet"
  readonly property string launcher: Quickshell.env("HOME") + "/.local/bin/BlueArchiveDesktopPet"

  Translations { id: strings; directory: Qt.resolvedUrl("i18n") }

  readonly property var trayItem: {
    var values = SystemTray.items.values
    for (var i = 0; i < values.length; i++) {
      if (String(values[i].id) === trayId) return values[i]
    }
    return null
  }
  readonly property bool running: trayItem !== null

  property bool starting: false
  onRunningChanged: if (running) starting = false

  // Desiste do "iniciando" se o app não registrar a bandeja (ex.: erro de OpenGL)
  Timer {
    id: startTimeout
    interval: 20000
    onTriggered: root.starting = false
  }

  function start() {
    if (running || starting) return
    starting = true
    startTimeout.restart()
    Quickshell.execDetached([launcher])
  }

  // Modo dos pets, escrito por ~/.local/bin/bapet-ghost: "ghost" (cliques
  // atravessam) ou "interactive" (dá para arrastar)
  readonly property string ghostScript: Quickshell.env("HOME") + "/.local/bin/bapet-ghost"
  property bool interactive: false

  FileView {
    path: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/bapet-mode"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.interactive = text().trim() === "interactive"
    onLoadFailed: root.interactive = false
  }

  property bool menuOpen: false
  function close() { menuOpen = false }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "" // nf-fa-paw
    dimmed: !root.running
    tooltipText: root.running ? strings.t("tooltip.on") : strings.t("tooltip.off")
    onPressed: function(b) {
      if (b === Qt.RightButton) {
        root.menuOpen = !root.menuOpen
      } else if (root.running) {
        root.trayItem.activate()
      } else {
        root.start()
      }
    }
  }

  QsMenuOpener {
    id: menuOpener
    menu: root.trayItem ? root.trayItem.menu : null
  }

  PopupCard {
    id: menuPopup
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.menuOpen
    padding: Style.space(8)
    borderColor: Qt.rgba(button.foreground.r, button.foreground.g, button.foreground.b, 0.45)
    contentWidth: menuPopup.fittedContentWidth(Style.space(232))
    contentHeight: menuPopup.fittedContentHeight(menuColumn.implicitHeight, Style.space(420))

    Column {
      id: menuColumn
      anchors.fill: parent
      spacing: 0

      // App desligado: só a opção de iniciar
      MenuRow {
        visible: !root.running
        label: root.starting ? strings.t("menu.starting") : strings.t("menu.start")
        enabled: !root.starting
        onActivated: { root.start(); root.close() }
      }

      MenuRow {
        visible: root.running
        label: strings.t("menu.interactive")
        checkable: true
        checked: root.interactive
        onActivated: { Quickshell.execDetached([root.ghostScript, "toggle"]); root.close() }
      }

      MenuRow {
        visible: root.running
        separator: true
      }

      Repeater {
        model: root.running ? menuOpener.children : []

        delegate: MenuRow {
          required property var modelData
          separator: modelData.isSeparator
          label: String(modelData.text || "")
          enabled: modelData.enabled
          checkable: modelData.buttonType !== QsMenuButtonType.None
          checked: modelData.checkState === Qt.Checked
          onActivated: { modelData.triggered(); root.close() }
        }
      }
    }
  }

  component MenuRow: Item {
    id: row
    property bool separator: false
    property string label: ""
    property bool checkable: false
    property bool checked: false
    signal activated()

    width: menuColumn.width
    implicitHeight: !visible ? 0 : (separator ? Style.space(11) : Style.space(30))
    opacity: enabled ? 1.0 : 0.45

    Rectangle {
      visible: row.separator
      anchors.left: parent.left
      anchors.leftMargin: Style.space(10)
      anchors.right: parent.right
      anchors.rightMargin: Style.space(10)
      anchors.verticalCenter: parent.verticalCenter
      height: 1
      color: Color.popups.border
      opacity: 0.45
    }

    Rectangle {
      visible: !row.separator
      anchors.fill: parent
      radius: Math.max(2, Style.cornerRadius)
      color: rowMouse.containsMouse && row.enabled ? Style.hoverFillFor(button.foreground, button.foreground) : "transparent"
    }

    Text {
      visible: !row.separator && row.checkable
      anchors.verticalCenter: parent.verticalCenter
      anchors.left: parent.left
      width: Style.space(22)
      horizontalAlignment: Text.AlignHCenter
      textFormat: Text.PlainText
      text: row.checked ? "" : "" // nf-fa-check
      color: button.foreground
      font.family: button.fontFamily
      font.pixelSize: Style.font.bodySmall
    }

    Text {
      visible: !row.separator
      anchors.verticalCenter: parent.verticalCenter
      anchors.left: parent.left
      anchors.leftMargin: Style.space(28)
      anchors.right: parent.right
      anchors.rightMargin: Style.space(10)
      textFormat: Text.PlainText
      text: row.label
      color: button.foreground
      font.family: button.fontFamily
      font.pixelSize: Style.font.bodySmall
      elide: Text.ElideRight
    }

    MouseArea {
      id: rowMouse
      anchors.fill: parent
      hoverEnabled: true
      enabled: !row.separator && row.enabled
      cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
      onClicked: row.activated()
    }
  }
}
