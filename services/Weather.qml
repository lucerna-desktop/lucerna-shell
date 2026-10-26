pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// O clima, vindo do módulo web do lucernad (o tópico web.weather): o daemon
// busca (Open-Meteo), guarda e publica; aqui só o que chega, a busca de cidade
// (pelo Web) e a escolha, que o DashboardState salva na config pelo `located`.
// A cidade e o intervalo quem manda é o Web, no web.configure.
Singleton {
    id: root

    // Não é readonly: os testes trocam por um cliente próprio.
    property var client: Lucernad.client
    // Quem usa decide (o DashboardState): a aba Painel ou Clima à mostra.
    property bool active: false

    // { temp, feels, humidity, wind, code, isDay } ou null
    property var current: null
    // [{ date: "AAAA-MM-DD", max, min, code, rainChance }], até 7 dias
    property var daily: []
    // "HH:MM" do dia de hoje na cidade; "" sem dado.
    property string sunrise: ""
    property string sunset: ""
    property var updatedAt: null
    // "none", "loading", "ready" ou "error" ("" sem nada recebido).
    property string state: ""
    property string error: ""
    // { name, latitude, longitude } ou null: a do tópico.
    property var location: null
    readonly property bool loading: state === "loading"

    // A busca de cidade: [{ name, label, latitude, longitude }].
    property var results: []
    property bool searching: false
    property string searchError: ""
    property string lastQuery: ""
    // Conta as buscas: só a resposta da última vale (repetir o texto também).
    property int searchSeq: 0

    signal located(var location)

    function wantedTopics(active: bool): var {
        return active ? ["web.weather"] : [];
    }

    function sync(): void {
        client.want("weather", wantedTopics(active));
    }

    function toCurrent(c: var): var {
        return {
            temp: c.temperature,
            feels: c.apparent,
            humidity: c.humidity,
            wind: c.wind,
            code: c.code,
            isDay: c.isDay === true
        };
    }

    function toDay(d: var): var {
        return {
            date: String(d.date ?? ""),
            max: d.max,
            min: d.min,
            code: d.code,
            rainChance: d.precipitation ?? 0
        };
    }

    // "2026-10-24T05:41" → "05:41"; qualquer outra coisa → "".
    function clock(iso: string): string {
        const m = /T(\d{2}:\d{2})/.exec(String(iso ?? ""));
        return m ? m[1] : "";
    }

    // Um estado recebido do daemon; `null` e tópico desconhecido não mudam nada.
    function apply(topic: string, data: var): void {
        if (data === null || data === undefined)
            return;
        if (topic === "web.weather")
            applyWeather(data);
    }

    function applyWeather(data: var): void {
        current = data.current ? toCurrent(data.current) : null;
        daily = Array.from(data.daily ?? []).map(d => toDay(d));
        sunrise = clock(data.sunrise);
        sunset = clock(data.sunset);
        updatedAt = typeof data.updatedAt === "number" ? new Date(data.updatedAt * 1000) : null;
        state = String(data.state ?? "");
        error = data.error ? String(data.error) : "";
        location = data.location ?? null;
    }

    function clear(): void {
        current = null;
        daily = [];
        sunrise = "";
        sunset = "";
        updatedAt = null;
        state = "";
        error = "";
        location = null;
    }

    // A conexão mudou: ao cair, o clima some; nos dois casos a assinatura vai de novo.
    function connectionChanged(connected: bool): void {
        if (!connected)
            clear();
        sync();
    }

    // Procura a cidade pelo nome; a resposta de uma busca que não é a última se perde.
    function search(name: string): void {
        const query = name.trim();
        if (query === "")
            return;
        lastQuery = query;
        searchSeq++;
        const seq = searchSeq;
        searching = true;
        searchError = "";
        Web.searchCity(query, reply => searchDone(query, seq, reply));
    }

    function searchDone(query: string, seq: int, reply: var): void {
        if (seq !== searchSeq)
            return;
        searching = false;
        if (reply?.error) {
            results = [];
            searchError = String(reply.error.message ?? "");
            return;
        }
        results = Array.from(reply?.result?.results ?? []).map(r => toResult(r));
        searchError = results.length === 0 ? `Não encontrei "${query}"` : "";
    }

    function toResult(r: var): var {
        return {
            name: [r.name, r.state, r.countryCode].filter(x => x).join(", "),
            label: [r.name, r.state, r.country].filter(x => x).join(" · "),
            latitude: Number(r.latitude),
            longitude: Number(r.longitude)
        };
    }

    // Escolhe um resultado: emite `located` e devolve o nome ("" fora da lista).
    function choose(index: int): string {
        const r = results[index];
        if (!r)
            return "";
        located({
            name: r.name,
            latitude: r.latitude,
            longitude: r.longitude
        });
        results = [];
        return r.name;
    }

    function refresh(): void {
        Web.refresh();
    }

    // Velha: sem previsão ou mais antiga que o intervalo de atualização.
    function isStale(): bool {
        return !updatedAt || Date.now() - updatedAt.getTime() > Web.refreshMinutes * 60 * 1000;
    }

    onActiveChanged: sync()

    Connections {
        target: root.client

        function onReceived(topic: string, data: var): void {
            root.apply(topic, data);
        }

        function onConnectedChanged(): void {
            root.connectionChanged(root.client.connected);
        }
    }

    IpcHandler {
        target: "weather"

        // Busca cidades pelo nome (o resultado fica nas configurações).
        function search(query: string): void {
            root.search(query);
        }

        // Escolhe a cidade da última busca; devolve o nome ("" sem resultado).
        function choose(index: int): string {
            return root.choose(index);
        }

        // Atualiza o clima agora.
        function refresh(): void {
            root.refresh();
        }
    }

    Component.onCompleted: sync()
}
