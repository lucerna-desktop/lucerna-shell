// Testes de services/HyprFile: o texto do arquivo controlado pelo shell
// (~/.config/lucerna/hypr/settings.lua) e o arquivo antigo dos monitores.
// Só funções puras: nada é gravado.
function run(t) {
    const H = t.HyprFile;
    const header = "-- Gerado pelo Lucerna (Configurações). Não edite: é reescrito. O seu arquivo é o ~/.config/hypr/hyprland.lua.";

    t.test("hyprfile: as seções em ordem, sem as vazias", () => {
        const text = H.compose({ monitors: "a", binds: "", input: "b" });
        t.eq(text, `${header}\n\n-- [input]\nb\n\n-- [monitors]\na\n`);
        t.check(!text.includes("-- [binds]"), "a seção vazia sai");
    });

    t.test("hyprfile: o arquivo lido volta às seções", () => {
        const sections = { input: "b\nc", monitors: "a" };
        t.eq(H.parse(H.compose(sections)), sections);
        t.eq(H.parse(""), {});
        t.eq(H.parse("hl.monitor(...)"), {}, "sem seções, nada");
    });

    t.test("hyprfile: o arquivo antigo gerado é neutralizado e o do usuário não", () => {
        t.check(H.isLegacyGenerated("-- Gerado pelo Lucerna (Configurações → Monitores)…"), "o gerado");
        t.check(H.isLegacyGenerated(H.legacyNotice), "o já neutralizado continua sendo do Lucerna");
        t.check(!H.isLegacyGenerated("hl.monitor(...)"), "o escrito à mão");
        t.check(!H.isLegacyGenerated(""), "o vazio");
        t.check(!H.isLegacyGenerated("hl.monitor(...)\n-- Gerado pelo Lucerna"), "só a primeira linha conta");
    });
}
