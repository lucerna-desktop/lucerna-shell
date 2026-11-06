// Testes de core/pixel/Pixel: o alinhamento ao pixel físico em escala fracionária.
function run(t) {
    const P = t.Pixel;

    t.test("pixel: snap em 1,25", () => {
        t.near(P.snap(10, 1.25), 10.4, 1e-9, "10 lógicos caem em 12,5 físicos: vai para 13");
        t.near(P.snap(10.4, 1.25), 10.4, 1e-9, "já no pixel físico, fica");
        t.eq(P.snap(7, 1), 7, "em 1, o inteiro fica");
    });

    t.test("pixel: linha de um pixel físico", () => {
        t.eq(P.hairline(1), 1);
        t.near(P.hairline(1.25), 0.8, 1e-9, "1 px físico em 1,25");
        t.near(P.hairline(1.5), 2 / 1.5, 1e-9, "em 1,5, 2 px físicos (o arredondado)");
        t.eq(P.hairline(2), 1, "2 px físicos em 2");
    });
}
