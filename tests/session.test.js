// Testes de services/Session: o estado de bloqueio (sem systemctl).
function run(t) {
    const S = t.Session;

    // lock()/unlock() gravam locked (via PersistentProperties). Guarda o
    // estado de antes para restaurar no fim (a suíte roda no mesmo processo
    // que as seguintes).
    const original = {
        locked: S.locked
    };

    t.test("session: bloquear e desbloquear", () => {
        S.lock();
        t.check(S.locked, "bloqueada");
        S.unlock();
        t.check(!S.locked, "desbloqueada");
    });

    t.test("session: a marca do bloqueio volta a bloquear", () => {
        S.unlock();
        S.restoreLock(false);
        t.check(!S.locked, "sem a marca, continua desbloqueada");
        S.restoreLock(true);
        t.check(S.locked, "com a marca, bloqueia");
        S.restoreLock(false);
        t.check(S.locked, "sem a marca, não desbloqueia");
    });

    if (original.locked)
        S.lock();
    else
        S.unlock();

    t.test("session: estado original restaurado", () => {
        t.eq(S.locked, original.locked);
    });
}
