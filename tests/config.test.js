// Testes de core/config/Config: a gravação adiada do config.json. Um slider
// arrastado muda a Config a cada movimento; o arquivo só é gravado depois de
// uns 200 ms parado, o reload pelo watcher espera essa gravação (senão leria o
// arquivo velho e desfaria a mudança) e o flush grava na hora (ao sair).
function run(t) {
    const C = t.Config;

    t.test("config: a mudança espera para ir ao disco", () => {
        const before = C.notificationTimeout;
        C.flush();
        try {
            t.check(!C.writePending, "nada esperando depois do flush");
            C.notificationTimeout = before + 1;
            C.notificationTimeout = before + 2;
            t.check(C.writePending, "as mudanças seguidas esperam juntas");
            t.check(C.writeDelay >= 150 && C.writeDelay <= 300, `uns 200 ms (${C.writeDelay})`);
        } finally {
            C.notificationTimeout = before;
            C.flush();
        }
        t.check(!C.writePending, "o flush grava na hora");
    });

    t.test("config: o reload do watcher espera a gravação", () => {
        const before = C.notificationTimeout;
        C.flush();
        try {
            C.notificationTimeout = before + 5;
            C.diskChanged();
            t.eq(C.notificationTimeout, before + 5, "com a gravação esperando, o arquivo velho não desfaz a mudança");
            C.flush();
            C.diskChanged();
            t.eq(C.notificationTimeout, before + 5, "gravada, a releitura dá o mesmo valor");
        } finally {
            C.notificationTimeout = before;
            C.flush();
        }
        C.diskChanged();
        t.eq(C.notificationTimeout, before, "restaurado no disco");
    });
}
