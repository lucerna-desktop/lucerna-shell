pragma Singleton

import QtQuick
import Quickshell
import qs.core.config
import qs.services

// O modo jogo, vindo do módulo game do lucernad (dono "game"): o estado
// (game.state), se o módulo está de pé (game.status), a configuração
// (game.configure), que só este singleton manda, inteira, a cada conexão e a
// cada mudança das preferências, e a lista "nunca" de fábrica (game.defaults,
// lida a cada conexão). A exceção dos serviços que só leem o Config: a
// migração da cópia antiga do gameNever, que roda sem a página aberta. O lucernad é a fonte da verdade: as features
// só derivam o comportamento delas de `active` (nada do modo jogo é gravado no
// Config além das preferências game*). Sem o daemon, `available` fica falso, e
// a conexão que cai desliga a parte do shell na hora, em silêncio.
Singleton {
    id: root

    // Não é readonly: os testes trocam por um cliente próprio.
    property var client: Lucernad.client
    // O error do game.status: o módulo pode estar indisponível com o daemon de pé.
    property string error: ""
    // Disponível é conectado e sem `error`.
    readonly property bool available: client.connected && error === ""
    readonly property string unavailableNote: {
        if (available)
            return "";
        if (!client.connected)
            return "Indisponível: sem conexão com o lucernad.";
        return `Indisponível: ${error}`;
    }

    // O game.state.
    property bool active: false
    // "on", "off" ou "" (sem trava manual).
    property string manual: ""
    // Subconjunto de ["manual", "fullscreen", "game", "always"], nessa ordem.
    property var reasons: []
    property var windows: []
    // Desde quando está ligado (ms desde a época), 0 desligado.
    property real since: 0
    // O since da última sessão que terminou (para o resumo das notificações).
    property real lastSince: 0
    readonly property var effectIds: ["compositor", "vrr", "tearing", "profile", "gamemode", "light"]
    property var effects: offEffects()
    // Se já chegou o primeiro estado desta conexão: os avisos só valem depois (D19).
    property bool seenState: false

    // Uma troca de `active` vista com a conexão de pé, depois do primeiro
    // estado: só ela mostra os avisos (o OSD e o resumo).
    signal changedByDaemon(bool active)

    // As preferências que o configure manda, ligadas ao Config pelos Bindings
    // do fim; os testes trocam direto.
    property bool autoFullscreen: true
    property bool autoGames: true
    property var always: []
    // null: a lista do usuário não existe e vale a de fábrica do daemon (o
    // configure vai sem `never`, e o daemon usa a dele).
    property var never: null
    property bool effectsOn: true
    property bool vrr: true
    property bool tearing: false
    property bool profile: true
    property bool gamemode: true
    property bool light: true

    readonly property int maxClasses: 100
    readonly property int maxClassLength: 128

    // A lista "nunca" de fábrica do daemon (o game.defaults), limpa; null
    // enquanto não veio ou com um lucernad sem o método. Não zera quando a
    // conexão cai: a de fábrica só muda com outra versão do daemon, e a próxima
    // conexão lê de novo.
    property var factoryNever: null
    // A lista "nunca" que vale: a do usuário ou, sem ela, a de fábrica (vazia
    // se ainda não veio).
    readonly property var effectiveNever: never ?? factoryNever ?? []

    function offEffects(): var {
        const out = {};
        for (const id of effectIds)
            out[id] = "off";
        return out;
    }

    function wantedTopics(): var {
        return ["game.state", "game.status"];
    }

    function sync(): void {
        client.want("game", wantedTopics());
    }

    // As classes como o daemon aceita: aparadas, minúsculas, sem vazias nem
    // repetidas, cada uma até 128 caracteres e no máximo 100.
    function cleanClasses(list: var): var {
        const out = [];
        for (const item of Array.from(list ?? [])) {
            const cls = String(item ?? "").trim().toLowerCase();
            if (cls === "" || cls.length > maxClassLength || out.includes(cls))
                continue;
            out.push(cls);
            if (out.length === maxClasses)
                break;
        }
        return out;
    }

    // Duas listas limpas com as mesmas classes, em qualquer ordem.
    function sameClasses(a: var, b: var): bool {
        const x = cleanClasses(a);
        const y = cleanClasses(b);
        return x.length === y.length && x.every(c => y.includes(c));
    }

    // A lista "nunca" como o Config guarda: null (a de fábrica) quando ela tem
    // as mesmas classes da de fábrica, senão a própria lista.
    function storedNever(list: var): var {
        return factoryNever !== null && sameClasses(list, factoryNever) ? null : list;
    }

    // O game.configure inteiro (o Formato do lucernad); sem a lista do usuário,
    // sem o `never` (o campo ausente é a de fábrica, também num lucernad sem o
    // game.defaults).
    function configureParams(): var {
        const params = {
            auto: {
                fullscreen: autoFullscreen,
                games: autoGames
            },
            always: cleanClasses(always)
        };
        if (never !== null && never !== undefined)
            params.never = cleanClasses(never);
        params.compositor = {
            effects: effectsOn,
            vrr: vrr,
            tearing: tearing
        };
        params.system = {
            profile: profile,
            gamemode: gamemode,
            light: light
        };
        return params;
    }

    // Uma mudança das preferências: as do mesmo turno (a página grava uma
    // chave por vez; as listas mudam a cada atribuição) viram um configure só.
    property bool configurePending: false

    function requestConfigure(): void {
        if (configurePending)
            return;
        configurePending = true;
        Qt.callLater(root.flushConfigure);
    }

    function flushConfigure(): void {
        if (!configurePending)
            return;
        configurePending = false;
        configure();
    }

    function configure(): void {
        if (client.connected)
            client.call("game.configure", configureParams(), null);
    }

    function readDefaults(): void {
        if (client.connected)
            client.call("game.defaults", {}, response => root.applyDefaults(response));
    }

    // A resposta do game.defaults. Um erro do daemon (um lucernad sem o método)
    // deixa a de fábrica desconhecida; a falta de conexão (-1) não muda nada. A
    // lista do Config igual à de fábrica (a cópia que o shell trazia antes do
    // game.defaults) volta a null, para acompanhar a do daemon.
    function applyDefaults(response: var): void {
        const list = response?.result?.never;
        if (Array.isArray(list)) {
            factoryNever = cleanClasses(list);
            if ((Config.gameNever ?? null) !== null && storedNever(Config.gameNever) === null)
                Config.gameNever = null;
        } else if (response?.error && response.error.code !== -1) {
            factoryNever = null;
        }
    }

    // Um estado recebido do daemon; `null` e tópico desconhecido não mudam nada.
    function apply(topic: string, data: var): void {
        if (data === null || data === undefined)
            return;
        if (topic === "game.state")
            applyState(data);
        else if (topic === "game.status")
            applyStatus(data);
    }

    function applyState(data: var): void {
        const was = active;
        const wasSince = since;
        const effectsIn = data.effects ?? {};
        const nextEffects = {};
        for (const id of effectIds)
            nextEffects[id] = effectsIn[id] ? String(effectsIn[id]) : "off";
        manual = data.manual === "on" || data.manual === "off" ? data.manual : "";
        reasons = Array.from(data.reasons ?? []).map(r => String(r));
        windows = Array.from(data.windows ?? []);
        effects = nextEffects;
        since = data.active === true ? Number(data.since ?? 0) || 0 : 0;
        if (was && data.active !== true)
            lastSince = wasSince;
        active = data.active === true;
        const first = !seenState;
        seenState = true;
        if (!first && was !== active)
            changedByDaemon(active);
    }

    function applyStatus(data: var): void {
        error = data.error ? String(data.error) : (data.available === false ? "o módulo do modo jogo não está de pé" : "");
    }

    // A conexão mudou: ao cair, a parte do shell desliga na hora, sem aviso; nos
    // dois casos a assinatura vai de novo e, conectado, a configuração.
    function connectionChanged(connected: bool): void {
        seenState = false;
        if (!connected) {
            error = "";
            active = false;
            manual = "";
            since = 0;
            reasons = [];
            windows = [];
            effects = offEffects();
        }
        sync();
        if (connected) {
            configure();
            readDefaults();
        }
    }

    function set(on: bool): void {
        client.call("game.set", {
            on: on
        }, null);
    }

    function toggle(): void {
        client.call("game.toggle", {}, null);
    }

    // Os motivos em pt-BR, na ordem do Formato ("tela cheia, jogo").
    function reasonsText(list: var): string {
        const names = {
            manual: "manual",
            fullscreen: "tela cheia",
            game: "jogo",
            always: "lista sempre"
        };
        return Array.from(list ?? []).map(r => names[r] ?? String(r)).join(", ");
    }

    // O estado numa linha, para o IPC `game get`: "ligado (tela cheia, jogo)",
    // "ligado", "desligado" ou "indisponível".
    function statusText(isAvailable: bool, isActive: bool, list: var): string {
        if (!isAvailable)
            return "indisponível";
        if (!isActive)
            return "desligado";
        const why = reasonsText(list);
        return why ? `ligado (${why})` : "ligado";
    }

    onAutoFullscreenChanged: requestConfigure()
    onAutoGamesChanged: requestConfigure()
    onAlwaysChanged: requestConfigure()
    onNeverChanged: requestConfigure()
    onEffectsOnChanged: requestConfigure()
    onVrrChanged: requestConfigure()
    onTearingChanged: requestConfigure()
    onProfileChanged: requestConfigure()
    onGamemodeChanged: requestConfigure()
    onLightChanged: requestConfigure()

    Binding {
        target: root
        property: "autoFullscreen"
        value: Config.gameAutoFullscreen
    }

    Binding {
        target: root
        property: "autoGames"
        value: Config.gameAutoGames
    }

    Binding {
        target: root
        property: "always"
        value: Config.gameAlways
    }

    Binding {
        target: root
        property: "never"
        value: Config.gameNever
    }

    Binding {
        target: root
        property: "effectsOn"
        value: Config.gameEffects
    }

    Binding {
        target: root
        property: "vrr"
        value: Config.gameVrr
    }

    Binding {
        target: root
        property: "tearing"
        value: Config.gameTearing
    }

    Binding {
        target: root
        property: "profile"
        value: Config.gameProfile
    }

    Binding {
        target: root
        property: "gamemode"
        value: Config.gameGamemode
    }

    Binding {
        target: root
        property: "light"
        value: Config.gameLight
    }

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
