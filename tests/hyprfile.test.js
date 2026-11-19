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

    t.test("hyprfile: o passo da gravação", () => {
        t.eq(H.writeStep("a", "", "", false), "write", "texto novo: grava");
        t.eq(H.writeStep("a", "", "", true), "wait", "outra gravação em curso: espera");
        t.eq(H.writeStep("a", "a", "", false), "done", "já está no disco");
        t.eq(H.writeStep("a", "", "a", false), "failed", "o texto que acabou de falhar não é gravado de novo sozinho");
    });

    t.test("hyprfile: gravação que falhou não recarrega o Hyprland", () => {
        const saved = { sections: H.sections, written: H.written, failed: H.failed, asked: H.reloadAsked };
        try {
            H.sections = { input: "x" };
            const text = H.compose(H.sections);
            H.written = "";
            H.failed = "";
            H.reloadAsked = true;
            H.finished(false, text);
            t.eq(H.failed, text, "o texto que falhou fica anotado");
            t.check(!H.reloadAsked, "o reload pedido cai: leria o arquivo velho e desfaria o que o eval já pôs");
            H.reloadAsked = true;
            H.write();
            t.check(!H.reloadAsked, "nem quando a próxima tentativa acha o mesmo texto que falhou");
            H.finished(true, text);
            t.eq([H.written, H.failed], [text, ""], "gravado: o texto no disco");
        } finally {
            H.sections = saved.sections;
            H.written = saved.written;
            H.failed = saved.failed;
            H.reloadAsked = saved.asked;
        }
    });

    t.test("hyprfile: o arquivo grande vai em pedaços pela linha de comando", () => {
        // Um argumento só vai até 128 KiB (MAX_ARG_STRLEN): o settings.lua
        // inteiro num argumento não seria gravado a partir desse tamanho.
        const big = "a" + "😀".repeat(50000);
        const argv = H.writeCommand("/x/settings.lua", big);
        t.eq(argv.slice(0, 2), ["sh", "-c"]);
        t.eq(argv[4], "/x/settings.lua", "o caminho");
        const parts = argv.slice(5);
        t.check(parts.length > 1, `em pedaços (${parts.length})`);
        t.check(parts.every(p => p.length <= 32768), "cada pedaço bem abaixo de 128 KiB, mesmo com 4 bytes por caractere");
        t.check(parts.every(p => !/[\uD800-\uDBFF]$/.test(p)), "nenhum pedaço corta um emoji ao meio");
        t.eq(parts.join(""), big, "juntos, o texto inteiro");
        t.eq(H.writeCommand("/x/s.lua", "a").slice(5), ["a"], "o pequeno vai num pedaço");
    });
}
