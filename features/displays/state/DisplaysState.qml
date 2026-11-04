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
// Sem interface própria; o arranjo se monta em Configurações → Monitores.
Singleton {
    id: root

    readonly property string setup: Monitors.setup
    property bool loginWasOn: false

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

    function writeLogin(): void {
        if (!HyprFile.layered && !Config.monitorsAtLogin)
            return;
        const saved = (Config.monitorSetups ?? {})[setup];
        if (!setup || !saved)
            return;
        const specs = Monitors.monitors.filter(m => saved[m.key]).map(m => Object.assign({}, saved[m.key], { name: m.description ? `desc:${m.description}` : m.name }));
        if (specs.length !== Monitors.monitors.length)
            return;
        if (HyprFile.layered)
            HyprFile.setSection("monitors", `-- Monitores: ${setup}\n${Monitors.lua(specs)}`);
        else
            Monitors.writeLoginFile(`${loginHeader}-- Monitores: ${setup}\n${Monitors.lua(specs)}\n`);
    }

    function restore(): void {
        const saved = (Config.monitorSetups ?? {})[setup];
        if (!setup || !saved)
            return;
        // O arranjo é salvo pela chave do monitor; a porta pode ter mudado.
        const specs = Monitors.monitors.filter(m => saved[m.key]).map(m => Object.assign({}, saved[m.key], { name: m.name }));
        if (specs.length === Monitors.monitors.length)
            Monitors.apply(specs);
    }
}
