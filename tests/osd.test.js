// Testes do OSD (features/osd/state): com a central aberta ele não aparece (sairia
// da mesma borda, por cima dela). O estado do OSD e os painéis voltam ao fim.
function run(t) {
    const O = t.OsdState;
    const P = t.Panels;

    t.test("osd: não aparece com a central aberta", () => {
        const armed0 = O.armed, shown0 = O.shown, kind0 = O.kind, opened0 = P.opened;
        try {
            O.armed = true;
            O.shown = false;
            P.opened = ["central"];
            O.show("brightness");
            t.check(!O.shown, "com a central: não");
            P.opened = ["dashboard"];
            O.show("brightness");
            t.check(O.shown, "com o painel superior: sim");
            t.eq(O.kind, "brightness");
        } finally {
            O.armed = armed0;
            O.shown = shown0;
            O.kind = kind0;
            P.opened = opened0;
        }
    });
}
