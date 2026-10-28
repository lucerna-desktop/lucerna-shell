// Testes de core/input/InputActions: catálogo de ações e nomes de teclas.
function run(t) {
    const A = t.InputActions;

    t.test("inputactions: acha uma ação pelo id", () => {
        t.eq(A.find("lock").label, "Bloquear a tela");
        t.eq(A.find("nada"), null);
    });

    t.test("inputactions: o nome antigo de uma ação acha a nova", () => {
        t.eq(A.find("sidebar")?.id, "central", "um botão salvo com a ação sidebar");
        t.eq(A.describe({ id: "sidebar" }), "Abrir a central");
        t.eq(A.find("central").label, "Abrir a central");
    });

    t.test("inputactions: os painéis da central", () => {
        t.eq(["actions", "notifications", "central"].map(id => A.describe({ id })), ["Abrir as ações", "Abrir as notificações", "Abrir a central"]);
    });

    t.test("inputactions: descreve a ação configurada", () => {
        t.eq(A.describe({ id: "lock" }), "Bloquear a tela");
        t.eq(A.describe({ id: "shortcut", mods: "SUPER SHIFT", key: "q" }), "Enviar Super + Shift + Q");
        t.eq(A.describe({ id: "command", command: "kitty" }), "Rodar “kitty”");
        t.eq(A.describe(null), "—");
    });

    t.test("inputactions: botão do Qt para o código do Linux", () => {
        t.eq(A.buttonFromQt(Qt.BackButton).code, 275);
        t.eq(A.buttonFromQt(Qt.LeftButton), null);
    });

    t.test("inputactions: nome do botão pelo código", () => {
        t.eq(A.buttonLabel(276), "Botão lateral (avançar)");
        t.eq(A.buttonLabel(999), "Botão 999");
    });

    t.test("inputactions: nome amigável de símbolo do xkb", () => {
        t.eq(A.prettySymbol("space"), "Espaço");
        t.eq(A.prettySymbol("a"), "A");
        t.eq(A.prettySymbol("XF86Launch5"), "Launch5");
        t.eq(A.prettySymbol("Page_Up"), "Page Up");
        t.eq(A.prettySymbol(""), "?");
    });

    t.test("inputactions: combinação legível", () => {
        t.eq(A.prettyCombo("CTRL ALT", "Delete"), "Ctrl + Alt + Delete");
        t.eq(A.prettyCombo("", "Return"), "Enter");
    });

    t.test("inputactions: modificadores do Qt para os do Hyprland", () => {
        t.eq(A.modsFromQt(Qt.ControlModifier | Qt.ShiftModifier), "CTRL SHIFT");
        t.eq(A.modsFromQt(Qt.MetaModifier | Qt.AltModifier), "SUPER ALT");
        t.eq(A.modsFromQt(0), "");
    });

    t.test("inputactions: o modo jogo e a barra, sem tecla padrão", () => {
        t.eq(["game", "bar"].map(id => A.describe({ id })), ["Ligar/desligar o modo jogo", "Mostrar/esconder a barra"]);
        const keys = t.ShellShortcuts.effective({});
        t.eq(["game", "bar"].map(id => keys.find(k => k.id === id)?.keys), [[], []], "na lista, sem tecla");
    });
}
