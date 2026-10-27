pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.core.config
import qs.core.launcher
import qs.core.panels
import qs.core.widgets
import qs.services

// View model do launcher, o mesmo para os três estilos (compacto, completo e
// tela cheia): o que se busca, onde (categoria), os resultados, o item
// selecionado e o que dá para fazer com ele. Só a apresentação muda de um
// estilo para o outro.
Singleton {
    id: root

    readonly property bool open: Panels.isOpen("launcher")
    readonly property var screen: Hypr.focusedScreen
    readonly property string style: ["compact", "full", "grid"].includes(Config.launcherStyle) ? Config.launcherStyle : "compact"

    property string query: ""
    property string category: "apps"
    // Tela cheia: categoria dos apps ("" = todos).
    property string appCategory: ""
    property int selected: 0

    onOpenChanged: {
        if (open) {
            query = "";
            category = "apps";
            appCategory = "";
            selected = 0;
        }
    }

    // A busca de arquivos roda depois do evento: dentro dele, o que depende da
    // busca (prefixo, texto sem prefixo) ainda não foi recalculado.
    onQueryChanged: {
        selected = 0;
        Qt.callLater(refreshFiles);
    }

    onCategoryChanged: {
        selected = 0;
        Qt.callLater(refreshFiles);
    }

    onAppCategoryChanged: selected = 0

    function close(): void {
        Panels.close();
    }

    // Categorias do estilo completo: aplicativos, arquivos por tipo e web.
    readonly property var categories: [
        { id: "apps", label: "Aplicativos", icon: Icons.apps },
        { id: "files", label: "Arquivos", icon: "folder" },
        { id: "documents", label: "Documentos", icon: "description" },
        { id: "images", label: "Imagens", icon: "image" },
        { id: "music", label: "Músicas", icon: "music_note" },
        { id: "videos", label: "Vídeos", icon: "movie" },
        { id: "web", label: "Web", icon: "language" }
    ]
    readonly property bool fileCategory: ["files", "documents", "images", "music", "videos"].includes(category)

    function setCategory(id: string): void {
        category = id;
    }

    function cycleCategory(step: int): void {
        const i = categories.findIndex(c => c.id === category);
        const n = categories.length;
        category = categories[((i + step) % n + n) % n].id;
    }

    // Aplicativos
    readonly property var hidden: Config.launcherHidden ?? []
    readonly property var usage: Config.launcherUsage ?? {}
    readonly property var apps: DesktopEntries.applications.values.filter(a => !a.noDisplay && !hidden.includes(a.id))

    function uses(id: string): int {
        return usage[id] ?? 0;
    }

    // Mais usados primeiro, depois por nome.
    readonly property var sortedApps: apps.slice().sort((a, b) => uses(b.id) - uses(a.id) || a.name.localeCompare(b.name))

    // Categorias da tela cheia, pelas categorias principais do freedesktop.
    readonly property var appCategories: [
        { id: "", label: "Todos", match: [] },
        { id: "favorites", label: "Favoritos", match: [] },
        { id: "internet", label: "Internet", match: ["Network", "WebBrowser", "Email", "Chat"] },
        { id: "dev", label: "Desenvolvimento", match: ["Development", "IDE"] },
        { id: "office", label: "Escritório", match: ["Office"] },
        { id: "graphics", label: "Gráficos", match: ["Graphics"] },
        { id: "media", label: "Multimídia", match: ["AudioVideo", "Audio", "Video"] },
        { id: "games", label: "Jogos", match: ["Game"] },
        { id: "system", label: "Sistema", match: ["System", "Settings"] },
        { id: "utility", label: "Utilitários", match: ["Utility", "Accessories"] }
    ]

    function inAppCategory(entry: var, id: string): bool {
        if (!id)
            return true;
        if (id === "favorites")
            return favorites.includes(entry.id);
        const match = appCategories.find(c => c.id === id)?.match ?? [];
        return (entry.categories ?? []).some(c => match.includes(c));
    }

    // Categorias que têm algum app (não mostra chip vazio).
    readonly property var usedAppCategories: appCategories.filter(c => !c.id || (c.id === "favorites" ? favorites.length > 0 : apps.some(a => inAppCategory(a, c.id))))

    // Favoritos: os fixados; sem nenhum, os mais usados.
    readonly property var favorites: Config.launcherFavorites ?? []
    readonly property bool hasPinned: favorites.length > 0
    readonly property var favoriteApps: hasPinned ? favorites.map(id => apps.find(a => a.id === id)).filter(a => a) : sortedApps.filter(a => uses(a.id) > 0).slice(0, 6)

    function isFavorite(id: string): bool {
        return favorites.includes(id);
    }

    function toggleFavorite(id: string): void {
        Config.launcherFavorites = isFavorite(id) ? favorites.filter(f => f !== id) : favorites.concat([id]);
    }

    function hide(id: string): void {
        if (!hidden.includes(id))
            Config.launcherHidden = hidden.concat([id]);
        Config.launcherFavorites = favorites.filter(f => f !== id);
    }

    function unhide(id: string): void {
        Config.launcherHidden = hidden.filter(h => h !== id);
    }

    // Ações do próprio shell. `keywords` ajuda a achar por sinônimos.
    readonly property var actions: [
        { name: "Bloquear tela", description: "Ação do Lucerna", glyph: Icons.lock, keywords: "lock bloqueio", run: () => Session.lock() },
        { name: "Painel", description: "Ação do Lucerna", glyph: Icons.dashboard, keywords: "dashboard calendário clima desempenho mídia música", run: () => Panels.open("dashboard") },
        { name: "Configurações", description: "Ação do Lucerna", glyph: Icons.settings, keywords: "ajustes preferências transparência desfoque blur xray desempenho opacidade animações settings", run: () => Panels.open("settings") },
        { name: "Trocar tema", description: "Ação do Lucerna", glyph: Icons.palette, keywords: "theme cores aparência", run: () => Panels.open("themes") },
        { name: "Notificações", description: "Ação do Lucerna", glyph: Icons.bell, keywords: "central avisos", run: () => Panels.openNotifications() },
        { name: "Wi-Fi", description: "Ação do Lucerna", glyph: Icons.wifiOn, keywords: "rede internet wifi conexão", run: () => Panels.openActions("rede") },
        { name: "Bluetooth", description: "Ação do Lucerna", glyph: Icons.bluetooth, keywords: "fone dispositivos parear", run: () => Panels.openActions("bluetooth") },
        { name: "Som", description: "Ação do Lucerna", glyph: Icons.sound, keywords: "audio volume microfone saída", run: () => Panels.openActions("som") },
        { name: Config.doNotDisturb ? "Desativar não perturbe" : "Ativar não perturbe", description: "Ação do Lucerna", glyph: Icons.bellSleep, keywords: "dnd silêncio silenciar", run: () => Config.doNotDisturb = !Config.doNotDisturb },
        { name: "Menu de energia", description: "Ação do Lucerna", glyph: Icons.power, keywords: "desligar reiniciar suspender sair logout power", run: () => Panels.open("power") }
    ].map(a => Object.assign({ kind: "action" }, a))

    function fromApp(entry: var): var {
        return { kind: "app", id: entry.id, name: entry.name, description: entry.genericName || entry.comment || "", icon: entry.icon, glyph: Icons.application, entry };
    }

    function normalize(text: string): string {
        return (text ?? "").toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, "");
    }

    // Pontua um texto contra a busca: começo do nome > começo de palavra >
    // trecho > letras na ordem (subsequência). O uso desempata.
    function score(q: string, name: string, extra: string): int {
        const n = normalize(name);
        if (n.startsWith(q))
            return 100;
        if (n.split(/[\s\-_.]+/).some(word => word.startsWith(q)))
            return 80;
        if (n.includes(q))
            return 60;
        if (normalize(extra).includes(q))
            return 30;
        let i = 0;
        for (const ch of n)
            if (ch === q[i])
                i++;
        return i === q.length ? 10 : 0;
    }

    // Apps (e ações) para uma busca; `pool` limita os apps (categoria da tela cheia).
    function searchApps(text: string, pool: var, withActions: bool): var {
        const q = normalize(text.trim());
        if (!q)
            return pool.map(fromApp);
        const scored = [];
        for (const entry of pool) {
            const s = score(q, entry.name, `${entry.genericName} ${entry.keywords} ${entry.comment} ${entry.id}`);
            if (s > 0)
                scored.push({ s: s * 1000 + Math.min(999, uses(entry.id)), r: fromApp(entry) });
        }
        if (withActions) {
            for (const action of actions) {
                const s = score(q, action.name, action.keywords);
                if (s > 0)
                    scored.push({ s: s * 1000 - 1, r: action });
            }
        }
        scored.sort((a, b) => b.s - a.s || a.r.name.localeCompare(b.r.name));
        return scored.map(x => x.r);
    }

    // Arquivos
    readonly property var fileKinds: ({ files: "all", documents: "documents", images: "images", music: "music", videos: "videos" })

    // Nos estilos compacto e tela cheia, um prefixo muda o que se busca:
    // "/texto" procura arquivos e "?texto" pesquisa na web.
    readonly property string prefixMode: style === "full" ? "" : query.startsWith("/") ? "files" : query.startsWith("?") ? "web" : ""
    // O texto a buscar, sem o prefixo.
    readonly property string searchText: (prefixMode ? query.slice(1) : query).trim()

    function refreshFiles(): void {
        if (!open)
            return;
        if (style === "full" && fileCategory)
            FileSearch.search(fileKinds[category], searchText);
        else if (prefixMode === "files")
            FileSearch.search("all", searchText);
    }

    readonly property var imageExts: ["png", "jpg", "jpeg", "webp", "gif", "svg", "bmp", "tiff", "heic", "avif"]

    function fileType(name: string): string {
        const ext = name.split(".").pop().toLowerCase();
        if (imageExts.includes(ext))
            return "image";
        if (["mp3", "flac", "ogg", "opus", "m4a", "wav", "aac", "wma"].includes(ext))
            return "music";
        if (["mp4", "mkv", "webm", "mov", "avi", "m4v", "wmv"].includes(ext))
            return "video";
        if (ext === "pdf")
            return "pdf";
        if (["zip", "tar", "gz", "xz", "zst", "7z", "rar"].includes(ext))
            return "archive";
        return "document";
    }

    readonly property var fileGlyphs: ({ image: "image", music: "music_note", video: "movie", pdf: "picture_as_pdf", archive: "folder_zip", document: "description" })

    function fromFile(f: var): var {
        const type = fileType(f.name);
        return Object.assign({ kind: "file", type, glyph: fileGlyphs[type], description: f.dir.replace(Quickshell.env("HOME"), "~") }, f);
    }

    readonly property bool searchingFiles: FileSearch.searching

    // Web
    readonly property var engines: SearchEngines.all
    readonly property var preferredEngine: engines.find(e => e.id === Config.launcherSearchEngine) ?? engines[0]

    // Favoritos primeiro, na ordem em que foram fixados; depois os demais.
    readonly property var appsFavoritesFirst: favorites.map(id => sortedApps.find(a => a.id === id)).filter(a => a).concat(sortedApps.filter(a => !favorites.includes(a.id)))

    function webItems(text: string): var {
        const q = text.trim();
        const list = [preferredEngine].concat(engines.filter(e => e !== preferredEngine));
        return list.map(e => ({ kind: "web", name: e.name, description: q ? `Pesquisar “${q}”` : "Digite o que pesquisar", glyph: "travel_explore", url: e.url, engine: e.id }));
    }

    // Resultados do estilo em uso.
    readonly property var items: {
        if (prefixMode === "files")
            return FileSearch.results.map(fromFile).slice(0, style === "compact" ? 8 : 60);
        if (prefixMode === "web")
            return webItems(searchText);
        if (style === "compact")
            return searchApps(query, appsFavoritesFirst, true).slice(0, 8);
        if (style === "grid")
            return searchApps(query, query.trim() ? sortedApps : appsFavoritesFirst.filter(a => inAppCategory(a, appCategory)), true);
        if (category === "apps")
            return searchApps(query, sortedApps, true);
        if (category === "web")
            return webItems(query);
        return FileSearch.results.map(fromFile);
    }

    readonly property var current: items[Math.min(selected, items.length - 1)] ?? null

    onCurrentChanged: {
        if (current?.kind === "app")
            AppInfo.request(current.id);
    }

    function appInfo(id: string): var {
        return AppInfo.info(id);
    }

    function select(index: int): void {
        selected = Math.max(0, Math.min(index, items.length - 1));
    }

    function move(step: int): void {
        if (items.length)
            select(selected + step);
    }

    // Abrir
    function activate(item: var): void {
        if (!item)
            return;
        if (item.kind === "web" && !searchText)
            return;
        Panels.close();
        if (item.kind === "app") {
            const all = Object.assign({}, usage);
            all[item.id] = (all[item.id] ?? 0) + 1;
            Config.launcherUsage = all;
            item.entry.execute();
        } else if (item.kind === "action") {
            item.run();
        } else if (item.kind === "file") {
            Qt.openUrlExternally(`file://${item.path}`);
        } else if (item.kind === "web") {
            Qt.openUrlExternally(item.url.replace("%s", encodeURIComponent(searchText)));
        }
    }

    // Uma ação do .desktop (Nova janela…), pelo índice.
    function runAction(item: var, index: int): void {
        const action = item?.entry?.actions?.[index];
        if (!action)
            return;
        Panels.close();
        action.execute();
    }

    function openFolder(item: var): void {
        Panels.close();
        Qt.openUrlExternally(`file://${item.dir}`);
    }

    function copy(text: string): void {
        Quickshell.clipboardText = text;
    }

    // O que dá para fazer com um item além de abrir (menu do clique direito e
    // "Mais opções" do estilo completo).
    function optionsFor(item: var): var {
        if (item?.kind === "app")
            return [
                { label: isFavorite(item.id) ? "Tirar dos favoritos" : "Fixar nos favoritos", icon: isFavorite(item.id) ? "star" : "star_outline", shortcut: "Ctrl+F", run: () => toggleFavorite(item.id) },
                { label: "Copiar o comando", icon: "content_copy", shortcut: "", run: () => copy(item.entry.execString || item.entry.command.join(" ")) },
                { label: "Ocultar do launcher", icon: "visibility_off", shortcut: "Ctrl+H", run: () => hide(item.id) }
            ];
        if (item?.kind === "file")
            return [
                { label: "Abrir a pasta", icon: "folder_open", shortcut: "", run: () => openFolder(item) },
                { label: "Copiar o caminho", icon: "content_copy", shortcut: "", run: () => copy(item.path) }
            ];
        return [];
    }

    // Atalhos comuns aos três estilos. Devolve se tratou a tecla.
    function handleShortcut(event: var): bool {
        if (!(event.modifiers & Qt.ControlModifier) || current?.kind !== "app")
            return false;
        if (event.key === Qt.Key_F) {
            toggleFavorite(current.id);
            return true;
        }
        if (event.key === Qt.Key_H) {
            hide(current.id);
            return true;
        }
        return false;
    }

    IpcHandler {
        target: "launcher"

        // Abre numa categoria (apps, files, documents, images, music, videos,
        // web) e, opcionalmente, já com uma busca.
        function open(category: string, text: string): void {
            Panels.open("launcher");
            Qt.callLater(() => {
                if (root.categories.some(c => c.id === category))
                    root.category = category;
                root.query = text ?? "";
            });
        }

        function toggle(): void {
            Panels.toggle("launcher");
        }
    }
}
