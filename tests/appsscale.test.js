// Testes de services/AppsScale: o modo "Escala pelos apps" (o compositor em 1
// e cada toolkit aumentando os apps). Só funções puras: nada é gravado nem
// mandado ao Hyprland (os arquivos são textos num objeto).
function run(t) {
    const A = t.AppsScale;
    const marker = "# lucerna: escala pelos apps";

    t.test("appsscale: ambiente em 1,25", () => {
        t.eq(A.envFor(1.25), { QT_SCALE_FACTOR: 1.25, GDK_SCALE: 1, GDK_DPI_SCALE: 1.25, XCURSOR_SIZE: 30, HYPRCURSOR_SIZE: 30 });
        t.eq(A.envFor(1.75).GDK_DPI_SCALE, 1.75, "abaixo de 2, o GTK fica em 1 e o texto escala");
    });

    t.test("appsscale: ambiente em 2", () => {
        const env = A.envFor(2);
        t.eq([env.QT_SCALE_FACTOR, env.GDK_SCALE, env.GDK_DPI_SCALE, env.XCURSOR_SIZE], [2, 2, 1, 48]);
    });

    t.test("appsscale: em 1, nada", () => {
        t.eq(A.envFor(1), {});
        t.eq(A.flagsText("", 1), "", "sem a linha das flags");
        const lua = A.hyprLua(1, {});
        for (const part of ['hl.env("QT_SCALE_FACTOR", "1")', 'hl.env("GDK_SCALE", "1")', 'hl.env("GDK_DPI_SCALE", "1")', 'hl.env("XCURSOR_SIZE", "24")', 'hl.env("HYPRCURSOR_SIZE", "24")'])
            t.check(lua.includes(part), `no Hyprland, o neutro (o fator de antes não fica): ${part}`);
    });

    t.test("appsscale: o session.env sem aspas, com o cabeçalho", () => {
        const text = A.sessionEnvText(A.envFor(1.5));
        const lines = text.split("\n");
        t.check(lines[0].startsWith("# Gerado pelo Lucerna"), lines[0]);
        t.check(lines.includes("QT_SCALE_FACTOR=1.5") && lines.includes("GDK_DPI_SCALE=1.5") && lines.includes("XCURSOR_SIZE=36"), text);
        t.check(!text.includes('"'), "o lucerna-session guarda as aspas no valor: sem elas");
        t.check(text.endsWith("\n"), "termina com uma quebra de linha");
    });

    t.test("appsscale: flags acrescenta e tira só a nossa linha", () => {
        const mine = "--enable-features=X\n";
        const on = A.flagsText(mine, 1.25);
        t.eq(on, `--enable-features=X\n${marker}\n--force-device-scale-factor=1.25\n`);
        t.eq(A.flagsText(on, 1.25), on, "idempotente");
        t.eq(A.flagsText(on, 1.5), `--enable-features=X\n${marker}\n--force-device-scale-factor=1.5\n`, "troca o fator");
        t.eq(A.flagsText(on, 1), mine, "em 1, só a linha da pessoa");
        t.eq(A.flagsText(A.flagsText("--a\n--b", 2), 1), "--a\n--b", "sem a quebra no fim, continua sem");
        t.eq(A.flagsText(A.flagsText("", 1.25), 1), "", "do vazio volta ao vazio");
    });

    t.test("appsscale: gtk ini mescla e devolve o original", () => {
        const ini = "[Settings]\ngtk-theme-name=Adwaita\ngtk-xft-dpi = 98304\n\n[Outro]\na=1\n";
        const on = A.gtkIniText(ini, 1.25, "98304");
        t.eq(on, "[Settings]\ngtk-theme-name=Adwaita\ngtk-xft-dpi = 122880\n\n[Outro]\na=1\n", "troca só o valor");
        t.eq(A.gtkIniText(on, 1, "98304"), ini, "volta ao original");
        t.eq(A.iniValue(ini, "Settings", "gtk-xft-dpi"), "98304");
        t.eq(A.iniValue("[Outro]\ngtk-xft-dpi=1\n", "Settings", "gtk-xft-dpi"), null, "só na seção certa");

        const plain = "[Settings]\ngtk-theme-name=Adwaita\n";
        const added = A.gtkIniText(plain, 1.5, null);
        t.eq(added, "[Settings]\ngtk-xft-dpi=147456\ngtk-theme-name=Adwaita\n", "acrescenta na seção");
        t.eq(A.gtkIniText(added, 1, null), plain, "sem original, tira a chave");

        t.eq(A.gtkIniText("", 1.25, null), "[Settings]\ngtk-xft-dpi=122880\n", "cria a seção");
        t.eq(A.gtkIniText("[Outro]\na=1\n", 2, null), "[Outro]\na=1\n[Settings]\ngtk-xft-dpi=196608\n", "a seção que faltava vai no fim");
    });

    t.test("appsscale: o Xresources", () => {
        t.check(A.xresourcesText(1.25).split("\n").includes("Xft.dpi: 120"), A.xresourcesText(1.25));
        t.check(A.xresourcesText(1).includes("Xft.dpi: 96"));
    });

    t.test("appsscale: a seção do Hyprland", () => {
        const lua = A.hyprLua(1.25, { borderSize: 2, rounding: 12 });
        for (const part of ['lucerna_scale_mode = "apps"', "force_zero_scaling = true", "border_size = 3", "gaps_in = 5", "gaps_out = 13", "rounding = 15", 'hl.env("QT_SCALE_FACTOR", "1.25")', 'hl.env("XCURSOR_SIZE", "30")'])
            t.check(lua.includes(part), `${part} em ${lua}`);
        t.check(A.hyprLua(1.25, {}).includes("rounding = 13"), "sem tema, a base (10)");
        t.check(!lua.startsWith("-"), "o hyprctl eval leria um -- no começo como opção");
        t.check(!A.restoreLua(null).startsWith("-"), "nem na volta");
    });

    t.test("appsscale: a volta ao Hyprland de antes", () => {
        const lua = A.restoreLua({ env: { XCURSOR_SIZE: "32", QT_SCALE_FACTOR: null }, gaps: { in: "4 4 4 4", out: "5 10 5 10" } });
        t.check(!lua.includes('", "")'), `nunca vazio: ${lua}`);
        for (const part of ["lucerna_scale_mode = nil", 'hl.env("XCURSOR_SIZE", "32")', 'hl.env("QT_SCALE_FACTOR", "1")', 'hl.env("GDK_SCALE", "1")', 'hl.env("GDK_DPI_SCALE", "1")', 'hl.env("HYPRCURSOR_SIZE", "24")', "gaps_in = 4", "gaps_out = { top = 5, right = 10, bottom = 5, left = 10 }"])
            t.check(lua.includes(part), `${part} em ${lua}`);
        t.check(A.restoreLua(null).includes("gaps_in = 4") && A.restoreLua(null).includes("gaps_out = 10"), "sem cópia, a base");
        t.eq(A.gapsLua("7"), "7");
        t.eq(A.gapsLua("x"), "", "o que não é número não vai");
    });

    t.test("appsscale: a leitura dos arquivos", () => {
        // O formato do `hyprctl getoption general:gaps_in -j` do Hyprland 0.57.1.
        const text = "\x1eelectron-flags.conf\x1f1--a\n\x1egtk-3.0/settings.ini\x1f0\x1e@xrdb\x1f1\n120\n\x1e@gaps_in\x1f{\"option\": \"general:gaps_in\", \"css\": \"0 0 0 0\", \"set\": true }\n";
        const read = A.parseRead(text);
        t.eq(read.files, { "electron-flags.conf": "--a\n", "gtk-3.0/settings.ini": null });
        t.eq([read.xrdb, read.xftDpi, read.gapsIn], [true, "120", "0 0 0 0"]);
        t.eq(A.parseRead('\x1e@gaps_out\x1f{"option": "general:gaps_out", "custom": "5 10 5 10", "set": true }').gapsOut, "5 10 5 10", "versões com custom");
        t.check(A.restoreLua({ gaps: { in: read.gapsIn } }).includes("gaps_in = 0"), "o 0 da pessoa volta 0, não 4");
        t.eq(A.parseRead("\x1e@xrdb\x1f0\n").xrdb, false);
    });

    // Os arquivos de uma pessoa: um Chromium com flag própria, um GTK 3 com
    // tema, o resto ausente.
    const files = {
        "electron-flags.conf": null,
        "chromium-flags.conf": "--enable-features=X\n",
        "chrome-flags.conf": null,
        "gtk-3.0/settings.ini": "[Settings]\ngtk-theme-name=Adwaita\n",
        "gtk-4.0/settings.ini": null,
        "lucerna/session.env": null,
        "lucerna/Xresources": null
    };
    const live = { env: { XCURSOR_SIZE: "24" }, gapsIn: "4 4 4 4", gapsOut: "10 10 10 10", xftDpi: null };

    function applied(state, writes) {
        const out = Object.assign({}, state);
        for (const name of Object.keys(writes))
            out[name] = writes[name];
        return out;
    }

    t.test("appsscale: aplicar e restaurar devolve os arquivos", () => {
        const first = A.planApply(files, null, 1.25, live);
        t.check(first.fresh, "a primeira mudança tira as cópias");
        t.eq(first.backup.files["chromium-flags.conf"], true);
        t.eq(first.backup.files["chrome-flags.conf"], false);
        t.eq(first.backup.env, live.env);
        const on = applied(files, first.writes);
        t.check(on["chromium-flags.conf"].includes("--force-device-scale-factor=1.25"), "flags");
        t.check(on["electron-flags.conf"].includes("--force-device-scale-factor=1.25"), "o Electron também");
        t.check(on["gtk-4.0/settings.ini"].includes("gtk-xft-dpi=122880"), "o GTK 4 criado");
        t.check(on["lucerna/session.env"].includes("QT_SCALE_FACTOR=1.25"), "session.env");
        t.check(on["lucerna/Xresources"].includes("Xft.dpi: 120"), "Xresources");

        const again = A.planApply(on, first.backup, 1.5, live);
        t.check(!again.fresh, "com a cópia, não tira de novo");
        t.eq(again.backup, first.backup, "a cópia de antes continua");
        const on2 = applied(on, again.writes);
        t.check(on2["chromium-flags.conf"].includes("=1.5") && !on2["chromium-flags.conf"].includes("=1.25"), "o fator trocado");

        const back = applied(on2, A.planRestore(on2, first.backup).writes);
        t.eq(back, files, "tudo como antes (os que não existiam somem)");
    });

    t.test("appsscale: restaurar sem a cópia só tira o que é do Lucerna", () => {
        const on = applied(files, A.planApply(files, null, 2, live).writes);
        const mine = Object.assign({}, on, { "lucerna/session.env": "FOO=1\n" });
        const back = applied(mine, A.planRestore(mine, null).writes);
        t.eq(back["chromium-flags.conf"], "--enable-features=X\n", "a linha marcada sai");
        t.eq(back["electron-flags.conf"], null, "o arquivo só com a nossa linha some");
        t.eq(back["lucerna/Xresources"], null, "o gerado some");
        t.eq(back["lucerna/session.env"], "FOO=1\n", "o da pessoa fica");
        t.eq(back["gtk-3.0/settings.ini"], on["gtk-3.0/settings.ini"], "sem o original, o GTK fica");
    });

    t.test("appsscale: sem o scale-backup.json no meio do modo, os originais não se perdem", () => {
        const first = A.planApply(files, null, 1.25, live);
        const on = applied(files, first.writes);
        // As cópias que a primeira aplicação tirou (dos que existiam).
        const copies = {};
        for (const name of Object.keys(files)) {
            if (files[name] !== null)
                copies[`${name}.lucerna-bak`] = files[name];
        }
        const scaledLive = { env: { QT_SCALE_FACTOR: "1.25", XCURSOR_SIZE: "30" }, gapsIn: "5 5 5 5", gapsOut: "13 13 13 13", xftDpi: "120" };
        const lost = A.planApply(Object.assign({}, on, copies), null, 1.5, scaledLive);
        t.check(lost.fresh, "sem o JSON, conta como a primeira");
        t.eq(lost.backup.files, first.backup.files, "quem existia antes, pelas cópias e pelas marcas");
        t.eq(lost.backup.gtk, first.backup.gtk, "o gtk-xft-dpi de antes, não o do modo");
        t.eq(lost.backup.own, first.backup.own);
        t.eq([lost.backup.env, lost.backup.gaps.in, lost.backup.xftDpi], [{}, "", null], "o ambiente, os espaços e o Xft.dpi de agora são do modo: não contam");
        const on2 = applied(on, lost.writes);
        t.eq(applied(on2, A.planRestore(on2, lost.backup).writes), files, "a volta devolve os arquivos de antes");

        const gtk = Object.assign({}, files, { "gtk-3.0/settings.ini": "[Settings]\ngtk-xft-dpi = 98304\n" });
        const onGtk = applied(gtk, A.planApply(gtk, null, 1.25, live).writes);
        const noCopy = A.planApply(onGtk, null, 1.25, scaledLive);
        t.eq(noCopy.backup.gtk["gtk-3.0/settings.ini"], null, "sem cópia, o valor do modo (122880) não vira o original");
        t.eq(noCopy.backup.files["gtk-4.0/settings.ini"], false, "o GTK 4 criado pelo modo não conta como da pessoa");
        t.eq(noCopy.backup.files["electron-flags.conf"], false, "nem as flags só com a nossa linha");
    });
}
