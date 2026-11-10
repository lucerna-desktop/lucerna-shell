pragma Singleton

import QtQuick
import Quickshell
import qs.core.config
import qs.services

// Reaplica o arranjo de monitores salvo para o conjunto conectado: ao iniciar,
// quando um monitor entra ou sai e depois de um reload do hyprland.lua. Na
// sessão Lucerna, o arranjo do conjunto conectado vai sempre para a seção
// "monitors" do arquivo do shell (HyprFile), que vale desde o login; fora
// dela, com "desde o login", vai para um arquivo que o hyprland.lua inclui.
// E a tampa do notebook (Monitors.lidPlan): fechada com um monitor externo
// ativo, desliga a tela interna (e bloqueia, com a opção de Energia); aberta,
// ou sem outro monitor sobrando, religa.
// Sem interface própria; o arranjo se monta em Configurações → Monitores.
Singleton {
    id: root

    readonly property string setup: Monitors.setup
    property bool loginWasOn: false
    // O último plano da tampa mandado por um monitor que mudou: o mesmo plano
    // de novo não é mandado (o Hyprland que recusa a mudança não vira laço a
    // cada leitura dos monitores).
    property string lastLidPlan: ""
    // A tampa foi lida antes dos monitores (a lista ainda vazia, na partida):
    // o plano vale na primeira lista que chegar, com a tampa aberta também
    // (a eDP deixada desligada por um shell que caiu enquanto a tampa abria).
    property bool lidWaitsMonitors: false

    onSetupChanged: {
        restore();
        writeLogin();
    }

    Connections {
        target: Config

        function onMonitorSetupsChanged() {
            root.writeLogin();
        }

        // Só limpa o arquivo quando a opção passa de ligada a desligada (o
        // carregamento da config também avisa, e quem nunca ligou fica sem arquivo).
        function onMonitorsAtLoginChanged() {
            if (HyprFile.layered)
                return;
            if (Config.monitorsAtLogin) {
                root.loginWasOn = true;
                root.writeLogin();
            } else if (root.loginWasOn) {
                root.loginWasOn = false;
                Monitors.writeLoginFile(`${root.loginHeader}-- Desligado.\n`);
            }
        }
    }

    // Um reload do hyprland.lua volta os monitores ao que está no arquivo. Na
    // sessão Lucerna, o arquivo do shell já traz o arranjo: não reaplica.
    Connections {
        target: Hypr

        function onConfigReloaded() {
            if (!HyprFile.layered)
                reloadDelay.restart();
        }
    }

    // A tampa abriu ou fechou: o plano inteiro, com o bloqueio. Só nesta
    // virada: um monitor que entra ou sai depois não bloqueia de novo, nem a
    // leitura da tampa na partida (o shell reiniciado com ela fechada).
    // Lida a tampa, o plano vale mesmo sem mudança: o interno apagado por um
    // shell anterior volta com a tampa aberta (o arranjo salvo vem depois).
    Connections {
        target: Logind

        function onLidClosedChanged() {
            root.followLid(Logind.lidFromEvent);
        }

        function onLidRead() {
            root.lidWaitsMonitors = Monitors.monitors.length === 0;
            root.followLid(false);
        }
    }

    // Com a tampa fechada, um monitor que entra ou sai muda o plano (o externo
    // ligado depois de fechar; o externo que sai religa o interno). Com ela
    // aberta, não: um interno desligado nas Configurações fica desligado. A
    // exceção é a primeira lista depois de uma leitura da tampa sem monitores.
    Connections {
        target: Monitors

        function onMonitorsChanged() {
            const waited = root.lidWaitsMonitors;
            if (Monitors.monitors.length)
                root.lidWaitsMonitors = false;
            if (Logind.lidClosed || waited)
                root.followLid(false);
        }
    }

    function followLid(withLock: bool): void {
        const plan = Monitors.lidPlan(Logind.lidClosed, Monitors.monitors, Config.lockOnLidDocked);
        const step = Monitors.lidStep(plan, lastLidPlan, withLock);
        if (!step.send)
            return;
        lastLidPlan = step.last;
        for (const name of plan.disable)
            Monitors.setEnabled(name, false);
        for (const name of plan.enable)
            Monitors.setEnabled(name, true);
        if (plan.enable.length)
            restoreDelay.restart();
        if (withLock && plan.lock)
            Session.lock();
    }

    // O interno religado volta ao arranjo salvo depois que o Hyprland o liga.
    Timer {
        id: restoreDelay

        interval: 300
        onTriggered: root.restore()
    }

    Timer {
        id: reloadDelay

        interval: 300
        onTriggered: root.restore()
    }

    // O arquivo vale para o último conjunto salvo que esteve conectado (no login,
    // costuma ser o mesmo). Cada monitor vai pela descrição, que não depende da
    // porta; sem descrição, pela porta. Ao desligar, o arquivo fica sem regras
    // (o include no hyprland.lua continua inofensivo).
    readonly property string loginHeader: "-- Gerado pelo Lucerna (Configurações → Monitores); é reescrito a cada arranjo salvo.\n"
        + `-- Para usar, no hyprland.lua: ${Monitors.includeLine}\n`

    // O modo de escala mudou (Configurações → Monitores): o arranjo do modo
    // novo. No "Escala pelos apps", os monitores em 1; de volta à escala do
    // monitor, o arranjo salvo.
    Connections {
        target: Config

        function onScaleModeChanged() {
            root.restore();
            root.writeLogin();
        }
    }

    // O arranjo do conjunto conectado no modo de escala atual (a porta de
    // agora em `name`, a descrição em `description`), ou null. No modo
    // "Escala pelos apps", o arranjo salvo dele; sem ele, o da escala do
    // monitor em 1 (Monitors.atScale); com `live`, sem nenhum salvo, os
    // monitores de agora em 1.
    function arrangement(live: bool): var {
        const apps = Config.scaleMode === "apps";
        const saved = Config.monitorSetups ?? {};
        const fromSaved = entry => {
            if (!setup || !entry)
                return null;
            // O arranjo é salvo pela chave do monitor; a porta pode ter mudado.
            const specs = Monitors.monitors.filter(m => entry[m.key]).map(m => Object.assign({}, entry[m.key], { name: m.name, description: m.description }));
            return specs.length === Monitors.monitors.length ? specs : null;
        };
        const own = fromSaved(saved[Monitors.setupKey(setup, apps)]);
        if (own || !apps)
            return own;
        const base = fromSaved(saved[setup]) ?? (live && Monitors.monitors.length ? Monitors.monitors.map(m => Object.assign({}, m)) : null);
        return base ? Monitors.atScale(base, 1) : null;
    }

    function writeLogin(): void {
        if (!HyprFile.layered && !Config.monitorsAtLogin)
            return;
        const specs = arrangement(false);
        if (!specs)
            return;
        const named = specs.map(s => Object.assign({}, s, { name: s.description ? `desc:${s.description}` : s.name }));
        if (HyprFile.layered)
            HyprFile.setSection("monitors", `-- Monitores: ${setup}\n${Monitors.lua(named)}`);
        else
            Monitors.writeLoginFile(`${loginHeader}-- Monitores: ${setup}\n${Monitors.lua(named)}\n`);
    }

    function restore(): void {
        const specs = arrangement(true);
        if (!specs)
            return;
        // Com a tampa fechada e um externo ativo no arranjo, o interno fica
        // desligado (Monitors.withLid).
        Monitors.apply(Monitors.withLid(specs, Logind.lidClosed));
    }
}
