// Testes de features/settings/state/ShortcutsState: a página Configurações →
// Atalhos (os nomes legíveis das teclas e as opções dos apps padrão).
function run(t) {
    const St = t.ShortcutsState;
    const S = t.ShellShortcuts;

    t.test("shortcutsstate: a página mostra o conjunto que vale", () => {
        t.eq(St.shortcuts, S.effective(t.Config.shellShortcuts, t.HyprFile.layered));
    });

    t.test("shortcutsstate: o nome do Super sozinho na página", () => {
        t.eq(St.pretty({ mods: "SUPER", trigger: "SUPER_L", release: true }), "Super sozinho");
        t.eq(St.pretty({ mods: "ALT", trigger: "ALT_L", release: true }), "Alt sozinho");
        t.eq(St.pretty({ mods: "SUPER", trigger: "space" }), "Super + Espaço");
        t.eq(St.pretty({ mods: "SUPER", trigger: "mouse:272" }), "Super + Botão esquerdo");
        t.eq(St.pretty({ mods: "SUPER SHIFT", trigger: "mouse:274" }), "Super + Shift + Botão do meio", "os outros botões pelo nome do InputActions");
        t.eq(St.pretty({ mods: "SUPER", trigger: "SUPER_L" }), "Super + Super esquerdo", "sem o soltar, é uma tecla qualquer");
        t.eq([St.editable("drag"), St.editable("terminal")], [false, true], "o arrastar só mostra a tecla");
    });

    t.test("shortcutsstate: as opções de um app padrão", () => {
        t.eq(St.appOptions(["kitty", "foot"], ""), [{ label: "Automático (kitty)", value: "" }, { label: "kitty", value: "kitty" }, { label: "foot", value: "foot" }]);
        t.eq(St.appOptions([], ""), [{ label: "Automático (nenhum instalado)", value: "" }]);
        t.eq(St.appOptions(["kitty"], "wezterm"), [{ label: "Automático (kitty)", value: "" }, { label: "kitty", value: "kitty" }, { label: "wezterm", value: "wezterm", detail: "não instalado" }], "o escolhido que sumiu continua na lista");
    });
}
