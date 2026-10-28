// Testes de features/idle/state: o que segura a ociosidade (o modo jogo entre
// os motivos) e o texto do motivo. Os IdleMonitor não contam nada aqui (o qs
// dos testes roda sem Wayland).
function run(t) {
    const I = t.IdleState;
    const none = { enabled: true, inhibit: false, game: false, media: false, fullscreen: false };

    function holds(fields) {
        return Object.assign({}, none, fields);
    }

    t.test("idle: o motivo, na ordem", () => {
        t.eq(I.reasonFor(none), "");
        t.eq(I.reasonFor(holds({ game: true, media: true })), "O modo jogo está ligado");
        t.eq(I.reasonFor(holds({ inhibit: true, game: true })), "“Não apagar a tela” está ligado");
        t.eq(I.reasonFor(holds({ media: true, fullscreen: true })), "Há mídia tocando");
        t.eq(I.reasonFor(holds({ fullscreen: true })), "Há um app em tela cheia");
        t.eq(I.reasonFor(holds({ enabled: false, game: true })), "", "desligada, sem motivo");
    });

    t.test("idle: o modo jogo segura, com o item ligado", () => {
        const G = t.GameMode, C = t.Config;
        const was = { active: G.active, idle: C.gameIdle, inhibit: C.idleInhibit };
        try {
            C.idleInhibit = false;
            C.gameIdle = true;
            G.active = true;
            t.eq([I.gameHeld, I.held], [true, true]);
            C.gameIdle = false;
            t.eq(I.gameHeld, false, "o item desligado não segura");
        } finally {
            G.active = was.active;
            C.gameIdle = was.idle;
            C.idleInhibit = was.inhibit;
        }
        t.eq([G.active, C.gameIdle, C.idleInhibit], [was.active, was.idle, was.inhibit], "estado original restaurado");
    });
}
