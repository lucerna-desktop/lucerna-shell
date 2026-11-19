pragma Singleton

import QtQuick
import Quickshell
import qs.services

// Espectro do som do player exibido (Media.active), vindo do módulo spectrum
// do lucernad: `values` traz 40 faixas de 0 a 1, das graves às agudas, já
// suavizadas. Só assina com `active` (quem mostra pede); sem o daemon,
// `values` fica vazio e o anel parado.
Singleton {
    id: root

    property bool active: false
    readonly property var client: Lucernad.client
    // O spectrum.status do daemon: o módulo pode estar indisponível com o
    // daemon de pé (sem PipeWire, um erro interno).
    property bool moduleAvailable: false
    readonly property int bars: 40
    // [0..1] por barra; vazio parado ou sem quadro.
    property var values: []
    // O nome D-Bus do player exibido; vazio sem player. Não é readonly: os
    // testes põem um nome (o MPRIS não roda no CI) e voltam com o Qt.binding.
    property string player: Media.active?.dbusName ?? ""

    // As faixas juntadas de duas em duas, pelo maior de cada par (a média
    // achataria o soco de uma faixa só): a metade das faixas, para quem
    // desenha menos barras com as mesmas frequências. Um número ímpar de
    // faixas deixa a última sozinha.
    function pairMax(values: var): var {
        const out = [];
        for (let i = 0; i < values.length; i += 2)
            out.push(i + 1 < values.length ? Math.max(values[i], values[i + 1]) : values[i]);
        return out;
    }

    // Os tópicos a assinar: o estado sempre; os quadros só com `active`.
    function wantedTopics(active: bool): var {
        const topics = ["spectrum.status"];
        if (active)
            topics.push("spectrum.bands");
        return topics;
    }

    function sync(): void {
        client.want("spectrum", wantedTopics(active));
    }

    // O player vai como nome, ou null sem player.
    function playerParam(name: string): var {
        return name === "" ? null : name;
    }

    // Diz ao daemon qual player seguir, só com a conexão feita (a cada
    // conexão nova, o connectionChanged manda de novo).
    function configure(): void {
        if (client.connected)
            client.call("spectrum.configure", {
                player: playerParam(player)
            }, null);
    }

    // Um estado recebido do daemon; `null` (o tópico ainda sem amostra) e
    // tópico desconhecido não mudam nada.
    function apply(topic: string, data: var): void {
        if (data === null || data === undefined)
            return;
        switch (topic) {
        case "spectrum.bands":
            applyBands(data);
            break;
        case "spectrum.status":
            applyStatus(data);
            break;
        }
    }

    // Um quadro só vale pedindo e com as 40 faixas, todas números. O array que
    // vem do sinal do cliente é uma lista do QML (Array.isArray dá falso):
    // vira array de JS.
    function applyBands(data: var): void {
        const bands = data.bands ? Array.from(data.bands) : [];
        if (active && bands.length === bars && bands.every(v => typeof v === "number" && isFinite(v)))
            values = bands;
    }

    function applyStatus(data: var): void {
        moduleAvailable = data.available === true;
    }

    // A conexão com o daemon mudou: ao cair, o módulo some e o quadro velho
    // também; nos dois casos, a assinatura e o player vão de novo.
    function connectionChanged(connected: bool): void {
        if (!connected) {
            moduleAvailable = false;
            values = [];
        }
        sync();
        configure();
    }

    onActiveChanged: {
        if (!active)
            values = [];
        sync();
    }

    onPlayerChanged: configure()

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
