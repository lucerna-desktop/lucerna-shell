pragma Singleton

import QtQuick
import Quickshell
import qs.services

// A letra da faixa, vinda do módulo web do lucernad (o tópico web.lyrics): o
// daemon busca (LRCLIB, Vagalume), guarda e publica; aqui só a faixa que vai
// pelo web.track, a letra que volta e a linha atual. `lines` é [{ time (s),
// text }], com time -1 sem tempo; vazio se não houver letra.
Singleton {
    id: root

    // Não é readonly: os testes trocam por um cliente próprio.
    property var client: Lucernad.client
    // Quem usa decide (o DashboardState): a aba Mídia à mostra e a letra ligada.
    property bool active: false

    property var lines: []
    property bool synced: false
    // "searching", "found", "none" ou "error" ("" sem nada recebido).
    property string state: ""
    // "lrclib" ou "vagalume"; `url` é a página da letra (só do Vagalume).
    property string source: ""
    property string url: ""
    property string error: ""
    property string key: ""
    readonly property bool loading: state === "searching"

    // A faixa do Media; muda a cada título, artista, álbum ou duração.
    readonly property string trackKey: `${Media.artist}\u0000${Media.title}\u0000${Media.album}\u0000${Math.round(Media.length)}`

    function wantedTopics(active: bool): var {
        return active ? ["web.lyrics"] : [];
    }

    function sync(): void {
        client.want("lyrics", wantedTopics(active));
    }

    function trackParams(title: string, artist: string, album: string, length: real): var {
        return {
            title: title,
            artist: artist,
            album: album,
            duration: length > 0 ? length : null
        };
    }

    // Diz ao daemon a faixa de agora, sem esperar resposta (a letra chega pelo tópico).
    function sendTrack(): void {
        if (client.connected)
            client.call("web.track", trackParams(Media.title, Media.artist, Media.album, Media.length), null);
    }

    function toLine(l: var): var {
        return {
            time: typeof l.time === "number" ? l.time : -1,
            text: String(l.text ?? "")
        };
    }

    // Um estado recebido do daemon; `null` e tópico desconhecido não mudam nada.
    function apply(topic: string, data: var): void {
        if (data === null || data === undefined)
            return;
        if (topic === "web.lyrics")
            applyLyrics(data);
    }

    function applyLyrics(data: var): void {
        lines = Array.from(data.lines ?? []).map(l => toLine(l));
        synced = data.synced === true;
        state = String(data.state ?? "");
        source = String(data.source ?? "");
        const link = String(data.url ?? "");
        url = link.startsWith("https://") ? link : "";
        error = data.error ? String(data.error) : "";
        key = String(data.key ?? "");
    }

    function clear(): void {
        lines = [];
        synced = false;
        state = "";
        source = "";
        url = "";
        error = "";
        key = "";
    }

    // A conexão mudou: ao cair, a letra some; a faixa não vai daqui, e sim
    // pelo Web.configured (o configure chega antes dela).
    function connectionChanged(connected: bool): void {
        if (!connected)
            clear();
        sync();
    }

    // O papel de uma linha para a formatação: "current" (a cantada agora),
    // "past" (já cantada), "next" (por vir) ou "plain" (letra sem tempo).
    function lineRole(index: int, current: int, synced: bool): string {
        if (!synced)
            return "plain";
        return index === current ? "current" : index < current ? "past" : "next";
    }

    // Índice da linha atual para uma posição, em segundos; -1 antes da primeira.
    function lineAt(position: real): int {
        if (!synced)
            return -1;
        let i = -1;
        while (i + 1 < lines.length && lines[i + 1].time <= position)
            i++;
        return i;
    }

    onActiveChanged: sync()
    onTrackKeyChanged: sendTrack()

    Connections {
        target: root.client

        function onReceived(topic: string, data: var): void {
            root.apply(topic, data);
        }

        function onConnectedChanged(): void {
            root.connectionChanged(root.client.connected);
        }
    }

    Connections {
        target: Web

        function onConfigured(): void {
            root.sendTrack();
        }
    }

    Component.onCompleted: sync()
}
