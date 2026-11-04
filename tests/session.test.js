// Testes de services/Session: o estado de bloqueio (sem systemctl) e o
// caminho do logind (com o Logind desligado na unidade: só o estado).
function run(t) {
    const S = t.Session;
    const L = t.Logind;

    // lock()/unlock() gravam locked (via PersistentProperties). Guarda o
    // estado de antes para restaurar no fim (a suíte roda no mesmo processo
    // que as seguintes).
    const original = {
        locked: S.locked,
        secure: S.secure,
        holding: L.holding
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

    t.test("session: dormir espera o bloqueio na tela", () => {
        S.unlock();
        S.setSecure(false);
        L.holding = true;
        S.onSleep(true);
        t.check(S.locked, "dormir bloqueia");
        t.check(L.holding, "sem o bloqueio na tela, o inibidor fica");
        S.setSecure(true);
        t.check(!L.holding, "com o bloqueio na tela, o inibidor sai");
        // Já bloqueada e na tela: solta na hora.
        L.holding = true;
        S.onSleep(true);
        t.check(!L.holding, "já na tela, solta na hora");
        S.unlock();
        S.setSecure(false);
    });

    t.test("session: acordar pega o inibidor de novo", () => {
        L.holding = false;
        S.onSleep(false);
        t.check(L.holding, "acordou: o inibidor de novo");
        // Uma volta sem o bloqueio chegar à tela: o secure que chega depois
        // não solta o inibidor da próxima vez.
        S.setSecure(false);
        L.holding = true;
        S.onSleep(true);
        S.onSleep(false);
        S.setSecure(true);
        t.check(L.holding, "o secure depois de acordar não solta");
        S.unlock();
        S.setSecure(false);
    });

    t.test("session: Unlock do logind desbloqueia", () => {
        S.lock();
        L.unlockRequested();
        t.check(!S.locked, "desbloqueada pelo logind");
        L.lockRequested();
        t.check(S.locked, "bloqueada pelo logind");
        S.unlock();
    });

    S.setSecure(original.secure);
    L.holding = original.holding;
    if (original.locked)
        S.lock();
    else
        S.unlock();

    t.test("session: estado original restaurado", () => {
        t.eq(S.locked, original.locked);
        t.eq(S.secure, original.secure);
        t.eq(L.holding, original.holding);
    });
}
