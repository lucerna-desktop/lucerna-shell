pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.core.config

// Ponte entre features: diz quais painéis estão abertos.
//
// Três tipos:
// - modais (launcher, themes, power, central): ficam sozinhos, abrir um fecha
//   os outros;
// - acompanhante (o dashboard, se a config deixa): fica aberto junto da base,
//   sem cobrir a barra;
// - base (settings): abrir fecha os outros, mas o acompanhante aberto depois
//   fica por cima dela.
// Um clique fora de todos (numa janela) fecha os não modais; Esc fecha só o
// que está com o teclado.
Singleton {
    id: root

    readonly property var companions: (Config.panelsTogether ?? []).filter(n => n === "dashboard")
    readonly property var bases: ["settings"]
    // Os painéis que existem. O IPC ignora outros nomes: um `panels open
    // sidebar` velho fecharia o que estava aberto e deixaria um modal sem janela.
    readonly property var names: ["launcher", "dashboard", "central", "settings", "themes", "power", "clipboard", "capture", "overview"]

    // Nomes abertos, na ordem em que abriram.
    property var opened: []
    // O último aberto.
    readonly property string current: opened.length ? opened[opened.length - 1] : ""
    readonly property bool anyOpen: opened.length > 0
    readonly property bool modalOpen: opened.some(n => isModal(n))

    // Um painel que deixou de ser acompanhante (mudança na config) não fica
    // aberto junto: sobra só ele.
    onCompanionsChanged: {
        const modals = opened.filter(n => isModal(n));
        if (modals.length && opened.length > 1)
            opened = [modals[modals.length - 1]];
    }

    function isCompanion(name: string): bool {
        return companions.includes(name);
    }

    function isPanel(name: string): bool {
        return names.includes(name);
    }

    function isModal(name: string): bool {
        return !isCompanion(name) && !bases.includes(name);
    }

    function open(name: string): void {
        if (!isCompanion(name))
            opened = [name];
        else if (!opened.includes(name))
            opened = opened.filter(n => !isModal(n)).concat([name]);
    }

    // Fecha todos.
    function close(): void {
        opened = [];
    }

    // Fecha só este.
    function dismiss(name: string): void {
        disturb();
        opened = opened.filter(n => n !== name);
    }

    function toggle(name: string): void {
        if (isOpen(name))
            dismiss(name);
        else
            open(name);
    }

    // Janelas que não fecham os acompanhantes ao receber um clique: as dos
    // painéis e as da barra. Cada uma se registra ao ser criada.
    property var surfaces: []

    function register(window: var): void {
        surfaces = surfaces.concat([window]);
    }

    function unregister(window: var): void {
        surfaces = surfaces.filter(w => w !== window);
    }

    // O grab também cai sem clique fora: ao fechar o painel que estava com o
    // teclado (o Hyprland manda o teclado para fora) e quando as telas mudam.
    // A decisão espera um instante; se houve uma dessas perto e ainda sobra
    // algum aberto, arma de novo em vez de fechar.
    property real lastDisturb: 0
    property bool rearming: false

    function disturb(): void {
        lastDisturb = Date.now();
    }

    Connections {
        target: Quickshell

        function onScreensChanged() {
            root.disturb();
        }
    }

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (event.name.startsWith("monitor"))
                root.disturb();
        }
    }

    // Só fecha se nada mudou desde que o grab caiu: um painel aberto nesse
    // meio-tempo não é fechado por um clique fora que aconteceu antes dele.
    Timer {
        id: clearedCheck

        property real at: 0
        property string snapshot: ""

        interval: 250
        onTriggered: {
            if (root.opened.join(" ") !== snapshot)
                return;
            if (root.anyOpen && Math.abs(root.lastDisturb - at) < 1000) {
                root.rearming = true;
                Qt.callLater(() => root.rearming = false);
            } else {
                root.close();
            }
        }
    }

    HyprlandFocusGrab {
        id: grab

        active: root.anyOpen && !root.modalOpen && !root.rearming
        windows: root.surfaces
        onCleared: {
            // Desativar o grab (fechar o último painel) também avisa; não é clique fora.
            if (!grab.active || !root.anyOpen)
                return;
            clearedCheck.at = Date.now();
            clearedCheck.snapshot = root.opened.join(" ");
            clearedCheck.restart();
        }
    }

    function isOpen(name: string): bool {
        return opened.includes(name);
    }

    // Central: um painel modal só, com dois sub-estados independentes, as
    // Ações (em cima) e as Notificações (embaixo). Ela está aberta enquanto um
    // dos dois estiver; fechada por fora (outro modal, Esc, `panels close`),
    // zera os dois. A entrada diz por onde as Ações abriram e qual página delas
    // já vem aberta: "rede" (o Wi-Fi), "bluetooth", "som" (a saída de áudio),
    // "energia" (a bateria) e "microfone" (só pelo IPC); "notificacoes" e ""
    // abrem o estado inicial.
    readonly property var centralEntries: ["rede", "bluetooth", "som", "notificacoes", "energia", "microfone"]
    property string centralEntry: ""
    property bool actionsOpen: false
    property bool notificationsOpen: false

    // A cada abertura das Ações ou troca de entrada, com a entrada que valeu.
    signal actionsOpened(string entry)

    // A central fechada não guarda nada: a próxima abertura começa do zero.
    // Aberta pelo nome (`panels open central`, sem sub-estado), abre os dois.
    onOpenedChanged: {
        if (!opened.includes("central")) {
            actionsOpen = false;
            notificationsOpen = false;
        } else if (!actionsOpen && !notificationsOpen) {
            actionsOpen = true;
            notificationsOpen = true;
        }
    }

    // As Ações fechadas esquecem a entrada, mesmo com as Notificações abertas.
    onActionsOpenChanged: {
        if (!actionsOpen)
            centralEntry = "";
    }

    // Os dois sub-estados de uma vez: a central abre quando um fica aberto e
    // fecha quando os dois fecham.
    function setCentral(actions: bool, notifications: bool): void {
        actionsOpen = actions;
        notificationsOpen = notifications;
        if (actions || notifications)
            open("central");
        else if (isOpen("central"))
            dismiss("central");
    }

    // Abre as Ações na entrada (uma desconhecida vale como ""); abertas, troca
    // de entrada. As Notificações ficam como estão.
    function openActions(entry: string): void {
        setCentral(true, notificationsOpen);
        centralEntry = centralEntries.includes(entry) ? entry : "";
        actionsOpened(centralEntry);
    }

    function closeActions(): void {
        setCentral(false, notificationsOpen);
    }

    // Fecha as Ações se já estiverem abertas pela mesma entrada, ou se a
    // pedida é a vazia (o atalho fecha de qualquer entrada); senão abre ou troca.
    function toggleActions(entry: string): void {
        if (actionsOpen && (entry === centralEntry || !centralEntries.includes(entry)))
            closeActions();
        else
            openActions(entry);
    }

    function openNotifications(): void {
        setCentral(actionsOpen, true);
    }

    function closeNotifications(): void {
        setCentral(actionsOpen, false);
    }

    function toggleNotifications(): void {
        setCentral(actionsOpen, !notificationsOpen);
    }

    // Abre os dois. A entrada, se houver, define a página das Ações; sem ela,
    // Ações já abertas ficam na página em que estão.
    function openCentral(entry: string): void {
        if (entry !== "" || !actionsOpen) {
            openActions(entry);
            openNotifications();
        } else {
            setCentral(true, true);
        }
    }

    // O atalho geral (sem entrada, ou com uma desconhecida): fecha os dois se
    // os dois estão abertos; senão abre o que falta. Com entrada: fecha os dois
    // só se os dois estão abertos por ela; senão abre o que falta e troca a página.
    function toggleCentral(entry: string): void {
        const own = centralEntries.includes(entry) ? entry : "";
        if (actionsOpen && notificationsOpen && (own === "" || own === centralEntry))
            setCentral(false, false);
        else
            openCentral(own);
    }

    // O ícone da barra dessa entrada fica aceso: as Ações abertas por ela.
    function actionsAt(entry: string): bool {
        return actionsOpen && centralEntry === entry;
    }

    IpcHandler {
        target: "panels"

        // A central abre os dois.
        function open(name: string): void {
            if (name === "central")
                root.openCentral("");
            else if (root.isPanel(name))
                root.open(name);
        }

        function close(): void {
            root.close();
        }

        function dismiss(name: string): void {
            root.dismiss(name);
        }

        function toggle(name: string): void {
            if (name === "central" && !root.isOpen(name))
                root.openCentral("");
            else if (root.isPanel(name))
                root.toggle(name);
        }

        function get(): string {
            return root.opened.join(" ");
        }
    }
}
