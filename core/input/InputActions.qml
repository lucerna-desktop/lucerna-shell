pragma Singleton

import QtQuick
import Quickshell
import qs.core.widgets

// O que um botão do mouse ou uma tecla pode fazer, e os nomes amigáveis de
// botões e teclas. Só dados: quem executa é a feature input; quem mostra são
// as configurações.
Singleton {
    id: root

    // kind: "shell" (roda no Lucerna, via IPC; `ipc` diz o alvo e a função,
    // senão é "action run <id>"), "hypr" (dispatch do Hyprland),
    // "shortcut" (envia uma combinação para a janela), "command" (roda um
    // comando), "none" (o botão ou a tecla deixa de fazer qualquer coisa).
    readonly property var actions: [
        { id: "launcher", group: "Lucerna", label: "Abrir o launcher", icon: Icons.apps, kind: "shell" },
        { id: "dashboard", group: "Lucerna", label: "Abrir o painel superior", icon: Icons.dashboard, kind: "shell" },
        { id: "actions", group: "Lucerna", label: "Abrir as ações", icon: Icons.central, kind: "shell" },
        { id: "notifications", group: "Lucerna", label: "Abrir as notificações", icon: Icons.bell, kind: "shell" },
        { id: "central", group: "Lucerna", label: "Abrir a central", icon: Icons.centralBoth, kind: "shell" },
        { id: "settings", group: "Lucerna", label: "Abrir as configurações", icon: Icons.settings, kind: "shell" },
        { id: "overview", group: "Lucerna", label: "Visão geral dos workspaces", icon: "overview_key", kind: "shell" },
        { id: "clipboard", group: "Lucerna", label: "Abrir o histórico da área de transferência", icon: "content_paste", kind: "shell" },
        { id: "capture", group: "Captura", label: "Capturar ou gravar a tela", icon: "screenshot_region", kind: "shell" },
        { id: "capture-screen", group: "Captura", label: "Capturar a tela inteira", icon: "fit_screen", kind: "shell", ipc: "capture screen" },
        { id: "capture-window", group: "Captura", label: "Capturar a janela ativa", icon: "select_window", kind: "shell", ipc: "capture window" },
        { id: "record", group: "Captura", label: "Gravar a tela ou parar", icon: "screen_record", kind: "shell", ipc: "capture record" },
        { id: "themes", group: "Lucerna", label: "Trocar o tema", icon: Icons.palette, kind: "shell" },
        { id: "power", group: "Lucerna", label: "Menu de energia", icon: Icons.power, kind: "shell" },
        { id: "lock", group: "Lucerna", label: "Bloquear a tela", icon: Icons.lock, kind: "shell" },
        { id: "dnd", group: "Lucerna", label: "Ligar/desligar o não perturbe", icon: Icons.bellSleep, kind: "shell" },
        { id: "game", group: "Lucerna", label: "Ligar/desligar o modo jogo", icon: "sports_esports", kind: "shell" },
        { id: "bar", group: "Lucerna", label: "Mostrar/esconder a barra", icon: Icons.toolbar, kind: "shell" },
        { id: "play-pause", group: "Mídia", label: "Tocar/pausar", icon: Icons.play, kind: "shell", locked: true },
        { id: "next", group: "Mídia", label: "Próxima faixa", icon: Icons.next, kind: "shell", locked: true },
        { id: "previous", group: "Mídia", label: "Faixa anterior", icon: Icons.previous, kind: "shell", locked: true },
        { id: "volume-up", group: "Mídia", label: "Aumentar o volume", icon: Icons.volumeUp, kind: "shell", locked: true, repeating: true },
        { id: "volume-down", group: "Mídia", label: "Diminuir o volume", icon: Icons.volumeDown, kind: "shell", locked: true, repeating: true },
        { id: "mute", group: "Mídia", label: "Silenciar o som", icon: Icons.volumeOff, kind: "shell", locked: true },
        { id: "mic-mute", group: "Mídia", label: "Silenciar o microfone", icon: Icons.micOff, kind: "shell", locked: true },
        { id: "brightness-up", group: "Mídia", label: "Aumentar o brilho", icon: Icons.brightnessHigh, kind: "shell", locked: true, repeating: true },
        { id: "brightness-down", group: "Mídia", label: "Diminuir o brilho", icon: Icons.brightnessLow, kind: "shell", locked: true, repeating: true },
        { id: "close", group: "Janelas", label: "Fechar a janela", icon: Icons.close, kind: "hypr", lua: "hl.dsp.window.close()" },
        { id: "fullscreen", group: "Janelas", label: "Tela cheia", icon: Icons.fullscreen, kind: "hypr", lua: "hl.dsp.window.fullscreen()" },
        { id: "float", group: "Janelas", label: "Flutuar/encaixar a janela", icon: Icons.float, kind: "hypr", lua: "hl.dsp.window.float({ action = \"toggle\" })" },
        { id: "pin", group: "Janelas", label: "Fixar em todos os workspaces", icon: Icons.pin, kind: "hypr", lua: "hl.dsp.window.pin()" },
        { id: "workspace-prev", group: "Janelas", label: "Workspace anterior", icon: Icons.previousWorkspace, kind: "hypr", lua: "hl.dsp.focus({ workspace = \"e-1\" })" },
        { id: "workspace-next", group: "Janelas", label: "Próximo workspace", icon: Icons.nextWorkspace, kind: "hypr", lua: "hl.dsp.focus({ workspace = \"e+1\" })" },
        { id: "shortcut", group: "Outros", label: "Enviar um atalho de teclado", icon: Icons.keyboard, kind: "shortcut" },
        { id: "command", group: "Outros", label: "Rodar um comando", icon: Icons.terminal, kind: "command" },
        { id: "none", group: "Outros", label: "Não fazer nada", icon: Icons.block, kind: "none" }
    ]

    // Ids que mudaram de nome (o antigo → o novo): um botão ou tecla salvo
    // com o antigo segue valendo.
    readonly property var renamed: ({ sidebar: "central" })

    function find(id: string): var {
        const real = renamed[id] ?? id;
        return actions.find(a => a.id === real) ?? null;
    }

    // Descrição de uma ação configurada ({ id, keys?, command? }).
    function describe(action: var): string {
        const a = find(action?.id ?? "");
        if (!a)
            return "—";
        if (a.kind === "shortcut")
            return `Enviar ${prettyCombo(action.mods ?? "", action.key ?? "")}`;
        if (a.kind === "command")
            return `Rodar “${action.command ?? ""}”`;
        return a.label;
    }

    // Botões do mouse: botão do Qt → código do Linux (o que o Hyprland usa em
    // "mouse:NNN"), na ordem em que o QtWayland os traduz (BTN_SIDE em diante).
    // Esquerdo e direito ficam de fora de propósito.
    readonly property var mouseButtons: [
        { qt: Qt.MiddleButton, code: 274, label: "Botão do meio" },
        { qt: Qt.BackButton, code: 275, label: "Botão lateral (voltar)" },
        { qt: Qt.ForwardButton, code: 276, label: "Botão lateral (avançar)" },
        { qt: Qt.TaskButton, code: 277, label: "Botão extra (avançar)" },
        { qt: Qt.ExtraButton4, code: 278, label: "Botão extra (voltar)" },
        { qt: Qt.ExtraButton5, code: 279, label: "Botão de tarefa" },
        { qt: Qt.ExtraButton6, code: 280, label: "Botão extra 1" },
        { qt: Qt.ExtraButton7, code: 281, label: "Botão extra 2" },
        { qt: Qt.ExtraButton8, code: 282, label: "Botão extra 3" },
        { qt: Qt.ExtraButton9, code: 283, label: "Botão extra 4" },
        { qt: Qt.ExtraButton10, code: 284, label: "Botão extra 5" },
        { qt: Qt.ExtraButton11, code: 285, label: "Botão extra 6" },
        { qt: Qt.ExtraButton12, code: 286, label: "Botão extra 7" },
        { qt: Qt.ExtraButton13, code: 287, label: "Botão extra 8" }
    ]

    function buttonFromQt(qt: int): var {
        return mouseButtons.find(b => b.qt === qt) ?? null;
    }

    function buttonLabel(code: int): string {
        return mouseButtons.find(b => b.code === code)?.label ?? `Botão ${code}`;
    }

    // Símbolos do xkb com nome em português.
    readonly property var symbolNames: ({
        "Escape": "Esc", "Return": "Enter", "KP_Enter": "Enter do teclado numérico", "space": "Espaço", "Tab": "Tab",
        "BackSpace": "Backspace", "Delete": "Delete", "Insert": "Insert", "Home": "Home", "End": "End",
        "Prior": "Page Up", "Next": "Page Down", "Up": "Seta para cima", "Down": "Seta para baixo",
        "Left": "Seta para a esquerda", "Right": "Seta para a direita", "Caps_Lock": "Caps Lock", "Num_Lock": "Num Lock",
        "Scroll_Lock": "Scroll Lock", "Print": "Print Screen", "Pause": "Pause", "Menu": "Menu",
        "Control_L": "Ctrl esquerdo", "Control_R": "Ctrl direito", "Shift_L": "Shift esquerdo", "Shift_R": "Shift direito",
        "Alt_L": "Alt esquerdo", "Alt_R": "Alt direito", "ISO_Level3_Shift": "Alt Gr", "Super_L": "Super esquerdo",
        "Super_R": "Super direito", "Hyper_L": "Hyper", "Multi_key": "Compose", "NoSymbol": "Nada",
        "XF86AudioPlay": "Tocar/pausar", "XF86AudioPause": "Pausar", "XF86AudioNext": "Próxima faixa",
        "XF86AudioPrev": "Faixa anterior", "XF86AudioStop": "Parar", "XF86AudioRaiseVolume": "Volume +",
        "XF86AudioLowerVolume": "Volume −", "XF86AudioMute": "Mudo", "XF86AudioMicMute": "Microfone mudo",
        "XF86MonBrightnessUp": "Brilho +", "XF86MonBrightnessDown": "Brilho −", "XF86Calculator": "Calculadora",
        "XF86Mail": "E-mail", "XF86HomePage": "Página inicial", "XF86Search": "Pesquisar", "XF86Explorer": "Arquivos",
        "XF86Tools": "Ferramentas", "XF86Favorites": "Favoritos", "XF86Back": "Voltar", "XF86Forward": "Avançar",
        "XF86Launch1": "Iniciar 1", "XF86Launch2": "Iniciar 2", "XF86Sleep": "Dormir", "XF86PowerOff": "Desligar"
    })

    function prettySymbol(sym: string): string {
        if (!sym)
            return "?";
        if (symbolNames[sym])
            return symbolNames[sym];
        if (sym.length === 1)
            return sym.toUpperCase();
        return sym.replace(/^XF86/, "").replace(/_/g, " ");
    }

    readonly property var modNames: ({ SUPER: "Super", CTRL: "Ctrl", ALT: "Alt", SHIFT: "Shift" })

    function prettyCombo(mods: string, sym: string): string {
        const parts = mods ? mods.split(/\s+/).filter(m => m).map(m => modNames[m] ?? m) : [];
        return parts.concat([prettySymbol(sym)]).join(" + ");
    }

    // Modificadores do Qt → os do Hyprland ("SUPER CTRL").
    function modsFromQt(modifiers: int): string {
        const out = [];
        if (modifiers & Qt.MetaModifier)
            out.push("SUPER");
        if (modifiers & Qt.ControlModifier)
            out.push("CTRL");
        if (modifiers & Qt.AltModifier)
            out.push("ALT");
        if (modifiers & Qt.ShiftModifier)
            out.push("SHIFT");
        return out.join(" ");
    }

    // Teclas que são só modificadores (não fecham uma combinação).
    readonly property var modifierKeys: [Qt.Key_Shift, Qt.Key_Control, Qt.Key_Alt, Qt.Key_Meta, Qt.Key_Super_L, Qt.Key_Super_R, Qt.Key_AltGr, Qt.Key_Hyper_L, Qt.Key_Hyper_R]

    // Alvos prontos para remapear uma tecla. "key" copia outra tecla do
    // keymap (inclusive se for modificador); "sym" põe um símbolo.
    readonly property var remapTargets: [
        { label: "Esc", to: { kind: "key", value: "ESC" } },
        { label: "Ctrl esquerdo", to: { kind: "key", value: "LCTL" } },
        { label: "Alt esquerdo", to: { kind: "key", value: "LALT" } },
        { label: "Super", to: { kind: "key", value: "LWIN" } },
        { label: "Shift esquerdo", to: { kind: "key", value: "LFSH" } },
        { label: "Caps Lock", to: { kind: "key", value: "CAPS" } },
        { label: "Backspace", to: { kind: "key", value: "BKSP" } },
        { label: "Enter", to: { kind: "key", value: "RTRN" } },
        { label: "Tab", to: { kind: "key", value: "TAB" } },
        { label: "Delete", to: { kind: "key", value: "DELE" } },
        { label: "Home", to: { kind: "key", value: "HOME" } },
        { label: "End", to: { kind: "key", value: "END" } },
        { label: "Page Up", to: { kind: "key", value: "PGUP" } },
        { label: "Page Down", to: { kind: "key", value: "PGDN" } },
        { label: "Print Screen", to: { kind: "key", value: "PRSC" } },
        { label: "Menu", to: { kind: "key", value: "COMP" } },
        { label: "Tocar/pausar", to: { kind: "sym", value: "XF86AudioPlay" } },
        { label: "Próxima faixa", to: { kind: "sym", value: "XF86AudioNext" } },
        { label: "Faixa anterior", to: { kind: "sym", value: "XF86AudioPrev" } },
        { label: "Volume +", to: { kind: "sym", value: "XF86AudioRaiseVolume" } },
        { label: "Volume −", to: { kind: "sym", value: "XF86AudioLowerVolume" } },
        { label: "Mudo", to: { kind: "sym", value: "XF86AudioMute" } },
        { label: "F13", to: { kind: "sym", value: "F13" } },
        { label: "F14", to: { kind: "sym", value: "F14" } },
        { label: "F15", to: { kind: "sym", value: "F15" } },
        { label: "F16", to: { kind: "sym", value: "F16" } },
        { label: "Nada (desativar a tecla)", to: { kind: "none" } }
    ]
}
