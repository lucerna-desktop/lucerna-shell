pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.core.config
import qs.core.theme
import qs.services

// Avisos e automações de energia: bateria baixa e crítica, carga completa,
// carregador, ação no nível crítico, perfil automático e modo leve.
// Não tem interface própria; as opções ficam em Configurações → Energia e bateria.
Singleton {
    id: root

    readonly property bool available: Battery.available
    readonly property int percent: Math.round(Battery.percentage * 100)
    readonly property bool onBattery: Battery.onBattery

    // Cada aviso sai uma vez por descarga: volta a valer ao ligar na tomada.
    property bool lowWarned: false
    property bool criticalWarned: false
    property bool saverApplied: false
    property bool fullNotified: false

    // Ação crítica agendada (com prazo para ligar na tomada e cancelar).
    readonly property int criticalGrace: 60
    property int criticalCountdown: 0

    readonly property var actionNames: ({ suspend: "suspender", hibernate: "hibernar", poweroff: "desligar" })
    // A ação que roda de fato: a escolhida, ou "suspend" no lugar do
    // "hibernate" quando o logind diz que não dá (sem swap).
    readonly property string criticalAction: criticalActionFor(Config.batteryCriticalAction, Logind.canHibernate)

    // O Hibernar escolhido sem hibernação disponível (CanHibernate "no" ou
    // "na") suspende: o systemctl hibernate falharia e a bateria acabaria
    // sem ação. A escolha gravada fica; com o swap de volta, hiberna. Sem
    // resposta do logind, o canHibernate fica true: como antes.
    function criticalActionFor(action: string, canHibernate: bool): string {
        return action === "hibernate" && !canHibernate ? "suspend" : action;
    }

    function notify(title: string, body: string, urgency: string): void {
        Quickshell.execDetached(["notify-send", "-a", "Energia", "-u", urgency, "-i", "battery", title, body]);
    }

    function check(): void {
        if (!available)
            return;
        if (!onBattery) {
            lowWarned = false;
            criticalWarned = false;
            saverApplied = false;
            if (criticalCountdown > 0) {
                criticalCountdown = 0;
                countdown.stop();
                notify("Ação cancelada", "O carregador foi conectado.", "normal");
            }
            if (Battery.full && !fullNotified && Config.batteryNotifyFull) {
                fullNotified = true;
                notify("Bateria carregada", "Pode tirar da tomada.", "low");
            }
            return;
        }
        fullNotified = false;

        if (percent <= Config.batteryCriticalLevel && !criticalWarned) {
            criticalWarned = true;
            lowWarned = true;
            const action = criticalAction;
            if (action !== "none") {
                // O swap pode ter vindo depois da partida: o CanHibernate
                // lido de novo antes do prazo.
                if (Config.batteryCriticalAction === "hibernate")
                    Logind.readCanHibernate();
                criticalCountdown = criticalGrace;
                countdown.start();
                notify(`Bateria crítica: ${percent}%`, `O computador vai ${actionNames[action]} em ${criticalGrace} s. Conecte o carregador para cancelar.`, "critical");
            } else {
                notify(`Bateria crítica: ${percent}%`, "Conecte o carregador agora.", "critical");
            }
        } else if (percent <= Config.batteryLowLevel && !lowWarned) {
            lowWarned = true;
            notify(`Bateria baixa: ${percent}%`, "Conecte o carregador em breve.", "normal");
        }

        if (Config.saverBelowEnabled && percent <= Config.saverBelow && !saverApplied) {
            saverApplied = true;
            Battery.setProfile(0);
        }
    }

    function runCriticalAction(): void {
        const action = criticalAction;
        if (action === "suspend")
            Session.suspend();
        else if (action === "hibernate")
            Session.hibernate();
        else if (action === "poweroff")
            Session.poweroff();
    }

    onPercentChanged: check()
    onAvailableChanged: check()

    onOnBatteryChanged: {
        if (!available)
            return;
        if (Config.batteryNotifyPlug)
            notify(onBattery ? "Na bateria" : "Carregador conectado", onBattery ? `${percent}% restantes.` : `Carregando a partir de ${percent}%.`, "low");
        if (Config.autoProfile)
            Battery.setProfile(onBattery ? Config.profileOnBattery : Config.profileOnAC);
        check();
    }

    Timer {
        id: countdown

        interval: 1000
        repeat: true
        onTriggered: {
            root.criticalCountdown -= 1;
            if (root.criticalCountdown <= 0) {
                stop();
                if (root.onBattery)
                    root.runCriticalAction();
            }
        }
    }

    // Modo leve: só na bateria e se o usuário pediu.
    Binding {
        target: ThemeManager
        property: "lightMode"
        value: Config.batteryLightMode && root.available && root.onBattery
    }

    IpcHandler {
        target: "energy"

        // A ação que roda no nível crítico (a escolhida, ou "suspend" no
        // lugar do "hibernate" sem hibernação disponível).
        function criticalAction(): string {
            return root.criticalAction;
        }
    }
}
