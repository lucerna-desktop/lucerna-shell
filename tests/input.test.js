// Testes de services/Input: o Lua gerado e o keymap remapeado (texto puro,
// sem hyprctl nem xkbcli). O keymap de exemplo usa espaços no lugar de tabs.
function run(t) {
    const I = t.Input;
    const keymap = [
        "xkb_keymap {",
        "xkb_keycodes \"evdev\" {",
        "    <ESC> = 9;",
        "    <CAPS> = 66;",
        "    <LCTL> = 37;",
        "};",
        "xkb_types \"complete\" {",
        "};",
        "xkb_symbols \"pc+us\" {",
        "    key <ESC> { [ Escape ] };",
        "    key <CAPS> { type= \"ONE_LEVEL\", symbols[1]= [ Caps_Lock ] };",
        "    key <LCTL> { [ Control_L ] };",
        "    modifier_map Lock { <CAPS> };",
        "    modifier_map Control { <LCTL> };",
        "};",
        "};",
        ""
    ].join("\n");

    // I.parseKeymap() não é pura: grava keyNames/keySymbols no singleton.
    // Guarda o estado de antes para restaurar no fim (a suíte roda no mesmo
    // processo que as seguintes).
    const originalKeyNames = I.keyNames;
    const originalKeySymbols = I.keySymbols;

    t.test("input: opção lida do Hyprland", () => {
        I.options = { "input.sensitivity": { value: 0.5, set: true } };
        t.eq(I.option("input.sensitivity"), 0.5);
        t.check(I.option("nada") === undefined, "opção que não existe");
        I.options = {};
    });

    t.test("input: string Lua escapada", () => {
        t.eq(I.luaString('a"b\\c\nd'), '"a\\"b\\\\c\\nd"');
    });

    t.test("input: valores Lua", () => {
        t.eq([I.luaValue(true), I.luaValue(3), I.luaValue("x")], ["true", "3", '"x"']);
        t.eq(I.luaValue(["a", 1]), '{ "a", 1 }');
        t.eq(I.luaValue({ input: { kb_layout: "br" } }), '{ input = { kb_layout = "br" } }');
        t.eq(I.luaValue({ "a-b": 1 }), '{ ["a-b"] = 1 }');
    });

    t.test("input: opções com ponto viram tabelas aninhadas", () => {
        t.eq(I.nest({ "input.touchpad.tap_to_click": true, "input.sensitivity": 0.2 }), { input: { touchpad: { tap_to_click: true }, sensitivity: 0.2 } });
    });

    t.test("input: binds e unbinds", () => {
        t.eq(I.unbindLua([{ key: "SUPER + d" }, { key: "ALT + q" }]), 'hl.unbind("SUPER + d")\nhl.unbind("ALT + q")');
        t.eq(I.bindLua([{ key: "SUPER + d", lua: "hl.dsp.exit()", repeating: true, locked: true }, { key: "ALT + q", lua: "x()" }]),
             'hl.bind("SUPER + d", hl.dsp.exit(), { repeating = true, locked = true })\nhl.bind("ALT + q", x())');
    });

    t.test("input: nomes e símbolos das teclas do keymap", () => {
        I.parseKeymap(keymap);
        t.eq(I.keyNames, { 9: "ESC", 37: "LCTL", 66: "CAPS" });
        t.eq(I.keySymbols, { ESC: "Escape", CAPS: "Caps_Lock", LCTL: "Control_L" });
    });

    t.test("input: bloco de uma tecla", () => {
        t.eq(I.keyBlock(keymap, "CAPS").text.trim(), 'key <CAPS> { type= "ONE_LEVEL", symbols[1]= [ Caps_Lock ] };');
        t.eq(I.keyBlock(keymap, "NADA"), null);
    });

    // Saída completa de patchKeymap(), escrita à mão a partir do keymap de
    // entrada (não gerada chamando a própria função), conferindo em
    // services/Input.qml onde cada trecho entra:
    // - nada muda antes de "xkb_symbols" (patchKeymap só mexe a partir daí);
    // - keyBlock() tira a linha "    key <CAPS> {...};" inteira (com o "\n"
    //   que vinha antes dela); o "replace()" do modifier_map só some com o
    //   texto casado pela regex ("modifier_map Lock { <CAPS> };"), não com a
    //   indentação em volta — por isso sobra uma linha só com 4 espaços onde
    //   estava esse modifier_map (linha 11 abaixo);
    // - a tecla nova entra com "\n\t" antes do "close", que é o PENÚLTIMO
    //   "};" do texto (o que fecha xkb_symbols — o último fecha xkb_keymap),
    //   por isso a linha em branco antes do "\tkey <CAPS>...".
    const head = [
        "xkb_keymap {",
        "xkb_keycodes \"evdev\" {",
        "    <ESC> = 9;",
        "    <CAPS> = 66;",
        "    <LCTL> = 37;",
        "};",
        "xkb_types \"complete\" {",
        "};",
        "xkb_symbols \"pc+us\" {",
        "    key <ESC> { [ Escape ] };",
        "    key <LCTL> { [ Control_L ] };",
        "    ",
        "    modifier_map Control { <LCTL> };",
        ""
    ];
    const tail = ["};", "};", ""];

    t.test("input: remapear Caps Lock para Esc", () => {
        const out = I.patchKeymap(keymap, [{ from: "CAPS", to: { kind: "key", value: "ESC" } }]);
        t.eq(out, head.concat(["\tkey <CAPS> { [ Escape ] };"], tail).join("\n"));
    });

    t.test("input: remapear para um modificador leva o modifier_map junto", () => {
        const out = I.patchKeymap(keymap, [{ from: "CAPS", to: { kind: "key", value: "LCTL" } }]);
        t.eq(out, head.concat(["\tkey <CAPS> { [ Control_L ] };", "\tmodifier_map Control { <CAPS> };"], tail).join("\n"));
    });

    t.test("input: remapear para um símbolo ou para nada", () => {
        const sym = I.patchKeymap(keymap, [{ from: "CAPS", to: { kind: "sym", value: "XF86AudioPlay" } }]);
        t.eq(sym, head.concat(["\tkey <CAPS> { type= \"ONE_LEVEL\", symbols[1]= [ XF86AudioPlay ] };"], tail).join("\n"));

        const none = I.patchKeymap(keymap, [{ from: "CAPS", to: { kind: "none" } }]);
        t.eq(none, head.concat(["\tkey <CAPS> { type= \"ONE_LEVEL\", symbols[1]= [ NoSymbol ] };"], tail).join("\n"));
    });

    // As ações novas do shell (features/input/state): `game` alterna o modo
    // jogo pelo daemon (um cliente de teste no GameMode) e `bar` pede a barra
    // pelo Panels (a feature input não importa a barra).
    t.test("input: a ação game alterna o modo jogo", () => {
        const G = t.GameMode;
        const client0 = G.client;
        const c = t.lucernaClient();
        try {
            G.client = c;
            c.opened();
            const hello = Object.keys(c.pending).map(Number)[0];
            c.receive(JSON.stringify({ jsonrpc: "2.0", id: hello, result: { protocol: "1.0", app: "lucernad", version: "0.1.0", topics: ["game.state"], streams: [], methods: [] } }));
            c.pending = {};
            t.InputState.run("game");
            t.eq(Object.values(c.pending).map(p => p.method), ["game.toggle"]);
        } finally {
            G.client = client0;
            c.destroy();
        }
        t.check(G.client === client0, "estado original restaurado");
    });

    t.test("input: a ação bar pede a barra na tela com foco", () => {
        const P = t.Panels;
        const asked = [];
        const record = screen => asked.push(screen);
        P.barToggleRequested.connect(record);
        try {
            t.InputState.run("bar");
        } finally {
            P.barToggleRequested.disconnect(record);
        }
        t.eq(asked.length, 1);
        t.check(asked[0] === t.Hypr.focusedScreen, "a tela com foco");
    });

    I.keyNames = originalKeyNames;
    I.keySymbols = originalKeySymbols;

    t.test("input: estado original restaurado", () => {
        t.eq([I.keyNames, I.keySymbols], [originalKeyNames, originalKeySymbols]);
    });
}
