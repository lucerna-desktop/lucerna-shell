pragma Singleton

import QtQuick
import Quickshell
import qs.core.config
import qs.core.format
import qs.services

// View model da aba Mídia: faixa, controles e letra.
Singleton {
    id: root

    readonly property bool available: Media.available
    readonly property string title: Media.title || "Sem título"
    readonly property string artist: Media.artist
    // O álbum só quando acrescenta algo ao título.
    readonly property string album: Media.albumShown(Media.album, Media.title)
    readonly property string art: Media.artUrl
    readonly property string player: Media.identity
    readonly property bool playing: Media.playing
    readonly property real progress: Media.length > 0 ? Media.position / Media.length : 0
    readonly property string positionText: Format.clock(Media.position)
    readonly property string lengthText: Format.clock(Media.length)
    readonly property int playerCount: Media.players.length
    readonly property bool canSeek: Media.canSeek

    // O espectro em volta da capa (lido do DashboardState, o mesmo do card da
    // aba Painel); desligável nas configurações.
    readonly property bool visualizer: Config.audioPulse
    // A aba à mostra.
    readonly property bool onScreen: DashboardState.isShowing("media")
    // Anima só com a aba à mostra e tocando.
    readonly property bool live: onScreen && Media.playing

    // Letra
    readonly property bool lyricsEnabled: Config.lyricsEnabled
    readonly property bool offline: Config.offline
    readonly property var lyrics: Lyrics.lines
    readonly property bool lyricsLoading: Lyrics.loading
    readonly property bool lyricsSynced: Lyrics.synced
    readonly property int currentLine: Lyrics.lineAt(Media.position + 0.3)

    // O aviso no lugar da letra (vazio com linhas).
    readonly property string lyricsNote: {
        if (lyrics.length > 0)
            return "";
        if (Config.offline)
            return "Modo offline: a letra não é buscada";
        if (!Web.available)
            return Web.error === "" ? "Indisponível: sem conexão com o lucernad." : `Indisponível: ${Web.error}`;
        if (Lyrics.loading)
            return "Procurando a letra…";
        if (Lyrics.error !== "")
            return Lyrics.error;
        return "Sem letra";
    }

    function togglePlaying(): void {
        Media.togglePlaying();
    }

    function next(): void {
        Media.next();
    }

    function previous(): void {
        Media.previous();
    }

    function seek(fraction: real): void {
        Media.seek(fraction);
    }

    // Passa para o próximo player (o ícone de troca ao lado do nome).
    function cyclePlayer(): void {
        Media.cycle();
    }

    // A linha da letra clicada: vai para o tempo dela.
    function seekTo(seconds: real): void {
        Media.seekTo(seconds);
    }

    function lineRole(index: int, current: int): string {
        return Lyrics.lineRole(index, current, Lyrics.synced);
    }
}
