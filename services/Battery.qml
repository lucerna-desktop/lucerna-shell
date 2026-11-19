pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import qs.core.config

// Bateria do notebook, via UPower. `available` é falso em desktops.
//
// No modo de desenvolvimento dá para simular a bateria por IPC, para testar
// avisos e automações sem tirar o notebook da tomada:
//   qs -c lucerna ipc call battery simulate 12 true   (12%, na bateria)
//   qs -c lucerna ipc call battery real
Singleton {
    id: root

    // { percentage (0-1), onBattery } ou null (valores reais)
    property var simulated: null

    readonly property UPowerDevice device: UPower.displayDevice
    readonly property bool available: simulated !== null || realBattery
    readonly property real percentage: simulated ? simulated.percentage : (device?.percentage ?? 0)
    readonly property bool onBattery: simulated ? simulated.onBattery : UPower.onBattery
    readonly property bool charging: simulated ? !simulated.onBattery && simulated.percentage < 1 : (device?.state === UPowerDeviceState.Charging || device?.state === UPowerDeviceState.PendingCharge)
    readonly property bool full: simulated ? !simulated.onBattery && simulated.percentage >= 1 : device?.state === UPowerDeviceState.FullyCharged
    // Bateria baixa: no limite das configurações ou abaixo, e sem carregar (a
    // barra e a central mostram em vermelho). Arredondada como o aviso da
    // feature energy, para o vermelho e o aviso coincidirem.
    readonly property real low: Config.batteryLowLevel / 100
    readonly property bool isLow: Math.round(percentage * 100) / 100 <= low && !charging
    // Segundos até esvaziar (descarregando) ou encher (carregando); 0 se desconhecido.
    readonly property real timeRemaining: simulated ? 0 : charging ? (device?.timeToFull ?? 0) : (device?.timeToEmpty ?? 0)
    // Potência agora, em W: o consumo na bateria ou a carga na tomada (real
    // mesmo com a bateria simulada; 0 se o UPower não sabe).
    readonly property real rate: Math.abs(device?.changeRate ?? 0)

    // O cliente do lucernad (o módulo power). Não é readonly: os testes trocam
    // por um cliente próprio.
    property var client: Lucernad.client
    // O error do power.status: o módulo pode estar parado com o daemon de pé.
    property string powerError: ""
    // Disponível é conectado e sem `powerError` (o `available` do status não
    // diz se o módulo funciona).
    readonly property bool powerAvailable: client.connected && powerError === ""

    // Consumo da última hora, para o gráfico da central: [{ time (s), value
    // (W), state (o do UPower: 1 carregando, 2 descarregando...) }], do mais
    // antigo ao mais novo, e quando foi lido (historyAt, em s). Vem do
    // power.history do lucernad, assinado só com `historyActive` (a central
    // na página da bateria). `historyError` diz por que o daemon não leu.
    property bool historyActive: false
    property var history: []
    property real historyAt: 0
    property string historyError: ""
    readonly property int historySpan: 3600
    readonly property bool realBattery: (device?.ready ?? false) && device.isLaptopBattery && device.isPresent

    function wantedTopics(active: bool): var {
        return active ? ["power.status", "power.profiles", "power.history"] : ["power.status", "power.profiles"];
    }

    function sync(): void {
        client.want("battery", wantedTopics(historyActive));
    }

    // Um estado recebido do daemon; `null` (o tópico ainda sem amostra) e
    // tópico desconhecido não mudam nada.
    function apply(topic: string, data: var): void {
        if (data === null || data === undefined)
            return;
        switch (topic) {
        case "power.history":
            applyHistory(data);
            break;
        case "power.profiles":
            applyProfiles(data);
            break;
        case "power.status":
            applyStatus(data);
            break;
        }
    }

    // Os pontos do daemon ({ time, rate, state }; o array do sinal é uma lista
    // do QML e vira array de JS antes do filter) em { time, value, state }, do
    // mais antigo ao mais novo; só com tempo e taxa numéricos e taxa >= 0.
    function applyHistory(data: var): void {
        const rows = data.points ? Array.from(data.points) : [];
        history = rows.filter(r => typeof r.time === "number" && typeof r.rate === "number" && r.rate >= 0).map(r => ({
                    time: r.time,
                    value: r.rate,
                    state: r.state ?? 0
                })).sort((a, b) => a.time - b.time);
        historyAt = Date.now() / 1000;
        historyError = data.error ? String(data.error) : "";
    }

    function applyProfiles(data: var): void {
        profilesReported = data.available === true;
    }

    function applyStatus(data: var): void {
        powerError = data.error ? String(data.error) : "";
    }

    // A conexão com o daemon mudou: ao cair, o histórico some (os perfis
    // ficam com o último valor: a troca é do Quickshell); nos dois casos, a
    // assinatura vai de novo.
    function connectionChanged(connected: bool): void {
        if (!connected) {
            history = [];
            historyError = "";
            powerError = "";
        }
        sync();
    }

    onHistoryActiveChanged: sync()
    Component.onCompleted: sync()

    Connections {
        target: root.client

        function onReceived(topic: string, data: var): void {
            root.apply(topic, data);
        }

        function onConnectedChanged(): void {
            root.connectionChanged(root.client.connected);
        }
    }

    // Perfil de energia (power-profiles-daemon): 0 economia, 1 equilibrado, 2 desempenho (o "Turbo").
    // No modo de desenvolvimento a troca é simulada, e o perfil simulado fica aqui.
    property int simulatedProfile: -1
    readonly property int profile: simulatedProfile >= 0 ? simulatedProfile : PowerProfiles.profile
    readonly property bool hasPerformance: PowerProfiles.hasPerformanceProfile
    readonly property var profileNames: ["Economia", "Equilibrado", "Turbo"]

    // O power-profiles-daemon responde no D-Bus do sistema? Vem do power.profiles
    // do lucernad; sem o daemon, fica o último valor conhecido. O PowerProfiles
    // do Quickshell não diz se o serviço existe; sem ele, a central esconde os
    // botões de perfil. `profilesReported` é o último valor do daemon (null
    // antes do primeiro; os testes trocam).
    property var profilesReported: null
    readonly property bool profilesAvailable: profilesFrom(profilesReported, hasPerformance)

    // Com o lucernad fora desde a partida não há último valor: vale o
    // `hasPerformanceProfile` do Quickshell, que só fica verdadeiro com o
    // power-profiles-daemon respondendo (sem o perfil de desempenho, os
    // botões esperam o daemon).
    function profilesFrom(reported: var, performance: bool): bool {
        return reported === null ? performance : reported === true;
    }

    function setProfile(value: int): void {
        if (value === profile)
            return;
        if (DevMode.simulate(`Perfil ${profileNames[value] ?? value}`))
            simulatedProfile = value;
        else
            PowerProfiles.profile = value;
    }

    IpcHandler {
        target: "battery"
        enabled: DevMode.active

        // Simula a bateria (percentual de 0 a 100; na bateria ou na tomada).
        function simulate(percent: int, onBattery: bool): void {
            root.simulated = { percentage: Math.max(0, Math.min(100, percent)) / 100, onBattery: onBattery };
        }

        // Volta aos valores reais.
        function real(): void {
            root.simulated = null;
        }
    }
}
