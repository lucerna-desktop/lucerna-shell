pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// Toda a conversa com o Hyprland passa por aqui. O Lucerna exige a config em
// Lua (Hyprland 0.56+), então os dispatches são código Lua: hl.dsp.*.
Singleton {
    id: root

    readonly property bool usingLua: Hyprland.usingLua

    // O hyprland.lua foi recarregado: o que o Lucerna aplica por cima
    // (monitores, entrada) precisa ser reaplicado.
    signal configReloaded

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (event.name === "configreloaded")
                root.configReloaded();
        }
    }
    property string version: ""

    // Workspaces normais (ids positivos), em ordem.
    readonly property var workspaces: Hyprland.workspaces.values.filter(w => w.id > 0).sort((a, b) => a.id - b.id)
    readonly property HyprlandWorkspace focusedWorkspace: Hyprland.focusedWorkspace
    readonly property int focusedWorkspaceId: focusedWorkspace?.id ?? 1
    readonly property HyprlandMonitor focusedMonitor: Hyprland.focusedMonitor
    readonly property string activeTitle: Hyprland.activeToplevel?.title ?? ""

    // Tela (ShellScreen) do monitor com foco, para abrir painéis onde o usuário está.
    readonly property var focusedScreen: Quickshell.screens.find(s => s.name === focusedMonitor?.name) ?? Quickshell.screens[0] ?? null

    function monitorFor(screen: var): var {
        return Hyprland.monitorFor(screen);
    }

    // Se o workspace à mostra no monitor dessa tela não tem nenhuma janela.
    function isScreenEmpty(screen: var): bool {
        const ws = Hyprland.monitorFor(screen)?.activeWorkspace;
        return !ws || ws.toplevels.values.length === 0;
    }

    // Para o wallpaper animado: o que está à mostra em cada tela. Conta também
    // a janela maximizada (o modo 1 de tela cheia do Hyprland).
    function hasFullscreen(screen: var): bool {
        return Hyprland.monitorFor(screen)?.activeWorkspace?.hasFullscreen ?? false;
    }

    // Tela cheia de verdade (o bit 2 do modo, o de um jogo ou vídeo), não a
    // janela maximizada. O modo vem do `lastIpcObject`, renovado no evento
    // `fullscreen`.
    function hasRealFullscreen(screen: var): bool {
        const ws = Hyprland.monitorFor(screen)?.activeWorkspace;
        return ws?.hasFullscreen === true && ws.toplevels.values.some(t => ((t.lastIpcObject?.fullscreen ?? 0) & 2) !== 0);
    }

    // Tela apagada (DPMS). O Quickshell não tem essa propriedade: vem dos dados
    // do monitor, atualizados quando o Hyprland avisa de mudança.
    function isDpmsOff(screen: var): bool {
        return Hyprland.monitorFor(screen)?.lastIpcObject?.dpmsStatus === false;
    }

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (event.name.startsWith("monitor") || event.name === "dpms")
                Hyprland.refreshMonitors();
            if (event.name === "fullscreen")
                Hyprland.refreshToplevels();
            if (["openwindow", "closewindow", "movewindow", "movewindowv2", "changefloatingmode", "fullscreen"].includes(event.name))
                root.windowsChanged();
        }
    }

    function workspace(id: int): var {
        return workspaces.find(w => w.id === id) ?? null;
    }

    function dispatch(lua: string): void {
        Hyprland.dispatch(lua);
    }

    function focusWorkspace(id: int): void {
        dispatch(`hl.dsp.focus({ workspace = ${id} })`);
    }

    // Anda entre os workspaces existentes: step > 0 vai para o próximo.
    function cycleWorkspace(step: int): void {
        dispatch(`hl.dsp.focus({ workspace = "e${step > 0 ? "+" : "-"}1" })`);
    }

    // Janelas (toplevels do Hyprland). `lastIpcObject` (posição, tamanho,
    // classe) só vem depois de `refreshToplevels()`.
    readonly property var toplevels: Hyprland.toplevels.values
    readonly property string activeAddress: Hyprland.activeToplevel?.address ?? ""

    // Uma janela abriu, fechou ou mudou de lugar.
    signal windowsChanged()

    function refreshToplevels(): void {
        Hyprland.refreshToplevels();
    }

    function focusWindow(address: string): void {
        dispatch(`hl.dsp.focus({ window = "address:0x${address}" })`);
    }

    // Move sem ir junto.
    function moveWindow(address: string, workspaceId: int): void {
        dispatch(`hl.dsp.window.move({ workspace = ${workspaceId}, window = "address:0x${address}", follow = false })`);
    }

    function closeWindow(address: string): void {
        dispatch(`hl.dsp.window.close({ window = "address:0x${address}" })`);
    }

    // Liga ou desliga todas as telas (DPMS).
    function dpms(on: bool): void {
        dispatch(`hl.dsp.dpms({ action = "${on ? "on" : "off"}" })`);
    }

    function exit(): void {
        dispatch("hl.dsp.exit()");
    }

    Process {
        running: true
        command: ["hyprctl", "version", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.version = JSON.parse(text).tag?.replace(/^v/, "") ?? "";
                } catch (e) {}
            }
        }
    }

    // Executa Lua na config em uso, sem gravar no arquivo (hyprctl eval).
    function evalLua(lua: string): void {
        Quickshell.execDetached(["hyprctl", "eval", lua]);
    }
}
