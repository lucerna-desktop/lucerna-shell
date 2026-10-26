pragma Singleton

import QtQuick
import Quickshell
import qs.services

// A rede externa, vinda do módulo web do lucernad: o estado (web.status) e a
// configuração (modo offline, chave do Vagalume, cidade e intervalo), que só
// este singleton manda, inteira, a cada conexão e a cada mudança. A letra e o
// clima ficam nos adaptadores deles (Lyrics e Weather); aqui também a busca de
// cidade e o pedido de atualizar. Sem o daemon, `available` fica falso.
Singleton {
    id: root

    // Não é readonly: os testes trocam por um cliente próprio.
    property var client: Lucernad.client
    // O error do web.status: o módulo pode estar indisponível com o daemon de pé.
    property string error: ""
    // Se o daemon acha que tem internet (com o módulo de pé).
    property bool moduleOnline: false
    // Disponível é conectado e sem `error`.
    readonly property bool available: client.connected && error === ""
    readonly property bool online: available && moduleOnline

    // A configuração; quem usa decide (as Bindings do DashboardState).
    property bool offline: true
    // A chave do Vagalume, do próprio usuário: só vai ao lucernad pelo configure.
    property string vagalumeKey: ""
    // { name, latitude, longitude } ou null.
    property var location: null
    property int refreshMinutes: 30

    // Emitido depois do configure de uma conexão: a faixa só vai depois dele.
    signal configured

    function wantedTopics(): var {
        return ["web.status"];
    }

    function sync(): void {
        client.want("web", wantedTopics());
    }

    // O web.configure inteiro (o que falta vai como null, o padrão do daemon);
    // o intervalo só vale de 5 a 1440 minutos.
    function configureParams(): var {
        const place = location ? {
            name: String(location.name ?? ""),
            latitude: Number(location.latitude),
            longitude: Number(location.longitude)
        } : null;
        const validRefresh = Number.isInteger(refreshMinutes) && refreshMinutes >= 5 && refreshMinutes <= 1440;
        return {
            offline: offline,
            vagalumeKey: vagalumeKey !== "" ? vagalumeKey : null,
            location: place,
            refresh: validRefresh ? refreshMinutes : null
        };
    }

    // Só com a conexão feita. O connectionChanged chama o sync() antes; o que
    // importa é o configure chegar ao daemon antes do web.track (o Lyrics só o
    // manda depois do `configured`).
    function configure(): void {
        if (client.connected)
            client.call("web.configure", configureParams(), null);
    }

    // Um estado recebido do daemon; `null` (o tópico ainda sem estado) e
    // tópico desconhecido não mudam nada.
    function apply(topic: string, data: var): void {
        if (data === null || data === undefined)
            return;
        if (topic === "web.status")
            applyStatus(data);
    }

    function applyStatus(data: var): void {
        error = data.error ? String(data.error) : "";
        moduleOnline = data.online === true;
    }

    // A conexão mudou: ao cair, o estado some; nos dois casos a assinatura vai
    // de novo e, conectado, a configuração e depois o aviso `configured`.
    function connectionChanged(connected: bool): void {
        if (!connected) {
            error = "";
            moduleOnline = false;
        }
        sync();
        if (connected) {
            configure();
            configured();
        }
    }

    // Atualiza o clima e refaz a letra com erro, sem esperar resposta.
    function refresh(): void {
        client.call("web.refresh", {}, null);
    }

    // Busca cidades pelo nome; `done` recebe a resposta inteira.
    function searchCity(query: string, done: var): void {
        client.call("web.searchCity", {
            query: query
        }, done);
    }

    onOfflineChanged: configure()
    onVagalumeKeyChanged: configure()
    onLocationChanged: configure()
    onRefreshMinutesChanged: configure()

    Connections {
        target: root.client

        function onReceived(topic: string, data: var): void {
            root.apply(topic, data);
        }

        function onConnectedChanged(): void {
            root.connectionChanged(root.client.connected);
        }
    }

    Component.onCompleted: sync()
}
