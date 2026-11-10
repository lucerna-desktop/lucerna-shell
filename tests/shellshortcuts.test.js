// Testes de core/input/ShellShortcuts: padrões e comparação de combinações.
function run(t) {
    const S = t.ShellShortcuts;

    t.test("shellshortcuts: sem mudanças, tudo vem dos padrões", () => {
        const list = S.effective({}, true);
        t.eq(list.length, S.defaults.length);
        t.check(list.every(s => !s.custom), "nenhum custom");
        t.eq(list[0], { id: "launcher", keys: S.defaultKeys("launcher", true), custom: false });
    });

    t.test("shellshortcuts: a mudança do usuário vale, até lista vazia", () => {
        const list = S.effective({ launcher: [], lock: [{ mods: "ALT", trigger: "l" }] }, true);
        t.eq(list.find(s => s.id === "launcher"), { id: "launcher", keys: [], custom: true });
        t.eq(list.find(s => s.id === "lock").keys, [{ mods: "ALT", trigger: "l" }]);
    });

    t.test("shellshortcuts: a tecla salva no nome antigo (sidebar) vale na central", () => {
        const old = [{ mods: "SUPER SHIFT", trigger: "c" }];
        t.eq(S.effective({ sidebar: old }, true).find(s => s.id === "central"), { id: "central", keys: old, custom: true });
        t.eq(S.effective({ sidebar: old, central: [] }, true).find(s => s.id === "central").keys, [], "a do nome novo vence");
        t.eq(S.effective({}, true).find(s => s.id === "central").keys, [{ mods: S.mod, trigger: "c" }]);
        t.check(!S.effective({ sidebar: old }, true).some(s => s.id === "sidebar"), "o nome antigo não vira atalho");
    });

    t.test("shellshortcuts: salvar e restaurar depois da ponte do nome antigo", () => {
        const old = [{ mods: "SUPER SHIFT", trigger: "c" }];
        const def = S.defaultKeys("central", true);
        const restored = S.withKeys({ sidebar: old, lock: [] }, "central", def, true);
        t.eq(restored, { lock: [] }, "restaurar apaga o nome antigo e o novo");
        t.eq(S.effective(restored, true).find(s => s.id === "central"), { id: "central", keys: def, custom: false });
        t.eq(S.withKeys({ sidebar: old }, "central", [{ mods: "ALT", trigger: "c" }], true), { central: [{ mods: "ALT", trigger: "c" }] }, "capturar outra tecla grava no nome novo");
        t.eq(S.withKeys({ sidebar: old }, "central", [{ mods: S.mod.toLowerCase(), trigger: "C" }], true), {}, "a padrão capturada conta como restaurar");
        t.eq(S.withKeys(null, "lock", [], true), { lock: [] }, "sem nome antigo, lista vazia fica");
    });

    t.test("shellshortcuts: teclas padrão de uma ação", () => {
        t.eq(S.defaultKeys("capture-screen", true), [{ mods: "SHIFT", trigger: "Print" }]);
        t.eq(["actions", "notifications", "central"].map(id => S.defaultKeys(id, true)), [[{ mods: S.mod, trigger: "a" }], [{ mods: S.mod, trigger: "n" }], [{ mods: S.mod, trigger: "c" }]], "os painéis da central, cada um com a sua");
        t.eq(S.defaultKeys("nada", true), []);
    });

    t.test("shellshortcuts: o lançador no Super sozinho, ao soltar", () => {
        const alone = S.mod === "SUPER" ? "SUPER_L" : "ALT_L";
        t.eq(S.defaultKeys("launcher", true), [{ mods: S.mod, trigger: alone, release: true }, { mods: S.mod, trigger: "space" }]);
        t.eq(S.defaultKeys("launcher", true)[0].release, true, "a primeira é a de soltar");
        t.eq(S.mod === "SUPER" ? S.defaultKeys("launcher", true)[0].trigger : "SUPER_L", "SUPER_L", "fora do desenvolvimento, o SUPER_L");
    });

    t.test("shellshortcuts: Configurações na vírgula, e a mudança antiga em Super+S fica", () => {
        t.eq(S.defaultKeys("settings", true), [{ mods: S.mod, trigger: "comma" }]);
        const old = [{ mods: "SUPER", trigger: "s" }];
        t.eq(S.effective({ settings: old }, true).find(s => s.id === "settings"), { id: "settings", keys: old, custom: true });
    });

    t.test("shellshortcuts: as nove áreas de trabalho e as setas", () => {
        const ids = S.defaults.map(d => d.id);
        const after = ids.slice(ids.indexOf("terminal"));
        const dirs = ["left", "right", "up", "down"];
        t.eq(after.slice(0, 3), ["terminal", "close", "fullscreen"], "terminal, fechar e tela cheia");
        t.eq(after.slice(3, 21), [1, 2, 3, 4, 5, 6, 7, 8, 9].map(n => `workspace-${n}`).concat([1, 2, 3, 4, 5, 6, 7, 8, 9].map(n => `move-to-${n}`)));
        t.eq(after.slice(21), dirs.map(d => `focus-${d}`).concat(dirs.map(d => `move-${d}`), ["drag", "resize"]));
        t.eq(S.defaultKeys("terminal", true), [{ mods: S.mod, trigger: "Return" }]);
        t.eq(S.defaults.find(d => d.id === "terminal").base, true, "o terminal também está na base");
        t.eq(S.defaults.filter(d => d.base).map(d => d.id), ["terminal"], "só ele");
        t.eq([S.defaultKeys("close", true), S.defaultKeys("fullscreen", true)], [[{ mods: S.mod, trigger: "q" }], [{ mods: S.mod, trigger: "f" }]]);
        t.eq([S.defaultKeys("workspace-1", true), S.defaultKeys("workspace-9", true)], [[{ mods: S.mod, trigger: "1" }], [{ mods: S.mod, trigger: "9" }]]);
        t.eq(S.defaultKeys("move-to-3", true), [{ mods: `${S.mod} SHIFT`, trigger: "3" }]);
        t.eq(dirs.map(d => S.defaultKeys(`focus-${d}`, true)[0].trigger), dirs);
        t.eq(S.defaultKeys("move-up", true), [{ mods: `${S.mod} SHIFT`, trigger: "up" }]);
        t.eq([S.defaultKeys("drag", true), S.defaultKeys("resize", true)], [[{ mods: S.mod, trigger: "mouse:272" }], [{ mods: S.mod, trigger: "mouse:273" }]]);
    });

    // Fora da sessão Lucerna (sem `layered`), os padrões são os de antes da
    // sessão: as teclas de janela, área de trabalho e terminal ficam com o
    // hyprland.lua da pessoa; o que ela personalizou vale sempre.
    t.test("shellshortcuts: fora da sessão Lucerna, os padrões de antes", () => {
        const out = S.effective({}, false);
        t.eq(out.map(s => s.id), S.defaults.map(d => d.id), "os mesmos atalhos, para a pessoa poder pôr tecla");
        t.eq(out.find(s => s.id === "launcher").keys, [{ mods: S.mod, trigger: "space" }], "o lançador só no Mod+Espaço, sem o Super sozinho");
        t.eq(out.find(s => s.id === "settings").keys, [{ mods: S.mod, trigger: "s" }], "Configurações no Mod+S, como antes");
        const fresh = ["terminal", "close", "fullscreen", "drag", "resize"].concat([1, 9].map(n => `workspace-${n}`), [1, 9].map(n => `move-to-${n}`), ["focus-left", "move-down"]);
        t.eq(fresh.map(id => out.find(s => s.id === id).keys), fresh.map(() => []), "janelas, áreas de trabalho e terminal sem tecla");
        t.eq(["dashboard", "lock", "capture"].map(id => S.defaultKeys(id, false)), ["dashboard", "lock", "capture"].map(id => S.defaultKeys(id, true)), "os outros, iguais nas duas");
        t.check(out.every(s => !s.custom), "nenhum custom");
    });

    t.test("shellshortcuts: o que a pessoa mudou vale dentro e fora da sessão", () => {
        const mine = { terminal: [{ mods: "SUPER", trigger: "Return" }], launcher: [] };
        for (const layered of [true, false]) {
            const list = S.effective(mine, layered);
            t.eq(list.find(s => s.id === "terminal"), { id: "terminal", keys: mine.terminal, custom: true }, `terminal (layered=${layered})`);
            t.eq(list.find(s => s.id === "launcher"), { id: "launcher", keys: [], custom: true }, `lançador (layered=${layered})`);
        }
        t.eq(S.withKeys({}, "settings", [{ mods: S.mod, trigger: "s" }], false), {}, "fora, Mod+S é o padrão: restaurar");
        t.eq(S.withKeys({}, "settings", [{ mods: S.mod, trigger: "s" }], true), { settings: [{ mods: S.mod, trigger: "s" }] }, "dentro, Mod+S é uma mudança");
        t.eq(S.withKeys({ close: [{ mods: "SUPER", trigger: "c" }] }, "close", [], false), {}, "fora, sem tecla é o padrão do fechar");
    });

    t.test("shellshortcuts: a página e os binds seguem a sessão", () => {
        const binds = layered => t.InputState.shellEntries(layered).map(e => `${e.mods}+${e.trigger}`);
        t.check(binds(true).includes(`${S.mod}+Return`), "na sessão, o terminal");
        t.check(!binds(false).includes(`${S.mod}+Return`), "fora, sem o terminal");
        t.check(!binds(false).includes(`${S.mod}+q`) && !binds(false).includes(`${S.mod}+1`), "fora, sem fechar nem áreas de trabalho");
        t.check(binds(false).includes(`${S.mod}+space`) && binds(false).includes(`${S.mod}+s`), "fora, lançador e Configurações de antes");
        t.eq(t.ShortcutsState.shortcuts, S.effective(t.Config.shellShortcuts, t.HyprFile.layered), "a página mostra o conjunto que vale");
    });

    t.test("shellshortcuts: as teclas padrão que também estão na base", () => {
        t.eq(S.baseKeys(), [{ mods: S.mod, trigger: "Return" }]);
        t.eq(S.keyOf({ mods: "SUPER SHIFT", trigger: "q" }), "SUPER + SHIFT + q");
        t.eq(S.keyOf({ mods: "", trigger: "Print" }), "Print");
    });

    t.test("shellshortcuts: nenhuma tecla padrão repetida", () => {
        const keys = [].concat(...S.defaults.map(d => d.keys.map(k => `${S.normalizeMods(k.mods)}+${k.trigger.toLowerCase()}`)));
        t.eq(keys.filter((k, i) => keys.indexOf(k) !== i), []);
    });

    t.test("shellshortcuts: modificadores em ordem fixa", () => {
        t.eq(S.normalizeMods("shift+super"), "SUPER SHIFT");
        t.eq(S.normalizeMods("ALT CTRL"), "CTRL ALT");
        t.eq(S.normalizeMods("  "), "");
    });

    t.test("shellshortcuts: mesma combinação, escrita de outro jeito", () => {
        t.check(S.same({ mods: "SHIFT SUPER", trigger: "Q" }, { mods: "SUPER+SHIFT", trigger: "q" }), "iguais");
        t.check(!S.same({ mods: "SUPER", trigger: "q" }, { mods: "SUPER", trigger: "w" }), "outra tecla");
        t.check(!S.same({ mods: "SUPER", trigger: "q" }, { mods: "ALT", trigger: "q" }), "outro modificador");
    });

    t.test("shellshortcuts: tecla do Hyprland e máscara de modificadores", () => {
        t.eq(S.fromKey("SUPER + SHIFT + q"), { mods: "SUPER SHIFT", trigger: "q" });
        t.eq(S.fromKey("Print"), { mods: "", trigger: "Print" });
        t.eq(S.modsFromMask(64 | 1), "SUPER SHIFT");
        t.eq(S.modsFromMask(4 | 8), "CTRL ALT");
        t.eq(S.modsFromMask(0), "");
    });

    // A página: o Super sozinho com nome legível e as opções dos apps padrão.
    t.test("shellshortcuts: o nome do Super sozinho na página", () => {
        const St = t.ShortcutsState;
        t.eq(St.pretty({ mods: "SUPER", trigger: "SUPER_L", release: true }), "Super sozinho");
        t.eq(St.pretty({ mods: "ALT", trigger: "ALT_L", release: true }), "Alt sozinho");
        t.eq(St.pretty({ mods: "SUPER", trigger: "space" }), "Super + Espaço");
        t.eq(St.pretty({ mods: "SUPER", trigger: "mouse:272" }), "Super + Botão esquerdo");
        t.eq(St.pretty({ mods: "SUPER", trigger: "SUPER_L" }), "Super + Super esquerdo", "sem o soltar, é uma tecla qualquer");
        t.eq([St.editable("drag"), St.editable("terminal")], [false, true], "o arrastar só mostra a tecla");
    });

    t.test("shellshortcuts: as opções de um app padrão", () => {
        const St = t.ShortcutsState;
        t.eq(St.appOptions(["kitty", "foot"], ""), [{ label: "Automático (kitty)", value: "" }, { label: "kitty", value: "kitty" }, { label: "foot", value: "foot" }]);
        t.eq(St.appOptions([], ""), [{ label: "Automático (nenhum instalado)", value: "" }]);
        t.eq(St.appOptions(["kitty"], "wezterm"), [{ label: "Automático (kitty)", value: "" }, { label: "kitty", value: "kitty" }, { label: "wezterm", value: "wezterm", detail: "não instalado" }], "o escolhido que sumiu continua na lista");
    });
}
