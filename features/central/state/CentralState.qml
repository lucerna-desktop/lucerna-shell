pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.core.frame
import qs.core.panels
import qs.services

// View model da central: os dois painéis flutuantes da direita (Ações em
// cima, Notificações embaixo), que abrem e fecham cada um por si
// (Panels.actionsOpen e Panels.notificationsOpen). O painel de Ações mostra os
// tiles e os sliders ou a página de um recurso (`page`). A entrada
// (Panels.centralEntry) escolhe a página que já vem aberta; sem o recurso, o
// estado inicial. Abrir as Ações volta tudo ao estado inicial (fechá-las não:
// o card fica na página até sumir).
Singleton {
    id: root

    // A janela da central: aberta com qualquer um dos dois.
    readonly property bool open: Panels.isOpen("central")
    readonly property bool actionsOpen: Panels.actionsOpen
    readonly property bool notificationsOpen: Panels.notificationsOpen
    // Fica no monitor onde abriu (ver Panels.screenFor).
    property var openedOn: null
    readonly property var screen: Panels.screenFor(openedOn, Quickshell.screens, Hypr.focusedScreen)
    // O topo do bloco: encostado na moldura de cima (Frame), onde ele se funde.
    readonly property real top: Frame.thickness

    // O que existe na máquina, para as páginas e os tiles.
    readonly property var has: ({
            wifi: WifiState.available,
            bluetooth: BluetoothState.available,
            output: SoundState.available,
            input: SoundState.hasMic,
            power: PowerState.any
        })

    // A página do painel de ações: "" (os tiles e os sliders), "wifi",
    // "bluetooth", "output", "input" ou "battery".
    property string page: ""

    // Zera só ao abrir as Ações: na saída, o card continua na página até sumir.
    onActionsOpenChanged: {
        if (actionsOpen)
            reset();
    }

    // O recurso da página aberta sumiu (o fone saiu, o adaptador some): volta
    // ao estado inicial.
    onHasChanged: page = pageIfPresent(page, has)

    Connections {
        target: Panels

        // A tela é gravada antes de a central abrir: aberta, ela já está nela.
        function onOpening(name) {
            if (name === "central")
                root.openedOn = Hypr.focusedScreen;
        }

        function onActionsOpened(entry) {
            root.page = root.pageFor(entry, root.has);
            root.clearWifi();
        }
    }

    // O Wi-Fi procura redes enquanto a página dele está à mostra.
    Binding {
        target: Network
        property: "scanning"
        value: root.actionsOpen && root.page === "wifi"
    }

    // E a bateria lê o histórico do consumo enquanto a página dela está à mostra.
    Binding {
        target: Battery
        property: "historyActive"
        value: root.actionsOpen && root.page === "battery"
    }

    // A página de cada entrada, se o recurso dela existir.
    function pageFor(entry: string, has: var): string {
        const i = ["rede", "bluetooth", "som", "energia", "microfone"].indexOf(entry);
        return pageIfPresent(i >= 0 ? ["wifi", "bluetooth", "output", "battery", "input"][i] : "", has);
    }

    // A página, se o recurso dela existir; senão, o estado inicial.
    function pageIfPresent(page: string, has: var): string {
        const i = ["wifi", "bluetooth", "output", "input", "battery"].indexOf(page);
        return i >= 0 && has[["wifi", "bluetooth", "output", "input", "power"][i]] ? page : "";
    }

    // Fecha o campo de senha e apaga o erro do Wi-Fi.
    function clearWifi(): void {
        WifiState.expanded = null;
        WifiState.error = "";
    }

    function reset(): void {
        page = "";
        clearWifi();
    }

    function setPage(value: string): void {
        page = value;
    }

    // Fecha os dois (Esc, o clique fora).
    function close(): void {
        Panels.dismiss("central");
    }

    // Os dois painéis. A entrada (rede, bluetooth, som, energia, microfone,
    // notificacoes; "" = nenhuma) escolhe a página das Ações.
    IpcHandler {
        target: "central"

        function open(entry: string): void {
            Panels.openCentral(entry);
        }

        function toggle(entry: string): void {
            Panels.toggleCentral(entry);
        }

        function close(): void {
            root.close();
        }
    }

    // Só as Ações (o nome `controls` não se confunde com o alvo `action`).
    IpcHandler {
        target: "controls"

        function open(entry: string): void {
            Panels.openActions(entry);
        }

        function toggle(entry: string): void {
            Panels.toggleActions(entry);
        }

        function close(): void {
            Panels.closeActions();
        }
    }
}
