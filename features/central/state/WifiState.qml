pragma Singleton

import QtQuick
import Quickshell
import qs.core.widgets
import qs.services

// View model da seção Wi-Fi.
Singleton {
    id: root

    readonly property bool available: Network.available && Network.wifiDevice !== null
    readonly property bool enabled: Network.wifiEnabled
    readonly property bool hardwareBlocked: !Network.wifiHardwareEnabled
    readonly property bool wired: Network.kind === "wired"
    // Tile das ações: o nome da rede, "Cabo" (no cabo, sem Wi-Fi conectado)
    // ou o estado; sem placa Wi-Fi, o tile "Rede" diz "Cabo" ou
    // "Desconectado". E o ícone.
    readonly property string summary: Network.wifiNetwork ? Network.wifiNetwork.name : wired ? "Cabo" : !available ? "Desconectado" : hardwareBlocked ? "Bloqueado" : !enabled ? "Desligado" : "Não conectado"
    readonly property string icon: Network.wifiNetwork ? Icons.level(Icons.wifi, Network.signal) : wired ? Icons.ethernet : !available || !enabled || hardwareBlocked ? Icons.wifiOff : Icons.wifi[0]

    readonly property var networks: Network.wifiNetworks.map(n => ({
        network: n,
        name: n.name,
        connected: n.connected,
        known: n.known,
        busy: n.stateChanging,
        secure: Network.isSecure(n),
        needsPassword: Network.needsPassword(n),
        icon: Icons.level(Icons.wifi, n.signalStrength)
    }))

    // Rede com o campo de senha aberto e a senha digitada nele. Ficam aqui, e
    // não na linha, porque a lista acima é refeita a cada mudança das redes (o
    // sinal, uma rede nova) e o Repeater recria as linhas: a linha nova da
    // rede aberta pega a senha daqui (e a posição do cursor). Mude as duas
    // pela expand(); a central zera a senha ao sair da página e ao fechar.
    property var expanded: null
    property string password: ""
    property int cursor: 0
    property string error: ""

    Connections {
        target: Network

        function onConnectionFailed(network, reason) {
            root.error = `Não foi possível conectar a ${network}${reason ? ` (${reason})` : ""}`;
        }
    }

    // A rede aberta saiu da lista (fora de alcance, o Wi-Fi desligou): fecha.
    onNetworksChanged: dropMissing(networks)

    function setEnabled(on: bool): void {
        Network.setWifiEnabled(on);
    }

    // Abre o campo de senha da rede (null fecha), sempre sem senha.
    function expand(network: var): void {
        clearPassword();
        expanded = network;
    }

    function clearPassword(): void {
        password = "";
        cursor = 0;
    }

    // Fecha o campo se a rede aberta não está em `list` (itens de networks).
    function dropMissing(list: var): void {
        if (expanded !== null && !list.some(n => n.network === expanded))
            expand(null);
    }

    // Clique numa rede: desconecta a atual, pede senha ou conecta direto.
    function activate(item: var): void {
        error = "";
        if (item.connected) {
            Network.disconnect(item.network);
        } else if (item.needsPassword) {
            expand(expanded === item.network ? null : item.network);
        } else {
            Network.connect(item.network, "");
        }
    }

    function submitPassword(item: var, secret: string): void {
        if (!secret)
            return;
        Network.connect(item.network, secret);
        expand(null);
    }

    function forget(item: var): void {
        Network.forget(item.network);
    }
}
