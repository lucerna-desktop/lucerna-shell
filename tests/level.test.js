// Testes de core/level/Level: as contas da barra de porcentagem (LevelSlider).
function run(t) {
    const L = t.Level;

    t.test("level: fração do valor", () => {
        t.eq([L.fraction(0.5, 0, 1), L.fraction(-1, 0, 1), L.fraction(2, 0, 1)], [0.5, 0, 1], "no meio e presa nas pontas");
        t.near(L.fraction(3000, 2500, 6000), 1 / 7, 1e-9, "num intervalo qualquer");
        t.eq(L.fraction(0, -1, 1), 0.5, "de -1 a 1");
        t.eq(L.fraction(5, 5, 5), 0, "intervalo vazio: 0, sem NaN");
    });

    t.test("level: snap no passo", () => {
        t.eq(L.snap(0.427, 0, 1, 0), 0.427, "sem passo, só presa");
        t.eq([L.snap(-3, 0, 1, 0), L.snap(7, 0, 1, 0)], [0, 1]);
        t.eq(L.snap(3333, 2500, 6000, 100), 3300, "o passo contado a partir de from");
        t.eq(L.snap(7.6, 5, 60, 5), 10, "nível da economia: de 5 em 5 a partir de 5");
        t.eq(L.snap(3, 0.2, 3, 0.1), 3, "o arredondamento não passa de to");
        t.eq(L.snap(2.04, 1, 20, 1), 2);
    });

    t.test("level: valor sob o ponteiro", () => {
        t.eq(L.valueAt(50, 200, 0, 1, 0), 0.25);
        t.eq([L.valueAt(-10, 200, 0, 1, 0), L.valueAt(500, 200, 0, 1, 0)], [0, 1], "fora da barra, presa");
        t.eq(L.valueAt(100, 200, 150, 1000, 25), 575, "no passo");
        t.eq(L.valueAt(0, 200, 0.01, 1, 0), 0.01, "o mínimo do brilho");
        t.eq(L.valueAt(10, 0, 0, 1, 0), 0, "barra sem largura: from");
    });

    t.test("level: passo do teclado e da roda", () => {
        t.near(L.stepped(0.5, 1, 0, 1, 0), 0.55, 1e-9, "sem passo, 5% do intervalo");
        t.near(L.stepped(0.5, -1, 0, 1, 0), 0.45, 1e-9);
        t.eq(L.stepped(1, 1, 0, 1, 0), 1, "presa em to");
        t.eq(L.stepped(0.02, -1, 0.01, 1, 0), 0.01, "presa em from");
        t.eq([L.stepped(10, 1, 1, 20, 1), L.stepped(10, -1, 1, 20, 1)], [11, 9], "com passo, um passo");
        t.near(L.stepped(0, 1, -1, 1, 0.05), 0.05, 1e-9, "de -1 a 1, de 5 em 5 centésimos");
    });

    t.test("level: largura da parte cheia", () => {
        t.eq(L.fillWidth(0.5, 200, 20), 100, "até a metade");
        t.eq(L.fillWidth(1, 200, 20), 200);
        t.eq(L.fillWidth(0.05, 200, 20), 20, "menos que a altura: o círculo da ponta");
        t.eq(L.fillWidth(0, 200, 20), 0, "sem valor, nada");
        t.eq([L.fillWidth(-1, 200, 20), L.fillWidth(2, 200, 20)], [0, 200], "fração presa");
    });
}
